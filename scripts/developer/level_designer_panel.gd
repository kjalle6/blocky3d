extends Control
## Plain-language inspector. It exposes only the registered whole-object fields.
var designer: CanvasLayer
var _toolbar: PanelContainer
var _sidebar: PanelContainer
var _test_bar: PanelContainer
var _status: Label
var _title: Label
var _list: ItemList
var _properties: VBoxContainer
var _filter: OptionButton
var _show_locked: CheckButton
var _undo: Button
var _redo: Button
var _save: Button
var _move: Button
var _build: Button
var _rebuilding := false
var _sidebar_collapsed := false
var _tabs: TabContainer
var _palette: Control
var _last_selection: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 17
	theme = ui_theme
	_toolbar = _panel(self)
	_toolbar.anchor_right = 1.0
	_toolbar.offset_left = 14
	_toolbar.offset_right = -14
	_toolbar.offset_top = 12
	var toolbar := VBoxContainer.new()
	_toolbar.add_child(toolbar)
	var heading := HBoxContainer.new()
	toolbar.add_child(heading)
	_title = _label(heading, "LEVEL DESIGNER", 23)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Color("73ffbc"))
	_button(heading, "Side panel", func() -> void:
		_sidebar_collapsed = not _sidebar_collapsed
		refresh())
	_button(heading, "Help", _help)
	_button(heading, "Close", func() -> void: designer.request_close())
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	toolbar.add_child(actions)
	_move = _button(actions, "Select / move", func() -> void: _tool("move"))
	_build = _button(actions, "Build", show_build_palette)
	_button(actions, "Add objects…", func() -> void: designer.object_browser.open())
	var snap := OptionButton.new()
	snap.name = "PositionSnap"
	for text in ["Snap: tile", "Snap: half tile", "Snap: pixel", "Snap: off"]: snap.add_item(text)
	snap.select(1)
	actions.add_child(snap)
	snap.item_selected.connect(func(index: int) -> void: designer.snap = [1.28, 0.64, 0.04, 0.0][index])
	_undo = _button(actions, "Undo", designer.undo)
	_redo = _button(actions, "Redo", designer.redo)
	_button(actions, "Frame selection", designer.frame_selection)
	_button(actions, "Test ▶", designer.test_layout)
	_save = _button(actions, "Save", designer.save_layout)
	_button(actions, "Revert", designer.revert_layout)
	_button(actions, "Reload saved", designer.reload_saved)
	_sidebar = _panel(self)
	_sidebar.anchor_left = 1.0
	_sidebar.anchor_right = 1.0
	_sidebar.anchor_bottom = 1.0
	_sidebar.offset_left = -354
	_sidebar.offset_right = -14
	_sidebar.offset_top = 144
	_sidebar.offset_bottom = -84
	_toolbar.resized.connect(func() -> void: _sidebar.offset_top = _toolbar.offset_top + _toolbar.size.y + 14)
	_tabs = TabContainer.new()
	_tabs.add_theme_font_size_override("font_size", 16)
	_sidebar.add_child(_tabs)
	_palette = preload("res://scripts/developer/level_object_palette.gd").new()
	_palette.name = "Add"
	_palette.designer = designer
	_tabs.add_child(_palette)
	_properties = _scroll_tab("Settings")
	var body := _scroll_tab("In level")
	_label(body, "PLACED OBJECTS", 19)
	_filter = OptionButton.new()
	for text in ["All supported objects", "Blocks / platforms", "Enemies", "Hazards", "Autosaves", "Decorations", "Supplies"]: _filter.add_item(text)
	body.add_child(_filter)
	_filter.item_selected.connect(func(_index: int) -> void: refresh())
	_show_locked = CheckButton.new()
	_show_locked.text = "Show protected objects"
	body.add_child(_show_locked)
	_show_locked.toggled.connect(func(_pressed: bool) -> void: refresh())
	_list = ItemList.new()
	_list.name = "DesignerObjects"
	_list.custom_minimum_size = Vector2(280, 155)
	_list.select_mode = ItemList.SELECT_MULTI
	body.add_child(_list)
	_list.multi_selected.connect(_list_selected)
	var footer := _panel(self)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.anchor_right = 1.0
	footer.offset_left = 14
	footer.offset_right = -14
	footer.offset_top = -70
	footer.offset_bottom = -12
	_status = _label(footer, "", 16)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_test_bar = _panel(self)
	_test_bar.anchor_left = 0.5
	_test_bar.anchor_right = 0.5
	_test_bar.offset_left = -270
	_test_bar.offset_right = 270
	_test_bar.offset_top = 14
	var test_row := HBoxContainer.new()
	_test_bar.add_child(test_row)
	_label(test_row, "TESTING DRAFT", 19)
	_button(test_row, "Return to editor · Esc", designer.return_to_editing)

