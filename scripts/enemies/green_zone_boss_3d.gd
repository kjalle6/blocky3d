extends CharacterBody3D
## First boss prototype. The landing has NO marker, warning sound or warning phase.
signal defeated(impact_position: Vector3)
signal health_changed(current: int, maximum: int)
signal landed(impact_position: Vector3)
signal missile_fired(projectile: Node3D)
signal attack_started(attack: StringName)

enum State { IDLE, SALVO, JUMP, RECOVERY, SMOKE_ESCAPE, SPACE_CHARGE, DEFEATED }
enum Pattern { MIXED, MISSILES, JUMPS }

const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const LANDING_RING := preload("res://assets/art/vfx/boss/landing_ring.png")
const EXPLOSION := preload("res://assets/art/vfx/boss/explosion.png")
const SMOKE := preload("res://scripts/presentation/boss_smoke_burst_3d.gd")
const HURT_DURATION := 0.18
# Tube centers measured in the unflipped 72px Attack1 frames 1..6:
# top-left, bottom-left, top-middle, bottom-middle, top-right, bottom-right.
const SALVO_TUBES := [Vector2(23, 23), Vector2(26, 29), Vector2(28, 23),
	Vector2(31, 29), Vector2(33, 23), Vector2(36, 29)]
const SALVO_ELEVATIONS := [20.0, 16.0, 22.0, 18.0, 24.0, 20.0]
const SALVO_SPREAD := [-0.75, 0.45, -0.15, 0.75, -0.45, 0.15]
const SHEETS := {
	"hurt": preload("res://assets/art/green_zone/bosses/launcher/Hurt.png"),
	"idle": preload("res://assets/art/green_zone/bosses/launcher/Idle.png"),
	"aim": preload("res://assets/art/green_zone/bosses/launcher/Sneer.png"),
	"walk": preload("res://assets/art/green_zone/bosses/launcher/Walk.png"),
	"launch": preload("res://assets/art/green_zone/bosses/launcher/Attack1.png"),
	"close": preload("res://assets/art/green_zone/bosses/launcher/Attack3.png"),
	"jump": preload("res://assets/art/green_zone/bosses/launcher/Attack4.png"),
	"death": preload("res://assets/art/green_zone/bosses/launcher/Death.png"),
}
@export var combat: CombatProfile = preload("res://resources/combat/green_zone_boss.tres")
@export var enabled := true
@export var pattern := Pattern.MIXED
@export var minimum_x := 2.8
@export var maximum_x := 17.68
@export var gravity := 32.0
@export var jump_duration := 1.25
@export var recovery_duration := 1.6
@export var missile_cooldown := 5.0
@export var jump_cooldown := 6.5
@export var walk_speed := 2.6
@export var walk_acceleration := 10.0
@export var preferred_distance := 7.0
@export var reposition_duration := 0.65
@export var maximum_jump_distance := 14.0
@export var missile_attack_range := 18.0
@export var landing_radius := 2.8
@export var landing_height := 1.4
@export var landing_active_time := 0.16
@export var missile_speed := 11.0
@export_range(0.08, 0.3, 0.01) var missile_interval := 0.12
@export var launcher_aim_duration := 0.3
@export var stomp_head_height := 2.85
@export var smoke_escape_speed := 6.0
@export var smoke_escape_clearance := 9.0
@export var smoke_escape_timeout := 2.5
@export var smoke_punishment_duration := 1.5
@export var smoke_fade_tail := 0.6
@export var charge_trigger_distance := 4.0
@export var charge_windup := 0.22
@export var charge_speed := 10.0
@export var charge_distance := 2.4
@export var charge_cooldown := 4.0
@export var charge_recovery := 0.45
@export var charge_knockback := 24.0
@export var charge_knockback_deceleration := 32.0
@export var salvo_shove_distance := 2.2
@export var salvo_shove_cooldown := 0.6

