extends SceneTree
## Paired clean and diagnostic review frames for authored set dressing.
## Diagnostic frames deliberately enable the grid and hitbox overlay; clean
## frames prove that the same composition still reads as the actual game.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews/dressing_review"
const REVIEW_BEATS := {
	&"00_launch": Vector3(126.68, 1.34, 0.0),
	&"01_rise": Vector3(131.84, 4.54, 0.0),
	&"02_dip": Vector3(151.04, 5.18, 0.0),
	&"03_peak": Vector3(160.0, 8.38, 0.0),
	&"04_landing": Vector3(171.0, 1.34, 0.0),
	&"05_exit": Vector3(187.2, 1.34, 0.0),
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 8:
		await process_frame
	game_root.load_level(&"arrival_shoreline")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	for frame in 8:
		await physics_frame
	_freeze_enemies(level)

	for beat_id in REVIEW_BEATS:
		_set_diagnostic_tools(game_root, false)
		game_root.get_node("Interface").visible = false
		await _place_review_camera(level, REVIEW_BEATS[beat_id])
		await _capture("%s_clean" % beat_id)

		game_root.get_node("Interface").visible = true
		_set_diagnostic_tools(game_root, true)
		game_root._update_developer_cursor_coordinate_at(OUTPUT_SIZE * 0.5)
		for frame in 2:
			await process_frame
		await _capture("%s_diagnostic" % beat_id)

	_set_diagnostic_tools(game_root, false)
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _place_review_camera(level: LevelSession3D, position: Vector3) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	for frame in 3:
		await process_frame


func _set_diagnostic_tools(game_root: Node, enabled: bool) -> void:
	game_root._set_developer_inspection_enabled(enabled)
	game_root._set_developer_collision_overlay_enabled(enabled)
	game_root._set_developer_measurement_grid_enabled(enabled)
	var level := game_root.current_level as LevelSession3D
	assert(level.is_developer_inspection_enabled() == enabled)
	assert(level.is_developer_collision_overlay_enabled() == enabled)
	assert(level.is_developer_measurement_grid_enabled() == enabled)


func _freeze_enemies(level: LevelSession3D) -> void:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		if node.has_method("reset_run"):
			node.call("reset_run")
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		node.set_physics_process(false)


func _capture(file_name: String) -> void:
	for frame in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null)
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIRECTORY, file_name])
	assert(error == OK)
