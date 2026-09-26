extends SceneTree
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const MENU := preload("res://scripts/developer/level_designer_context_menu.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0, true).timeout.connect(func() -> void: quit(1))
	# Standalone runs use an isolated profile; a failed earlier probe can leave
	# a recovery dialog there that blocks the next probe's context menus.
	preload("res://scripts/developer/level_layout_store.gd").clear_recovery("sandbox")
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	await process_frame
	var definition := load("res://resources/dev/level_designer_sandbox.tres") as LevelDefinition
	app.load_developer_level(definition)
	await process_frame
	var designer: CanvasLayer = app.level_designer
	app.audio_tuning_panel.open_panel()
	assert(app.audio_tuning_panel.is_open)
	designer.open_panel()
	assert(designer.is_editing() and paused)
	assert(not app.audio_tuning_panel.is_open)
	assert(app.current_level.get_meta("layout_preview", false))
	app.audio_tuning_panel.open_panel()
	assert(not app.audio_tuning_panel.is_open)
	assert(designer.document.working.is_empty())
	await _check_object_flipping(app, designer)
	await _check_decoration_layers(app, designer)
	# Create a platform above the foundation; then round-trip through undo/test.
	designer.add_platform(Rect2(Vector2(17.92, 1.28), Vector2(5.12, 1.28)))
	assert(designer.document.working.size() == 1)
	var id: String = designer.selection[0]
	var original: Dictionary = designer.document.working.duplicate(true)
	designer.update_values({"width": 7.68})
	assert(designer.document.working[id].values.width == 7.68)
	designer.undo()
	assert(designer.document.working == original)
	designer.redo()
	designer.undo()
	var before_test: Dictionary = designer.document.working.duplicate(true)
	designer.test_layout()
	assert(not paused and designer.mode == designer.Mode.TESTING)
	assert(not app.current_level.get_meta("layout_preview", false))
	for frame in 3: await physics_frame
	assert(app.current_level.player.test_move(Transform3D(Basis.IDENTITY, Vector3(20, 3.3, 0)), Vector3.DOWN))
	designer.return_to_editing()
	assert(paused and designer.document.working == before_test)
	designer.undo()
	assert(designer.document.working.is_empty())
	designer.redo()
	assert(designer.document.working.size() == 1)
	designer.duplicate_selected()
	# Undo clears a removed selection, so explicitly reselect before duplicating.
	designer.choose(id)
	designer.duplicate_selected()
	assert(designer.document.working.size() == 2)
	assert(designer.selection[0] != id)
	var duplicate_id: String = designer.selection[0]
	designer.choose(id, true)
	var group_before: Dictionary = designer.document.working.duplicate(true)
	var history_count: int = designer.history.get_history_count()
	designer.nudge(Vector2(1, 1))
	assert(designer.history.get_history_count() == history_count + 1)
	for selected in [id, duplicate_id]:
		assert(is_equal_approx(designer.document.working[selected].values.x - group_before[selected].values.x, 0.64))
	designer.undo()
	assert(designer.document.working == group_before)
	designer.choose(duplicate_id)
	designer.remove_selected()
	assert(designer.document.working.size() == 1)
	# Input projection and gesture cancellation at both supported viewport sizes.
	designer.choose(id)
	for viewport in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport
		root.content_scale_size = viewport
		designer.frame_selection()
		await process_frame
		var record: Dictionary = designer.document.working[id]
		var center := OBJECTS.bounds(record).get_center()
		var screen: Vector2 = designer.canvas.screen_at(center)
		assert(designer.canvas.world_at(screen).distance_to(center) < 0.0001)
		assert(id in designer.canvas.hit_objects(screen))
		var baseline: Dictionary = designer.document.working.duplicate(true)
		designer.canvas._press(screen, false)
		designer.canvas._motion(screen + Vector2(60, -40))
		designer.canvas.cancel_gesture()
		assert(designer.document.working == baseline and designer.history.has_undo())
		# Route a real mouse click through the viewport, not a direct choose call.
		designer.choose("")
		var mouse := InputEventMouseButton.new()
		mouse.position = screen
		mouse.global_position = screen
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		root.push_input(mouse)
		mouse = mouse.duplicate()
		mouse.pressed = false
		root.push_input(mouse)
		assert(id in designer.selection, "The viewport click must reach the object under the cursor.")
		# A real right-click targets the pointed object, with the same coordinates.
		_mouse_click(screen, MOUSE_BUTTON_RIGHT)
		assert(designer.context_menu.visible and designer.selection == [id])
		assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.FLIP)), "Unsupported objects must not offer a cosmetic flip that disagrees with their geometry.")
		assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.REVERT)), "New unsaved objects are removed or undone, not reverted to a nonexistent save.")
		designer.context_menu.hide()
		await process_frame
		# Right-click while dragging only cancels; it must not move or open a menu.
		designer.canvas._press(screen, false)
		designer.canvas._motion(screen + Vector2(45, 20))
		_mouse_click(screen + Vector2(45, 20), MOUSE_BUTTON_RIGHT)
		assert(not designer.context_menu.visible and designer.canvas.gesture.is_empty())
		assert(designer.document.working == baseline)
	# Close must offer a real cancel path without destroying draft/history.
	designer.request_close()
	assert(designer.dialog_open())
	designer._dialog.canceled.emit()
	assert(designer.is_editing() and designer.document.has_changes())
	designer.revert_layout()
	assert(not designer.document.has_changes())
	designer.request_close()
	assert(not designer.is_active() and not paused)
	# Audit the populated production section, including guarded script callbacks.
	app.load_developer_level(load("res://resources/dev/green_zone_finale_wip.tres"))
	designer.open_panel()
	assert(designer.is_editing())
	assert(designer.document.working.size() >= 7, "Keep authored objects and user-added layout objects.")
	var level: LevelSession3D = app.current_level
	var initial_position: Vector3 = level.get_node("OpeningPatrol").position
	for frame in 4: await process_frame
	assert(level.get_node("OpeningPatrol").position == initial_position)
	assert(not level.get_node("ShooterAreaTransition").body_entered.is_connected(level.get_node("ShooterAreaTransition")._on_body_entered))
	assert(not level.get_node("Hazards/FinalLandingSpikes").monitoring)
	var preview_player := level.player
	preview_player.ground_jump_started.emit()
	preview_player.landed.emit(12.0)
	for node in level.find_children("*", "AudioStreamPlayer", true, false): assert(not node.playing)
	assert(not preview_player.is_dead())
	assert(designer.locked.size() > 5)
	designer.choose("outdoors_dash_patrol")
	designer.update_values({"x": 51.2, "left": 1.28, "right": 2.56, "facing_right": false})
	var authored_records: Dictionary = designer.document.working.duplicate(true)
	designer.test_layout()
	var actor: StompableEnemy3D = app.current_level.get_node("DashLandingPatrol")
	actor.receive_melee_hit(Vector3.ZERO, CombatHit.new(actor.health.current, &"fixture"))
	assert(actor.is_defeated())
	designer.return_to_editing()
	assert(designer.document.working == authored_records)
	assert(not app.current_level.get_node("DashLandingPatrol").is_defeated())
	assert(is_equal_approx(app.current_level.get_node("DashLandingPatrol").position.x, 51.2))
	# Revert restores only the clicked saved object; other edits and undo survive.
	designer.choose("outdoors_opening_patrol")
	designer.nudge(Vector2.RIGHT)
	var other_edit: Dictionary = designer.document.working.outdoors_opening_patrol.duplicate(true)
	designer.choose("outdoors_dash_patrol")
	designer.context_menu.open_at(Vector2(400, 300))
	assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.DUPLICATE)))
	assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.REMOVE)))
	designer.context_menu.id_pressed.emit(MENU.Action.REVERT)
	assert(designer.document.working.outdoors_dash_patrol == designer.document.saved.outdoors_dash_patrol)
	assert(designer.document.working.outdoors_opening_patrol == other_edit)
	designer.undo()
	assert(designer.document.working.outdoors_dash_patrol == authored_records.outdoors_dash_patrol)
	designer.revert_layout()
	designer.request_close()
	app.free()
	print("Level designer passed: chest/object flipping, opening/reset, saved facing, preview isolation, palette, undo/redo, fresh testing, locks and audio ownership.")
	quit(0)