var health := HealthState.new()
var state := State.IDLE
var phase_time := 0.0
var phase_remaining := 1.3
var landing_count := 0
var missiles_fired := 0
var jump_target_x := 0.0
var missile_cooldown_remaining := 0.0
var jump_cooldown_remaining := 0.0
var charge_cooldown_remaining := 0.0
var charges_started := 0
var salvo_shoves := 0
var salvo_shove_cooldown_remaining := 0.0
var _charge_direction := 1.0
var _charge_travel := 0.0
var _charge_hit: CombatHit
var _ranged_followup := false
var _landing_player_side := -1.0
var _body_reset_frames := 0
var _initial_transform: Transform3D
var _next_jump := false
var _recovery_from_jump := false
var _facing := -1.0
var _shot_index := 0
var _salvo_target := Vector3.ZERO
var _landing_hit: CombatHit
var _landing_remaining := 0.0
var _hurt_remaining := 0.0
var smoke_escapes := 0
var _escape_player: PlayerCharacter
var _escape_target_x := 0.0
var _escape_elapsed := 0.0
var _smoke_release_remaining := -1.0
var _smoke_vfx: Node3D
var _animation := ""
var _animation_time := 0.0
var _missile_scene: PackedScene

@onready var visual: Sprite3D = $PixelVisual
@onready var body_collision: CollisionShape3D = $BodyCollision

func _ready() -> void:
	_initial_transform = global_transform
	_missile_scene = load("res://scenes/projectiles/boss_missile.tscn") as PackedScene
	add_to_group("run_resettable")
	add_to_group("melee_target")
	health.changed.connect(func(current: int, maximum: int) -> void:
		health_changed.emit(current, maximum))
	reset_run()

func _physics_process(delta: float) -> void:
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	_sync_player_body_collision(player)
	if state == State.DEFEATED:
		velocity.y -= gravity * delta
		move_and_slide()
		_tick_animation("death", delta, false)
		return
	# Existing F11 inspection freezes the encounter; normal gameplay stays intact.
	if player == null or player.is_dead() or player.is_developer_inspection_enabled():
		if state == State.SMOKE_ESCAPE: _finish_smoke_escape()
		_release_escape_player()
		return
	_tick_smoke_hold(delta)
	phase_time += delta
	if enabled:
		missile_cooldown_remaining = maxf(0.0, missile_cooldown_remaining - delta)
		jump_cooldown_remaining = maxf(0.0, jump_cooldown_remaining - delta)
		charge_cooldown_remaining = maxf(0.0, charge_cooldown_remaining - delta)
		salvo_shove_cooldown_remaining = maxf(0.0, salvo_shove_cooldown_remaining - delta)
	if state == State.SPACE_CHARGE:
		_tick_space_charge(player, delta)
		return
	if state == State.SMOKE_ESCAPE:
		_tick_smoke_escape(delta)
		return
	if _landing_remaining > 0.0:
		_apply_landing_damage(player)
		_landing_remaining = maxf(0.0, _landing_remaining - delta)
	if enabled and state == State.IDLE and is_on_floor():
		_walk_to_range(player, delta)
	elif state != State.JUMP:
		velocity.x = 0.0
	velocity.y -= gravity * delta
	var was_jumping := state == State.JUMP
	move_and_slide()
	if was_jumping and is_on_floor() and velocity.y <= 0.0:
		_land(player)
		return
	if state == State.JUMP:
		_tick_animation("jump", delta, false)
		# Hold the airborne poses until physical contact, rather than walking in air.
		if _hurt_remaining <= 0.0:
			visual.frame = clampi(int(phase_time / jump_duration * 5.0), 1, 4)
		return
	if not enabled:
		_tick_animation("idle", delta)
		return
	match state:
		State.IDLE:
			_tick_animation("walk" if absf(velocity.x) > 0.1 and is_on_floor() else "idle", delta)
			phase_remaining -= delta
			if phase_remaining <= 0.0 and is_on_floor():
				_try_ready_attack(player)
		State.SALVO:
			_try_salvo_shove(player)
			if not player.is_dead(): _tick_salvo(delta)
		State.RECOVERY:
			if _recovery_from_jump and phase_time < 0.3:
				_tick_animation("jump", delta, false)
				if _hurt_remaining <= 0.0: visual.frame = visual.hframes - 1
			else:
				_tick_animation("close" if phase_time < 0.3 else "idle", delta, phase_time >= 0.3)
			phase_remaining -= delta
			if phase_remaining <= 0.0:
				state = State.IDLE
				phase_time = 0.0
				phase_remaining = reposition_duration

