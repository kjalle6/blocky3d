extends SceneTree
## Structural, presentation, and isolated-session contract for the current
## production review slice: Shoreline, Green Threshold, Thorn Garden, and the
## open-air Double Jump rise.
##
## This validator proves that the authored route is technically coherent. It
## deliberately does not decide whether a jump is fun or appropriately hard;
## that remains a human playtest decision.

const EPSILON := 0.01


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := load(
		"res://resources/campaign/level_01.tres"
	) as LevelDefinition
	assert(definition != null)
	assert(definition.validation_errors().is_empty())
	assert(definition.level_id == &"arrival_shoreline")
	assert(definition.available_abilities == [PlayerAbility.DOUBLE_JUMP])
	assert(definition.assumed_owned_abilities.is_empty())
	assert(definition.required_abilities == [PlayerAbility.DOUBLE_JUMP])

	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	assert(game_root.campaign.find_by_id(definition.level_id) == definition)

	game_root.load_level(definition.level_id)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	for frame in 10:
		await physics_frame
	assert(level != null)
	assert(game_root.current_world_definition.world_id == &"green_zone")
	assert(game_root.current_level_definition == definition)
	assert(is_equal_approx(level.route_extent.length(), 203.52))
	assert(is_equal_approx(level.camera.maximum_center_x, 186.88))
	assert(is_equal_approx(level.camera.camera_height, 3.98))
	assert(is_equal_approx(level.camera.target_height, 3.98))
	assert(not level.camera.vertical_follow_enabled)
	assert(is_zero_approx(level.camera.rotation.x))
	assert(level.get_node("Platforms").get_child_count() == 15)
	assert(level.get_node("Checkpoints").get_child_count() == 2)
	assert(_scoped_group_count(level, &"melee_target") >= 6, "Preserve the six authored enemies and allow designer additions.")
	assert(_scoped_group_count(level, &"level_goal") == 0)
	assert(_scoped_group_count(level, &"level_transition") == 1)

	_validate_tools_ui(game_root)
	_validate_geometry(level)
	_validate_presentation(level)
	await _validate_water(level)
	await _validate_session(game_root, level, definition)

	print("Arrival / Shoreline through the open-air Double Jump rise validation passed.")
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _validate_tools_ui(game_root: Node) -> void:
	var instructions := game_root.get_node("Interface/Instructions") as Control
	var menu_hint := game_root.get_node("Interface/MenuHint") as Label
	assert(not instructions.visible)
	assert(menu_hint.visible)
	assert(
		menu_hint.text
		== "TAB: INVENTORY    F1: TOOLS    ESC: PAUSE"
	)
	_toggle_gameplay_tools(game_root)
	assert(instructions.visible)
	assert(
		menu_hint.text
		== "F1: HIDE    F7: HITBOXES    F10: GRID    F11: INSPECT    ESC: PAUSE"
	)
	assert(
		not (game_root.get_node(
			"Interface/DeveloperAbilityPanel"
		) as Control).visible,
		"Production Level 1 must not expose Firearm Review Lab ability toggles."
	)
	_toggle_gameplay_tools(game_root)
	assert(not instructions.visible)


