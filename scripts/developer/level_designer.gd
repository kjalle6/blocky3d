extends CanvasLayer
## Owns the document and undo lifetime outside disposable preview/test scenes.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const PREVIEW := preload("res://scripts/developer/level_layout_preview.gd")
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
enum Mode { CLOSED, EDITING, TESTING, SAVING }
signal decoration_layer_changed(value: int)

var mode := Mode.CLOSED
var document: RefCounted
var selection: Array[String] = []
var history := UndoRedo.new()
var nodes: Dictionary = {}
var locked: Dictionary = {}
var camera: PixelSideCamera3D
var panel: Control
var canvas: Control
var context_menu: PopupMenu
var object_browser: Control
var _placement_record: Dictionary = {}
var decoration_layer := 0
var _ghost_root: Node3D
var _ghost: Node3D
var tool := "move"
var snap := 0.64
var palette := "grass"
var status := ""
var _definition: LevelDefinition
var _world_definition: WorldDefinition
var _source_path := ""
var _source_packed: PackedScene
var _abilities: Array[StringName] = []
var _was_paused := false
var _time_scale := 1.0
var _camera_transform := Transform3D.IDENTITY
var _camera_size := 16.0
var _recovery_due := -1.0
var _dialog: ConfirmationDialog
@onready var app := get_parent()

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	history.max_steps = 80
	canvas = preload("res://scripts/developer/level_designer_canvas.gd").new()
	canvas.designer = self
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = preload("res://scripts/developer/level_designer_panel.gd").new()
	panel.designer = self
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	context_menu = preload("res://scripts/developer/level_designer_context_menu.gd").new()
	context_menu.designer = self
	add_child(context_menu)
	object_browser = preload("res://scripts/developer/level_object_browser.gd").new()
	object_browser.designer = self
	add_child(object_browser)
	object_browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func is_active() -> bool:
	return mode != Mode.CLOSED

func is_editing() -> bool:
	return mode in [Mode.EDITING, Mode.SAVING]

func open_panel() -> void:
	if mode == Mode.TESTING:
		return_to_editing()
		return
	if is_active(): return
	var level: LevelSession3D = app.current_level
	if not REGISTRY.can_author() or not app.developer_tools_enabled: return
	if level == null or REGISTRY.section_for(level).is_empty():
		app.show_developer_message("Level designer", "Designer is not enabled for this scene. Open a game level or the Level Designer Sandbox.")
		return
	if level._resetting or level._completed or level.player.is_dead() or level.player.is_transition_running() or app.completion_fade.visible or app.active_interstitial() != null:
		app.show_developer_message("Level designer", "Finish the current death, transition or sequence before opening the designer.")
		return
	if not app.claim_developer_tool("designer"): return
	_definition = app.current_level_definition
	_world_definition = app.current_world_definition
	_source_path = level.scene_file_path
	_abilities = level.session_unlocked_abilities()
	_was_paused = get_tree().paused
	_time_scale = Engine.time_scale
	_camera_transform = level.camera.global_transform
	_camera_size = level.camera.size
	var error := _read_document()
	if not error.is_empty():
		app.release_developer_tool("designer")
		app.show_developer_message("Could not open the designer", error)
		return
	history.clear_history()
	selection.clear()
	mode = Mode.EDITING
	visible = true
	_enter_editing()
	set_status("Build: choose a zone and block, then click or drag · Add objects: props and enemies · Right-click for actions")
	var recovery := STORE.recover(document)
	if not recovery.is_empty() and recovery != document.saved:
		_offer_recovery(recovery)