func _sync_player_body_collision(player: PlayerCharacter) -> void:
	if player == null: return
	if _body_reset_frames > 0:
		_body_reset_frames -= 1
		add_collision_exception_with(player)
		return
	if player.is_dead() or player.is_developer_inspection_enabled():
		add_collision_exception_with(player)
		return
	# Solid while supported by terrain, at any elevation. Leap/escape bodies
	# pass through so the boss lands on terrain and a captured player can fall.
	if not is_on_floor() or state in [State.JUMP, State.SMOKE_ESCAPE, State.DEFEATED]:
		add_collision_exception_with(player)
	elif _separate_landing_overlap(player):
		remove_collision_exception_with(player)

func _separate_landing_overlap(player: PlayerCharacter) -> bool:
	# An airborne boss can land across the player. Separate along the play
	# plane before restoring solidity; generic 3D overlap recovery can push Z.
	var boss_size := (body_collision.shape as BoxShape3D).size * body_collision.global_basis.get_scale()
	var player_collision := player.get_node("CollisionShape3D") as CollisionShape3D
	var player_size := (player_collision.shape as BoxShape3D).size * player_collision.global_basis.get_scale()
	var separation := (boss_size.x + player_size.x) * 0.5 + 0.01
	var offset := player.global_position.x - global_position.x
	if absf(offset) >= separation - 0.02 \
			or player.feet_world_y() >= body_collision.global_position.y + boss_size.y * 0.5 - 0.005 \
			or player.feet_world_y() + player_size.y <= body_collision.global_position.y - boss_size.y * 0.5:
		return true
	add_collision_exception_with(player)
	var side := signf(offset) if absf(offset) > 0.08 else _landing_player_side
	player.move_and_collide(Vector3(side * (separation - absf(offset)), 0, 0))
	var remaining := separation - (player.global_position.x - global_position.x) * side
	if remaining > 0.005:
		# Near a wall the player cannot be shoved through it; move the boss back.
		move_and_collide(Vector3(-side * remaining, 0, 0))
	# Defer re-enabling until these moved transforms are visible to both bodies.
	_body_reset_frames = 1
	return false

func _walk_to_range(player: PlayerCharacter, delta: float) -> void:
	var offset := player.global_position.x - global_position.x
	var direction := 0.0
	if absf(offset) > preferred_distance + 1.0:
		direction = signf(offset)
	elif absf(offset) < preferred_distance - 1.0:
		direction = -signf(offset)
		if absf(offset) < 0.1:
			direction = signf((minimum_x + maximum_x) * 0.5 - global_position.x)
		# At a wall, move back into the room instead of pushing into the boundary.
		if global_position.x + direction * 0.2 < minimum_x or global_position.x + direction * 0.2 > maximum_x:
			direction = -direction
	velocity.x = move_toward(velocity.x, direction * walk_speed, walk_acceleration * delta)
	velocity.x = clampf(velocity.x, (minimum_x - global_position.x) / delta,
		(maximum_x - global_position.x) / delta)
	if absf(velocity.x) > 0.1:
		_face(global_position.x + velocity.x)

func _try_ready_attack(player: PlayerCharacter) -> void:
	# Normal follow-camera play must see the attacker when a new attack starts.
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_in_frustum(global_position + Vector3.UP * 1.5):
		return
	var distance := absf(player.global_position.x - global_position.x)
	var can_missile := pattern != Pattern.JUMPS and missile_cooldown_remaining <= 0.0 and distance <= missile_attack_range
	var can_jump := pattern != Pattern.MISSILES and jump_cooldown_remaining <= 0.0 and distance <= maximum_jump_distance
	if _ranged_followup and can_missile:
		_prepare_salvo(player)
	elif can_jump and (_next_jump or not can_missile):
		_start_jump(player)
	elif can_missile:
		_prepare_salvo(player)

func _prepare_salvo(player: PlayerCharacter) -> void:
	var close := absf(player.global_position.x - global_position.x) < charge_trigger_distance
	var within_body_height := player.feet_world_y() < global_position.y + 2.35 \
		and player.feet_world_y() + 1.1 > global_position.y + 0.15
	if close and within_body_height:
		if charge_cooldown_remaining <= 0.0:
			_start_space_charge(player)
		# Otherwise keep backing away until there is room or the charge recharges.
		return
	_start_salvo(player)

