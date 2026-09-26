extends VBoxContainer
## Shared layer control for existing scenery and the next placement.
signal layer_changed(value: int)
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
var entry: SpinBox

func _init(current := 0, caption := "Decoration layer") -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	entry = SpinBox.new()
	entry.name = "DecorationLayer"
	entry.min_value = OBJECTS.MIN_DECORATION_LAYER
	entry.max_value = OBJECTS.MAX_DECORATION_LAYER
	entry.step = 1
	entry.value = current
	entry.custom_minimum_size.x = 86
	entry.tooltip_text = "Higher numbers appear in front of lower numbers. Applies to decorations and animated scenery."
	row.add_child(entry)
	entry.value_changed.connect(func(value: float) -> void: layer_changed.emit(int(value)))
	var hint := Label.new()
	hint.text = "Lower = behind · Higher = in front"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("a6bdc9"))
	add_child(hint)

func set_layer(value: int) -> void:
	entry.set_value_no_signal(value)
