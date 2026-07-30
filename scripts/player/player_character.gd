class_name PlayerCharacter
extends CharacterBody3D
## Core path-relative 2.5D controller. Abilities such as wall movement and dash
## will be composed later; this script owns only universally available motion.

signal died
signal attack_connected(target: Node3D)
signal damage_received(source_position: Vector3)

@export var movement: PlayerMovementConfig
@export var traversal_rail: TraversalRail3D
@export var fall_limit_y := -8.0
@export_range(0.05, 1.0, 0.01) var attack_duration := 0.34
@export_range(0.0, 1.0, 0.01) var attack_impact_time := 0.13
@export_range(0.1, 3.0, 0.05) var attack_reach := 1.25
@export_range(0.1, 2.0, 0.05) var attack_vertical_tolerance := 0.9

var path_speed := 0.0
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _dead := false
var _descending_before_slide := false
var _facing_sign := 1.0
var _attack_remaining := 0.0
var _attack_hit_applied := false
var _available_abilities: Array[StringName] = []
var _active_abilities: Array[StringName] = []

@onready var pixel_visual: PixelPlayerVisual3D = get_node_or_null("PixelVisual") as PixelPlayerVisual3D


func _ready() -> void:
	assert(movement != null, "PlayerCharacter requires a PlayerMovementConfig.")
	add_to_group("player_character")
	floor_snap_length = movement.floor_snap_length
	floor_max_angle = deg_to_rad(movement.maximum_floor_angle_degrees)


func _physics_process(delta: float) -> void:
	if traversal_rail == null:
		return
	if _dead:
		_update_pixel_visual(delta)
		return

	_update_jump_timers(delta)
	_update_attack(delta)
	var input_axis := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(input_axis):
		_facing_sign = signf(input_axis)
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

	_descending_before_slide = velocity.y < -0.5
	move_and_slide()
	global_position = traversal_rail.constrain_world_position(global_position)

	if global_position.y < fall_limit_y:
		kill()
	_update_pixel_visual(delta)


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
	if pixel_visual != null:
		pixel_visual.tick(0.0, is_on_floor(), 0.0, 0.0, false, true, _facing_sign > 0.0)
	died.emit()


func bounce(vertical_speed: float) -> void:
	if _dead:
		return
	velocity.y = vertical_speed
	_descending_before_slide = false
	floor_snap_length = 0.0


func was_descending_before_slide() -> bool:
	return _descending_before_slide


func stop_for_completion() -> void:
	velocity = Vector3.ZERO
	path_speed = 0.0
	set_physics_process(false)


func reset_at(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	path_speed = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_attack_remaining = 0.0
	_attack_hit_applied = false
	_dead = false
	_descending_before_slide = false
	visible = true
	set_physics_process(true)
	if pixel_visual != null:
		pixel_visual.reset_feedback()
		pixel_visual.set_state("idle", true)
	if traversal_rail != null:
		global_position = traversal_rail.constrain_world_position(global_position)


func is_dead() -> bool:
	return _dead


func configure_abilities(
	owned_abilities: Array[StringName],
	available_abilities: Array[StringName]
) -> void:
	_available_abilities = available_abilities.duplicate()
	_active_abilities.clear()
	for ability_id in owned_abilities:
		if ability_id in _available_abilities and ability_id not in _active_abilities:
			_active_abilities.append(ability_id)


func enable_ability(ability_id: StringName) -> bool:
	if ability_id not in _available_abilities or ability_id in _active_abilities:
		return false
	_active_abilities.append(ability_id)
	return true


func has_ability(ability_id: StringName) -> bool:
	return ability_id in _active_abilities


func feet_world_y() -> float:
	return global_position.y - 0.55


func receive_enemy_hit(source_position: Vector3) -> void:
	if _dead:
		return
	damage_received.emit(source_position)
	kill()


func play_damage_flash() -> void:
	if pixel_visual != null:
		pixel_visual.flash_damage()


func _update_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and _attack_remaining <= 0.0:
		_attack_remaining = attack_duration
		_attack_hit_applied = false
	if _attack_remaining <= 0.0:
		return
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	var elapsed := attack_duration - _attack_remaining
	if not _attack_hit_applied and elapsed >= attack_impact_time:
		_attack_hit_applied = true
		_perform_melee_hit()


func _perform_melee_hit() -> void:
	var tangent := traversal_rail.tangent_at_world_position(global_position)
	for candidate in get_tree().get_nodes_in_group("melee_target"):
		if not candidate is Node3D or not candidate.has_method("receive_melee_hit"):
			continue
		var target := candidate as Node3D
		var offset := target.global_position - global_position
		var forward_distance := offset.dot(tangent) * _facing_sign
		if (
			forward_distance >= 0.0
			and forward_distance <= attack_reach
			and absf(offset.y) <= attack_vertical_tolerance
		):
			candidate.call("receive_melee_hit", global_position)
			attack_connected.emit(target)


func _update_pixel_visual(delta: float) -> void:
	if pixel_visual == null:
		return
	pixel_visual.tick(
		delta,
		is_on_floor(),
		path_speed,
		velocity.y,
		_attack_remaining > 0.0,
		_dead,
		_facing_sign > 0.0
	)
