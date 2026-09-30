class_name PlayerCharacter
extends CharacterBody3D
## Core 2D side-scrolling controller. Optional movement abilities are gated
## by the active level's declared ability policy and share typed tuning.

## Half the authored 1.1 m body height; shared by feet and swept stomp contact.
const FEET_OFFSET_Y := 0.55
const DOUBLE_JUMP_VISUAL_DURATION := 0.43
const DEATH_KIND_GENERIC: StringName = &"generic"
const DEATH_KIND_WATER: StringName = &"water"
const ENEMY_CONTACT := preload("res://scripts/combat/enemy_combat_contact.gd")

signal died
signal death_started(kind: StringName, world_position: Vector3)
signal attack_connected(target: Node3D)
signal melee_swung(world_position: Vector3)
signal stomp_bounced(world_position: Vector3)
signal damage_received(source_position: Vector3)
signal health_changed(current: int, maximum: int)
signal healing_used(item_id: StringName, amount: int)
signal ability_performed(ability_id: StringName)
signal weapon_equipped(weapon_id: StringName)
signal projectile_fired(projectile: HandgunProjectile3D)
signal handgun_empty_triggered(world_position: Vector3)
signal ground_jump_started
signal landed(impact_speed: float)
signal movement_reset

@export var combat: CombatProfile = preload("res://resources/combat/player.tres")
@export var knife_attack: AttackDefinition = preload("res://resources/combat/knife.tres")
@export var stomp_attack: AttackDefinition = preload("res://resources/combat/stomp.tres")
@export var movement: PlayerMovementConfig
@export_range(0.2, 1.0, 0.05) var handgun_backpedal_speed_ratio := 0.65
@export var fall_limit_y := -8.0
@export_range(0.05, 1.0, 0.01) var attack_duration := 0.34
@export_range(0.0, 1.0, 0.01) var attack_impact_time := 0.13
## Keep contact through the fully extended source poses, before frame 5 retracts.
@export_range(0.01, 0.3, 0.01) var attack_active_duration := 0.14
@export_range(0.1, 3.0, 0.05) var attack_reach := 1.25
@export_range(0.1, 2.0, 0.05) var attack_vertical_tolerance := 0.9
@export_category("Developer inspection")
@export_range(1.0, 40.0, 0.5) var inspection_flight_speed := 14.0
@export_range(1.0, 4.0, 0.25) var inspection_fast_multiplier := 2.0

var health := HealthState.new()
var inventory := PlayerInventory.new()
var healing_remaining := 0.0
var last_healing_amount := 0
var _attack_lock_remaining := 0.0
var _hurt_visual_remaining := 0.0
var _psychic_freeze_remaining := 0.0
var _ground_hold_source: Node3D
var _ground_hold_remaining := 0.0
var _melee_hit: CombatHit
var horizontal_speed := 0.0
var _knockback_speed := 0.0
var _knockback_deceleration := 24.0
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _dead := false
var _death_kind := DEATH_KIND_GENERIC
var _descending_before_slide := false
var _facing_sign := 1.0
var _attack_remaining := 0.0
var _melee_hit_targets: Array[int] = []
var _active_attack_weapon_id: StringName = &""
var _active_attack_aim_up := false
var _owned_weapon_ids: Array[StringName] = [PlayerWeapon.KNIFE]
var _equipped_weapon_id: StringName = PlayerWeapon.KNIFE
var _pending_weapon_id: StringName = &""
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
@onready var hazard_contact: Area3D = get_node_or_null("HazardContact") as Area3D
@onready var player_handgun: PlayerHandgun3D = get_node_or_null("%PlayerHandgun") as PlayerHandgun3D


