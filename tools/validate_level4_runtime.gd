extends SceneTree
## Level 4 structure, entry policy, pickup, Wall Jump, camera, and reset checks.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"wall_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	for frame in 8:
		await physics_frame

	assert(game_root.current_world_definition.world_id == &"green_zone")
	assert(game_root.current_level_definition.display_number == 4)
	assert(level.route_extent.length() == 84.0)
	assert(level.get_node("Platforms").get_child_count() == 14)
	assert(level.get_node("Checkpoints").get_child_count() == 3)
	assert(level.get_node("Hazards").get_child_count() == 0)
	assert(level.camera.vertical_follow_enabled)
	assert(level.camera.maximum_vertical_offset == 14.5)
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not player.has_ability(PlayerAbility.WALL_JUMP))
	var pickup := level.get_node("WallJumpPickup") as AbilityPickup3D
	assert(not pickup.is_claimed())
	assert(level.unlock_ability(PlayerAbility.WALL_JUMP))
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(pickup.is_claimed())

	var performed_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.WALL_JUMP:
				performed_count[0] += 1
	)
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(5.2, 4.2, 0)))
	player.velocity.y = -7.0
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if player.is_wall_sliding():
			break
	assert(player.is_wall_sliding(), "The introduction shaft must support wall sliding.")
	for frame in 8:
		await physics_frame
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	assert(performed_count[0] == 1)
	assert(player.horizontal_speed < -9.0)
	Input.action_release("jump")
	Input.action_release("move_right")

	level._reset_run()
	await process_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(pickup.is_claimed())

	print("Level 4 structure, Wall Jump, camera, and reset validation passed.")
	quit(0)
