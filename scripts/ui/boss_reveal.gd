extends CanvasLayer
## Freeze-frame boss reveal. It pauses the game on the current frame, drains
## that frame to night blue, slams a stepped magenta band across it, and pops
## the boss on top in full colour at a whole-pixel scale with its name on the
## band. A press after a short hold, or the hold running out, ends it and
## unpauses the game.

signal finished

const FRAME_SHADER := preload("res://scripts/ui/boss_reveal_frame.gdshader")
const OUTLINE_SHADER := preload("res://scripts/ui/boss_reveal_outline.gdshader")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
const SCREEN := Vector2(1920, 1080)
const MAGENTA := Color("#ed489f")
const CYAN := Color("#32def1")
const INK := Color("#f4f5d2")
const SHADOW := Color("#1a0c24")
## The font's pixels are 100 of its 2048 units; 123 draws each as six screen
## pixels, and the band's steps use the same six-pixel grid.
const NAME_SIZE := 123
const GRID := 6
const BOSS_SCALE := 8
## Band: rises to the right; its top edge crosses mid-screen at BAND_TOP.
const BAND_SLOPE := 0.2
const BAND_TOP := 640.0
const BAND_HEIGHT := 210.0
const EDGE_HEIGHT := 12.0
const NAME_CENTRE_X := 820.0
const BOSS_FEET_X := 1430.0

@export_range(0.2, 3.0, 0.05) var minimum_hold := 0.9
@export_range(0.5, 6.0, 0.05) var hold_time := 2.4

var _active := false
var _accepting := false
var _paused_tree := false
var _shake := 0.0
var _stage: Control
var _frame: TextureRect
var _flash: ColorRect
var _band: Node2D
var _boss: TextureRect
var _name: Control
var _title := ""


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _active


## Freezes on the current frame and reveals the boss drawn by visual.
func play(visual: Sprite3D, title: String) -> void:
	_active = true
	_title = title
	_paused_tree = not get_tree().paused
	get_tree().paused = true
	# The paused world still renders: grab the next frame as the backdrop,
	# without the boss, which the reveal draws large on top instead.
	var boss_texture := _boss_frame(visual)
	visual.visible = false
	await RenderingServer.frame_post_draw
	visual.visible = true
	if not _active:
		return
	var image := get_viewport().get_texture().get_image()
	_build(image, boss_texture)
	_animate_in()


## Ends the reveal at once, as a run reset does.
func cancel() -> void:
	if not _active:
		return
	_active = false
	_release_pause()
	queue_free()


func _process(delta: float) -> void:
	if not _active:
		return
	# Something else unpausing (closing the pause menu) must not thaw the freeze.
	if not get_tree().paused:
		get_tree().paused = true
	if _shake > 0.0 and _stage != null:
		_shake = maxf(0.0, _shake - delta)
		var reach := 2 if _shake > 0.0 else 0
		_stage.position = Vector2(randi_range(-reach, reach), randi_range(-reach, reach)) * 4.0


func _input(event: InputEvent) -> void:
	if not _active:
		return
	# The reveal owns input while it is up; nothing reaches the paused game.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if _accepting and event.is_pressed() and not event.is_echo():
			_close()


func _boss_frame(visual: Sprite3D) -> ImageTexture:
	var sheet := visual.texture.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	var cell := Vector2i(int(sheet.get_width() / float(visual.hframes)),
		int(sheet.get_height() / float(visual.vframes)))
	var origin := Vector2i(visual.frame % visual.hframes, floori(float(visual.frame) / visual.hframes)) * cell
	# A clear pixel of padding all round leaves room for the outline.
	var padded := Image.create(cell.x + 2, cell.y + 2, false, Image.FORMAT_RGBA8)
	padded.blit_rect(sheet, Rect2i(origin, cell), Vector2i.ONE)
	if visual.flip_h:
		padded.flip_x()
	return ImageTexture.create_from_image(padded)


