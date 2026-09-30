extends SceneTree
## Actual six-tube firing, mirrored sprite ports, fixed area, boost and steering.
var game: Node
var boss: CharacterBody3D
var player: PlayerCharacter
var controls: Node
var shots: Array[Dictionary] = []
var first_rocket: Node3D

func _init() -> void:
	call_deferred("_run")
	create_timer(30.0).timeout.connect(func():
		printerr("Boss missile ripple validation timed out.")
		quit(1))

func _run() -> void:
	game = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_developer_level(game.developer_level_definitions[4])
	await process_frame
	var level: LevelSession3D = game.current_level
	boss = level.get_node("GreenZoneBoss")
	player = level.player
	controls = level.get_node("BossLabController")
	boss.missile_fired.connect(_record_shot)
	var left_shots: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		controls.test_missile_ripple(side)
		await _frames(12)
		player.set_physics_process(false)
		player.health.reset(1000)
		shots.clear()
		first_rocket = null
		var aim: Vector3 = player.global_position + Vector3.UP * 0.35
		await _until(func(): return boss.state_name() == "SALVO", 90, "Ripple never began.")
		await _frames(4)
		assert(boss.visual.texture.resource_path.ends_with("/Sneer.png"), "Use the authored launcher swivel.")
		assert(shots.is_empty(), "The tubes must settle before releasing rockets.")
		await _until(func(): return shots.size() == 1, 60, "First tube did not fire.")
		var first_direction: Vector3 = first_rocket.travel_direction()
		var first_speed: float = first_rocket.speed
		var first_y: float = first_rocket.global_position.y
		var target: Vector3 = first_rocket.target_position
		# Dodge after commitment. Neither the remaining tube targets nor the
		# in-flight first rocket may follow this new position.
		player.global_position += Vector3(side * 3.0, 5.0, 0)
		await _frames(8)
		assert(is_instance_valid(first_rocket))
		assert(first_rocket.travel_direction().is_equal_approx(first_direction), "Boost must hold the departure angle.")
		assert(first_rocket.global_position.y > first_y and first_rocket.speed > first_speed)
		assert(first_rocket.target_position == target)
		var previous_direction: Vector3 = first_rocket.travel_direction()
		for tick in 30:
			await _frames(1)
			if not is_instance_valid(first_rocket): break
			var direction: Vector3 = first_rocket.travel_direction()
			assert(direction.x * side > 0.0, "Rockets must not loop back.")
			assert(previous_direction.angle_to(direction) <= 2.4 / Engine.physics_ticks_per_second + 0.002,
				"A rocket cannot snap its nose toward the target.")
			previous_direction = direction
		await _until(func(): return shots.size() == 6, 80, "Expected all six tubes.")
		await _until(func(): return boss.state_name() == "RECOVERY", 80, "Ripple never recovered.")
		await _frames(35)
		assert(shots.size() == 6, "One salvo must release exactly six, with no extra recovery shot.")
		var origins := {}
		var targets := {}
		for i in shots.size():
			var shot := shots[i]
			assert(shot.frame == i + 1 and shot.sheet.ends_with("/Attack1.png"), "Release must match its firing frame.")
			assert(shot.flip == (side < 0.0))
			assert(shot.direction.x * side > 0.0 and shot.direction.y > 0.0)
			assert(shot.offset.x * side >= -0.81 and shot.offset.x * side <= 0.01)
			assert(shot.offset.y > 2.5 and shot.offset.y < 3.0 and is_zero_approx(shot.offset.z),
				"Rocket roots must emerge from the visible launcher, on the collision plane.")
			assert(absf(shot.target.x - aim.x) <= 0.76 and is_equal_approx(shot.target.y, aim.y),
				"The complete ripple must keep the original target area.")
			origins[shot.offset] = true
			targets[shot.target] = true
			if i > 0:
				assert(absf(shot.time - shots[i - 1].time - 0.12) <= 0.018, "Ripple cadence must stay even.")
		assert(origins.size() == 6 and targets.size() == 6, "Use all six tube origins and a small spread.")
		assert(shots[5].time - shots[0].time >= 0.58 and shots[5].time - shots[0].time <= 0.62)
		if side < 0.0:
			left_shots = shots.duplicate(true)
		else:
			for i in 6:
				assert(is_equal_approx(shots[i].offset.x, -left_shots[i].offset.x))
				assert(is_equal_approx(shots[i].offset.y, left_shots[i].offset.y))
				assert(is_equal_approx(shots[i].direction.x, -left_shots[i].direction.x))
				assert(is_equal_approx(shots[i].direction.y, left_shots[i].direction.y))
		print("Six-tube ripple verified facing ", side, ": ", shots.map(func(shot): return shot.offset))
	game.queue_free()
	await process_frame
	print("Boss missile ripple passed: six tubes, both directions, synchronized poses, even cadence, boost acceleration, bounded curves and committed spread.")
	quit(0)

func _record_shot(rocket: Node3D) -> void:
	if not is_instance_valid(first_rocket): first_rocket = rocket
	shots.append({"time": boss.phase_time, "offset": rocket.global_position - boss.global_position,
		"target": rocket.target_position, "direction": rocket.travel_direction(),
		"frame": boss.visual.frame, "sheet": boss.visual.texture.resource_path, "flip": boss.visual.flip_h})
	# The rendered rocket's authored nose must follow its world direction.
	var authored_angle: float = PI - rocket.ART_NOSE_ANGLE if rocket.visual.flip_h else rocket.ART_NOSE_ANGLE
	var nose_angle: float = rocket.visual.rotation.z + authored_angle
	assert(absf(angle_difference(nose_angle, atan2(rocket.travel_direction().y, rocket.travel_direction().x))) < 0.001)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _until(condition: Callable, limit: int, message: String) -> void:
	for i in limit:
		if condition.call(): return
		await _frames(1)
	quit(1)
	assert(false, message)