func _validate_geometry(level: LevelSession3D) -> void:
	var sand := _platform(level, "SandArrival")
	var transition := _platform(level, "ShorelineTransition")
	var approach := _platform(level, "GreenApproach")
	var threshold_run := _platform(level, "ThresholdRun")
	var threshold_crown := _platform(level, "ThresholdCrown")
	var threshold_landing := _platform(level, "ThresholdLanding")
	var garden_entry := _platform(level, "ThornGardenEntry")
	var terrace := _platform(level, "ThornTerrace")
	var wall := _platform(level, "ThornWall")
	var garden_exit := _platform(level, "ThornGardenExit")
	var aerial_rise := _platform(level, "AerialRise")
	var aerial_crown := _platform(level, "AerialCrown")
	var aerial_dip := _platform(level, "AerialDip")
	var aerial_peak := _platform(level, "AerialPeak")
	var aerial_landing := _platform(level, "AerialLanding")

	# The approved shoreline and its biome seam stay untouched.
	_assert_platform(sand, Vector3(5.12, -1.28, 0), Vector3(10.24, 2.56, 2))
	_assert_platform(
		transition, Vector3(12.16, -1.28, 0), Vector3(3.84, 2.56, 2)
	)
	_assert_platform(
		approach, Vector3(19.84, -1.28, 0), Vector3(11.52, 3.84, 2)
	)
	assert(is_zero_approx(_gap(sand, transition)))
	assert(is_zero_approx(_gap(transition, approach)))

	# Green Threshold: one readable threat, the protected unlock, and an
	# immediate height proof which cannot be mistaken for a normal jump.
	_assert_platform(
		threshold_run, Vector3(34.56, -1.28, 0), Vector3(11.52, 3.84, 2)
	)
	_assert_platform(
		threshold_crown, Vector3(47.36, 3.2, 0), Vector3(5.12, 1.28, 2)
	)
	_assert_platform(
		threshold_landing, Vector3(59.52, -0.64, 0), Vector3(10.24, 3.84, 2)
	)
	assert(is_equal_approx(_gap(approach, threshold_run), 3.2))
	assert(is_equal_approx(_gap(threshold_run, threshold_crown), 4.48))
	assert(is_equal_approx(_top(threshold_crown) - _top(threshold_run), 3.2))
	assert(is_equal_approx(_gap(threshold_crown, threshold_landing), 4.48))

	# Thorn Garden is terrain-shaped: two lethal sunken beds separated by
	# raised safe ground, followed by a committed descent to the exit.
	_assert_platform(
		garden_entry, Vector3(73.6, -1.28, 0), Vector3(10.24, 3.84, 2)
	)
	_assert_platform(
		terrace, Vector3(90.24, 0, 0), Vector3(7.68, 3.84, 2)
	)
	_assert_platform(wall, Vector3(103.04, 1.28, 0), Vector3(7.68, 3.84, 2))
	_assert_platform(
		garden_exit, Vector3(119.04, -1.28, 0), Vector3(15.36, 3.84, 2)
	)
	assert(is_equal_approx(_gap(threshold_landing, garden_entry), 3.84))
	assert(is_equal_approx(_gap(garden_entry, terrace), 7.68))
	assert(is_equal_approx(_gap(terrace, wall), 5.12))
	assert(is_equal_approx(_gap(wall, garden_exit), 4.48))
	assert(_top(terrace) > _top(garden_entry))
	assert(_top(wall) > _top(terrace))

	# The new phrase stays outside and develops Double Jump over one continuous
	# visible thorn floor. Its alternating silhouette rises, dips, rises again,
	# then asks the player to carry the final descent forward.
	_assert_platform(
		aerial_rise, Vector3(131.84, 3.2, 0), Vector3(3.84, 1.28, 2)
	)
	_assert_platform(
		aerial_crown, Vector3(142.08, 5.76, 0), Vector3(3.84, 1.28, 2)
	)
	_assert_platform(
		aerial_dip, Vector3(151.04, 3.84, 0), Vector3(3.84, 1.28, 2)
	)
	_assert_platform(
		aerial_peak, Vector3(160, 7.04, 0), Vector3(3.84, 1.28, 2)
	)
	_assert_platform(
		aerial_landing, Vector3(181.76, -1.28, 0), Vector3(46.08, 3.84, 2)
	)
	assert(is_equal_approx(_gap(garden_exit, aerial_rise), 3.2))
	assert(is_equal_approx(_gap(aerial_rise, aerial_crown), 6.4))
	assert(is_equal_approx(_gap(aerial_crown, aerial_dip), 5.12))
	assert(is_equal_approx(_gap(aerial_dip, aerial_peak), 5.12))
	assert(_left(aerial_landing) < aerial_peak.global_position.x)
	assert(_right(aerial_landing) > _right(aerial_peak))
	assert(_top(aerial_rise) < _top(aerial_crown))
	assert(_top(aerial_dip) < _top(aerial_crown))
	assert(_top(aerial_peak) > _top(aerial_crown))
	assert(_top(aerial_landing) < _top(aerial_dip))
	assert(
		_right(aerial_landing)
		> level.camera.maximum_center_x + level.camera.size * 16.0 / 9.0 * 0.5,
		"The flat tire-swing clearing must continue beyond the final camera frame."
	)

	var spike_contracts := [["ThresholdSpikes", threshold_run, 1.8]]
	for contract in spike_contracts:
		var spikes := level.get_node("Hazards/%s" % contract[0]) as PixelSpikeRow3D
		var support := contract[1] as PixelPlatform3D
		assert(spikes != null)
		assert(is_equal_approx(spikes.global_position.y, _top(support)))
		assert(is_equal_approx(spikes.row_width, float(contract[2])))
		assert(spikes.global_position.x - spikes.row_width * 0.5 >= _left(support))
		assert(spikes.global_position.x + spikes.row_width * 0.5 <= _right(support))
	var basin_spikes := level.get_node(
		"Hazards/ThornBasinASpikes"
	) as PixelSpikeRow3D
	var pocket_spikes := level.get_node(
		"Hazards/ThornPocketSpikes"
	) as PixelSpikeRow3D
	assert(is_equal_approx(basin_spikes.row_width, 6.2))
	assert(is_equal_approx(basin_spikes.global_position.x, 82.56))
	assert(is_equal_approx(basin_spikes.global_position.y, -2.4))
	assert(
		basin_spikes.global_position.x - basin_spikes.row_width * 0.5
		> _right(garden_entry)
	)
	assert(
		basin_spikes.global_position.x + basin_spikes.row_width * 0.5
		< _left(terrace)
	)
	assert(is_equal_approx(pocket_spikes.row_width, 4.0))
	assert(is_equal_approx(pocket_spikes.global_position.x, 96.64))
	assert(is_equal_approx(pocket_spikes.global_position.y, -2.4))
	assert(
		is_equal_approx(
			basin_spikes.global_position.y,
			pocket_spikes.global_position.y
		),
		"Both open thorn beds must read as one consistent low spike floor."
	)
	assert(
		pocket_spikes.global_position.x - pocket_spikes.row_width * 0.5
		> _right(terrace)
	)
	assert(
		pocket_spikes.global_position.x + pocket_spikes.row_width * 0.5
		< _left(wall)
	)
	assert(
		level.get_node_or_null("Platforms/ThornBasinA") == null
		and level.get_node_or_null("Platforms/ThornPocket") == null,
		"Long thorn beds must be open spike pits, not decorated platforms."
	)
	var aerial_basin := level.get_node(
		"Hazards/AerialBasinSpikes"
	) as PixelSpikeRow3D
	var blind_landing := level.get_node(
		"Hazards/BlindLandingSpikes"
	) as PixelSpikeRow3D
	assert(aerial_basin != null and blind_landing != null)
	assert(is_equal_approx(aerial_basin.global_position.y, -2.4))
	assert(is_equal_approx(aerial_basin.row_width, 32.0))
	assert(is_equal_approx(
		aerial_basin.global_position.x - aerial_basin.row_width * 0.5,
		_right(garden_exit)
	))
	assert(is_equal_approx(
		aerial_basin.global_position.x + aerial_basin.row_width * 0.5,
		_left(aerial_landing)
	))
	assert(is_equal_approx(blind_landing.global_position.y, _top(aerial_landing)))
	assert(is_equal_approx(blind_landing.row_width, 8.272))
	var blind_spike_count := roundi(
		blind_landing.row_width / blind_landing.spike_height
	)
	assert(blind_spike_count == 11)
	var blind_spike_pitch := (
		blind_landing.row_width / float(blind_spike_count)
	)
	assert(absf(
		blind_landing.global_position.x
		- blind_landing.row_width * 0.5
		+ blind_spike_pitch * 0.5
		- 159.52
	) < 0.001)
	assert(absf(
		blind_landing.global_position.x
		+ blind_landing.row_width * 0.5
		- blind_spike_pitch * 0.5
		- 167.04
	) < 0.001)
	assert(blind_landing.global_position.x + blind_landing.row_width * 0.5 < _right(aerial_landing))
	var blind_drop_x := 167.04
	assert(
		blind_landing.global_position.x - blind_landing.row_width * 0.5
		<= blind_drop_x
		and blind_landing.global_position.x + blind_landing.row_width * 0.5
		>= blind_drop_x,
		"An ordinary forward drop beyond the final high platform must meet the concealed spikes."
	)

	var camera_region := level.get_node(
		"DoubleJumpRiseCameraRegion"
	) as VerticalCameraRegion3D
	assert(camera_region != null)
	assert(camera_region.validation_errors().is_empty())
	assert(camera_region.contains_world_position(Vector3(120.0, 1.19, 0.0)))
	assert(camera_region.contains_world_position(Vector3(160.0, 8.23, 0.0)))
	assert(is_equal_approx(camera_region.maximum_vertical_offset, 7.04))
	var peak_camera_bottom: float = (
		level.camera.camera_height
		+ camera_region.maximum_vertical_offset
		- level.camera.size * 0.5
	)
	var blind_spike_tip: float = (
		blind_landing.global_position.y + blind_landing.spike_height
	)
	assert(
		blind_spike_tip < peak_camera_bottom,
		"The final spike must exist normally but sit below the peak composition."
	)

	var enemy_contracts := [
		["ApproachPatrol", approach, 1.7],
		["ThresholdLandingPatrol", threshold_landing, 1.7],
		["ThornWallPatrol", wall, 1.7],
		["SkateRampPatrol", garden_exit, 2.0],
		["AerialDipPatrol", aerial_dip, 1.7],
		["AerialLandingPatrol", aerial_landing, 1.7],
	]
	for contract in enemy_contracts:
		var enemy := level.get_node(str(contract[0])) as StompableEnemy3D
		var support := contract[1] as PixelPlatform3D
		assert(enemy != null)
		assert(is_equal_approx(enemy.patrol_speed, float(contract[2])))
		assert(absf(enemy.global_position.y - (_top(support) + 0.38)) < 0.02)
		assert(enemy.global_position.x > _left(support))
		assert(enemy.global_position.x < _right(support))
	var skater := level.get_node("SkateRampPatrol") as StompableEnemy3D
	assert(is_zero_approx(skater.patrol_left_distance))
	assert(is_zero_approx(skater.patrol_right_distance))
	assert(skater.pixel_visual.animation_textures.size() == 4)
	skater.pixel_visual.set_state("attack", true)
	assert(skater.pixel_visual.hframes == 4)
	skater.pixel_visual.set_state("walk", true)
	assert(skater.pixel_visual.hframes == 6)
	var aerial_dip_enemy := level.get_node(
		"AerialDipPatrol"
	) as StompableEnemy3D
	var aerial_landing_enemy := level.get_node(
		"AerialLandingPatrol"
	) as StompableEnemy3D
	assert(is_zero_approx(aerial_dip_enemy.patrol_left_distance))
	assert(is_zero_approx(aerial_dip_enemy.patrol_right_distance))
	assert(is_equal_approx(aerial_landing_enemy.patrol_left_distance, 10.5))
	assert(is_equal_approx(aerial_landing_enemy.patrol_right_distance, 5.1))
	assert(
		aerial_dip_enemy.global_position.x > _left(aerial_dip)
		and aerial_dip_enemy.global_position.x < _right(aerial_dip),
		"The aerial dip patrol must begin on its support and use natural ledge reversal."
	)
	var landing_patrol_bounds := aerial_landing_enemy.authored_patrol_bounds_x()
	assert(
		landing_patrol_bounds.x
		> blind_landing.global_position.x + blind_landing.row_width * 0.5
		and landing_patrol_bounds.x
		< blind_landing.global_position.x + blind_landing.row_width * 0.5 + 0.6,
		"The landing patrol must walk up to the blind spikes without entering them."
	)
	assert(
		landing_patrol_bounds.y > 183.0
		and landing_patrol_bounds.y < 184.0
		and _right(aerial_landing) - landing_patrol_bounds.y > 7.0,
		"The landing patrol must end before the safe finish clearing."
	)

	var pickup := level.get_node("DoubleJumpPickup") as AbilityPickup3D
	var pickup_checkpoint := level.get_node(
		"Checkpoints/PickupCheckpoint"
	) as LevelCheckpoint3D
	var exit_checkpoint := level.get_node(
		"Checkpoints/ThornGardenExitCheckpoint"
	) as LevelCheckpoint3D
	assert(is_equal_approx(pickup.global_position.x, 36.2))
	assert(is_equal_approx(pickup.global_position.y, _top(threshold_run)))
	assert(pickup.global_position.x > _right(level.get_node(
		"Hazards/ThresholdSpikes"
	) as PixelSpikeRow3D))
	assert(pickup_checkpoint.route_index == 2)
	assert(pickup_checkpoint.global_position == pickup.global_position)
	assert(exit_checkpoint.route_index == 3)
	assert(is_equal_approx(exit_checkpoint.global_position.y, _top(garden_exit)))
	var level_2_transition := level.get_node(
		"Level2Transition"
	) as LevelTransition3D
	assert(level_2_transition != null)
	assert(level_2_transition.validation_errors().is_empty())
	assert(level_2_transition.target_level != null)
	assert(level_2_transition.target_level.level_id == &"overgrown_coastal_ascent")
	assert(level_2_transition.target_scene == null)
	assert(level_2_transition.completes_source_level)
	assert(level_2_transition.source_exit_mode == LevelTransition3D.SourceExitMode.RUN)
	assert(level_2_transition.run_destination_during_fade_in)
	assert(level_2_transition.global_position.x > exit_checkpoint.global_position.x)
	assert(level_2_transition.global_position.x > _left(aerial_landing))
	assert(level_2_transition.global_position.x < _right(aerial_landing))
	assert(is_equal_approx(level_2_transition.global_position.y, _top(aerial_landing)))

	var kill_plane := level.get_node("KillPlane") as Area3D
	var kill_shape := kill_plane.get_node("Collision") as CollisionShape3D
	var kill_box := kill_shape.shape as BoxShape3D
	assert(
		kill_plane.global_position.x - kill_box.size.x * 0.5
		<= level.route_extent.route_start_x
	)
	assert(
		kill_plane.global_position.x + kill_box.size.x * 0.5
		>= level.route_extent.route_end_x
	)
	assert(kill_plane.global_position.y + kill_box.size.y * 0.5 < -3.0)


