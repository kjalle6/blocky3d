class_name PixelHandgunEnemyVisual3D
extends Sprite3D

const TEXTURES := {
	&"idle": preload("res://assets/art/green_zone/enemies/handgun_idle.png"),
	&"panic": preload("res://assets/art/green_zone/enemies/handgun_idle.png"),
	# The first attack frame is the authored guns-raised pose. Holding it makes
	# the enemy's aim readable before begin_forward_shot() continues at frame 1.
	&"telegraph": preload("res://assets/art/green_zone/enemies/handgun_attack.png"),
	&"attack": preload("res://assets/art/green_zone/enemies/handgun_attack.png"),
	&"death": preload("res://assets/art/green_zone/enemies/handgun_death.png"),
}
const SHEET_COLUMNS := {
	&"idle": 4,
	&"panic": 4,
	&"telegraph": 9,
	&"attack": 9,
	&"death": 6,
}
const FRAME_COUNTS := {
	&"idle": 4,
	&"panic": 4,
	&"telegraph": 1,
	&"attack": 9,
	&"death": 6,
}
const FRAME_RATES := {
	&"idle": 6.0,
	&"panic": 10.0,
	&"telegraph": 8.0,
	&"attack": 14.0,
	&"death": 10.0,
}
## The source enemy has no authored surprise sheet. This short idle-frame
## punctuation matches the player's reaction rhythm without borrowing a hurt
## or death pose: normal -> small jolt -> normal -> overhead panic marks.
const PANIC_FRAMES := [0, 1, 0, 0]
const PANIC_MARK_STEP := 3
const PANIC_HOP_HEIGHT := 0.08
const PANIC_MARK_HORIZONTAL_OFFSET := 0.4

var _state: StringName = &""
var _elapsed := 0.0
var _flash_tween: Tween
var _impact_flashing := false
var _rest_position := Vector3.ZERO

@onready var panic_marks: Sprite3D = %PanicMarks


func _ready() -> void:
	_rest_position = position
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panic_marks.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	panic_marks.shaded = false
	panic_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_state(&"idle", true)


func tick(delta: float, next_state: StringName, facing_right: bool) -> void:
	set_state(next_state, false)
	_elapsed += delta
	var count: int = FRAME_COUNTS[_state]
	var next_frame := floori(_elapsed * float(FRAME_RATES[_state]))
	frame = (
		mini(count - 1, next_frame)
		if _state == &"death" or _state == &"attack"
		else next_frame % count
	)
	flip_h = not facing_right
	if not _impact_flashing:
		modulate = Color.WHITE


func tick_panic(delta: float, facing_right: bool) -> void:
	set_state(&"panic", false)
	_elapsed += delta
	var step := mini(
		PANIC_FRAMES.size() - 1,
		floori(_elapsed * float(FRAME_RATES[&"panic"]))
	)
	frame = PANIC_FRAMES[step]
	flip_h = not facing_right
	position = _rest_position + Vector3(
		0.0,
		PANIC_HOP_HEIGHT if step == 1 else 0.0,
		0.0
	)
	panic_marks.position.x = (
		-PANIC_MARK_HORIZONTAL_OFFSET
		if facing_right
		else PANIC_MARK_HORIZONTAL_OFFSET
	)
	panic_marks.flip_h = not facing_right
	panic_marks.visible = step >= PANIC_MARK_STEP
	if not _impact_flashing:
		modulate = Color.WHITE


func set_state(next_state: StringName, force: bool = false) -> void:
	if not force and next_state == _state:
		return
	assert(TEXTURES.has(next_state), "Unknown handgun enemy visual state '%s'." % next_state)
	_clear_panic_pose()
	_state = next_state
	_elapsed = 0.0
	texture = TEXTURES[_state]
	hframes = SHEET_COLUMNS[_state]
	frame = 0


func current_state() -> StringName:
	return _state


func begin_forward_shot() -> void:
	set_state(&"attack", true)
	_elapsed = 1.0 / float(FRAME_RATES[&"attack"])
	frame = 1


func flash_impact() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_impact_flashing = true
	modulate = Color(1.5, 0.48, 0.48, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	_flash_tween.tween_callback(func() -> void: _impact_flashing = false)


func reset_feedback() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_impact_flashing = false
	modulate = Color.WHITE
	_clear_panic_pose()


func _clear_panic_pose() -> void:
	position = _rest_position
	if panic_marks != null:
		panic_marks.visible = false
