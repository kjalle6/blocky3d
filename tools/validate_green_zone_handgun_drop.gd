extends SceneTree
## Focused contract for the first gun's death-gated physical presentation,
## collection, and run-local ownership lifecycle.

const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")

var _completed := false
var _drop_started_count := 0
var _settled_count := 0
var _acquired_count := 0
var _pickup_sounds: Array[Dictionary] = []


func _init() -> void:
	create_timer(12.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Green Zone handgun-drop validation aborted before completing.")
	quit(1)


func _run() -> void:
	var original_mix := FileAccess.get_sha256(MIX.SAVE_PATH)
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame

	var shooter := level.get_node(
		"ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy"
	) as HandgunEnemy3D
	var anchor := level.get_node(
		"ShooterEncounterStaging/GunDropAnchor"
	) as Marker3D
	var pickup := anchor.get_node("HandgunPickup") as HandgunPickup3D
	var panel: CanvasLayer = game_root.audio_tuning_panel
	panel.open_panel()
	panel.select_event("pickups/handgun")
	var bank: Resource = panel._bank()
	bank.clips.clear()
	bank.labels.clear()
	bank.disabled_indices.clear()
	panel._add_files(PackedStringArray(["res://assets/audio/combat/shot_1.wav", "res://assets/audio/combat/shot_2.wav"]))
	bank.enabled = true
	bank.selection_mode = 1
	bank.fixed_index = 1
	bank.volume_db = -31.0
	bank.pitch_scale = 1.1
	bank.pitch_variation = 0.0
	bank.use_room_reverb = false
	panel.close_panel()
	level.combat_feedback.combat_audio.event_played.connect(func(event: Dictionary) -> void:
		if event.id == "pickups/handgun": _pickup_sounds.append(event))
	pickup._on_body_entered(level.player)
	assert(_pickup_sounds.is_empty(), "A locked pickup must not play collection audio.")
	assert(shooter != null and anchor != null and pickup != null)
	assert(level.get_tree().get_nodes_in_group("weapon_pickup").size() == 1)
	assert(pickup.validation_errors().is_empty())
	assert(pickup.is_locked())
	assert(not pickup.visible)
	assert(pickup.collection_enabled)
	assert(not pickup.collection_is_active())
	assert(pickup.collection_shape.disabled)
	assert(pickup.landing_position().is_equal_approx(anchor.global_position))
	assert(is_equal_approx(anchor.global_position.x, 23.04))
	assert(is_equal_approx(anchor.global_position.y, 0.18))

	pickup.drop_started.connect(func() -> void: _drop_started_count += 1)
	pickup.settled.connect(func() -> void: _settled_count += 1)
	level.weapon_acquired.connect(
		func(weapon_id: StringName) -> void:
			if weapon_id == PlayerWeapon.HANDGUN:
				_acquired_count += 1
	)
	shooter.receive_melee_hit(level.player.global_position, CombatHit.new(50, &"fixture"))
	assert(shooter.is_defeated())
	assert(_drop_started_count == 1)
	assert(pickup.is_airborne())
	assert(pickup.visible)
	assert(not pickup.collection_is_active())
	assert(pickup.visual.texture.resource_path.ends_with(
		"/handgun_pickup_airborne.png"
	))
	assert(pickup.global_position.x > pickup.landing_position().x)
	assert(pickup.global_position.y > pickup.landing_position().y)

	# A defeated enemy cannot create another reward from repeated hit requests.
	shooter.receive_melee_hit(level.player.global_position, CombatHit.new(50, &"fixture"))
	assert(_drop_started_count == 1)

	for frame in 90:
		await physics_frame
		if pickup.is_available():
			break
	assert(pickup.is_available())
	assert(_settled_count == 1)
	assert(pickup.global_position.is_equal_approx(anchor.global_position))
	assert(pickup.visual.texture.resource_path.ends_with("/handgun_pickup.png"))
	assert(is_zero_approx(pickup.visual.rotation.z))
	assert(pickup.collection_is_active())
	assert(not pickup.collection_shape.disabled)

	# Entering the settled pickup grants exactly one session-owned gun and
	# auto-equips it. The scene-authored actor is claimed rather than replaced.
	level.player.reset_at(Transform3D(
		Basis.IDENTITY,
		Vector3(anchor.global_position.x, 0.7, 0.0)
	))
	for frame in 8:
		await physics_frame
	assert(_acquired_count == 1)
	assert(_pickup_sounds.size() == 1, "Real pickup contact must play its audio-tool bank exactly once.")
	assert(_pickup_sounds[0].clip_index == 1 and _pickup_sounds[0].volume_db == -31.0)
	assert(is_equal_approx(_pickup_sounds[0].pitch, 1.1) and _pickup_sounds[0].bus == &"Master")
	pickup._on_body_entered(level.player)
	assert(_pickup_sounds.size() == 1)
	assert(level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	assert(pickup.is_claimed())
	assert(not pickup.visible)
	assert(not pickup.collection_is_active())
	assert(pickup.collection_shape.disabled)

	assert(level.combat_feedback.combat_audio._voices.any(func(voice: AudioStreamPlayer3D) -> bool:
		return voice.process_mode == Node.PROCESS_MODE_ALWAYS and not voice.stream_paused),
		"The collection cue must remain unpaused during the reveal.")
	await _validate_unlock_reveal(game_root, level)
	var restored := level.save_state.transfer_state()
	level.save_state.apply_state(restored)
	assert(game_root.campaign_menu.page.is_empty() and not paused,
		"Restoring ownership must not reopen the first-pickup showcase.")

	# A death/checkpoint world reset retains the earned weapon and cannot reveal
	# or duplicate its one pickup.
	level.call(&"_reset_world")
	for frame in 6:
		await physics_frame
	assert(level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	assert(pickup.is_claimed())
	assert(not pickup.visible)
	assert(_acquired_count == 1)
	assert(_pickup_sounds.size() == 1, "Restoring an owned gun must not replay pickup audio.")
	assert(game_root.campaign_menu.page.is_empty() and not paused)

	# Manual R is the authored full-section restart: it clears the session gun,
	# rearms the shooter, and reuses the same locked pickup actor.
	level.call(&"_reset_run")
	for frame in 6:
		await physics_frame
	assert(not shooter.is_defeated())
	assert(not level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	assert(pickup.is_locked())
	assert(not pickup.visible)
	assert(not pickup.collection_is_active())
	assert(pickup.global_position.is_equal_approx(anchor.global_position))

	# Resetting during the kick cannot leave a delayed bounce or ghost pickup.
	shooter.receive_melee_hit(level.player.global_position, CombatHit.new(50, &"fixture"))
	for frame in 8:
		await physics_frame
	assert(pickup.is_airborne())
	assert(_drop_started_count == 2)
	level.call(&"_reset_run")
	for frame in 45:
		await physics_frame
	assert(not shooter.is_defeated())
	assert(pickup.is_locked())
	assert(not pickup.visible)
	assert(_settled_count == 1)

	# The exact same actor can perform the complete deterministic drop again.
	shooter.receive_melee_hit(level.player.global_position, CombatHit.new(50, &"fixture"))
	for frame in 90:
		await physics_frame
		if pickup.is_available():
			break
	assert(pickup.is_available())
	assert(_drop_started_count == 3)
	assert(_settled_count == 2)
	assert(pickup.global_position.is_equal_approx(anchor.global_position))
	assert(pickup.collection_is_active())
	assert(level.get_tree().get_nodes_in_group("weapon_pickup").size() == 1)

	bank.enabled = false
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(anchor.global_position.x, 0.7, 0.0)))
	for frame in 8: await physics_frame
	assert(pickup.is_claimed() and _pickup_sounds.size() == 1, "Muted pickups still grant the weapon silently.")
	await _validate_unlock_reveal(game_root, level, &"mouse")
	game_root.campaign_menu.show_weapon_unlock(PlayerWeapon.HANDGUN)
	await _validate_unlock_reveal(game_root, level, &"controller")
	# Switching sections while a reveal is open must release its pause.
	game_root.campaign_menu.show_weapon_unlock(PlayerWeapon.HANDGUN)
	game_root.load_level(&"arrival_shoreline")
	assert(game_root.campaign_menu.page.is_empty() and not paused)
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_mix)
	print(
		"Green Zone handgun drop passed: one authored pickup, crisp two-pose "
		+ "kick, one acquisition, death persistence, full-restart rearm, and "
		+ "reset cancellation; selected pickup audio, mute and saved-mix preservation; "
		+ "first-pickup showcase, pause, input protection, mouse/keyboard dismissal and restore cleanup."
	)
	_completed = true
	quit(0)


func _validate_unlock_reveal(app: Node, level: LevelSession3D, control := &"keyboard") -> void:
	var menu: CanvasLayer = app.campaign_menu
	assert(menu.page == "weapon_unlock" and paused)
	assert(not app.weapon_status_hud.hint_is_visible())
	var origin := level.player.global_position
	var loaded := level.player.player_handgun.loaded_rounds
	# Neither a leftover release nor an early press can skip the reveal.
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await process_frame
	assert(paused and menu.page == "weapon_unlock")
	await create_timer(0.35).timeout
	assert(level.player.global_position.is_equal_approx(origin), "The world must stay still during the reveal.")
	assert(menu.weapon_unlock_panel.is_armed())
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	_key(KEY_J, true)
	_key(KEY_J, false)
	await process_frame
	assert(menu.page == "weapon_unlock" and paused, "Inventory and attack cannot replace or dismiss the showcase.")
	if control == &"mouse":
		var point: Vector2 = menu.weapon_unlock_panel.continue_button.get_global_rect().get_center()
		_mouse(point, true)
		await process_frame
		assert(paused)
		_mouse(point, false)
	elif control == &"controller":
		_joy(true)
		await process_frame
		assert(paused)
		_joy(false)
	else:
		_key(KEY_SPACE, true)
		await process_frame
		assert(paused, "Confirmation must wait for release to avoid an accidental jump.")
		_key(KEY_SPACE, false)
	for frame in 2: await physics_frame
	assert(not paused and menu.page.is_empty(), "%s did not dismiss the reveal." % control)
	assert(level.player.velocity.y <= 0.0, "Dismissing must not jump.")
	assert(level.player.player_handgun.loaded_rounds == loaded, "Dismissing must not fire.")
	# Once owned, further contact cannot replay either the reveal or its cue.
	level.get_node("ShooterEncounterStaging/GunDropAnchor/HandgunPickup")._on_body_entered(level.player)
	assert(menu.page.is_empty())


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _joy(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	root.push_input(event)


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
