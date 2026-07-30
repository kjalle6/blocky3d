extends SceneTree
## Deterministic graphical captures for the pixel Level 1 composition.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(1)
	await process_frame

	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 12:
		await process_frame
	_capture("level_01_start")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(3.0, 0.7, 0.0)))
	level.camera.snap_to_target()
	for frame in 12:
		await process_frame
	_capture("level_01_tree_overlap")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(17.0, 0.7, 0.0)))
	level.camera.snap_to_target()
	for frame in 12:
		await process_frame
	_capture("level_01_enemy")

	level._reset_run()
	await physics_frame
	var enemy := level.get_node("GreenZonePatrol") as StompableEnemy3D
	level.player.reset_at(Transform3D(
		Basis.IDENTITY,
		enemy.global_position + Vector3(-0.95, 0.18, 0.0)
	))
	level.camera.snap_to_target()
	Input.action_press("move_right")
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for frame in 18:
		await physics_frame
		if enemy.is_defeated():
			break
	Input.action_release("move_right")
	assert(enemy.is_defeated(), "Attack preview setup must land the authored melee hit.")
	await process_frame
	_capture("level_01_attack")

	level._reset_run()
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(17.0, 0.7, 0.0)))
	level.camera.snap_to_target()
	level.player.receive_enemy_hit(enemy.global_position)
	await process_frame
	_capture("level_01_player_hit")

	level._reset_run()
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(17.0, 0.7, 0.0)))
	level.camera.snap_to_target()
	level.player.kill()
	for frame in 20:
		await physics_frame
	_capture("level_01_player_death")

	level._reset_run()
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(46.5, 0.7, 0.0)))
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
