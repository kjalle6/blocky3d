class_name PlayerCharacter
extends CharacterBody3D
## Core 2D side-scrolling controller. Optional movement abilities are gated
## by the active level's declared ability policy and share typed tuning.

const DOUBLE_JUMP_VISUAL_DURATION := 0.43
const DEATH_KIND_GENERIC: StringName = &"generic"
const DEATH_KIND_WATER: StringName = &"water"

signal died
signal death_started(kind: StringName, world_position: Vector3)
signal attack_connected(target: Node3D)
signal damage_received(source_position: Vector3)
signal ability_performed(ability_id: StringName)

@export var movement: PlayerMovementConfig
@export var fall_limit_y := -8.0
@export_range(0.05, 1.0, 0.01) var attack_duration := 0.34
@export_range(0.0, 1.0, 0.01) var attack_impact_time := 0.13
@export_range(0.1, 3.0, 0.05) var attack_reach := 1.25
@export_range(0.1, 2.0, 0.05) var attack_vertical_tolerance := 0.9
@export_category("Developer inspection")
@export_range(1.0, 40.0, 0.5) var inspection_flight_speed := 14.0
@export_range(1.0, 4.0, 0.25) var inspection_fast_multiplier := 2.0

var horizontal_speed := 0.0
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _dead := false
var _death_kind := DEATH_KIND_GENERIC
var _descending_before_slide := false
var _facing_sign := 1.0
var _attack_remaining := 0.0
var _attack_hit_applied := false
var _available_abilities: Array[StringName] = []
var _active_abilities: Array[StringName] = []
var _aerial_jumps_remaining := 0
var _double_jump_visual_remaining := 0.0
var _wall_contact_direction := 0.0
var _last_wall_contact_direction := 0.0
var _wall_coyote_remaining := 0.0
var _wall_jump_control_lock_remaining := 0.0
var _wall_sliding := false
var _blocked_wall_jump_direction := 0.0
var _dash_remaining := 0.0
var _dash_available := false
var _dash_direction := 1.0
var _transition_run_remaining := 0.0
var _transition_run_direction := 1.0
var _transition_run_speed := 0.0
var _developer_inspection_enabled := false
var _normal_collision_layer := 0
var _normal_collision_mask := 0
var _normal_hazard_contact_layer := 0

@onready var pixel_visual: PixelPlayerVisual3D = get_node_or_null("PixelVisual") as PixelPlayerVisual3D
@onready var hazard_contact: Area3D = get_node("HazardContact") as Area3D


func _ready() -> void:
	assert(movement != null, "PlayerCharacter requires a PlayerMovementConfig.")
	add_to_group("player_character")
	floor_snap_length = movement.floor_snap_length
	floor_max_angle = deg_to_rad(movement.maximum_floor_angle_degrees)
	_normal_collision_layer = collision_layer
	_normal_collision_mask = collision_mask
	_normal_hazard_contact_layer = hazard_contact.collision_layer


