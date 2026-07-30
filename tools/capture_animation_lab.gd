extends SceneTree
## Captures the disposable Animation Lab for visual review.


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

	game_root.load_developer_room()
	for frame in 8:
		await physics_frame
	for frame in 4:
		await process_frame
	_capture("animation_lab_start")

	var room := game_root.current_level as LevelSession3D
	room.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(26.0, 0.7, 0)))
	room.camera.snap_to_target()
	for frame in 8:
		await process_frame
	_capture("animation_lab_far_side")

	room.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(28.35, 4.2, 0)))
	room.player.velocity.y = -7.0
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if room.player.is_wall_sliding():
			break
	Input.action_release("move_right")
	assert(room.player.is_wall_sliding(), "Wall-slide capture requires wall contact.")
	room.camera.snap_to_target()
	for frame in 4:
		await process_frame
	_capture("animation_lab_wall_slide")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Animation Lab capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Animation Lab preview.")