func _read_document() -> String:
	var packed := ResourceLoader.load(_source_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null: return "The structural scene could not be loaded."
	var base := packed.instantiate()
	var section := REGISTRY.section_for(base)
	var saved := STORE.read(REGISTRY.save_path(section))
	var fresh := DOCUMENT.new()
	var error: String = saved.error if not saved.error.is_empty() else fresh.open(base, saved.data, saved.hash)
	base.free()
	if error.is_empty():
		document = fresh
		_source_packed = packed
	return error

func _enter_editing() -> void:
	cancel_placement()
	object_browser.hide()
	context_menu.hide()
	mode = Mode.EDITING
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_release_inputs()
	MIX.clear_gameplay_tails()
	app._transition_serial += 1
	# Rebuild the preview from this document's immutable source snapshot. External
	# scene changes block saving/testing, but never destroy the editable draft.
	app._start_session(_definition, _world_definition, _abilities, _source_packed, document.serialize(), true, document.fingerprint)
	var level: LevelSession3D = app.current_level
	if level == null or not level.get_meta("layout_preview", false): return
	nodes = OBJECTS.inspect(level).nodes
	_collect_locked(level)
	camera = PixelSideCamera3D.new()
	camera.name = "DesignerCamera"
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	level.add_child(camera)
	camera.global_transform = _camera_transform
	camera.size = _camera_size
	camera.make_current()
	if level.background != null:
		level.background.bind_camera(camera)
		level.background.snap_to_camera(true)
	app.menu_hint.hide()
	refresh_presentation()
	canvas.show()
	canvas.grab_focus()
	panel.refresh()

func test_layout() -> void:
	if mode != Mode.EDITING or dialog_open(): return
	cancel_placement()
	object_browser.hide()
	context_menu.hide()
	if REGISTRY.fingerprint(document.section) != document.fingerprint:
		set_status("The base scene changed. Reload saved before testing; your current draft is intact.")
		return
	canvas.cancel_gesture()
	_camera_transform = camera.global_transform
	_camera_size = camera.size
	_flush_recovery()
	_release_inputs()
	mode = Mode.TESTING
	var packed := ResourceLoader.load(_source_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not app._start_session(_definition, _world_definition, _abilities, packed, document.serialize()):
		mode = Mode.EDITING
		return
	get_tree().paused = false
	Engine.time_scale = _time_scale
	canvas.hide()
	nodes.clear()
	camera = null
	panel.refresh()
	set_status("Testing your draft · Esc returns to editing · R reloads · F1 opens tools")

func return_to_editing() -> void:
	if mode != Mode.TESTING: return
	_enter_editing()
	set_status("Back in the editor. Test movement and defeated enemies were discarded.")

func commit_records(label: String, records: Dictionary) -> bool:
	if not is_editing() or records == document.working: return false
	var before: Dictionary = document.working.duplicate(true)
	# Camera/world vectors use float32, while JSON uses doubles. Canonicalize
	# only edited numbers, below pixel precision, so a save cannot create a
	# microscopic dirty change on reload. Untouched authored values stay exact.
	for id in records:
		if records[id] == document.saved.get(id) or records[id] == document.base.get(id): continue
		for key in records[id].values:
			var value: Variant = records[id].values[key]
			if value is int:
				records[id].values[key] = float(value)
			elif value is float and is_finite(value) and (not before.has(id) or before[id].values.get(key) != value):
				records[id].values[key] = String.num(value, 6).to_float()
	if records == before: return false
	document.working = records
	var validation: Dictionary = document.resolve(document.serialize())
	document.working = before
	if not validation.error.is_empty():
		set_status(validation.error)
		return false
	history.create_action(label)
	history.add_do_method(_restore_records.bind(records.duplicate(true)))
	history.add_undo_method(_restore_records.bind(before))
	history.commit_action()
	set_status(label + " · Undo is available")
	return true

func _restore_records(records: Dictionary) -> void:
	var previous: Dictionary = document.working
	document.working = records.duplicate(true)
	if is_editing():
		for id in nodes.keys():
			if not records.has(id):
				var node: Node = nodes[id]
				node.get_parent().remove_child(node)
				node.free()
				nodes.erase(id)
		for id in records:
			var record: Dictionary = records[id]
			if nodes.has(id) and previous.get(id, {}).get("template", "") != record.get("template", ""):
				var old: Node = nodes[id]
				old.get_parent().remove_child(old)
				old.free()
				nodes.erase(id)
			if not nodes.has(id):
				nodes[id] = OBJECTS.create_object(app.current_level, id, record)
			elif not previous.has(id) or previous[id].values != record.values:
				OBJECTS.apply(nodes[id], record.kind, record.values, true)
		_order_decorations()
		PREVIEW.finish(app.current_level)
		if camera != null: camera.make_current()
	selection.assign(selection.filter(func(id: String) -> bool: return records.has(id)))
	# Coalesce edits without postponing recovery indefinitely during long nudges.
	if _recovery_due < 0.0: _recovery_due = 0.6
	panel.refresh()
	canvas.queue_redraw()

func choose(id: String, additive := false) -> void:
	cancel_placement()
	if not additive: selection.clear()
	if document.working.has(id):
		if additive and id in selection: selection.erase(id)
		else: selection.append(id)
	tool = "move"
	panel.refresh()
	canvas.queue_redraw()

func update_values(changes: Dictionary) -> void:
	if selection.size() != 1: return
	var records: Dictionary = document.working.duplicate(true)
	var record: Dictionary = records[selection[0]]
	# Numeric resizing keeps the left/bottom edge, just like dragging that edge's opposite handle.
	if changes.has("width") and not changes.has("x"):
		changes.x = record.values.x + (float(changes.width) - record.values.width) * 0.5
	if changes.has("height") and record.kind == "platform" and not changes.has("y"):
		changes.y = record.values.y + (float(changes.height) - record.values.height) * 0.5
	records[selection[0]].values.merge(changes, true)
	commit_records("Change object settings", records)

func add_platform(rect: Rect2) -> void:
	var id := "platform_" + Crypto.new().generate_random_bytes(12).hex_encode()
	var values := {"x": rect.get_center().x, "y": rect.get_center().y, "width": rect.size.x,
		"height": rect.size.y, "style": palette, "surface": palette,
		"left_cap": true, "right_cap": true, "bottom_cap": true}
	var records: Dictionary = document.working.duplicate(true)
	records[id] = DOCUMENT.new_platform_record(values)
	if commit_records("Build platform", records): choose(id)

func can_flip_selected() -> bool:
	if selection.is_empty(): return false
	for id in selection:
		if OBJECTS.horizontal_flip_field(document.working[id].kind).is_empty(): return false
	return true

func flip_selected() -> void:
	if not is_editing() or not can_flip_selected(): return
	canvas.cancel_gesture()
	var records: Dictionary = document.working.duplicate(true)
	for id in selection:
		var key := OBJECTS.horizontal_flip_field(records[id].kind)
		records[id].values[key] = not bool(records[id].values.get(key, false))
	commit_records("Flip horizontally", records)

func can_duplicate_selected() -> bool:
	if selection.is_empty(): return false
	for id in selection:
		var record: Dictionary = document.working[id]
		if not record.removable or (not record.created and record.kind != "platform"): return false
	return true

func can_remove_selected() -> bool:
	if selection.is_empty(): return false
	for id in selection:
		if not document.working[id].removable: return false
	return true

func can_revert_selected() -> bool:
	var changed := false
	for id in selection:
		if not document.saved.has(id): return false
		changed = changed or document.working[id] != document.saved[id]
	return changed

func revert_selected() -> void:
	if not is_editing() or not can_revert_selected(): return
	canvas.cancel_gesture()
	var records: Dictionary = document.working.duplicate(true)
	for id in selection: records[id] = document.saved[id].duplicate(true)
	commit_records("Revert selection to last save", records)

func duplicate_selected() -> void:
	if not can_duplicate_selected():
		set_status("Added objects and approved independent platforms can be duplicated.")
		return
	var records: Dictionary = document.working.duplicate(true)
	var duplicates: Array[String] = []
	for id in selection:
		var record: Dictionary = records[id]
		var new_id := "object_" + Crypto.new().generate_random_bytes(12).hex_encode()
		var values: Dictionary = record.values.duplicate(true)
		values.x += OBJECTS.TILE
		values.y += OBJECTS.TILE
		records[new_id] = OBJECTS.new_record(record.template, values) if record.created else DOCUMENT.new_platform_record(values)
		duplicates.append(new_id)
	if commit_records("Duplicate selection", records):
		selection = duplicates
		panel.refresh()

func remove_selected() -> void:
	if not can_remove_selected():
		set_status("This existing object is protected from removal.")
		return
	var records: Dictionary = document.working.duplicate(true)
	for id in selection:
		records.erase(id)
	commit_records("Remove selection", records)

func nudge(direction: Vector2) -> void:
	var records: Dictionary = document.working.duplicate(true)
	var distance := snap if snap > 0.0 else 0.04
	for id in selection:
		records[id].values.x += direction.x * distance
		records[id].values.y += direction.y * distance
	commit_records("Nudge selection", records)

func undo() -> void:
	canvas.cancel_gesture()
	if history.undo(): set_status("Undid the last edit")

func redo() -> void:
	canvas.cancel_gesture()
	if history.redo(): set_status("Redid the edit")

func save_layout() -> bool:
	if mode != Mode.EDITING: return false
	cancel_placement()
	canvas.cancel_gesture()
	mode = Mode.SAVING
	var error := STORE.save(document)
	mode = Mode.EDITING
	if error.is_empty():
		STORE.clear_recovery(document.section)
		_recovery_due = -1.0
		set_status("Saved to the project. Future launches use this layout.")
	else:
		var review_error := STORE.keep_review(document)
		if not review_error.is_empty(): error += "\n" + review_error
		set_status(error)
		app.show_developer_message("Layout was not saved", error + "\nUse Reload saved, or keep the recovery draft for review with Codex.")
	panel.refresh()
	return error.is_empty()

func revert_layout() -> void:
	canvas.cancel_gesture()
	if document.has_changes(): commit_records("Revert to last save", document.saved.duplicate(true))

func reload_saved() -> void:
	if document.has_changes():
		var error := STORE.keep_review(document)
		if not error.is_empty():
			set_status(error + " The current layout has not been reloaded.")
			return
		_confirm("Reload saved layout?", "A recovery copy of your current draft has been kept for review. Reload the saved layout and clear undo history?", _reload_confirmed)
	else: _reload_confirmed()

func _reload_confirmed() -> void:
	var error := _read_document()
	if not error.is_empty():
		set_status(error)
		return
	history.clear_history()
	selection.clear()
	_enter_editing()
	set_status("Reloaded the saved layout and structural scene")

func request_close(to_menu := false) -> void:
	cancel_placement()
	object_browser.hide()
	context_menu.hide()
	if mode == Mode.TESTING: return_to_editing()
	if not is_editing() or dialog_open(): return
	canvas.cancel_gesture()
	if not document.has_changes():
		_finish_close(to_menu)
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Unsaved layout changes"
	_dialog.dialog_text = "Save this layout before leaving the designer?"
	_dialog.ok_button_text = "Save"
	_dialog.cancel_button_text = "Cancel"
	_dialog.add_button("Discard", false, "discard")
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialog)
	_dialog.confirmed.connect(func() -> void:
		_close_dialog()
		if save_layout(): _finish_close(to_menu))
	_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			_close_dialog()
			_finish_close(to_menu))
	_dialog.canceled.connect(_close_dialog)
	_dialog.popup_centered(Vector2i(540, 180))