func _ready() -> void:
	assert(combat != null, "PlayerCharacter requires a CombatProfile in combat.")
	assert(movement != null, "PlayerCharacter requires a PlayerMovementConfig.")
	assert(knife_attack != null, "PlayerCharacter requires an AttackDefinition in knife_attack.")
	assert(stomp_attack != null, "PlayerCharacter requires an AttackDefinition in stomp_attack.")
	assert(hazard_contact != null, "PlayerCharacter requires an Area3D child named HazardContact.")
	assert(player_handgun != null, "PlayerCharacter requires a unique PlayerHandgun node with PlayerHandgun3D.")
	health.changed.connect(func(current: int, maximum: int) -> void: health_changed.emit(current, maximum))
	health.reset(combat.maximum_hp)
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

	healing_remaining = maxf(0.0, healing_remaining - delta)
	_attack_lock_remaining = maxf(0.0, _attack_lock_remaining - delta)
	_hurt_visual_remaining = maxf(0.0, _hurt_visual_remaining - delta)
	if _ground_hold_remaining > 0.0:
		_update_ground_hold(delta)
		return
	if is_psychically_frozen():
		_psychic_freeze_remaining = maxf(0.0, _psychic_freeze_remaining - delta)
		velocity = Vector3.ZERO
		horizontal_speed = 0.0
		if pixel_visual != null:
			pixel_visual.set_psychic_frozen(is_psychically_frozen())
		return
	if Input.is_action_just_pressed("quick_item_1"):
		use_quick_item(0)
	if Input.is_action_just_pressed("quick_item_2"):
		use_quick_item(1)
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
	if (
		not is_dashing()
		and _wall_jump_control_lock_remaining <= 0.0
		and not is_zero_approx(input_axis)
	):
		_facing_sign = signf(input_axis)
	_update_weapon_selection_input()
	var shot_blocked_by_dash := is_dashing()
	_update_attack(delta)
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
		if grounded and player_handgun.is_retreating(input_axis):
			target_speed *= handgun_backpedal_speed_ratio
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

	var controlled_speed := horizontal_speed
	if controlled_speed * _knockback_speed < 0.0:
		# A held run cannot erase the impact immediately. Countersteering
		# returns smoothly as the shove falls below ordinary running speed.
		# Jump stays live; dash and wall jump explicitly cancel the impulse.
		controlled_speed *= 1.0 - clampf(absf(_knockback_speed) / movement.maximum_speed, 0.0, 1.0)
	velocity.x = controlled_speed + _knockback_speed
	_knockback_speed = move_toward(_knockback_speed, 0.0, _knockback_deceleration * delta)
	velocity.z = 0.0
	_descending_before_slide = velocity.y < -0.5
	var vertical_speed_before_slide := velocity.y
	var position_before_slide := global_position
	move_and_slide()
	if is_on_wall():
		_knockback_speed = 0.0
	# Resolve player damage before enemy attacks, using this tick's movement.
	if is_melee_contact_active():
		_perform_melee_hit()
	_resolve_stomp(position_before_slide)
	if not grounded and is_on_floor():
		landed.emit(maxf(0.0, -vertical_speed_before_slide))
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
	if not shot_blocked_by_dash:
		_fire_handgun_from_input()


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
	_clear_psychic_freeze()
	_hurt_visual_remaining = 0.0
	_knockback_speed = 0.0
	release_ground_hold()
	if health.current > 0:
		health.reset(health.maximum, 0)
	_death_kind = kind
	_dash_remaining = 0.0
	_dash_available = false
	_cancel_active_attack(false)
	_pending_weapon_id = &""
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
	# This bounce is requested by confirmed enemy stomps, not ordinary landings.
	stomp_bounced.emit(global_position)


func was_descending_before_slide() -> bool:
	return _descending_before_slide


func stop_for_completion() -> void:
	_hurt_visual_remaining = 0.0
	_knockback_speed = 0.0
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
	_clear_psychic_freeze()
	_hurt_visual_remaining = 0.0
	_knockback_speed = 0.0
	release_ground_hold()
	health.reset(combat.maximum_hp)
	_attack_lock_remaining = 0.0
	healing_remaining = 0.0
	_melee_hit = null
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_attack_remaining = 0.0
	_melee_hit_targets.clear()
	_active_attack_weapon_id = &""
	_active_attack_aim_up = false
	_pending_weapon_id = &""
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
	movement_reset.emit()


