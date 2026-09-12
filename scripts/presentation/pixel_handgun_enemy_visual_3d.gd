class_name PixelHandgunEnemyVisual3D
extends Sprite3D

signal shot_frame_reached

const TEXTURES := {
	&"idle": preload("res://assets/art/green_zone/enemies/handgun_idle.png"),
	&"panic": preload("res://assets/art/green_zone/enemies/handgun_idle.png"),
	# Each three-frame group contains aim, flash, and recoil for one direction.
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
	&"attack": 2,
	&"death": 6,
}
const FRAME_RATES := {
	&"idle": 6.0,
	&"panic": 10.0,
	&"telegraph": 8.0,
	&"death": 10.0,
}
const AIM_FORWARD := 0
const AIM_DOWN := 3
const AIM_UP := 6
## Use the nearest authored angle, without quantizing projectile trajectories.
const DIAGONAL_AIM_THRESHOLD := PI / 8.0
## Front/rear flash roots measured on each centered 48px source frame.
## Each gun releases its own round at its authored barrel.
const MUZZLE_PIXELS := {
	AIM_FORWARD: [Vector2(30.0, 26.0), Vector2(18.0, 25.0)],
	AIM_DOWN: [Vector2(28.0, 36.0), Vector2(19.0, 35.0)],
	AIM_UP: [Vector2(26.0, 14.0), Vector2(17.0, 14.0)],
}
## Keep the 0.18s beat, but punctuate it with a short flash, recoil, and
## return to aim. The guns stay ready between shots in the same volley.
const SHOT_FRAMES := [1, 2, 0]
const SHOT_FRAME_TIMES := [0.0, 0.04, 0.11]
const SHOT_DURATION := 0.18
const SHOT_FIRE_STEP := 0
## The source enemy has no authored surprise sheet. This short idle-frame
## punctuation matches the player's reaction rhythm without borrowing a hurt
## or death pose: normal -> small jolt -> normal -> overhead panic marks.
const PANIC_FRAMES := [0, 1, 0, 0]
const PANIC_MARK_STEP := 3
const PANIC_HOP_HEIGHT := 0.08
const PANIC_MARK_HORIZONTAL_OFFSET := 0.4

var _state: StringName = &""
var _elapsed := 0.0
var _shot_step := -1
var _aim_frame := AIM_FORWARD
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
	if _state == &"attack":
		_apply_shot_frame()
		if _elapsed >= SHOT_DURATION:
			set_state(&"telegraph", true)
		return
	var count: int = FRAME_COUNTS[_state]
	var next_frame := floori(_elapsed * float(FRAME_RATES[_state]))
	frame = (
		mini(count - 1, next_frame)
		if _state == &"death"
		else next_frame % count
	)
	if _state == &"telegraph":
		frame = _aim_frame
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
	_shot_step = -1
	texture = TEXTURES[_state]
	hframes = SHEET_COLUMNS[_state]
	if _state != &"telegraph" and _state != &"attack":
		_aim_frame = AIM_FORWARD
	frame = _aim_frame if _state == &"telegraph" else 0


func current_state() -> StringName:
	return _state


func set_aim_direction(direction: Vector3, facing_right: bool) -> void:
	# A released shot owns its pose through recoil. Tracking resumes on the
	# next telegraph or shot, so target movement cannot change a flash midway.
	if is_shot_playing():
		return
	_select_aim(direction, facing_right)
	if _state == &"telegraph":
		frame = _aim_frame


func begin_shot(direction: Vector3, facing_right: bool) -> void:
	set_state(&"attack", true)
	_select_aim(direction, facing_right)
	_apply_shot_frame()


func muzzle_world_position(gun_index: int) -> Vector3:
	assert(gun_index >= 0 and gun_index < MUZZLE_PIXELS[_aim_frame].size())
	var source: Vector2 = MUZZLE_PIXELS[_aim_frame][gun_index]
	var facing := -1.0 if flip_h else 1.0
	return to_global(Vector3((source.x - 24.0) * facing, 24.0 - source.y, 0.0) * pixel_size)


func _select_aim(direction: Vector3, facing_right: bool) -> void:
	var elevation := atan2(direction.y, absf(direction.x))
	_aim_frame = AIM_FORWARD
	if elevation > DIAGONAL_AIM_THRESHOLD:
		_aim_frame = AIM_UP
	elif elevation < -DIAGONAL_AIM_THRESHOLD:
		_aim_frame = AIM_DOWN
	flip_h = not facing_right


func is_shot_playing() -> bool:
	return _state == &"attack"


func _apply_shot_frame() -> void:
	# Frame crossings own the shot event, including when a long tick crosses
	# several markers. Revisiting the same frame never fires another round.
	for step in SHOT_FRAMES.size():
		if step <= _shot_step or _elapsed < SHOT_FRAME_TIMES[step]:
			continue
		_shot_step = step
		frame = _aim_frame + SHOT_FRAMES[step]
		if step == SHOT_FIRE_STEP:
			shot_frame_reached.emit()


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