func _finish_close(to_menu: bool) -> void:
	STORE.clear_recovery(document.section)
	_recovery_due = -1.0
	mode = Mode.CLOSED
	visible = false
	history.clear_history()
	nodes.clear()
	locked.clear()
	selection.clear()
	camera = null
	get_tree().paused = _was_paused
	Engine.time_scale = _time_scale
	# The old session may have hidden the pointer for its aiming crosshair.
	# That session is replaced; the new HUD owns whether aiming hides it again.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_release_inputs()
	app.release_developer_tool("designer")
	if to_menu: app.show_level_select()
	else:
		var packed := ResourceLoader.load(_source_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if not app._start_session(_definition, _world_definition, _abilities, packed):
			app.show_level_select()

func dialog_open() -> bool:
	return is_instance_valid(_dialog)

func _confirm(title: String, message: String, action: Callable) -> void:
	if dialog_open(): return
	_dialog = ConfirmationDialog.new()
	_dialog.title = title
	_dialog.dialog_text = message
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialog)
	_dialog.confirmed.connect(func() -> void:
		_close_dialog()
		action.call())
	_dialog.canceled.connect(_close_dialog)
	_dialog.popup_centered(Vector2i(600, 180))

func _offer_recovery(records: Dictionary) -> void:
	_confirm("Recover an unsaved layout?", "A compatible draft from an earlier session is available. Restore it for review? It will not replace the project save until you choose Save.", func() -> void: commit_records("Recover draft", records))

