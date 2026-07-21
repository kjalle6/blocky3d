extends SceneTree
## Focused runtime checks for Level 1 entity interaction and full-run reset.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame

	var level := game_root.get_node("World/Level1Blockout") as LevelSession3D
	var player := level.player
	var enemies := level.find_children("Enemy*", "StompableEnemy3D", true, false)
	assert(enemies.size() == 3, "Level 1 should contain three introductory enemies.")

	for frame in 8:
		await physics_frame

	var enemy := enemies[0] as StompableEnemy3D
	player.reset_at(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3.UP * 1.35))
	player.velocity.y = -5.0
	for frame in 24:
		await physics_frame
		if not enemy.visible:
			break
	assert(not enemy.visible, "Falling from above should stomp an enemy.")
	assert(player.velocity.y > 0.0, "A stomp should bounce the player upward.")

	var spikes := level.get_node("Spikes01") as Area3D
	player.reset_at(Transform3D(Basis.IDENTITY, spikes.global_position + Vector3.UP * 0.55))
	for frame in 3:
		await physics_frame
	assert(not player.visible, "Touching a spike strip should defeat the player.")
	for frame in 20:
		await physics_frame
	assert(player.visible, "Player should return after the reset delay.")
	assert(enemy.visible, "Defeated enemies should return on a full-run reset.")
	assert(
		player.global_position.distance_to(level.spawn_point.global_position) < 0.2,
		"Reset should return to Level 1 spawn."
	)

	var goal := level.get_node("Goal") as LevelGoal3D
	player.reset_at(Transform3D(Basis.IDENTITY, goal.global_position + Vector3(0.3, 0.72, 0.0)))
	for frame in 4:
		await physics_frame
	assert(not player.is_physics_processing(), "Goal contact should stop player simulation.")
	assert(game_root.get_node("Interface/CompletionLabel").visible, "Goal contact should show completion UI.")

	level._reset_run()
	await physics_frame
	assert(player.is_physics_processing(), "Run reset should restore player control after completion.")
	assert(not game_root.get_node("Interface/CompletionLabel").visible, "Run reset should hide completion UI.")

	print("Level 1 enemy, goal, and reset validation passed.")
	quit(0)
