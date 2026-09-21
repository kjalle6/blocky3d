extends PanelContainer
## One compact, scrollable grid. Assignments reference stacks without consuming.
signal close_requested
const STYLE := preload("res://scripts/ui/cyberpunk_ui_style.gd")
const SCROLL_HANDLE := preload("res://assets/art/ui/inventory/scroll_handle.png")
const CELL := 64
const GAP := 2
const COLUMNS := 5
const VISIBLE_ROWS := 6
var _inventory: PlayerInventory
var _selected: StringName = &""
var _grid: GridContainer
var _scroll: ScrollContainer
var _scroll_handle: VSlider
var _sort_mode := 0
var _sort_menu: MenuButton
var _item_menu: PopupMenu
var _item_buttons: Dictionary = {}


func _ready() -> void:
	name = "InventoryPanel"
	custom_minimum_size = Vector2(396, 494)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = STYLE.make_theme()
	theme.default_font = STYLE.FONT
	var focus_fill := StyleBoxFlat.new()
	focus_fill.bg_color = Color(1, 1, 1, 0.035)
	theme.set_stylebox("focus", "Button", focus_fill)
	theme.set_stylebox("panel", "TooltipPanel", STYLE.frame(STYLE.WINDOW, 14))
	theme.set_font("font", "TooltipLabel", STYLE.FONT)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -10)
	add_child(column)
	var window := preload("res://scripts/ui/cyberpunk_window_panel.gd").new()
	window.name = "ItemWindow"
	var margins := StyleBoxEmpty.new()
	margins.set_content_margin(SIDE_LEFT, 34)
	margins.set_content_margin(SIDE_RIGHT, 34)
	margins.set_content_margin(SIDE_TOP, 4)
	margins.set_content_margin(SIDE_BOTTOM, 24)
	window.add_theme_stylebox_override("panel", margins)
	column.add_child(window)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	window.add_child(rows)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.custom_minimum_size.y = 38
	rows.add_child(header)
	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(252, 38)
	var title_texture := AtlasTexture.new()
	title_texture.atlas = STYLE.TITLE
	title_texture.region = Rect2(0, 0, 32, 18)
	var title_style := STYLE.frame(title_texture, 4)
	title_style.set_texture_margin(SIDE_LEFT, 8)
	title_style.set_texture_margin(SIDE_RIGHT, 8)
	title_style.set_texture_margin(SIDE_TOP, 3)
	title_style.set_texture_margin(SIDE_BOTTOM, 3)
	title_panel.add_theme_stylebox_override("panel", title_style)
	header.add_child(title_panel)
	var title := _label(title_panel, "INVENTORY", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var chrome := Control.new()
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(chrome)
	var corner_close := _button(chrome, "", func() -> void: close_requested.emit())
	corner_close.name = "CornerClose"
	corner_close.icon = STYLE.CLOSE
	corner_close.expand_icon = true
	corner_close.add_theme_constant_override("icon_max_width", 24)
	corner_close.add_theme_color_override("icon_normal_color", Color("#ff3c24"))
	corner_close.add_theme_color_override("icon_hover_color", Color("#ff8970"))
	corner_close.tooltip_text = "Close inventory · Tab / Esc"
	corner_close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner_close.offset_left = -14
	corner_close.offset_top = 0
	corner_close.offset_right = 24
	corner_close.offset_bottom = 38
	_scroll = ScrollContainer.new()
	_scroll.name = "ItemScroll"
	_scroll.custom_minimum_size = Vector2(COLUMNS * CELL + (COLUMNS - 1) * GAP,
		VISIBLE_ROWS * CELL + (VISIBLE_ROWS - 1) * GAP)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keep Godot's wheel/focus scrolling; the pack handle drives the same range.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	rows.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "Items"
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_scroll.add_child(_grid)
	var rail := Control.new()
	rail.name = "ScrollRail"
	rail.custom_minimum_size.x = 34
	chrome.add_child(rail)
	rail.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rail.offset_left = 8
	rail.offset_right = 42
	rail.offset_top = 40
	rail.offset_bottom = 40 + VISIBLE_ROWS * CELL + (VISIBLE_ROWS - 1) * GAP
	_scroll_handle = VSlider.new()
	_scroll_handle.name = "ScrollHandle"
	_scroll_handle.scale = Vector2(2, 2)
	_scroll_handle.size = Vector2(17, _scroll.custom_minimum_size.y / 2)
	_scroll_handle.step = 1
	_scroll_handle.scrollable = true
	_scroll_handle.tooltip_text = "Scroll items"
	_scroll_handle.mouse_entered.connect(func() -> void: _scroll_handle.self_modulate = Color(1.18, 1.18, 1.18))
	_scroll_handle.mouse_exited.connect(func() -> void: _scroll_handle.self_modulate = Color.WHITE)
	var handle := AtlasTexture.new()
	handle.atlas = SCROLL_HANDLE
	handle.region = Rect2(15, 0, 17, 32)
	for style_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		_scroll_handle.add_theme_icon_override(style_name, handle)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#17223d")
	track.border_color = Color("#647c99")
	track.set_border_width_all(1)
	track.set_content_margin(SIDE_LEFT, 3)
	track.set_content_margin(SIDE_RIGHT, 3)
	_scroll_handle.add_theme_stylebox_override("slider", track)
	_scroll_handle.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	_scroll_handle.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	rail.add_child(_scroll_handle)
	rail.resized.connect(func() -> void: _scroll_handle.size = Vector2(17, rail.size.y / 2))
	_scroll_handle.value_changed.connect(_on_scroll_handle_changed)
	_scroll.get_v_scroll_bar().changed.connect(_sync_scroll_handle)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _sync_scroll_handle())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 48)
	column.add_child(footer)
	var close_button := _button(footer, "CLOSE", func() -> void: close_requested.emit())
	close_button.name = "Close"
	close_button.custom_minimum_size = Vector2(134, 42)
	close_button.tooltip_text = "Close inventory · Tab / Esc"
	STYLE.accent_button(close_button, STYLE.RED)
	close_button.add_theme_font_size_override("font_size", 24)
	_sort_menu = MenuButton.new()
	_sort_menu.name = "Sort"
	_sort_menu.flat = false
	_sort_menu.text = "SORT"
	_sort_menu.custom_minimum_size = Vector2(134, 42)
	_sort_menu.tooltip_text = "Sort by name, quantity or healing strength"
	var popup := _sort_menu.get_popup()
	_style_popup(popup)
	popup.add_radio_check_item("Name", 0)
	popup.add_radio_check_item("Quantity", 1)
	popup.add_radio_check_item("Healing amount", 2)
	popup.id_pressed.connect(_sort_items)
	popup.set_item_checked(_sort_mode, true)
	STYLE.accent_button(_sort_menu, STYLE.GOLD)
	_sort_menu.add_theme_font_size_override("font_size", 24)
	footer.add_child(_sort_menu)
	_item_menu = PopupMenu.new()
	_item_menu.name = "ItemActions"
	_style_popup(_item_menu)
	_item_menu.id_pressed.connect(_item_action)
	add_child(_item_menu)
	title.tooltip_text = "Hover an item and press Q or E to assign it.\nRight click an item for assignment options."


