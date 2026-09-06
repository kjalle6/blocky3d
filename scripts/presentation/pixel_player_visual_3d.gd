class_name PixelPlayerVisual3D
extends Node3D
signal footstep_contact(contact: Dictionary)
## Presentation-only state machine. Gameplay decides the state; this component
## owns strip selection and frame timing for the body and equipped weapon.

const BODY_TEXTURES := {
	"backpedal": preload("res://assets/art/green_zone/characters/player_run.png"),
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
const FOOTSTEP_TRACKS := {
	"run": preload("res://resources/audio/markers/player_run.tres"),
	"run_attack": preload("res://resources/audio/markers/player_run.tres"),
	"backpedal": preload("res://resources/audio/markers/player_backpedal.tres"),
}
const WEAPON_TEXTURES := {
	"idle": preload("res://assets/art/green_zone/characters/weapon_idle.png"),
	"run": preload("res://assets/art/green_zone/characters/weapon_run.png"),
	"attack": preload("res://assets/art/green_zone/characters/weapon_attack.png"),
	"run_attack": preload("res://assets/art/green_zone/characters/weapon_run_attack.png"),
}
const HANDGUN_BODY_TEXTURES := {
	"backpedal": preload("res://assets/art/green_zone/characters/player_handgun_walk_one_hand.png"),
	"idle": preload(
		"res://assets/art/green_zone/characters/player_handgun_idle_one_hand.png"
	),
	"run": preload(
		"res://assets/art/green_zone/characters/player_handgun_run_one_hand.png"
	),
	"jump": preload(
		"res://assets/art/green_zone/characters/player_handgun_jump_one_hand.png"
	),
}
const HANDGUN_GRIP_TEXTURES := {
	"horizontal": preload(
		"res://assets/art/green_zone/weapons/player_handgun_grip_horizontal.png"
	),
	"diagonal": preload(
		"res://assets/art/green_zone/weapons/player_handgun_grip_diagonal.png"
	),
}
const HANDGUN_HORIZONTAL_TEXTURE := preload(
	"res://assets/art/green_zone/weapons/player_handgun_horizontal.png"
)
const HANDGUN_DIAGONAL_TEXTURE := preload(
	"res://assets/art/green_zone/weapons/player_handgun_diagonal.png"
)
const HANDGUN_HORIZONTAL_SHOT_TEXTURE := preload(
	"res://assets/art/green_zone/effects/player_handgun_shot_horizontal.png"
)
const HANDGUN_DIAGONAL_SHOT_TEXTURE := preload(
	"res://assets/art/green_zone/effects/player_handgun_shot_diagonal.png"
)
const FRAME_COUNTS := {
	"backpedal": 6,
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
	"backpedal": 1.5, # Frames per world unit travelled, rather than per second.
	"idle": 8.0,
	"run": 10.0,
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
const KNIFE_WEAPON_ID: StringName = &"knife"
const HANDGUN_WEAPON_ID: StringName = &"handgun"
const HANDGUN_SHOT_FRAME_COUNT := 3
## Show only the first four pixels of each source muzzle-streak frame.
## Keep native pixel scale and leave the travelling bullet visually separate.
const HANDGUN_SHOT_FRAME_RATE := 40.0
## Gun images are tightly cropped, unlike the centred body and 32-pixel grip
## canvases. These offsets place the grip and support hand on the weapon
## instead of centring the gun through the character's chest.
const HANDGUN_HORIZONTAL_GUN_OFFSET := Vector2(13.5, 3.0)
const HANDGUN_UP_GUN_OFFSET := Vector2(10.0, 10.0)
## Register the complete grip at the shoulder of each 48x48 body frame.
## Sprite offsets use Y-up; the source sheet uses Y-down. Move the gun and
## flash with the grip so their existing hand/muzzle registration is retained.
const HANDGUN_GRIP_OFFSETS := {
	"backpedal": [Vector2(-5, -2), Vector2(-5, -1), Vector2(-5, -1), Vector2(-5, -2), Vector2(-5, -1), Vector2(-5, -1)],
	"idle": [Vector2(-5, -2), Vector2(-6, -2), Vector2(-6, -2), Vector2(-5, -2)],
	"run": [Vector2(1, -3), Vector2(2, -3), Vector2(2, -3), Vector2(2, -2), Vector2(2, -3), Vector2(1, -3)],
	"jump": [Vector2(2, 0), Vector2(0, 3), Vector2(-3, -1), Vector2(-3, -3)],
}

var _state := ""
var _elapsed := 0.0
var _run_elapsed := 0.0
var _walk_elapsed := 0.0
var _contact_serial := 0
var _flash_tween: Tween
var _equipped_weapon_id: StringName = KNIFE_WEAPON_ID
var _active_attack_weapon_id: StringName = &""
var _mouse_aim_active := false
var _mouse_aim_angle := 0.0
var _handgun_aim_up := false
var _handgun_shot_active := false
var _handgun_shot_elapsed := 0.0
var _facing_right := true

@onready var body: Sprite3D = %Body
@onready var weapon: Sprite3D = %Weapon
## The firing arm is the far arm: the torso hides its rotating shoulder cap.
@onready var gun: Sprite3D = _firearm_sprite("Gun", -0.02, 8)
@onready var gun_grip: Sprite3D = _firearm_sprite("GunGrip", -0.01, 9)
@onready var shot_effect: Sprite3D = _firearm_sprite("ShotEffect", 0.03, 13)


func _firearm_sprite(node_name: String, depth: float, priority: int) -> Sprite3D:
	var sprite := get_node_or_null(NodePath(node_name)) as Sprite3D
	if sprite == null:
		# Older knife-only cutscene puppets share this presentation script.
		# Supply dormant firearm layers so those authored scenes remain valid.
		sprite = Sprite3D.new()
		sprite.name = node_name
		sprite.visible = false
		sprite.pixel_size = body.pixel_size
		sprite.position.z = depth
		sprite.render_priority = priority
		add_child(sprite)
	return sprite


func _ready() -> void:
	for sprite in [body, weapon, gun, gun_grip, shot_effect]:
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shot_effect.hframes = 1
	shot_effect.region_enabled = true
	shot_effect.region_rect = Rect2(0, 20, 4, 8)
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
	dash_airborne := false,
	backpedalling := false
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
	elif attacking and _active_attack_weapon_id != HANDGUN_WEAPON_ID:
		desired_state = "run_attack" if grounded and absf(horizontal_speed) > 0.5 else "attack"
	elif double_jumping:
		desired_state = "double_jump"
	elif wall_sliding:
		desired_state = "wall_slide"
	elif not grounded:
		desired_state = "jump"
	elif absf(horizontal_speed) > 0.15:
		desired_state = "backpedal" if backpedalling else "run"
	set_state(desired_state, false)
	var previous_cursor := _footstep_cursor()
	if _state in ["run", "run_attack"]:
		_run_elapsed += delta
	elif _state == "backpedal":
		_walk_elapsed += delta * absf(horizontal_speed)
	_elapsed += delta * absf(horizontal_speed) if _state == "backpedal" else delta
	_apply_frame(vertical_speed)
	_apply_facing(facing_right)
	if grounded and absf(horizontal_speed) > 0.15 and FOOTSTEP_TRACKS.has(_state):
		var rate: float = FRAME_RATES["run"] if _state != "backpedal" else absf(horizontal_speed) * FRAME_RATES["backpedal"]
		for contact in FOOTSTEP_TRACKS[_state].contacts_between(previous_cursor, _footstep_cursor()):
			_contact_serial += 1
			contact["id"] = _contact_serial
			contact["state"] = _state
			contact["age_seconds"] = contact.age_frames / rate
			footstep_contact.emit(contact)
	_advance_handgun_shot(delta)


func _footstep_cursor() -> float:
	return _walk_elapsed * FRAME_RATES["backpedal"] if _state == "backpedal" else _run_elapsed * FRAME_RATES["run"]


func set_state(next_state: String, force: bool) -> void:
	if not force and next_state == _state:
		return
	# Pause the stride through grounded stops and knife swings. Rapid tapping
	# resumes the same cycle instead of repeatedly planting the first foot.
	if force or next_state not in ["idle", "run", "run_attack", "backpedal"]:
		_run_elapsed = 0.0
		_walk_elapsed = 0.0
	_state = next_state
	_elapsed = 0.0
	_refresh_weapon_layers(0)


## Gameplay owns the loadout and attack snapshot. Presentation consumes only
## stable ids so acquiring/switching weapons never leaks HUD or session policy
## into the sprite state machine.
func set_weapon_presentation(
	equipped_weapon_id: StringName,
	active_attack_weapon_id: StringName,
	aim_up: bool
) -> void:
	assert(
		equipped_weapon_id in [KNIFE_WEAPON_ID, HANDGUN_WEAPON_ID],
		"Unknown equipped weapon presentation '%s'." % equipped_weapon_id
	)
	assert(
		active_attack_weapon_id.is_empty()
		or active_attack_weapon_id in [KNIFE_WEAPON_ID, HANDGUN_WEAPON_ID],
		"Unknown active weapon presentation '%s'." % active_attack_weapon_id
	)
	_equipped_weapon_id = equipped_weapon_id
	_active_attack_weapon_id = active_attack_weapon_id
	_handgun_aim_up = aim_up and not _mouse_aim_active
	_refresh_weapon_layers(body.frame)
	_apply_facing(_facing_right)


## Connected directly to PlayerHandgun3D so the authored streak begins on the
## frame a projectile actually launches, not at the earlier input wind-up.
func _on_player_handgun_shot_fired(_projectile: HandgunProjectile3D) -> void:
	_handgun_shot_active = true
	_handgun_shot_elapsed = 0.0
	shot_effect.frame = 0
	shot_effect.region_rect = Rect2(0, 20, 4, 8)
	_refresh_weapon_layers(body.frame)
	_apply_facing(_facing_right)


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
	if _state in ["run", "run_attack"]:
		_run_elapsed += delta
	_apply_frame(vertical_speed)
	_apply_facing(facing_right)
	_advance_handgun_shot(delta)


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var damage_colour := Color(1.5, 0.48, 0.48, 1.0)
	for sprite in [body, weapon, gun, gun_grip]:
		sprite.modulate = damage_colour
	_flash_tween = create_tween().set_parallel(true)
	for sprite in [body, weapon, gun, gun_grip]:
		_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func reset_feedback() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	for sprite in [body, weapon, gun, gun_grip]:
		sprite.modulate = Color.WHITE


func _apply_frame(vertical_speed: float) -> void:
	var count: int = FRAME_COUNTS[_state]
	var frame := 0
	if _state in ["run", "run_attack"]:
		frame = floori(_run_elapsed * FRAME_RATES["run"]) % count
	elif _state == "backpedal":
		frame = count - 1 - (floori(_walk_elapsed * FRAME_RATES[_state]) % count)
	elif _state == "jump":
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
		if _state == "run_attack":
			weapon.frame = mini(weapon.hframes - 1, floori(_elapsed * FRAME_RATES["run_attack"]))


func _refresh_weapon_layers(preserved_frame: int) -> void:
	var displayed_weapon := (
		_active_attack_weapon_id
		if not _active_attack_weapon_id.is_empty()
		else _equipped_weapon_id
	)
	var handgun_supported := (
		displayed_weapon == HANDGUN_WEAPON_ID
		and HANDGUN_BODY_TEXTURES.has(_state)
	)
	if handgun_supported:
		body.texture = HANDGUN_BODY_TEXTURES[_state]
		body.hframes = FRAME_COUNTS[_state]
		body.frame = mini(preserved_frame, body.hframes - 1)
		weapon.visible = false
		var hand_pose := "diagonal" if _handgun_aim_up else "horizontal"
		gun_grip.texture = HANDGUN_GRIP_TEXTURES[hand_pose]
		gun.visible = true
		gun_grip.visible = true
		gun.texture = (
			HANDGUN_DIAGONAL_TEXTURE
			if _handgun_aim_up
			else HANDGUN_HORIZONTAL_TEXTURE
		)
		# The grip folder already provides a distinct upward pose. Only the
		# diagonal gun/effect sources point downward and need a vertical flip.
		gun_grip.flip_v = false
		gun.flip_v = _handgun_aim_up
		shot_effect.texture = HANDGUN_HORIZONTAL_SHOT_TEXTURE
		shot_effect.flip_v = false
		shot_effect.visible = _handgun_shot_active
		return

	body.texture = BODY_TEXTURES[_state]
	body.hframes = FRAME_COUNTS[_state]
	body.frame = mini(preserved_frame, body.hframes - 1)
	gun.visible = false
	gun_grip.visible = false
	shot_effect.visible = false
	# The reaction sheet returns to the ordinary stance under its overhead mark.
	# Keep the knife registered on its first idle frame instead of making it
	# vanish for the half-second cutscene beat.
	var weapon_state := "idle" if _state == "notice" else _state
	if not WEAPON_TEXTURES.has(weapon_state):
		weapon_state = ""
	weapon.visible = (
		displayed_weapon == KNIFE_WEAPON_ID
		and not weapon_state.is_empty()
	)
	if weapon.visible:
		weapon.texture = WEAPON_TEXTURES[weapon_state]
		weapon.hframes = FRAME_COUNTS[weapon_state]
		weapon.frame = (
			0
			if _state == "notice"
			else mini(preserved_frame, weapon.hframes - 1)
		)


func _apply_facing(facing_right: bool) -> void:
	_facing_right = facing_right
	# The torso is centered near source x=13 on the 48px canvas.
	# Translate the complete rig so the body, not the extended weapon, sits
	# over the centered gameplay collision shape.
	position.x = (11.0 if facing_right else -11.0) * body.pixel_size
	var flip_horizontal := not facing_right
	body.flip_h = flip_horizontal
	weapon.flip_h = flip_horizontal
	gun.flip_h = flip_horizontal
	gun_grip.flip_h = flip_horizontal
	shot_effect.flip_h = flip_horizontal
	var grip_offset := handgun_grip_offset()
	gun_grip.offset = grip_offset
	var gun_offset := (
		HANDGUN_UP_GUN_OFFSET
		if _handgun_aim_up
		else HANDGUN_HORIZONTAL_GUN_OFFSET
	)
	gun.offset = Vector2(
		gun_offset.x if facing_right else -gun_offset.x,
		gun_offset.y
	) + grip_offset
	var angle := _mouse_aim_angle if _mouse_aim_active else 0.0
	var shoulder := handgun_shoulder_pixels() * gun.pixel_size
	var translation := shoulder - shoulder.rotated(angle)
	for sprite in [gun, gun_grip]:
		sprite.rotation.z = angle
		sprite.position.x = translation.x
		sprite.position.y = translation.y
	var muzzle := handgun_muzzle_pixels() * gun.pixel_size
	var flash_angle := angle
	if not _mouse_aim_active and _handgun_aim_up:
		flash_angle = PI / 4.0 if facing_right else -PI / 4.0
	var flash_direction := Vector2(1 if facing_right else -1, 0).rotated(flash_angle)
	shot_effect.offset = Vector2.ZERO
	shot_effect.rotation.z = flash_angle
	shot_effect.position.x = muzzle.x + flash_direction.x * 2.0 * gun.pixel_size
	shot_effect.position.y = muzzle.y + flash_direction.y * 2.0 * gun.pixel_size


func set_mouse_aim(active: bool, angle: float) -> void:
	_mouse_aim_active = active
	_mouse_aim_angle = angle


func handgun_shoulder_pixels() -> Vector2:
	return Vector2(-2.0 if _facing_right else 2.0, 1.0) + handgun_grip_offset()


func handgun_muzzle_pixels() -> Vector2:
	var base := Vector2(14, 14) if _handgun_aim_up else Vector2(19, 5)
	if not _facing_right:
		base.x = -base.x
	base += handgun_grip_offset()
	if _mouse_aim_active:
		var shoulder := handgun_shoulder_pixels()
		base = shoulder + (base - shoulder).rotated(_mouse_aim_angle)
	return base


func handgun_muzzle_world() -> Vector3:
	var muzzle := handgun_muzzle_pixels() * gun.pixel_size
	var world := to_global(Vector3(muzzle.x, muzzle.y, 0))
	world.z = 0.0
	return world



func handgun_grip_offset() -> Vector2:
	if not HANDGUN_GRIP_OFFSETS.has(_state):
		return Vector2.ZERO
	var offsets: Array = HANDGUN_GRIP_OFFSETS[_state]
	var offset: Vector2 = offsets[mini(body.frame, offsets.size() - 1)]
	return Vector2(offset.x if _facing_right else -offset.x, offset.y)


func handgun_muzzle_registration() -> Vector3:
	var offset := handgun_grip_offset() * gun.pixel_size
	return Vector3(offset.x, offset.y, 0.0)


func _advance_handgun_shot(delta: float) -> void:
	if not _handgun_shot_active:
		shot_effect.visible = false
		return
	_handgun_shot_elapsed += delta
	var frame := floori(_handgun_shot_elapsed * HANDGUN_SHOT_FRAME_RATE)
	if frame >= HANDGUN_SHOT_FRAME_COUNT:
		_handgun_shot_active = false
		shot_effect.visible = false
		return
	shot_effect.region_rect = Rect2(frame * 96, 20, 4, 8)
	shot_effect.visible = gun.visible