func _close_dialog() -> void:
	if is_instance_valid(_dialog): _dialog.queue_free()
	_dialog = null

func set_status(message: String) -> void:
	status = message
	if panel != null: panel.update_status()

func _process(delta: float) -> void:
	if is_active() and _recovery_due >= 0.0:
		_recovery_due -= delta
		if _recovery_due < 0.0: _flush_recovery()

func _flush_recovery() -> void:
	if document != null and document.has_changes():
		var error := STORE.keep_recovery(document)
		if not error.is_empty(): set_status(error)

func _exit_tree() -> void:
	if is_active():
		_flush_recovery()
		get_tree().paused = _was_paused
		Engine.time_scale = _time_scale
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not is_active() or dialog_open() or not event is InputEventKey or not event.pressed or event.echo: return
	if context_menu.visible or object_browser.visible: return
	if mode == Mode.TESTING:
		if event.physical_keycode in [KEY_ESCAPE, KEY_F1]:
			get_viewport().set_input_as_handled()
			return_to_editing()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	var handled := true
	match event.physical_keycode:
		KEY_ESCAPE:
			if cancel_placement():
				canvas.cancel_gesture()
				panel.refresh()
				set_status("Placement cancelled")
			elif not canvas.cancel_gesture():
				selection.clear()
				tool = "move"
				panel.refresh()
		KEY_Z:
			if event.ctrl_pressed:
				if event.shift_pressed: redo()
				else: undo()
			else: handled = false
		KEY_Y:
			if event.ctrl_pressed: redo()
			else: handled = false
		KEY_S:
			if event.ctrl_pressed: save_layout()
			else: handled = false
		KEY_D:
			if event.ctrl_pressed: duplicate_selected()
			else: handled = false
		KEY_DELETE: remove_selected()
		KEY_F: frame_selection()
		_: handled = false
	if handled: get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if mode != Mode.EDITING or dialog_open() or not event.is_pressed() or not canvas.has_focus(): return
	if context_menu.visible or object_browser.visible: return
	if not event is InputEventKey: return
	match event.physical_keycode:
		KEY_LEFT: nudge(Vector2.LEFT)
		KEY_RIGHT: nudge(Vector2.RIGHT)
		KEY_UP: nudge(Vector2(0, 1))
		KEY_DOWN: nudge(Vector2(0, -1))
		_: return
	get_viewport().set_input_as_handled()

