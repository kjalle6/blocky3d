extends SceneTree
## Drives the real controller through the approved six-platform Level 1 route.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"fundamentals")
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var enemy := level.get_node("GreenZonePatrol") as StompableEnemy3D
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	var jump_markers := [8.8, 21.0, 26.2, 32.6, 40.2]
	var next_jump := 0
	var jump_frames_remaining := 0
	var attacked := false
	Input.action_press("move_right")
	for frame in 900:
		if player.is_dead():
			break
		if not attacked and absf(enemy.global_position.x - player.global_position.x) <= 1.2:
			Input.action_press("attack")
			attacked = true
		elif attacked:
			Input.action_release("attack")
		if next_jump < jump_markers.size() and player.global_position.x >= jump_markers[next_jump]:
			Input.action_press("jump")
			jump_frames_remaining = 18
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
	Input.action_release("attack")

	if player.is_dead():
		push_error("The scripted Level 1 route died near x=%.2f." % player.global_position.x)
		quit(1)
		return
	if not completion_label.visible:
		push_error("The scripted Level 1 route stopped near x=%.2f." % player.global_position.x)
		quit(1)
		return
	print("Level 1 scripted playthrough validation passed.")
	quit(0)
