extends SceneTree
## Level 5 structure, strict Dash distances, clear silhouettes, and reset policy.

const MAXIMUM_NO_DASH_GAP := 13.65
const AUTHORED_DASH_GAP := 14.08
const OVERLAP_TOLERANCE := 0.01


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"dash")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	for frame in 8:
		await physics_frame

	assert(game_root.current_world_definition.world_id == &"green_zone_regression")
	assert(game_root.current_level_definition.display_number == 5)
	assert(is_equal_approx(level.route_extent.length(), 193.28))
	assert(level.get_node("Platforms").get_child_count() == 8)
	assert(level.get_node("Checkpoints").get_child_count() == 4)
	assert(level.get_node("Hazards").get_child_count() == 0)
	_assert_enemy_flow_placements(level)
	assert(not level.camera.vertical_follow_enabled)
	assert(is_equal_approx(level.camera.look_ahead, 8.0))
	assert((level.get_node("Props/OpeningTree") as Sprite3D).render_priority == 0)
	assert((level.get_node("Props/FinishTree") as Sprite3D).render_priority == 0)
	var opening_fence := level.get_node("Props/OpeningFence") as Sprite3D
	assert(opening_fence.render_priority == 20)
	assert(is_equal_approx(opening_fence.pixel_size, 0.02))
	assert(is_equal_approx(opening_fence.scale.x, 1.828571))
	assert(opening_fence.position.y - 32.0 * opening_fence.pixel_size >= 0.0)
	assert((level.get_node("Props/FinishBench") as Sprite3D).render_priority == 20)
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(not player.has_ability(PlayerAbility.DASH))
	assert(not player.dash_available())
	assert(is_equal_approx(player.movement.dash_speed, 22.0))
	assert(is_equal_approx(player.movement.dash_duration, 0.25))

	var pickup := level.get_node("DashPickup") as AbilityPickup3D
	assert(not pickup.is_claimed())
	var opening := _platform(level, "OpeningGround")
	var pickup_runway := _platform(level, "PickupRunway")
	assert(is_equal_approx(_gap(opening, pickup_runway), 2.56))
	assert(pickup.position.x > _left_edge(pickup_runway))
	assert(_right_edge(pickup_runway) - pickup.position.x >= 17.9)
	var collection_shape := pickup.get_node("CollectionShape") as CollisionShape3D
	var collection_box := collection_shape.shape as BoxShape3D
	assert(collection_box.size.y >= 6.4, "The new ability must not be jump-skippable.")

	var dash_route: Array[PixelPlatform3D] = [
		pickup_runway,
		_platform(level, "FirstDashLanding"),
		_platform(level, "RisingDashLanding"),
		_platform(level, "MidBreather"),
		_platform(level, "HighDashLanding"),
		_platform(level, "DescentLanding"),
		_platform(level, "FinishGround"),
	]
	for index in range(dash_route.size() - 1):
		var authored_gap := _gap(dash_route[index], dash_route[index + 1])
		assert(is_equal_approx(authored_gap, AUTHORED_DASH_GAP))
		assert(
			authored_gap > MAXIMUM_NO_DASH_GAP,
			"Every post-pickup crossing must genuinely require Dash."
		)
		assert(
			dash_route[index + 1].size.x >= 10.2,
			"Dash landings must remain broad enough to be fair."
		)

	assert(is_equal_approx(_top_edge(dash_route[0]), 0.0))
	assert(is_equal_approx(_top_edge(dash_route[1]), 0.0))
	assert(is_equal_approx(_top_edge(dash_route[2]), 1.28))
	assert(is_equal_approx(_top_edge(dash_route[3]), 0.0))
	assert(is_equal_approx(_top_edge(dash_route[4]), 2.56))
	assert(is_equal_approx(_top_edge(dash_route[5]), 1.28))
	assert(is_equal_approx(_top_edge(dash_route[6]), 0.0))
	_assert_no_floating_platform_has_playable_ground_below(level)
	_assert_checkpoint_supports(level)

	assert(level.unlock_ability(PlayerAbility.DASH))
	assert(player.has_ability(PlayerAbility.DASH))
	assert(player.dash_available())
	assert(pickup.is_claimed())
	player._try_start_dash(1.0)
	assert(player.is_dashing())
	assert(player.horizontal_speed >= 21.5)
	assert(not player.dash_available())

	level._reset_run()
	await process_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(player.has_ability(PlayerAbility.DASH))
	assert(player.dash_available())
	assert(pickup.is_claimed())
	assert(not (level.get_node("FirstFlowPatrol") as StompableEnemy3D).is_defeated())
	assert(not (level.get_node("MidFlowPatrol") as StompableEnemy3D).is_defeated())
	assert(not (level.get_node("FinishFlowPatrol") as StompableEnemy3D).is_defeated())

	print("Level 5 strict Dash route, silhouette, and reset validation passed.")
	quit(0)


