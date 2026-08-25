extends SceneTree
## Clean and diagnostic review frames for the production Level 2 opening slice.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews/level_2_interior_opening"
const GAMEPLAY_CAMERA_SIZE := 12.9375
const OVERVIEW_CAMERA_SIZE := 82.0
const OVERVIEW_CENTER := Vector3(71.68, 22.0, 0.0)
## Each route is shown at the moment a player would actually take it, because
## that is what "visibly real" means for review. The machine rises to open the
## floor lane and drops to open the ceiling lane, so each frame is pinned to the
## end of its travel that opens the route being shown. The worst case of each
## lane is a number, not a picture, and the structural validator asserts it.
const BEAT_MACHINE_PHASE := {
	&"09_machine_low_route": 0.25,   # machine risen, so the floor lane is the open one
	&"10_machine_high_route": 0.75,  # machine dropped, so the ceiling lane is the open one
}
const BEAT_DUAL_MACHINE_PHASE := {
	# Both bodies remain visible in one frame while still demonstrating the
	# opposite-direction timing window.
	&"14_dual_machine_window": Vector2(0.125, 0.625),
}
const REVIEW_BEATS := {
	&"00_entry": Vector3(7.68, 0.7, 0.0),
	&"01_recap": Vector3(22.4, 0.7, 0.0),
	&"02_floating_ascent": Vector3(47.36, 5.18, 0.0),
	&"03_shaft_bottom": Vector3(60.16, 7.1, 0.0),
	&"04_shaft_middle": Vector3(58.88, 17.0, 0.0),
	&"05_top_left_end": Vector3(44.8, 28.86, 0.0),
	&"06_top_junction": Vector3(58.88, 28.86, 0.0),
	&"07_dash_crossing": Vector3(70.64, 30.0, 0.0),
	&"08_machine_run_up": Vector3(80.64, 28.86, 0.0),
	&"09_machine_low_route": Vector3(94.08, 28.71, 0.0),
	&"10_machine_high_route": Vector3(94.08, 32.73, 0.0),
	&"11_chamber_landing": Vector3(105.0, 29.50, 0.0),
	&"12_chamber_end": Vector3(113.0, 28.86, 0.0),
	&"13_dual_machine_run_up": Vector3(107.52, 28.86, 0.0),
	&"14_dual_machine_window": Vector3(120.96, 31.115, 0.0),
	&"15_dual_chamber_landing": Vector3(132.0, 29.50, 0.0),
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 6:
		await process_frame
	var definition := load("res://resources/dev/level_2_interior_wip.tres") as LevelDefinition
	assert(definition != null)
	game_root.load_developer_level(definition)
	for frame in 8:
		await physics_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	_freeze_enemies(level)

	_set_diagnostic_tools(game_root, false)
	game_root.get_node("Interface").visible = false
	await _place_overview_camera(level)
	await _capture("route_overview_clean")

	game_root.get_node("Interface").visible = true
	_set_diagnostic_tools(game_root, true)
	game_root._update_developer_cursor_coordinate_at(OUTPUT_SIZE * 0.5)
	for frame in 2:
		await process_frame
	await _capture("route_overview_diagnostic")
	_restore_gameplay_camera(level)

	for beat_id in REVIEW_BEATS:
		_pin_machine_phase(level, beat_id)
		_set_diagnostic_tools(game_root, false)
		game_root.get_node("Interface").visible = false
		await _place_review_camera(level, REVIEW_BEATS[beat_id])
		await _capture("%s_clean" % beat_id)

		game_root.get_node("Interface").visible = true
		_set_diagnostic_tools(game_root, true)
		game_root._update_developer_cursor_coordinate_at(OUTPUT_SIZE * 0.5)
		for frame in 2:
			await process_frame
		await _capture("%s_diagnostic" % beat_id)

	_set_diagnostic_tools(game_root, false)
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _place_review_camera(level: LevelSession3D, position: Vector3) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	for frame in 3:
		await process_frame


func _place_overview_camera(level: LevelSession3D) -> void:
	level.player.set_physics_process(false)
	level.camera.set_process(false)
	level.camera.size = OVERVIEW_CAMERA_SIZE
	level.camera.global_position = Vector3(
		OVERVIEW_CENTER.x,
		OVERVIEW_CENTER.y,
		level.camera.side_distance
	)
	level.camera.look_at(OVERVIEW_CENTER, Vector3.UP)
	for frame in 3:
		await process_frame


func _restore_gameplay_camera(level: LevelSession3D) -> void:
	level.camera.size = GAMEPLAY_CAMERA_SIZE
	level.camera.set_process(true)
	level.camera.snap_to_target()


func _set_diagnostic_tools(game_root: Node, enabled: bool) -> void:
	game_root._set_developer_inspection_enabled(enabled)
	game_root._set_developer_collision_overlay_enabled(enabled)
	game_root._set_developer_measurement_grid_enabled(enabled)


func _freeze_enemies(level: LevelSession3D) -> void:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		if node.has_method("reset_run"):
			node.call("reset_run")
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		node.set_physics_process(false)


func _capture(file_name: String) -> void:
	for frame in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Level 2 capture requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIRECTORY, file_name])
	assert(error == OK, "Could not save Level 2 review frame '%s'." % file_name)


func _pin_machine_phase(level: LevelSession3D, beat_id: StringName) -> void:
	var machine := level.get_node_or_null("ShaftFlyer") as HoveringHazard3D
	var dual_rising := level.get_node_or_null(
		"DualShaftFlyerRising"
	) as HoveringHazard3D
	var dual_falling := level.get_node_or_null(
		"DualShaftFlyerFalling"
	) as HoveringHazard3D
	if machine != null:
		machine.bob_phase = BEAT_MACHINE_PHASE.get(beat_id, 0.0)
		machine.reset_run()
		machine.set_physics_process(false)
	if dual_rising == null or dual_falling == null:
		return
	var phases := BEAT_DUAL_MACHINE_PHASE.get(beat_id, Vector2(0.0, 0.5)) as Vector2
	dual_rising.bob_phase = phases.x
	dual_falling.bob_phase = phases.y
	for dual_machine in [dual_rising, dual_falling]:
		dual_machine.reset_run()
		dual_machine.set_physics_process(false)
