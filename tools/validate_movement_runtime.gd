extends SceneTree
## Exercises the production player, Level 1 collision, input, and full-run
## reset without depending on a separate legacy movement lab.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame
	var level := game_root.get_node("World/Level01") as LevelSession3D
	var player := level.player

	# Let the player settle before applying movement.
	for frame in 12:
		await physics_frame

	var start_x := player.global_position.x
	Input.action_press("move_right")
	for frame in 24:
		await physics_frame
	Input.action_release("move_right")
	assert(player.global_position.x > start_x + 1.5, "Right input should move the production player.")
	assert(player.path_speed > 7.0, "The player should reach the authored maximum speed promptly.")

	for frame in 12:
		await physics_frame
	assert(absf(player.path_speed) < 0.5, "Ground release should decelerate the player cleanly.")

	var grounded_y := player.global_position.y
	var highest_y := grounded_y
	Input.action_press("jump")
	for frame in 20:
		await physics_frame
		highest_y = maxf(highest_y, player.global_position.y)
	Input.action_release("jump")
	for frame in 36:
		await physics_frame
		highest_y = maxf(highest_y, player.global_position.y)
	assert(highest_y > grounded_y + 2.0, "Jump input should produce the authored useful jump height.")

	player.kill()
	for frame in 40:
		await physics_frame
	assert(not player.is_dead(), "Level 1 should restore the player after death.")
	assert(
		player.global_position.distance_to(level.spawn_point.global_position) < 0.2,
		"Reset should return the player to the Level 1 spawn."
	)

	print("Runtime movement and reset validation passed.")
	quit(0)
