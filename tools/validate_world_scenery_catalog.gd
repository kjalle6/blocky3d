extends SceneTree
## Also runs from LayoutSmoke to prove the expanded art is self-contained.
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const LIBRARY := preload("res://scripts/developer/level_object_library.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60.0, true).timeout.connect(func() -> void: quit(1))
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/level_catalogs/world_scenery.json"))
	assert(pack.size() > 2000)
	var examples := {}
	var animated := 0
	for id in pack:
		var entry: Dictionary = pack[id]
		assert(entry.image.begins_with("res://assets/art/world_scenery/"))
		assert(ResourceLoader.exists(entry.image), entry.image)
		var values := LIBRARY.defaults(id)
		if entry.kind == "decoration": values.decoration_layer = 2
		assert(OBJECTS.validate(entry.kind, values).is_empty(), id)
		var record := OBJECTS.new_record(id, values)
		var node := OBJECTS.instantiate_record(record)
		var visual := node.get_node("Visual") as Sprite3D
		assert(visual.texture != null and visual.texture.get_width() > 0 and visual.texture.get_height() > 0, id)
		if visual.texture is AtlasTexture:
			assert(visual.texture.region.end.x <= visual.texture.atlas.get_width() and visual.texture.region.end.y <= visual.texture.atlas.get_height(), id)
		if entry.kind == "tile":
			assert((node.get_node_or_null("Collision") != null) == entry.solid, id)
			if entry.image.contains("WaterTile"): assert(not entry.solid and values.surface == "silent")
		elif entry.has("fps"):
			animated += 1
			for frame in visual._frames:
				assert(frame.region.position.x >= 0 and frame.region.end.x <= frame.atlas.get_width(), id)
			var first: Rect2 = visual.texture.region
			visual._process(1.1 / float(entry.fps))
			assert(first != visual.texture.region, id)
		var family: String = entry.zone + ":" + entry.category
		if not examples.has(family): examples[family] = id
		node.free()
	assert(animated > 60)
	if not REGISTRY.can_author():
		assert(not DirAccess.dir_exists_absolute("res://assets/library"))
		print("Exported scenery passed: %d templates load with no source library; %d animations." % [pack.size(), animated])
		quit(0)
		return
	# One sample from every pack/category survives a real JSON save and reload.
	var base := (load(REGISTRY.SECTIONS.sandbox) as PackedScene).instantiate()
	var document := DOCUMENT.new()
	assert(document.open(base, {}).is_empty())
	for id in examples.values():
		var values := LIBRARY.defaults(id)
		values.x = 20.0
		# Designer commits canonicalize numerical settings to JSON floats.
		if CATALOG.ENTRIES[id].kind == "decoration": values.decoration_layer = -2.0
		document.working["object_" + str(examples.values().find(id))] = OBJECTS.new_record(id, values)
	var path := "user://world_scenery_%d.json" % Time.get_ticks_usec()
	assert(STORE.save(document, path).is_empty())
	var saved := STORE.read(path)
	var fresh := DOCUMENT.new()
	assert(fresh.open(base, saved.data, saved.hash).is_empty())
	assert(fresh.working == document.working)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	base.free()
	STORE.clear_recovery("sandbox")
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var browser: Control = designer.object_browser
	browser.open()
	assert(browser._results.size() > 2000 and browser._cards.get_child_count() <= browser.PAGE_SIZE)
	var first_id: String = browser._cards.get_child(0).get_meta("catalog_id")
	browser._pager.page_changed.emit(1)
	assert(browser._page == 1 and browser._cards.get_child(0).get_meta("catalog_id") != first_id)
	assert(browser._cards.get_child_count() <= browser.PAGE_SIZE)
	browser._zone.select(CATALOG.zones().find("Nature"))
	browser._zone.item_selected.emit(browser._zone.selected)
	assert(browser._results.size() == 144 and browser._page == 0)
	browser._pager.page_changed.emit(1)
	var selected: String = browser.selected_id
	designer.set_decoration_layer(3)
	browser._place()
	var id: String = designer.place_catalog_object(Vector2(20, 0))
	assert(designer.document.working[id].template == selected and designer.document.working[id].values.decoration_layer == 3)
	designer.undo()
	var palette: Control = designer.panel._palette
	palette._zone.select(CATALOG.zones().find("Trees"))
	palette._category.select(LIBRARY.CATEGORIES.find("Decorations"))
	palette._refresh()
	assert(palette._results.size() == 70 and palette._cards.get_child_count() == palette.PAGE_SIZE)
	palette._pager.page_changed.emit(2)
	assert(palette._page == 2 and palette._cards.get_child_count() == 22)
	palette._search.text = "birch"
	palette._search.text_changed.emit("birch")
	assert(palette._page == 0 and palette._results.size() > 0 and palette._results.size() < 70)
	assert(not designer.document.has_changes())
	designer.request_close()
	app.free()
	await process_frame
	print("World scenery passed: %d templates, %d animations, all pack/category saves, paging, search and placement layers." % [pack.size(), animated])
	quit(0)