func can_save_state(stationary := true) -> bool:
	return not _dead and not is_control_locked() and not is_transition_running() and not _developer_inspection_enabled and not is_attacking() and not player_handgun.is_reloading() and healing_remaining <= 0.0 and _attack_lock_remaining <= 0.0 and (not stationary or absf(velocity.x) < 0.1) and absf(velocity.y) < 0.1


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
	return global_position.y - FEET_OFFSET_Y


func is_attacking() -> bool:
	return _attack_remaining > 0.0 or (
		_active_attack_weapon_id == PlayerWeapon.HANDGUN
		and player_handgun.is_recovering()
	)


func is_melee_attacking() -> bool:
	return is_attacking() and _active_attack_weapon_id == PlayerWeapon.KNIFE


func is_melee_contact_active() -> bool:
	var elapsed := attack_duration - _attack_remaining
	return (
		is_melee_attacking() and not _dead
		and elapsed >= attack_impact_time
		and elapsed <= attack_impact_time + attack_active_duration
	)


func active_attack_weapon_id() -> StringName:
	return _active_attack_weapon_id


func equipped_weapon_id() -> StringName:
	return _equipped_weapon_id


func owned_weapon_ids() -> Array[StringName]:
	return _owned_weapon_ids.duplicate()


func owns_weapon(weapon_id: StringName) -> bool:
	return weapon_id in _owned_weapon_ids


func configure_weapon_ownership(
	owned_weapon_ids: Array[StringName],
	auto_equip_weapon_id: StringName = &""
) -> void:
	_owned_weapon_ids.assign([PlayerWeapon.KNIFE])
	for weapon_id in owned_weapon_ids:
		if (
			PlayerWeapon.is_known(weapon_id)
			and weapon_id not in _owned_weapon_ids
		):
			_owned_weapon_ids.append(weapon_id)
	if (
		not auto_equip_weapon_id.is_empty()
		and auto_equip_weapon_id in _owned_weapon_ids
	):
		request_weapon(auto_equip_weapon_id)
	elif _equipped_weapon_id not in _owned_weapon_ids:
		_equip_weapon(PlayerWeapon.KNIFE)
	if (
		not _pending_weapon_id.is_empty()
		and _pending_weapon_id not in _owned_weapon_ids
	):
		_pending_weapon_id = &""
	_update_weapon_presentation()


func request_weapon(weapon_id: StringName) -> bool:
	if is_control_locked(): return false
	if not PlayerWeapon.is_known(weapon_id) or weapon_id not in _owned_weapon_ids:
		return false
	if is_attacking():
		_pending_weapon_id = weapon_id
		return true
	_pending_weapon_id = &""
	_equip_weapon(weapon_id)
	return true


func developer_melee_bounds() -> Rect2:
	var minimum_x := global_position.x
	if _facing_sign < 0.0:
		minimum_x -= attack_reach
	return Rect2(
		Vector2(minimum_x, global_position.y - attack_vertical_tolerance),
		Vector2(attack_reach, attack_vertical_tolerance * 2.0)
	)


func is_ground_held() -> bool:
	return _ground_hold_remaining > 0.0 and is_instance_valid(_ground_hold_source) and _ground_hold_source.is_inside_tree()


func is_control_locked() -> bool:
	return is_ground_held() or is_psychically_frozen()


