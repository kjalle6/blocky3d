class_name PixelEnemyVisual3D
extends Sprite3D

const TEXTURES := {
	"idle": preload("res://assets/art/green_zone/enemies/green_idle.png"),
	"walk": preload("res://assets/art/green_zone/enemies/green_walk.png"),
	"attack": preload("res://assets/art/green_zone/enemies/green_attack.png"),
	"death": preload("res://assets/art/green_zone/enemies/green_death.png"),
}
const FRAME_COUNTS := {"idle": 4, "walk": 6, "attack": 6, "death": 6}
const FRAME_RATES := {"idle": 6.0, "walk": 10.0, "attack": 10.0, "death": 10.0}

## Optional square-frame sprite sheets for another patrol character.
@export var animation_textures: Dictionary[String, Texture2D] = {}
@export var attack_frame_rate := 10.0
@export var body_center_offset_pixels := 0.0

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
	var count: int = hframes
	var rate: float = attack_frame_rate if _state == "attack" else FRAME_RATES[_state]
	var next_frame := floori(_elapsed * rate)
	frame = mini(count - 1, next_frame) if _state in ["death", "attack"] else next_frame % count
	flip_h = not facing_right
	position.x = body_center_offset_pixels * pixel_size * (1.0 if facing_right else -1.0)


func set_state(next_state: String, force: bool) -> void:
	if not force and next_state == _state:
		return
	_state = next_state
	_elapsed = 0.0
	texture = animation_textures.get(_state, TEXTURES[_state])
	hframes = texture.get_width() / texture.get_height() if animation_textures.has(_state) else FRAME_COUNTS[_state]
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
