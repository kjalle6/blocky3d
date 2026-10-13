extends Button
## Faceted neon menu plate. All input types use the same native Button focus.
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
const PALETTE := [Color("#72eef3"), Color("#e9f5ef"), Color("#fa60a8")]
const COLOR_BEAT := 4.3
var _plate: Control
var _effect_time := 0.0
var _focus_amount := 0.0
var _last_disabled := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", Color("#c9dbe7"))
	add_theme_color_override("font_focus_color", Color("#f3fbf8"))
	add_theme_color_override("font_hover_color", Color("#f3fbf8"))
	add_theme_color_override("font_pressed_color", Color("#72eef3"))
	add_theme_color_override("font_disabled_color", Color("#59697d"))
	add_theme_color_override("font_shadow_color", Color("#060b18"))
	add_theme_constant_override("shadow_offset_y", 2)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# The native label stays above the custom chrome; no duplicate text/input view.
	_plate = Control.new()
	_plate.name = "NeonPlate"
	_plate.show_behind_parent = true
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_plate)
	_plate.draw.connect(_draw_plate)
	focus_entered.connect(_plate.queue_redraw)
	focus_exited.connect(_plate.queue_redraw)
	mouse_entered.connect(func() -> void:
		if not disabled: grab_focus()
		_plate.queue_redraw())
	mouse_exited.connect(_plate.queue_redraw)
	button_down.connect(_plate.queue_redraw)
	button_up.connect(_plate.queue_redraw)
	resized.connect(_plate.queue_redraw)

func update_presentation(seconds: float, delta: float) -> void:
	# Called by the visible menu's one clock, capped at 30 updates per second.
	var target := 1.0 if has_focus() and not disabled else 0.0
	_focus_amount = move_toward(_focus_amount, target, delta * 9.0)
	_effect_time = seconds
	if not disabled or disabled != _last_disabled:
		_plate.queue_redraw()
	_last_disabled = disabled

func outline_color() -> Color:
	var beat := fposmod(_effect_time, COLOR_BEAT * PALETTE.size()) / COLOR_BEAT
	var index := int(floor(beat))
	# Hold each title colour, then ease into the next over the final 0.9 seconds.
	var blend := smoothstep(COLOR_BEAT - 0.9, COLOR_BEAT, fposmod(_effect_time, COLOR_BEAT))
	return PALETTE[index].lerp(PALETTE[(index + 1) % PALETTE.size()], blend)

func _draw_plate() -> void:
	var w := size.x
	var h := size.y
	var active := has_focus() and not disabled
	var amount := _focus_amount if not disabled else 0.0
	var accent := outline_color()
	var edge := Color("#314256") if disabled else Color("#182c43").lerp(accent, 0.48 + amount * 0.52)
	var shell := PackedVector2Array([
		Vector2(20, 2), Vector2(w - 44, 2), Vector2(w - 34, 10),
		Vector2(w - 4, 10), Vector2(w - 4, h - 20), Vector2(w - 22, h - 2),
		Vector2(44, h - 2), Vector2(34, h - 10), Vector2(4, h - 10), Vector2(4, 18)])
	var closed := shell.duplicate()
	closed.append(shell[0])
	var shadow := shell.duplicate()
	for i in shadow.size(): shadow[i] += Vector2(3, 5)
	_plate.draw_colored_polygon(shadow, Color(0.015, 0.025, 0.06, 0.85))
	if amount > 0.0:
		_plate.draw_polyline(closed, Color(accent, 0.06 * amount), 10.0)
		_plate.draw_polyline(closed, Color(accent, 0.14 * amount), 6.0)
	var fill := Color("#101b30").lerp(Color(accent, 1.0), amount * 0.09)
	if disabled: fill = Color("#0b1423")
	if is_pressed() and not disabled: fill = fill.lightened(0.14)
	_plate.draw_colored_polygon(shell, fill)
	_plate.draw_polyline(closed, edge, 2.0)
	# Offset inner facets make the surface read as a cut panel rather than a box.
	_plate.draw_colored_polygon(PackedVector2Array([
		Vector2(23, 7), Vector2(w - 47, 7), Vector2(w - 40, 14),
		Vector2(47, 14), Vector2(39, 21), Vector2(10, 21)]),
		Color("#1a2a42") if disabled else Color(accent, 0.06 + amount * 0.05))
	_plate.draw_polyline(PackedVector2Array([
		Vector2(8, h - 17), Vector2(37, h - 17), Vector2(46, h - 8), Vector2(w - 24, h - 8)]),
		Color("#1d2b41") if disabled else Color(accent, 0.16 + amount * 0.14), 2.0)
	# Two broken conductor rails leave the centre quiet behind the action label.
	_plate.draw_line(Vector2(48, 2), Vector2(133, 2), edge, 3.0)
	_plate.draw_line(Vector2(140, 2), Vector2(151, 2), edge, 3.0)
	_plate.draw_line(Vector2(w - 137, h - 2), Vector2(w - 48, h - 2), edge, 3.0)
	_plate.draw_line(Vector2(w - 155, h - 2), Vector2(w - 145, h - 2), edge, 3.0)
	var mid := h * 0.5
	# Selection is also a shape/value cue, independent of the cycling hue.
	if active:
		_plate.draw_colored_polygon(PackedVector2Array([
			Vector2(24, mid - 9), Vector2(34, mid), Vector2(24, mid + 9),
			Vector2(29, mid)]), PALETTE[1])
		_plate.draw_line(Vector2(2, 22), Vector2(2, h - 22), accent, 4.0)
		_plate.draw_polyline(PackedVector2Array([
			Vector2(w - 15, 19), Vector2(w - 9, 19), Vector2(w - 9, h - 24)]), accent, 3.0)
		var glint := fposmod(_effect_time, 2.6) / 2.6
		_plate.draw_line(Vector2(49 + glint * 61, 2), Vector2(68 + glint * 61, 2), PALETTE[1], 3.0)
	else:
		_plate.draw_rect(Rect2(25, mid - 2, 9, 4), edge)
	# Three fixed neon strokes echo the title palette, independent of the frame hue.
	for i in 3:
		var x := w - 52 + i * 8
		var start := Vector2(x, mid + 7)
		var end := Vector2(x + 5, mid - 4)
		var tube: Color = PALETTE[i]
		if disabled:
			_plate.draw_line(start, end, Color("#101b30").lerp(tube, 0.22), 2.0)
		else:
			_plate.draw_line(start, end, Color(tube, 0.07), 11.0)
			_plate.draw_line(start, end, Color(tube, 0.16), 7.0)
			_plate.draw_line(start, end, Color(tube, 0.85 + amount * 0.15), 3.0)