func begin_ground_hold(source: Node3D, maximum_duration: float) -> bool:
	if _dead or _developer_inspection_enabled or is_transition_running() or is_ground_held():
		return false
	if not is_instance_valid(source) or maximum_duration <= 0.0:
		return false
	_knockback_speed = 0.0
	_hurt_visual_remaining = 0.0
	_ground_hold_source = source
	_ground_hold_remaining = maximum_duration
	_cancel_active_attack(false)
	_pending_weapon_id = &""
	_dash_remaining = 0.0
	_double_jump_visual_remaining = 0.0
	_wall_sliding = false
	_wall_jump_control_lock_remaining = 0.0
	_wall_contact_direction = 0.0
	_wall_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_descending_before_slide = false
	velocity = Vector3(0, minf(velocity.y, 0.0), 0)
	horizontal_speed = 0.0
	floor_snap_length = movement.floor_snap_length
	player_handgun.cancel_reload()
	if pixel_visual != null:
		pixel_visual.set_state("hurt", true)
		pixel_visual.tick_authored_state(0.0, "hurt", _facing_sign > 0.0)
	movement_reset.emit()
	return true


func release_ground_hold(source: Node3D = null) -> void:
	if source != null and _ground_hold_source != source:
		return
	_ground_hold_source = null
	_ground_hold_remaining = 0.0
	_jump_buffer_remaining = 0.0


func _update_ground_hold(delta: float) -> void:
	_ground_hold_remaining = maxf(0.0, _ground_hold_remaining - delta)
	if not is_ground_held():
		release_ground_hold()
		return
	# Input is blocked, but gravity and terrain collision still ground the player.
	horizontal_speed = 0.0
	velocity = Vector3(0, maxf(velocity.y - movement.gravity * 2.0 * delta,
		-movement.maximum_fall_speed), 0)
	move_and_slide()
	if global_position.y < fall_limit_y:
		kill()
	if pixel_visual != null and not _dead:
		pixel_visual.tick_authored_state(0.0, "hurt", _facing_sign > 0.0)


func is_psychically_frozen() -> bool:
	return _psychic_freeze_remaining > 0.0


func receive_psychic_hit(source_position: Vector3, hit: CombatHit, duration: float) -> bool:
	# Mark the freeze before damage feedback: this attack never pauses the world.
	var previous_freeze := _psychic_freeze_remaining
	_psychic_freeze_remaining = maxf(previous_freeze, duration)
	if not receive_enemy_hit(source_position, hit):
		_psychic_freeze_remaining = previous_freeze
		return false
	if _dead: return true
	_hurt_visual_remaining = 0.0
	_knockback_speed = 0.0
	_dash_remaining = 0.0
	_double_jump_visual_remaining = 0.0
	_wall_sliding = false
	_wall_jump_control_lock_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_descending_before_slide = false
	floor_snap_length = 0.0
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	player_handgun.cancel_reload()
	if pixel_visual != null:
		pixel_visual.tick_authored_state(0.0, "hurt", _facing_sign > 0.0)
		pixel_visual.set_psychic_frozen(true)
	return true


func _clear_psychic_freeze() -> void:
	_psychic_freeze_remaining = 0.0
	if pixel_visual != null:
		pixel_visual.set_psychic_frozen(false)


func receive_enemy_hit(source_position: Vector3, hit: CombatHit) -> bool:
	if _dead or _developer_inspection_enabled or is_transition_running():
		return false
	if not health.damage(hit):
		return false
	_cancel_active_attack(true)
	_attack_lock_remaining = maxf(_attack_lock_remaining, combat.hurt_duration)
	# Present the authored reaction immediately, before feedback pauses the frame.
	# Movement remains live; the existing hurt attack lock owns recovery timing.
	if health.current > 0 and not is_control_locked():
		_hurt_visual_remaining = combat.hurt_duration
		if pixel_visual != null:
			pixel_visual.set_state("hurt", true)
			pixel_visual.tick_authored_state(0.0, "hurt", _facing_sign > 0.0)
	damage_received.emit(source_position)
	if health.current == 0:
		kill()
	return true