func frame_selection() -> void:
	if camera == null: return
	var bounds := Rect2()
	for id in selection:
		var next := OBJECTS.bounds(document.working[id])
		bounds = next if bounds.size == Vector2.ZERO else bounds.merge(next)
	if bounds.size == Vector2.ZERO:
		var spawn: Vector3 = app.current_level.spawn_point.position
		bounds = Rect2(Vector2(spawn.x - 8.0, spawn.y - 3.0), Vector2(16, 8))
	var viewport := get_viewport().get_visible_rect().size
	var inspector_width := 0.0 if panel.inspector_collapsed() else 368.0
	var available := Vector2(maxf(320.0, viewport.x - inspector_width - 28.0), maxf(240.0, viewport.y - 220.0))
	camera.size = clampf(maxf(bounds.size.y * viewport.y / available.y, bounds.size.x * viewport.y / available.x) * 1.6, 10.0, 120.0)
	var center := bounds.get_center()
	# Leave space for the inspector on the right.
	camera.position.x = center.x + inspector_width * 0.5 * camera.size / viewport.y
	camera.position.y = center.y + 30.0 * camera.size / viewport.y
	refresh_presentation()

func refresh_presentation() -> void:
	if camera == null: return
	var level: LevelSession3D = app.current_level
	if level.background != null: level.background.snap_to_camera()
	for node in level.find_children("*", "PixelRegionGrade3D", true, false): node._process(0.0)
	canvas.queue_redraw()

