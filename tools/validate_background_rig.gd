extends SceneTree
## Production contract for native-scale backgrounds, deterministic recycling,
## flat-camera projection, and vertical-camera coverage.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const WIDE_OUTPUT_SIZE := Vector2i(2560, 1080)
const EPSILON := 0.05


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame

	var arrival_definition := load(
		"res://resources/campaign/level_01.tres"
	) as LevelDefinition
	game_root.load_level(arrival_definition.level_id)
	await process_frame
	var arrival := game_root.current_level as LevelSession3D
	for frame in 3:
		await process_frame
	_validate_arrival_projection(arrival)
	_validate_profile_and_imports(arrival.background.profile)
	_validate_transition_anchor(arrival)

	var camera := arrival.camera as PixelSideCamera3D
	var background := arrival.background as PixelBackgroundRig3D
	assert(background.has_node("GeneratedLayers"))
	arrival.player.set_physics_process(false)
	_set_camera_center(arrival, camera.minimum_center_x)
	var cloud_world_phases := []
	for cloud_index in 2:
		cloud_world_phases.append(_layer_world_phase(background, cloud_index))
	var stable_ids := _copy_instance_ids(background)
	for center_x in [
		camera.minimum_center_x,
		16.0,
		23.0,
		34.0,
		45.0,
		58.0,
		camera.maximum_center_x,
		camera.minimum_center_x,
	]:
		_set_camera_center(arrival, center_x)
		_assert_horizontal_coverage(background, camera, OUTPUT_SIZE.x)
		assert(
			_copy_instance_ids(background) == stable_ids,
			"Camera travel and teleports must recycle existing Sprite3D copies."
		)
		for cloud_index in 2:
			var current_phase := _layer_world_phase(background, cloud_index)
			var repeat_step := (
				background.profile.layers[cloud_index].repeat_step_pixels()
				* background.profile.pixel_size
			)
			var phase_error := absf(
				current_phase - cloud_world_phases[cloud_index]
			)
			phase_error = minf(phase_error, repeat_step - phase_error)
			assert(
				phase_error < 0.002,
				(
					"World-locked cloud track %d changed phase from %.6f to %.6f."
					% [cloud_index, cloud_world_phases[cloud_index], current_phase]
				)
			)
	background.position = Vector3(3.0, 2.0, 1.0)
	background.snap_to_camera()
	_assert_horizontal_coverage(background, camera, OUTPUT_SIZE.x)
	assert(
		_copy_instance_ids(background) == stable_ids,
		"Moving the rig must not replace its runtime-owned sprite pool."
	)
	background.position = Vector3.ZERO
	background.snap_to_camera()

	root.content_scale_size = WIDE_OUTPUT_SIZE
	root.size = WIDE_OUTPUT_SIZE
	await process_frame
	background.snap_to_camera()
	_assert_horizontal_coverage(background, camera, WIDE_OUTPUT_SIZE.x)
	var visible_width := camera.size * WIDE_OUTPUT_SIZE.x / WIDE_OUTPUT_SIZE.y
	for layer_index in background.runtime_layer_count():
		var layer := background.profile.layers[layer_index]
		var repeat_step := layer.repeat_step_pixels() * background.profile.pixel_size
		var required_copies := maxi(3, ceili(visible_width / repeat_step) + 2)
		assert(
			background.runtime_copies(layer_index).size() >= required_copies,
			"Ultrawide layout requires a persistent correctly sized sprite pool."
		)

	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	await process_frame
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	await _validate_vertical_fixture(game_root, &"wall_jump", 14.5)
	await _validate_vertical_fixture(game_root, &"green_zone_finale", 16.5)

	print("Pixel background rig, camera projection, imports, and coverage validation passed.")
	quit(0)