func receive_knockback_hit(source_position: Vector3, hit: CombatHit, impulse: float,
		deceleration := 24.0) -> bool:
	# Damage deduplication also owns the impulse: repeated contact cannot shove again.
	if not receive_enemy_hit(source_position, hit):
		return false
	if _dead or is_control_locked(): return true
	_dash_remaining = 0.0
	horizontal_speed = 0.0
	_knockback_speed = impulse
	_knockback_deceleration = maxf(1.0, deceleration)
	velocity.x = impulse
	velocity.y = maxf(velocity.y, 3.0)
	floor_snap_length = 0.0
	player_handgun.cancel_reload()
	return true


func use_quick_item(slot: int) -> bool:
	if _dead or is_control_locked() or is_transition_running() or _developer_inspection_enabled or healing_remaining > 0.0:
		return false
	if slot < 0 or slot >= inventory.quick_slots.size():
		return false
	var item_id := inventory.quick_slots[slot]
	var item := ItemCatalog.definition(item_id)
	if item == null or inventory.count(item_id) <= 0 or health.current >= health.maximum:
		return false
	var before := health.current
	if not health.heal(item.healing):
		return false
	inventory.consume(item_id)
	_cancel_active_attack(true)
	healing_remaining = item.use_duration
	_attack_lock_remaining = maxf(_attack_lock_remaining, item.use_duration)
	last_healing_amount = health.current - before
	healing_used.emit(item_id, last_healing_amount)
	return true


func capture_state() -> Dictionary:
	return {
		"health": health.to_dictionary(),
		"inventory": inventory.to_dictionary(),
		"handgun_ammo": {"loaded": player_handgun.loaded_rounds},
		"weapons": Array(_owned_weapon_ids),
		"equipped_weapon": String(_equipped_weapon_id),
		"abilities": Array(_active_abilities),
		"facing": _facing_sign,
	}


func restore_state(data: Dictionary) -> void:
	_clear_psychic_freeze()
	_hurt_visual_remaining = 0.0
	_knockback_speed = 0.0
	release_ground_hold()
	health.reset(int(data.health.maximum), int(data.health.current))
	inventory.restore(data.inventory)
	var weapons: Array[StringName] = []
	weapons.assign(data.weapons)
	configure_weapon_ownership(weapons, StringName(data.equipped_weapon))
	if data.has("handgun_ammo"):
		player_handgun.set_loaded_rounds(int(data.handgun_ammo.loaded))
	elif owns_weapon(PlayerWeapon.HANDGUN):
		# Pre-ammo saves owned an unlimited gun. Give one initial 30-round supply;
		# every new snapshot records the exact remaining rounds thereafter.
		player_handgun.grant_initial_ammo(30)
	else:
		player_handgun.set_loaded_rounds(0)
	_facing_sign = float(data.get("facing", 1.0))
	_attack_lock_remaining = 0.0
	healing_remaining = 0.0


func set_developer_inspection_enabled(enabled: bool) -> void:
	if _developer_inspection_enabled == enabled:
		return
	_developer_inspection_enabled = enabled
	_clear_psychic_freeze()
	_hurt_visual_remaining = 0.0
	_knockback_speed = 0.0
	release_ground_hold()
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	_dash_remaining = 0.0
	_transition_run_remaining = 0.0
	_transition_run_speed = 0.0
	_attack_remaining = 0.0
	_melee_hit_targets.clear()
	_active_attack_weapon_id = &""
	_active_attack_aim_up = false
	_pending_weapon_id = &""
	_wall_sliding = false
	floor_snap_length = 0.0 if enabled else movement.floor_snap_length
	_apply_developer_inspection_collision()
	set_physics_process(true)
	if pixel_visual != null:
		pixel_visual.set_state("idle", true)
	movement_reset.emit()


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
	_melee_hit_targets.clear()
	_active_attack_weapon_id = &""
	_active_attack_aim_up = false
	_pending_weapon_id = &""
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
	if is_dashing() or is_control_locked() or _attack_lock_remaining > 0.0:
		_cancel_active_attack(true)
		return
	# Gun recovery follows the weapon's cooldown. Knife contact and swing
	# duration must neither delay a shot nor impose a second firing gate.
	if _active_attack_weapon_id == PlayerWeapon.HANDGUN:
		if player_handgun.is_recovering():
			return
		_finish_active_attack()
	if (
		Input.is_action_just_pressed("attack") and _attack_remaining <= 0.0
		and _equipped_weapon_id == PlayerWeapon.KNIFE
	):
		_active_attack_weapon_id = PlayerWeapon.KNIFE
		_active_attack_aim_up = false
		_attack_remaining = attack_duration
		_melee_hit_targets.clear()
		_melee_hit = CombatHit.new(knife_attack.damage, &"knife", global_position)
		melee_swung.emit(global_position)
	if _attack_remaining <= 0.0:
		_apply_pending_weapon()
		return
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	if is_melee_contact_active():
		_perform_melee_hit()
	if _attack_remaining <= 0.0:
		_finish_active_attack()


