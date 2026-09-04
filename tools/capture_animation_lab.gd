extends SceneTree
## Captures the focused firearm comparison states in the former Animation Lab.


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
	var room := game_root.current_level as LevelSession3D
	var shooter := room.get_node("HandgunEnemy") as HandgunEnemy3D
	var controller := room.get_node("FirearmReviewController") as FirearmReviewLab3D
	var combat_feedback := room.get_node("CombatFeedback") as CombatFeedback3D
	var review_transform := room.player.global_transform
	review_transform.origin = Vector3(14.72, 0.7, 0.0)
	room.player.reset_at(review_transform)
	room.camera.snap_to_target()

	shooter.set_fire_pattern(HandgunEnemy3D.FirePattern.TWIN)
	await combat_feedback.projectile_impact_presented
	for frame in 3:
		await process_frame
	_capture("firearm_review_impact")
	await _wait_for_shots(shooter, 4)
	for frame in 3:
		await physics_frame
	for frame in 3:
		await process_frame
	_capture("firearm_review_twin")

	controller.toggle_fire_pattern()
	await _wait_for_shots(shooter, 6)
	for frame in 3:
		await process_frame
	_capture("firearm_review_triple")

	for frame in 80:
		await physics_frame
	for frame in 3:
		await process_frame
	assert(not room.player.is_dead(), "Cover capture requires the player to remain protected.")
	assert(shooter.active_projectile_count() == 0)
	_capture("firearm_review_cover")
	quit(0)


func _wait_for_shots(shooter: HandgunEnemy3D, target_count: int) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while shooter.shots_fired_total() < target_count and Time.get_ticks_msec() < deadline:
		await physics_frame
	assert(shooter.shots_fired_total() >= target_count, "Shooter did not fire in time.")


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null, "Firearm Review Lab capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Firearm Review Lab preview.")
