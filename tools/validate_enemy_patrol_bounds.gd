extends SceneTree
## Enemy patrol contract: ordinary patrols use their whole support while an
## optional asymmetric authored range can stop a patrol at a nearby hazard.

const LEVEL_ID: StringName = &"arrival_shoreline"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	if packed_scene == null:
		_fail("The application root could not be loaded.")
		return
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_level(LEVEL_ID)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	if level == null:
		_fail("Arrival / Shoreline did not instantiate.")
		return
	# The small-platform enemy has no artificial lane and must make visible use
	# of the platform before its normal ledge sensor reverses it.
	var natural_enemy := level.get_node("AerialDipPatrol") as StompableEnemy3D
	if natural_enemy.patrol_left_distance > 0.0 or natural_enemy.patrol_right_distance > 0.0:
		_fail("The small-platform patrol still has an artificial range.")
		return
	var natural_minimum_x := natural_enemy.global_position.x
	var natural_maximum_x := natural_enemy.global_position.x
	var natural_direction_changes := 0
	var natural_previous_direction := natural_enemy.facing_sign()

	# Keep the player far enough away that both are pure patrol tests rather
	# than attack-state tests.
	level.player.set_developer_inspection_enabled(true)
	level.player.global_position = Vector3(170.2, 5.0, 0.0)
	for frame in 360:
		await physics_frame
		natural_minimum_x = minf(natural_minimum_x, natural_enemy.global_position.x)
		natural_maximum_x = maxf(natural_maximum_x, natural_enemy.global_position.x)
		if natural_enemy.facing_sign() != natural_previous_direction:
			natural_direction_changes += 1
			natural_previous_direction = natural_enemy.facing_sign()
	if natural_direction_changes < 2:
		_fail("The small-platform patrol did not naturally reverse at both ledges.")
		return
	if natural_maximum_x - natural_minimum_x < 2.0:
		_fail("The small-platform patrol still paces in an artificially narrow space.")
		return

	var enemy := level.get_node("AerialLandingPatrol") as StompableEnemy3D
	var authored_bounds := enemy.authored_patrol_bounds_x()
	var minimum_x := authored_bounds.x
	var maximum_x := authored_bounds.y
	var observed_minimum_x := enemy.global_position.x
	var observed_maximum_x := enemy.global_position.x
	var previous_x := enemy.global_position.x
	var direction_changes := 0
	var previous_direction := enemy.facing_sign()

	# Accelerate this isolated test so it can prove the complete 15.6 m route
	# without making the validation suite wait for a real-time traversal.
	enemy.patrol_speed = 8.5
	for frame in 300:
		await physics_frame
		observed_minimum_x = minf(observed_minimum_x, enemy.global_position.x)
		observed_maximum_x = maxf(observed_maximum_x, enemy.global_position.x)
		if enemy.facing_sign() != previous_direction:
			direction_changes += 1
			previous_direction = enemy.facing_sign()
		var step_distance := absf(enemy.global_position.x - previous_x)
		if step_distance > enemy.patrol_speed * 0.04:
			_fail("The bounded patrol teleported instead of moving normally.")
			return
		previous_x = enemy.global_position.x

	var accelerated_frame_tolerance := 0.18
	if observed_minimum_x < minimum_x - accelerated_frame_tolerance:
		_fail(
			"The bounded patrol crossed its authored left limit: %.3f < %.3f."
			% [observed_minimum_x, minimum_x]
		)
		return
	if observed_maximum_x > maximum_x + accelerated_frame_tolerance:
		_fail(
			"The bounded patrol crossed its authored right limit: %.3f > %.3f."
			% [observed_maximum_x, maximum_x]
		)
		return
	if direction_changes < 2:
		_fail("The bounded patrol did not traverse and reverse across its lane.")
		return
	if observed_maximum_x - observed_minimum_x < (maximum_x - minimum_x) * 0.9:
		_fail("The bounded patrol did not use most of its authored lane.")
		return
	enemy.reset_run()
	var authored_origin_x := minimum_x + enemy.patrol_left_distance
	if absf(enemy.global_position.x - authored_origin_x) > 0.001:
		_fail("Reset did not return the bounded patrol to its authored origin.")
		return
	if enemy.facing_sign() >= 0.0:
		_fail("Reset did not restore the bounded patrol's authored start direction.")
		return

	# Either authored side may be used independently. A zero right distance must
	# keep natural wall/ledge patrol active instead of becoming a limit at spawn.
	enemy.patrol_left_distance = 2.0
	enemy.patrol_right_distance = 0.0
	enemy.starts_moving_right = true
	enemy.reset_run()
	var one_sided_origin_x := enemy.global_position.x
	var one_sided_maximum_x := one_sided_origin_x
	for frame in 30:
		await physics_frame
		one_sided_maximum_x = maxf(one_sided_maximum_x, enemy.global_position.x)
	if one_sided_maximum_x <= one_sided_origin_x + 1.0:
		_fail("A disabled right limit prevented the one-sided patrol roaming naturally.")
		return
	print("Reusable natural, bounded, and one-sided enemy patrol validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
