extends SceneTree
## Visual QA capture for the development-only world measurement grid.

const OUTPUT_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_level(&"arrival_shoreline")
	await process_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F10
	event.keycode = KEY_F10
	event.pressed = true
	game_root._unhandled_input(event)
	for frame in 2:
		await process_frame
	game_root.set_process(false)
	game_root._update_developer_cursor_coordinate_at(Vector2(960.0, 540.0))
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null)
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png(
		"res://build/previews/developer_measurement_grid.png"
	)
	assert(error == OK)
	quit(0)