func placement_warning(id: String) -> String:
	if not nodes.has(id) or not document.working.has(id): return ""
	var record: Dictionary = document.working[id]
	if record.kind not in ["enemy", "gunner", "tank", "crate", "checkpoint", "chest"]: return ""
	var node: Node3D = nodes[id]
	var feet := node.global_position
	if record.kind in ["enemy", "gunner", "tank", "crate"]:
		var collision := node.get_node("BodyCollision") as CollisionShape3D
		if collision == null: return ""
		feet = collision.global_position
		if collision.shape is BoxShape3D: feet.y -= collision.shape.size.y * 0.5
		elif collision.shape is CapsuleShape3D: feet.y -= collision.shape.height * 0.5
		else: return ""
	if is_finite(OBJECTS.nearby_floor(app.current_level, Vector2(feet.x, feet.y), 0.16)): return ""
	return "No supporting floor detected here. Check the height and use Test before saving."

func _collect_locked(level: Node) -> void:
	locked.clear()
	for node in level.find_children("*", "", true, false):
		if node.has_meta("layout_id") or not node is Node3D: continue
		if node is PixelPlatform3D or node is PixelInteriorTerrain3D or node is StompableEnemy3D or node is HandgunEnemy3D or node is PixelSpikeRow3D or node is LevelCheckpoint3D or node is HoveringHazard3D or node is LevelTransition3D or node.has_meta("layout_locked"):
			var bounds := Rect2(Vector2(node.global_position.x - 0.7, node.global_position.y), Vector2(1.4, 2.0))
			if node is PixelPlatform3D:
				bounds = Rect2(Vector2(node.global_position.x - node.size.x * 0.5, node.global_position.y - node.size.y * 0.5), Vector2(node.size.x, node.size.y))
			locked[str(level.get_path_to(node))] = {"name": str(node.name).capitalize(), "bounds": bounds,
				"reason": str(node.get_meta("layout_locked", "Protected scenery or scripted assembly — adjust with Codex."))}

func begin_placement(template: String, values: Dictionary) -> void:
	if mode != Mode.EDITING or not CATALOG.ENTRIES.has(template): return
	cancel_placement()
	canvas.cancel_gesture()
	selection.clear()
	_placement_record = OBJECTS.new_record(template, values)
	if _placement_record.kind == "decoration":
		_set_layer_value(_placement_record.values, decoration_layer)
	_ghost_root = Node3D.new()
	_ghost_root.name = "PlacementPreview"
	PREVIEW.prepare(_ghost_root)
	app.current_level.add_child(_ghost_root)
	_ghost = OBJECTS.instantiate_record(_placement_record)
	_ghost.set_meta("layout_kind", _placement_record.kind)
	_ghost_root.add_child(_ghost)
	_order_decorations()
	PREVIEW.finish(_ghost_root)
	for sprite in _ghost_root.find_children("*", "Sprite3D", true, false): sprite.modulate = Color(0.7, 1.0, 0.85, 0.55)
	tool = "place"
	update_placement(canvas.world_at(canvas.get_local_mouse_position()))
	panel.refresh()
	canvas.grab_focus()
	if _placement_record.kind == "tile":
		set_status("Building with %s · Click or drag · Right-click / Esc to finish" % preload("res://scripts/developer/level_object_library.gd").title(template))
	else:
		set_status("Placing %s · Click to place · Shift-click to keep placing · Right-click / Esc to cancel" % CATALOG.ENTRIES[template].name)

