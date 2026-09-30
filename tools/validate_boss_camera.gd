extends SceneTree
## Nearby boss framing, distant player follow, vertical mobility and transitions.
var game: Node
var level: LevelSession3D
var player: PlayerCharacter
var boss: CharacterBody3D
var camera: PixelSideCamera3D

func _init() -> void:
	call_deferred("_run")
	create_timer(20.0).timeout.connect(func():
		printerr("Boss camera validation timed out.")
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
	camera = level.camera
	level.get_node("BossLabController").set_boss_active(false)
	player.set_physics_process(false)
	boss.set_physics_process(false)
	for tick in 4:
		await physics_frame
		await process_frame
	# Both directions, including the full combat range and room edges.
	for setup in [Vector2(15, 6), Vector2(15, 24), Vector2(15, -3),
			Vector2(15, 33), Vector2(-16.4, -7.4), Vector2(36.88, 27.88)]:
		boss.global_position = Vector3(setup.x, 0, 0)
		player.global_position = Vector3(setup.y, PlayerCharacter.FEET_OFFSET_Y, 0)
		camera.snap_to_target()
		assert(is_equal_approx(camera.size, 12.9375 * 1.22))
		_assert_bodies_visible()
	# Vertical follow must retain the ground-level boss during a high jump.
	boss.global_position = Vector3(15, 0, 0)
	player.global_position = Vector3(6, 10.7, 0)
	camera.snap_to_target()
	_assert_bodies_visible()
	# Well outside the fight, let the boss leave frame and follow the player.
	player.global_position = Vector3(-17, PlayerCharacter.FEET_OFFSET_Y, 0)
	camera.snap_to_target()
	assert(is_equal_approx(camera.size, 12.9375))
	assert(camera.is_position_in_frustum(player.global_position))
	assert(not camera.is_position_in_frustum(boss.global_position + Vector3.UP * 1.5))
	# Enter and leave combat smoothly. No snap/pumping of zoom each frame.
	player.global_position = Vector3(6, PlayerCharacter.FEET_OFFSET_Y, 0)
	var previous_size := camera.size
	for tick in 90:
		await physics_frame
		await process_frame
		assert(camera.size >= previous_size - 0.001 and camera.size - previous_size < 0.3,
			"Zoom-in transition jumped: " + str(previous_size) + " -> " + str(camera.size))
		previous_size = camera.size
	_assert_bodies_visible()
	assert(camera.size > 15.6)
	player.global_position = Vector3(-17, PlayerCharacter.FEET_OFFSET_Y, 0)
	for tick in 90:
		await physics_frame
		await process_frame
		assert(camera.size <= previous_size + 0.001 and previous_size - camera.size < 0.3)
		previous_size = camera.size
	assert(camera.size < 13.0)
	# Inspection and defeat return to player framing; reset restores the fight.
	player.global_position = Vector3(6, PlayerCharacter.FEET_OFFSET_Y, 0)
	camera.set_developer_inspection_enabled(true)
	assert(is_equal_approx(camera.size, 12.9375))
	camera.set_developer_inspection_enabled(false)
	_assert_bodies_visible()
	boss.receive_melee_hit(player.global_position, CombatHit.new(300, &"camera_test"))
	camera.snap_to_target()
	assert(is_equal_approx(camera.size, 12.9375))
	level.get_node("BossLabController").reset_fight()
	assert(is_equal_approx(camera.size, 12.9375 * 1.22))
	_assert_bodies_visible()
	game.queue_free()
	await process_frame
	print("Boss camera passed: both actors at 9/18 m on either side and room edges, high jump, distant normal follow, smooth transitions, inspection, defeat and reset.")
	quit(0)

func _assert_bodies_visible() -> void:
	for point in [player.global_position + Vector3(-0.4, -0.6, 0),
			player.global_position + Vector3(0.4, 1.0, 0),
			boss.global_position + Vector3(-2.0, 0.15, 0),
			boss.global_position + Vector3(2.0, 3.7, 0)]:
		assert(camera.is_position_in_frustum(point), "Nearby actor clipped: " + str(point))