func refresh() -> void:
	if _rebuilding or designer.document == null: return
	_rebuilding = true
	var editing: bool = designer.is_editing()
	_toolbar.visible = editing
	_sidebar.visible = editing and not _sidebar_collapsed
	_test_bar.visible = not editing
	_title.text = "LEVEL DESIGNER  ·  " + designer.REGISTRY.TITLES.get(designer.document.section, designer.document.section.capitalize())
	_title.text += "  •  Unsaved" if designer.document.has_changes() else "  •  Saved"
	_undo.disabled = not designer.history.has_undo()
	_redo.disabled = not designer.history.has_redo()
	_save.disabled = not designer.document.has_changes()
	_move.modulate = Color("73ffbc") if designer.tool == "move" else Color.WHITE
	_build.modulate = Color("73ffbc") if designer._placement_record.get("kind", "") == "tile" else Color.WHITE
	_palette.highlight_current()
	_list.clear()
	var filter_kinds: Array = [[], ["platform", "tile"], ["enemy", "gunner"], ["spikes", "flyer"], ["checkpoint"], ["decoration"], ["chest"]][_filter.selected]
	for id in designer.document.working:
		var record: Dictionary = designer.document.working[id]
		if not filter_kinds.is_empty() and record.kind not in filter_kinds: continue
		var index := _list.add_item(record.name + (" · %.2f, %.2f" % [record.values.x, record.values.y] if record.created else ""))
		_list.set_item_metadata(index, {"id": id, "locked": false})
		_list.set_item_tooltip(index, "%s · %s" % [record.name, record.kind])
		if id in designer.selection: _list.select(index, false)
	if _show_locked.button_pressed:
		for id in designer.locked:
			var index := _list.add_item("🔒 " + designer.locked[id].name)
			_list.set_item_metadata(index, {"id": id, "locked": true})
			_list.set_item_tooltip(index, designer.locked[id].reason)
	for child in _properties.get_children():
		_properties.remove_child(child)
		child.queue_free()
	_build_properties()
	if _last_selection != designer.selection:
		_tabs.current_tab = 0 if designer.selection.is_empty() else 1
		_last_selection.assign(designer.selection)
	update_status()
	_rebuilding = false

func _scroll_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body

