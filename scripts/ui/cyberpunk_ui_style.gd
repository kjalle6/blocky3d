extends RefCounted
## Shared presentation from the owned Cyberpunk GUI pack.
const WINDOW := preload("res://assets/art/ui/inventory/window.png")
const SLOT := preload("res://assets/art/ui/inventory/slot.png")
const BUTTON := preload("res://assets/art/ui/inventory/button.png")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
const INK := Color("#f4f5d2")
const RED := preload("res://assets/art/ui/inventory/red_button.png")
const GOLD := preload("res://assets/art/ui/inventory/gold_button.png")
const GREEN := preload("res://assets/art/ui/inventory/green_button.png")
const PRESSED := preload("res://assets/art/ui/inventory/pressed_button.png")
const CLOSE := preload("res://assets/art/ui/inventory/close_icon.png")
const TITLE := preload("res://assets/art/ui/inventory/frame_25.png")
const WINDOW_TILES := [
	preload("res://assets/art/ui/inventory/frame_01.png"),
	preload("res://assets/art/ui/inventory/frame_02.png"),
	preload("res://assets/art/ui/inventory/frame_03.png"),
	preload("res://assets/art/ui/inventory/frame_13.png"),
	preload("res://assets/art/ui/inventory/frame_56.png"),
	preload("res://assets/art/ui/inventory/frame_22.png"),
	preload("res://assets/art/ui/inventory/frame_19.png"),
	preload("res://assets/art/ui/inventory/frame_20.png"),
	preload("res://assets/art/ui/inventory/frame_21.png"),
]


## Keep the pack's large corner/edge pieces instead of shrinking a whole frame.
static func draw_pack_window(control: Control) -> void:
	var extent := control.size
	control.draw_set_transform(Vector2.ZERO, 0, Vector2(2, 2))
	control.draw_texture_rect(WINDOW_TILES[4], Rect2(Vector2(13, 13), extent / 2 - Vector2(26, 26)), true)
	control.draw_set_transform(Vector2.ZERO)
	var widths := [64.0, extent.x - 128.0, 64.0]
	var heights := [64.0, extent.y - 128.0, 64.0]
	var origin := Vector2.ZERO
	for row in 3:
		origin.x = 0
		for column in 3:
			if row != 1 or column != 1:
				control.draw_texture_rect(WINDOW_TILES[row * 3 + column],
					Rect2(origin, Vector2(widths[column], heights[row])), false)
			origin.x += widths[column]
		origin.y += heights[row]


static func accent_button(button: Button, texture: Texture2D) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = PRESSED if state == "pressed" else texture
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_texture_margin(side, 3)
			box.set_content_margin(side, 12 if side in [SIDE_LEFT, SIDE_RIGHT] else 8)
		box.modulate_color = Color("#82909e") if state == "disabled" else Color.WHITE
		if state == "hover":
			box.modulate_color = Color(1.18, 1.18, 1.18)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#473832"))
	button.add_theme_constant_override("outline_size", 2)



static func frame(texture: Texture2D, padding: int = 16, tint := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 7 if texture == SLOT else 14)
		box.set_content_margin(side, padding)
	return box


static func focus() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color("#86e6d0")
	box.set_border_width_all(2)
	return box


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("#a9ffe0"))
	theme.set_color("font_disabled_color", "Button", Color("#7d899a"))
	theme.set_stylebox("panel", "PanelContainer", frame(WINDOW, 26))
	theme.set_stylebox("normal", "Button", frame(BUTTON, 12, Color("#c1c8e0")))
	theme.set_stylebox("hover", "Button", frame(BUTTON, 12, Color("#e0edff")))
	theme.set_stylebox("pressed", "Button", frame(BUTTON, 12, Color("#82b8bd")))
	theme.set_stylebox("disabled", "Button", frame(BUTTON, 12, Color("#727b95")))
	theme.set_stylebox("focus", "Button", focus())
	return theme
