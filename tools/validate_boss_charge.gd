extends SceneTree
## Close-pressure decision, real charge/contact/knockback and mobility regressions.
var game: Node
var level: LevelSession3D
var player: PlayerCharacter
var boss: CharacterBody3D
var controls: Node

func _init() -> void:
	call_deferred("_run")
	create_timer(45.0).timeout.connect(func():
		printerr("Boss charge validation timed out.")
		quit(1))

func _run() -> void:
	game = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_developer_level(game.developer_level_definitions[4])
	await process_frame
	level = game.current_level
	player = level.player
	boss = level.get_node("GreenZoneBoss")
	controls = level.get_node("BossLabController")

	# Both sides: natural missile decision becomes one charge, then ranged follow-up.
	for side in [-1.0, 1.0]:
		controls.test_close_pressure(side)
		var start_x := player.global_position.x
		await _until(func(): return boss.state_name() == "SPACE_CHARGE", 45, "Crowded missile intent did not charge.")
		assert(boss.missiles_fired == 0 and boss.smoke_escapes == 0)
		await _until(func(): return player.health.current < 100, 50, "Charge never contacted the player.")
		assert(player.health.current == 75 and not player.is_control_locked())
		assert(signf(player.get("_knockback_speed")) == side)
		assert(boss.state_name() == "RECOVERY" and boss.charge_cooldown_remaining > 3.9)
		await _frames(42)
		var free_push: float = (player.global_position.x - start_x) * side
		print("Unopposed charge push facing ", side, ": travel=", free_push)
		assert(free_push >= 8.0 and free_push < 10.5, "The stronger hit should create a controlled roughly nine-metre shove.")
		assert(player.health.current == 75 and boss.charges_started == 1 and boss.smoke_escapes == 0)
		await _until(func(): return boss.state_name() == "SALVO", 180, "Charge did not return to missile intent.")
		assert(boss.charge_cooldown_remaining > 0.0, "Charge must recharge during ranged follow-up.")

	# Holding ordinary run toward the boss cannot immediately swallow the shove.
	# Use the knife so mouse-dependent handgun backpedaling cannot weaken input.
	for side in [-1.0, 1.0]:
		controls.test_close_pressure(side)
		player.request_weapon(PlayerWeapon.KNIFE)
		var toward := "move_right" if side < 0.0 else "move_left"
		Input.action_press(toward)
		await _until(func(): return player.health.current == 75, 90, "Running pressure did not receive the charge.")
		var hit_x := player.global_position.x
		var peak_displacement := 0.0
		for tick in 100:
			await _frames(1)
			peak_displacement = maxf(peak_displacement, (player.global_position.x - hit_x) * side)
			assert(absf(player.global_position.z) < 0.01, "Push must remain on the play plane.")
			if boss.state_name() == "SALVO": break
		Input.action_release(toward)
		var followup_gap := absf(player.global_position.x - boss.global_position.x)
		print("Opposed charge push facing ", side, ": peak=", peak_displacement, ", ranged gap=", followup_gap)
		if peak_displacement < 6.0 or boss.state_name() != "SALVO" or followup_gap < 5.5:
			quit(1)
			assert(false, "Charge must create ranged space even against held running input.")
		assert(player.health.current == 75 and boss.smoke_escapes == 0 and not player.is_control_locked())

	# Actual jump during the committed windup clears the low body rush.
	controls.test_close_pressure()
	await _until(func(): return boss.state_name() == "SPACE_CHARGE", 45, "Jump setup failed.")
	var facing: float = boss.get("_charge_direction")
	Input.action_press("jump")
	await _frames(34)
	Input.action_release("jump")
	assert(player.health.current == 100, "Jumping over the charge must evade it.")
	assert(boss.get("_charge_direction") == facing, "Charge cannot turn to track a dodge.")
	assert(boss.smoke_escapes == 0, "An upward jump must not deploy smoke.")

	# A real dash away during windup escapes the committed short reach.
	controls.test_close_pressure()
	await _until(func(): return boss.state_name() == "SPACE_CHARGE", 45, "Dash setup failed.")
	Input.action_press("move_left")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	await _frames(30)
	Input.action_release("move_left")
	assert(player.health.current == 100 and boss.smoke_escapes == 0)

	# A dash after being hit cancels residual push; it never becomes a ground hold.
	controls.test_close_pressure()
	await _until(func(): return player.health.current == 75, 90, "Push setup failed.")
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	Input.action_release("move_right")
	assert(player.is_dashing() and is_zero_approx(player.get("_knockback_speed")))
	assert(not player.is_ground_held())

	# No charge for distant missile targets, jump intent, or unavailable missiles.
	controls.reset_fight()
	boss.phase_remaining = 0.05
	await _until(func(): return boss.state_name() == "SALVO", 40, "Distant missiles did not start.")
	assert(boss.charges_started == 0)
	controls.test_close_pressure()
	boss.set_pattern(2)
	await _until(func(): return boss.state_name() == "JUMP", 45, "Close jump intent changed.")
	assert(boss.charges_started == 0)
	controls.test_close_pressure()
	boss.missile_cooldown_remaining = 3.0
	await _frames(30)
	assert(boss.charges_started == 0 and boss.missiles_fired == 0)
	controls.test_close_pressure()
	boss.charge_cooldown_remaining = 3.0
	await _frames(30)
	assert(boss.charges_started == 0, "Crowding cannot bypass the charge cooldown.")

	# Committed front contact cannot hit someone who crossed behind the boss.
	controls.test_close_pressure()
	await _until(func(): return boss.state_name() == "SPACE_CHARGE", 45, "Behind setup failed.")
	player.global_position.x = boss.global_position.x + 2.8
	await _frames(38)
	assert(player.health.current == 100 and boss.smoke_escapes == 0)

	# Physical walls absorb push; boss movement stays inside authored bounds.
	controls.test_close_pressure(1.0)
	boss.global_position.x = boss.maximum_x - 1.0
	player.global_position.x = boss.global_position.x + 2.8
	level.camera.snap_to_target()
	await _until(func(): return player.health.current == 75, 90, "Wall-side charge did not hit.")
	await _frames(24)
	assert(player.global_position.x <= 38.71 and is_zero_approx(player.get("_knockback_speed")))
	assert(boss.global_position.x <= boss.maximum_x + 0.01)
	assert(player.health.current == 75, "Wall contact must not repeat damage.")

	# Damage ledger rejects duplicate impulses; reset and status changes clear momentum.
	controls.set_boss_active(false)
	var hit := CombatHit.new(25, &"boss_charge")
	assert(player.receive_knockback_hit(boss.global_position, hit, -18.0))
	var push: float = player.get("_knockback_speed")
	assert(not player.receive_knockback_hit(boss.global_position, hit, 18.0))
	assert(player.health.current == 75 and player.get("_knockback_speed") == push)
	controls.reset_fight()
	assert(is_zero_approx(player.get("_knockback_speed")))
	assert(player.receive_knockback_hit(boss.global_position, CombatHit.new(25, &"boss_charge"), -18.0))
	player.set_developer_inspection_enabled(true)
	assert(is_zero_approx(player.get("_knockback_speed")))
	player.set_developer_inspection_enabled(false)

	# A head landing still interrupts a charge into the existing smoke response.
	controls.test_close_pressure()
	await _until(func(): return boss.state_name() == "SPACE_CHARGE", 45, "Head setup failed.")
	player.global_position = boss.global_position + Vector3(0, boss.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y + 0.1, 0)
	player.velocity.y = -5.0
	await _until(func(): return player.is_ground_held(), 20, "Descending head contact lost its smoke response.")
	assert(boss.state_name() == "SMOKE_ESCAPE" and boss.smoke_escapes == 1)
	assert(boss.health.current == 300 and player.health.current == 100)
	assert(boss.charge_cooldown_remaining > 0.0 and is_zero_approx(player.get("_knockback_speed")))
	controls.reset_fight()
	assert(not player.is_control_locked() and boss.charges_started == 0)
	game.queue_free()
	await process_frame
	print("Boss charge passed: ranged-intent gating, both directions, single damage/push, ranged follow-up, jump/dash evasion, fixed direction, cooldowns, walls, duplicate rejection, reset and head-only smoke.")
	quit()

func _frames(count: int) -> void:
	for tick in count: await physics_frame

func _until(predicate: Callable, maximum_frames: int, message: String) -> void:
	for tick in maximum_frames:
		if predicate.call(): return
		await physics_frame
	if not predicate.call():
		printerr(message)
		quit(1)
		assert(false, message)