func _check_object_flipping(app: Node, designer: CanvasLayer) -> void:
	const DOCUMENT = preload("res://scripts/developer/level_layout_document.gd")
	const STORE = preload("res://scripts/developer/level_layout_store.gd")
	var records: Dictionary = designer.document.working.duplicate(true)
	var values := OBJECTS.CATALOG.defaults("supply_chest")
	values.x = 8.96
	assert(not values.has("flip_h") and OBJECTS.validate("chest", values).is_empty(), "Older chests keep their original facing without migration of their values.")
	records["object_flip_chest"] = OBJECTS.new_record("supply_chest", values)
	assert(designer.commit_records("Add flip fixture", records), designer.status)
	designer.choose("object_flip_chest")
	var original: Dictionary = designer.document.working.duplicate(true)
	var chest := designer.nodes.object_flip_chest as ItemReward3D
	var original_position := chest.position
	var shape: BoxShape3D = chest.get_child(0).shape
	var original_size := shape.size
	var toggle := designer.panel.find_child("Property_flip_h", true, false) as CheckButton
	assert(toggle != null and not toggle.button_pressed)
	toggle.button_pressed = true
	assert(chest.visual.flip_h and designer.document.working.object_flip_chest.values.flip_h)
	assert(chest.position == original_position and chest.basis == Basis.IDENTITY and shape.size == original_size)
	designer.undo()
	assert(designer.document.working == original and not chest.visual.flip_h)
	designer.context_menu.open_at(Vector2(400, 300))
	assert(not designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.FLIP)))
	designer.context_menu.id_pressed.emit(MENU.Action.FLIP)
	assert(chest.visual.flip_h)
	designer.undo()
	assert(not chest.visual.flip_h)
	designer.redo()
	assert(chest.visual.flip_h)
	var flipped: Dictionary = designer.document.working.duplicate(true)
	# Save/reload an isolated file, leaving the project's layout untouched.
	var base: Node = load("res://scenes/dev/level_designer_sandbox.tscn").instantiate()
	var document := DOCUMENT.new()
	assert(document.open(base, designer.document.serialize()).is_empty())
	var path := "user://chest_flip_%d.json" % Time.get_ticks_usec()
	assert(STORE.save(document, path).is_empty())
	var saved := STORE.read(path)
	var reloaded := DOCUMENT.new()
	assert(reloaded.open(base, saved.data, saved.hash).is_empty())
	assert(reloaded.working == flipped)
	base.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var invalid := values.duplicate()
	invalid.flip_h = "yes"
	assert(not OBJECTS.validate("chest", invalid).is_empty())
	designer.test_layout()
	chest = OBJECTS.inspect(app.current_level).nodes.object_flip_chest
	assert(chest.visual.flip_h and chest.position == original_position)
	assert(chest.collect())
	chest._process(0.3)
	assert(chest.visual.flip_h and chest.visual.texture.region.position.x > 0)
	chest.reset_run()
	assert(chest.visual.flip_h and chest.visual.texture.region.position.x == 6 * 32)
	designer.return_to_editing()
	assert(designer.document.working == flipped)
	chest = designer.nodes.object_flip_chest
	assert(chest.visual.flip_h and chest.visual.texture.region.position.x == 0)
	designer.choose("object_flip_chest")
	designer.duplicate_selected()
	var duplicate: String = designer.selection[0]
	assert(designer.nodes[duplicate].visual.flip_h)
	designer.choose("object_flip_chest", true)
	var group_before: Dictionary = designer.document.working.duplicate(true)
	var history_count: int = designer.history.get_history_count()
	designer.flip_selected()
	assert(designer.history.get_history_count() == history_count + 1)
	for id in designer.selection:
		assert(not designer.nodes[id].visual.flip_h)
		assert(designer.document.working[id].values.x == group_before[id].values.x)
	designer.undo()
	assert(designer.document.working == group_before)
	designer.revert_layout()
	assert(designer.document.working.is_empty())