func _physics_process(delta: float) -> void:
	if _developer_inspection_enabled:
		_update_developer_inspection(delta)
		return
	if _dead:
		_update_pixel_visual(delta)
		return
	if is_transition_running():
		_update_transition_run(delta)
		return

	_update_jump_timers(delta)
	_double_jump_visual_remaining = maxf(0.0, _double_jump_visual_remaining - delta)
	_wall_jump_control_lock_remaining = maxf(
		0.0,
		_wall_jump_control_lock_remaining - delta
	)
	_update_dash_timer(delta)
	var input_axis := Input.get_axis("move_left", "move_right")
	var grounded := is_on_floor()
	if grounded and not is_dashing():
		_refresh_dash()
	if Input.is_action_just_pressed("dash"):
		_try_start_dash(input_axis)
	_update_attack(delta)
	if (
		not is_dashing()
		and _wall_jump_control_lock_remaining <= 0.0
		and not is_zero_approx(input_axis)
	):
		_facing_sign = signf(input_axis)
	if grounded:
		_refresh_aerial_jumps()
		_wall_coyote_remaining = 0.0
		_blocked_wall_jump_direction = 0.0
	elif _wall_contact_direction != 0.0 and has_ability(PlayerAbility.WALL_JUMP):
		_wall_coyote_remaining = movement.wall_coyote_time
		_last_wall_contact_direction = _wall_contact_direction
	else:
		_wall_coyote_remaining = maxf(0.0, _wall_coyote_remaining - delta)

	if is_dashing():
		horizontal_speed = _dash_direction * movement.dash_speed
	elif _wall_jump_control_lock_remaining <= 0.0:
		var acceleration := movement.air_acceleration
		if grounded:
			acceleration = (
				movement.ground_acceleration
				if not is_zero_approx(input_axis)
				else movement.ground_deceleration
			)
		var target_speed := input_axis * movement.maximum_speed
		horizontal_speed = move_toward(horizontal_speed, target_speed, acceleration * delta)

	_wall_sliding = (
		has_ability(PlayerAbility.WALL_JUMP)
		and not is_dashing()
		and not grounded
		and _wall_contact_direction != 0.0
		and velocity.y < 0.0
	)
	var active_gravity := movement.gravity
	var active_fall_speed := movement.maximum_fall_speed
	if _wall_sliding:
		active_gravity *= movement.wall_slide_gravity_multiplier
		active_fall_speed = movement.wall_slide_max_fall_speed
		_facing_sign = _wall_contact_direction
	if is_dashing():
		velocity.y = 0.0
	else:
		velocity.y = maxf(velocity.y - active_gravity * delta, -active_fall_speed)

	if _jump_buffer_remaining > 0.0:
		if _coyote_remaining > 0.0:
			_perform_ground_jump()
		elif _can_wall_jump():
			_perform_wall_jump()
		elif _can_double_jump():
			_perform_double_jump()
	elif grounded:
		floor_snap_length = movement.floor_snap_length

	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= movement.released_jump_multiplier

	velocity.x = horizontal_speed
	velocity.z = 0.0
	_descending_before_slide = velocity.y < -0.5
	move_and_slide()
	_update_wall_contact()
	if is_dashing() and is_on_wall():
		_finish_dash(true)
	_wall_sliding = (
		has_ability(PlayerAbility.WALL_JUMP)
		and not is_dashing()
		and not is_on_floor()
		and _wall_contact_direction != 0.0
		and velocity.y < 0.0
	)
	if _wall_sliding:
		velocity.y = maxf(velocity.y, -movement.wall_slide_max_fall_speed)

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


func kill(kind: StringName = DEATH_KIND_GENERIC) -> void:
	if _dead or _developer_inspection_enabled or is_transition_running():
		return
	_dead = true
	_death_kind = kind
	_dash_remaining = 0.0
	_dash_available = false
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	if pixel_visual != null:
		pixel_visual.tick(0.0, is_on_floor(), 0.0, 0.0, false, true, _facing_sign > 0.0)
	death_started.emit(_death_kind, global_position)
	died.emit()


func bounce(vertical_speed: float) -> void:
	if _dead:
		return
	if is_dashing():
		_finish_dash()
	velocity.y = vertical_speed
	_descending_before_slide = false
	floor_snap_length = 0.0


func was_descending_before_slide() -> bool:
	return _descending_before_slide


func stop_for_completion() -> void:
	_transition_run_remaining = 0.0
	_transition_run_speed = 0.0
	_dash_remaining = 0.0
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	if pixel_visual != null:
		pixel_visual.set_state("idle", true)
	set_physics_process(false)


## Used when a doorway's art is itself the occluder. The body stops at the
## threshold and vanishes into that authored darkness instead of visibly
## running beyond the entrance while the screen closes.
func disappear_for_transition() -> void:
	stop_for_completion()
	visible = false