func cancel_placement() -> bool:
	var active := not _placement_record.is_empty()
	if is_instance_valid(_ghost_root): _ghost_root.free()
	_ghost_root = null
	_ghost = null
	_placement_record.clear()
	_order_decorations()
	if tool == "place": tool = "move"
	return active

func set_decoration_layer(value: int) -> void:
	decoration_layer = clampi(value, OBJECTS.MIN_DECORATION_LAYER, OBJECTS.MAX_DECORATION_LAYER)
	if not _placement_record.is_empty() and _placement_record.kind == "decoration":
		_set_layer_value(_placement_record.values, decoration_layer)
		OBJECTS.apply(_ghost, "decoration", _placement_record.values)
		_order_decorations()
	decoration_layer_changed.emit(decoration_layer)

func can_layer_selected() -> bool:
	if mode != Mode.EDITING or selection.is_empty(): return false
	for id in selection:
		if document.working[id].kind != "decoration": return false
	return true

func set_selected_decoration_layer(value: int) -> void:
	if not can_layer_selected(): return
	canvas.cancel_gesture()
	var records: Dictionary = document.working.duplicate(true)
	for id in selection: _set_layer_value(records[id].values, value)
	commit_records("Change decoration layer", records)

func shift_decoration_layer(step: int) -> void:
	if not can_layer_selected(): return
	canvas.cancel_gesture()
	var records: Dictionary = document.working.duplicate(true)
	for id in selection:
		var value := int(records[id].values.get("decoration_layer", 0)) + step
		if value < OBJECTS.MIN_DECORATION_LAYER or value > OBJECTS.MAX_DECORATION_LAYER:
			set_status("Decoration layers range from -100 to 100")
			return
		_set_layer_value(records[id].values, value)
	commit_records("Move decoration layer forward" if step > 0 else "Move decoration layer backward", records)

static func _set_layer_value(values: Dictionary, value: int) -> void:
	if value == 0: values.erase("decoration_layer")
	else: values.decoration_layer = value

func _order_decorations() -> void:
	# Include the placement preview so its overlap matches the chosen layer.
	var ordered := nodes.duplicate()
	if is_instance_valid(_ghost): ordered["placement_preview"] = _ghost
	# Scene changes can leave old preview references until inspect() refreshes them.
	for id in ordered.keys():
		if not is_instance_valid(ordered[id]): ordered.erase(id)
	OBJECTS.order_decorations(ordered)

func update_placement(point: Vector2) -> void:
	if _placement_record.is_empty() or not is_instance_valid(_ghost): return
	var entry: Dictionary = CATALOG.ENTRIES[_placement_record.template]
	var anchor := point.snapped(Vector2.ONE * snap) if snap > 0.0 else point
	if entry.anchor == "grid": anchor = (point / OBJECTS.TILE).floor() * OBJECTS.TILE + Vector2.ONE * OBJECTS.TILE * 0.5
	if entry.anchor == "ground":
		var floor_y := OBJECTS.nearby_floor(app.current_level, Vector2(anchor.x, point.y), 0.38, _ghost_root)
		if is_finite(floor_y): anchor.y = floor_y
	var values: Dictionary = _placement_record.values
	values.x = anchor.x
	values.y = anchor.y + (values.height * 0.5 if entry.kind == "platform" else float(entry.get("feet", 0)))
	_ghost.position = Vector3(values.x, values.y, 0)
	canvas.queue_redraw()

func place_catalog_object(point: Vector2, keep_placing := false) -> String:
	if tool != "place" or _placement_record.is_empty(): return ""
	update_placement(point)
	var record := _placement_record.duplicate(true)
	var id := "object_" + Crypto.new().generate_random_bytes(12).hex_encode()
	var records: Dictionary = document.working.duplicate(true)
	records[id] = record
	if not commit_records("Place " + record.name, records): return ""
	if not keep_placing: choose(id)
	else: set_status("Placing %s · Click again to place · Right-click / Esc to finish" % record.name)
	return id

static func _release_inputs() -> void:
	for action in InputMap.get_actions(): Input.action_release(action)