func _check_decoration_layers(app: Node, designer: CanvasLayer) -> void:
	const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
	const STORE := preload("res://scripts/developer/level_layout_store.gd")
	var records: Dictionary = designer.document.working.duplicate(true)
	var values := OBJECTS.CATALOG.defaults("gz_prop_fence_6")
	values.x = 20.0
	# ID order deliberately opposes the layer we will give the box.
	records["object_z_fence"] = OBJECTS.new_record("gz_prop_fence_6", values)
	records["object_a_box"] = OBJECTS.new_record("gz_prop_other_box", values)
	assert(designer.commit_records("Add layer fixtures", records), designer.status)
	var original: Dictionary = designer.document.working.duplicate(true)
	var fence: Node3D = designer.nodes.object_z_fence
	var box: Node3D = designer.nodes.object_a_box
	assert(box.get_node("Visual").position.z < fence.get_node("Visual").position.z)
	designer.choose("object_a_box")
	var picker := designer.panel._properties.find_child("DecorationLayer", true, false) as SpinBox
	assert(picker != null)
	picker.value = 1
	assert(box.get_node("Visual").position.z > fence.get_node("Visual").position.z)
	assert(box.position == fence.position and box.position.z == 0)
	assert(OBJECTS.read_values(box, "decoration").decoration_layer == 1)
	designer.undo()
	assert(designer.document.working == original)
	assert(box.get_node("Visual").position.z < fence.get_node("Visual").position.z)
	designer.redo()
	assert(box.get_node("Visual").position.z > fence.get_node("Visual").position.z)
	designer.context_menu.open_at(Vector2(400, 300))
	designer.context_menu.id_pressed.emit(MENU.Action.LAYER_BACK)
	assert(designer.document.working == original, "Returning to layer zero preserves the legacy record.")
	designer.undo()
	designer.choose("object_z_fence", true)
	var group_before: Dictionary = designer.document.working.duplicate(true)
	var count: int = designer.history.get_version()
	designer.shift_decoration_layer(-1)
	assert(designer.history.get_version() == count + 1)
	assert(designer.document.working.object_z_fence.values.decoration_layer == -1)
	assert(box.get_node("Visual").position.z > fence.get_node("Visual").position.z)
	designer.undo()
	assert(designer.document.working == group_before)
	# Both browsers share the new-placement layer. Changing it updates an active ghost.
	var placement_picker := designer.panel._palette.find_child("DecorationLayer", true, false) as SpinBox
	placement_picker.value = -2
	assert(designer.object_browser.find_child("DecorationLayer", true, false).value == -2)
	designer.begin_placement("gz_prop_other_box", OBJECTS.CATALOG.defaults("gz_prop_other_box"))
	assert(designer._ghost.get_node("Visual").position.z < fence.get_node("Visual").position.z)
	designer.object_browser.find_child("DecorationLayer", true, false).value = 2
	assert(placement_picker.value == 2)
	assert(designer._ghost.get_node("Visual").position.z > box.get_node("Visual").position.z)
	var first: String = designer.place_catalog_object(Vector2(23, 0), true)
	var second: String = designer.place_catalog_object(Vector2(25, 0))
	assert(designer.document.working[first].values.decoration_layer == 2)
	assert(designer.document.working[second].values.decoration_layer == 2)
	var layered: Dictionary = designer.document.working.duplicate(true)
	var base: Node = load("res://scenes/dev/level_designer_sandbox.tscn").instantiate()
	var document := DOCUMENT.new()
	assert(document.open(base, designer.document.serialize()).is_empty())
	var path := "user://decoration_layers_%d.json" % Time.get_ticks_usec()
	assert(STORE.save(document, path).is_empty())
	var saved := STORE.read(path)
	var reloaded := DOCUMENT.new()
	assert(reloaded.open(base, saved.data, saved.hash).is_empty())
	assert(reloaded.working == layered)
	base.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for invalid in [-101, 101, 0.5, "front", true]:
		var bad := values.duplicate()
		bad.decoration_layer = invalid
		assert(not OBJECTS.validate("decoration", bad).is_empty())
	designer.test_layout()
	var live: Dictionary = OBJECTS.inspect(app.current_level).nodes
	assert(live.object_a_box.get_node("Visual").position.z > live.object_z_fence.get_node("Visual").position.z)
	assert(live[first].get_node("Visual").position.z > live.object_a_box.get_node("Visual").position.z)
	await process_frame
	designer.return_to_editing()
	assert(designer.document.working == layered)
	designer.revert_layout()
	designer.set_decoration_layer(0)
	assert(designer.document.working.is_empty())
	print("Decoration layers passed: legacy order, inspector/context/group undo, live placement preview, both browsers, save/reload and runtime.")

func _mouse_click(point: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