func reset_at(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_attack_remaining = 0.0
	_attack_hit_applied = false
	_double_jump_visual_remaining = 0.0
	_wall_contact_direction = 0.0
	_last_wall_contact_direction = 0.0
	_wall_coyote_remaining = 0.0
	_wall_jump_control_lock_remaining = 0.0
	_wall_sliding = false
	_blocked_wall_jump_direction = 0.0
	_dash_remaining = 0.0
	_dash_available = has_ability(PlayerAbility.DASH)
	_dash_direction = _facing_sign
	_transition_run_remaining = 0.0
	_transition_run_direction = _facing_sign
	_transition_run_speed = 0.0
	_aerial_jumps_remaining = 1 if has_ability(PlayerAbility.DOUBLE_JUMP) else 0
	_dead = false
	_death_kind = DEATH_KIND_GENERIC
	_descending_before_slide = false
	visible = true
	set_physics_process(true)
	if pixel_visual != null:
		pixel_visual.reset_feedback()
		pixel_visual.set_state("idle", true)
	_apply_developer_inspection_collision()


func is_dead() -> bool:
	return _dead


func death_kind() -> StringName:
	return _death_kind


func configure_abilities(
	owned_abilities: Array[StringName],
	available_abilities: Array[StringName]
) -> void:
	_available_abilities = available_abilities.duplicate()
	_active_abilities.clear()
	for ability_id in owned_abilities:
		if ability_id in _available_abilities and ability_id not in _active_abilities:
			_active_abilities.append(ability_id)
	_aerial_jumps_remaining = 1 if has_ability(PlayerAbility.DOUBLE_JUMP) else 0
	_dash_remaining = 0.0
	_dash_available = has_ability(PlayerAbility.DASH)


func enable_ability(ability_id: StringName) -> bool:
	if ability_id not in _available_abilities or ability_id in _active_abilities:
		return false
	_active_abilities.append(ability_id)
	if ability_id == PlayerAbility.DOUBLE_JUMP:
		_aerial_jumps_remaining = maxi(_aerial_jumps_remaining, 1)
	elif ability_id == PlayerAbility.DASH:
		_dash_available = true
	return true


func has_ability(ability_id: StringName) -> bool:
	return ability_id in _active_abilities


func aerial_jumps_remaining() -> int:
	return _aerial_jumps_remaining


func is_wall_sliding() -> bool:
	return _wall_sliding


func wall_contact_direction() -> float:
	return _wall_contact_direction


func blocked_wall_jump_direction() -> float:
	return _blocked_wall_jump_direction


func is_dashing() -> bool:
	return _dash_remaining > 0.0


func dash_available() -> bool:
	return _dash_available


func dash_direction() -> float:
	return _dash_direction


func is_dash_airborne() -> bool:
	return is_dashing() and not _has_dash_floor_support()


func feet_world_y() -> float:
	return global_position.y - 0.55


func is_attacking() -> bool:
	return _attack_remaining > 0.0


func developer_melee_bounds() -> Rect2:
	var minimum_x := global_position.x
	if _facing_sign < 0.0:
		minimum_x -= attack_reach
	return Rect2(
		Vector2(minimum_x, global_position.y - attack_vertical_tolerance),
		Vector2(attack_reach, attack_vertical_tolerance * 2.0)
	)


func receive_enemy_hit(source_position: Vector3) -> void:
	if _dead or _developer_inspection_enabled or is_transition_running():
		return
	damage_received.emit(source_position)
	kill()


func set_developer_inspection_enabled(enabled: bool) -> void:
	if _developer_inspection_enabled == enabled:
		return
	_developer_inspection_enabled = enabled
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	_dash_remaining = 0.0
	_transition_run_remaining = 0.0
	_transition_run_speed = 0.0
	_attack_remaining = 0.0
	_attack_hit_applied = false
	_wall_sliding = false
	floor_snap_length = 0.0 if enabled else movement.floor_snap_length
	_apply_developer_inspection_collision()
	set_physics_process(true)
	if pixel_visual != null:
		pixel_visual.set_state("idle", true)


func is_developer_inspection_enabled() -> bool:
	return _developer_inspection_enabled


## Carries a committed horizontal run through a black scene transition. Input,
## attacks, abilities, and lethal contacts are temporarily ignored so the exit
## and entrance read as one matched movement rather than two stationary spawns.
func begin_transition_run(direction: float, speed: float, duration: float) -> void:
	assert(is_equal_approx(absf(direction), 1.0))
	assert(speed > 0.0)
	assert(duration > 0.0)
	_transition_run_direction = signf(direction)
	_transition_run_speed = speed
	_transition_run_remaining = duration
	_facing_sign = _transition_run_direction
	_dash_remaining = 0.0
	_attack_remaining = 0.0
	_attack_hit_applied = false
	_wall_sliding = false
	_wall_jump_control_lock_remaining = 0.0
	horizontal_speed = _transition_run_direction * _transition_run_speed
	velocity.x = horizontal_speed
	set_physics_process(true)


func finish_transition_run() -> void:
	_transition_run_remaining = 0.0
	_transition_run_speed = 0.0
	_transition_run_direction = _facing_sign
	horizontal_speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	set_physics_process(true)
	if pixel_visual != null:
		pixel_visual.set_state("idle", true)


func is_transition_running() -> bool:
	return _transition_run_remaining > 0.0


func _update_transition_run(delta: float) -> void:
	_transition_run_remaining = maxf(0.0, _transition_run_remaining - delta)
	_facing_sign = _transition_run_direction
	horizontal_speed = _transition_run_direction * _transition_run_speed
	velocity.x = horizontal_speed
	velocity.z = 0.0
	velocity.y = maxf(
		velocity.y - movement.gravity * delta,
		-movement.maximum_fall_speed
	)
	move_and_slide()
	_update_pixel_visual(delta)


func _apply_developer_inspection_collision() -> void:
	if not is_node_ready():
		return
	collision_layer = 0 if _developer_inspection_enabled else _normal_collision_layer
	collision_mask = 0 if _developer_inspection_enabled else _normal_collision_mask
	hazard_contact.collision_layer = (
		0 if _developer_inspection_enabled else _normal_hazard_contact_layer
	)


func _update_developer_inspection(delta: float) -> void:
	var flight_input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("developer_fly_down", "developer_fly_up")
	)
	if flight_input.length_squared() > 1.0:
		flight_input = flight_input.normalized()
	var active_speed := inspection_flight_speed
	if Input.is_action_pressed("dash"):
		active_speed *= inspection_fast_multiplier
	velocity = Vector3(flight_input.x, flight_input.y, 0.0) * active_speed
	horizontal_speed = velocity.x
	global_position += velocity * delta
	global_position.z = 0.0
	if not is_zero_approx(flight_input.x):
		_facing_sign = signf(flight_input.x)
	_update_pixel_visual(delta)


