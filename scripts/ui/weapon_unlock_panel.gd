extends PanelContainer
## Pack-built weapon display with authored pixel trim and animated neon lighting.
## CampaignMenu continues to own pause, input protection and dismissal.
signal continue_requested

const STYLE := preload("res://scripts/ui/cyberpunk_ui_style.gd")
const MENU_PANEL := preload("res://scripts/ui/cyberpunk_menu_panel.gd")
const HANDGUN := preload("res://assets/art/green_zone/weapons/player_handgun_horizontal.png")
const BLUE_CABLE := preload("res://assets/art/ui/weapon_unlock/cable_blue.png")
const SCREEN_SHADER := preload("res://scripts/ui/weapon_unlock_screen.gdshader")
const GUN_SHADER := preload("res://scripts/ui/weapon_unlock_gun.gdshader")
const LIGHT_GLOW_SHADER := preload("res://scripts/ui/weapon_unlock_light_glow.gdshader")
const INPUT_DELAY := 0.3
const CYAN := Color("#32def1")
const MAGENTA := Color("#ed489f")
const CASE_RECT := Rect2(0, 82, 560, 264)
const SCREEN_RECT := Rect2(28, 110, 504, 210)
const GUN_ORIGIN := Vector2(192, 126)
const GLOW_PADDING := 24.0
# One set of positions drives both the crisp strip and its soft light spill.
const LIGHT_STRIPS := [
	[Rect2(32, 96, 40, 4), MAGENTA, 1.0],
	[Rect2(488, 96, 40, 4), CYAN, 1.0],
	[Rect2(32, 328, 40, 4), MAGENTA, 1.0],
	[Rect2(488, 328, 40, 4), CYAN, 1.0],
	[Rect2(10, 178, 4, 64), MAGENTA, 1.0],
	[Rect2(546, 178, 4, 64), CYAN, 1.0],
	[Rect2(26, 18, 4, 28), MAGENTA, 1.0],
	[Rect2(530, 18, 4, 28), CYAN, 1.0],
	[Rect2(158, 424, 244, 4), CYAN, 0.85],
	[Rect2(0, 188, 6, 4), CYAN, 0.3],
	[Rect2(0, 196, 6, 4), CYAN, 0.3],
	[Rect2(0, 204, 6, 4), CYAN, 0.3],
]

var continue_button: Button
var _elapsed := 0.0
var _screen_material: ShaderMaterial
var _gun_material: ShaderMaterial
var _gun: TextureRect
var _screen_frame: StyleBoxTexture
var _strip_glows: Control


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = STYLE.make_theme()
	theme.default_font = STYLE.FONT
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_screen_frame = STYLE.frame(STYLE.SLOT, 0)
	var layout := Control.new()
	layout.custom_minimum_size = Vector2(560, 438)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	var screen := ColorRect.new()
	screen.position = SCREEN_RECT.position
	screen.size = SCREEN_RECT.size
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = SCREEN_SHADER
	_screen_material.set_shader_parameter("display_size", SCREEN_RECT.size)
	screen.material = _screen_material
	layout.add_child(screen)
	var circuitry := Control.new()
	circuitry.position = SCREEN_RECT.position
	circuitry.size = SCREEN_RECT.size
	circuitry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circuitry.draw.connect(_draw_circuitry.bind(circuitry))
	layout.add_child(circuitry)
	_gun = TextureRect.new()
	_gun.texture = HANDGUN
	_gun.position = GUN_ORIGIN
	_gun.size = Vector2(176, 112)
	_gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gun_material = ShaderMaterial.new()
	_gun_material.shader = GUN_SHADER
	_gun.material = _gun_material
	layout.add_child(_gun)
	var title := _label("WEAPON UNLOCKED", 32, Color.WHITE)
	title.position = Vector2(48, 8)
	title.size = Vector2(464, 56)
	layout.add_child(title)
	var weapon_name := _label("HANDGUN", 36, Color.WHITE)
	weapon_name.name = "WeaponName"
	weapon_name.position = Vector2(28, 266)
	weapon_name.size = Vector2(504, 48)
	weapon_name.add_theme_color_override("font_shadow_color", Color("#206e85"))
	weapon_name.add_theme_constant_override("shadow_offset_y", 2)
	layout.add_child(weapon_name)
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = "CONTINUE"
	MENU_PANEL.style_button(continue_button, 26)
	continue_button.position = Vector2(156, 366)
	continue_button.size = Vector2(248, 56)
	continue_button.add_theme_color_override("font_color", Color("#dcf4f3"))
	continue_button.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var button_style := continue_button.get_theme_stylebox(state).duplicate() as StyleBoxTexture
		button_style.modulate_color = Color(1, 1.18, 1.22) if state == "hover" else Color(0.88, 1.08, 1.16)
		if state == "pressed": button_style.modulate_color = Color(0.72, 0.9, 0.98)
		continue_button.add_theme_stylebox_override(state, button_style)
	var focus_fill := StyleBoxFlat.new()
	focus_fill.bg_color = Color(0.5, 1.0, 1.0, 0.08)
	continue_button.add_theme_stylebox_override("focus", focus_fill)
	continue_button.pressed.connect(func() -> void:
		if is_armed(): continue_requested.emit())
	layout.add_child(continue_button)
	_add_strip_glows(layout)
	hide()


