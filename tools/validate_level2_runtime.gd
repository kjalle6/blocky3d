extends SceneTree
## Level 2 regression: authored route, fair spike contact, checkpoint earning,
## checkpoint persistence across death, and manual full restart.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"gaps_and_spikes")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	for frame in 10:
		await physics_frame

	assert(level.get_node("Platforms").get_child_count() == 22, "Level 2 requires 22 authored platforms.")
	assert(level.get_node("Hazards").get_child_count() == 5, "Level 2 requires five spike rows.")
	assert(level.get_node("Checkpoints").get_child_count() == 4, "Level 2 requires four checkpoints.")
	assert(get_nodes_in_group("melee_target").size() == 6, "Level 2 requires six patrol enemies.")
	assert(level.route_extent.length() > 130.0, "Level 2 route should retain its full course length.")
	_validate_route(level)
	_validate_spike_geometry(level)
	_validate_gap_spike_centering(level)

	var player := level.player
	var checkpoint := level.get_node("Checkpoints/Checkpoint02") as LevelCheckpoint3D
	player.reset_at(Transform3D(Basis.IDENTITY, checkpoint.global_position + Vector3(0, 1.8, 0)))
	player.velocity.y = -1.0
	for frame in 3:
		await physics_frame
	assert(
		level.active_checkpoint_index() == -1,
		"Airborne overlap must not earn a checkpoint."
	)

	player.reset_at(checkpoint.respawn_transform())
	for frame in 14:
		await physics_frame
	assert(level.active_checkpoint_index() == 2, "Stable grounded contact should earn Checkpoint 02.")
	assert(checkpoint.is_activated(), "The earned checkpoint should retain its session state.")

	player.kill()
	for frame in 40:
		await physics_frame
	assert(not player.is_dead(), "Checkpoint death should complete the fast reset.")
	assert(level.active_checkpoint_index() == 2, "Death must preserve the latest earned checkpoint.")
	assert(
		player.global_position.distance_to(checkpoint.respawn_transform().origin) < 0.2,
		"Death should return to the latest checkpoint."
	)

	var spike := level.get_node("Hazards/SpikesRun01") as PixelSpikeRow3D
	player.reset_at(Transform3D(Basis.IDENTITY, spike.global_position + Vector3.UP * 0.7))
	for frame in 3:
		await physics_frame
	assert(player.is_dead(), "Clear foot contact with the spike body should be lethal.")

	level._reset_run()
	await physics_frame
	assert(level.active_checkpoint_index() == -1, "Manual full restart should clear checkpoint progress.")
	assert(
		player.global_position.distance_to(level.spawn_point.global_position) < 0.2,
		"Manual full restart should return to the level entrance."
	)
	for frame in 35:
		await physics_frame

	print("Level 2 route, spikes, checkpoints, and reset validation passed.")
	quit(0)


func _validate_route(level: LevelSession3D) -> void:
	var routes := [
		["GroundStart", "OpeningStep01", "OpeningStep02", "OpeningStep03", "GroundEarly"],
		["GroundGap", "MidStep01", "MidStep02", "MidStep03", "GroundMid",
			"PrecisionStep01", "PrecisionStep02", "PrecisionStep03", "PrecisionStep04",
			"GroundSpikeRun"],
		["GroundSpikeRun", "HazardStep01", "HazardStep02", "HazardStep03",
			"GroundCheckpointIsland", "FinalClimb01", "FinalClimb02", "FinalClimb03"],
	]
	for route in routes:
		for index in route.size() - 1:
			var current := level.get_node("Platforms/%s" % route[index]) as PixelPlatform3D
			var following := level.get_node("Platforms/%s" % route[index + 1]) as PixelPlatform3D
			var current_right := current.global_position.x + current.size.x * 0.5
			var following_left := following.global_position.x - following.size.x * 0.5
			var gap := maxf(0.0, following_left - current_right)
			var current_top := current.global_position.y + current.size.y * 0.5
			var following_top := following.global_position.y + following.size.y * 0.5
			assert(gap <= 3.2, "%s -> %s exceeds the jump gap budget." % [route[index], route[index + 1]])
			assert(
				following_top - current_top <= 2.8,
				"%s -> %s exceeds the jump-rise budget." % [route[index], route[index + 1]]
			)


func _validate_spike_geometry(level: LevelSession3D) -> void:
	for node in level.get_node("Hazards").get_children():
		var spike := node as PixelSpikeRow3D
		assert(spike != null, "Every Level 2 hazard should use the pixel spike contract.")
		var collision := spike.get_node("DamageCollision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		assert(
			is_equal_approx(shape.size.x, spike.row_width * spike.collision_width_ratio),
			"Spike damage width must remain inset from its visible row."
		)
		assert(
			shape.size.y <= spike.spike_height * 0.5,
			"Spike damage should stay in the lower half of the visible art."
		)


func _validate_gap_spike_centering(level: LevelSession3D) -> void:
	var authored_gaps := [
		["GroundEarly", "GroundGap", "SpikesGap01"],
		["GroundGap", "MidStep01", "SpikesGap02"],
		["GroundMid", "PrecisionStep01", "SpikesGap03"],
	]
	for gap in authored_gaps:
		var left := level.get_node("Platforms/%s" % gap[0]) as PixelPlatform3D
		var right := level.get_node("Platforms/%s" % gap[1]) as PixelPlatform3D
		var spikes := level.get_node("Hazards/%s" % gap[2]) as PixelSpikeRow3D
		var left_edge := left.global_position.x + left.size.x * 0.5
		var right_edge := right.global_position.x - right.size.x * 0.5
		var gap_center := (left_edge + right_edge) * 0.5
		assert(
			absf(spikes.global_position.x - gap_center) <= 0.01,
			"%s must remain visually centered between its neighboring platforms." % gap[2]
		)