func play_damage_flash() -> void:
	if pixel_visual != null:
		pixel_visual.flash_damage()


func _update_attack(delta: float) -> void:
	if is_dashing():
		_attack_remaining = 0.0
		_attack_hit_applied = false
		return
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
	for candidate in get_tree().get_nodes_in_group("melee_target"):
		if not candidate is Node3D or not candidate.has_method("receive_melee_hit"):
			continue
		var target := candidate as Node3D
		var offset := target.global_position - global_position
		var forward_distance := offset.x * _facing_sign
		if (
			forward_distance >= 0.0
			and forward_distance <= attack_reach
			and absf(offset.y) <= attack_vertical_tolerance
		):
			candidate.call("receive_melee_hit", global_position)
			attack_connected.emit(target)


func _perform_ground_jump() -> void:
	if is_dashing():
		_finish_dash()
	velocity.y = movement.jump_velocity
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	floor_snap_length = 0.0


func _can_double_jump() -> bool:
	return (
		has_ability(PlayerAbility.DOUBLE_JUMP)
		and _aerial_jumps_remaining > 0
	)


func _can_wall_jump() -> bool:
	return (
		has_ability(PlayerAbility.WALL_JUMP)
		and _wall_coyote_remaining > 0.0
		and _last_wall_contact_direction != 0.0
		and _last_wall_contact_direction != _blocked_wall_jump_direction
	)


