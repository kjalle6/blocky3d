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
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var browser: Control = designer.object_browser
	browser.open()
	browser._zone.select(designer.CATALOG.zones().find("Green Zone"))
	browser.category = "Blocks"
	browser._refresh()
	await _capture("green_zone_terrain_browser_1080")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _capture("green_zone_terrain_browser_720")
	browser.category = "Decorations"
	browser._search.text = "tree"
	browser._refresh()
	await _capture("green_zone_props_browser_720")
	browser._search.text = ""
	browser.category = "Animated scenery"
	browser._refresh()
	await _capture("green_zone_animated_browser_720")
	browser.close()
	designer.panel.show_build_palette()
	# A temporary building example; the user's actual sandbox remains empty.
	designer.camera.position = Vector3(24.32, 4.4, designer.camera.position.z)
	designer.refresh_presentation()
	for row in 3:
		var template := "gz_tile_02" if row == 2 else "gz_tile_14" if row == 1 else "gz_tile_04"
		designer.begin_placement(template, designer.CATALOG.defaults(template))
		var start: Vector2 = designer.canvas.screen_at(Vector2(18.0, row * 1.28 + 0.1))
		var end: Vector2 = designer.canvas.screen_at(Vector2(24.3, row * 1.28 + 0.1))
		designer.canvas._press(start, true)
		designer.canvas._motion(end)
		designer.canvas._release(end)
	for setting in [{"id": "gz_prop_other_tree1", "point": Vector2(20.48, 3.84)}, {"id": "gz_animated_fountain", "point": Vector2(23.04, 3.84)}]:
		designer.begin_placement(setting.id, designer.CATALOG.defaults(setting.id))
		designer.place_catalog_object(setting.point)
	designer.choose("")
	var palette: Control = designer.panel._palette
	palette._zone.select(designer.CATALOG.zones().find("Green Zone"))
	palette._category.select(palette.LIBRARY.CATEGORIES.find("Blocks"))
	palette._refresh()
	designer.begin_placement("gz_tile_42", designer.CATALOG.defaults("gz_tile_42"))
	designer.update_placement(Vector2(25.0, 0.1))
	await _capture("green_zone_tile_building_720")
	designer.cancel_placement()
	designer.revert_layout()
	designer.request_close()
	app.free()
	quit(0)

func _capture(name: String) -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/previews/%s.png" % name) == OK)