func _build_properties() -> void:
	if designer.selection.is_empty():
		_paragraph(_properties, "Select an object in the level to edit its settings. The Add tab has assets to place; In level lists objects already here.")
		_paragraph(_properties, "Middle mouse: pan\nMouse wheel: zoom\nF: frame selection\nArrow keys: nudge")
		return
	if designer.selection.size() > 1:
		_label(_properties, "%d objects selected" % designer.selection.size(), 20)
		_paragraph(_properties, "Drag any selected object to move the group. Their spacing stays the same.")
		if designer.can_layer_selected(): _decoration_layer_controls()
		_button(_properties, "Flip horizontally", designer.flip_selected).disabled = not designer.can_flip_selected()
		_button(_properties, "Duplicate selection", designer.duplicate_selected).disabled = not designer.can_duplicate_selected()
		_button(_properties, "Remove selection", designer.remove_selected).disabled = not designer.can_remove_selected()
		return
	var record: Dictionary = designer.document.working[designer.selection[0]]
	var values: Dictionary = record.values
	_label(_properties, record.name, 20)
	var warning: String = designer.placement_warning(designer.selection[0])
	if not warning.is_empty():
		var warning_label := _label(_properties, warning, 16)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.add_theme_color_override("font_color", Color("ffd28a"))
	_numeric("X position", "x", values.x)
	_numeric("Y position", "y", values.y)
	match record.kind:
		"tile":
			_toggle("Flip horizontally", "flip_h", values.flip_h)
			if designer.CATALOG.ENTRIES[record.template].solid:
				_choice("Footstep surface", "surface", ["grass", "sand", "cave", "silent"], ["Grass", "Sand", "Cave", "Silent"], values.surface)
			_paragraph(_properties, "One grid block. Build opens the zone's blocks; each drag is one undo step.")
		"platform":
			_numeric("Width (tiles)", "width", values.width / 1.28, 1.28)
			_numeric("Height (tiles)", "height", values.height / 1.28, 1.28)
			_choice("Block style", "style", ["grass", "sand"], ["Grass", "Sand"], values.style)
			_choice("Footstep surface", "surface", ["grass", "sand", "silent"], ["Grass", "Sand", "Silent"], values.surface)
			_toggle("Left edge cap", "left_cap", values.left_cap)
			_toggle("Right edge cap", "right_cap", values.right_cap)
			_toggle("Bottom edge cap", "bottom_cap", values.bottom_cap)
			_paragraph(_properties, "Square handles resize from an edge. The opposite edge stays in place.")
		"enemy":
			_numeric("Patrol speed (m/s)", "speed", values.speed)
			_toggle("Start moving right", "facing_right", values.facing_right)
			_patrol_side("Left", "left", values.left)
			_patrol_side("Right", "right", values.right)
			_paragraph(_properties, "Drag the round patrol handles to set limits. Walls and ledges still turn the enemy around.")
		"spikes": _numeric("Row width (m)", "width", values.width)
		"gunner":
			_toggle("Start facing right", "facing_right", values.facing_right)
			_paragraph(_properties, "Uses the existing gunner behaviour. Test to check its firing range and nearby cover.")
		"flyer": _paragraph(_properties, "Uses the existing vertical bob and electrical discharge. Place it in the air and test the space around it.")
		"decoration":
			_toggle("Flip horizontally", "flip_h", values.flip_h)
			_decoration_layer_controls()
			_paragraph(_properties, "Scenery only. Does not block the player or projectiles.")
		"chest":
			_toggle("Flip horizontally", "flip_h", values.get("flip_h", false))
			var loot = preload("res://scripts/items/chest_loot.gd")
			var pool_ids: Array = ["level"]
			var pool_labels: Array = ["Automatic · this level"]
			for id in loot.pools:
				pool_ids.append(id)
				pool_labels.append(loot.pools[id].name)
			pool_ids.append("fixed")
			pool_labels.append("Fixed contents")
			_choice("Contents", "loot_pool", pool_ids, pool_labels, values.loot_pool)
			if values.loot_pool == "fixed":
				_numeric("Medicine · +25 HP", "basic_heal", values.basic_heal)
				_numeric("Medicine · +50 HP", "large_heal_test", values.large_heal_test)
				_numeric("Medicine · +75 HP", "medical_bag", values.medical_bag)
				_numeric("Handgun rounds", "handgun_ammo", values.handgun_ammo)
			else:
				var pool_id: String = loot.pool_for_level(designer.app.current_level.level_definition().level_id) if values.loot_pool == "level" else values.loot_pool
				_paragraph(_properties, "%s: one reward, %d%% chance of a second item type. Ammo requires the handgun." % [loot.pools[pool_id].name, roundi(loot.pools[pool_id].bonus_chance * 100)])
			_paragraph(_properties, "Y is ground height. Opens on contact. Contents repeat after loading an earlier save; claimed chests stay open.")
		"checkpoint":
			_numeric("Trigger width (m)", "width", values.width)
			_numeric("Trigger height (m)", "height", values.height)
			_paragraph(_properties, "Y is the ground height. Stand here to set a respawn point; later campaign checkpoints still work." if record.created else "Y is the ground height. Place the checkpoint on a solid surface; its purpose and order stay fixed.")
	if record.removable:
		_button(_properties, "Duplicate · Ctrl+D", designer.duplicate_selected)
		_button(_properties, "Remove · Delete", designer.remove_selected)

func _decoration_layer_controls() -> void:
	var values: Dictionary = designer.document.working[designer.selection[0]].values
	var layer_picker := preload("res://scripts/developer/level_decoration_layer_picker.gd").new(int(values.get("decoration_layer", 0)))
	_properties.add_child(layer_picker)
	layer_picker.layer_changed.connect(designer.set_selected_decoration_layer)
	for id in designer.selection:
		if designer.document.working[id].values.get("decoration_layer", 0) != values.get("decoration_layer", 0):
			_paragraph(_properties, "Mixed layers. Entering a number sets the whole selection to that layer.")
			break
	var actions := HBoxContainer.new()
	_properties.add_child(actions)
	_button(actions, "Layer back", func() -> void: designer.shift_decoration_layer(-1))
	_button(actions, "Layer forward", func() -> void: designer.shift_decoration_layer(1))

func _numeric(label: String, key: String, value: float, factor := 1.0) -> void:
	var row := HBoxContainer.new()
	_properties.add_child(row)
	var caption := _label(row, label, 16)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entry := LineEdit.new()
	entry.name = "Property_" + key
	var initial := String.num(value, 4)
	entry.text = initial
	entry.custom_minimum_size.x = 100
	entry.expand_to_text_length = false
	row.add_child(entry)
	var commit := func() -> void:
		if _rebuilding or not is_instance_valid(entry) or not entry.is_inside_tree() or entry.text == initial: return
		if not entry.text.is_valid_float():
			designer.set_status("Enter a number for " + label.to_lower())
			return
		var changes := {}
		changes[key] = float(entry.text) * factor
		designer.update_values(changes)
	entry.text_submitted.connect(func(_text: String) -> void: commit.call())
	entry.focus_exited.connect(commit)

