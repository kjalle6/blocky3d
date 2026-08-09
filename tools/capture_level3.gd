extends SceneTree
## Captures the Level 3 teaching beats for visual review.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 12:
		await process_frame
	_capture("level_select_with_level_03")

	game_root.load_level(&"double_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 8:
		await physics_frame
	for node in get_nodes_in_group("melee_target"):
		if level.is_ancestor_of(node):
			node.set_physics_process(false)

	await _capture_at(level, "level_03_pickup_and_height", Vector3(6.2, 0.7, 0), false)
	level.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	game_root.get_node("Interface").visible = true
	for frame in 4:
		await process_frame
	_capture("level_03_unlock_prompt")
	game_root.get_node("Interface").visible = false
	await _capture_double_jump(level)
	await _capture_at(level, "level_03_distance_lesson", Vector3(22.0, 0.7, 0))
	await _capture_at(level, "level_03_mixed_rhythm", Vector3(47.2, 0.7, 0))
	await _capture_at(level, "level_03_spike_lesson", Vector3(61.0, 0.7, 0))
	await _capture_at(level, "level_03_enemy_encounter", Vector3(79.2, 0.7, 0))
	await _capture_at(level, "level_03_final_proof", Vector3(84.2, 0.7, 0))
	await _capture_at(level, "level_03_finish", Vector3(103.5, 0.7, 0))
	quit(0)


func _capture_at(
	level: LevelSession3D,
	file_name: String,
	position: Vector3,
	hide_pickup := true
) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	if hide_pickup:
		(level.get_node("DoubleJumpPickup") as Node3D).visible = false
	level.camera.snap_to_target()
	for frame in 8:
		await process_frame
	_capture(file_name)


func _capture_double_jump(level: LevelSession3D) -> void:
	(level.get_node("DoubleJumpPickup") as Node3D).visible = false
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(11.8, 2.3, 0)))
	level.player.set_physics_process(false)
	level.player.pixel_visual.tick(0.12, false, 8.0, 14.0, false, false, true, true)
	level.camera.snap_to_target()
	for frame in 8:
		await process_frame
	_capture("level_03_double_jump_animation")


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Preview capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Level 3 preview.")
