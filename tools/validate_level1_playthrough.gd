extends SceneTree
## Drives the real controller through Level 1's intended route. This is not an
## AI player; it is a coarse reachability guard for changes to tuning/layout.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame

	var level := game_root.get_node("World/Level1Blockout") as LevelSession3D
	var player := level.player
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	var jump_markers := [9.5, 16.0, 22.5, 32.0, 39.0, 48.0, 56.8, 62.9, 74.3, 82.0, 92.3, 99.5, 107.0]
	var next_jump := 0
	var jump_frames_remaining := 0
	var jump_trace: Array[String] = []
	Input.action_press("move_right")
	for frame in 1200:
		if not player.visible:
			break
		if next_jump < jump_markers.size() and player.global_position.x >= jump_markers[next_jump]:
			jump_trace.append(
				"%.1f@x%.2f/y%.2f/floor=%s"
				% [jump_markers[next_jump], player.global_position.x, player.global_position.y, player.is_on_floor()]
			)
			Input.action_press("jump")
			jump_frames_remaining = 24
			next_jump += 1
		if jump_frames_remaining > 0:
			jump_frames_remaining -= 1
			if jump_frames_remaining == 0:
				Input.action_release("jump")
		if completion_label.visible:
			break
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")

	if not player.visible:
		push_error(
			"The scripted Level 1 route hit a hazard near x=%.2f after jump marker %d."
			% [player.global_position.x, next_jump] + " Jumps: " + ", ".join(jump_trace)
		)
		quit(1)
		return
	if not completion_label.visible:
		push_error("The scripted Level 1 route stopped near x=%.2f." % player.global_position.x)
		quit(1)
		return
	print("Level 1 scripted playthrough validation passed.")
	quit(0)
