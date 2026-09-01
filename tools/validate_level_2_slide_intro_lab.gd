extends SceneTree
## Focused contract for the Level 2 cave-slide cutscene and its disposable lab.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame

	var definition := _developer_definition(
		game_root,
		&"dev_level_2_slide_intro_lab"
	)
	game_root.load_developer_level(definition)
	for frame in 4:
		await process_frame
	var lab := game_root.current_level as Level2SlideIntroLab
	assert(lab != null)
	assert(not lab.player.visible)
	assert(not lab.player.is_physics_processing())

	var cutscene := lab.cave_slide_intro
	assert(cutscene != null)
	assert(cutscene.validation_errors().is_empty())
	assert(cutscene.camera.current)
	assert(cutscene.camera.target == cutscene.camera_target)
	assert(cutscene.background.profile.profile_id == &"rock_underworks_cave")
	assert(cutscene.path_marker_paths.size() == 6)
	assert(cutscene.chute_rock_count == 39)
	assert(is_equal_approx(cutscene.slide_duration, 4.4))
	assert(is_equal_approx(cutscene.slide_contact_depth, 0.26))
	assert(absf(cutscene.terminal_horizontal_speed() - 8.0) < 0.15)
	assert(
		cutscene.slide_dust_puff_count()
		== cutscene.SLIDE_DUST_PUFF_COUNT
	)

	assert(
		cutscene.find_children("ChuteFloorRock*", "Sprite3D", true, false).size()
		== cutscene.chute_rock_count
	)
	var initial_camera_left := (
		cutscene.camera.minimum_center_x
		- cutscene.camera.size * 16.0 / 9.0 * 0.5
	)
	var uphill_rock_center := INF
	for node in cutscene.find_children("ChuteFloorRock*", "Sprite3D", true, false):
		uphill_rock_center = minf(
			uphill_rock_center,
			(node as Sprite3D).global_position.x
		)
	assert(
		uphill_rock_center < initial_camera_left - 1.0,
		"The uphill chute edge must remain safely outside the opening frame."
	)
	assert(cutscene.get_node_or_null("ChuteRoof") == null)
	assert(cutscene.get_node_or_null("LandingFill") == null)
	assert(cutscene.get_node_or_null("LandingRock") == null)
	assert(cutscene.get_node_or_null("Landing") == null)
	_validate_pixel_sizes(cutscene)

	cutscene.preview_slide_progress(0.5)
	await process_frame
	assert(cutscene.pixel_visual.current_state() == "wall_slide")
	assert(is_equal_approx(
		rad_to_deg(cutscene.visual_pivot.rotation.z),
		cutscene.slide_visual_angle_degrees
	))
	assert(cutscene.visual_pivot.position.is_equal_approx(
		cutscene.slide_contact_offset()
	))
	assert(is_equal_approx(
		cutscene.visual_pivot.position.length(),
		cutscene.slide_contact_depth
	))
	var middle_position := cutscene.puppet.global_position
	var first_marker := cutscene.get_node(
		cutscene.path_marker_paths.front()
	) as Marker3D
	assert(middle_position.x > first_marker.global_position.x + 2.0)
	assert(middle_position.y < first_marker.global_position.y - 2.0)
	assert(cutscene.visible_slide_dust_count() >= 3)

	cutscene.preview_slide_progress(0.94)
	await process_frame
	assert(cutscene.pixel_visual.current_state() == "wall_slide")
	assert(cutscene.puppet.global_position.x > middle_position.x + 8.0)
	assert(cutscene.puppet.global_position.y < middle_position.y - 4.0)

	var finish_count := [0]
	cutscene.finished.connect(
		func(_skipped: bool) -> void:
			finish_count[0] += 1
	)
	cutscene.play_from_start()
	cutscene.skip_to_end()
	assert(cutscene.has_finished())
	assert(cutscene.was_skipped())
	assert(cutscene.pixel_visual.current_state() == "wall_slide")
	assert(cutscene.puppet.global_position.is_equal_approx(
		cutscene.slide_exit_global_position()
	))
	assert(cutscene.visible_slide_dust_count() == 0)
	assert(finish_count[0] == 1)
	cutscene.skip_to_end()
	assert(finish_count[0] == 1)

	cutscene.slide_duration = 0.05
	cutscene.play_from_start()
	for frame in 20:
		await process_frame
		if cutscene.has_finished():
			break
	assert(cutscene.has_finished())
	assert(not cutscene.was_skipped())
	assert(finish_count[0] == 2)

	print(
		"Level 2 slide intro lab passed: extended slide, dust, exit, skip, and replay."
	)
	quit(0)


func _validate_pixel_sizes(cutscene: Level2CaveSlideIntro3D) -> void:
	for node in cutscene.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		var expected_size := PixelPlatform3D.TILE_PIXEL_SIZE
		if cutscene.puppet.is_ancestor_of(sprite):
			expected_size = 0.04375
		assert(
			is_equal_approx(sprite.pixel_size, expected_size),
			"%s has the wrong pixel size." % cutscene.get_path_to(sprite)
		)
		assert(not sprite.shaded)
		assert(
			sprite.cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)


func _developer_definition(
	game_root: Node,
	level_id: StringName
) -> LevelDefinition:
	for definition in game_root.developer_level_definitions:
		if definition != null and definition.level_id == level_id:
			return definition
	assert(false, "Missing developer level definition: %s" % level_id)
	return null
