extends SceneTree
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const LIBRARY := preload("res://scripts/developer/level_object_library.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const SURFACES := preload("res://scripts/audio/footstep_surface_resolver.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(35.0, true).timeout.connect(func() -> void: quit(1))
	STORE.clear_recovery("sandbox")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/level_catalogs/green_zone.json"))
	assert(pack.size() == 179)
	var tiles := 0
	var solid := 0
	var animated := 0
	var static_props := 0
	for id in pack:
		var entry: Dictionary = pack[id]
		assert(entry.zone == "Green Zone" and entry.image.begins_with("res://assets/art/green_zone/catalog/"))
		assert(ResourceLoader.exists(entry.image))
		var record := OBJECTS.new_record(id, CATALOG.defaults(id))
		assert(OBJECTS.validate(record.kind, record.values).is_empty())
		var node := OBJECTS.instantiate_record(record)
		var visual := node.get_node("Visual") as Sprite3D
		assert(visual.texture != null and is_equal_approx(visual.pixel_size, 0.04))
		if entry.kind == "tile":
			tiles += 1
			assert(OBJECTS.bounds(record).size.is_equal_approx(Vector2.ONE * 1.28))
			if entry.solid:
				solid += 1
				assert(node.get_node("Collision").shape is ConvexPolygonShape3D)
			else: assert(node.get_node_or_null("Collision") == null)
		elif entry.has("fps"):
			animated += 1
			var first: Rect2 = visual.texture.region
			visual._process(1.1 / float(entry.fps))
			assert(visual.texture.region != first and visual.texture.region.size == first.size)
			for frame in visual._frames:
				assert(frame.region.position.x >= 0 and frame.region.end.x <= frame.atlas.get_width())
			if id == "gz_animated_chest_open":
				assert(visual._frames.size() == 7 and visual._frames[1].region.position.x - first.position.x == 32)
				visual._process(10.0)
				assert(visual.texture == visual._frames.back(), "The chest must hold its final open frame.")
		else: static_props += 1
		node.free()
	assert(tiles == 96 and solid == 72 and static_props == 78 and animated == 5)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/green_zone/catalog/manifest.json"))
	for item in manifest.files:
		assert(FileAccess.get_sha256("res://" + item.source) == item.sha256)
		assert(FileAccess.get_sha256("res://" + item.output) == item.sha256)
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var browser: Control = designer.object_browser
	browser.open()
	browser._zone.select(CATALOG.zones().find("Green Zone"))
	browser.category = "Blocks"
	browser._refresh()
	assert(browser._results.size() == 96)
	browser._zone.select(CATALOG.zones().find("Beach"))
	browser._refresh()
	assert(browser._results.size() >= 6 and not browser._place_button.disabled)
	for id in browser._results:
		assert(LIBRARY.defaults(id).surface == ("sand" if CATALOG.ENTRIES[id].solid else "silent"))
		assert(CATALOG.icon(id) != null)
	browser._zone.select(CATALOG.zones().find("Shared"))
	browser._refresh()
	assert(browser._results.is_empty() and browser._place_button.disabled)
	browser.close()
	# Paint through the canvas, including interpolation, cancellation and replacement.
	designer.begin_placement("gz_tile_02", CATALOG.defaults("gz_tile_02"))
	var start: Vector2 = designer.canvas.screen_at(Vector2(18.1, 0.2))
	var end: Vector2 = designer.canvas.screen_at(Vector2(22.2, 0.2))
	designer.canvas._press(start, false)
	designer.canvas._motion(end)
	assert(designer.document.working.is_empty())
	designer.canvas.cancel_gesture()
	assert(designer.document.working.is_empty())
	var history: int = designer.history.get_history_count()
	designer.canvas._press(start, false)
	designer.canvas._motion(end)
	designer.canvas._release(end)
	assert(designer.document.working.size() == 4 and designer.history.get_history_count() == history + 1)
	assert(designer.tool == "place")
	assert(designer.panel._tabs.current_tab == 0 and designer.selection.is_empty())
	var original: Dictionary = designer.document.working.duplicate(true)
	# Clicking the same cells is a no-op and never exits the brush.
	designer.canvas._press(start, false)
	designer.canvas._motion(end)
	designer.canvas._release(end)
	assert(designer.document.working == original and designer.history.get_history_count() == history + 1 and designer.tool == "place")
	designer.begin_placement("gz_tile_03", CATALOG.defaults("gz_tile_03"))
	designer.canvas._press(start, false)
	designer.canvas._motion(end)
	designer.canvas._release(end)
	assert(designer.document.working.size() == 4)
	for id in original:
		assert(designer.document.working[id].template == "gz_tile_03")
		assert(designer.nodes[id].get_meta("layout_template") == "gz_tile_03")
	designer.undo()
	assert(designer.document.working == original)
	for id in original: assert(designer.nodes[id].get_meta("layout_template") == "gz_tile_02")
	# Scenery uses its own layer, so painting it does not remove solid terrain.
	designer.begin_placement("gz_tile_75", CATALOG.defaults("gz_tile_75"))
	designer.canvas._press(start, true)
	designer.canvas._motion(end)
	designer.canvas._release(end)
	assert(designer.document.working.size() == 8)
	designer.cancel_placement()
	# The Build command always reveals the block palette, including from a collapsed inspector.
	designer.panel._sidebar_collapsed = true
	designer.panel.show_build_palette()
	assert(designer.panel._sidebar.visible and designer.panel._tabs.current_tab == 0)
	assert(designer.panel._palette._category.get_item_text(designer.panel._palette._category.selected) == "Blocks")
	assert(designer.panel.find_child("PlatformPalette", true, false) == null)
	# Sand uses the same gesture and keeps its surface after a real save/reload.
	designer.begin_placement("beach_tile_top", LIBRARY.defaults("beach_tile_top"))
	var sand_start: Vector2 = designer.canvas.screen_at(Vector2(28.2, 0.2))
	designer.canvas._press(sand_start, false)
	designer.canvas._release(sand_start)
	var sand_id := ""
	for id in designer.document.working:
		if designer.document.working[id].template == "beach_tile_top": sand_id = id
	assert(not sand_id.is_empty() and designer.document.working[sand_id].values.surface == "sand")
	designer.cancel_placement()
	# Round-trip the complete pack in one document, without touching a project save.
	var records: Dictionary = designer.document.working.duplicate(true)
	var index := 0
	for id in pack:
		var values := CATALOG.defaults(id)
		values.x = 50.56 + (index % 30) * 3.84
		values.y = 5.76 + (index / 30) * 5.12
		records["object_pack_" + id] = OBJECTS.new_record(id, values)
		index += 1
	assert(designer.commit_records("Complete catalog fixture", records))
	var fountain: Sprite3D = designer.nodes.object_pack_gz_animated_fountain.get_node("Visual")
	for frame in 4: await process_frame
	assert(fountain._time == 0, "Animated scenery must remain frozen in the editor.")
	var path := "user://green_zone_catalog_%d.json" % Time.get_ticks_usec()
	var save_error := STORE.save(designer.document, path)
	assert(save_error.is_empty(), save_error)
	var base := (load("res://scenes/dev/level_designer_sandbox.tscn") as PackedScene).instantiate()
	var fresh := DOCUMENT.new()
	var stored := STORE.read(path)
	assert(fresh.open(base, stored.data, stored.hash).is_empty())
	assert(fresh.working == designer.document.working)
	assert(stored.data.schema == 3)
	var changed_asset: Dictionary = stored.data.duplicate(true)
	changed_asset.catalog["gz_tile_42"] = "changed"
	assert(not fresh.resolve(changed_asset).error.is_empty(), "Changed used assets must be rejected.")
	base.free()
	designer.test_layout()
	var level: LevelSession3D = app.current_level
	var runtime: Dictionary = OBJECTS.inspect(level).nodes
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(19.84, 2.5, 0)))
	for frame in 40: await physics_frame
	assert(level.player.is_on_floor())
	assert(SURFACES.sample(level.player).surface == "grass")
	var tile: Node3D = runtime[original.keys()[0]]
	assert(SURFACES.surface_at(tile, tile.position) == "grass")
	assert(SURFACES.surface_at(runtime[sand_id], runtime[sand_id].position) == "sand")
	# The diagonal collision follows the slope, including after flipping it.
	var slope: Node3D = runtime.object_pack_gz_tile_42
	var left := _floor_hit(level, slope.position + Vector3(-0.32, 2, 0))
	var right := _floor_hit(level, slope.position + Vector3(0.32, 2, 0))
	assert(left.collider == slope and right.collider == slope and left.position.y > right.position.y + 0.4)
	assert(absf(left.position.y - slope.layout_floor_y_at(left.position.x)) < 0.06)
	var slope_values: Dictionary = designer.document.working.object_pack_gz_tile_42.values.duplicate(true)
	slope_values.flip_h = true
	OBJECTS.apply(slope, "tile", slope_values, true)
	await physics_frame
	left = _floor_hit(level, slope.position + Vector3(-0.32, 2, 0))
	right = _floor_hit(level, slope.position + Vector3(0.32, 2, 0))
	assert(left.position.y < right.position.y - 0.4)
	var scenery: Node3D = runtime.object_pack_gz_tile_75
	var through := _floor_hit(level, scenery.position + Vector3(0, 2, 0))
	assert(through.collider != scenery)
	assert(runtime.object_pack_gz_animated_fountain.get_node("Visual")._time > 0)
	designer.return_to_editing()
	assert(designer.document.working == fresh.working)
	designer.document.saved = {}
	designer.revert_layout()
	designer.request_close()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	app.free()
	print("Green Zone catalog passed: all 179 assets, unchanged source art, zone filters, tile strokes/replacement/undo, complete disk round-trip, solid/sloped/scenery collision, footsteps and frozen/live animations.")
	quit(0)

func _floor_hit(level: Node3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 40, 1)
	return level.get_world_3d().direct_space_state.intersect_ray(query)