func _start_space_charge(player: PlayerCharacter) -> void:
	state = State.SPACE_CHARGE
	phase_time = 0.0
	velocity.x = 0.0
	_face(player.global_position.x)
	_charge_direction = _facing
	_charge_travel = 0.0
	_charge_hit = CombatHit.new(combat.attack_damage, &"boss_charge", global_position)
	_ranged_followup = true
	charges_started += 1
	attack_started.emit(&"space_charge")

func _tick_space_charge(player: PlayerCharacter, delta: float) -> void:
	var active := phase_time >= charge_windup
	var step := minf(charge_speed * delta, charge_distance - _charge_travel) if active else 0.0
	velocity.x = clampf(_charge_direction * step / delta,
		(minimum_x - global_position.x) / delta, (maximum_x - global_position.x) / delta)
	velocity.y -= gravity * delta
	var previous_x := global_position.x
	move_and_slide()
	var travelled := absf(global_position.x - previous_x)
	_charge_travel += travelled
	_tick_animation("walk" if active else "idle", delta)
	if active and _try_charge_hit(player, previous_x):
		_finish_space_charge()
	elif active and (travelled < step * 0.5 or _charge_travel >= charge_distance - 0.001):
		_finish_space_charge()

func _try_charge_hit(player: PlayerCharacter, previous_x: float) -> bool:
	# Swept front contact, committed facing and body-height overlap. Crossing
	# behind or jumping above the charge misses; head landings still use smoke.
	var forward := (player.global_position.x - previous_x) * _charge_direction
	var travel := absf(global_position.x - previous_x)
	var feet := player.feet_world_y()
	if forward < -0.36 or forward > travel + 1.95 \
			or feet > global_position.y + 2.35 or feet + 1.1 < global_position.y + 0.15:
		return false
	if not _body_hit_unobstructed(player): return false
	return player.receive_knockback_hit(global_position, _charge_hit,
		_charge_direction * charge_knockback, charge_knockback_deceleration)

