class_name PixelPlayerVisual3D
extends Node3D
## Presentation-only state machine. Gameplay decides the state; this component
## owns strip selection and frame timing for the body and equipped weapon.

const BODY_TEXTURES := {
	"idle": preload("res://assets/art/green_zone/characters/player_idle.png"),
	"run": preload("res://assets/art/green_zone/characters/player_run.png"),
	"jump": preload("res://assets/art/green_zone/characters/player_jump.png"),
	"double_jump": preload("res://assets/art/green_zone/characters/player_double_jump.png"),
	"wall_slide": preload("res://assets/art/green_zone/characters/player_jump.png"),
	"dash": preload("res://assets/art/green_zone/characters/player_dash.png"),
	"air_dash": preload("res://assets/art/green_zone/characters/player_dash.png"),
	"attack": preload("res://assets/art/green_zone/characters/player_attack.png"),
	"run_attack": preload("res://assets/art/green_zone/characters/player_run_attack.png"),
	"notice": preload("res://assets/art/green_zone/characters/player_notice.png"),
	"hurt": preload("res://assets/art/green_zone/characters/player_hurt.png"),
	"death": preload("res://assets/art/green_zone/characters/player_death.png"),
}
const WEAPON_TEXTURES := {
	"idle": preload("res://assets/art/green_zone/characters/weapon_idle.png"),
	"run": preload("res://assets/art/green_zone/characters/weapon_run.png"),
	"attack": preload("res://assets/art/green_zone/characters/weapon_attack.png"),
	"run_attack": preload("res://assets/art/green_zone/characters/weapon_run_attack.png"),
}
const FRAME_COUNTS := {
	"idle": 4,
	"run": 6,
	"jump": 4,
	"double_jump": 6,
	"wall_slide": 4,
	"dash": 6,
	"air_dash": 6,
	"attack": 6,
	"run_attack": 6,
	"notice": 6,
	"hurt": 2,
	"death": 6,
}
const FRAME_RATES := {
	"idle": 8.0,
	"run": 12.0,
	"jump": 8.0,
	"double_jump": 14.0,
	"wall_slide": 0.0,
	"dash": 24.0,
	"air_dash": 24.0,
	"attack": 18.0,
	"run_attack": 18.0,
	"notice": 10.0,
	"hurt": 8.0,
	"death": 13.0,
}
const AIR_DASH_FRAMES := [1, 2, 3, 2, 3, 4]
## One-indexed source intent: normal -> frame 2 -> normal -> frame 6. The
## final pose carries the overhead "oh no" mark and holds until the first shot.
const NOTICE_FRAMES := [0, 1, 0, 5]

var _state := ""
var _elapsed := 0.0
var _flash_tween: Tween

@onready var body: Sprite3D = %Body
@onready var weapon: Sprite3D = %Weapon


func _ready() -> void:
	for sprite in [body, weapon]:
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_state("idle", true)


func tick(
	delta: float,
	grounded: bool,
	horizontal_speed: float,
	vertical_speed: float,
	attacking: bool,
	dead: bool,
	facing_right: bool,
	double_jumping := false,
	wall_sliding := false,
	dashing := false,
	dash_airborne := false
) -> void:
	var desired_state := "idle"
	if dead:
		desired_state = "death"
	elif dashing:
		# The source Dash strip is authored as a grounded move: its first and
		# last frames are upright recovery poses. Keep those frames on the
		# ground, but use only the active burst poses while airborne so the
		# character never appears to stand motionless in mid-air.
		desired_state = "air_dash" if dash_airborne else "dash"
	elif attacking:
		desired_state = "run_attack" if grounded and absf(horizontal_speed) > 0.5 else "attack"
	elif double_jumping:
		desired_state = "double_jump"
	elif wall_sliding:
		desired_state = "wall_slide"
	elif not grounded:
		desired_state = "jump"
	elif absf(horizontal_speed) > 0.15:
		desired_state = "run"
	set_state(desired_state, false)
	_elapsed += delta
	_apply_frame(vertical_speed)
	body.flip_h = not facing_right
	weapon.flip_h = not facing_right


func set_state(next_state: String, force: bool) -> void:
	if not force and next_state == _state:
		return
	_state = next_state
	_elapsed = 0.0
	body.texture = BODY_TEXTURES[_state]
	body.hframes = FRAME_COUNTS[_state]
	body.frame = 0
	# The reaction sheet returns to the ordinary stance under its overhead mark.
	# Keep the knife registered on its first idle frame instead of making it
	# vanish for the half-second cutscene beat.
	var weapon_state := "idle" if _state == "notice" else _state
	if not WEAPON_TEXTURES.has(weapon_state):
		weapon_state = ""
	weapon.visible = not weapon_state.is_empty()
	if weapon.visible:
		weapon.texture = WEAPON_TEXTURES[weapon_state]
		weapon.hframes = FRAME_COUNTS[weapon_state]
		weapon.frame = 0


func current_state() -> String:
	return _state


## Advances one explicitly authored presentation state without asking gameplay
## to manufacture locomotion flags. Short in-engine cutscenes use this to pose
## the same player art while no CharacterBody is reading input or collision.
func tick_authored_state(
	delta: float,
	state: String,
	facing_right: bool,
	vertical_speed := 0.0
) -> void:
	assert(BODY_TEXTURES.has(state), "Unknown authored player state '%s'." % state)
	set_state(state, false)
	_elapsed += delta
	_apply_frame(vertical_speed)
	body.flip_h = not facing_right
	weapon.flip_h = not facing_right


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	body.modulate = Color(1.5, 0.48, 0.48, 1.0)
	weapon.modulate = body.modulate
	_flash_tween = create_tween().set_parallel(true)
	_flash_tween.tween_property(body, "modulate", Color.WHITE, 0.1)
	_flash_tween.tween_property(weapon, "modulate", Color.WHITE, 0.1)


func reset_feedback() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	body.modulate = Color.WHITE
	weapon.modulate = Color.WHITE


func _apply_frame(vertical_speed: float) -> void:
	var count: int = FRAME_COUNTS[_state]
	var frame := 0
	if _state == "jump":
		if vertical_speed > 7.0:
			frame = 0
		elif vertical_speed > 1.0:
			frame = 1
		elif vertical_speed > -5.0:
			frame = 2
		else:
			frame = 3
	elif _state == "wall_slide":
		frame = 2
	elif _state == "air_dash":
		var step := mini(AIR_DASH_FRAMES.size() - 1, floori(
			_elapsed * FRAME_RATES[_state]
		))
		frame = AIR_DASH_FRAMES[step]
	elif _state == "notice":
		var step := mini(NOTICE_FRAMES.size() - 1, floori(
			_elapsed * FRAME_RATES[_state]
		))
		frame = NOTICE_FRAMES[step]
	elif _state in [
		"double_jump",
		"dash",
		"attack",
		"run_attack",
		"hurt",
		"death",
	]:
		frame = mini(count - 1, floori(_elapsed * FRAME_RATES[_state]))
	else:
		frame = floori(_elapsed * FRAME_RATES[_state]) % count
	body.frame = frame
	if weapon.visible:
		weapon.frame = 0 if _state == "notice" else mini(frame, weapon.hframes - 1)