func _fire_handgun_from_input() -> void:
	# Movement, animation frame, and mouse aim resolve first, within this same
	# physics tick. Jump + fire therefore uses the new pose's real barrel.
	if (
		_dead or is_control_locked() or is_dashing() or is_attacking() or _attack_lock_remaining > 0.0
		or _equipped_weapon_id != PlayerWeapon.HANDGUN
		or not Input.is_action_just_pressed("attack")
	):
		return
	if not player_handgun.can_fire():
		if player_handgun.try_empty_trigger():
			handgun_empty_triggered.emit(global_position)
		return
	_active_attack_weapon_id = PlayerWeapon.HANDGUN
	_active_attack_aim_up = Input.is_action_pressed("aim_up")
	var projectile := player_handgun.fire(_facing_sign, _active_attack_aim_up, self)
	if projectile != null:
		projectile_fired.emit(projectile)
	else:
		_finish_active_attack()


func _finish_active_attack() -> void:
	_attack_remaining = 0.0
	_melee_hit_targets.clear()
	_active_attack_weapon_id = &""
	_active_attack_aim_up = false
	_apply_pending_weapon()


func _cancel_active_attack(apply_pending: bool) -> void:
	_attack_remaining = 0.0
	_melee_hit_targets.clear()
	_active_attack_weapon_id = &""
	_active_attack_aim_up = false
	if apply_pending:
		_apply_pending_weapon()


func _perform_melee_hit() -> void:
	for candidate in get_tree().get_nodes_in_group("melee_target") + get_tree().get_nodes_in_group("breakable_cover"):
		if not candidate is Node3D or not candidate.has_method("receive_melee_hit"):
			continue
		# Defeated actors remain in the group during their death presentation.
		# They reject damage, so they must not report another successful hit.
		if candidate.has_method("is_defeated") and candidate.call("is_defeated"):
			continue
		var target := candidate as Node3D
		if target.get_instance_id() in _melee_hit_targets:
			continue
		var bounds := ENEMY_CONTACT.hurt_bounds(target)
		var forward_distance := (bounds.get_center().x - global_position.x) * _facing_sign
		if (
			forward_distance >= 0.0
			and developer_melee_bounds().intersects(bounds)
		):
			_melee_hit_targets.append(target.get_instance_id())
			if _melee_hit == null:
				_melee_hit = CombatHit.new(knife_attack.damage, &"knife", global_position)
			if candidate.call("receive_melee_hit", global_position, _melee_hit):
				attack_connected.emit(target)


