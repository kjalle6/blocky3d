extends SceneTree
## Solid supported boss, actual movement input, elevated floors and airborne exceptions.
var game: Node
var level: LevelSession3D
var player: PlayerCharacter
var boss: CharacterBody3D
var controls: Node

func _init() -> void:
	call_deferred("_run")
	create_timer(40.0).timeout.connect(func():
		printerr("Boss body blocking validation timed out.")
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
	for side in [-1.0, 1.0]:
		await _setup(side)
		var action := "move_right" if side < 0 else "move_left"
		Input.action_press(action)
		await _frames(60)
		assert((player.global_position.x - boss.global_position.x) * side > 1.65, "Running cannot pass the grounded boss.")
		assert(player.is_on_floor() and player.is_on_wall())
		assert(player.health.current == 100 and boss.smoke_escapes == 0)
		Input.action_press("dash")
		await _frames(2)
		Input.action_release("dash")
		await _frames(18)
		Input.action_release(action)
		assert((player.global_position.x - boss.global_position.x) * side > 1.65, "Ground dash cannot phase through the boss.")
		assert(boss.health.current == 300 and player.health.current == 100)

	# Real double jump clears the boss, which is taller than one ordinary jump.
	await _setup(-1.0)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(10)
	Input.action_release("jump")
	await _frames(1)
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(24)
	Input.action_release("jump")
	await _frames(38)
	Input.action_release("move_right")
	assert(player.global_position.x > boss.global_position.x + 2.0, "Jump must clear the boss.")
	assert(boss.smoke_escapes == 0 and player.health.current == 100, "The tested double jump must clear the head without contact.")

	# A raised solid platform uses the same rule, not a hard-coded floor Y.
	await _setup(-1.0)
	var platform := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 1, 2)
	shape.shape = box
	platform.add_child(shape)
	level.add_child(platform)
	platform.global_position = Vector3(boss.global_position.x, 5.5, 0)
	boss.global_position.y = 6.05
	player.global_position = boss.global_position + Vector3(-3, PlayerCharacter.FEET_OFFSET_Y, 0)
	level.camera.snap_to_target()
	await _frames(12)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	assert(boss.is_on_floor() and player.is_on_floor())
	assert(player.feet_world_y() > 5.95 and player.global_position.x < boss.global_position.x - 1.65)
	platform.queue_free()
	await _frames(2)

	# Boss airborne motion stays free of player collision, and its landing hits terrain.
	await _setup(-1.0)
	boss._start_jump(player)
	await _frames(18)
	player.global_position.x = boss.global_position.x - 1.0
	Input.action_press("move_right")
	await _frames(15)
	Input.action_release("move_right")
	assert(player.global_position.x > boss.global_position.x + 1.0, "The airborne boss must leave passage underneath.")
	assert(boss.get_collision_exceptions().has(player))
	await _frames(60)
	assert(absf(boss.global_position.y) < 0.05)

	# Landing directly onto a real grounded player must not bury or trap either body.
	await _setup(-1.0)
	boss._start_jump(player)
	for tick in 130:
		await _frames(1)
		if absf(player.global_position.z) > 0.01 or absf(boss.global_position.z) > 0.01:
			print("DRIFT ", tick, " ", boss.state_name(), " p=", player.global_position, " b=", boss.global_position, " exceptions=", boss.get_collision_exceptions().size())
			quit(1)
			return
		if boss.landing_count == 1: break
	assert(boss.landing_count == 1, "Landing must reach terrain.")
	await _frames(20)
	assert(absf(player.global_position.z) < 0.01 and absf(boss.global_position.z) < 0.01,
		"Landing overlap must stay inside the 2D play plane.")
	assert(player.feet_world_y() > -0.06, "Solid landing must not push the player through terrain.")
	assert(absf(boss.global_position.y) < 0.05, "Boss must land on terrain, not the player.")
	Input.action_press("move_left")
	await _frames(35)
	Input.action_release("move_left")
	assert(player.global_position.x < boss.global_position.x - 1.65, "Player must be able to leave a landing overlap.")

	# Existing head landing drops the player onto terrain during smoke, then resets solid.
	controls.test_head_landing()
	await _until(func(): return player.is_ground_held(), 30, "Head contact did not trigger smoke.")
	await _frames(28)
	assert(player.is_on_floor() and absf(player.feet_world_y()) < 0.05)
	assert(boss.health.current == 300 and player.health.current == 100)
	controls.reset_fight()
	await _frames(5)
	assert(not boss.get_collision_exceptions().has(player))
	boss.receive_melee_hit(player.global_position, CombatHit.new(300, &"test_defeat"))
	await _frames(4)
	assert(boss.get_collision_exceptions().has(player))
	controls.reset_fight()
	await _frames(5)
	assert(not boss.get_collision_exceptions().has(player))
	game.queue_free()
	await process_frame
	print("Boss body blocking passed: both sides, run/dash, jump-over, raised support, airborne passage, landing, head smoke, defeat/reset.")
	quit()

func _setup(side: float) -> void:
	controls.set_boss_active(false)
	player.global_position = boss.global_position + Vector3(side * 3.0, PlayerCharacter.FEET_OFFSET_Y, 0)
	level.camera.snap_to_target()
	await _frames(8)
	assert(absf(player.global_position.z) < 0.01 and absf(boss.global_position.z) < 0.01,
		"Reset must restore both bodies to the play plane.")

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
