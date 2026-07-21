extends SceneTree
## Exercises real physics and InputMap actions through both gaps and the first
## turn. This catches scene/collision/rail regressions that static checks miss.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame
	var lab := game_root.get_node("World/MovementLab") as MovementLab
	var player := lab.player

	# Let the player settle before applying movement.
	for frame in 12:
		await physics_frame

	Input.action_press("move_right")
	var first_jump_started := false
	var second_jump_started := false
	var jump_frames_remaining := 0
	var furthest_depth := player.global_position.z
	for frame in 420:
		var position := player.global_position
		if not first_jump_started and position.x > 7.0 and position.z < 2.0:
			Input.action_press("jump")
			first_jump_started = true
			jump_frames_remaining = 10
		elif not second_jump_started and position.z > 9.0 and position.x > 22.0:
			Input.action_press("jump")
			second_jump_started = true
			jump_frames_remaining = 10
		if jump_frames_remaining > 0:
			jump_frames_remaining -= 1
			if jump_frames_remaining == 0:
				Input.action_release("jump")
		furthest_depth = maxf(furthest_depth, position.z)
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")

	assert(first_jump_started, "The player never reached the first jump test.")
	assert(second_jump_started, "The player never followed the rail into depth.")
	assert(furthest_depth > 14.0, "The player did not clear the second gap.")

	player.kill()
	for frame in 20:
		await physics_frame
	assert(player.visible, "The lab did not restore the player after death.")
	assert(player.global_position.distance_to(lab.spawn_point.global_position) < 0.2, "Reset did not return to spawn.")

	print("Runtime movement and reset validation passed.")
	quit(0)