func _validate_arrival_projection(level: LevelSession3D) -> void:
	var camera := level.camera as PixelSideCamera3D
	assert(camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	assert(is_equal_approx(camera.size, 12.9375))
	assert(camera.keep_aspect == Camera3D.KEEP_HEIGHT)
	assert(is_equal_approx(camera.camera_height, 3.98))
	assert(is_equal_approx(camera.target_height, 3.98))
	assert(is_zero_approx(camera.rotation.x))
	assert(is_zero_approx(camera.rotation.y))
	assert(is_zero_approx(camera.rotation.z))

	var reference_y := camera.unproject_position(
		Vector3(camera.global_position.x, 1.25, -5.0)
	).y
	for depth in [0.0, 1.36]:
		var projected_y := camera.unproject_position(
			Vector3(camera.global_position.x, 1.25, depth)
		).y
		assert(
			absf(projected_y - reference_y) < 0.01,
			"A flat camera must project equal world Y identically at every Z depth."
		)
	var target_screen := camera.unproject_position(
		Vector3(camera.global_position.x, camera.target_height, 0.0)
	)
	assert(absf(target_screen.y - OUTPUT_SIZE.y * 0.5) < 0.01)
	var ground_screen_y := camera.unproject_position(
		Vector3(camera.global_position.x, 0.0, 0.0)
	).y
	assert(absf(ground_screen_y - 872.2) < 2.0)


func _validate_profile_and_imports(profile: PixelBackgroundProfile) -> void:
	assert(profile != null)
	assert(profile.profile_id == &"arrival_shoreline")
	assert(profile.validation_errors().is_empty())
	assert(is_equal_approx(profile.pixel_size, 0.04))
	assert(profile.panel_size_world().is_equal_approx(Vector2(23.04, 12.96)))
	assert(profile.layers.size() == 3)
	var expected_sizes := [
		Vector2i(144, 33),
		Vector2i(72, 51),
		Vector2i(576, 324),
	]
	var expected_vertical_policies := [
		PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED,
		PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED,
		PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED,
	]
	var imported_paths := PackedStringArray()
	for layer_index in profile.layers.size():
		var layer := profile.layers[layer_index]
		assert(
			Vector2i(layer.texture.get_width(), layer.texture.get_height())
			== expected_sizes[layer_index]
		)
		assert(layer.cover_viewport_width == (layer_index == 2))
		assert(
			layer.horizontal_policy
			== (
				PixelBackgroundLayerProfile.HorizontalPolicy.WORLD_LOCKED
					if layer_index < 2
					else PixelBackgroundLayerProfile.HorizontalPolicy.PARALLAX
			)
		)
		assert(layer.vertical_policy == expected_vertical_policies[layer_index])
		assert(
			layer.horizontal_repeat
			== PixelBackgroundLayerProfile.HorizontalRepeat.MIRROR
		)
		var source_texture := layer.texture
		if source_texture is AtlasTexture:
			source_texture = (source_texture as AtlasTexture).atlas
		if source_texture.resource_path not in imported_paths:
			imported_paths.append(source_texture.resource_path)
	for texture_path in imported_paths:
		var import_text := FileAccess.get_file_as_string(texture_path + ".import")
		assert("compress/mode=0" in import_text)
		assert("mipmaps/generate=false" in import_text)
		assert("\"vram_texture\": false" in import_text)


func _validate_transition_anchor(level: LevelSession3D) -> void:
	var background := level.background as PixelBackgroundRig3D
	var camera := level.camera as PixelSideCamera3D
	var anchor := level.get_node("BackgroundTransitionAnchor") as Node3D
	assert(anchor != null)
	assert(
		background.transition_anchor_path
		== NodePath("../BackgroundTransitionAnchor")
	)
	assert(is_equal_approx(anchor.global_position.x, 14.08))
	var expected_offsets := {
		0: Vector2(3.92, 19.92),
		1: Vector2(15.92, 33.92),
		2: Vector2(-2.08, 12.92),
	}
	for layer_index in expected_offsets:
		var layer := background.profile.layers[layer_index]
		assert(layer.uses_transition_anchor())
		var actual_offsets := (
			Vector2(
				layer.fade_in_start_offset_x,
				layer.fade_in_end_offset_x
			)
			if layer.fade_in_enabled
			else Vector2(
				layer.fade_out_start_offset_x,
				layer.fade_out_end_offset_x
			)
		)
		assert(actual_offsets.is_equal_approx(expected_offsets[layer_index]))

	_set_camera_center(level, 23.0)
	var original_opacities := PackedFloat32Array()
	for layer_index in background.runtime_layer_count():
		original_opacities.append(
			background.runtime_copies(layer_index)[0].modulate.a
		)
	anchor.position.x += 6.4
	background.snap_to_camera()
	var changed_layer := false
	for layer_index in background.runtime_layer_count():
		var expected_opacity := background.profile.layers[layer_index].opacity_at(
			camera.global_position.x,
			anchor.global_position.x,
			camera.global_position.y,
			0.0
		)
		var actual_opacity := (
			background.runtime_copies(layer_index)[0].modulate.a
		)
		assert(absf(actual_opacity - expected_opacity) < 0.001)
		changed_layer = (
			changed_layer
			or absf(actual_opacity - original_opacities[layer_index]) > 0.01
		)
	assert(
		changed_layer,
		"Moving the terrain transition anchor must shift its background fades."
	)
	anchor.position.x -= 6.4
	background.snap_to_camera()
	for layer_index in background.runtime_layer_count():
		assert(
			absf(
				background.runtime_copies(layer_index)[0].modulate.a
				- original_opacities[layer_index]
			) < 0.001
		)


func _set_camera_center(level: LevelSession3D, center_x: float) -> void:
	var camera := level.camera as PixelSideCamera3D
	level.player.global_position.x = center_x - camera.look_ahead
	camera.snap_to_target()
	level.background.snap_to_camera()


func _assert_horizontal_coverage(
	background: PixelBackgroundRig3D,
	camera: PixelSideCamera3D,
	viewport_width: float
) -> void:
	for layer_index in background.runtime_layer_count():
		if not background.profile.layers[layer_index].cover_viewport_width:
			continue
		var intervals: Array[Vector2] = []
		var visible_copies: Array[Sprite3D] = []
		for sprite in background.runtime_copies(layer_index):
			if not sprite.visible:
				continue
			visible_copies.append(sprite)
			var world_width := (
				float(sprite.texture.get_width()) * sprite.pixel_size
			)
			var screen_left := camera.unproject_position(
				sprite.global_position - Vector3(world_width * 0.5, 0.0, 0.0)
			).x
			var screen_right := camera.unproject_position(
				sprite.global_position + Vector3(world_width * 0.5, 0.0, 0.0)
			).x
			intervals.append(Vector2(screen_left, screen_right))
		intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		visible_copies.sort_custom(
			func(a: Sprite3D, b: Sprite3D) -> bool:
				return a.global_position.x < b.global_position.x
		)
		if intervals.is_empty():
			continue
		assert(
			intervals[0].x <= EPSILON,
			"Layer %d begins at %.3f px." % [layer_index, intervals[0].x]
		)
		assert(
			intervals[-1].y >= viewport_width - EPSILON,
			"Layer %d ends at %.3f px of %.3f px."
			% [layer_index, intervals[-1].y, viewport_width]
		)
		for interval_index in range(1, intervals.size()):
			assert(
				intervals[interval_index].x
				<= intervals[interval_index - 1].y + EPSILON,
				"Recycled background panels must never expose a geometric gap."
			)
		for copy_index in range(1, visible_copies.size()):
			assert(
				visible_copies[copy_index].flip_h
				!= visible_copies[copy_index - 1].flip_h,
				"Mirrored repetition must join identical texture edges."
			)


func _copy_instance_ids(background: PixelBackgroundRig3D) -> Array:
	var result: Array = []
	for layer_index in background.runtime_layer_count():
		var layer_ids: Array[int] = []
		for sprite in background.runtime_copies(layer_index):
			layer_ids.append(sprite.get_instance_id())
		result.append(layer_ids)
	return result


func _layer_world_phase(
	background: PixelBackgroundRig3D,
	layer_index: int
) -> float:
	var layer := background.profile.layers[layer_index]
	var repeat_step := layer.repeat_step_pixels() * background.profile.pixel_size
	var copies := background.runtime_copies(layer_index)
	assert(not copies.is_empty())
	return fposmod(copies[0].global_position.x, repeat_step)


func _validate_vertical_fixture(
	game_root: Node,
	level_id: StringName,
	maximum_offset: float
) -> void:
	game_root.show_level_select()
	game_root.load_level(level_id)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var camera := level.camera as PixelSideCamera3D
	var background := level.background as PixelBackgroundRig3D
	level.player.set_physics_process(false)
	level.player.global_position.y = camera.vertical_anchor_y
	camera.snap_to_target()
	background.snap_to_camera()
	var baseline_y := PackedFloat32Array()
	for layer_index in background.runtime_layer_count():
		baseline_y.append(camera.unproject_position(
			background.runtime_copies(layer_index)[0].global_position
		).y)

	level.player.global_position.y = camera.vertical_anchor_y + maximum_offset
	camera.snap_to_target()
	background.snap_to_camera()
	for layer_index in background.runtime_layer_count():
		var projected_y := camera.unproject_position(
			background.runtime_copies(layer_index)[0].global_position
		).y
		assert(
			absf(projected_y - baseline_y[layer_index]) < 0.01,
			"Screen-locked background layers must survive vertical camera travel."
		)