func _resolve_stomp(previous_position: Vector3) -> void:
	if not _descending_before_slide or _dead or is_ground_held():
		return
	var start := Vector2(previous_position.x, previous_position.y - FEET_OFFSET_Y)
	var end := Vector2(global_position.x, feet_world_y())
	var target: Node3D
	var first_contact := 2.0
	var head_y := 0.0
	for candidate in get_tree().get_nodes_in_group("melee_target"):
		if not candidate.has_method("receive_stomp") or candidate.is_defeated():
			continue
		var bounds := ENEMY_CONTACT.stomp_bounds(candidate)
		var contact := ENEMY_CONTACT.stomp_crossing(start, end, bounds, 0.36)
		if contact >= 0.0 and contact < first_contact:
			target = candidate
			first_contact = contact
			head_y = bounds.end.y
	if target != null:
		global_position.y = head_y + FEET_OFFSET_Y
		target.receive_stomp(self)
		return
	# The solid body is lower than the drawn head and has a different centre.
	# An edge landing or short hop can miss the head plane but still land on
	# that body. Resolve the actual top contact instead of riding the enemy.
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y <= 0.7:
			continue
		var body := collision.get_collider() as Node3D
		if body != null and body.has_method("receive_stomp") and not body.is_defeated():
			body.receive_stomp(self)
			return


func _perform_ground_jump() -> void:
	if is_dashing():
		_finish_dash()
	ground_jump_started.emit()
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
	_knockback_speed = 0.0
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
	_knockback_speed = 0.0
	_dash_direction = signf(input_axis) if not is_zero_approx(input_axis) else _facing_sign
	_facing_sign = _dash_direction
	_dash_remaining = movement.dash_duration
	_dash_available = false
	_cancel_active_attack(true)
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
	if is_control_locked():
		return
	_update_weapon_presentation()
	if not _dead and _hurt_visual_remaining > 0.0:
		pixel_visual.tick_authored_state(delta, "hurt", _facing_sign > 0.0)
		return
	pixel_visual.tick(
		delta,
		is_on_floor(),
		horizontal_speed,
		velocity.y,
		is_attacking(),
		_dead,
		_facing_sign > 0.0,
		_double_jump_visual_remaining > 0.0,
		_wall_sliding,
		is_dashing(),
		is_dash_airborne(),
		player_handgun.is_retreating(horizontal_speed)
	)
	player_handgun.update_mouse_aim(_facing_sign)


func _update_weapon_selection_input() -> void:
	if Input.is_action_just_pressed("weapon_slot_1"):
		request_weapon(PlayerWeapon.KNIFE)
		return
	if Input.is_action_just_pressed("weapon_slot_2"):
		request_weapon(PlayerWeapon.HANDGUN)
		return
	if Input.is_action_just_pressed("weapon_cycle_next"):
		_cycle_weapon(1)
		return
	if Input.is_action_just_pressed("weapon_cycle_previous"):
		_cycle_weapon(-1)


func _cycle_weapon(direction: int) -> void:
	if _owned_weapon_ids.size() <= 1:
		return
	var cycle_from := (
		_pending_weapon_id
		if not _pending_weapon_id.is_empty()
		else _equipped_weapon_id
	)
	var current_index := _owned_weapon_ids.find(cycle_from)
	if current_index < 0:
		current_index = 0
	var next_index := posmod(current_index + direction, _owned_weapon_ids.size())
	request_weapon(_owned_weapon_ids[next_index])


func _apply_pending_weapon() -> void:
	if _pending_weapon_id.is_empty():
		return
	var requested_weapon := _pending_weapon_id
	_pending_weapon_id = &""
	if requested_weapon in _owned_weapon_ids:
		_equip_weapon(requested_weapon)


func _equip_weapon(weapon_id: StringName) -> void:
	if weapon_id == _equipped_weapon_id:
		_update_weapon_presentation()
		return
	_equipped_weapon_id = weapon_id
	_update_weapon_presentation()
	weapon_equipped.emit(_equipped_weapon_id)


func _update_weapon_presentation() -> void:
	if pixel_visual == null:
		return
	var presentation_aim_up := (
		_active_attack_aim_up
		if _active_attack_weapon_id == PlayerWeapon.HANDGUN
		else (
			_equipped_weapon_id == PlayerWeapon.HANDGUN
			and Input.is_action_pressed("aim_up")
		)
	)
	pixel_visual.set_weapon_presentation(
		_equipped_weapon_id,
		_active_attack_weapon_id,
		presentation_aim_up
	)