func _style_popup(popup: PopupMenu) -> void:
	popup.add_theme_stylebox_override("panel", STYLE.frame(STYLE.WINDOW, 14))
	popup.add_theme_font_size_override("font_size", 20)
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color("#38485f")
	popup.add_theme_stylebox_override("hover", highlight)


func _sync_scroll_handle() -> void:
	var native_bar := _scroll.get_v_scroll_bar()
	var overflow := maxf(0, native_bar.max_value - native_bar.page)
	_scroll_handle.set_block_signals(true)
	_scroll_handle.max_value = maxf(1, overflow)
	# VSlider's high end is at the top; inventory offset zero is the top row.
	_scroll_handle.value = _scroll_handle.max_value - native_bar.value
	_scroll_handle.editable = overflow > 0
	_scroll_handle.modulate.a = 1.0 if overflow > 0 else 0.45
	_scroll_handle.set_block_signals(false)


func _on_scroll_handle_changed(value: float) -> void:
	_scroll.scroll_vertical = roundi(_scroll_handle.max_value - value)


func _sort_items(mode: int) -> void:
	_sort_mode = mode
	for index in 3:
		_sort_menu.get_popup().set_item_checked(index, index == mode)
	_refresh()


func _item_before(a: String, b: String) -> bool:
	var first := ItemCatalog.definition(StringName(a))
	var second := ItemCatalog.definition(StringName(b))
	if _sort_mode == 1 and _inventory.count(StringName(a)) != _inventory.count(StringName(b)):
		return _inventory.count(StringName(a)) > _inventory.count(StringName(b))
	if _sort_mode == 2 and first.healing != second.healing:
		return first.healing > second.healing
	return first.display_name.naturalnocasecmp_to(second.display_name) < 0


func bind_inventory(inventory: PlayerInventory) -> void:
	unbind()
	_inventory = inventory
	_inventory.changed.connect(_refresh)
	_refresh()
	show()
	if _item_buttons.has(_selected):
		(_item_buttons[_selected] as Button).grab_focus()