func _build(image: Image, boss_texture: ImageTexture) -> void:
	_stage = Control.new()
	_stage.size = SCREEN
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_frame = TextureRect.new()
	_frame.size = SCREEN
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame_material := ShaderMaterial.new()
	frame_material.shader = FRAME_SHADER
	# Tweens need a starting value; an unset uniform has none.
	frame_material.set_shader_parameter("amount", 0.0)
	_frame.material = frame_material
	if image != null and not image.is_empty():
		_frame.texture = ImageTexture.create_from_image(image)
	_stage.add_child(_frame)
	_band = Node2D.new()
	_band.position.x = -SCREEN.x - 200.0
	_stage.add_child(_band)
	_band.add_child(_stepped_band(-EDGE_HEIGHT, 0.0, CYAN))
	_band.add_child(_stepped_band(0.0, BAND_HEIGHT, MAGENTA))
	_boss = TextureRect.new()
	_boss.texture = boss_texture
	_boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss.stretch_mode = TextureRect.STRETCH_SCALE
	_boss.size = Vector2(boss_texture.get_size()) * BOSS_SCALE
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	_boss.material = outline
	# Feet a little into the band, measured from the frame's lowest solid row.
	var used := boss_texture.get_image().get_used_rect()
	var feet := Vector2(BOSS_FEET_X, _band_top(BOSS_FEET_X) + GRID * 3)
	_boss.position = (feet - Vector2(_boss.size.x * 0.5, used.end.y * BOSS_SCALE)).round()
	_boss.modulate.a = 0.0
	_stage.add_child(_boss)
	_name = Control.new()
	_name.size = SCREEN
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.draw.connect(_draw_name)
	_name.modulate.a = 0.0
	_stage.add_child(_name)
	_flash = ColorRect.new()
	_flash.size = SCREEN
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_flash)


func _animate_in() -> void:
	var tween := create_tween()
	tween.tween_property(_frame.material, "shader_parameter/amount", 1.0, 0.12)
	# The band slams in from the left and lands with a flash and a jolt.
	tween.parallel().tween_method(_set_band_x, _band.position.x, 0.0, 0.16) \
		.set_delay(0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land.bind(0.45, 0.12))
	# The boss punches in from the right with a little overshoot.
	var rest := _boss.position
	_boss.position = rest + Vector2(480, 0)
	tween.tween_property(_boss, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_method(_set_boss_position.bind(rest), 1.0, 0.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Then the name slams in from the left.
	tween.tween_property(_name, "modulate:a", 1.0, 0.04)
	tween.parallel().tween_method(_set_name_x, -640.0, 0.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land.bind(0.0, 0.18))
	tween.tween_interval(minimum_hold)
	tween.tween_callback(func() -> void: _accepting = true)
	tween.tween_interval(maxf(0.0, hold_time - minimum_hold))
	tween.tween_callback(_close)


func _close() -> void:
	if not _active or _stage == null:
		return
	_accepting = false
	_active = false
	var tween := create_tween()
	tween.tween_property(_stage, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func() -> void:
		_release_pause()
		finished.emit()
		queue_free())


func _release_pause() -> void:
	if _paused_tree:
		get_tree().paused = false
		_paused_tree = false


func _land(flash: float, shake: float) -> void:
	_shake = maxf(_shake, shake)
	if flash > 0.0:
		_flash.color.a = flash
		create_tween().tween_property(_flash, "color:a", 0.0, 0.22)


func _set_band_x(x: float) -> void:
	_band.position.x = roundf(x / GRID) * GRID


func _set_boss_position(away: float, rest: Vector2) -> void:
	_boss.position = (rest + Vector2(480.0 * away, 0)).round()


func _set_name_x(x: float) -> void:
	_name.position.x = roundf(x / GRID) * GRID


func _band_top(x: float) -> float:
	return BAND_TOP - BAND_SLOPE * (x - SCREEN.x * 0.5)


## A strip below the band's top edge, from top to bottom, with its slanted
## edges stepped on the six-pixel grid.
func _stepped_band(top: float, bottom: float, colour: Color) -> Polygon2D:
	var step := GRID / BAND_SLOPE
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var x := -step * 2.0
	while x <= SCREEN.x + step * 2.0:
		var y := roundf(_band_top(x) / GRID) * GRID
		upper.append(Vector2(x, y + top))
		upper.append(Vector2(x + step, y + top))
		lower.append(Vector2(x, y + bottom))
		lower.append(Vector2(x + step, y + bottom))
		x += step
	lower.reverse()
	upper.append_array(lower)
	var polygon := Polygon2D.new()
	polygon.polygon = upper
	polygon.color = colour
	return polygon


func _draw_name() -> void:
	var width := FONT.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var centre_y := _band_top(NAME_CENTRE_X) + BAND_HEIGHT * 0.5
	# Cap height is 1400 of the font's 2048 units.
	var baseline := roundf((centre_y + NAME_SIZE * 1400.0 / 2048.0 * 0.5) / GRID) * GRID
	var left := roundf((NAME_CENTRE_X - width * 0.5) / GRID) * GRID
	_name.draw_string(FONT, Vector2(left, baseline) + Vector2(GRID, GRID), _title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, SHADOW)
	_name.draw_string(FONT, Vector2(left, baseline), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, INK)
