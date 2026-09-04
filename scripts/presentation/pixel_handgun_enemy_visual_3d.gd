class_name PixelHandgunEnemyVisual3D
extends Sprite3D

const TEXTURES := {
	&"idle": preload("res://assets/art/green_zone/enemies/handgun_idle.png"),
	&"telegraph": preload("res://assets/art/green_zone/enemies/handgun_idle.png"),
	&"attack": preload("res://assets/art/green_zone/enemies/handgun_attack.png"),
	&"death": preload("res://assets/art/green_zone/enemies/handgun_death.png"),
}
const FRAME_COUNTS := {&"idle": 4, &"telegraph": 4, &"attack": 9, &"death": 6}
const FRAME_RATES := {&"idle": 6.0, &"telegraph": 8.0, &"attack": 14.0, &"death": 10.0}

var _state: StringName = &""
var _elapsed := 0.0
var _flash_tween: Tween
var _impact_flashing := false


func _ready() -> void:
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func set_state(next_state: StringName, force: bool = false) -> void:
	if not force and next_state == _state:
		return
	assert(TEXTURES.has(next_state), "Unknown handgun enemy visual state '%s'." % next_state)
	_state = next_state
	_elapsed = 0.0
	texture = TEXTURES[_state]
	hframes = FRAME_COUNTS[_state]
	frame = 0


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
