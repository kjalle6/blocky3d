class_name PixelEnemyVisual3D
extends Sprite3D

const TEXTURES := {
	"idle": preload("res://assets/art/level01/enemies/green_idle.png"),
	"walk": preload("res://assets/art/level01/enemies/green_walk.png"),
	"attack": preload("res://assets/art/level01/enemies/green_attack.png"),
	"death": preload("res://assets/art/level01/enemies/green_death.png"),
}
const FRAME_COUNTS := {"idle": 4, "walk": 6, "attack": 6, "death": 6}
const FRAME_RATES := {"idle": 6.0, "walk": 10.0, "attack": 10.0, "death": 10.0}

var _state := ""
var _elapsed := 0.0
var _flash_tween: Tween


func _ready() -> void:
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_state("walk", true)


func tick(delta: float, next_state: String, facing_right: bool) -> void:
	set_state(next_state, false)
	_elapsed += delta
	var count: int = FRAME_COUNTS[_state]
	var next_frame := floori(_elapsed * FRAME_RATES[_state])
	frame = mini(count - 1, next_frame) if _state == "death" else next_frame % count
	flip_h = not facing_right


func set_state(next_state: String, force: bool) -> void:
	if not force and next_state == _state:
		return
	_state = next_state
	_elapsed = 0.0
	texture = TEXTURES[_state]
	hframes = FRAME_COUNTS[_state]
	frame = 0


func flash_impact() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color(1.5, 0.48, 0.48, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08)


func reset_feedback() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color.WHITE