func _validate_presentation(level: LevelSession3D) -> void:
	var sand := _platform(level, "SandArrival")
	var transition := _platform(level, "ShorelineTransition")
	var approach := _platform(level, "GreenApproach")
	assert(sand.style.resource_path.ends_with("shoreline_sand.tres"))
	assert(transition.style.resource_path.ends_with("shoreline_to_green.tres"))
	assert(approach.style.resource_path.ends_with("green_zone.tres"))
	assert(not sand.cap_right_edge)
	assert(transition.cap_left_edge and transition.cap_right_edge)
	assert(approach.style.has_deep_row() and approach.style.has_bottom_row())

	var player_body := level.player.get_node("PixelVisual/Body") as Sprite3D
	var support_contracts := {
		"TransitionBush": _top(approach),
		"ApproachTree": _top(approach),
		"ApproachTreeBush": _top(approach),
		"ApproachGrass": _top(approach),
		"ThresholdBush": _top(_platform(level, "ThresholdRun")),
		"ThresholdGrass": _top(_platform(level, "ThresholdRun")),
		"ThresholdLandingStone": _top(_platform(level, "ThresholdLanding")),
		"ThresholdLandingTree": _top(_platform(level, "ThresholdLanding")),
		"ThresholdLandingBush": _top(_platform(level, "ThresholdLanding")),
		"GardenEntryTree": _top(_platform(level, "ThornGardenEntry")),
		"GardenEntryBush": _top(_platform(level, "ThornGardenEntry")),
		"ThornEdgeStone": _top(_platform(level, "ThornGardenEntry")),
		"ThornTerraceHedgeLeftEnd": _top(_platform(level, "ThornTerrace")),
		"ThornTerraceHedgeLeftCap": _top(_platform(level, "ThornTerrace")),
		"ThornTerraceHedgeRightEnd": _top(_platform(level, "ThornTerrace")),
		"ThornTerraceHedgeRightCap": _top(_platform(level, "ThornTerrace")),
		"ThornTerraceGrass": _top(_platform(level, "ThornTerrace")),
		"ThornWallGrass": _top(_platform(level, "ThornWall")),
		"ThornWallHedgeLeftEnd": _top(_platform(level, "ThornWall")),
		"ThornWallHedgeLeftCap": _top(_platform(level, "ThornWall")),
		"ThornWallHedgeRightEnd": _top(_platform(level, "ThornWall")),
		"ThornWallHedgeRightCap": _top(_platform(level, "ThornWall")),
		"GardenExitBench": _top(_platform(level, "ThornGardenExit")),
		"GardenExitTree": _top(_platform(level, "ThornGardenExit")),
		"GardenExitSkateRamp": _top(_platform(level, "ThornGardenExit")),
		"GardenExitSkateRampLeft": _top(_platform(level, "ThornGardenExit")),
		"GardenExitGrass": _top(_platform(level, "ThornGardenExit")),
		"AerialRiseBush": _top(_platform(level, "AerialRise")),
		"AerialRiseGrass": _top(_platform(level, "AerialRise")),
		"AerialCrownGrass": _top(_platform(level, "AerialCrown")),
		"AerialCrownBush": _top(_platform(level, "AerialCrown")),
		"AerialDipBush": _top(_platform(level, "AerialDip")),
		"AerialDipGrass": _top(_platform(level, "AerialDip")),
		"AerialPeakGrass": _top(_platform(level, "AerialPeak")),
		"AerialPeakBush": _top(_platform(level, "AerialPeak")),
		"AerialLandingBush": _top(_platform(level, "AerialLanding")),
		"AerialLandingTree": _top(_platform(level, "AerialLanding")),
		"AerialLandingStone": _top(_platform(level, "AerialLanding")),
		"AerialLandingGrass": _top(_platform(level, "AerialLanding")),
		"AerialExitApproachGrass": _top(_platform(level, "AerialLanding")),
		"AerialExitApproachStone": _top(_platform(level, "AerialLanding")),
		"AerialExitTrailBush": _top(_platform(level, "AerialLanding")),
		"AerialExitTrailGrass": _top(_platform(level, "AerialLanding")),
		"AerialExitTireSwingTree": _top(_platform(level, "AerialLanding")),
	}
	for prop_name in support_contracts:
		var prop := level.get_node("Props/%s" % prop_name) as Sprite3D
		assert(prop != null)
		assert(prop.texture != null)
		assert(prop.global_position.z < player_body.global_position.z)
		assert(prop.render_priority < player_body.render_priority)
		assert(prop.find_children("*", "CollisionObject3D", true, false).is_empty())
		var visible_bottom := _sprite_visible_bottom(prop)
		assert(
			absf(visible_bottom - float(support_contracts[prop_name])) <= 0.08,
			"%s must visually touch its authored terrain support." % prop.name
		)
		assert(
			visible_bottom <= float(support_contracts[prop_name]) + EPSILON,
			"%s must never float above its authored terrain support." % prop.name
		)

	var player_weapon := level.player.get_node("PixelVisual/Weapon") as Sprite3D
	var enemy_visual := level.get_node(
		"ThornWallPatrol/PixelVisual"
	) as Sprite3D
	var foreground_gates := {
		"ThornTerraceGate": _top(_platform(level, "ThornTerrace")),
		"ThornWallGate": _top(_platform(level, "ThornWall")),
	}
	for gate_name in foreground_gates:
		var gate := level.get_node("Props/%s" % gate_name) as Sprite3D
		assert(gate != null and gate.texture != null)
		var clean_gate_texture := gate.texture as AtlasTexture
		assert(clean_gate_texture != null)
		assert(clean_gate_texture.region == Rect2(1, 2, 33, 60))
		assert(
			clean_gate_texture.atlas.resource_path.ends_with(
				"garden_gate_open.png"
			),
			"Foreground gates must retain the tab-free source crop."
		)
		assert(gate.global_position.z > player_body.global_position.z)
		assert(gate.global_position.z > enemy_visual.global_position.z)
		assert(gate.render_priority > player_weapon.render_priority)
		assert(gate.render_priority > enemy_visual.render_priority)
		assert(gate.find_children("*", "CollisionObject3D", true, false).is_empty())
		assert(
			absf(_sprite_visible_bottom(gate) - float(foreground_gates[gate_name]))
			<= 0.08,
			"%s must remain seated in its authored terrain support." % gate.name
		)

	var transition_talus := level.get_node("Props/TransitionTalus") as Node3D
	assert(transition_talus.get_child_count() >= 5)
	for child in transition_talus.get_children():
		var rock := child as Sprite3D
		assert(rock != null)
		assert(rock.global_position.z < player_body.global_position.z)
		assert(rock.render_priority < player_body.render_priority)
		assert(rock.find_children("*", "CollisionObject3D", true, false).is_empty())

	assert(level.get_node_or_null("Props/TrailheadSlopeMass") == null)
	assert(level.get_node_or_null("Platforms/TrailheadEmbankment") == null)

	var background := level.background
	assert(background != null)
	assert(background.profile != null)
	assert(background.profile.profile_id == &"arrival_shoreline")
	assert(background.profile.validation_errors().is_empty())
	assert(is_equal_approx(background.profile.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE))


