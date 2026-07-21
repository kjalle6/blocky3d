class_name PlayerCharacter
extends CharacterBody3D
## Core path-relative 2.5D controller. Abilities such as wall movement and dash
## will be composed later; this script owns only universally available motion.

signal died

@export var movement: PlayerMovementConfig
@export var traversal_rail: TraversalRail3D
@export var fall_limit_y := -8.0

var path_speed := 0.0
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _dead := false


func _ready() -> void:
	assert(movement != null, "PlayerCharacter requires a PlayerMovementConfig.")
	floor_snap_length = movement.floor_snap_length
	floor_max_angle = deg_to_rad(movement.maximum_floor_angle_degrees)


func _physics_process(delta: float) -> void:
	if _dead or traversal_rail == null:
		return

	_update_jump_timers(delta)
	var input_axis := Input.get_axis("move_left", "move_right")
	var grounded := is_on_floor()
	var acceleration := movement.air_acceleration
	if grounded:
		acceleration = movement.ground_acceleration if not is_zero_approx(input_axis) else movement.ground_deceleration
	var target_speed := input_axis * movement.maximum_speed
	path_speed = move_toward(path_speed, target_speed, acceleration * delta)

	var tangent := traversal_rail.tangent_at_world_position(global_position)
	velocity.x = tangent.x * path_speed
	velocity.z = tangent.z * path_speed
	velocity.y = maxf(velocity.y - movement.gravity * delta, -movement.maximum_fall_speed)

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = movement.jump_velocity
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		floor_snap_length = 0.0
	elif grounded:
		floor_snap_length = movement.floor_snap_length

	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= movement.released_jump_multiplier

	move_and_slide()
	global_position = traversal_rail.constrain_world_position(global_position)

	if global_position.y < fall_limit_y:
		kill()


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_remaining = movement.coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = movement.jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)


func kill() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	path_speed = 0.0
	visible = false
	set_physics_process(false)
	died.emit()


func reset_at(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	path_speed = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_dead = false
	visible = true
	set_physics_process(true)
	if traversal_rail != null:
		global_position = traversal_rail.constrain_world_position(global_position)