func _add_strip_glows(layout: Control) -> void:
	# A small overlay per strip keeps the bloom local and its fill cost low.
	_strip_glows = Control.new()
	_strip_glows.name = "StripGlow"
	_strip_glows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_strip_glows)
	for strip in LIGHT_STRIPS:
		var rect: Rect2 = strip[0]
		var glow := ColorRect.new()
		glow.position = rect.position - Vector2.ONE * GLOW_PADDING
		glow.size = rect.size + Vector2.ONE * GLOW_PADDING * 2
		glow.color = strip[1]
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow_material := ShaderMaterial.new()
		glow_material.shader = LIGHT_GLOW_SHADER
		glow_material.set_shader_parameter("strip_size", rect.size)
		glow_material.set_shader_parameter("padding", GLOW_PADDING)
		glow_material.set_shader_parameter("strength", strip[2])
		glow.material = glow_material
		_strip_glows.add_child(glow)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func begin_reveal() -> void:
	_elapsed = 0.0
	continue_button.disabled = true
	_update_display()
	show()


func is_armed() -> bool:
	return visible and _elapsed >= INPUT_DELAY


func _process(delta: float) -> void:
	if not visible:
		return
	var was_armed := is_armed()
	_elapsed += delta
	_update_display()
	if not was_armed and is_armed():
		continue_button.disabled = false
		continue_button.grab_focus()


func _update_display() -> void:
	_screen_material.set_shader_parameter("elapsed", _elapsed)
	_gun_material.set_shader_parameter("elapsed", _elapsed)
	_gun.position.y = GUN_ORIGIN.y + roundf(sin(_elapsed * 1.6) * 2)
	_strip_glows.modulate.a = 0.9 + 0.1 * sin(_elapsed * 1.8)
	queue_redraw()


func _draw() -> void:
	# Structure sits behind the three separate pieces: heading, display and key.
	# Short leads curl just outside the inset socket, then return to the case.
	_draw_wire(PackedVector2Array([Vector2(-2, 218), Vector2(-2, 230),
		Vector2(-10, 238), Vector2(-10, 248), Vector2(-4, 254), Vector2(6, 258)]), MAGENTA)
	_draw_wire(PackedVector2Array([Vector2(6, 218), Vector2(6, 232),
		Vector2(0, 238), Vector2(0, 246), Vector2(6, 250)]), MAGENTA)
	draw_texture_rect(BLUE_CABLE, Rect2(Vector2(526, 190), BLUE_CABLE.get_size() * 2), false)
	for x in [68.0, 474.0]:
		_draw_support(Rect2(x, 56, 18, 36))
	for x in [186.0, 356.0]:
		_draw_support(Rect2(x, 338, 18, 30))
	_draw_wire(PackedVector2Array([Vector2(96, 60), Vector2(96, 74), Vector2(102, 80), Vector2(102, 86)]), CYAN)
	_draw_wire(PackedVector2Array([Vector2(108, 60), Vector2(108, 70), Vector2(116, 78), Vector2(116, 86)]), MAGENTA)
	_draw_wire(PackedVector2Array([Vector2(438, 60), Vector2(438, 68), Vector2(428, 78), Vector2(428, 86)]), MAGENTA)
	_draw_wire(PackedVector2Array([Vector2(456, 60), Vector2(456, 72), Vector2(446, 82), Vector2(446, 86)]), CYAN)
	_draw_case(CASE_RECT)
	_draw_left_connector()
	_screen_frame.draw(get_canvas_item(), SCREEN_RECT.grow(2))
	_draw_header()
	_draw_button_mount()

	# Small panel joints and countersunk fasteners interrupt the long plain trim.
	for joint in [Rect2(382, 84, 2, 20), Rect2(158, 326, 2, 18),
			Rect2(2, 148, 20, 2), Rect2(538, 278, 20, 2)]:
		draw_rect(joint, Color("#111a30"))
		draw_rect(Rect2(joint.position + Vector2(2, 2), joint.size), Color("#536580"))
	for point in [Vector2(12, 92), Vector2(540, 92), Vector2(12, 328), Vector2(540, 328)]:
		_draw_fastener(point)

	for strip in LIGHT_STRIPS:
		_draw_light(strip[0], strip[1])


func _draw_left_connector() -> void:
	# Recess the socket so its lights sit at the case edge with only a slim lip.
	draw_rect(Rect2(-10, 176, 18, 50), Color("#0a1021"))
	draw_rect(Rect2(-8, 178, 16, 46), Color("#36416b"))
	draw_rect(Rect2(-8, 178, 14, 2), Color("#819eae"))
	draw_rect(Rect2(-8, 222, 14, 2), Color("#18223b"))
	draw_rect(Rect2(-2, 186, 10, 28), Color("#11192d"))
	draw_rect(Rect2(-6, 182, 2, 2), Color("#aa718c"))
	draw_rect(Rect2(-6, 218, 2, 2), Color("#819eae"))


