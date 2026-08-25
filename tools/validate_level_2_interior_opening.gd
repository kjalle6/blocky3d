extends SceneTree
## Structural and progression contract for the first production Level 2 slice.

const DEFINITION_PATH := "res://resources/dev/level_2_interior_wip.tres"
const TILE_SIZE := PixelInteriorTerrain3D.TILE_WORLD_SIZE
const EXPECTED_DASH_GAP := 10.24
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
	assert(terrain.column_count() == 92)
	assert(
		terrain.collision_rectangle_count() == 10,
		"collision rectangles: %d" % terrain.collision_rectangle_count()
	)

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

	# The evasive-flyer chamber: a full-height break in the corridor with a
	# hovering machine in it. The break is open floor-to-sky, so nothing above
	# or below the machine can be mistaken for a route.
	for row in [5, 9, 11, 14, 20, 30, 39]:
		assert(
			not terrain.is_solid_cell(row, 73),
			"The gap must stay open through the corridor and out the bottom (row %d)." % row
		)
	# The gap has to read as endless, so it stays open far past anything the
	# camera shows. What closes it is a spiked lid rather than a floor: if the
	# movement kit ever grows enough to climb up there, the answer is death, not
	# a roof to stand on.
	for row in [0, 2, 4]:
		assert(
			terrain.is_solid_cell(row, 73),
			"The gap must be closed off well above the camera at row %d." % row
		)
	var ceiling_spikes := level.get_node(
		"Hazards/MachineShaftCeilingSpikes"
	) as PixelSpikeRow3D
	assert(ceiling_spikes != null, "The gap needs a lethal lid, not an open top.")
	assert(is_equal_approx(ceiling_spikes.position.y, 42.24))
	assert(is_equal_approx(ceiling_spikes.position.x, 94.08))
	assert(
		ceiling_spikes.row_width >= (79.0 - 68.0) * TILE_SIZE,
		"The lid must span the whole gap or it can be climbed around."
	)
	assert(
		ceiling_spikes.position.y > 33.28 + 6.4,
		"The lid must sit well above the corridor so it stays out of frame."
	)

	assert(terrain.is_solid_cell(16, 67), "Takeoff ledge must be solid.")
	assert(terrain.is_solid_cell(16, 79), "Landing ledge must be solid.")
	assert(not terrain.is_solid_cell(15, 67))
	assert(not terrain.is_solid_cell(15, 79))
	assert(terrain.is_solid_cell(13, 91), "The corridor must end in a back wall.")

	var shaft_gap := (79.0 - 68.0) * TILE_SIZE
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
	var run_up := 68.0 * TILE_SIZE - (69.12 + 10.24 * 0.5)
	assert(
		run_up >= 12.8 - 0.01,
		"Run-up to the machine is only %.2f m; it must stay long enough to read it." % run_up
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
	assert(is_equal_approx(dash_crossing_spikes.position.x, 69.12))
	assert(is_equal_approx(dash_crossing_spikes.row_width, EXPECTED_DASH_GAP))
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

	var takeoff_edge := 54.0 * TILE_SIZE
	var landing_edge := 62.0 * TILE_SIZE
	var dash_gap := landing_edge - takeoff_edge
	assert(is_equal_approx(dash_gap, EXPECTED_DASH_GAP))
	assert(
		dash_gap > level.player.movement.ideal_full_speed_jump_distance() * 1.6,
		"Upper crossing must clearly exceed the ordinary jump envelope."
	)

	var camera_region := level.get_node(
		"ShaftCameraRegion"
	) as VerticalCameraRegion3D
	assert(camera_region != null)
	assert(camera_region.validation_errors().is_empty())
	assert(camera_region.contains_world_position(Vector3(58.88, 18.0, 0)))
	assert(camera_region.contains_world_position(Vector3(80.0, 28.86, 0)))
	assert(is_equal_approx(camera_region.maximum_vertical_offset, 30.72))

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
	assert(
		not _blocked(level.player, Vector3(94.08, 28.86, 0), Vector3.DOWN),
		"The machine's shaft must be a real hole, not a floor with art removed."
	)

	print(
		"Level 2 interior opening passed: recap, shaft, turnback, %.2f m Dash crossing."
		% dash_gap
	)
	_completed = true
	quit(0)


func _blocked(body: CharacterBody3D, origin: Vector3, motion: Vector3) -> bool:
	return body.test_move(Transform3D(Basis.IDENTITY, origin), motion)


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Level 2 interior opening validator aborted before completing.")
	quit(1)
