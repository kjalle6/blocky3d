extends SceneTree
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const LIBRARY := preload("res://scripts/developer/level_object_library.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const RESOLVER := preload("res://scripts/developer/level_layout_resolver.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0, true).timeout.connect(func() -> void: quit(1))
	# The runner isolates user:// from the user's game. Discard recovery left
	# by an interrupted earlier probe, so it cannot open a modal over this test.
	STORE.clear_recovery("sandbox")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var browser: Control = designer.object_browser
	browser.open()
	assert(browser.visible and browser._results.size() == CATALOG.ENTRIES.size() - 2)
	assert("grass_platform" not in browser._results and "sand_platform" not in browser._results)
	browser.category = "Enemies"
	browser._refresh()
	await _double_click_card(browser, "skater_enemy")
	assert(not browser.visible and designer.tool == "place")
	assert(designer._placement_record.template == "skater_enemy" and designer.document.working.is_empty(), "A browser double-click must not place through the closing window.")
	designer.cancel_placement()
	browser.open()
	browser.category = "Enemies"
	browser._refresh()
	assert(browser._results.size() == 3)
	browser._search.text = "skater"
	browser._refresh()
	assert(browser._results == ["skater_enemy"])
	browser.selected_id = "skater_enemy"
	browser._place()
	assert(not browser.visible and designer.tool == "place" and designer.document.working.is_empty())
	for area in designer._ghost_root.find_children("*", "Area3D", true, false): assert(not area.monitoring and area.collision_layer == 0)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	designer._input(escape)
	assert(designer.document.working.is_empty() and designer.tool == "move" and designer.status == "Placement cancelled")
	browser.open()
	browser.category = "Blocks"
	browser._search.text = ""
	browser.selected_id = "gz_tile_02"
	browser._refresh()
	assert(browser._results.size() == 102)
	await _double_click_card(browser, "gz_tile_02")
	assert(designer._placement_record.kind == "tile")
	assert(designer.document.working.is_empty(), "Opening the block brush must not place through the browser.")
	designer.cancel_placement()
	# The compact palette starts the same placement flow with one real click.
	var panel: Control = designer.panel
	assert(panel._tabs.current_tab == 0)
	var palette: Control = panel._palette
	palette._category.select(LIBRARY.CATEGORIES.find("Enemies"))
	palette._category.item_selected.emit(LIBRARY.CATEGORIES.find("Enemies"))
	assert(palette._cards.get_child_count() == 3)
	palette._search.text = "skater"
	palette._search.text_changed.emit("skater")
	for frame in 3: await process_frame
	var quick_card: Control = palette._cards.get_child(0)
	_click(quick_card.get_global_rect().get_center())
	assert(not browser.visible and designer.tool == "place" and designer.document.working.is_empty())
	assert(designer._placement_record.template == "skater_enemy")
	_click(designer.canvas.screen_at(Vector2(18, 0.02)), false, true)
	assert(designer.document.working.size() == 1 and designer.tool == "place" and panel._tabs.current_tab == 0)
	_click(designer.canvas.screen_at(Vector2(20, 0.02)))
	assert(designer.document.working.size() == 2 and designer.tool == "move" and panel._tabs.current_tab == 1)
	panel._tabs.current_tab = 2
	panel._list_selected(0, true)
	await process_frame
	assert(panel._tabs.current_tab == 2, "Selecting from the placed list should keep it open for group selection.")
	panel.focus_selected_settings()
	assert(panel._tabs.current_tab == 1)
	designer.undo()
	designer.undo()
	assert(designer.document.working.is_empty())
	var ids := {}
	var x := 20.48
	for template in CATALOG.CORE_ENTRIES:
		var entry: Dictionary = CATALOG.ENTRIES[template]
		designer.begin_placement(template, CATALOG.defaults(template))
		var location := Vector2(x, 3.84 if entry.kind in ["platform", "flyer"] else 0.02)
		var id: String = designer.place_catalog_object(location)
		assert(not id.is_empty())
		ids[template] = id
		assert(designer.document.working[id].template == template)
		if entry.anchor == "ground" and entry.kind != "platform":
			assert(is_equal_approx(designer.document.working[id].values.y, float(entry.get("feet", 0))))
		x += 7.68
	# Every created type survives grouped duplication/removal/undo as a template.
	designer.choose(ids.skater_enemy)
	designer.choose(ids.checkpoint, true)
	var original: Dictionary = designer.document.working.duplicate(true)
	var nonfinite := original.duplicate(true)
	nonfinite[ids.skater_enemy].values.x = NAN
	assert(not designer.commit_records("Invalid edit", nonfinite))
	assert(designer.document.working == original)
	designer.duplicate_selected()
	assert(designer.selection.size() == 2 and designer.document.working.size() == original.size() + 2)
	designer.remove_selected()
	assert(designer.document.working == original)
	designer.undo()
	assert(designer.document.working.size() == original.size() + 2)
	designer.undo()
	assert(designer.document.working == original)
	# One verified disk save contains all templates; no source-project save is used.
	var path := "user://browser_layout_%d.json" % Time.get_ticks_usec()
	var save_error := STORE.save(designer.document, path)
	assert(save_error.is_empty(), save_error)
	var fresh := DOCUMENT.new()
	var base := (load(REGISTRY.SECTIONS.sandbox) as PackedScene).instantiate()
	var stored := STORE.read(path)
	assert(fresh.open(base, stored.data, stored.hash).is_empty())
	for id in fresh.working:
		if fresh.working[id] != designer.document.working[id]:
			print("Disk record: ", fresh.working[id])
			print("Editor record: ", designer.document.working[id])
	assert(fresh.working == designer.document.working)
	base.free()
	var invalid: Dictionary = stored.data.duplicate(true)
	invalid.created[ids.skater_enemy].template = "res://arbitrary.gd"
	base = (load(REGISTRY.SECTIONS.sandbox) as PackedScene).instantiate()
	assert(not RESOLVER.apply_layout(base, invalid).is_empty())
	assert(base.get_node_or_null("DesignerObjects") == null, "Reject unknown templates before adding any object.")
	base.free()
	# Legacy platform-only JSON retains its values through the schema upgrade.
	var legacy: Dictionary = stored.data.duplicate(true)
	legacy.schema = 1
	legacy.erase("catalog")
	legacy.created = {"platform_legacy": original[ids.grass_platform].values}
	var legacy_result: Dictionary = fresh.resolve(legacy)
	assert(legacy_result.error.is_empty() and legacy_result.records.platform_legacy.kind == "platform")
	designer.test_layout()
	var level: LevelSession3D = app.current_level
	var runtime: Dictionary = OBJECTS.inspect(level).nodes
	assert(runtime.size() == original.size())
	var skater: StompableEnemy3D = runtime[ids.skater_enemy]
	skater.receive_melee_hit(Vector3.ZERO, CombatHit.new(skater.health.current, &"fixture"))
	assert(skater.is_defeated())
	level._reset_world()
	assert(not skater.is_defeated())
	assert(is_equal_approx(skater.position.x, original[ids.skater_enemy].values.x))
	var checkpoint: LevelCheckpoint3D = runtime[ids.checkpoint]
	level.player.reset_at(checkpoint.respawn_transform())
	for frame in 16: await physics_frame
	assert(checkpoint.is_activated(), "An added checkpoint must respond to real grounded overlap.")
	assert(level.active_checkpoint_index() == -1, "An added checkpoint must not consume an authored route index.")
	level._reset_world()
	assert(is_equal_approx(level.player.position.x, checkpoint.position.x))
	var authored := (load("res://scenes/level/level_checkpoint.tscn") as PackedScene).instantiate() as LevelCheckpoint3D
	authored.route_index = 1
	level.add_child(authored)
	level._on_checkpoint_activated(authored)
	assert(level.active_checkpoint_index() == 1, "Later authored checkpoints must still advance normally.")
	var gunner: HandgunEnemy3D = runtime[ids.gunner_enemy]
	level.player.reset_at(Transform3D(Basis.IDENTITY, gunner.position + Vector3(-5, 0.2, 0)))
	for frame in 150:
		await physics_frame
		if gunner._shots_fired_total > 0: break
	assert(gunner._shots_fired_total > 0, "The placed gunner must fire real shots during Test.")
	var spikes: PixelSpikeRow3D = runtime[ids.spike_row]
	level.player.reset_at(Transform3D(Basis.IDENTITY, spikes.position + Vector3(0, 0.6, 0)))
	for frame in 3: await physics_frame
	assert(level.player.is_dead(), "Placed spikes must retain their lethal collision.")
	designer.return_to_editing()
	assert(designer.document.working == original)
	# Undo all additions, then leave without writing any project layout.
	designer.document.saved = {}
	designer.revert_layout()
	designer.request_close()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	# Every registered level uses the same browser and keeps gameplay frozen.
	for section in REGISTRY.SECTIONS:
		var definition := LevelDefinition.new()
		definition.level_id = StringName("dev_browser_" + section)
		definition.scene = load(REGISTRY.SECTIONS[section])
		assert(app._start_session(definition, null))
		designer.open_panel()
		assert(designer.is_editing(), "Designer should open in " + section)
		designer.object_browser.open()
		assert(designer.object_browser.visible)
		designer.object_browser.close()
		for area in app.current_level.find_children("*", "Area3D", true, false): assert(not area.monitoring)
		designer.request_close()
	app.free()
	print("Object browser passed: catalog placement, grounded previews, typed save/reload, mixed undo, real combat/checkpoints/hazards and every registered section.")
	quit(0)

func _double_click_card(browser: Control, id: String) -> void:
	for frame in 3: await process_frame
	var card: Control
	for candidate in browser._cards.get_children():
		if candidate.get_meta("catalog_id", "") == id: card = candidate
	assert(card != null)
	var point := card.get_global_rect().get_center()
	_click(point)
	await process_frame
	assert(is_instance_valid(card) and card.is_inside_tree() and browser.selected_id == id)
	_click(point, true)
	await process_frame

func _click(point: Vector2, double_click := false, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = double_click
	event.shift_pressed = shift
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	event.double_click = false
	root.push_input(event)
