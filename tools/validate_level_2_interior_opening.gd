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
	assert(terrain.column_count() == 72)
	assert(terrain.collision_rectangle_count() == 6)

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
	assert(_blocked(level.player, Vector3(84.0, 28.86, 0), Vector3.DOWN))

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
