extends PanelContainer
## Shared Options/dialog frame, centered title and compact grey controls.
signal close_requested
const STYLE := preload("res://scripts/ui/cyberpunk_ui_style.gd")
const BUTTON := preload("res://assets/art/ui/options/button.png")
const FRAME := [
	preload("res://assets/art/ui/options/frame_46.png"),
	preload("res://assets/art/ui/options/frame_47.png"),
	preload("res://assets/art/ui/options/frame_48.png"),
	preload("res://assets/art/ui/options/frame_55.png"),
	preload("res://assets/art/ui/inventory/frame_56.png"),
	preload("res://assets/art/ui/options/frame_57.png"),
	preload("res://assets/art/ui/options/frame_64.png"),
	preload("res://assets/art/ui/options/frame_65.png"),
	preload("res://assets/art/ui/options/frame_66.png"),
]
const HEADER := [
	preload("res://assets/art/ui/options/frame_49.png"),
	preload("res://assets/art/ui/options/frame_50.png"),
	preload("res://assets/art/ui/options/frame_51.png"),
]
var content: VBoxContainer
var title_label: Label
var close_button: Button


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = STYLE.make_theme()
	theme.default_font = STYLE.FONT
	var focus_fill := StyleBoxFlat.new()
	focus_fill.bg_color = Color(1, 1, 1, 0.035)
	theme.set_stylebox("focus", "Button", focus_fill)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var header := Control.new()
	header.name = "Header"
	header.custom_minimum_size.y = 64
	column.add_child(header)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.clip_text = true
	header.add_child(title_label)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Equal insets center the title on the window, independent of the red X.
	title_label.offset_left = 52
	title_label.offset_right = -52
	# The pack font's visible capitals sit high within its line metrics.
	title_label.offset_top = 4
	title_label.offset_bottom = 4
	close_button = Button.new()
	close_button.name = "CornerClose"
	close_button.icon = STYLE.CLOSE
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width", 28)
	close_button.add_theme_color_override("icon_normal_color", Color("#ec301f"))
	close_button.add_theme_color_override("icon_hover_color", Color("#ff5942"))
	for state in ["normal", "hover", "pressed"]:
		close_button.add_theme_stylebox_override(state, STYLE.frame(STYLE.BUTTON, 4,
			Color(1.12, 1.12, 1.12) if state == "hover" else Color.WHITE))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -46
	close_button.offset_right = -6
	close_button.offset_top = 8
	close_button.offset_bottom = 48
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 28)
	inset.add_theme_constant_override("margin_right", 28)
	inset.add_theme_constant_override("margin_top", 16)
	inset.add_theme_constant_override("margin_bottom", 24)
	column.add_child(inset)
	content = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 18)
	inset.add_child(content)


func configure(title: String, width: float, can_close := true) -> void:
	custom_minimum_size.x = width
	content.custom_minimum_size.x = width - 56
	title_label.text = title
	var title_size := 32 if title.length() > 15 else 36
	while title_size > 20 and STYLE.FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > width - 104:
		title_size -= 2
	title_label.add_theme_font_size_override("font_size", title_size)
	close_button.visible = can_close
	close_button.tooltip_text = "Back · Esc"


static func style_button(button: Button, font_size := 28) -> void:
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = BUTTON
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_texture_margin(side, 3)
			box.set_content_margin(side, 12 if side in [SIDE_LEFT, SIDE_RIGHT] else 6)
		match state:
			"hover": box.modulate_color = Color(1.12, 1.12, 1.12)
			"pressed": box.modulate_color = Color(0.86, 0.86, 0.86)
			"disabled": box.modulate_color = Color(0.72, 0.72, 0.72)
		button.add_theme_stylebox_override(state, box)


func _draw() -> void:
	# Assemble original tiles at the inventory's pixel scale.
	draw_set_transform(Vector2.ZERO, 0, Vector2(2, 2))
	draw_texture_rect(FRAME[4], Rect2(Vector2(3, 3), size / 2 - Vector2(6, 6)), true)
	draw_set_transform(Vector2.ZERO)
	var widths := [64.0, size.x - 128.0, 64.0]
	var heights := [64.0, size.y - 128.0, 64.0]
	var origin := Vector2.ZERO
	for row in 3:
		origin.x = 0
		for column in 3:
			if row != 1 or column != 1:
				draw_texture_rect(FRAME[row * 3 + column],
					Rect2(origin, Vector2(widths[column], heights[row])), false)
			origin.x += widths[column]
		origin.y += heights[row]
	origin = Vector2.ZERO
	for column in 3:
		draw_texture_rect(HEADER[column], Rect2(origin, Vector2(widths[column], 64)), false)
		origin.x += widths[column]