func _assert_no_floating_platform_has_playable_ground_below(
	level: LevelSession3D
) -> void:
	var platforms := level.get_node("Platforms").get_children()
	for first_index in range(platforms.size()):
		var first := platforms[first_index] as PixelPlatform3D
		for second_index in range(first_index + 1, platforms.size()):
			var second := platforms[second_index] as PixelPlatform3D
			var overlap_left := maxf(_left_edge(first), _left_edge(second))
			var overlap_right := minf(_right_edge(first), _right_edge(second))
			if overlap_right - overlap_left <= OVERLAP_TOLERANCE:
				continue
			if absf(_top_edge(first) - _top_edge(second)) <= OVERLAP_TOLERANCE:
				continue
			var upper := first if _top_edge(first) > _top_edge(second) else second
			var lower := second if upper == first else first
			var air_gap := _bottom_edge(upper) - _top_edge(lower)
			assert(
				air_gap <= OVERLAP_TOLERANCE,
				(
					"%s floats above %s over x %.2f..%.2f with a %.2f m air gap."
					% [
						upper.name,
						lower.name,
						overlap_left,
						overlap_right,
						air_gap,
					]
				)
			)


func _assert_checkpoint_supports(level: LevelSession3D) -> void:
	var supports := {
		"CheckpointDashReady": _platform(level, "PickupRunway"),
		"CheckpointMid": _platform(level, "MidBreather"),
		"CheckpointHigh": _platform(level, "HighDashLanding"),
		"CheckpointDescent": _platform(level, "DescentLanding"),
	}
	for checkpoint_name in supports:
		var checkpoint := level.get_node(
			"Checkpoints/%s" % checkpoint_name
		) as LevelCheckpoint3D
		var support: PixelPlatform3D = supports[checkpoint_name]
		assert(is_equal_approx(checkpoint.position.y, _top_edge(support)))
		assert(checkpoint.position.x >= _left_edge(support) + 2.4)
		assert(checkpoint.position.x <= _right_edge(support) - 2.4)


func _assert_enemy_flow_placements(level: LevelSession3D) -> void:
	var level_enemy_count := 0
	for node in get_nodes_in_group("melee_target"):
		if level.is_ancestor_of(node):
			level_enemy_count += 1
	assert(level_enemy_count == 3, "Level 5 needs exactly three optional flow encounters.")

	var first := level.get_node("FirstFlowPatrol") as StompableEnemy3D
	_assert_flow_enemy(
		first,
		_platform(level, "FirstDashLanding"),
		49.95,
		"the first natural landing"
	)

	var middle := level.get_node("MidFlowPatrol") as StompableEnemy3D
	var middle_checkpoint := level.get_node(
		"Checkpoints/CheckpointMid"
	) as LevelCheckpoint3D
	_assert_flow_enemy(
		middle,
		_platform(level, "MidBreather"),
		middle_checkpoint.position.x,
		"the middle checkpoint"
	)
	assert(middle.position.x - middle_checkpoint.position.x >= 7.5)

	_assert_flow_enemy(
		level.get_node("FinishFlowPatrol") as StompableEnemy3D,
		_platform(level, "FinishGround"),
		180.43,
		"the final natural landing"
	)


func _assert_flow_enemy(
	enemy: StompableEnemy3D,
	support: PixelPlatform3D,
	safe_entry_x: float,
	entry_description: String
) -> void:
	assert(is_equal_approx(enemy.patrol_speed, 1.2))
	assert(enemy.starts_moving_right)
	assert(enemy.facing_sign() > 0.0)
	assert(absf(enemy.position.y - (_top_edge(support) + 0.42)) <= 0.05)
	assert(
		enemy.position.x - safe_entry_x >= 6.0,
		"%s must begin clear of %s." % [enemy.name, entry_description]
	)
	assert(enemy.position.x >= _left_edge(support) + 6.0)
	assert(enemy.position.x <= _right_edge(support) - 3.0)


func _platform(level: LevelSession3D, node_name: String) -> PixelPlatform3D:
	return level.get_node("Platforms/%s" % node_name) as PixelPlatform3D


func _left_edge(platform: PixelPlatform3D) -> float:
	return platform.position.x - platform.size.x * 0.5


func _right_edge(platform: PixelPlatform3D) -> float:
	return platform.position.x + platform.size.x * 0.5


func _top_edge(platform: PixelPlatform3D) -> float:
	return platform.position.y + platform.size.y * 0.5


func _bottom_edge(platform: PixelPlatform3D) -> float:
	return platform.position.y - platform.size.y * 0.5


func _gap(left: PixelPlatform3D, right: PixelPlatform3D) -> float:
	return _left_edge(right) - _right_edge(left)
