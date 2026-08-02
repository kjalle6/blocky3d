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

	room.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(8.0, 0.55, 0)))
	for frame in 8:
		await physics_frame
	assert(room.player.is_on_floor(), "Ground Dash capture requires floor contact.")
	assert(room.player._try_start_dash(1.0))
	await physics_frame
	room.camera.snap_to_target()
	for frame in 2:
		await process_frame
	assert(not room.player.is_dash_airborne())
	assert(room.player.pixel_visual.current_state() == "dash")
	_capture("animation_lab_dash")

	room.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(8.0, 5.0, 0)))
	for frame in 3:
		await physics_frame
	assert(room.player._try_start_dash(1.0))
	await physics_frame
	room.camera.snap_to_target()
	for frame in 2:
		await process_frame
	assert(room.player.is_dash_airborne())
	assert(room.player.pixel_visual.current_state() == "air_dash")
	assert(
		room.player.pixel_visual.body.frame in PixelPlayerVisual3D.AIR_DASH_FRAMES
	)
	_capture("animation_lab_air_dash")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Animation Lab capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Animation Lab preview.")
