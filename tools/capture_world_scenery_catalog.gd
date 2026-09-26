extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(35.0, true).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	preload("res://scripts/developer/level_layout_store.gd").clear_recovery("sandbox")
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var browser: Control = designer.object_browser
	browser.open()
	browser._zone.select(designer.CATALOG.zones().find("Nature"))
	browser.category = "Decorations"
	browser._refresh()
	browser._pager.page_changed.emit(1)
	await _capture("world_scenery_nature_1080")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	browser._zone.select(designer.CATALOG.zones().find("Trees"))
	browser._refresh()
	await _capture("world_scenery_trees_720")
	assert(browser._window.get_global_rect().encloses(browser._window.get_child(0).get_global_rect()), "Browser contents must fit after filtering and resizing.")
	browser.close()
	designer.camera.position = Vector3(24, 2.8, 24)
	designer.camera.size = 12.0
	designer.refresh_presentation()
	for setting in [{"id":"scenery_environment_vegetation_trees_png_birch_1", "point":Vector2(20,0)},
		{"id":"scenery_environment_structures_doors_and_portals_2_portals_1", "point":Vector2(26,0)}]:
		designer.set_decoration_layer(1)
		designer.begin_placement(setting.id, designer.CATALOG.defaults(setting.id))
		designer.place_catalog_object(setting.point)
	designer.choose("")
	var palette: Control = designer.panel._palette
	palette._zone.select(designer.CATALOG.zones().find("Trees"))
	palette._category.select(palette.LIBRARY.CATEGORIES.find("Decorations"))
	palette._refresh()
	await _capture("world_scenery_placed_720")
	designer.revert_layout()
	designer.request_close()
	app.free()
	quit(0)

func _capture(name: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/previews/%s.png" % name) == OK)
