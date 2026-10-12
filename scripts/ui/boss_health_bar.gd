extends Control
## A boss's name and health along the bottom of the screen, drawn with the
## player's health pill at a larger whole-pixel scale. The pill's rounded ends
## keep their shape and its middle repeats, so the long bar stays crisp. Bind it
## to a boss that emits health_changed(current, maximum); fill() sweeps the bar
## up from empty, as when an encounter first reveals its boss.

const FULL := preload("res://assets/art/ui/health/player_full.png")
const EMPTY := preload("res://assets/art/ui/health/player_empty.png")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
const INK := Color("#f4f5d2")
const OUTLINE := Color("#101b2b")
const FILL_TIME := 0.6
## Whole-pixel scale of the 32x14 pill art.
const SCALE := 3
## Source pixels at each end that hold the pill's rounded cap.
const CAP := 4
const BAR_WIDTH := 900
## The font's pixels are 100 of its 2048 units, so size 41 draws each one as
## two screen pixels and the name stays crisp.
const TITLE_SIZE := 41
const TITLE_OUTLINE := 8
const TITLE_GAP := 8

var boss_title := "BOSS"
var _boss: Node
var _shown := 0.0
var _fill_tween: Tween


func _init() -> void:
	name = "BossHealth"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Docks the bar at the bottom centre of its layer.
func dock_bottom() -> void:
	var height := _title_height() + TITLE_GAP + FULL.get_height() * SCALE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -BAR_WIDTH * 0.5
	offset_right = BAR_WIDTH * 0.5
	offset_top = -24 - height
	offset_bottom = -24


func bind(boss: Node) -> void:
	_boss = boss
	if "display_name" in boss:
		boss_title = boss.display_name
	boss.health_changed.connect(_on_health_changed)
	refresh()


func refresh() -> void:
	_on_health_changed(_boss.health.current, _boss.health.maximum)


func fill() -> void:
	refresh()
	var target := _shown
	_shown = 0.0
	_fill_tween = create_tween()
	_fill_tween.tween_method(_set_shown, 0.0, target, FILL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The fraction of the bar currently drawn full.
func shown_value() -> float:
	return _shown


func _on_health_changed(current: int, maximum: int) -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_set_shown(float(current) / maxf(1.0, float(maximum)))


func _set_shown(value: float) -> void:
	_shown = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _boss == null:
		return
	var defeated: bool = _boss.health.current <= 0
	var title := boss_title + (" - DEFEATED" if defeated else "")
	var title_width := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var title_position := Vector2(roundf((BAR_WIDTH - title_width) * 0.5), FONT.get_ascent(TITLE_SIZE))
	draw_string_outline(FONT, title_position, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, TITLE_OUTLINE, OUTLINE)
	draw_string(FONT, title_position, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, INK)
	var top := _title_height() + TITLE_GAP
	_draw_pill(EMPTY, top, BAR_WIDTH)
	# Whole screen pixels of fill, so the edge never lands between art pixels.
	_draw_pill(FULL, top, floorf(BAR_WIDTH * _shown / SCALE) * SCALE)


## Draws the pill's left cap, repeated middle and right cap, cut off after
## visible_width screen pixels.
func _draw_pill(texture: Texture2D, top: float, visible_width: float) -> void:
	var height := texture.get_height()
	var middle := texture.get_width() - CAP * 2
	var x := 0.0
	var pieces: Array = [[0, CAP, CAP * SCALE]]
	var middle_width := BAR_WIDTH - CAP * SCALE * 2
	var repeats := int(ceil(float(middle_width) / (middle * SCALE)))
	for index in repeats:
		var width := mini(middle * SCALE, middle_width - index * middle * SCALE)
		pieces.append([CAP, float(width) / SCALE, width])
	pieces.append([texture.get_width() - CAP, CAP, CAP * SCALE])
	for piece in pieces:
		if x >= visible_width:
			return
		var drawn := minf(float(piece[2]), visible_width - x)
		var source_width := drawn / SCALE
		draw_texture_rect_region(texture, Rect2(x, top, drawn, height * SCALE),
			Rect2(piece[0], 0, source_width, height))
		x += piece[2]


func _title_height() -> float:
	return FONT.get_height(TITLE_SIZE)
