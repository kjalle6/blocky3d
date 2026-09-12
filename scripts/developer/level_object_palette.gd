extends VBoxContainer
## Compact access to the same prepared objects as the full browser.
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const LIBRARY := preload("res://scripts/developer/level_object_library.gd")
const THUMBNAIL := preload("res://scripts/developer/level_object_thumbnail.gd")
var designer: CanvasLayer
var _search: LineEdit
var _category: OptionButton
var _zone: OptionButton
var _cards: GridContainer

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = "Choose a zone and block, then click or drag to build."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("a6bdc9"))
	add_child(hint)
	_search = LineEdit.new()
	_search.placeholder_text = "Search assets…"
	add_child(_search)
	_zone = OptionButton.new()
	for zone in CATALOG.zones(): _zone.add_item(zone)
	_zone.select(CATALOG.zones().find("Green Zone"))
	_zone.tooltip_text = "Zone / asset pack. Available in every level."
	add_child(_zone)
	_category = OptionButton.new()
	for category in LIBRARY.CATEGORIES: _category.add_item(category)
	_category.select(LIBRARY.CATEGORIES.find("Blocks"))
	add_child(_category)
	var browse := Button.new()
	browse.text = "Open full browser…"
	browse.custom_minimum_size.y = 34
	add_child(browse)
	browse.pressed.connect(func() -> void:
		var browser: Control = designer.object_browser
		browser._zone.select(_zone.selected)
		browser.category = _category.get_item_text(_category.selected)
		browser._search.text = _search.text
		browser.open())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 6)
	_cards.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_cards)
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	_category.item_selected.connect(func(_index: int) -> void: _refresh())
	_zone.item_selected.connect(func(_index: int) -> void: _refresh())
	_refresh()

func show_blocks() -> void:
	_search.text = ""
	_category.select(LIBRARY.CATEGORIES.find("Blocks"))
	if _zone.get_item_text(_zone.selected) == "Shared": _zone.select(CATALOG.zones().find("Green Zone"))
	_refresh()

func _refresh() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var query := _search.text.strip_edges().to_lower()
	var category := _category.get_item_text(_category.selected)
	for id in CATALOG.ENTRIES:
		var entry: Dictionary = CATALOG.ENTRIES[id]
		if not LIBRARY.matches(entry, _zone.get_item_text(_zone.selected), category, query): continue
		var card := Button.new()
		card.set_meta("catalog_id", id)
		card.custom_minimum_size = Vector2(126, 118)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = LIBRARY.title(id) + "\n" + LIBRARY.description(id)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("132935")
		style.border_color = Color("335367")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("normal", style)
		_cards.add_child(card)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 4
		content.offset_right = -4
		content.offset_top = 4
		content.offset_bottom = -4
		var thumb := THUMBNAIL.new()
		thumb.catalog_id = id
		thumb.custom_minimum_size.y = 68
		content.add_child(thumb)
		var label := Label.new()
		label.text = LIBRARY.title(id)
		label.add_theme_font_size_override("font_size", 14)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		card.pressed.connect(func() -> void:
			designer.begin_placement(id, LIBRARY.defaults(id)))
	if _cards.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No matching objects"
		_cards.add_child(empty)
	highlight_current()

func highlight_current() -> void:
	for card in _cards.get_children():
		if not card is Button: continue
		var active: bool = card.get_meta("catalog_id", "") == designer._placement_record.get("template", "")
		var style := card.get_theme_stylebox("normal") as StyleBoxFlat
		style.border_color = Color("73ffbc") if active else Color("335367")
		style.bg_color = Color("173746") if active else Color("132935")
