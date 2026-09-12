extends SceneTree
## Visual check of the menu entry and empty designer workspace.

const OUTPUT_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	var packed := load("res://scenes/app/game_root.tscn") as PackedScene
	var app := packed.instantiate()
	app.persist_progression = false
	root.add_child(app)
	for frame in 3:
		await process_frame
	await _capture("level_designer_sandbox_menu")
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	for frame in 12:
		await physics_frame
	await _capture("level_designer_sandbox")
	quit(0)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	assert(capture != null and capture.get_size() == OUTPUT_SIZE)
	assert(capture.save_png("res://build/previews/%s.png" % filename) == OK)
