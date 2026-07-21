extends SceneTree
## Graphical regression capture. Run without --headless.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame
	var lab := game_root.get_node("World/MovementLab") as MovementLab
	for frame in 8:
		await process_frame
	_capture("movement_lab_start")

	Input.action_press("move_right")
	var jump_started := false
	var jump_frames := 0
	for frame in 260:
		if not jump_started and lab.player.global_position.x > 7.0:
			Input.action_press("jump")
			jump_started = true
			jump_frames = 10
		if jump_frames > 0:
			jump_frames -= 1
			if jump_frames == 0:
				Input.action_release("jump")
		if lab.player.global_position.z > 6.5:
			break
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")
	for frame in 12:
		await process_frame
	_capture("movement_lab_turn")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Preview capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save movement-lab preview.")
