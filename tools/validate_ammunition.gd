extends SceneTree
## Ammo conservation, reload/cancel boundaries, reward claims and saved state.
const AMMO: StringName = &"handgun_ammo"


func _init() -> void:
	call_deferred("_run")
	create_timer(20.0, true).timeout.connect(func() -> void: quit(1))


func _run() -> void:
	var app := preload("res://scenes/app/game_root.tscn").instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_room()
	await process_frame
	await physics_frame
	var session: LevelSession3D = app.current_level
	var player := session.player
	var gun := player.player_handgun
	player.set_physics_process(false)
	gun.set_physics_process(false)
	_check_trigger_cadence(player, gun)
	_check_active_reload(player, gun, app.weapon_status_hud)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 30)
	assert(not gun.start_reload(), "A full magazine must not spend ammo or play a reload.")
	for index in 12:
		assert(gun.fire(1.0, false, player) != null)
		gun._physics_process(gun.definition.fire_interval)
	assert(gun.loaded_rounds == 0 and gun.reserve_rounds() == 30)
	assert(gun.fire(1.0, false, player) == null, "An empty gun cannot spawn another projectile.")
	# Running out of ammo must not leave the previous shot stuck as an attack.
	player.set("_active_attack_weapon_id", PlayerWeapon.HANDGUN)
	player._update_attack(0.0)
	assert(not player.is_attacking())
	assert(gun.start_reload(), "Empty guns must still be reloadable.")
	gun._physics_process(0.6)
	assert(gun.loaded_rounds == 0 and gun.reserve_rounds() == 30)
	assert(not gun.start_reload(), "Repeated reload input cannot reset progress.")
	assert(gun.fire(1.0, false, player) == null)
	gun._physics_process(0.91)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 18)

	gun.set_loaded_rounds(9)
	assert(gun.start_reload())
	gun._physics_process(0.5)
	assert(player.request_weapon(PlayerWeapon.KNIFE))
	gun._physics_process(0.01)
	assert(not gun.is_reloading() and gun.loaded_rounds == 9 and gun.reserve_rounds() == 18)
	assert(not app.weapon_status_hud.status_is_visible())
	assert(player.request_weapon(PlayerWeapon.HANDGUN))
	assert(gun.start_reload())
	gun._physics_process(1.51)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 15, "Top-up preserves remaining rounds.")

	player.inventory.consume(AMMO, 13)
	gun.set_loaded_rounds(8)
	assert(gun.start_reload())
	gun._physics_process(1.51)
	assert(gun.loaded_rounds == 10 and gun.reserve_rounds() == 0, "A short reserve gives a partial magazine.")
	assert(not gun.start_reload())
	assert(not player.inventory.equip(0, AMMO), "Reserve ammo is not a healing quick item.")
	player.inventory.add(AMMO, 5)
	assert(gun.start_reload())
	player.health.damage(CombatHit.new(25, &"fixture"))
	gun._physics_process(0.01)
	assert(not gun.is_reloading() and gun.loaded_rounds == 10 and gun.reserve_rounds() == 5)

	var before := session.save_state.transfer_state()
	var chest := session.get_node("HealingChestFixture") as ItemReward3D
	var medicine := player.inventory.count(&"basic_heal")
	assert(chest.collect())
	assert(gun.reserve_rounds() == 35 and player.inventory.count(&"basic_heal") == medicine + 1)
	assert(not chest.collect() and gun.reserve_rounds() == 35)
	var after := session.save_state.transfer_state()
	session.save_state.apply_state(before)
	assert(gun.loaded_rounds == 10 and gun.reserve_rounds() == 5)
	assert(chest.collect() and gun.reserve_rounds() == 35)
	session.save_state.apply_state(after)
	assert(not chest.collect() and gun.reserve_rounds() == 35)

	# Exercise actual disk serialization in the runner's isolated profile.
	app.load_level("arrival_shoreline")
	await process_frame
	await physics_frame
	session = app.current_level
	player = session.player
	gun = player.player_handgun
	assert(session.acquire_weapon(PlayerWeapon.HANDGUN))
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 18, "First weapon grants 30 total rounds.")
	assert(not session.acquire_weapon(PlayerWeapon.HANDGUN))
	assert(gun.reserve_rounds() == 18, "Repeated acquisition cannot duplicate ammo.")
	gun.set_loaded_rounds(7)
	var store := ProgressionStore.new()
	store.save_path = "user://ammunition_validation/progress.json"
	store.load_progress()
	store.unlock_weapon(PlayerWeapon.HANDGUN)
	var saved := session.save_state.capture(player.global_position)
	saved.progress = store.progress.to_dictionary()
	assert(store.write_snapshot(saved, "manual", 1), store.last_error)
	gun.set_loaded_rounds(1)
	player.inventory.consume(AMMO, 15)
	var cold := ProgressionStore.new()
	cold.save_path = store.save_path
	cold.load_progress()
	var reloaded: Dictionary = cold.read_slot("manual", 1).data
	player.restore_state(reloaded.player)
	assert(gun.loaded_rounds == 7 and gun.reserve_rounds() == 18)
	var invalid: Dictionary = reloaded.player.duplicate(true)
	invalid.handgun_ammo.loaded = 13
	assert(not SaveSnapshot.player_error(invalid).is_empty())
	invalid = reloaded.player.duplicate(true)
	invalid.inventory.quick_slots[0] = "handgun_ammo"
	assert(not SaveSnapshot.player_error(invalid).is_empty())
	# Old unlimited-gun saves migrate once; new saves retain exact amounts.
	var legacy: Dictionary = reloaded.player.duplicate(true)
	legacy.erase("handgun_ammo")
	legacy.inventory.quantities.erase("handgun_ammo")
	assert(SaveSnapshot.player_error(legacy).is_empty())
	player.restore_state(legacy)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 18)
	var migrated := player.capture_state()
	player.restore_state(migrated)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 18)
	store.free()
	cold.free()
	app.free()
	print("Ammunition passed: active timing/input/one-attempt/pause/interruption, empty/full/partial magazines, conservation, knife HUD, chest claims, exact saves and migration.")
	quit()


