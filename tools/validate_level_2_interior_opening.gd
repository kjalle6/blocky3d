extends SceneTree
## Structural and progression contract for the first production Level 2 slice.

const LEVEL_2_INTERIOR := preload("res://tools/level_2_interior_fixture.gd")
## Row in water_cave_lake.png where the lake surface begins, measured from the
## art: above it the crop is empty, below it is water.
const WATERLINE_SOURCE_ROW := 203.0
const TILE_SIZE := PixelInteriorTerrain3D.TILE_WORLD_SIZE
const EPSILON := 0.001
const EXPECTED_DASH_SPIKE_WIDTH := 13.28
const EXPECTED_DASH_SPIKE_LEFT_EDGE := 64.0
const EXPECTED_DASH_SPIKE_CENTER := (
	EXPECTED_DASH_SPIKE_LEFT_EDGE + EXPECTED_DASH_SPIKE_WIDTH * 0.5
)
const FLAT_CONTINUATION_LEFT_EDGE := 128.0
const FLAT_CONTINUATION_RIGHT_EDGE := 174.08
const EXIT_CHECKPOINT_X := 131.84
const EXIT_APPROACH_ENEMY_X := 139.52
const EXIT_SPIKE_LEFT_EDGE := 145.92
const EXIT_SPIKE_WIDTH := 13.28
const EXIT_SPIKE_CENTER := EXIT_SPIKE_LEFT_EDGE + EXIT_SPIKE_WIDTH * 0.5
const EXIT_LANDING_ENEMY_X := 164.48
const EXIT_LIFT_ORIGIN := Vector3(172.16, 28.16, 0.0)
const COMPLETION_FADE_DURATION := 1.0
const EXIT_CEILING_BOTTOM_Y := 42.24
const DUAL_SHAFT_LEFT_EDGE := 89.0 * TILE_SIZE
const DUAL_SHAFT_WIDTH := 11.0 * TILE_SIZE
const DUAL_FLYER_INWARD_NUDGE := 0.32
const DUAL_FLYER_LEFT_X := (
	DUAL_SHAFT_LEFT_EDGE + DUAL_SHAFT_WIDTH / 6.0 + DUAL_FLYER_INWARD_NUDGE
)
const DUAL_FLYER_RIGHT_X := (
	DUAL_SHAFT_LEFT_EDGE + DUAL_SHAFT_WIDTH * 5.0 / 6.0 - DUAL_FLYER_INWARD_NUDGE
)
var _completed := false