func _body_hit_unobstructed(player: PlayerCharacter) -> bool:
	var excluded: Array[RID] = [get_rid(), player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP,
		player.global_position, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _try_salvo_shove(player: PlayerCharacter) -> void:
	# A separate close-contact defense runs alongside the complete salvo.
	# Do not change facing, target, shot index, animation clock or attack state.
	if salvo_shove_cooldown_remaining > 0.0 or not is_on_floor() or player.is_control_locked():
		return
	var offset := player.global_position.x - global_position.x
	var feet := player.feet_world_y()
	if absf(offset) > salvo_shove_distance or feet > global_position.y + 2.35 \
			or feet + 1.1 < global_position.y + 0.15:
		return
	if not _body_hit_unobstructed(player): return
	var direction := signf(offset) if absf(offset) > 0.05 else _facing
	var hit := CombatHit.new(combat.attack_damage, &"boss_salvo_shove", global_position)
	if player.receive_knockback_hit(global_position, hit,
			direction * charge_knockback, charge_knockback_deceleration):
		salvo_shoves += 1
		salvo_shove_cooldown_remaining = salvo_shove_cooldown

func _finish_space_charge() -> void:
	charge_cooldown_remaining = charge_cooldown
	_charge_hit = null
	state = State.RECOVERY
	_recovery_from_jump = false
	velocity.x = 0.0
	phase_time = 0.3
	phase_remaining = charge_recovery

func _start_salvo(player: PlayerCharacter) -> void:
	_ranged_followup = false
	state = State.SALVO
	phase_time = 0.0
	_shot_index = 0
	velocity.x = 0.0
	_face(player.global_position.x)
	# One committed target for the whole salvo, including airborne players.
	_salvo_target = player.global_position + Vector3.UP * 0.35
	_next_jump = true
	attack_started.emit(&"missiles")

func _start_jump(player: PlayerCharacter) -> void:
	var offset := player.global_position.x - global_position.x
	if absf(offset) > 0.05: _landing_player_side = signf(offset)
	state = State.JUMP
	_sync_player_body_collision(player)
	phase_time = 0.0
	jump_target_x = clampf(player.global_position.x,
		maxf(minimum_x, global_position.x - maximum_jump_distance),
		minf(maximum_x, global_position.x + maximum_jump_distance))
	_face(jump_target_x)
	velocity.x = (jump_target_x - global_position.x) / jump_duration
	velocity.y = gravity * jump_duration * 0.5
	_landing_hit = CombatHit.new(combat.attack_damage, &"boss_landing", global_position)
	_next_jump = false
	attack_started.emit(&"jump")

func _land(player: PlayerCharacter) -> void:
	velocity = Vector3.ZERO
	landing_count += 1
	_landing_remaining = landing_active_time
	_landing_hit.source_position = global_position
	# Start at the expanded ring frames so the footprint is visible at impact.
	EFFECT.spawn(get_parent(), global_position + Vector3.UP * landing_height * 0.5,
		LANDING_RING, 72, landing_radius * 2.0 / 72.0,
		landing_height / (landing_radius * 2.0), 3)
	_apply_landing_damage(player)
	landed.emit(global_position)
	_begin_recovery()

func _apply_landing_damage(player: PlayerCharacter) -> void:
	if _landing_hit == null or player.is_dead():
		return
	# Compare the player's actual body bounds against a ground-level impact box.
	var feet := player.feet_world_y()
	if absf(player.global_position.x - global_position.x) <= landing_radius + 0.36 \
			and feet <= global_position.y + landing_height \
			and feet + 1.1 >= global_position.y:
		player.receive_enemy_hit(global_position, _landing_hit)

func _begin_recovery() -> void:
	_recovery_from_jump = state == State.JUMP
	if _recovery_from_jump:
		jump_cooldown_remaining = jump_cooldown
	else:
		missile_cooldown_remaining = missile_cooldown
	state = State.RECOVERY
	velocity.x = 0.0
	phase_time = 0.0
	phase_remaining = recovery_duration

func _face(target_x: float) -> void:
	if absf(target_x - global_position.x) > 0.05:
		_facing = signf(target_x - global_position.x)
	visual.flip_h = _facing < 0.0

func _tick_salvo(delta: float) -> void:
	if phase_time < launcher_aim_duration:
		_tick_animation("aim", delta, false)
		if _hurt_remaining <= 0.0:
			visual.frame = mini(5, int(phase_time / launcher_aim_duration * 6.0))
		return
	_tick_animation("launch", delta, false)
	while _shot_index < SALVO_TUBES.size() and phase_time >= launcher_aim_duration + _shot_index * missile_interval:
		if _hurt_remaining <= 0.0: visual.frame = _shot_index + 1
		_fire_missile()
		_shot_index += 1
	if _hurt_remaining <= 0.0:
		visual.frame = _shot_index
		if phase_time >= launcher_aim_duration + SALVO_TUBES.size() * missile_interval:
			visual.frame = 7
	if phase_time >= salvo_duration():
		_begin_recovery()

func salvo_duration() -> float:
	return launcher_aim_duration + (SALVO_TUBES.size() + 1) * missile_interval

func muzzle_position(shot_index := -1) -> Vector3:
	var tube: Vector2 = SALVO_TUBES[clampi(_shot_index if shot_index < 0 else shot_index, 0, 5)]
	var pixel_offset := Vector3((tube.x - 36.0) * _facing, 36.0 - tube.y, 0.0)
	var point := visual.to_global(pixel_offset * visual.pixel_size)
	# The art is in front of the play plane; projectile collision stays on it.
	return Vector3(point.x, point.y, global_position.z)

func _fire_missile() -> void:
	var missile := _missile_scene.instantiate() as HandgunProjectile3D
	missile.speed = missile_speed
	missile.maximum_distance = 32.0
	get_parent().add_child(missile)
	missile.global_position = muzzle_position(_shot_index)
	var elevation := deg_to_rad(SALVO_ELEVATIONS[_shot_index])
	var launch_direction := Vector3(cos(elevation) * _facing, sin(elevation), 0.0)
	var target := _salvo_target + Vector3(SALVO_SPREAD[_shot_index] * _facing, 0, 0)
	missile.launch_at(target, launch_direction, self,
		CombatHit.new(combat.attack_damage, &"boss_missile", missile.global_position))
	missiles_fired += 1
	missile_fired.emit(missile)

func _tick_animation(next: String, delta: float, loop := true) -> void:
	if _animation != next:
		_animation = next
		_animation_time = 0.0
	_animation_time += delta
	# Hurt changes presentation only. The attack clock and underlying animation
	# keep advancing, so hits cannot restart a salvo or stall a jump.
	if _hurt_remaining > 0.0 and next != "death":
		visual.texture = SHEETS.hurt
		visual.hframes = 2
		visual.frame = mini(1, int((HURT_DURATION - _hurt_remaining) / HURT_DURATION * 2.0))
		return
	visual.texture = SHEETS[next]
	visual.hframes = visual.texture.get_width() / 72
	var rate := 10.0 if next == "idle" else 12.0
	if next == "walk" and state in [State.SMOKE_ESCAPE, State.SPACE_CHARGE]: rate = 24.0
	var next_frame := int(_animation_time * rate)
	visual.frame = next_frame % visual.hframes if loop else mini(next_frame, visual.hframes - 1)

func combat_hurt_bounds() -> Rect2:
	return Rect2(global_position.x - 1.65, global_position.y + 0.08, 3.3, 2.95)

func receive_melee_hit(source: Vector3, hit: CombatHit = null) -> bool:
	if is_defeated(): return false
	if hit == null:
		hit = CombatHit.new(25, &"knife", source)
	if hit.kind == &"stomp": return false
	if not health.damage(hit, combat): return false
	_hurt_remaining = HURT_DURATION
	if health.current == 0:
		_release_escape_player()
		_charge_hit = null
		_ranged_followup = false
		state = State.DEFEATED
		velocity = Vector3.ZERO
		_landing_remaining = 0.0
		_landing_hit = null
		set_deferred("collision_layer", 0)
		for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
			if projectile.get_parent() == get_parent(): projectile.reset_run()
		EFFECT.spawn(get_parent(), global_position + Vector3.UP * 1.5, EXPLOSION, 48, 0.06)
		defeated.emit(global_position)
	return true

func receive_projectile_hit(source: Vector3, hit: CombatHit = null) -> bool:
	return receive_melee_hit(source, hit)

func receive_stomp(player: PlayerCharacter) -> void:
	if is_defeated() or state == State.SMOKE_ESCAPE or player.is_dead():
		return
	# Only the descending head-contact path may deploy smoke. A hit, touch,
	# upward crossing or unrelated callback must never capture the player.
	if not player.was_descending_before_slide(): return
	if absf(player.feet_world_y() - global_position.y - stomp_head_height) > 0.12: return
	if absf(player.global_position.x - global_position.x) >= 1.95: return
	if not player.begin_ground_hold(self, smoke_escape_timeout + smoke_punishment_duration + 0.2):
		return
	_escape_player = player
	_escape_elapsed = 0.0
	_smoke_release_remaining = -1.0
	# A head landing cancels the current attack into this defensive escape.
	if state == State.SALVO:
		missile_cooldown_remaining = maxf(missile_cooldown_remaining, missile_cooldown)
	elif state == State.JUMP:
		jump_cooldown_remaining = maxf(jump_cooldown_remaining, jump_cooldown)
	elif state == State.SPACE_CHARGE:
		charge_cooldown_remaining = charge_cooldown
	_charge_hit = null
	_ranged_followup = false
	state = State.SMOKE_ESCAPE
	_sync_player_body_collision(player)
	_landing_remaining = 0.0
	_landing_hit = null
	velocity.y = minf(velocity.y, 0.0)
	var left_room := player.global_position.x - minimum_x
	var right_room := maximum_x - player.global_position.x
	var direction := signf(global_position.x - player.global_position.x)
	if is_zero_approx(direction):
		direction = 1.0 if right_room >= left_room else -1.0
	if (direction > 0.0 and right_room < smoke_escape_clearance + 0.4) \
			or (direction < 0.0 and left_room < smoke_escape_clearance + 0.4):
		direction = 1.0 if right_room >= left_room else -1.0
	_escape_target_x = clampf(player.global_position.x + direction * (smoke_escape_clearance + 0.4),
		minimum_x, maximum_x)
	_face(_escape_target_x)
	if is_instance_valid(_smoke_vfx): _smoke_vfx.queue_free()
	_smoke_vfx = SMOKE.spawn(get_parent(), Vector3(player.global_position.x, player.feet_world_y(), 0),
		smoke_escape_timeout + smoke_punishment_duration + 0.2, player)
	smoke_escapes += 1


func _tick_smoke_escape(delta: float) -> void:
	if not is_instance_valid(_escape_player) or not _escape_player.is_ground_held():
		_finish_smoke_escape()
		return
	_escape_elapsed += delta
	var offset := _escape_target_x - global_position.x
	velocity.x = clampf(offset / delta, -smoke_escape_speed, smoke_escape_speed)
	velocity.y -= gravity * delta
	move_and_slide()
	_tick_animation("walk" if is_on_floor() else "jump", delta)
	var clear := absf(global_position.x - _escape_player.global_position.x) >= smoke_escape_clearance
	if clear and _escape_player.is_on_floor() and is_on_floor():
		_finish_smoke_escape(true)
	elif _escape_elapsed >= smoke_escape_timeout:
		_finish_smoke_escape()


func _tick_smoke_hold(delta: float) -> void:
	if _escape_player == null:
		return
	if not is_instance_valid(_escape_player) or not _escape_player.is_ground_held():
		_release_escape_player()
		return
	if _smoke_release_remaining >= 0.0:
		_smoke_release_remaining -= delta
		if _smoke_release_remaining <= 0.0:
			_release_escape_player(false)


func _release_escape_player(clear_smoke := true) -> void:
	if is_instance_valid(_escape_player):
		_escape_player.release_ground_hold(self)
	_escape_player = null
	_smoke_release_remaining = -1.0
	if clear_smoke:
		if is_instance_valid(_smoke_vfx):
			_smoke_vfx.queue_free()
		_smoke_vfx = null


func _finish_smoke_escape(counterattack := false) -> void:
	velocity.x = 0.0
	state = State.RECOVERY
	_recovery_from_jump = false
	phase_time = 0.3
	phase_remaining = reposition_duration
	if not counterattack:
		_release_escape_player()
		return
	# Clearing the player ends the retreat, not the punishment. Keep the
	# player vulnerable through the counterattack, then leave fading wisps.
	_smoke_release_remaining = smoke_punishment_duration
	if is_instance_valid(_smoke_vfx):
		_smoke_vfx.call("finish", smoke_punishment_duration + smoke_fade_tail)
	var camera := get_viewport().get_camera_3d()
	if not enabled or (camera != null and not camera.is_position_in_frustum(global_position + Vector3.UP * 1.5)):
		return
	# This defensive response can counter even an interrupted, recharging
	# attack. Finishing it starts that attack's normal full cooldown again.
	if pattern == Pattern.JUMPS:
		_start_jump(_escape_player)
	else:
		_start_salvo(_escape_player)


func _exit_tree() -> void:
	_release_escape_player()

func is_defeated() -> bool:
	return state == State.DEFEATED

func reset_run() -> void:
	# Let reset transforms reach the physics server before this pair is solid.
	_body_reset_frames = 2
	_landing_player_side = -1.0
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player != null: add_collision_exception_with(player)
	_release_escape_player()
	smoke_escapes = 0
	_escape_elapsed = 0.0
	global_transform = _initial_transform
	velocity = Vector3.ZERO
	state = State.IDLE
	phase_time = 0.0
	phase_remaining = 1.3
	_next_jump = false
	_recovery_from_jump = false
	missile_cooldown_remaining = 0.0
	jump_cooldown_remaining = 0.0
	charge_cooldown_remaining = 0.0
	charges_started = 0
	salvo_shoves = 0
	salvo_shove_cooldown_remaining = 0.0
	_charge_hit = null
	_charge_travel = 0.0
	_ranged_followup = false
	_landing_hit = null
	_landing_remaining = 0.0
	_hurt_remaining = 0.0
	_animation = ""
	landing_count = 0
	missiles_fired = 0
	body_collision.set_deferred("disabled", false)
	collision_layer = 1
	health.reset(combat.maximum_hp)
	_facing = -1.0
	visual.flip_h = true
	visual.modulate = Color.WHITE
	_tick_animation("idle", 0.0)

func set_pattern(value: int) -> void:
	pattern = value as Pattern

func set_enabled(value: bool) -> void:
	enabled = value

func state_name() -> String:
	return State.keys()[state]
