extends SceneTree
## Focused contract for Level 3's approved opening and first mastery turn: the
## parked Level 2 lift feeds one continuous ravine, then a deceptively narrow
## impossible gap drops safely into one short deep-cave encounter before a long,
## hazard-free Wall Jump shaft returns to the night forest.

var _completed := false


func _init() -> void:
	create_timer(20.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Level 3 WIP validation aborted before completing.")
	quit(1)


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
	assert(level.route_extent.route_end_x == 171.52)
	assert(is_equal_approx(level.camera.look_ahead, 4.48))
	assert(is_equal_approx(level.camera.maximum_center_x, 160.0))
	assert(level.background.profile.profile_id == &"green_zone_night")
	assert(level.background.runtime_layer_count() == 7)
	for background_index in 6:
		var forest_layer := level.background.profile.layers[background_index]
		assert(forest_layer.zone_tag.is_empty())
		assert(not forest_layer.invert_zone_visibility)
		assert(forest_layer.vertical_policy == 2)
		assert(is_equal_approx(level.background.zone_opacity_at(
			forest_layer,
			Vector3(139.52, -25.6, 0)
		), 1.0))
	var cave_layer := level.background.profile.layers[6]
	assert(cave_layer.zone_tag.is_empty())
	assert(not cave_layer.invert_zone_visibility)
	assert(cave_layer.texture.resource_path.ends_with(
		"/cave_depth/cave_composite.png"
	))
	assert(cave_layer.pixel_scale == 3)
	assert(is_equal_approx(cave_layer.horizontal_parallax, 0.08))
	assert(cave_layer.vertical_policy == 2)
	assert(cave_layer.world_repeat_below == 0)
	assert(cave_layer.world_repeat_above == 0)
	assert(is_equal_approx(cave_layer.offset_pixels.y, -486.0))
	assert(cave_layer.tint.is_equal_approx(
		Color(0.62, 0.69, 0.86, 1)
	))
	assert(is_equal_approx(level.background.zone_opacity_at(
		cave_layer,
		Vector3(139.52, -25.6, 0)
	), 1.0))
	var initial_camera_y := 2.7
	var cave_panel_height := (
		cave_layer.texture.get_height()
		* level.background.profile.pixel_size
		* float(cave_layer.pixel_scale)
	)
	var cave_boundary_y := (
		initial_camera_y
		+ cave_layer.offset_pixels.y * level.background.profile.pixel_size
		+ cave_panel_height * 0.5
	)
	var forest_panel_height := (
		level.background.profile.layers[0].texture.get_height()
		* level.background.profile.pixel_size
	)
	var forest_boundary_y := initial_camera_y - forest_panel_height * 0.5
	assert(is_equal_approx(forest_boundary_y, -3.78))
	assert(is_equal_approx(cave_boundary_y, forest_boundary_y))
	assert(is_equal_approx(cave_boundary_y - cave_panel_height, -29.7))
	var night_environment := (
		level.get_node("WorldEnvironment") as WorldEnvironment
	).environment
	assert(night_environment != null)
	assert(night_environment.background_color.is_equal_approx(
		Color(0.002, 0.003, 0.008, 1)
	))
	assert(is_equal_approx(level.player.fall_limit_y, -31.0))
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
	var deceptive_takeoff := (
		level.get_node("Platforms/DeceptiveTakeoffGround") as PixelPlatform3D
	)
	var far_side_surface := (
		level.get_node("Platforms/FarSideSurface") as PixelPlatform3D
	)
	var upper_continuation := (
		level.get_node("Platforms/UpperContinuationGround") as PixelPlatform3D
	)
	var supports: Array[PixelPlatform3D] = [
		lift_shelf,
		double_jump_island,
		dash_island_01,
		dash_island_02,
		continuation,
		deceptive_takeoff,
		far_side_surface,
		upper_continuation,
	]
	for support in supports:
		assert(support != null)
		assert(not support.cap_bottom_edge)
		assert(is_equal_approx(_top(support), 0.0))
		_assert_support_below(level, Vector3(support.global_position.x, 0.25, 0), support)
		var deep_bottom_tile := support.get_node("Tile_04_01") as Sprite3D
		assert(deep_bottom_tile.texture == support.style.deep)

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
	assert(is_equal_approx(_left(deceptive_takeoff), _right(continuation)))
	assert(not continuation.cap_right_edge)
	assert(not deceptive_takeoff.cap_left_edge)
	var deceptive_gap := _left(far_side_surface) - _right(deceptive_takeoff)
	assert(is_equal_approx(deceptive_gap, 20.48))
	assert(deceptive_gap > movement.ideal_double_jump_dash_distance() + 2.5)
	assert(deceptive_gap < movement.ideal_double_jump_dash_distance() + 4.0)

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

	var deep_terrain := (
		level.get_node("Platforms/DeepRockShell") as PixelInteriorTerrain3D
	)
	assert(deep_terrain != null)
	assert(deep_terrain.validation_errors().is_empty())
	assert(deep_terrain.row_count() == 23)
	assert(deep_terrain.column_count() == 50)
	# The right shaft wall joins the floor, so the greedy collision builder
	# claims that column first and splits the remaining floor into two pieces.
	assert(deep_terrain.collision_rectangle_count() == 4)
	# The deceptive gap remains visually open all the way down; its former
	# hanging far face is deliberately absent.
	for row in 20:
		assert(not deep_terrain.is_solid_cell(row, 18))
	# The 5.12 m two-face shaft preserves the proven Level 2 Wall Jump rhythm.
	for row in 5:
		assert(not deep_terrain.is_solid_cell(row, 36))
		assert(not deep_terrain.is_solid_cell(row, 41))
	assert(deep_terrain.is_solid_cell(5, 36))
	assert(deep_terrain.is_solid_cell(5, 41))
	assert(deep_terrain.left_face_overrides == PackedVector2Array([Vector2(41, 5)]))
	assert(deep_terrain.right_face_overrides.size() == 13)
	for row in range(5, 18):
		assert(deep_terrain.right_face_overrides.has(Vector2(36, row)))
		var left_shaft_wall_tile := (
			deep_terrain.get_node("Tile_%02d_36" % row) as Sprite3D
		)
		assert(left_shaft_wall_tile.texture == deep_terrain.style.right)
	var left_shaft_attachment := deep_terrain.get_node("Tile_05_36") as Sprite3D
	var right_shaft_attachment := deep_terrain.get_node("Tile_05_41") as Sprite3D
	assert(left_shaft_attachment.texture == deep_terrain.style.right)
	assert(right_shaft_attachment.texture == deep_terrain.style.left)
	assert(deep_terrain.top_face_overrides == PackedVector2Array([
		Vector2(41, 20),
	]))
	var right_floor_junction := deep_terrain.get_node("Tile_20_41") as Sprite3D
	assert(right_floor_junction.texture == deep_terrain.style.top)
	var left_green_attachment := far_side_surface.get_node("Tile_04_18") as Sprite3D
	var right_green_attachment := (
		upper_continuation.get_node("Tile_04_00") as Sprite3D
	)
	assert(left_green_attachment.texture == far_side_surface.style.deep_right)
	assert(right_green_attachment.texture == upper_continuation.style.deep_left)
	assert(is_zero_approx(left_green_attachment.rotation.z))
	assert(is_zero_approx(right_green_attachment.rotation.z))
	assert(deep_terrain.is_solid_cell(17, 36))
	assert(not deep_terrain.is_solid_cell(18, 36))
	assert(deep_terrain.is_solid_cell(19, 41))
	for column in deep_terrain.column_count():
		var expected_deep_floor := column >= 3
		assert(deep_terrain.is_solid_cell(20, column) == expected_deep_floor)
		assert(deep_terrain.is_solid_cell(21, column) == expected_deep_floor)
		assert(deep_terrain.is_solid_cell(22, column) == expected_deep_floor)
	var deep_floor_left_x := (
		deep_terrain.global_position.x
		+ 3.0 * PixelInteriorTerrain3D.TILE_WORLD_SIZE
	)
	assert(is_equal_approx(deep_floor_left_x, 111.36))
	assert(
		is_equal_approx(
			deep_floor_left_x - _right(deceptive_takeoff),
			PixelInteriorTerrain3D.TILE_WORLD_SIZE
		)
	)
	var shaft_left_inner_x := (
		deep_terrain.global_position.x
		+ 37.0 * PixelInteriorTerrain3D.TILE_WORLD_SIZE
	)
	var shaft_right_inner_x := (
		deep_terrain.global_position.x
		+ 41.0 * PixelInteriorTerrain3D.TILE_WORLD_SIZE
	)
	assert(is_equal_approx(shaft_right_inner_x - shaft_left_inner_x, 5.12))
	assert(is_equal_approx(far_side_surface.size.x, 24.32))
	assert(is_equal_approx(upper_continuation.size.x, 11.52))
	assert(is_equal_approx(_right(far_side_surface), shaft_left_inner_x))
	assert(is_equal_approx(_left(upper_continuation), shaft_right_inner_x))
	_assert_support_below(
		level,
		Vector3(127.0, -25.35, 0),
		deep_terrain
	)
	_assert_wall(
		level,
		Vector3(156.0, -12.0, 0),
		Vector3.LEFT * 2.0,
		deep_terrain
	)
	_assert_wall(
		level,
		Vector3(159.0, -12.0, 0),
		Vector3.RIGHT * 2.0,
		deep_terrain
	)

	var deep_spikes := level.get_node("Hazards/DeepRunSpikes") as PixelSpikeRow3D
	assert(deep_spikes != null)
	assert(is_equal_approx(deep_spikes.global_position.y, -25.6))
	assert(is_equal_approx(deep_spikes.row_width, 5.12))
	var deep_spike_left := deep_spikes.global_position.x - deep_spikes.row_width * 0.5
	var deep_spike_right := deep_spikes.global_position.x + deep_spikes.row_width * 0.5
	assert(is_equal_approx(deep_spike_left, 143.36))
	assert(is_equal_approx(deep_spike_right, 148.48))
	assert(deep_spike_right < shaft_left_inner_x)

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
		assert(is_zero_approx(flyer.horizontal_amplitude))
		assert(is_zero_approx(flyer.horizontal_patrol_period()))
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
	var runup_patrol := level.get_node("RunupPatrol") as StompableEnemy3D
	assert(runup_patrol != null)
	assert(runup_patrol.is_on_floor())
	# The ground patrol owns the complete safe runway. Its only authored turn is
	# just beyond the spike art, because spikes are hazards rather than walls;
	# the zero right distance leaves the real gap ledge in charge of that turn.
	var runup_patrol_bounds := runup_patrol.authored_patrol_bounds_x()
	assert(is_equal_approx(runup_patrol.patrol_left_distance, 11.44))
	assert(is_zero_approx(runup_patrol.patrol_right_distance))
	assert(is_equal_approx(runup_patrol_bounds.x, 80.08))
	assert(is_equal_approx(runup_patrol_bounds.x - spike_right, 0.72))
	var runup_flyer := level.get_node("RunupFlyer") as HoveringHazard3D
	assert(runup_flyer != null)
	assert((runup_flyer.validation_errors() as PackedStringArray).is_empty())
	assert(is_equal_approx(runup_flyer.bob_amplitude, 0.64))
	assert(is_equal_approx(runup_flyer.lowest_body_y(), 1.92))
	assert(is_equal_approx(runup_flyer.highest_body_y(), 3.2))
	assert(is_equal_approx(runup_flyer.horizontal_amplitude, 20.4))
	assert(is_equal_approx(runup_flyer.horizontal_speed, 4.0))
	assert(is_equal_approx(runup_flyer.horizontal_phase, 0.25))
	assert(is_equal_approx(runup_flyer.horizontal_patrol_period(), 20.4))
	assert(runup_flyer.horizontal_speed > runup_patrol.patrol_speed)
	assert(is_equal_approx(runup_flyer.leftmost_body_x(), 68.56))
	assert(is_equal_approx(runup_flyer.rightmost_body_x(), 109.36))
	assert(is_equal_approx(
		runup_flyer.leftmost_body_x() - _left(dash_island_02),
		0.72
	))
	assert(runup_flyer.leftmost_body_x() < spike_left)
	assert(is_equal_approx(
		(runup_flyer.leftmost_body_x() + runup_flyer.rightmost_body_x()) * 0.5,
		88.96
	))
	assert(runup_flyer.global_position.x >= runup_flyer.leftmost_body_x())
	assert(runup_flyer.global_position.x <= runup_flyer.rightmost_body_x())
	assert(is_equal_approx(
		_right(deceptive_takeoff) - runup_flyer.rightmost_body_x(),
		0.72
	))
	runup_flyer.reset_run()
	assert(is_equal_approx(runup_flyer.global_position.x, 88.96))
	assert(is_equal_approx(runup_flyer.global_position.y, 3.2))
	var deep_patrol := level.get_node("DeepRunPatrol") as StompableEnemy3D
	assert(deep_patrol != null)
	assert(deep_patrol.is_on_floor())
	var deep_patrol_bounds := deep_patrol.authored_patrol_bounds_x()
	assert(deep_patrol_bounds.is_equal_approx(Vector2(134.4, 140.8)))
	assert(deep_patrol_bounds.y < deep_spike_left)

	var checkpoint := level.get_node("Checkpoints/OpeningCheckpoint") as LevelCheckpoint3D
	assert(checkpoint != null)
	assert(checkpoint.route_index == 1)
	assert(checkpoint.global_position.x > _left(continuation) + 2.0)
	assert(not checkpoint.is_activated())
	var deep_checkpoint := (
		level.get_node("Checkpoints/DeepLandingCheckpoint") as LevelCheckpoint3D
	)
	var exit_checkpoint := (
		level.get_node("Checkpoints/WallJumpExitCheckpoint") as LevelCheckpoint3D
	)
	assert(deep_checkpoint != null and exit_checkpoint != null)
	assert(deep_checkpoint.route_index == 2)
	assert(deep_checkpoint.global_position.is_equal_approx(
		Vector3(132.48, -25.6, 0)
	))
	assert(exit_checkpoint.route_index == 3)
	assert(exit_checkpoint.global_position.is_equal_approx(Vector3(165.12, 0, 0)))
	assert(not deep_checkpoint.is_activated())
	assert(not exit_checkpoint.is_activated())

	var deep_camera_region := level.get_node(
		"DeepRouteCameraRegion"
	) as VerticalCameraRegion3D
	assert(deep_camera_region != null)
	assert(deep_camera_region.validation_errors().is_empty())
	assert(deep_camera_region.position.is_equal_approx(Vector3(139.52, -14.72, 0)))
	assert(deep_camera_region.size.is_equal_approx(Vector2(64.0, 29.44)))
	assert(is_equal_approx(deep_camera_region.vertical_anchor_world_y(), 0.7))
	assert(is_equal_approx(deep_camera_region.minimum_vertical_offset, -25.6))
	assert(is_equal_approx(deep_camera_region.maximum_vertical_offset, 0.0))
	assert(not deep_camera_region.contains_world_position(Vector3(110.0, 0.7, 0)))
	assert(deep_camera_region.contains_world_position(Vector3(120.0, -0.1, 0)))
	assert(deep_camera_region.contains_world_position(Vector3(132.48, -24.9, 0)))
	var wall_focus := level.get_node("WallJumpCameraFocus") as VerticalCameraRegion3D
	assert(wall_focus != null)
	assert(wall_focus.validation_errors().is_empty())
	assert(not wall_focus.vertical_framing_enabled)
	assert(wall_focus.horizontal_focus_enabled)
	assert(wall_focus.priority > deep_camera_region.priority)
	assert(wall_focus.position.is_equal_approx(Vector3(157.44, -12.8, 0)))
	assert(wall_focus.size.is_equal_approx(Vector2(5.12, 25.6)))
	assert(is_equal_approx(wall_focus.horizontal_focus_world_x(), 157.44))
	assert(wall_focus.contains_world_position(Vector3(155.2, -24.9, 0)))
	assert(wall_focus.contains_world_position(Vector3(159.6, -0.1, 0)))
	assert(not wall_focus.contains_world_position(Vector3(153.6, -12.8, 0)))
	var bottom_hold := level.get_node("BottomCameraHold") as VerticalCameraRegion3D
	assert(bottom_hold != null)
	assert(bottom_hold.validation_errors().is_empty())
	assert(bottom_hold.vertical_framing_enabled)
	assert(not bottom_hold.horizontal_focus_enabled)
	assert(bottom_hold.priority > deep_camera_region.priority)
	assert(bottom_hold.position.is_equal_approx(Vector3(143.36, -23.68, 0)))
	assert(bottom_hold.size.is_equal_approx(Vector2(23.04, 3.84)))
	assert(is_equal_approx(bottom_hold.minimum_vertical_offset, -25.6))
	assert(is_equal_approx(bottom_hold.maximum_vertical_offset, -25.6))
	assert(bottom_hold.contains_world_position(Vector3(132.48, -24.9, 0)))
	assert(bottom_hold.contains_world_position(Vector3(154.8, -24.9, 0)))
	assert(not bottom_hold.contains_world_position(Vector3(143.36, -20.0, 0)))

	var surface_region := level.get_node(
		"SurfaceBackgroundRegion"
	) as PixelBackgroundRegion3D
	assert(surface_region != null)
	assert(surface_region.validation_errors().is_empty())
	assert(surface_region.position.is_equal_approx(Vector3(85.76, 2.7, 0)))
	assert(surface_region.size.is_equal_approx(Vector2(180.0, 8.0)))
	assert(surface_region.shows_zone(&"surface"))
	assert(is_equal_approx(surface_region.weight_at(Vector3(4.0, 0.0, 0)), 1.0))
	assert(is_equal_approx(surface_region.weight_at(Vector3(139.52, 0.0, 0)), 1.0))
	assert(is_equal_approx(surface_region.weight_at(Vector3(139.52, -5.3, 0)), 0.5))
	assert(is_zero_approx(surface_region.weight_at(Vector3(139.52, -25.6, 0))))
	assert(is_equal_approx(
		level.background.zone_weight_at(&"surface", Vector3(139.52, 0.0, 0)),
		1.0
	))
	assert(is_zero_approx(
		level.background.zone_weight_at(&"surface", Vector3(139.52, -25.6, 0))
	))
	var deep_grade := level.get_node("DeepRegionGrade") as PixelRegionGrade3D
	assert(deep_grade != null)
	assert(deep_grade.validation_errors().is_empty())
	assert(deep_grade.zone_tag == &"surface")
	assert(is_equal_approx(deep_grade.dark_brightness, 0.56))
	assert(is_equal_approx(deep_grade.dark_saturation, 0.62))
	assert(is_equal_approx(deep_grade.dark_contrast, 1.08))
	assert(is_equal_approx(deep_grade.lit_brightness, 0.82))
	assert(is_equal_approx(deep_grade.lit_saturation, 0.76))
	assert(is_equal_approx(deep_grade.lit_contrast, 1.05))
	_assert_sprite_grounded(level.get_node("Props/ContinuationTree") as Sprite3D, 0.0)
	_assert_sprite_grounded(level.get_node("Props/ContinuationBush") as Sprite3D, 0.0)

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(4.0, 0.7, 0)))
	for frame in 120:
		await physics_frame
	assert(level.player.is_on_floor())
	assert(is_equal_approx(float(lift.call("travel_progress")), 1.0))
	assert(not bool(lift.call("is_moving")))

	# The deep route needs a low global death boundary, but misses in the opening
	# ravine must retain the original quick reset instead of falling 25.6 m.
	for opening_gap_x in [21.12, 40.32, 60.8]:
		level.player.reset_at(
			Transform3D(Basis.IDENTITY, Vector3(opening_gap_x, 0.7, 0))
		)
		var opening_death_frame := -1
		for frame in 60:
			await physics_frame
			if level.player.is_dead():
				opening_death_frame = frame + 1
				break
		assert(opening_death_frame > 0)
		assert(opening_death_frame < 55)
		for frame in 60:
			await physics_frame
			if not level.player.is_dead():
				break
		assert(not level.player.is_dead())

	# Missing the deceptive jump is forward progress, not a death. Prove the
	# player can fall the full authored height onto the rock floor without ever
	# crossing either the player fall limit or the physical kill plane.
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(127.0, 0.7, 0)))
	for frame in 120:
		await physics_frame
	assert(not level.player.is_dead())
	assert(level.player.is_on_floor())
	assert(absf(level.player.feet_world_y() - -25.6) < 0.05)
	assert(not deep_checkpoint.is_activated())
	level.player.reset_at(
		Transform3D(Basis.IDENTITY, Vector3(132.48, -24.9, 0))
	)
	for frame in 20:
		await physics_frame
	assert(level.player.is_on_floor())
	assert(deep_checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 2)

	var kill_plane := level.get_node("KillPlane") as Area3D
	assert(kill_plane != null)
	assert(is_equal_approx(kill_plane.global_position.x, 85.76))
	assert(is_equal_approx(kill_plane.global_position.y, -32.0))
	var kill_shape := (
		kill_plane.get_node("Collision") as CollisionShape3D
	).shape as BoxShape3D
	assert(kill_shape != null)
	assert(is_equal_approx(kill_shape.size.x, 192.0))
	var opening_kill_plane := level.get_node("OpeningRavineKillPlane") as Area3D
	assert(opening_kill_plane != null)
	assert(opening_kill_plane.global_position.is_equal_approx(
		Vector3(39.68, -8.0, 0)
	))
	var opening_kill_shape := (
		opening_kill_plane.get_node("Collision") as CollisionShape3D
	).shape as BoxShape3D
	assert(opening_kill_shape != null)
	assert(is_equal_approx(opening_kill_shape.size.x, 79.36))
	var opening_kill_right := (
		opening_kill_plane.global_position.x + opening_kill_shape.size.x * 0.5
	)
	assert(is_equal_approx(opening_kill_right, _right(dash_island_02)))
	assert(opening_kill_right < _right(deceptive_takeoff) - 20.0)
	assert(level.get_node("Hazards").get_child_count() == 2)
	assert(level.get_node("Checkpoints").get_child_count() == 3)
	assert(_owned_group_nodes(level, &"level_goal").is_empty())
	assert(_owned_group_nodes(level, &"level_transition").is_empty())

	print(
		"Level 3 WIP passed: quick opener deaths, mixed run-up, deceptive "
		+ "max-kit gap, committed-jump descent, deep enemy-and-spike pocket, dark "
		+ "grade, and clean Wall Jump return."
	)
	_completed = true
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


func _assert_wall(
	level: LevelSession3D,
	from: Vector3,
	direction: Vector3,
	expected_collider: CollisionObject3D
) -> void:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction, 1)
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
