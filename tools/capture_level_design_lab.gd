extends SceneTree
## Captures the Level Design Lab's current cave-and-lift starting fixture.

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
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/dev/level_design_lab.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	for frame in 6:
		await physics_frame
	var room := game_root.current_level as LevelSession3D
	assert(room != null)
	room.player.set_developer_inspection_enabled(true)

	await _move_and_capture(
		room,
		Vector3(7.68, 0.7, 0),
		"level_design_lab_lower"
	)
	await _move_and_capture(
		room,
		Vector3(21.12, 6.4, 0),
		"level_design_lab_shaft"
	)
	await _move_and_capture(
		room,
		Vector3(31.36, 13.5, 0),
		"level_design_lab_upper"
	)
	room.set_developer_collision_overlay_enabled(true)
	await _move_and_capture(
		room,
		Vector3(21.12, 6.4, 0),
		"level_design_lab_collision"
	)
	quit(0)


func _move_and_capture(
	room: LevelSession3D,
	position: Vector3,
	file_name: String
) -> void:
	room.player.global_position = position
	room.player.velocity = Vector3.ZERO
	room.camera.snap_to_target()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Interior capture requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png(
		"%s/%s.png" % [OUTPUT_DIRECTORY, file_name]
	)
	assert(error == OK, "Could not save interior-lab preview '%s'." % file_name)
