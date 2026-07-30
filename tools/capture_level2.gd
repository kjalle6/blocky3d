extends SceneTree
## Deterministic visual review of the Level 2 route and catalog-driven selector.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 12:
		await process_frame
	_capture("level_select")

	game_root.load_level(&"gaps_and_spikes")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 8:
		await physics_frame
	for node in get_nodes_in_group("melee_target"):
		if level.is_ancestor_of(node):
			node.set_physics_process(false)

	await _capture_at(level, "level_02_start", Vector3(2.2, 0.7, 0))
	await _capture_at(level, "level_02_opening_stairs", Vector3(17.28, 3.7, 0))
	await _capture_at(level, "level_02_first_spike_gap", Vector3(28.0, 0.7, 0))
	await _capture_at(level, "level_02_twin_spike_gaps", Vector3(37.56, 0.7, 0))
	await _capture_at(level, "level_02_middle_steps", Vector3(43.78, 2.2, 0))
	await _capture_at(level, "level_02_mid_ground", Vector3(58.0, 0.7, 0))
	await _capture_at(level, "level_02_precision_steps", Vector3(78.28, 4.7, 0))
	await _capture_at(level, "level_02_spike_run", Vector3(87.0, 0.7, 0))
	await _capture_at(level, "level_02_hazard_steps", Vector3(102.64, 4.2, 0))
	await _capture_at(level, "level_02_finish", Vector3(128.1, 7.2, 0))
	quit(0)


func _capture_at(level: LevelSession3D, file_name: String, position: Vector3) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	for frame in 8:
		await process_frame
	_capture(file_name)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Preview capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Level 2 preview.")
