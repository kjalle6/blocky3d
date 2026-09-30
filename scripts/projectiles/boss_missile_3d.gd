extends "res://scripts/projectiles/handgun_projectile_3d.gd"
## A tube-by-tube rocket ripple. Boost clear before curving toward the fixed
## salvo area; never chase the player or loop back after passing the target.
const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const EXPLOSION := preload("res://assets/art/vfx/boss/explosion.png")
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

func _ready() -> void:
	super()
	impacted.connect(_on_impact)

func launch_at(target: Vector3, launch_direction: Vector3, source: CollisionObject3D,
		attack: CombatHit) -> void:
	target_position = target
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
	super(delta)

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