func _perform_wall_jump() -> void:
	if is_dashing():
		_finish_dash()
	var source_wall_direction := _last_wall_contact_direction
	var jump_direction := -source_wall_direction
	velocity.y = movement.wall_jump_vertical_speed
	horizontal_speed = jump_direction * movement.wall_jump_horizontal_speed
	_facing_sign = jump_direction
	_blocked_wall_jump_direction = source_wall_direction
	_wall_jump_control_lock_remaining = movement.wall_jump_control_lock_time
	_wall_coyote_remaining = 0.0
	_wall_contact_direction = 0.0
	_wall_sliding = false
	_jump_buffer_remaining = 0.0
	floor_snap_length = 0.0
	ability_performed.emit(PlayerAbility.WALL_JUMP)


func _perform_double_jump() -> void:
	if is_dashing():
		_finish_dash()
	velocity.y = movement.jump_velocity
	_aerial_jumps_remaining -= 1
	_jump_buffer_remaining = 0.0
	floor_snap_length = 0.0
	_double_jump_visual_remaining = DOUBLE_JUMP_VISUAL_DURATION
	ability_performed.emit(PlayerAbility.DOUBLE_JUMP)


func _refresh_aerial_jumps() -> void:
	_aerial_jumps_remaining = 1 if has_ability(PlayerAbility.DOUBLE_JUMP) else 0


func _refresh_dash() -> void:
	_dash_available = has_ability(PlayerAbility.DASH)


func _update_dash_timer(delta: float) -> void:
	if not is_dashing():
		return
	_dash_remaining -= delta
	if _dash_remaining <= 0.0:
		_finish_dash()


func _try_start_dash(input_axis: float) -> bool:
	if (
		not has_ability(PlayerAbility.DASH)
		or not _dash_available
		or is_dashing()
	):
		return false
	_dash_direction = signf(input_axis) if not is_zero_approx(input_axis) else _facing_sign
	_facing_sign = _dash_direction
	_dash_remaining = movement.dash_duration
	_dash_available = false
	_attack_remaining = 0.0
	_attack_hit_applied = false
	_wall_jump_control_lock_remaining = 0.0
	_wall_contact_direction = 0.0
	_wall_sliding = false
	velocity.y = 0.0
	horizontal_speed = _dash_direction * movement.dash_speed
	floor_snap_length = 0.0
	ability_performed.emit(PlayerAbility.DASH)
	return true


func _finish_dash(stopped_by_wall := false) -> void:
	_dash_remaining = 0.0
	if stopped_by_wall:
		horizontal_speed = 0.0
	elif absf(horizontal_speed) > movement.dash_exit_speed:
		horizontal_speed = signf(horizontal_speed) * movement.dash_exit_speed


func _has_dash_floor_support() -> bool:
	if is_on_floor():
		return true
	# Dash deliberately disables floor snapping. A short test motion preserves
	# the grounded presentation while the body is still directly supported,
	# without mistaking a real gap crossing for a grounded Dash.
	return test_move(
		global_transform,
		Vector3.DOWN * maxf(0.05, movement.floor_snap_length)
	)


func _update_wall_contact() -> void:
	_wall_contact_direction = 0.0
	if not has_ability(PlayerAbility.WALL_JUMP) or not is_on_wall():
		return
	var along_route := get_wall_normal().x
	if absf(along_route) < 0.5:
		return
	_wall_contact_direction = -signf(along_route)
	if (
		_blocked_wall_jump_direction != 0.0
		and _wall_contact_direction != _blocked_wall_jump_direction
	):
		_blocked_wall_jump_direction = 0.0
	_last_wall_contact_direction = _wall_contact_direction


func _update_pixel_visual(delta: float) -> void:
	if pixel_visual == null:
		return
	pixel_visual.tick(
		delta,
		is_on_floor(),
		horizontal_speed,
		velocity.y,
		_attack_remaining > 0.0,
		_dead,
		_facing_sign > 0.0,
		_double_jump_visual_remaining > 0.0,
		_wall_sliding,
		is_dashing(),
		is_dash_airborne()
	)
