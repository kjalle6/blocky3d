extends SceneTree
## Captures Level 4's vertical teaching beats for visual review.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 8:
		await process_frame
	game_root.load_level(&"wall_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 8:
		await physics_frame

	await _capture_at(level, "level_04_pickup_and_intro", Vector3(3.2, 0.7, 0))
	await _capture_at(level, "level_04_intro_exit", Vector3(11.5, 10.94, 0))
	await _capture_at(level, "level_04_descent", Vector3(24.3, 5.18, 0))
	await _capture_at(level, "level_04_second_shaft_entry", Vector3(46.1, 0.7, 0))
	await _capture_at(level, "level_04_second_shaft_exit", Vector3(55.0, 12.22, 0))
	await _capture_at(level, "level_04_finish", Vector3(79.0, 0.7, 0))
	quit(0)


func _capture_at(
	level: LevelSession3D,
	file_name: String,
	position: Vector3
) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	for frame in 8:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null, "Level 4 capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Level 4 preview.")
