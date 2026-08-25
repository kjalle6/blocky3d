extends SceneTree
## Structural and progression contract for the first production Level 2 slice.

const DEFINITION_PATH := "res://resources/dev/level_2_interior_wip.tres"
const TILE_SIZE := PixelInteriorTerrain3D.TILE_WORLD_SIZE
const EXPECTED_DASH_SPIKE_WIDTH := 13.28
const EXPECTED_DASH_SPIKE_LEFT_EDGE := 64.0
const EXPECTED_DASH_SPIKE_CENTER := (
	EXPECTED_DASH_SPIKE_LEFT_EDGE + EXPECTED_DASH_SPIKE_WIDTH * 0.5
)
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
	var definition := load(DEFINITION_PATH) as LevelDefinition
	assert(definition != null)
	assert(definition.validation_errors().is_empty())
	assert(definition.available_abilities == PlayerAbility.IMPLEMENTED)
	var expected_entry_abilities: Array[StringName] = [&"double_jump"]
	assert(definition.assumed_owned_abilities == expected_entry_abilities)

	var level := definition.scene.instantiate() as LevelSession3D
	assert(level != null)
	level.configure(definition, null, definition.assumed_owned_abilities)
	root.add_child(level)
	for frame in 4:
		await physics_frame

	var terrain := level.get_node("Platforms/RockShell") as PixelInteriorTerrain3D
	assert(terrain != null)
	assert(terrain.validation_errors().is_empty())
	assert(terrain.row_count() == 40)
	assert(terrain.column_count() == 113)
	assert(
		terrain.collision_rectangle_count() == 12,
		"collision rectangles: %d" % terrain.collision_rectangle_count()
	)

	# The editable Interior WIP owns two localized lake-cavern vistas. Their X
	# positions and every visual layer stay authored in world space; neither a
	# jump nor the shaft climb may drag cave art vertically with the camera.
	# The frozen transition snapshot deliberately has no such experiment.
	_validate_water_vista(level, "MachineShaftWaterVista", 94.08, 30.88)
	_validate_water_vista(level, "DualMachineShaftWaterVista", 120.96, 30.88)
	var background := level.get_node("Background") as PixelBackgroundRig3D
	assert(background != null and background.visible)
	assert(background.profile != null)
	assert(background.profile.profile_id == &"rock_underworks_cave")
	assert(background.profile.layers.size() == 2)
	assert(background.profile.validation_errors().is_empty())
	# Global cave art stays static on screen vertically, so a jump changes
	# nothing. The flat base is screen-locked on both axes; only the featured
	# distant composition parallax-scrolls as the player travels horizontally.
	#
	# Neither layer repeats vertically. Repeating featured art puts an identical
	# band overhead during a climb, which reads exactly like art that follows.
	for index in background.profile.layers.size():
		var layer := background.profile.layers[index]
		assert(
			layer.vertical_policy
			== PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED,
			(
				"Cave layer %d is not vertically static; jumping would move "
				+ "the background."
			) % index
		)
		assert(layer.world_repeat_below == 0 and layer.world_repeat_above == 0)

	# The base is unzoned continuous coverage; the distant composition is the
	# zoned layer that authored regions reveal.
	var base := background.profile.layers[0]
	assert(not base.is_zoned())
	assert(
		base.horizontal_policy
		== PixelBackgroundLayerProfile.HorizontalPolicy.SCREEN_LOCKED
	)
	var distant := background.profile.layers[1]
	assert(
		distant.zone_tag == &"upper",
		"The distant cave composition must stay zoned to the upper floor."
	)
	assert(
		distant.horizontal_policy
		== PixelBackgroundLayerProfile.HorizontalPolicy.PARALLAX
		and distant.horizontal_parallax > 0.0,
		"The distant composition must drift as the player walks."
	)
	var upper_region := level.get_node("UpperCaveBackgroundRegion") as PixelBackgroundRegion3D
	assert(upper_region != null, "The upper floor needs an authored background region.")
	assert(upper_region.validation_errors().is_empty())
	assert(
		upper_region.shows_zone(&"upper"),
		"The upper region must reveal the zone the distant layer is tagged with."
	)
	assert(
		upper_region.blend_margin >= 2.5 and upper_region.blend_exponent >= 1.5,
		(
			"The handoff must arrive rather than accumulate: a ramp that is "
			+ "short and back-loaded keeps the lower cave in its own treatment "
			+ "until the climb actually reaches the top."
		)
	)
	assert(upper_region.position.is_equal_approx(Vector3(94.08, 39.0, 0.0)))
	assert(upper_region.size.is_equal_approx(Vector2(110.0, 22.0)))
	var lower_face_y := upper_region.global_position.y - upper_region.size.y * 0.5
	var sample_x := upper_region.global_position.x
	assert(is_zero_approx(background.zone_opacity_at(
		distant,
		Vector3(sample_x, lower_face_y - upper_region.blend_margin - 0.1, 0.0)
	)))
	var blend_opacity := background.zone_opacity_at(
		distant,
		Vector3(sample_x, lower_face_y - upper_region.blend_margin * 0.5, 0.0)
	)
	assert(
		blend_opacity > 0.0 and blend_opacity < 1.0,
		"The upper cave region must produce a real partial-opacity blend."
	)
	assert(is_equal_approx(background.zone_opacity_at(
		distant,
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
	assert(terrain.is_solid_cell(11, 60))

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
	# cave roof bounds the WIP space, but it must remain harmless: the machine
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
	assert(terrain.is_solid_cell(13, 112), "The corridor must end in a back wall.")

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

	var camera_region := level.get_node(
		"ShaftCameraRegion"
	) as VerticalCameraRegion3D
	assert(camera_region != null)
	assert(camera_region.validation_errors().is_empty())
	assert(camera_region.contains_world_position(Vector3(58.88, 18.0, 0)))
	assert(camera_region.contains_world_position(Vector3(80.0, 28.86, 0)))
	assert(camera_region.contains_world_position(Vector3(120.96, 28.86, 0)))
	assert(
		is_equal_approx(camera_region.maximum_vertical_offset, 28.0),
		(
			"The shaft camera must clamp to the upper floor. Extra travel above "
			+ "28.0 m makes the entire cave shell follow an ordinary jump."
		)
	)

	# Contact probes make sure the authored art and collision agree at each beat.
	assert(_blocked(level.player, Vector3(4.48, 0.7, 0), Vector3.DOWN))
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
	assert(
		not _blocked(level.player, Vector3(94.08, 28.86, 0), Vector3.DOWN),
		"The machine's shaft must be a real hole, not a floor with art removed."
	)
	assert(
		not _blocked(level.player, Vector3(120.96, 28.86, 0), Vector3.DOWN),
		"The dual-machine shaft must be a real hole."
	)
	await _validate_vertical_background_behavior(level, background, camera_region)

	print(
		"Level 2 interior opening passed: recap, shaft, turnback, %.2f m Dash crossing."
		% dash_spike_width
	)
	_completed = true
	quit(0)


func _blocked(body: CharacterBody3D, origin: Vector3, motion: Vector3) -> bool:
	return body.test_move(Transform3D(Basis.IDENTITY, origin), motion)


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
	var expected_layers := {
		"CeilingFill": {
			"region": Rect2(112.0, 0.0, 352.0, 1.0),
			"position_y": 8.92,
			"scale_y": 122.0,
		},
		"CaveCeiling": {
			"region": Rect2(112.0, 0.0, 352.0, 87.0),
			"position_y": 4.74,
		},
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


func _validate_vertical_background_behavior(
	level: LevelSession3D,
	background: PixelBackgroundRig3D,
	camera_region: VerticalCameraRegion3D
) -> void:
	var camera := level.camera as PixelSideCamera3D
	assert(camera != null)
	# Every backdrop in the upper chamber must ride the camera exactly on Y.
	# Horizontal localization remains independent: the global layers cover the
	# viewport while each water vista stays attached to its authored shaft X.
	# Let the camera and global background settle before recording a baseline.
	for frame in 2:
		await process_frame
	var original_player_position := level.player.global_position
	var baseline_camera_y := camera.global_position.y
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
		camera_region.global_position.x,
		camera_region.vertical_anchor_world_y()
			+ camera_region.maximum_vertical_offset,
		0.0
	)
	camera.snap_to_target()
	background.snap_to_camera()
	# Let the camera and global background settle after this deliberate 28 m
	# teleport before comparing screen-relative and world-relative behavior.
	for frame in 6:
		await process_frame
	assert(camera.global_position.y > baseline_camera_y + 25.0)

	# Vertically static means the art must ride the camera exactly: same screen
	# position before and after a jump, which is the whole point.
	var camera_rise := camera.global_position.y - baseline_camera_y
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
					"Cave layer %d moved relative to the screen during a %.2f m "
					+ "camera rise; jumping must not shift the background."
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