func _choice(label: String, key: String, values: Array, labels: Array, current: String) -> void:
	_label(_properties, label, 16)
	var picker := OptionButton.new()
	for text in labels: picker.add_item(text)
	picker.name = "Property_" + key
	picker.select(maxi(0, values.find(current)))
	_properties.add_child(picker)
	picker.item_selected.connect(func(index: int) -> void:
		var changes := {}
		changes[key] = values[index]
		designer.update_values(changes))

func _toggle(label: String, key: String, checked: bool) -> void:
	var toggle := CheckButton.new()
	toggle.name = "Property_" + key
	toggle.text = label
	toggle.button_pressed = checked
	_properties.add_child(toggle)
	toggle.toggled.connect(func(value: bool) -> void:
		var changes := {}
		changes[key] = value
		designer.update_values(changes))

func _patrol_side(label: String, key: String, value: float) -> void:
	var picker := OptionButton.new()
	picker.add_item(label + ": automatic edge / wall turn")
	picker.add_item(label + ": fixed patrol limit")
	picker.select(0 if is_zero_approx(value) else 1)
	_properties.add_child(picker)
	picker.item_selected.connect(func(index: int) -> void:
		var changes := {}
		changes[key] = 0.0 if index == 0 else 2.56
		designer.update_values(changes))
	if value > 0.0: _numeric(label + " distance (m)", key, value)

func _list_selected(index: int, selected: bool) -> void:
	if _rebuilding: return
	var metadata: Dictionary = _list.get_item_metadata(index)
	if metadata.locked:
		designer.set_status(designer.locked[metadata.id].reason)
		designer.canvas.locked_hover = metadata.id
		designer.canvas.queue_redraw()
		return
	designer.cancel_placement()
	designer.canvas.cancel_gesture()
	if selected and metadata.id not in designer.selection:
		designer.selection.append(metadata.id)
	elif not selected: designer.selection.erase(metadata.id)
	# Refresh after ItemList finishes dispatching a multiple-selection event.
	# Keep the list open while building a group; Settings is a separate tab.
	_last_selection.assign(designer.selection)
	call_deferred("refresh")
	designer.canvas.queue_redraw()

func _tool(tool: String) -> void:
	if tool == "build":
		show_build_palette()
		return
	designer.cancel_placement()
	designer.canvas.cancel_gesture()
	designer.tool = tool
	refresh()
	designer.canvas.grab_focus()
	designer.set_status("Click to select · Shift-click to group · Drag to move")

func show_build_palette() -> void:
	designer.cancel_placement()
	designer.canvas.cancel_gesture()
	designer.choose("")
	_sidebar_collapsed = false
	_palette.show_blocks()
	refresh()
	_tabs.current_tab = 0
	designer.set_status("Choose a zone and block · Click or drag to build · Right-click / Esc to finish")

func update_status() -> void:
	if _status != null: _status.text = designer.status

func inspector_collapsed() -> bool:
	return _sidebar_collapsed

func focus_selected_settings() -> void:
	_sidebar_collapsed = false
	refresh()
	_tabs.current_tab = 1
	var position_entry := _properties.find_child("Property_x", true, false) as LineEdit
	if position_entry != null:
		position_entry.grab_focus()
		position_entry.select_all()

func _help() -> void:
	designer.app.show_developer_message("Level designer controls", "Build: choose a zone and block in the side panel, then click or drag.\nThe block brush stays active. Right-click or Esc finishes; each stroke is one Undo.\nAdd objects: props, enemies, hazards, and checkpoints.\nFull browser: double-click a card, or use the button beneath its details.\nObjects place once; Shift-click keeps placing them.\nSettings edits your selection; In level lists placed objects.\nSelect / move: click an object, then drag it. Shift-click selects a group.\nRight-click opens object actions; during a drag it cancels the drag.\nSquare handles resize existing platforms; round handles set enemy patrol limits.\nMiddle mouse pans; the wheel zooms; F frames the selection.\nArrows nudge. Ctrl+Z / Ctrl+Y undo / redo. Ctrl+S saves.\nTest starts a fresh attempt; Esc returns with your edits and history.\nSave keeps the layout for future launches. Revert returns to your last save.\nProtected objects, scripts, camera regions and caves stay with Codex.")

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.09, 0.97)
	style.border_color = Color("335367")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _paragraph(parent: Node, text: String) -> void:
	var label := _label(parent, text, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("a6bdc9"))

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	parent.add_child(button)
	button.pressed.connect(action)
	return button
