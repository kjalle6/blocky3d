extends SceneTree
## Focused contract for the first Level 3 blockout: the run begins on the
## parked Level 2 construction lift and continues onto a simple night run-up.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := load(
		"res://resources/dev/green_zone_finale_wip.tres"
	) as LevelDefinition
	assert(definition != null)
	assert(definition.validation_errors().is_empty())
	assert(definition.level_id == &"dev_green_zone_finale_wip")
	assert(definition.assumed_owned_abilities == PlayerAbility.IMPLEMENTED)

	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	assert(game_root.campaign.find_by_id(definition.level_id) == null)
	assert(
		game_root.campaign.find_world_by_id(&"green_zone").ordered_levels().size()
		== 2
	)

	game_root.load_developer_level(definition)
	for frame in 8:
		await physics_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	assert(level.name == "DeveloperGreenZoneFinaleWip")
	assert(game_root.current_world_definition == null)
	assert(level.route_extent.route_start_x == 0.0)
	assert(level.route_extent.route_end_x == 38.4)
	assert(level.background.profile.profile_id == &"green_zone_night")
	assert(level.background.runtime_layer_count() == 6)
	for ability_id in PlayerAbility.IMPLEMENTED:
		assert(level.player.has_ability(ability_id))

	var lift := level.get_node("Props/LevelStartLift") as Node3D
	assert(lift != null)
	assert((lift.call("validation_errors") as PackedStringArray).is_empty())
	assert(bool(lift.get("starts_at_top")))
	assert(not bool(lift.get("trigger_on_boarding")))
	assert(not bool(lift.get("return_from_top_when_empty")))
	assert(lift.get("exit_goal_path") == NodePath())
	var shaft_backdrop := lift.get_node("ShaftBackdrop") as MeshInstance3D
	assert(shaft_backdrop != null)
	assert(not shaft_backdrop.visible)
	assert(is_equal_approx(float(lift.call("travel_progress")), 1.0))
	assert(not bool(lift.call("is_moving")))
	var carriage := lift.get_node("Carriage") as AnimatableBody3D
	assert(carriage != null)
	assert(is_equal_approx(carriage.global_position.y, 0.0))
	assert(level.player.is_on_floor())
	assert(is_equal_approx(level.player.global_position.x, carriage.global_position.x))
	var player_shape := (
		level.player.get_node("CollisionShape3D") as CollisionShape3D
	).shape as BoxShape3D
	assert(player_shape != null)
	assert(absf(
		level.player.global_position.y
		- (carriage.global_position.y + player_shape.size.y * 0.5)
	) < 0.05)
	_assert_support_below(level, Vector3(4.0, 0.25, 0), carriage)

	var run_up := level.get_node("Platforms/RunUpGround") as StaticBody3D
	assert(run_up != null)
	_assert_support_below(level, Vector3(8.0, 0.25, 0), run_up)
	_assert_sprite_grounded(level.get_node("Props/RunUpTree") as Sprite3D, 0.0)
	_assert_sprite_grounded(level.get_node("Props/RunUpBush") as Sprite3D, 0.0)
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(8.0, 0.7, 0)))
	for frame in 120:
		await physics_frame
	assert(level.player.is_on_floor())
	assert(is_equal_approx(float(lift.call("travel_progress")), 1.0))
	assert(not bool(lift.call("is_moving")))
	assert(level.get_node("Hazards").get_child_count() == 0)
	assert(_owned_group_nodes(level, &"level_goal").is_empty())
	assert(_owned_group_nodes(level, &"level_transition").is_empty())

	print("Level 3 WIP passed: parked lift-top spawn and basic night run-up.")
	quit(0)


func _assert_support_below(
	level: LevelSession3D,
	from: Vector3,
	expected_collider: CollisionObject3D
) -> void:
	var query := PhysicsRayQueryParameters3D.create(
		from,
		from + Vector3(0, -0.75, 0),
		1
	)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	assert(hit.get("collider") == expected_collider)


func _assert_sprite_grounded(sprite: Sprite3D, support_y: float) -> void:
	assert(sprite != null)
	assert(sprite.texture != null)
	var half_height := (
		float(sprite.texture.get_height())
		* sprite.pixel_size
		* absf(sprite.scale.y)
		* 0.5
	)
	assert(absf(sprite.global_position.y - half_height - support_y) < 0.001)


func _owned_group_nodes(level: LevelSession3D, group: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in get_nodes_in_group(group):
		if level.is_ancestor_of(node):
			found.append(node)
	return found
