extends SceneTree
## Focused runtime checks for Level 1 combat policy, goal, and full-run reset.


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
	var combat_feedback := level.get_node("CombatFeedback")
	var requested_audio_cues: Array[StringName] = []
	combat_feedback.audio_cue_requested.connect(
		func(cue_name: StringName, _world_position: Vector3) -> void:
			requested_audio_cues.append(cue_name)
	)
	for frame in 8:
		await physics_frame

	player.reset_at(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3.UP * 1.35))
	player.velocity.y = -5.0
	for frame in 24:
		await physics_frame
		if enemy.is_defeated():
			break
	assert(enemy.is_defeated(), "Falling from above should stomp an enemy.")
	assert(player.velocity.y > 0.0, "A stomp should bounce the player upward.")
	assert(
		requested_audio_cues.has(&"enemy_defeat"),
		"Enemy defeat should expose a silent, replaceable audio cue."
	)

	level._reset_run()
	assert(is_equal_approx(Engine.time_scale, 1.0), "A run reset must clear active hit-stop.")
	await physics_frame
	player.reset_at(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(-0.95, 0.18, 0.0)))
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for frame in 18:
		await physics_frame
	assert(enemy.is_defeated(), "The player's authored melee range should defeat the enemy.")
	assert(not player.is_dead(), "The faster player strike should land before the enemy attack impact.")

	level._reset_run()
	await physics_frame
	enemy.attack_damage_distance = 0.01
	player.reset_at(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(0.65, 0.0, 0.0)))
	for frame in 42:
		await physics_frame
	assert(
		enemy.facing_sign() > 0.0,
		"Player body contact during attack recovery must not reverse enemy facing."
	)

	level._reset_run()
	await physics_frame
	player.receive_enemy_hit(enemy.global_position)
	assert(player.is_dead(), "Authored enemy damage should defeat the player.")
	assert(
		requested_audio_cues.has(&"player_damage"),
		"Player damage should expose a silent, replaceable audio cue."
	)
	assert(Engine.time_scale < 1.0, "Player damage should briefly pause the impact frame.")
	level._reset_run()
	assert(is_equal_approx(Engine.time_scale, 1.0), "Reset must cancel player-damage hit-stop.")

	await physics_frame
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(6.0, -6.0, 0.0)))
	for frame in 3:
		await physics_frame
	assert(player.is_dead(), "Falling into the kill volume should defeat the player.")
	for frame in 40:
		await physics_frame
	assert(not player.is_dead(), "Player should return after the reset delay.")
	assert(not enemy.is_defeated(), "Defeated enemies should return on a full-run reset.")
	assert(
		player.global_position.distance_to(level.spawn_point.global_position) < 0.2,
		"Reset should return to the Level 1 spawn."
	)

	var goal := level.get_node("Goal") as PixelGoal3D
	player.reset_at(Transform3D(Basis.IDENTITY, goal.global_position + Vector3(0.0, 0.7, 0.0)))
	for frame in 4:
		await physics_frame
	assert(not player.is_physics_processing(), "Goal contact should stop player simulation.")
	assert(game_root.get_node("Interface/CompletionLabel").visible, "Goal contact should show completion UI.")

	level._reset_run()
	await physics_frame
	assert(player.is_physics_processing(), "Run reset should restore player control after completion.")
	assert(not game_root.get_node("Interface/CompletionLabel").visible, "Run reset should hide completion UI.")

	print("Level 1 combat, goal, and reset validation passed.")
	quit(0)
