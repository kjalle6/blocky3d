extends SceneTree
## Clean review frames for the cave-hoist fixture in the Level Design Lab.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/dev/level_design_lab.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	for frame in 5:
		await physics_frame
	game_root.get_node("Interface").visible = false
	var room := game_root.current_level as LevelSession3D
	assert(room != null)
	room.set_developer_inspection_enabled(true)
	var lift := room.get_node("Props/CaveConstructionLift")
	assert(lift != null)

	await _position_and_capture(
		room,
		lift,
		0.0,
		"construction_lift_lab_boarding"
	)
	await _position_and_capture(
		room,
		lift,
		0.48,
		"construction_lift_lab_travel"
	)
	await _position_and_capture(
		room,
		lift,
		1.0,
		"construction_lift_lab_top"
	)
	quit(0)


func _position_and_capture(
	room: LevelSession3D,
	lift: Node,
	progress: float,
	file_name: String
) -> void:
	lift.call("preview_travel_progress", progress)
	await physics_frame
	var carriage_height := float(
		lift.call("preview_height_for_progress", progress)
	)
	room.player.global_position = Vector3(
		(lift as Node3D).global_position.x,
		(lift as Node3D).global_position.y + carriage_height + 0.7,
		0.0
	)
	room.player.velocity = Vector3.ZERO
	room.camera.snap_to_target()
	if room.background != null:
		room.background.snap_to_camera(true)
	for frame in 5:
		await process_frame
	room.player.pixel_visual.tick_authored_state(0.0, "idle", true)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Construction-lift capture requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png(
		"%s/%s.png" % [OUTPUT_DIRECTORY, file_name]
	)
	assert(error == OK, "Could not save construction-lift preview '%s'." % file_name)