func _init() -> void:
	create_timer(8.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _run() -> void:
	var definition := LEVEL_2_INTERIOR.production_definition()
	assert(definition != null)
	assert(definition.validation_errors().is_empty())
	assert(definition.available_abilities == PlayerAbility.IMPLEMENTED)
	var expected_entry_abilities: Array[StringName] = [&"double_jump"]
	assert(definition.assumed_owned_abilities == expected_entry_abilities)

	var level := LEVEL_2_INTERIOR.instantiate_session()
	root.add_child(level)
	for frame in 4:
		await physics_frame

	var terrain := level.get_node("Platforms/RockShell") as PixelInteriorTerrain3D
	assert(terrain != null)
	assert(terrain.validation_errors().is_empty())
	assert(terrain.row_count() == 40)
	assert(terrain.column_count() == 137)
	assert(
		terrain.collision_rectangle_count() == 9,
		"collision rectangles: %d" % terrain.collision_rectangle_count()
	)
	assert(terrain.hidden_face_region == Rect2i(0, 29, 1, 9))
	assert(terrain.visual_extension_rows_below == 1)
	for hidden_row in range(29, 38):
		assert(terrain.get_node_or_null("Tile_%02d_00" % hidden_row) == null)
	assert(terrain.get_node_or_null("Tile_40_00") is Sprite3D)
	assert(terrain.get_node_or_null("Tile_40_136") is Sprite3D)
	assert(terrain.get_node_or_null("Tile_40_73") == null)
	assert(terrain.get_node_or_null("Tile_40_94") == null)
	assert(not terrain.is_solid_cell(40, 0))
	var collision_bottom := INF
	for child in terrain.get_children():
		var collision := child as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			continue
		var box := collision.shape as BoxShape3D
		collision_bottom = minf(
			collision_bottom,
			collision.global_position.y - box.size.y * 0.5
		)
	assert(is_equal_approx(collision_bottom, terrain.global_position.y))
	var opening_camera := level.camera as PixelSideCamera3D
	assert(opening_camera != null)
	var opening_half_width := opening_camera.size * 16.0 / 9.0 * 0.5
	var route_start_x := (
		level.route_extent.global_position.x + level.route_extent.route_start_x
	)
	assert(is_equal_approx(opening_camera.minimum_center_x, 11.52))
	assert(is_equal_approx(opening_camera.maximum_center_x, 162.56))
	assert(is_equal_approx(
		level.route_extent.route_end_x,
		FLAT_CONTINUATION_RIGHT_EDGE
	))
	assert(
		opening_camera.minimum_center_x - opening_half_width >= route_start_x,
		"The opening camera must not reveal world behind the authored route start."
	)
	var rendered_terrain_bottom := (
		terrain.global_position.y
		- terrain.visual_extension_rows_below * TILE_SIZE
	)
	var opening_view_bottom := opening_camera.camera_height - opening_camera.size * 0.5
	assert(
		rendered_terrain_bottom <= opening_view_bottom,
		"The terrain face must cover the camera below the playable floor."
	)
	assert(
		opening_view_bottom - rendered_terrain_bottom
		>= PixelInteriorTerrain3D.TILE_PIXEL_SIZE,
		"The terrain face needs at least one source pixel of bottom coverage margin."
	)

	# The production interior owns two localized lake-cavern vistas. Their X
	# positions and every visual layer stay authored in world space; neither a
	# jump nor the shaft climb may drag cave art vertically with the camera.
	_validate_water_vista(level, "MachineShaftWaterVista", 94.08, 30.88)
	_validate_water_vista(level, "DualMachineShaftWaterVista", 120.96, 30.88)
	var background := level.get_node("Background") as PixelBackgroundRig3D
	assert(background != null and background.visible)
	assert(background.profile != null)
	assert(background.profile.profile_id == &"rock_underworks_cave")
	assert(background.profile.layers.size() == 5)
	assert(background.profile.validation_errors().is_empty())
	_validate_upper_cave_ceiling(level)
	# Every global cave layer stays static on screen vertically, so a jump
	# changes nothing. Each region owns one flat coverage layer while its depth
	# layers parallax-scroll as the player travels horizontally.
	# No layer repeats vertically: repeating featured art puts an identical
	# band overhead during a climb.
	for index in background.profile.layers.size():
		var layer := background.profile.layers[index]
		assert(
			layer.vertical_policy
			== PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED
		)
		assert(layer.world_repeat_below == 0 and layer.world_repeat_above == 0)

	# Smoky crystal-cave coverage remains beneath the upper composition's
	# transparent pixels. Its two depth layers belong only below the upper
	# region and fade out across the same boundary that reveals the water cave.
	# All three retain the source artwork's pale smoky-grey palette unchanged.
	var lower_base := background.profile.layers[0]
	assert(not lower_base.is_zoned())
	assert(lower_base.tint == Color.WHITE)
	assert(
		lower_base.horizontal_policy
		== PixelBackgroundLayerProfile.HorizontalPolicy.SCREEN_LOCKED
	)
	var lower_distant := background.profile.layers[1]
	assert(lower_distant.zone_tag == &"upper")
	assert(lower_distant.invert_zone_visibility)
	assert(lower_distant.tint == Color.WHITE)
	assert(
		lower_distant.horizontal_policy
		== PixelBackgroundLayerProfile.HorizontalPolicy.PARALLAX
		and lower_distant.horizontal_parallax > 0.0
	)
	var lower_crystals := background.profile.layers[2]
	assert(lower_crystals.zone_tag == &"upper")
	assert(lower_crystals.invert_zone_visibility)
	assert(lower_crystals.tint == Color.WHITE)
	assert(lower_crystals.horizontal_parallax > lower_distant.horizontal_parallax)
	var upper_base := background.profile.layers[3]
	assert(upper_base.zone_tag == &"upper")
	assert(not upper_base.invert_zone_visibility)
	assert(
		upper_base.horizontal_policy
		== PixelBackgroundLayerProfile.HorizontalPolicy.SCREEN_LOCKED
	)
	var upper_distant := background.profile.layers[4]
	assert(
		upper_distant.zone_tag == &"upper",
		"The distant cave composition must stay zoned to the upper floor."
	)
	assert(not upper_distant.invert_zone_visibility)
	assert(
		upper_distant.horizontal_policy
		== PixelBackgroundLayerProfile.HorizontalPolicy.PARALLAX
		and upper_distant.horizontal_parallax > 0.0,
		"The distant composition must drift as the player walks."
	)
	# Falling down a machine shaft ends at the water you can see, not at a fixed
	# depth. The lake is drawn by a camera-locked vista, so its world height
	# moves with the camera: a hazard pinned to any single height is correct for
	# one instant of a fall and wrong for the rest, which is how the splash
	# ended up firing tens of metres below the visible surface. Parenting the
	# contact to the vista makes it ride the same water, and the splash reads
	# its surface from the same node, so all three cannot disagree.
	for frame in 3:
		await process_frame
	var vista_contacts := {
		"MachineShaftWaterVista": "MachineShaftWaterContact",
		"DualMachineShaftWaterVista": "DualMachineShaftWaterContact",
	}
	var lake_surface_local := 0.0
	for vista_name in vista_contacts:
		var vista := level.get_node(NodePath(vista_name)) as PixelVistaWindow3D
		var lake := vista.get_node("LakeAndRocks") as Sprite3D
		assert(lake != null and lake.region_enabled)
		var centre_row := lake.region_rect.position.y + lake.region_rect.size.y * 0.5
		var water_surface_y: float = (
			lake.global_position.y
			+ (centre_row - WATERLINE_SOURCE_ROW) * lake.pixel_size
		)
		lake_surface_local = water_surface_y - vista.global_position.y

		var contact := level.get_node(
			NodePath("Hazards/%s" % vista_contacts[vista_name])
		) as Hazard3D
		assert(
			contact != null,
			"%s needs a water contact following it so the two move together."
			% vista_name
		)
		assert(
			not contact.height_source_path.is_empty(),
			(
				"%s water contact must follow the vista. A fixed height is "
				+ "right for one instant of a fall and wrong for the rest."
			) % vista_name
		)
		assert(
			contact.death_kind == PlayerCharacter.DEATH_KIND_WATER,
			"%s must report a water death, not a generic one." % vista_name
		)
		var box := (
			contact.get_node("Collision") as CollisionShape3D
		).shape as BoxShape3D
		var contact_top := contact.global_position.y + box.size.y * 0.5
		assert(
			absf(contact_top - water_surface_y) <= 0.05,
			(
				"%s kills at y %.2f but its water is drawn at %.2f."
			) % [vista_name, contact_top, water_surface_y]
		)
		assert(
			box.size.x >= DUAL_SHAFT_WIDTH - 0.01,
			"%s water contact must span its whole shaft." % vista_name
		)

	var splash := level.get_node("WaterDeathSplash") as PixelWaterDeathSplash3D
	assert(splash != null, "The cave needs the water death presentation.")
	assert(
		not splash.surface_source_path.is_empty(),
		(
			"The splash must follow the drawn water rather than a fixed height, "
			+ "or it plays where the lake used to be."
		)
	)
	assert(
		absf(splash.surface_source_offset - lake_surface_local) <= 0.05,
		(
			"The splash sits %.2f m from its source but the lake surface is "
			+ "%.2f m from it."
		) % [splash.surface_source_offset, lake_surface_local]
	)

	var upper_region := level.get_node("UpperCaveBackgroundRegion") as PixelBackgroundRegion3D
	assert(upper_region != null, "The upper floor needs an authored background region.")
	assert(upper_region.validation_errors().is_empty())
	assert(
		upper_region.shows_zone(&"upper"),
		"The upper region must reveal the zone the distant layer is tagged with."
	)
	assert(
		upper_region.blend_margin >= 6.5
		and upper_region.blend_exponent >= 0.9
		and upper_region.blend_exponent <= 1.25,
		(
			"The handoff must begin during the final climb and use a broad, "
			+ "balanced ramp so the smoky grey mixes into the water-cave blue "
			+ "before the player reaches the upper landing."
		)
	)
	assert(upper_region.position.is_equal_approx(Vector3(110.08, 39.0, 0.0)))
	assert(upper_region.size.is_equal_approx(Vector2(142.0, 22.0)))
	var lower_face_y := upper_region.global_position.y - upper_region.size.y * 0.5
	var sample_x := upper_region.global_position.x
	assert(is_zero_approx(background.zone_opacity_at(
		upper_distant,
		Vector3(sample_x, lower_face_y - upper_region.blend_margin - 0.1, 0.0)
	)))
	var blend_opacity := background.zone_opacity_at(
		upper_distant,
		Vector3(sample_x, lower_face_y - upper_region.blend_margin * 0.5, 0.0)
	)
	assert(
		blend_opacity > 0.0 and blend_opacity < 1.0,
		"The upper cave region must produce a real partial-opacity blend."
	)
	var lower_blend_opacity := background.zone_opacity_at(
		lower_crystals,
		Vector3(sample_x, lower_face_y - upper_region.blend_margin * 0.5, 0.0)
	)
	assert(
		is_equal_approx(lower_blend_opacity + blend_opacity, 1.0),
		"Lower and upper cave art must cross-fade without a colour gap."
	)
	assert(is_equal_approx(background.zone_opacity_at(
		upper_distant,
		Vector3(sample_x, lower_face_y + 0.1, 0.0)
	), 1.0))

	# One grid owns the lower tunnel, continuous shaft, upper-left Dash alcove,
	# and upper-right destination corridor. The ascent itself remains three
	# independent terrain bodies so every ledge is visibly unsupported.
	assert(not terrain.is_solid_cell(29, 4))
	assert(terrain.is_solid_cell(28, 4))
	assert(terrain.is_solid_cell(38, 4))
	assert(not terrain.is_solid_cell(29, 45))
	assert(terrain.is_solid_cell(29, 48))
	assert(not terrain.is_solid_cell(28, 45))
	assert(terrain.is_solid_cell(28, 43))
	assert(terrain.is_solid_cell(28, 48))
	assert(not terrain.is_solid_cell(16, 45))
	assert(terrain.is_solid_cell(16, 43))
	assert(terrain.is_solid_cell(16, 48))
	assert(not terrain.is_solid_cell(15, 38))
	assert(terrain.is_solid_cell(16, 38))
	assert(not terrain.is_solid_cell(15, 60))
	assert(terrain.is_solid_cell(16, 60))
	assert(not terrain.is_solid_cell(11, 60))

	# The ordinary foreground roof is raised to the same top row as the two
	# machine openings. That leaves the source artwork's rocky ceiling visible
	# throughout the upper chamber without faking a lower decorative strip.
	for upper_column in [38, 60, 73, 83, 94, 106]:
		assert(terrain.is_solid_cell(4, upper_column))
		assert(not terrain.is_solid_cell(5, upper_column))
		assert(not terrain.is_solid_cell(11, upper_column))

	# Both evasive-flyer chambers are full-height breaks in the corridor. They
	# stay open floor-to-sky, so nothing above or below a machine can be mistaken
	# for a route.
	for gap_column in [73, 94]:
		for row in [5, 9, 11, 14, 20, 30, 39]:
			assert(
				not terrain.is_solid_cell(row, gap_column),
				(
					"Gap at column %d must stay open through the corridor and out "
					+ "the bottom (row %d)."
				) % [gap_column, row]
			)
	# The gap stays open far past the ordinary camera framing. A distant solid
	# cave roof bounds the authored space, but it must remain harmless: the machine
	# encounter does not force a surprise row of overhead spikes.
	for gap_column in [73, 94]:
		for row in [0, 2, 4]:
			assert(
				terrain.is_solid_cell(row, gap_column),
				"Gap at column %d must close above the camera at row %d."
				% [gap_column, row]
			)
	assert(
		level.get_node_or_null("Hazards/MachineShaftCeilingSpikes") == null,
		"The first machine gap must not have forced overhead spikes."
	)
	assert(
		level.get_node_or_null("Hazards/DualMachineShaftCeilingSpikes") == null,
		"The dual-machine gap must not have forced overhead spikes."
	)

	assert(terrain.is_solid_cell(16, 67), "Takeoff ledge must be solid.")
	assert(terrain.is_solid_cell(16, 79), "Landing ledge must be solid.")
	assert(terrain.is_solid_cell(16, 88), "Second takeoff ledge must be solid.")
	assert(terrain.is_solid_cell(16, 100), "Second landing ledge must be solid.")
	assert(not terrain.is_solid_cell(15, 67))
	assert(not terrain.is_solid_cell(15, 79))
	assert(not terrain.is_solid_cell(15, 88))
	assert(not terrain.is_solid_cell(15, 100))

	# The abandoned aerial finale is gone. After the paired machines the cave
	# continues as one level floor under the existing ceiling and camera, giving
	# the next ending design a neutral baseline rather than inherited geometry.
	for continuation_column in range(100, 136):
		for open_row in range(5, 16):
			assert(not terrain.is_solid_cell(open_row, continuation_column))
		assert(terrain.is_solid_cell(16, continuation_column))
	for boundary_row in range(5, 40):
		assert(terrain.is_solid_cell(boundary_row, 136))
	assert(is_equal_approx(100.0 * TILE_SIZE, FLAT_CONTINUATION_LEFT_EDGE))
	assert(is_equal_approx(136.0 * TILE_SIZE, FLAT_CONTINUATION_RIGHT_EDGE))

	var shaft_gap := (79.0 - 68.0) * TILE_SIZE
	var dual_shaft_gap := (100.0 - 89.0) * TILE_SIZE
	assert(is_equal_approx(dual_shaft_gap, shaft_gap))
	# Sized against the reach the player actually has here, not a single jump.
	# They own Double Jump by this point, and two arcs carry roughly twice as
	# far, so a gap tuned to one jump stops requiring the ability it teaches.
	var movement := level.player.movement
	assert(
		shaft_gap > movement.ideal_double_jump_distance() + 1.5,
		(
			"The machine gap is %.2f m but a Double Jump reaches %.2f m; "
			+ "it must clearly exceed that or Dash is optional."
		) % [shaft_gap, movement.ideal_double_jump_distance()]
	)
	assert(
		shaft_gap < movement.ideal_double_jump_dash_distance() - 1.5,
		(
			"The machine gap is %.2f m but Double Jump plus Dash only reaches "
			+ "%.2f m; the crossing must keep a fair landing margin."
		) % [shaft_gap, movement.ideal_double_jump_dash_distance()]
	)

	# The machine has to be visible and readable well before it is committed to,
	# so the ledge leading in is authored length rather than whatever was left
	# over after the Dash crossing.
	var run_up := (
		68.0 * TILE_SIZE
		- (EXPECTED_DASH_SPIKE_LEFT_EDGE + EXPECTED_DASH_SPIKE_WIDTH)
	)
	assert(
		run_up >= 7.5 * TILE_SIZE - 0.01,
		"Run-up to the machine is only %.2f m; it must stay long enough to read it." % run_up
	)
	var dual_run_up := (89.0 - 79.0) * TILE_SIZE
	assert(
		dual_run_up >= 12.8 - 0.01,
		"Run-up to the dual machines is only %.2f m." % dual_run_up
	)

	var flyer := level.get_node("ShaftFlyer") as HoveringHazard3D
	assert(flyer != null)
	assert(flyer.validation_errors().is_empty())
	assert(
		not flyer.is_in_group("melee_target"),
		"The machine is a traversal hazard; it must not be attackable."
	)
	assert(not flyer.is_in_group("stompable"))
	assert(is_zero_approx(flyer.horizontal_amplitude))
	assert(is_zero_approx(flyer.horizontal_patrol_period()))
	assert(is_equal_approx(flyer.leftmost_body_x(), flyer.rightmost_body_x()))

	# The design rule for this beat: the machine's travel must never close both
	# routes at once. When it rises the floor lane opens; when it drops the
	# ceiling lane opens. Whatever the bob is tuned to, one of them stays
	# generous, so the encounter is a choice rather than a needle to thread.
	var corridor_floor_y := 28.16
	var corridor_ceiling_y := 33.28
	var player_box := (
		level.player.get_node("CollisionShape3D") as CollisionShape3D
	).shape as BoxShape3D
	assert(player_box != null)
	var lane_needed := player_box.size.y + 0.4
	var floor_lane := (flyer.highest_body_y() - 0.92) - corridor_floor_y
	var ceiling_lane := corridor_ceiling_y - (flyer.lowest_body_y() + 0.5)
	assert(
		floor_lane > lane_needed,
		"With the machine risen the floor lane is only %.2f m." % floor_lane
	)
	assert(
		ceiling_lane > lane_needed,
		"With the machine dropped the ceiling lane is only %.2f m." % ceiling_lane
	)

	var rising_flyer := level.get_node("DualShaftFlyerRising") as HoveringHazard3D
	var falling_flyer := level.get_node("DualShaftFlyerFalling") as HoveringHazard3D
	assert(rising_flyer != null and falling_flyer != null)
	for dual_flyer in [rising_flyer, falling_flyer]:
		assert(dual_flyer.validation_errors().is_empty())
		assert(not dual_flyer.is_in_group("melee_target"))
		assert(not dual_flyer.is_in_group("stompable"))
		assert(is_zero_approx(dual_flyer.horizontal_amplitude))
		assert(is_zero_approx(dual_flyer.horizontal_patrol_period()))
		assert(is_equal_approx(
			dual_flyer.leftmost_body_x(),
			dual_flyer.rightmost_body_x()
		))
		assert(is_equal_approx(dual_flyer.bob_amplitude, flyer.bob_amplitude))
		assert(is_equal_approx(dual_flyer.bob_period, flyer.bob_period))
		assert(is_equal_approx(dual_flyer.lowest_body_y(), flyer.lowest_body_y()))
		assert(is_equal_approx(dual_flyer.highest_body_y(), flyer.highest_body_y()))
	assert(is_equal_approx(rising_flyer.position.x, DUAL_FLYER_LEFT_X))
	assert(is_equal_approx(falling_flyer.position.x, DUAL_FLYER_RIGHT_X))
	assert(is_equal_approx(
		falling_flyer.position.x - rising_flyer.position.x,
		DUAL_SHAFT_WIDTH * 2.0 / 3.0 - DUAL_FLYER_INWARD_NUDGE * 2.0
	))
	assert(is_equal_approx(rising_flyer.bob_phase, 0.0))
	assert(is_equal_approx(falling_flyer.bob_phase, 0.5))
	assert(
		is_equal_approx(
			absf(sin(rising_flyer.bob_phase * TAU) - sin(falling_flyer.bob_phase * TAU)),
			0.0
		),
		"Both machines must begin at the same height."
	)
	assert(
		cos(rising_flyer.bob_phase * TAU) > 0.0
		and cos(falling_flyer.bob_phase * TAU) < 0.0,
		"One dual machine must begin rising while the other begins falling."
	)

	assert(level.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not level.player.has_ability(PlayerAbility.WALL_JUMP))
	assert(not level.player.has_ability(PlayerAbility.DASH))
	var ascent_platforms: Array[PixelInteriorTerrain3D] = [
		level.get_node("Platforms/AscentPlatform01") as PixelInteriorTerrain3D,
		level.get_node("Platforms/AscentPlatform02") as PixelInteriorTerrain3D,
		level.get_node("Platforms/AscentPlatform03") as PixelInteriorTerrain3D,
	]
	var expected_platform_positions: Array[Vector3] = [
		Vector3(34.56, 1.28, 0.0),
		Vector3(44.8, 3.2, 0.0),
		Vector3(55.04, 5.12, 0.0),
	]
	for index in ascent_platforms.size():
		var platform := ascent_platforms[index]
		assert(platform != null)
		assert(platform.validation_errors().is_empty())
		assert(platform.solid_rows == PackedStringArray(["####"]))
		assert(platform.position.is_equal_approx(expected_platform_positions[index]))
	var ascent_enemy := level.get_node("AscentPlatform02Patrol") as StompableEnemy3D
	assert(ascent_enemy != null)
	assert(is_equal_approx(ascent_enemy.patrol_speed, 2.0))
	assert(is_zero_approx(ascent_enemy.patrol_left_distance))
	assert(is_zero_approx(ascent_enemy.patrol_right_distance))
	var second_platform_top := (
		ascent_platforms[1].position.y + PixelInteriorTerrain3D.TILE_WORLD_SIZE
	)
	assert(ascent_enemy.position.y - second_platform_top >= 0.38 - EPSILON)
	assert(ascent_enemy.position.y - second_platform_top <= 0.42 + EPSILON)
	var ascent_enemy_authored_x := (
		ascent_enemy.authored_patrol_bounds_x().x
		+ ascent_enemy.authored_patrol_bounds_x().y
	) * 0.5
	assert(
		is_equal_approx(
			ascent_enemy_authored_x,
			ascent_platforms[1].position.x
			+ PixelInteriorTerrain3D.TILE_WORLD_SIZE * 2.0
		),
		"The ascent enemy must begin at the centre of the second platform."
	)
	var wall_pickup := level.get_node("WallJumpPickup") as AbilityPickup3D
	var dash_pickup := level.get_node("DashPickup") as AbilityPickup3D
	var dash_crossing_spikes := level.get_node(
		"Hazards/DashCrossingSpikes"
	) as PixelSpikeRow3D
	assert(wall_pickup != null and not wall_pickup.is_claimed())
	assert(dash_pickup != null and not dash_pickup.is_claimed())
	assert(wall_pickup.ability_id == PlayerAbility.WALL_JUMP)
	assert(wall_pickup.position.is_equal_approx(Vector3(57.6, 6.4, 0.0)))
	assert(dash_pickup.ability_id == PlayerAbility.DASH)
	assert(dash_pickup.position.is_equal_approx(Vector3(48.64, 28.16, 0.0)))
	assert(dash_crossing_spikes != null)
	assert(is_equal_approx(dash_crossing_spikes.position.x, EXPECTED_DASH_SPIKE_CENTER))
	assert(is_equal_approx(dash_crossing_spikes.row_width, EXPECTED_DASH_SPIKE_WIDTH))
	assert(is_equal_approx(
		dash_crossing_spikes.position.x - dash_crossing_spikes.row_width * 0.5,
		EXPECTED_DASH_SPIKE_LEFT_EDGE
	))
	assert(dash_crossing_spikes.get_node_or_null("Spike17") != null)
	assert(dash_crossing_spikes.get_node_or_null("Spike18") == null)
	var shaft_checkpoint := level.get_node(
		"Checkpoints/CheckpointShaftReady"
	) as LevelCheckpoint3D
	assert(shaft_checkpoint != null)
	assert(shaft_checkpoint.position.is_equal_approx(Vector3(80.64, 28.16, 0.0)))
	assert(
		shaft_checkpoint.position.x - 1.2
		> dash_crossing_spikes.position.x + dash_crossing_spikes.row_width * 0.5,
		"Post-crossing checkpoint trigger must not overlap the widened spike row."
	)
	var low_wall_spikes := level.get_node(
		"Hazards/ShaftRightSpikesLow"
	) as PixelSpikeRow3D
	var high_wall_spikes := level.get_node(
		"Hazards/ShaftRightSpikesHigh"
	) as PixelSpikeRow3D
	assert(low_wall_spikes != null and high_wall_spikes != null)
	assert(is_equal_approx(low_wall_spikes.row_width, 1.706667))
	assert(is_equal_approx(high_wall_spikes.row_width, 1.706667))
	assert(is_equal_approx(low_wall_spikes.position.y, 11.946667))
	assert(is_equal_approx(high_wall_spikes.position.y, 23.413333))

	var dash_spike_width := dash_crossing_spikes.row_width
	assert(
		dash_spike_width > movement.ideal_double_jump_distance() + 1.4,
		(
			"Dash spike row is %.2f m but a Double Jump reaches %.2f m; "
			+ "the newly collected Dash must be required."
		) % [dash_spike_width, movement.ideal_double_jump_distance()]
	)
	assert(
		dash_spike_width < movement.ideal_double_jump_dash_distance() - 1.5,
		(
			"Dash spike row is %.2f m but Double Jump plus Dash only reaches "
			+ "%.2f m; the crossing must keep a fair landing margin."
		) % [dash_spike_width, movement.ideal_double_jump_dash_distance()]
	)

	# The finale stays on the established upper floor: a short enemy run-up,
	# one proven Dash-only spike row, a landing-side surprise patrol, and the
	# cave lift. Nothing here is allowed to create a new platforming climb.
	var exit_spikes := level.get_node(
		"Hazards/ExitGauntletSpikes"
	) as PixelSpikeRow3D
	assert(exit_spikes != null)
	assert(exit_spikes.position.is_equal_approx(
		Vector3(EXIT_SPIKE_CENTER, 28.16, 0.0)
	))
	assert(is_equal_approx(exit_spikes.row_width, EXIT_SPIKE_WIDTH))
	assert(is_equal_approx(
		exit_spikes.position.x - exit_spikes.row_width * 0.5,
		EXIT_SPIKE_LEFT_EDGE
	))
	assert(exit_spikes.get_node_or_null("Spike17") != null)
	assert(exit_spikes.get_node_or_null("Spike18") == null)
	assert(
		exit_spikes.row_width > movement.ideal_double_jump_distance() + 1.4,
		"The exit strip must still require Dash after Double Jump."
	)
	assert(
		exit_spikes.row_width
		< movement.ideal_double_jump_dash_distance() - 1.5,
		"The exit strip must retain a fair Dash landing margin."
	)

	var exit_checkpoint := level.get_node(
		"Checkpoints/CheckpointExitGauntletReady"
	) as LevelCheckpoint3D
	assert(exit_checkpoint != null)
	assert(exit_checkpoint.route_index == 5)
	assert(exit_checkpoint.position.is_equal_approx(
		Vector3(EXIT_CHECKPOINT_X, 28.16, 0.0)
	))

	var exit_approach_enemy := level.get_node(
		"ExitGauntletApproachPatrol"
	) as StompableEnemy3D
	var exit_landing_enemy := level.get_node(
		"ExitGauntletLandingPatrol"
	) as StompableEnemy3D
	assert(exit_approach_enemy != null and exit_landing_enemy != null)
	for exit_enemy in [exit_approach_enemy, exit_landing_enemy]:
		assert(exit_enemy.position.y - 28.16 >= 0.38 - EPSILON)
		assert(exit_enemy.position.y - 28.16 <= 0.42 + EPSILON)
		assert(is_equal_approx(exit_enemy.patrol_speed, 2.0))
		assert(is_equal_approx(exit_enemy.patrol_left_distance, 3.84))
		assert(is_equal_approx(exit_enemy.patrol_right_distance, 3.84))
	assert(exit_approach_enemy.starts_moving_right)
	assert(not exit_landing_enemy.starts_moving_right)
	var approach_bounds := exit_approach_enemy.authored_patrol_bounds_x()
	var landing_bounds := exit_landing_enemy.authored_patrol_bounds_x()
	assert(approach_bounds.is_equal_approx(Vector2(135.68, 143.36)))
	assert(landing_bounds.is_equal_approx(Vector2(160.64, 168.32)))
	var exit_enemy_body := (
		exit_approach_enemy.get_node("BodyCollision") as CollisionShape3D
	).shape as BoxShape3D
	var player_shape := (
		level.player.get_node("CollisionShape3D") as CollisionShape3D
	).shape as BoxShape3D
	assert(exit_enemy_body != null and player_shape != null)
	var enemy_half_width := exit_enemy_body.size.x * 0.5
	var player_half_width := player_shape.size.x * 0.5
	assert(
		EXIT_SPIKE_LEFT_EDGE - (approach_bounds.y + enemy_half_width)
		>= 2.2 - EPSILON,
		"The first patrol must leave enough floor to accelerate into the Dash."
	)
	assert(
		(landing_bounds.x - enemy_half_width)
		- (EXIT_SPIKE_LEFT_EDGE + EXIT_SPIKE_WIDTH) >= 1.08 - EPSILON,
		"The surprise patrol must never body-block the player over the spikes."
	)
	var checkpoint_shape := (
		exit_checkpoint.get_node("Trigger") as CollisionShape3D
	).shape as BoxShape3D
	assert(checkpoint_shape != null)
	assert(
		approach_bounds.x
		- (
			exit_checkpoint.position.x
			+ checkpoint_shape.size.x * 0.5
			+ player_half_width
		)
		> exit_approach_enemy.attack_trigger_distance,
		"Every player position overlapping the retry checkpoint must be safe."
	)

	var lift := level.get_node("Props/CaveLiftExit") as Node3D
	assert(lift != null)
	assert(lift.position.is_equal_approx(EXIT_LIFT_ORIGIN))
	assert(lift.has_method("validation_errors"))
	assert((lift.call("validation_errors") as PackedStringArray).is_empty())
	assert(level.get_node_or_null("Props/ServiceDoorExit") == null)
	assert(lift.get_node_or_null("CaveMask") == null)
	assert(is_zero_approx(float(lift.get("boarding_delay"))))
	assert(is_equal_approx(float(lift.get("exit_trigger_progress")), 0.62))
	assert(is_equal_approx(float(lift.get("exit_still_duration")), 1.0))
	assert(lift.get("exit_goal_path") == NodePath("../../Goal"))
	assert(is_equal_approx(level.completion_fade_duration, COMPLETION_FADE_DURATION))
	var shaft_backdrop := lift.get_node("ShaftBackdrop") as MeshInstance3D
	assert(not shaft_backdrop.visible)
	var shaft_mesh := shaft_backdrop.mesh as QuadMesh
	assert(shaft_mesh != null)
	assert(shaft_mesh.size.is_equal_approx(Vector2(3.84, 17.92)))
	assert(is_equal_approx(
		lift.global_position.x + shaft_mesh.size.x * 0.5,
		FLAT_CONTINUATION_RIGHT_EDGE
	))
	var carriage := lift.get_node("Carriage") as AnimatableBody3D
	var carriage_shape := (
		carriage.get_node("Collision") as CollisionShape3D
	).shape as BoxShape3D
	var boarding_area := carriage.get_node("BoardingArea") as Area3D
	var boarding_shape := (
		boarding_area.get_node("Collision") as CollisionShape3D
	).shape as BoxShape3D
	assert(carriage_shape.size.is_equal_approx(Vector3(2.32, 0.18, 1.2)))
	assert(boarding_shape.size.is_equal_approx(Vector3(2.16, 1.5, 1.1)))
	var production_texture_paths := PackedStringArray([
		"res://assets/art/interiors/rock_underworks/props/cave_lift/tower_top.png",
		"res://assets/art/interiors/rock_underworks/props/cave_lift/tower_middle.png",
		"res://assets/art/interiors/rock_underworks/props/cave_lift/tower_base.png",
		"res://assets/art/interiors/rock_underworks/props/cave_lift/hoist.png",
		"res://assets/art/interiors/rock_underworks/props/cave_lift/platform.png",
		"res://assets/art/interiors/rock_underworks/props/cave_lift/guard_left.png",
		"res://assets/art/interiors/rock_underworks/props/cave_lift/guard_right.png",
	])
	for texture_path in production_texture_paths:
		assert(ResourceLoader.exists(texture_path))
	for sprite in lift.find_children("*", "Sprite3D", true, false):
		var lift_sprite := sprite as Sprite3D
		assert(lift_sprite.texture != null)
		assert(
			lift_sprite.texture.resource_path.begins_with(
				"res://assets/art/interiors/rock_underworks/props/cave_lift/"
			),
			"Production lift sprite still depends on the source-art catalog."
		)

	var goal := level.get_node("Goal") as LevelGoal3D
	assert(goal != null and not goal is PixelGoal3D)
	assert(goal.position.is_equal_approx(EXIT_LIFT_ORIGIN))
	assert(not goal.trigger_on_body_entry)
	var goal_shape := (
		goal.get_node("Collision") as CollisionShape3D
	).shape as BoxShape3D
	assert(goal_shape != null and player_shape != null)
	var first_boarding_overlap_x := (
		lift.global_position.x
		- boarding_shape.size.x * 0.5
		- player_half_width
	)
	assert(
		first_boarding_overlap_x - (landing_bounds.y + enemy_half_width)
		>= 2.0 - EPSILON,
		"The landing patrol must leave a clean final approach to the lift."
	)
	assert(level.get_node_or_null("FinaleCameraRegion") == null)
	assert(level.camera.get_script().resource_path == "res://scripts/camera/phantom_pixel_camera_3d.gd")
	assert(level.get_node("CameraDirection/CameraRail") is Path3D)
	assert(level.get_node("CameraDirection/BranchRail") is Path3D)

	# Contact probes make sure the authored art and collision agree at each beat.
	assert(_blocked(level.player, Vector3(4.48, 0.7, 0), Vector3.DOWN))
	assert(
		_blocked(level.player, Vector3(1.64, 0.7, 0), Vector3.LEFT),
		"Hiding the opening pillar must not remove its left-boundary collision."
	)
	assert(_blocked(level.player, Vector3(37.12, 3.26, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(47.36, 5.18, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(57.6, 7.1, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(58.88, 12.0, 0), Vector3.LEFT * 4.0))
	assert(_blocked(level.player, Vector3(58.88, 12.0, 0), Vector3.RIGHT * 4.0))
	assert(_blocked(level.player, Vector3(48.64, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(80.64, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(105.0, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(110.0, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(132.0, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(148.0, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(160.0, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(169.0, 28.86, 0), Vector3.DOWN))
	assert(_blocked(level.player, Vector3(173.0, 28.86, 0), Vector3.RIGHT * 2.0))
	assert(
		not _blocked(level.player, Vector3(94.08, 28.86, 0), Vector3.DOWN),
		"The machine's shaft must be a real hole, not a floor with art removed."
	)
	assert(
		not _blocked(level.player, Vector3(120.96, 28.86, 0), Vector3.DOWN),
		"The dual-machine shaft must be a real hole."
	)
	await _validate_wall_jump_camera_focus(level)
	await _validate_vertical_background_behavior(level, background)

	# The broad area only notices a possible rider. Even fully on the left half,
	# the player remains in control until standing still for one authored second;
	# then the carriage owns their chosen offset while the slower fade begins.
	for exit_enemy in [exit_approach_enemy, exit_landing_enemy]:
		exit_enemy.set_physics_process(false)
	var completion_state := {"reached": false}
	level.run_completed.connect(func() -> void: completion_state.reached = true)
	level.player.reset_at(Transform3D(
		Basis.IDENTITY,
		EXIT_LIFT_ORIGIN + Vector3(-0.56, 0.7, 0.0)
	))
	level.camera.snap_to_target()
	for frame in 2:
		await physics_frame
	for frame in 30:
		await physics_frame
	assert(not completion_state.reached)
	assert(level.player.is_physics_processing())
	assert(is_zero_approx(carriage.position.y))
	var locked_camera_position: Vector3 = level.camera.global_position
	var rider_start_y: float = level.player.global_position.y
	var carriage_start_y: float = carriage.global_position.y
	for frame in 180:
		await physics_frame
	await process_frame
	assert(completion_state.reached)
	assert(not level.player.is_physics_processing())
	assert(level.player.visible)
	assert(level.player.pixel_visual.current_state() == "idle")
	assert(carriage.position.y > 0.0)
	assert(level.player.global_position.y > rider_start_y)
	assert(is_equal_approx(
		level.player.global_position.y - rider_start_y,
		carriage.global_position.y - carriage_start_y
	), "rider rise %.4f, carriage rise %.4f" % [
		level.player.global_position.y - rider_start_y,
		carriage.global_position.y - carriage_start_y,
	])
	assert(level.camera.global_position.is_equal_approx(locked_camera_position))
	var fade_end_progress := (
		float(lift.get("exit_trigger_progress"))
		+ COMPLETION_FADE_DURATION / float(lift.get("travel_duration"))
	)
	var rise_before_black := float(lift.call(
		"preview_height_for_progress",
		fade_end_progress
	))
	var player_top_at_black := (
		EXIT_LIFT_ORIGIN.y
		+ 0.7
		+ player_shape.size.y * 0.5
		+ rise_before_black
	)
	assert(
		player_top_at_black < EXIT_CEILING_BOTTOM_Y,
		"The completion fade must be opaque before the lift reaches the solid ceiling."
	)

	print(
		(
			"Level 2 interior passed: recap, shaft, turnback, two %.2f m "
			+ "Dash crossings, enemy exit gauntlet, cave-lift departure."
		) % dash_spike_width
	)
	_completed = true
	quit(0)


func _blocked(body: CharacterBody3D, origin: Vector3, motion: Vector3) -> bool:
	return body.test_move(Transform3D(Basis.IDENTITY, origin), motion)


func _validate_upper_cave_ceiling(level: LevelSession3D) -> void:
	var ceiling := level.get_node("UpperCaveCeiling") as PixelCaveCeilingOverlay3D
	assert(ceiling != null, "The upper floor needs its shared cave ceiling.")
	assert(ceiling.validation_errors().is_empty())
	assert(ceiling.zone_tag == &"upper")
	assert(is_equal_approx(ceiling.vertical_offset, 0.02))
	assert(ceiling.horizontal_panel_count == 7)
	assert(is_equal_approx(ceiling.horizontal_panel_step, 23.04))
	assert(is_equal_approx(ceiling.global_position.x, 93.44))
	assert(ceiling.get_node_or_null("LakeAndRocks") == null)
	assert(ceiling.get_node_or_null("DeepWaterFill") == null)
	var expected_layers := {
		"CeilingFill": {
			"region": Rect2(0.0, 0.0, 576.0, 1.0),
			"position_y": 8.92,
			"scale_y": 122.0,
		},
		"CaveCeiling": {
			"region": Rect2(0.0, 0.0, 576.0, 87.0),
			"position_y": 4.74,
		},
	}
	for layer_name in expected_layers:
		var layer := ceiling.get_node(layer_name) as Sprite3D
		assert(layer != null, "UpperCaveCeiling/%s is missing." % layer_name)
		assert(is_equal_approx(layer.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE))
		assert(layer.region_enabled)
		assert(layer.region_rect == expected_layers[layer_name]["region"])
		assert(is_equal_approx(
			layer.position.y,
			expected_layers[layer_name]["position_y"]
		))
		if expected_layers[layer_name].has("scale_y"):
			assert(is_equal_approx(
				layer.scale.y,
				expected_layers[layer_name]["scale_y"]
			))
		assert(layer.render_priority == -90)
		assert(not layer.shaded)
		assert(layer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var panel_counts := {}
	var ceiling_sprites: Array[Sprite3D] = []
	for child in ceiling.get_children():
		var sprite := child as Sprite3D
		if sprite == null:
			continue
		ceiling_sprites.append(sprite)
		var slot := roundi(sprite.position.x / ceiling.horizontal_panel_step)
		assert(slot >= -3 and slot <= 3)
		assert(is_equal_approx(
			sprite.position.x,
			slot * ceiling.horizontal_panel_step
		))
		assert(sprite.flip_h == (abs(slot) % 2 == 1))
		panel_counts[slot] = int(panel_counts.get(slot, 0)) + 1
	assert(ceiling_sprites.size() == 14)
	assert(panel_counts.size() == 7)
	for slot in range(-3, 4):
		assert(panel_counts.get(slot, 0) == 2)


func _validate_water_vista(
	level: LevelSession3D,
	node_name: StringName,
	expected_x: float,
	expected_y: float
) -> void:
	var vista := level.get_node(NodePath(node_name)) as PixelVistaWindow3D
	assert(vista != null, "%s is missing its localized water vista." % node_name)
	assert(is_equal_approx(vista.position.x, expected_x))
	assert(is_equal_approx(vista.authored_world_y(), expected_y))
	assert(
		vista.vertical_policy == PixelVistaWindow3D.VerticalPolicy.CAMERA_LOCKED,
		(
			"The lake keeps its authored horizontal opening but must stay "
			+ "vertically fixed on screen while the jump camera follows."
		)
	)
	assert(is_equal_approx(vista.vertical_offset, 0.02))
	assert(vista.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(vista.get_node_or_null("CeilingFill") == null)
	assert(vista.get_node_or_null("CaveCeiling") == null)
	var expected_layers := {
		"LakeAndRocks": {
			"region": Rect2(112.0, 150.0, 352.0, 174.0),
			"position_y": -5.0,
		},
		"DeepWaterFill": {
			"region": Rect2(112.0, 323.0, 352.0, 1.0),
			"position_y": -23.68,
			"scale_y": 760.0,
		},
	}
	for layer_name in expected_layers:
		var layer := vista.get_node(layer_name) as Sprite3D
		assert(layer != null, "%s/%s is missing." % [node_name, layer_name])
		assert(is_equal_approx(layer.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE))
		assert(layer.region_enabled)
		assert(layer.region_rect == expected_layers[layer_name]["region"])
		assert(is_equal_approx(
			layer.position.y,
			expected_layers[layer_name]["position_y"]
		))
		if expected_layers[layer_name].has("scale_y"):
			assert(is_equal_approx(
				layer.scale.y,
				expected_layers[layer_name]["scale_y"]
			))
		assert(layer.render_priority == -90)
		assert(not layer.shaded)
		assert(layer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _validate_wall_jump_camera_focus(level: LevelSession3D) -> void:
	var camera := level.camera as PixelSideCamera3D
	var original_player_position := level.player.global_position
	var player_was_processing := level.player.is_physics_processing()
	level.player.set_physics_process(false)
	var expected_camera_x := camera.snap_world_x(58.88)
	var expected_camera_y := camera.camera_height + camera.snap_world_y(20.0 - camera.camera_height)
	var minimum_measured_camera_x := INF
	var maximum_measured_camera_x := -INF
	for player_x in [56.72, 58.88, 61.04]:
		level.player.global_position = Vector3(player_x, 18.0, 0.0)
		camera.snap_to_target()
		await process_frame
		minimum_measured_camera_x = minf(
			minimum_measured_camera_x,
			camera.global_position.x
		)
		maximum_measured_camera_x = maxf(
			maximum_measured_camera_x,
			camera.global_position.x
		)
		assert(
			absf(camera.global_position.x - expected_camera_x)
			<= camera.world_units_per_screen_pixel(),
			"Wall-jump framing drifted away from the shaft focus."
		)
		assert(
			absf(camera.global_position.y - expected_camera_y)
			<= camera.world_units_per_screen_pixel(),
			"Horizontal shaft focus changed the climb's vertical camera tracking."
		)
	assert(
		absf(maximum_measured_camera_x - minimum_measured_camera_x)
		<= camera.world_units_per_screen_pixel(),
		"Crossing the wall-jump shaft made the camera chase the player horizontally."
	)
	level.player.global_position = original_player_position
	level.player.set_physics_process(player_was_processing)
	camera.snap_to_target()
	await process_frame


func _validate_vertical_background_behavior(
	level: LevelSession3D,
	background: PixelBackgroundRig3D
) -> void:
	var camera := level.camera as PixelSideCamera3D
	assert(camera != null)
	# Every backdrop in the upper chamber must ride the camera exactly on Y.
	# Horizontal localization remains independent of that vertical lock.
	# Let the camera and global background settle before recording a baseline.
	for frame in 2:
		await process_frame
	var original_player_position := level.player.global_position
	var baseline_camera_position := camera.global_position
	var baseline_camera_y := camera.global_position.y
	var ceiling := level.get_node("UpperCaveCeiling") as PixelCaveCeilingOverlay3D
	assert(ceiling != null)
	var baseline_ceiling_position := ceiling.global_position
	var baseline_background_y: Array[PackedFloat32Array] = []
	for layer_index in background.runtime_layer_count():
		var copy_y := PackedFloat32Array()
		for sprite in background.runtime_copies(layer_index):
			copy_y.append(sprite.global_position.y)
		baseline_background_y.append(copy_y)
		var row_centers := _unique_sorted_y(copy_y)
		assert(
			row_centers.size()
			== background.profile.layers[layer_index].world_row_count()
		)
		var row_height := (
			background.profile.layers[layer_index].texture.get_height()
			* background.profile.pixel_size
		)
		for row_index in range(1, row_centers.size()):
			assert(is_equal_approx(
				row_centers[row_index] - row_centers[row_index - 1],
				row_height
			))

	var vistas: Array[PixelVistaWindow3D] = [
		level.get_node("MachineShaftWaterVista") as PixelVistaWindow3D,
		level.get_node("DualMachineShaftWaterVista") as PixelVistaWindow3D,
	]
	var baseline_vista_y := PackedFloat32Array()
	var baseline_vista_child_y: Array[PackedFloat32Array] = []
	for vista in vistas:
		baseline_vista_y.append(vista.global_position.y)
		var child_y := PackedFloat32Array()
		for child in vista.get_children():
			if child is Node3D:
				child_y.append((child as Node3D).global_position.y)
		baseline_vista_child_y.append(child_y)

	level.player.set_physics_process(false)
	level.player.global_position = Vector3(
		107.52,
		28.7,
		0.0
	)
	camera.snap_to_target()
	background.snap_to_camera()
	# Let the camera and global background settle after this deliberate 28 m
	# teleport before comparing screen-relative and world-relative behavior.
	for frame in 6:
		await process_frame
	assert(camera.global_position.y > baseline_camera_y + 25.0)

	# The roof stays authored in the level on X, so walking does not carry it
	# along with the player. Its Y still rides the camera exactly, preserving the
	# established ceiling line through the tall transition.
	var camera_shift := camera.global_position - baseline_camera_position
	var camera_rise := camera.global_position.y - baseline_camera_y
	assert(is_equal_approx(
		ceiling.global_position.x,
		baseline_ceiling_position.x
	))
	assert(absf(camera_shift.x) > 1.0)
	assert(is_equal_approx(
		ceiling.global_position.y,
		baseline_ceiling_position.y + camera_rise
	))
	for layer_index in background.runtime_layer_count():
		var copies := background.runtime_copies(layer_index)
		assert(copies.size() == baseline_background_y[layer_index].size())
		for copy_index in copies.size():
			assert(
				is_equal_approx(
					copies[copy_index].global_position.y,
					baseline_background_y[layer_index][copy_index] + camera_rise
				),
				(
					"Cave layer %d moved relative to the screen during a "
					+ "%.2f m camera rise; jumping must not shift the background."
				) % [layer_index, camera_rise]
			)

	# The localized lake vistas keep their authored X but ride the camera on Y,
	# preventing the whole water composition from dropping on screen during a
	# jump. Their children must preserve exactly the same relative transform.
	for vista_index in vistas.size():
		var vista := vistas[vista_index]
		assert(
			is_equal_approx(
				vista.global_position.y,
				baseline_vista_y[vista_index] + camera_rise
			),
			"Vista %d moved relative to the screen during the camera rise."
			% vista_index
		)
		var child_index := 0
		for child in vista.get_children():
			if child is Node3D:
				assert(is_equal_approx(
					(child as Node3D).global_position.y,
					baseline_vista_child_y[vista_index][child_index]
						+ camera_rise
				))
				child_index += 1

	level.player.global_position = original_player_position
	camera.snap_to_target()
	background.snap_to_camera()


func _unique_sorted_y(values: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for value in values:
		var already_present := false
		for existing in result:
			if is_equal_approx(value, existing):
				already_present = true
				break
		if not already_present:
			result.append(value)
	result.sort()
	return result


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Level 2 interior opening validator aborted before completing.")
	quit(1)
