extends SceneTree
## Focused contract for Level 3's approved opening: the parked Level 2 lift
## feeds one continuous ravine crossed by Double Jump, two Dashes, and a
## controlled spike-side landing before the route safely continues.


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
	assert(level.route_extent.route_end_x == 99.84)
	assert(is_equal_approx(level.camera.look_ahead, 4.48))
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

	var lift_shelf := level.get_node("Platforms/LiftShelf") as PixelPlatform3D
	var double_jump_island := (
		level.get_node("Platforms/DoubleJumpIsland") as PixelPlatform3D
	)
	var dash_island_01 := level.get_node("Platforms/DashIsland01") as PixelPlatform3D
	var dash_island_02 := level.get_node("Platforms/DashIsland02") as PixelPlatform3D
	var continuation := (
		level.get_node("Platforms/ContinuationGround") as PixelPlatform3D
	)
	var supports: Array[PixelPlatform3D] = [
		lift_shelf,
		double_jump_island,
		dash_island_01,
		dash_island_02,
		continuation,
	]
	for support in supports:
		assert(support != null)
		assert(is_equal_approx(_top(support), 0.0))
		_assert_support_below(level, Vector3(support.global_position.x, 0.25, 0), support)

	var movement := level.player.movement
	var double_jump_gap := _left(double_jump_island) - _right(lift_shelf)
	assert(double_jump_gap > movement.ideal_full_speed_jump_distance() + 2.0)
	assert(double_jump_gap < movement.ideal_double_jump_distance() - 2.0)
	var first_dash_gap := _left(dash_island_01) - _right(double_jump_island)
	var second_dash_gap := _left(dash_island_02) - _right(dash_island_01)
	for gap in [first_dash_gap, second_dash_gap]:
		assert(gap > movement.ideal_double_jump_distance() + 1.4)
		assert(gap < movement.ideal_double_jump_dash_distance() - 1.5)
	assert(is_equal_approx(first_dash_gap, 14.08))
	assert(is_equal_approx(second_dash_gap, 14.08))

	var spikes := level.get_node("Hazards/FinalLandingSpikes") as PixelSpikeRow3D
	assert(spikes != null)
	assert(is_equal_approx(spikes.global_position.y, _top(dash_island_02)))
	assert(is_equal_approx(spikes.row_width, 7.36))
	var spike_left := spikes.global_position.x - spikes.row_width * 0.5
	var spike_right := spikes.global_position.x + spikes.row_width * 0.5
	assert(is_equal_approx(spike_left, 72.0))
	assert(is_equal_approx(spike_right, _right(dash_island_02)))
	assert(is_equal_approx(spike_left - _left(dash_island_02), 4.16))
	assert(is_equal_approx(_left(continuation), _right(dash_island_02)))
	assert(not dash_island_02.cap_right_edge)
	assert(not continuation.cap_left_edge)

	var patrol := level.get_node("OpeningPatrol") as StompableEnemy3D
	assert(patrol != null)
	assert(patrol.is_on_floor())
	var patrol_bounds := patrol.authored_patrol_bounds_x()
	assert(patrol_bounds.x >= _left(lift_shelf) + 1.28)
	assert(patrol_bounds.y <= _right(lift_shelf) - 1.28 + 0.001)
	var rising_flyer := level.get_node("OpeningFlyerRising") as HoveringHazard3D
	var falling_flyer := level.get_node("OpeningFlyerFalling") as HoveringHazard3D
	assert(rising_flyer != null and falling_flyer != null)
	for flyer in [rising_flyer, falling_flyer]:
		assert((flyer.validation_errors() as PackedStringArray).is_empty())
		assert(flyer.global_position.x > _right(double_jump_island))
		assert(flyer.global_position.x < _left(dash_island_01))
		assert(flyer.lowest_body_y() < _top(double_jump_island))
		assert(flyer.highest_body_y() > _top(double_jump_island) + 6.0)
	assert(is_equal_approx(rising_flyer.bob_phase, 0.0))
	assert(is_equal_approx(falling_flyer.bob_phase, 0.5))
	assert(absf(
		(rising_flyer.global_position.x + falling_flyer.global_position.x) * 0.5
		- (_right(double_jump_island) + _left(dash_island_01)) * 0.5
	) < 0.001)

	var landing_patrol := level.get_node("DashLandingPatrol") as StompableEnemy3D
	assert(landing_patrol != null)
	assert(landing_patrol.is_on_floor())
	var landing_patrol_bounds := landing_patrol.authored_patrol_bounds_x()
	assert(landing_patrol_bounds.x >= _left(dash_island_01) + 1.28)
	assert(landing_patrol_bounds.y <= _right(dash_island_01) - 1.28 + 0.001)

	var checkpoint := level.get_node("Checkpoints/OpeningCheckpoint") as LevelCheckpoint3D
	assert(checkpoint != null)
	assert(checkpoint.route_index == 1)
	assert(checkpoint.global_position.x > _left(continuation) + 2.0)
	assert(not checkpoint.is_activated())
	_assert_sprite_grounded(level.get_node("Props/ContinuationTree") as Sprite3D, 0.0)
	_assert_sprite_grounded(level.get_node("Props/ContinuationBush") as Sprite3D, 0.0)

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(4.0, 0.7, 0)))
	for frame in 120:
		await physics_frame
	assert(level.player.is_on_floor())
	assert(is_equal_approx(float(lift.call("travel_progress")), 1.0))
	assert(not bool(lift.call("is_moving")))
	assert(level.get_node("Hazards").get_child_count() == 1)
	assert(level.get_node("Checkpoints").get_child_count() == 1)
	assert(_owned_group_nodes(level, &"level_goal").is_empty())
	assert(_owned_group_nodes(level, &"level_transition").is_empty())

	print(
		"Level 3 WIP passed: lift recap, Double Jump island, two Dash gaps, "
		+ "paired vertical flyers, landing patrol, joined spike tail, and safe continuation."
	)
	quit(0)


func _left(platform: PixelPlatform3D) -> float:
	return platform.global_position.x - platform.size.x * 0.5


func _right(platform: PixelPlatform3D) -> float:
	return platform.global_position.x + platform.size.x * 0.5


func _top(platform: PixelPlatform3D) -> float:
	return platform.global_position.y + platform.size.y * 0.5


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
