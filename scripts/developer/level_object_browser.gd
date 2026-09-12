extends Control
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const LIBRARY := preload("res://scripts/developer/level_object_library.gd")
const THUMBNAIL := preload("res://scripts/developer/level_object_thumbnail.gd")
var designer: CanvasLayer
var selected_id := "gz_tile_02"
var category := "All objects"
var _zone: OptionButton
var _window: PanelContainer
var _search: LineEdit
var _cards: GridContainer
var _detail: VBoxContainer
var _categories: VBoxContainer
var _hint: Label
var _place_button: Button
var _results: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window = PanelContainer.new()
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.add_theme_stylebox_override("panel", _box(Color("10202c"), Color("53778b")))
	add_child(_window)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	_window.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := _label(heading, "ADD OBJECTS", 25)
	title.add_theme_color_override("font_color", Color("73ffbc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Close · Esc", close)
	_label(body, "Double-click an object to place it, or select one to see its options.", 17)
	var filters := HBoxContainer.new()
	body.add_child(filters)
	_label(filters, "Zone", 17)
	_zone = OptionButton.new()
	_zone.custom_minimum_size.x = 200
	for zone in CATALOG.zones(): _zone.add_item(zone)
	filters.add_child(_zone)
	_zone.item_selected.connect(func(_index: int) -> void: _refresh())
	_search = LineEdit.new()
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.placeholder_text = "Search objects…"
	filters.add_child(_search)
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	body.add_child(columns)
	_categories = VBoxContainer.new()
	_categories.custom_minimum_size.x = 142
	columns.add_child(_categories)
	for name in LIBRARY.CATEGORIES:
		_button(_categories, name, func() -> void:
			category = name
			_refresh())
	var scrolling := ScrollContainer.new()
	scrolling.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scrolling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(scrolling)
	_cards = GridContainer.new()
	_cards.columns = 3
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 8)
	_cards.add_theme_constant_override("v_separation", 8)
	scrolling.add_child(_cards)
	var detail_column := VBoxContainer.new()
	detail_column.custom_minimum_size.x = 260
	detail_column.add_theme_constant_override("separation", 14)
	columns.add_child(detail_column)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_column.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 14)
	detail_scroll.add_child(_detail)
	_place_button = _button(detail_column, "Place in level", _place)
	_place_button.add_theme_color_override("font_color", Color("73ffbc"))
	_hint = _label(detail_column, "", 16)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout)
	visible = false
	_layout()

func open() -> void:
	if designer.mode != designer.Mode.EDITING or designer.dialog_open(): return
	designer.context_menu.hide()
	designer.cancel_placement()
	designer.canvas.cancel_gesture()
	show()
	_layout()
	_refresh()
	_search.grab_focus()

func close() -> void:
	hide()
	designer.canvas.grab_focus()

func _layout() -> void:
	if _window == null: return
	var extent := Vector2(minf(1160, size.x - 40), minf(800, size.y - 40))
	_window.position = (size - extent) * 0.5
	_window.size = extent
	_cards.columns = 3 if extent.x >= 1090 else 2

func _refresh() -> void:
	_results.clear()
	for id in CATALOG.ENTRIES:
		var entry: Dictionary = CATALOG.ENTRIES[id]
		if not LIBRARY.matches(entry, _zone.get_item_text(_zone.selected), category, _search.text): continue
		_results.append(id)
	if selected_id not in _results: selected_id = _results[0] if not _results.is_empty() else ""
	for button in _categories.get_children(): button.modulate = Color("73ffbc") if button.text == category else Color.WHITE
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for id in _results:
		var card := Button.new()
		card.set_meta("catalog_id", id)
		card.custom_minimum_size = Vector2(154, 154)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = LIBRARY.description(id)
		card.add_theme_stylebox_override("normal", _box(Color("173746") if id == selected_id else Color("132935"), Color("73ffbc") if id == selected_id else Color("335367")))
		_cards.add_child(card)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_top = 6
		content.offset_right = -6
		content.offset_bottom = -6
		var thumb := THUMBNAIL.new()
		thumb.catalog_id = id
		thumb.custom_minimum_size.y = 96
		content.add_child(thumb)
		var caption := _label(content, LIBRARY.title(id), 16)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pressed.connect(func() -> void:
			if visible: _select_card(id))
		card.gui_input.connect(func(event: InputEvent) -> void:
			if visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
				card.accept_event()
				_select_card(id)
				_place())
	if _results.is_empty(): _label(_cards, "No matching objects", 17)
	_refresh_detail()

func _select_card(id: String) -> void:
	# Keep the buttons alive between clicks so the second click reaches the
	# same card.
	if selected_id == id: return
	selected_id = id
	for card in _cards.get_children():
		if not card is Button: continue
		var selected: bool = card.get_meta("catalog_id") == selected_id
		card.add_theme_stylebox_override("normal", _box(Color("173746") if selected else Color("132935"), Color("73ffbc") if selected else Color("335367")))
	_refresh_detail()

func _refresh_detail() -> void:
	_place_button.disabled = selected_id.is_empty()
	_hint.text = ""
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if selected_id.is_empty(): return
	var entry: Dictionary = CATALOG.ENTRIES[selected_id]
	var heading := _label(_detail, LIBRARY.title(selected_id), 22)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var thumb := THUMBNAIL.new()
	thumb.catalog_id = selected_id
	thumb.custom_minimum_size.y = 140
	_detail.add_child(thumb)
	var description := _label(_detail, LIBRARY.description(selected_id), 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_button.text = "Build with this block" if entry.kind == "tile" else "Place in level"
	_hint.text = "Click or drag to build.\nOne stroke = one Undo.\nRight-click or Esc to finish." if entry.kind == "tile" else "Click to place once.\nShift-click to keep placing.\nRight-click or Esc to cancel."
	var placement := _label(_detail, "Place or drag across the tile grid." if entry.anchor == "grid" else "Place it in the air." if entry.anchor == "air" else "The preview sits on nearby floors automatically.", 16)
	placement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placement.add_theme_color_override("font_color", Color("b3d6e4"))

func _place() -> void:
	if selected_id.is_empty(): return
	var values := LIBRARY.defaults(selected_id)
	close()
	designer.begin_placement(selected_id, values)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()

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
	button.add_theme_font_size_override("font_size", 17)
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _box(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
