extends PanelContainer
## A receipt for successfully granted items, never a second collection interface.
const STYLE := preload("res://scripts/ui/cyberpunk_ui_style.gd")
var _session: LevelSession3D
var _items: Dictionary = {}
var _rows: VBoxContainer
var _remaining := 0.0


func _ready() -> void:
	name = "LootReceipt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = STYLE.make_theme()
	add_theme_stylebox_override("panel", STYLE.frame(STYLE.WINDOW, 18))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -420
	offset_right = -24
	offset_top = -156
	offset_bottom = -24
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	clear()


func bind_session(session: LevelSession3D) -> void:
	if is_instance_valid(_session):
		if _session.item_received.is_connected(_on_item_received):
			_session.item_received.disconnect(_on_item_received)
		if _session.run_reset.is_connected(clear):
			_session.run_reset.disconnect(clear)
	_session = session
	if _session != null:
		_session.item_received.connect(_on_item_received)
		_session.run_reset.connect(clear)
	clear()


func _on_item_received(item_id: StringName, amount: int) -> void:
	if ItemCatalog.definition(item_id) == null or amount <= 0:
		return
	_items[item_id] = int(_items.get(item_id, 0)) + amount
	_remaining = 4.0
	modulate.a = 1.0
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = "RECEIVED"
	heading.add_theme_font_override("font", STYLE.FONT)
	heading.add_theme_font_size_override("font_size", 17)
	_rows.add_child(heading)
	for id in _items:
		var item := ItemCatalog.definition(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(row)
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s  ×%d" % [item.display_name, int(_items[id])]
		label.add_theme_font_size_override("font_size", 21)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x = 270
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
	# Anchor the growing receipt above the bottom margin.
	reset_size()
	show()


func _process(delta: float) -> void:
	if _remaining <= 0:
		return
	_remaining = maxf(0.0, _remaining - delta)
	modulate.a = minf(1.0, _remaining / 0.4)
	if _remaining <= 0:
		clear()


func clear() -> void:
	_items.clear()
	_remaining = 0.0
	hide()