func _check_trigger_cadence(player: PlayerCharacter, gun: PlayerHandgun3D) -> void:
	assert(is_equal_approx(gun.definition.fire_interval, 0.20))
	assert(not gun.try_empty_trigger(), "A loaded gun cannot accept an empty trigger pull.")
	gun.set_loaded_rounds(1)
	assert(gun.fire(1.0, false, player) != null)
	assert(is_equal_approx(gun.cooldown_remaining(), 0.20))
	assert(not gun.try_empty_trigger(), "The last live round must delay the first empty click.")
	gun._physics_process(0.19)
	assert(not gun.try_empty_trigger())
	gun._physics_process(0.011)
	assert(gun.try_empty_trigger())
	assert(is_equal_approx(gun.cooldown_remaining(), 0.20))
	gun._physics_process(0.19)
	assert(not gun.try_empty_trigger(), "Empty clicks must obey the same interval as shots.")
	gun._physics_process(0.011)
	assert(gun.try_empty_trigger())
	assert(gun.loaded_rounds == 0 and gun.reserve_rounds() == 30)
	gun.set_loaded_rounds(12)
	assert(not gun.can_fire(), "Ammunition changes must not erase trigger recovery.")
	gun._physics_process(0.20)
	assert(gun.can_fire())
	gun.reset_run()