func unbind() -> void:
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = null
	if _item_menu != null:
		_item_menu.hide()
	if _sort_menu != null:
		_sort_menu.get_popup().hide()
	hide()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _refresh() -> void:
	if _inventory == null:
		return
	_clear(_grid)
	_item_buttons.clear()
	var ids: Array[String] = []
	for id in _inventory.quantities:
		if _inventory.count(StringName(id)) > 0 and ItemCatalog.definition(StringName(id)) != null:
			ids.append(String(id))
	ids.sort_custom(_item_before)
	if String(_selected) not in ids:
		_selected = StringName(ids[0]) if not ids.is_empty() else &""
	for id in ids:
		var item_id := StringName(id)
		var item := ItemCatalog.definition(item_id)
		var button := Button.new()
		button.name = "Item_" + id
		button.custom_minimum_size = Vector2(CELL, CELL)
		button.icon = item.icon
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 60)
		_style_slot(button)
		if item.quick_usable:
			button.tooltip_text = "%s\nRestores %d HP · Carried %d\nQ / E: assign · Right click: options" % [
				item.display_name, item.healing, _inventory.count(item_id)]
		else:
			button.tooltip_text = "%s\nReserve rounds: %d\nR: reload the equipped handgun" % [item.display_name, _inventory.count(item_id)]
		button.mouse_entered.connect(_hover_item.bind(item_id))
		button.pressed.connect(_select.bind(item_id))
		button.focus_entered.connect(_select.bind(item_id))
		button.gui_input.connect(_item_input.bind(item_id))
		_grid.add_child(button)
		var quantity := Label.new()
		quantity.text = str(_inventory.count(item_id))
		quantity.add_theme_font_size_override("font_size", 15)
		quantity.add_theme_color_override("font_outline_color", Color("#101b2b"))
		quantity.add_theme_constant_override("outline_size", 4)
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(quantity)
		quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		quantity.position -= quantity.get_minimum_size() + Vector2(3, 1)
		var assigned := Label.new()
		for slot in 2:
			if _inventory.quick_slots[slot] == item_id:
				assigned.text += ("Q " if slot == 0 else "E ")
		assigned.position = Vector2(4, 1)
		assigned.add_theme_font_size_override("font_size", 13)
		assigned.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(assigned)
		_item_buttons[item_id] = button
	# A single grid grows without a carrying limit; six rows establish its window.
	for index in maxi(0, COLUMNS * VISIBLE_ROWS - ids.size()):
		var empty := Button.new()
		empty.custom_minimum_size = Vector2(CELL, CELL)
		empty.focus_mode = Control.FOCUS_NONE
		empty.mouse_entered.connect(_hover_empty)
		_style_slot(empty, true)
		_grid.add_child(empty)
	if is_visible_in_tree() and _item_buttons.has(_selected):
		(_item_buttons[_selected] as Button).grab_focus()
	_sync_scroll_handle.call_deferred()


func _style_slot(button: Button, empty := false) -> void:
	var base_tint := Color("#8190ae") if empty else Color.WHITE
	var hover_tint := base_tint * Color(1.18, 1.18, 1.18)
	button.add_theme_stylebox_override("normal", STYLE.frame(STYLE.SLOT, 4, base_tint))
	# Subtle lighting keeps the pack's original pixel border without an extra outline.
	button.add_theme_stylebox_override("hover", STYLE.frame(STYLE.SLOT, 4, hover_tint))
	button.add_theme_stylebox_override("pressed", STYLE.frame(STYLE.SLOT, 4, base_tint))
	button.add_theme_stylebox_override("hover_pressed", STYLE.frame(STYLE.SLOT, 4, hover_tint))


func _hover_item(item_id: StringName) -> void:
	_select(item_id)
	# Keyboard/controller focus follows the pointed-at item without a click.
	if _item_buttons.has(item_id):
		(_item_buttons[item_id] as Button).grab_focus()


func _hover_empty() -> void:
	_selected = &""
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused.get_parent() == _grid:
		focused.release_focus()


func _select(item_id: StringName) -> void:
	_selected = item_id


func _item_input(event: InputEvent, item_id: StringName) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_select(item_id)
		_item_menu.clear()
		_item_menu.add_item("Assign to Q", 0)
		_item_menu.add_item("Assign to E", 1)
		var quick_usable := ItemCatalog.definition(item_id).quick_usable
		_item_menu.set_item_disabled(0, not quick_usable)
		_item_menu.set_item_disabled(1, not quick_usable)
		_item_menu.add_separator()
		_item_menu.add_item("Clear Q", 2)
		_item_menu.add_item("Clear E", 3)
		_item_menu.set_item_disabled(_item_menu.get_item_index(2), _inventory.quick_slots[0].is_empty())
		_item_menu.set_item_disabled(_item_menu.get_item_index(3), _inventory.quick_slots[1].is_empty())
		_item_menu.position = Vector2i(event.global_position)
		_item_menu.popup()
		(_item_buttons[item_id] as Button).accept_event()


func _item_action(action: int) -> void:
	_item_menu.hide()
	if action < 2:
		assign_selected(action)
	else:
		_clear_slot(action - 2)


func assign_selected(slot: int) -> void:
	if _inventory != null and not _selected.is_empty() and _inventory.count(_selected) > 0:
		_inventory.equip(slot, _selected)


func _clear_slot(slot: int) -> void:
	if _inventory != null:
		_inventory.equip(slot, &"")


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)
	return button
