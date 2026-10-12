extends "res://scripts/projectiles/handgun_projectile_3d.gd"
## A tube-by-tube rocket ripple. Boost clear before curving toward the fixed
## salvo area; never chase the player or loop back after passing the target.
const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const EXPLOSION := preload("res://assets/art/vfx/boss/explosion.png")
const EXHAUST := preload("res://assets/art/vfx/boss/rocket_exhaust.png")
const TRAIL_PUFFS := [preload("res://assets/art/vfx/boss/smoke_puff_a.png"),
	preload("res://assets/art/vfx/boss/smoke_puff_b.png")]
## The boss smoke's palest shade, as for the landing dust; translucent so the
## trail never hides the launcher or the player.
const TRAIL_SHADE := Color("#a0afaa", 0.8)
# The sheet's only single-piece flame frames; the others carry a detached
# spark that reads as separate debris behind a small rocket.
const EXHAUST_FRAMES := [1, 2]
# Bullet.png already points up-right by about 18 degrees.
const ART_NOSE_ANGLE := 0.32175055
@export var launch_duration := 0.24
@export var launch_speed := 4.5
@export var acceleration := 24.0
@export var turn_rate := 2.4
var target_position := Vector3.ZERO
var _flight_time := 0.0
var _launch_facing := 1.0
var _guidance_finished := false
var _cruise_speed := 11.0
## The flame rides the rocket's tail; smoke puffs are released into the level
## behind it and finish fading on their own after impact or expiry.
@export var tail_offset := 0.36
@export var trail_spacing := 0.45
@export var trail_pixel_size := 0.04
## The flame stays hidden until the tail has cleared the launcher pod, so it
## never paints over the boss's head during release.
@export var exhaust_clearance := 1.3
var _launch_point := Vector3.ZERO
# Below the boss sprite's 10 while leaving its tube, so a rocket emerges from
# the launcher instead of sitting on top of it; the scene's own priority after.
const LEAVING_TUBE_PRIORITY := 9
var _flight_priority := 14
var _exhaust: Sprite3D
var _trail_travel := 0.0
var _puffs_released := 0

func _ready() -> void:
	super()
	impacted.connect(_on_impact)
	_exhaust = Sprite3D.new()
	_exhaust.name = "Exhaust"
	_exhaust.texture = EXHAUST
	_exhaust.hframes = 6
	_exhaust.pixel_size = 0.06
	# The flame's base sits on the cell's bottom row: pin that row to the tail.
	_exhaust.offset = Vector2(0, 16)
	_exhaust.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_exhaust.shaded = false
	_exhaust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_exhaust.render_priority = 13
	_exhaust.visible = false
	add_child(_exhaust)
	_flight_priority = visual.render_priority

func launch_at(target: Vector3, launch_direction: Vector3, source: CollisionObject3D,
		attack: CombatHit) -> void:
	target_position = target
	_launch_point = global_position
	visual.render_priority = LEAVING_TUBE_PRIORITY
	_launch_facing = signf(launch_direction.x)
	_flight_time = 0.0
	_guidance_finished = false
	_cruise_speed = speed
	speed = minf(launch_speed, _cruise_speed)
	launch(launch_direction, source, attack)

func _physics_process(delta: float) -> void:
	if not _launched or _expired:
		return
	_flight_time += delta
	speed = move_toward(speed, _cruise_speed, acceleration * delta)
	var to_target := target_position - global_position
	if to_target.x * _launch_facing <= 0.0:
		_guidance_finished = true
	if _flight_time > launch_duration and not _guidance_finished:
		var current_angle := atan2(_direction.y, _direction.x)
		var target_angle := atan2(to_target.y, to_target.x)
		var change := clampf(angle_difference(current_angle, target_angle),
			-turn_rate * delta, turn_rate * delta)
		var next_angle := current_angle + change
		_direction = Vector3(cos(next_angle), sin(next_angle), 0)
		_apply_directional_visual()
	var previous := global_position
	super(delta)
	if not _expired:
		_tick_trail(global_position.distance_to(previous))

func _tick_trail(travelled: float) -> void:
	var back := -_direction
	# Clear of the pod: draw in front again and light the flame together.
	var clear := global_position.distance_to(_launch_point) >= exhaust_clearance
	visual.render_priority = _flight_priority if clear else LEAVING_TUBE_PRIORITY
	_exhaust.visible = clear
	_exhaust.position = back * tail_offset + Vector3(0, 0, visual.position.z - 0.01)
	# The flame art points up; turn its tip away from the travel direction.
	_exhaust.rotation.z = atan2(back.y, back.x) - PI * 0.5
	_exhaust.frame = EXHAUST_FRAMES[int(_flight_time * 14.0) % EXHAUST_FRAMES.size()]
	# Smoke starts once the rocket has boosted clear of the launcher.
	if _flight_time < launch_duration:
		return
	_trail_travel += travelled
	while _trail_travel >= trail_spacing:
		_trail_travel -= trail_spacing
		# Space puffs along the path actually flown this frame.
		var point := global_position + back * (tail_offset + _trail_travel)
		var puff: Sprite3D = EFFECT.spawn(get_parent(), point - Vector3(0, 0, 1.4) + Vector3(0, 0, visual.position.z - 0.02),
			TRAIL_PUFFS[_puffs_released % TRAIL_PUFFS.size()], 32, trail_pixel_size)
		puff.frame_rate = 12.0
		# The puff is drawn low in its 48 px cell; centre it on the path.
		puff.offset = Vector2(0, 12)
		puff.modulate = TRAIL_SHADE
		puff.render_priority = 12
		puff.flip_h = _puffs_released % 2 == 1
		_puffs_released += 1

func _apply_directional_visual() -> void:
	super()
	if visual == null: return
	# Mirror the authored rising rocket for left launches, keeping its nose
	# aligned with travel rather than adding the sheet's baked-in angle twice.
	visual.flip_h = _direction.x < 0.0
	var authored_angle := PI - ART_NOSE_ANGLE if visual.flip_h else ART_NOSE_ANGLE
	visual.rotation.z = atan2(_direction.y, _direction.x) - authored_angle

func _on_impact(point: Vector3, _normal: Vector3, _collider: Object) -> void:
	EFFECT.spawn(get_parent(), point, EXPLOSION, 48, 0.04)