func _check_active_reload(player: PlayerCharacter, gun: PlayerHandgun3D, hud: WeaponStatusHUD) -> void:
	var original := player.capture_state()
	var press := InputEventAction.new()
	press.action = &"reload"
	press.pressed = true
	# A seeded sample checks variation without flaky chance-based assertions.
	gun._reload_random.seed = 20260921
	var sampled_positions := {}
	for index in 16:
		gun.set_loaded_rounds(8)
		assert(gun.start_reload())
		var window := gun.active_reload_window()
		assert(window.x >= gun.definition.active_reload_earliest - 0.00001)
		assert(window.x <= gun.definition.active_reload_latest + 0.00001)
		assert(is_equal_approx(window.y - window.x, gun.definition.active_reload_window))
		assert(window.y < gun.definition.reload_duration)
		sampled_positions[roundi(window.x * 10.0)] = true
		gun._physics_process(0.1)
		assert(not gun.start_reload())
		assert(gun.active_reload_window() == window, "Ticking or repeated starts cannot move the current target.")
		gun.cancel_reload()
	assert(sampled_positions.size() >= 3, "Success zones must move across successive reloads.")
	# One early mistake uses the attempt; mashing later cannot rescue it.
	gun.set_loaded_rounds(8)
	assert(gun.start_reload())
	gun._physics_process(gun.active_reload_window().x - 0.01)
	var remaining := gun._reload_remaining
	assert(not gun.try_active_reload())
	assert(is_equal_approx(gun._reload_remaining, remaining))
	gun._physics_process(0.11)
	assert(not gun.try_active_reload() and gun.loaded_rounds == 8)
	gun._physics_process(gun._reload_remaining + 0.01)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 26)

	# A late press also preserves the original completion time.
	gun.set_loaded_rounds(8)
	gun._unhandled_input(press)
	gun._physics_process(gun.active_reload_window().y + 0.01)
	remaining = gun._reload_remaining
	assert(not gun.try_active_reload())
	assert(is_equal_approx(gun._reload_remaining, remaining))
	gun._physics_process(gun._reload_remaining + 0.01)
	assert(gun.loaded_rounds == 12 and gun.reserve_rounds() == 22)

	# Reload input inside either edge of the window completes immediately.
	for offset in [0.001, gun.definition.active_reload_window - 0.001]:
		gun.set_loaded_rounds(8)
		var total := gun.loaded_rounds + gun.reserve_rounds()
		gun._unhandled_input(press)
		gun._physics_process(gun.active_reload_window().x + offset)
		gun._unhandled_input(press)
		assert(not gun.is_reloading() and gun.can_fire())
		assert(gun.loaded_rounds == 12 and gun.loaded_rounds + gun.reserve_rounds() == total)
		assert(hud._reload_success_remaining > 0.0)
		assert(not gun._reload_voice.playing)
		gun._unhandled_input(press)
		assert(not gun.is_reloading(), "Repeated input cannot reload a full magazine.")

	# Pause must not consume the timing attempt.
	gun.set_loaded_rounds(8)
	assert(gun.start_reload())
	gun._physics_process(gun.active_reload_window().x + gun.definition.active_reload_window * 0.5)
	paused = true
	assert(not gun.try_active_reload() and gun.active_reload_available())
	paused = false
	assert(gun.try_active_reload())

	# A hit just before the button press cancels, even before the next tick.
	gun.set_loaded_rounds(8)
	assert(gun.start_reload())
	gun._physics_process(gun.active_reload_window().x + gun.definition.active_reload_window * 0.5)
	var reserve := gun.reserve_rounds()
	player.health.damage(CombatHit.new(25, &"active_reload_fixture"))
	assert(not gun.try_active_reload())
	assert(not gun.is_reloading() and gun.loaded_rounds == 8 and gun.reserve_rounds() == reserve)

	# Successful timing never creates ammunition when the reserve is short.
	player.inventory.consume(AMMO, gun.reserve_rounds() - 2)
	assert(gun.start_reload())
	gun._physics_process(gun.active_reload_window().x + gun.definition.active_reload_window * 0.5)
	assert(gun.try_active_reload())
	assert(gun.loaded_rounds == 10 and gun.reserve_rounds() == 0)
	player.restore_state(original)
