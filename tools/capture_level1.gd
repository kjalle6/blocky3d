extends SceneTree
## Graphical captures for reviewing the Level 1 blockout composition.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame

	var level := game_root.get_node("World/Level1Blockout") as LevelSession3D
	for frame in 12:
		await process_frame
	_capture("level_01_start")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(48.5, 0.72, 0.0)))
	level.camera.snap_to_target()
	for frame in 12:
		await process_frame
	_capture("level_01_middle")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(108.0, 2.72, 0.0)))
	level.camera.snap_to_target()
	for frame in 12:
		await process_frame
	_capture("level_01_finish")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Preview capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Level 1 preview.")
