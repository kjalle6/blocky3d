extends SceneTree
## Crowd defense must run beside, never restart or turn, a committed six-shot salvo.
var game: Node
var level: LevelSession3D
var player: PlayerCharacter
var boss: CharacterBody3D
var controls: Node
var shots: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")
	create_timer(45.0).timeout.connect(func():
		printerr("Boss salvo shove validation timed out.")
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
	boss.missile_fired.connect(func(rocket):
		shots.append({"time": boss.phase_time, "target": rocket.target_position,
			"direction": rocket.travel_direction()}))

	# Reproduce the actual exploit: keep running back after the opening charge.
	for side in [-1.0, 1.0]:
		controls.test_close_pressure(side)
		player.set_physics_process(true)
		player.request_weapon(PlayerWeapon.KNIFE)
		player.health.reset(1000)
		shots.clear()
		var toward := "move_right" if side < 0.0 else "move_left"
		Input.action_press(toward)
		await _until(func(): return boss.state_name() == "SALVO", 240, "Opening charge never reached its salvo.")
		var committed: Vector3 = boss.get("_salvo_target")
		var facing: float = boss.get("_facing")
		await _until(func(): return boss.salvo_shoves == 1, 90, "Running back into the firing boss escaped its shove.")
		Input.action_release(toward)
		assert(boss.state_name() == "SALVO" and boss.charges_started == 1)
		assert(boss.charge_cooldown_remaining > 0.0, "Defense must work while the opening charge recharges.")
		assert(signf(player.get("_knockback_speed")) == side)
		assert(not player.is_control_locked() and boss.smoke_escapes == 0)
		assert(boss.get("_salvo_target") == committed and boss.get("_facing") == facing)
		var hit_x := player.global_position.x
		var at_shove: int = boss.missiles_fired
		await _until(func(): return boss.state_name() == "RECOVERY", 90, "Shove stalled or restarted the volley.")
		_check_six_shots(committed, facing)
		await _frames(25)
		assert((player.global_position.x - hit_x) * side > 6.0, "Return pressure must be pushed clear.")
		assert(absf(player.global_position.z) < 0.01)
		print("Real run-back repelled facing ", side, " after ", at_shove, " rockets; all six completed.")

	# Swivel and late firing, front and rear: independent of charge cooldown.
	for phase in [0.05, 0.82]:
		for side in [-1.0, 1.0]:
			await _setup_salvo()
			var committed: Vector3 = boss.get("_salvo_target")
			var facing: float = boss.get("_facing")
			await _until(func(): return boss.phase_time >= phase, 70, "Timed contact setup failed.")
			var prior_shots: int = boss.missiles_fired
			_place_at_side(side)
			await _until(func(): return boss.salvo_shoves == 1, 3, "Crowding was unprotected during the firing process.")
			assert(player.health.current == 975 and signf(player.get("_knockback_speed")) == side)
			assert(boss.state_name() == "SALVO" and boss.get("_facing") == facing)
			assert(boss.get("_salvo_target") == committed and boss.charges_started == 0)
			assert(boss.missiles_fired >= prior_shots and boss.smoke_escapes == 0 and not player.is_ground_held())
			player.global_position = boss.global_position + Vector3(-9, 5, 0)
			await _until(func(): return boss.state_name() == "RECOVERY", 90, "Contact restarted the salvo.")
			_check_six_shots(committed, facing)

	# Remaining pressed into its side can trigger a second shove, but never
	# per-frame damage. A frozen target emulates a blocked displacement here.
	await _setup_salvo()
	_place_at_side(1.0)
	await _until(func(): return boss.salvo_shoves == 1, 3, "First blocked-contact shove missing.")
	await _frames(25)
	assert(boss.salvo_shoves == 1 and player.health.current == 975)
	await _until(func(): return boss.salvo_shoves == 2, 20, "Salvo defense did not rearm.")
	assert(player.health.current == 950)
	await _until(func(): return boss.state_name() == "RECOVERY", 60, "Blocked-contact salvo did not finish.")
	await _frames(30)
	assert(boss.salvo_shoves == 2 and player.health.current == 950, "Defense must stop outside missile firing.")

	# Vertical clearance and intervening terrain each prevent a body shove.
	await _setup_salvo()
	player.global_position = boss.global_position + Vector3(1.9, 3.3, 0)
	await _frames(40)
	assert(boss.salvo_shoves == 0 and player.health.current == 1000)
	await _setup_salvo()
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 3.0, 1.0)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	wall.global_position = boss.global_position + Vector3(1.6, 1.5, 0)
	await _frames(2)
	_place_at_side(1.0)
	await _frames(20)
	assert(boss.salvo_shoves == 0 and player.health.current == 1000, "Cannot shove through solid terrain.")
	wall.queue_free()
	await _frames(2)

	# Real descending head contact still takes priority over the body defense.
	await _setup_salvo()
	player.set_physics_process(true)
	player.global_position = boss.global_position + Vector3(0, boss.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y + 0.1, 0)
	player.velocity.y = -5.0
	await _until(func(): return player.is_ground_held(), 20, "Head landing lost its smoke response.")
	assert(boss.state_name() == "SMOKE_ESCAPE" and boss.salvo_shoves == 0 and boss.smoke_escapes == 1)
	assert(boss.health.current == 300 and player.health.current == 1000)
	controls.reset_fight()
	assert(boss.salvo_shoves == 0 and is_zero_approx(boss.salvo_shove_cooldown_remaining))
	assert(not player.is_control_locked())
	game.queue_free()
	await process_frame
	print("Boss salvo shove passed: real run-back, both sides, swivel/late shots, independent cooldown, fixed six-rocket commitment, repeat limit, vertical/terrain clearance, recovery and head-only smoke.")
	quit(0)

func _setup_salvo() -> void:
	controls.test_missile_ripple(-1.0)
	player.set_physics_process(false)
	player.health.reset(1000)
	shots.clear()
	await _frames(4)
	boss.charge_cooldown_remaining = 4.0
	boss._start_salvo(player)

func _place_at_side(side: float) -> void:
	player.global_position = boss.global_position + Vector3(side * 1.9, PlayerCharacter.FEET_OFFSET_Y, 0)

func _check_six_shots(committed: Vector3, facing: float) -> void:
	assert(shots.size() == 6 and boss.missiles_fired == 6, "Shoving cannot lose, duplicate or restart rockets.")
	for i in 6:
		assert(absf(shots[i].target.x - committed.x) <= 0.76)
		assert(is_equal_approx(shots[i].target.y, committed.y))
		assert(shots[i].direction.x * facing > 0.0, "Contact behind cannot turn the launcher.")
		if i > 0:
			assert(absf(shots[i].time - shots[i - 1].time - 0.12) < 0.02, "Shoving cannot alter the firing cadence.")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _until(condition: Callable, limit: int, message: String) -> void:
	for i in limit:
		if condition.call(): return
		await _frames(1)
	printerr(message, " state=", boss.state_name(), " phase=", boss.phase_time,
		" boss=", boss.global_position, " player=", player.global_position,
		" shoves=", boss.salvo_shoves, " rockets=", boss.missiles_fired,
		" held=", player.is_control_locked(), " knockback=", player.get("_knockback_speed"))
	quit(1)
	assert(false, message)
