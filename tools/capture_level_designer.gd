extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40.0, true).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	await process_frame
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	app.level_designer.open_panel()
	var designer: CanvasLayer = app.level_designer
	await _capture("level_designer_empty")
	designer.object_browser.open()
	await _capture("level_object_browser_1080")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _capture("level_object_browser_720")
	designer.object_browser.close()
	await _capture("level_designer_quick_add_720")
	designer.begin_placement("skater_enemy", designer.CATALOG.defaults("skater_enemy"))
	designer.update_placement(Vector2(18, 0))
	await _capture("level_object_placement_720")
	designer.cancel_placement()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	designer.add_platform(Rect2(Vector2(17.92, 1.28), Vector2(5.12, 1.28)))
	designer.add_platform(Rect2(Vector2(26.88, 3.84), Vector2(3.84, 2.56)))
	designer.palette = "sand"
	designer.add_platform(Rect2(Vector2(33.28, 6.4), Vector2(5.12, 2.56)))
	designer.frame_selection()
	await _capture("level_designer_build")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _capture("level_designer_720")
	designer.canvas.open_context_menu(designer.canvas.screen_at(designer.OBJECTS.bounds(designer.document.working[designer.selection[0]]).get_center()))
	await _capture("level_designer_context_720")
	designer.context_menu.hide()
	designer.revert_layout()
	designer.request_close()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	app.load_developer_level(load("res://resources/dev/green_zone_finale_wip.tres"))
	designer.open_panel()
	designer.choose("outdoors_dash_patrol")
	designer.frame_selection()
	designer.camera.size = 16.0
	designer.refresh_presentation()
	await _capture("level_designer_patrol")
	designer.update_values({"speed": 1.5})
	designer.canvas.open_context_menu(designer.canvas.screen_at(designer.OBJECTS.bounds(designer.document.working[designer.selection[0]]).get_center()))
	await _capture("level_designer_context_patrol")
	designer.context_menu.hide()
	designer.revert_layout()
	designer.request_close()
	app.free()
	quit(0)

func _capture(name: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("res://build/previews/%s.png" % name) == OK)