func _validate_water(level: LevelSession3D) -> void:
	var water := level.get_node("Hazards/ShoreWater") as PixelWaterStrip3D
	assert(water != null)
	assert(is_equal_approx(water.width, 12.8))
	assert(water.body_rows == 3)
	assert(water.frame_count == 4)
	assert(water.runtime_tile_count() == 40)
	assert(is_zero_approx(water.global_position.x + water.width * 0.5))
	var initial_frame := water.current_frame()
	for frame in 10:
		await physics_frame
	assert(water.current_frame() != initial_frame)

	var water_contact := level.get_node(
		"Hazards/ShoreWaterContact"
	) as Hazard3D
	assert(water_contact.death_kind == PlayerCharacter.DEATH_KIND_WATER)
	var wave := level.get_node("ShoreWave") as PixelShoreWave3D
	assert(wave.crest_count() == 3)
	assert(wave.crest_offsets_x.size() == wave.crest_delays.size())
	assert(is_equal_approx(wave.global_position.x + wave.shoreline_x, 0.0))
	assert(is_equal_approx(wave.crest_sprite(0).pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE))
	assert(is_equal_approx(wave.shore_foam_sprite().pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE))
	for crest_index in wave.crest_count():
		assert(not wave.crest_sprite(crest_index).flip_h)
		assert(wave.crest_sprite(crest_index).global_position.z < water.face_depth)