func _draw_case(rect: Rect2) -> void:
	# Same source tiles and two-pixel scale as the inventory, in a local rect.
	draw_set_transform(rect.position, 0, Vector2(2, 2))
	draw_texture_rect(STYLE.WINDOW_TILES[4], Rect2(Vector2(13, 13), rect.size / 2 - Vector2(26, 26)), true)
	draw_set_transform(rect.position)
	var widths := [64.0, rect.size.x - 128.0, 64.0]
	var heights := [64.0, rect.size.y - 128.0, 64.0]
	var origin := Vector2.ZERO
	for row in 3:
		origin.x = 0
		for column in 3:
			if row != 1 or column != 1:
				draw_texture_rect(STYLE.WINDOW_TILES[row * 3 + column],
					Rect2(origin, Vector2(widths[column], heights[row])), false)
			origin.x += widths[column]
		origin.y += heights[row]
	draw_set_transform(Vector2.ZERO)


func _draw_header() -> void:
	var widths := [64.0, 432.0, 64.0]
	var header_x := 0.0
	for column in 3:
		draw_texture_rect(MENU_PANEL.HEADER[column], Rect2(header_x, 0, widths[column], 64), false)
		header_x += widths[column]
	# End plates leave equal room on both sides of the centered heading.
	for x in [4.0, 536.0]:
		draw_rect(Rect2(x, 6, 20, 52), Color("#283553"))
		draw_rect(Rect2(x, 6, 20, 2), Color("#819eae"))
		draw_rect(Rect2(x, 56, 20, 2), Color("#11162b"))
		_draw_fastener(Vector2(x + 6, 8))
		_draw_fastener(Vector2(x + 6, 48))


func _draw_button_mount() -> void:
	var rect := Rect2(146, 360, 268, 74)
	draw_rect(rect, Color("#0a1021"))
	draw_rect(rect.grow(-2), Color("#2e3c5e"))
	draw_rect(Rect2(150, 362, 260, 2), Color("#8ca9b5"))
	draw_rect(Rect2(150, 430, 260, 2), Color("#19223e"))
	for point in [Vector2(148, 366), Vector2(404, 366), Vector2(148, 416), Vector2(404, 416)]:
		_draw_fastener(point)


func _draw_support(rect: Rect2) -> void:
	draw_rect(rect, Color("#080e1c"))
	draw_rect(rect.grow(-2), Color("#374766"))
	draw_rect(Rect2(rect.position + Vector2(4, 0), Vector2(4, rect.size.y)), Color("#7895a5"))
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 6), Vector2(rect.size.x - 4, 2)), Color("#9bb4c3"))


func _draw_wire(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, Color("#08101d"), 8, false)
	draw_polyline(points, color.darkened(0.35), 4, false)
	draw_polyline(points, color, 2, false)


func _draw_fastener(point: Vector2) -> void:
	draw_rect(Rect2(point, Vector2(8, 8)), Color("#10182c"))
	draw_rect(Rect2(point + Vector2(2, 0), Vector2(4, 2)), Color("#a1b7c8"))
	draw_rect(Rect2(point + Vector2(2, 2), Vector2(4, 4)), Color("#51617d"))
	draw_rect(Rect2(point + Vector2(2, 4), Vector2(4, 2)), Color("#172037"))


func _draw_light(rect: Rect2, color: Color) -> void:
	var pulse := 0.9 + 0.1 * sin(_elapsed * 1.8)
	# Keep the pixel core sharp beneath the separate additive glow overlays.
	draw_rect(rect.grow(2), Color("#10172b"))
	draw_rect(rect, color * Color(pulse, pulse, pulse, 1))
	var highlight := Rect2(rect.position, Vector2(rect.size.x, 2) if rect.size.x > rect.size.y else Vector2(2, rect.size.y))
	draw_rect(highlight, Color(color.lerp(Color.WHITE, 0.5), 0.75))


func _draw_circuitry(control: Control) -> void:
	# Two restrained etched traces, tucked away from the weapon and its name.
	var left := PackedVector2Array([Vector2(8, 34), Vector2(16, 26), Vector2(16, 10)])
	var right := PackedVector2Array([Vector2(478, 196), Vector2(490, 184), Vector2(490, 172)])
	control.draw_polyline(left, Color(MAGENTA, 0.68), 2, false)
	control.draw_polyline(right, Color(CYAN, 0.68), 2, false)
	for point in [Vector2(8, 34), Vector2(16, 10)]:
		control.draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), MAGENTA, false, 2)
	for point in [Vector2(478, 196), Vector2(490, 172)]:
		control.draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), CYAN, false, 2)