func _validate_session(
	game_root: Node,
	level: LevelSession3D,
	definition: LevelDefinition
) -> void:
	var player := level.player
	var pickup := level.get_node("DoubleJumpPickup") as AbilityPickup3D
	var pickup_checkpoint := level.get_node(
		"Checkpoints/PickupCheckpoint"
	) as LevelCheckpoint3D
	var exit_checkpoint := level.get_node(
		"Checkpoints/ThornGardenExitCheckpoint"
	) as LevelCheckpoint3D
	assert(not player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not pickup.is_claimed())
	assert(not pickup_checkpoint.is_activated())
	assert(not exit_checkpoint.is_activated())

	var water_splash := level.get_node(
		"WaterDeathSplash"
	) as PixelWaterDeathSplash3D
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.2, 0)))
	for frame in 10:
		await physics_frame
		if player.is_dead():
			break
	assert(player.is_dead())
	assert(player.death_kind() == PlayerCharacter.DEATH_KIND_WATER)
	assert(water_splash.is_playing())
	assert(water_splash.splash_audio != null)
	assert(water_splash.splash_audio.playing)
	assert(water_splash.splash_audio.stream.get_length() > 0.0)
	var splash_start_volume := water_splash.splash_audio.volume_linear
	var splash_faded := false
	var water_wait_started := Time.get_ticks_msec()
	for frame in 240:
		await physics_frame
		if water_splash.splash_audio.playing and water_splash.splash_audio.volume_linear < splash_start_volume * 0.8:
			splash_faded = true
		if not player.is_dead():
			break
	assert(not player.is_dead())
	assert(not splash_faded, "Current splash audition should play without a fade.")
	var water_wait_seconds := float(Time.get_ticks_msec() - water_wait_started) / 1000.0
	assert(water_wait_seconds >= 1.5 and water_wait_seconds < 2.0,
		"Beach water respawn should take 1.7 seconds, not wait for the silent clip tail.")
	assert(absf(player.global_position.x - 1.8) < 0.2)

	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(36.2, 1.34, 0)))
	for frame in 16:
		await physics_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup.is_claimed())
	assert(pickup_checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 2)
	player.kill()
	for frame in 40:
		await physics_frame
	assert(not player.is_dead())
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup.is_claimed())
	assert(absf(player.global_position.x - 36.2) < 0.2)

	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(120.0, 1.34, 0)))
	for frame in 16:
		await physics_frame
	assert(exit_checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 3)
	player.kill()
	for frame in 40:
		await physics_frame
	assert(not player.is_dead())
	assert(absf(player.global_position.x - 120.0) < 0.2)

	var completion_fade := game_root.get_node("Interface/CompletionFade") as ColorRect
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	assert(not completion_fade.visible)
	assert(not completion_label.visible)

	level._reset_run()
	await physics_frame
	assert(not completion_fade.visible)
	assert(not completion_label.visible)
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup.is_claimed())
	assert(not pickup_checkpoint.is_activated())
	assert(not exit_checkpoint.is_activated())

	game_root.show_level_select()
	game_root.load_level(definition.level_id)
	await process_frame
	var fresh_level := game_root.current_level as LevelSession3D
	assert(fresh_level != level)
	assert(not fresh_level.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not (fresh_level.get_node("DoubleJumpPickup") as AbilityPickup3D).is_claimed())
	for checkpoint in fresh_level.get_node("Checkpoints").get_children():
		assert(not (checkpoint as LevelCheckpoint3D).is_activated())

	var level_2_transition := fresh_level.get_node(
		"Level2Transition"
	) as LevelTransition3D
	var fresh_player := fresh_level.player
	level_2_transition._on_body_entered(fresh_player)
	await physics_frame
	assert(fresh_player.is_transition_running())
	assert(fresh_player.horizontal_speed > 0.0)
	assert(not completion_label.visible)
	await create_timer(0.3).timeout
	assert(completion_fade.visible)
	assert(completion_fade.modulate.a > 0.2)
	assert(not completion_label.visible)
	await create_timer(0.35).timeout
	assert(game_root.current_level_definition.level_id == &"overgrown_coastal_ascent")
	assert(game_root.current_world_definition.world_id == &"green_zone")
	assert(game_root.current_level != fresh_level)
	assert(game_root.current_level.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(game_root.current_level.player.is_transition_running())
	assert(not completion_label.visible)
	await create_timer(0.5).timeout
	assert(not game_root.current_level.player.is_transition_running())


func _assert_platform(
	platform: PixelPlatform3D,
	expected_position: Vector3,
	expected_size: Vector3
) -> void:
	assert(platform != null)
	assert(platform.position.is_equal_approx(expected_position))
	assert(platform.size.is_equal_approx(expected_size))
	assert(
		absf(platform.size.x / PixelPlatform3D.TILE_WORLD_SIZE
		- roundf(platform.size.x / PixelPlatform3D.TILE_WORLD_SIZE)) < EPSILON
	)
	assert(
		absf(platform.size.y / PixelPlatform3D.TILE_WORLD_SIZE
		- roundf(platform.size.y / PixelPlatform3D.TILE_WORLD_SIZE)) < EPSILON
	)


func _sprite_visible_bottom(sprite: Sprite3D) -> float:
	var used_rect := sprite.texture.get_image().get_used_rect()
	var half_height := float(sprite.texture.get_height()) * 0.5
	return (
		sprite.global_position.y
		+ (half_height - float(used_rect.end.y))
		* sprite.pixel_size
		* absf(sprite.scale.y)
	)


func _scoped_group_count(level: LevelSession3D, group: StringName) -> int:
	return get_nodes_in_group(group).filter(
		func(node: Node) -> bool:
			return level.is_ancestor_of(node)
	).size()


func _toggle_gameplay_tools(game_root: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F1
	game_root._unhandled_input(event)


func _platform(level: LevelSession3D, node_name: String) -> PixelPlatform3D:
	return level.get_node("Platforms/%s" % node_name) as PixelPlatform3D


func _left(platform: Node3D) -> float:
	var size: Vector3 = platform.get("size") if platform.has_method("get") else Vector3.ZERO
	if platform is PixelSpikeRow3D:
		return platform.global_position.x - (platform as PixelSpikeRow3D).row_width * 0.5
	return platform.global_position.x - size.x * 0.5


func _right(platform: Node3D) -> float:
	if platform is PixelSpikeRow3D:
		return platform.global_position.x + (platform as PixelSpikeRow3D).row_width * 0.5
	var size: Vector3 = platform.get("size")
	return platform.global_position.x + size.x * 0.5


func _top(platform: PixelPlatform3D) -> float:
	return platform.global_position.y + platform.size.y * 0.5


func _gap(left_platform: PixelPlatform3D, right_platform: PixelPlatform3D) -> float:
	return _left(right_platform) - _right(left_platform)
