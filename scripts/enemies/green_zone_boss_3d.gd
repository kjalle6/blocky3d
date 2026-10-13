extends CharacterBody3D
## First boss prototype. The landing has NO marker, warning sound or warning phase.
signal defeated(impact_position: Vector3)
signal health_changed(current: int, maximum: int)
signal landed(impact_position: Vector3)
signal missile_fired(projectile: Node3D)
signal attack_started(attack: StringName)
## Emitted once per fight when health first falls to phase_two_health_fraction.
signal phase_changed(new_phase: int)
## A charge or salvo shove that actually knocked the player back.
signal shoved(impact_position: Vector3)
## The head-landing defense released its smoke and grabbed the player.
signal smoke_vented(world_position: Vector3)
## The lob's canisters left the pod, once per lob.
signal firebombs_released(origin: Vector3)

enum State { IDLE, SALVO, JUMP, RECOVERY, SMOKE_ESCAPE, SPACE_CHARGE, DEFEATED, LOB }
enum Pattern { MIXED, MISSILES, JUMPS, FIREBOMBS }

const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const LANDING_RING := preload("res://assets/art/vfx/boss/landing_ring_large.png")
const LANDING_DUST := preload("res://assets/art/vfx/boss/landing_dust.png")
const LANDING_DEBRIS := preload("res://assets/art/vfx/boss/smoke_puff_c.png")
## The boss smoke's palest shade: thrown-up dust, not snow, against the night.
const LANDING_DUST_SHADE := Color("#a0afaa")
const EXPLOSION := preload("res://assets/art/vfx/boss/explosion.png")
const SMOKE := preload("res://scripts/presentation/boss_smoke_burst_3d.gd")
const FIREBOMB := preload("res://scripts/projectiles/boss_firebomb_3d.gd")
const DECK_LAYER := 64
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
	"lob": preload("res://assets/art/green_zone/bosses/launcher/Attack2.png"),
	"death": preload("res://assets/art/green_zone/bosses/launcher/Death.png"),
}
@export var combat: CombatProfile = preload("res://resources/combat/green_zone_boss.tres")
## Shown on the boss bar and the encounter's reveal.
@export var display_name := "S.T.O.M.P."
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
## Camera jolt when the boss lands: strength 1 reaches the camera's shake_pixels.
@export_range(0.0, 2.0, 0.05) var landing_shake := 0.7
@export_range(0.0, 1.0, 0.05) var landing_shake_time := 0.35
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
## The fight's second phase starts when health first falls to this fraction.
@export_range(0.0, 1.0, 0.05) var phase_two_health_fraction := 0.5
@export_group("Pursuit")
## Arena-only leap onto the surface the player stands on. It is off by default
## so the flat Boss Test Lab keeps its accepted tuning.
@export var chase_enabled := false
@export var chase_cooldown := 3.0
@export var chase_rise_threshold := 2.0
@export var maximum_chase_rise := 12.0
@export var chase_clearance := 1.5
## A chase leap may start while the boss is below the camera: it rises into view
## before it lands. Missiles and attack leaps still need it on screen to start.
@export var chase_from_off_screen := true
@export_group("Firebombs")
## Lob incendiary canisters that leave burning patches. Off by default so the
## flat Boss Test Lab keeps its accepted attack mix; its F1 test pattern still lobs.
@export var firebomb_enabled := false
@export var firebomb_cooldown := 8.0
@export_range(1, 6, 1) var firebombs_per_lob := 2
## Horizontal gap between the canisters of one lob.
@export var firebomb_spread := 4.2
@export var firebomb_range := 22.0
@export var firebomb_patch_width := 3.84
@export var firebomb_burn_time := 30.0
@export var firebomb_damage := 25
## Seconds the player may stand on ordinary ground before the boss lobs at
## them regardless of the cooldown. Decks and pass-up ledges do not count.
@export var ground_camp_time := 3.0
@export var lob_duration := 0.6
@export var lob_release_time := 0.32
@export_group("")

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
var chase_cooldown_remaining := 0.0
var chase_leaps := 0
var phase := 1
var firebomb_cooldown_remaining := 0.0
var lobs_started := 0
var ground_punishes := 0
var ground_time := 0.0
var _next_lob := false
var _noticing := false
var _lob_released := false
var _lob_targets: Array[Vector3] = []
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
var _chase_jump := false
var _jump_target_y := 0.0
var _jump_total_time := 1.25
# Bodies in the "boss_pass_up" group are ignored while a leap rises. Each one
# collides again once the descending boss is above it, unless it is higher
# than the surface the leap aims for.
var _pass_up_bodies: Array[PhysicsBody3D] = []
var _pass_up_tops: Dictionary = {}

@onready var visual: Sprite3D = $PixelVisual
@onready var body_collision: CollisionShape3D = $BodyCollision

func _ready() -> void:
	_initial_transform = global_transform
	_missile_scene = load("res://scenes/projectiles/boss_missile.tscn") as PackedScene
	add_to_group("run_resettable")
	add_to_group("mechanical")
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
		chase_cooldown_remaining = maxf(0.0, chase_cooldown_remaining - delta)
		firebomb_cooldown_remaining = maxf(0.0, firebomb_cooldown_remaining - delta)
		if _lobs_allowed():
			# Standing on the ground builds up; time up in the structure drains it.
			ground_time = ground_time + delta if _player_on_ground(player) \
				else maxf(0.0, ground_time - delta * 2.0)
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
	if was_jumping and not _pass_up_bodies.is_empty() and velocity.y <= 0.0:
		_settle_pass_up()
	move_and_slide()
	if was_jumping and is_on_floor() and velocity.y <= 0.0:
		_land(player)
		return
	if state == State.JUMP:
		_tick_animation("jump", delta, false)
		# Hold the airborne poses until physical contact, rather than walking in air.
		if _hurt_remaining <= 0.0:
			visual.frame = clampi(int(phase_time / _jump_total_time * 5.0), 1, 4)
		return
	if not enabled:
		# An encounter's entry beat can hold the swivelled launcher on screen.
		_tick_animation("aim" if _noticing else "idle", delta, not _noticing)
		return
	match state:
		State.IDLE:
			_tick_animation("walk" if absf(velocity.x) > 0.1 and is_on_floor() else "idle", delta)
			phase_remaining -= delta
			# A player camping on the ground is flamed whenever the boss is free,
			# ignoring both the lob cooldown and the reposition pause.
			if is_on_floor() and _ground_punish_ready(player) and _on_screen():
				_start_lob(player, true)
			elif phase_remaining <= 0.0 and is_on_floor():
				_try_ready_attack(player)
		State.LOB:
			_tick_lob(player, delta)
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
	var camera := get_viewport().get_camera_3d()
	var on_screen := camera == null or camera.is_position_in_frustum(global_position + Vector3.UP * 1.5)
	if (on_screen or chase_from_off_screen) and _try_chase(player):
		return
	# Normal follow-camera play must see the attacker when a new attack starts.
	if not on_screen:
		return
	var distance := absf(player.global_position.x - global_position.x)
	var can_missile := pattern in [Pattern.MIXED, Pattern.MISSILES] \
		and missile_cooldown_remaining <= 0.0 and distance <= missile_attack_range
	var can_jump := pattern in [Pattern.MIXED, Pattern.JUMPS] \
		and jump_cooldown_remaining <= 0.0 and distance <= maximum_jump_distance
	var can_lob := _lobs_allowed() and pattern in [Pattern.MIXED, Pattern.FIREBOMBS] \
		and firebomb_cooldown_remaining <= 0.0 and distance <= firebomb_range
	if pattern == Pattern.FIREBOMBS:
		if can_lob: _start_lob(player)
	elif _ranged_followup and can_missile:
		_prepare_salvo(player)
	elif can_lob and (_next_lob or not (can_missile or can_jump)):
		_start_lob(player)
	elif can_jump and (_next_jump or not can_missile):
		_start_jump(player)
	elif can_missile:
		_prepare_salvo(player)

func _on_screen() -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or camera.is_position_in_frustum(global_position + Vector3.UP * 1.5)

func _lobs_allowed() -> bool:
	return firebomb_enabled or pattern == Pattern.FIREBOMBS

func _ground_punish_ready(player: PlayerCharacter) -> bool:
	return _lobs_allowed() and ground_time >= ground_camp_time and player.is_on_floor() \
		and absf(player.global_position.x - global_position.x) <= firebomb_range

## Standing on terrain that is not a deck or a pass-up ledge.
func _player_on_ground(player: PlayerCharacter) -> bool:
	if player == null or not player.is_on_floor() or player.is_dead():
		return false
	var hit := _surface_under(player)
	return not hit.is_empty() and not (hit.collider as Node).is_in_group("boss_pass_up")

func _surface_under(player: PlayerCharacter) -> Dictionary:
	var feet := Vector3(player.global_position.x, player.feet_world_y(), 0)
	var excluded: Array[RID] = [get_rid(), player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.1, feet + Vector3.DOWN * 0.4,
		1 | DECK_LAYER, excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray)

func _start_lob(player: PlayerCharacter, punish := false) -> void:
	state = State.LOB
	phase_time = 0.0
	velocity.x = 0.0
	_face(player.global_position.x)
	_lob_released = false
	_next_lob = false
	lobs_started += 1
	if punish:
		ground_punishes += 1
		ground_time = 0.0
	# Like the missiles, the lob commits to where the player stands when it starts.
	var under := _surface_under(player)
	var base := Vector3(player.global_position.x, under.position.y if not under.is_empty() else player.feet_world_y(), 0)
	var side := signf(player.velocity.x)
	if absf(player.velocity.x) < 0.5:
		side = signf((minimum_x + maximum_x) * 0.5 - player.global_position.x)
	if is_zero_approx(side): side = 1.0
	_lob_targets = [base]
	for index in range(1, firebombs_per_lob):
		var x := clampf(base.x + side * firebomb_spread * index, minimum_x, maximum_x)
		_lob_targets.append(Vector3(x, base.y, 0))
	attack_started.emit(&"firebomb")

func _tick_lob(_player: PlayerCharacter, delta: float) -> void:
	_tick_animation("lob", delta, false)
	if not _lob_released and phase_time >= lob_release_time:
		_lob_released = true
		# The tilted pod's mouth, mirrored with facing.
		var origin := global_position + Vector3(_facing * 0.6, 2.9, 0)
		for index in _lob_targets.size():
			var target := _lob_targets[index]
			var flight := clampf(0.85 + absf(target.x - origin.x) * 0.035 + index * 0.12, 0.85, 1.6)
			FIREBOMB.launch(get_parent(), origin, target, flight, gravity, firebomb_patch_width,
				firebomb_burn_time, firebomb_damage, lobs_started * 3 + index)
		firebombs_released.emit(origin)
	if phase_time >= lob_duration:
		_begin_recovery()

func _try_chase(player: PlayerCharacter) -> bool:
	if not chase_enabled or pattern == Pattern.MISSILES or chase_cooldown_remaining > 0.0:
		return false
	var landing := _find_chase_landing(player)
	if landing.is_empty():
		return false
	_start_jump(player, landing)
	return true

## The surface the player stands on, or the highest one in reach below them,
## with the landing spot kept far enough from its ends for the whole body.
func _find_chase_landing(player: PlayerCharacter) -> Dictionary:
	if not player.is_on_floor() or player.is_control_locked():
		return {}
	var rise := player.feet_world_y() - global_position.y
	if rise < chase_rise_threshold or absf(player.global_position.x - global_position.x) > maximum_jump_distance:
		return {}
	var excluded: Array[RID] = [get_rid(), player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(player.global_position.x, global_position.y + minf(rise, maximum_chase_rise) + 0.3, 0),
		Vector3(player.global_position.x, global_position.y + chase_rise_threshold, 0),
		collision_mask, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return {}
	var half_body := (body_collision.shape as BoxShape3D).size.x * 0.5 + 0.1
	var span := _surface_span(hit, half_body)
	if span.y - span.x < half_body * 2.0:
		return {}
	var target_x := clampf(clampf(player.global_position.x, span.x + half_body, span.y - half_body),
		minimum_x, maximum_x)
	if absf(target_x - global_position.x) > maximum_jump_distance:
		return {}
	return {"x": target_x, "top": hit.position.y}

func _surface_span(hit: Dictionary, half_body: float) -> Vector2:
	var fallback := Vector2(hit.position.x - half_body, hit.position.x + half_body)
	var body := hit.collider as CollisionObject3D
	if body == null:
		return fallback
	var shape_owner := body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape3D
	if shape_owner == null or not shape_owner.shape is BoxShape3D:
		return fallback
	var half := (shape_owner.shape as BoxShape3D).size.x * absf(shape_owner.global_basis.get_scale().x) * 0.5
	return Vector2(shape_owner.global_position.x - half, shape_owner.global_position.x + half)

func _begin_pass_up() -> void:
	_end_pass_up()
	for node in get_tree().get_nodes_in_group("boss_pass_up"):
		var body := node as PhysicsBody3D
		if body == null or body == self:
			continue
		var top := -INF
		for child in body.get_children():
			var shape := child as CollisionShape3D
			if shape != null and shape.shape is BoxShape3D:
				top = maxf(top, shape.global_position.y
					+ (shape.shape as BoxShape3D).size.y * absf(shape.global_basis.get_scale().y) * 0.5)
		if top == -INF:
			continue
		add_collision_exception_with(body)
		_pass_up_bodies.append(body)
		_pass_up_tops[body] = top

func _settle_pass_up() -> void:
	var feet := global_position.y
	for body in _pass_up_bodies.duplicate():
		var top: float = _pass_up_tops[body]
		if top <= feet + 0.02 and top <= _jump_target_y + 0.9:
			if is_instance_valid(body):
				remove_collision_exception_with(body)
			_pass_up_bodies.erase(body)
			_pass_up_tops.erase(body)

func _end_pass_up() -> void:
	for body in _pass_up_bodies:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	_pass_up_bodies.clear()
	_pass_up_tops.clear()

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
	if not player.receive_knockback_hit(global_position, _charge_hit,
			_charge_direction * charge_knockback, charge_knockback_deceleration):
		return false
	shoved.emit(player.global_position)
	return true

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
		shoved.emit(player.global_position)

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

func _start_jump(player: PlayerCharacter, landing := {}) -> void:
	var offset := player.global_position.x - global_position.x
	if absf(offset) > 0.05: _landing_player_side = signf(offset)
	state = State.JUMP
	_sync_player_body_collision(player)
	phase_time = 0.0
	_chase_jump = not landing.is_empty()
	if _chase_jump:
		# Height-solved arc: peak just above the target surface, then drop onto it.
		jump_target_x = landing.x
		_jump_target_y = landing.top
		var rise := _jump_target_y - global_position.y
		var apex := maxf(rise, 0.0) + chase_clearance
		velocity.y = sqrt(2.0 * gravity * apex)
		_jump_total_time = velocity.y / gravity + sqrt(2.0 * (apex - rise) / gravity)
		chase_leaps += 1
	else:
		jump_target_x = clampf(player.global_position.x,
			maxf(minimum_x, global_position.x - maximum_jump_distance),
			minf(maximum_x, global_position.x + maximum_jump_distance))
		# Its own level, or a lower player's: pass-up surfaces stay open until then.
		_jump_target_y = minf(global_position.y, player.feet_world_y()) if player.is_on_floor() \
			else global_position.y
		_jump_total_time = jump_duration
		velocity.y = gravity * jump_duration * 0.5
		_next_jump = false
		_next_lob = true
	_face(jump_target_x)
	velocity.x = (jump_target_x - global_position.x) / _jump_total_time
	_begin_pass_up()
	_landing_hit = CombatHit.new(combat.attack_damage, &"boss_landing", global_position)
	attack_started.emit(&"chase_leap" if _chase_jump else &"jump")

func _land(player: PlayerCharacter) -> void:
	_end_pass_up()
	velocity = Vector3.ZERO
	landing_count += 1
	_landing_remaining = landing_active_time
	_landing_hit.source_position = global_position
	_spawn_landing_effects()
	var camera = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("add_shake"):
		camera.add_shake(landing_shake, landing_shake_time)
	_apply_landing_damage(player)
	landed.emit(global_position)
	_begin_recovery()

## The landing's weight on screen, all at whole multiples of the art's pixels:
## a shockwave ring flattened onto the ground, dust rolling out both ways, and
## debris kicked up at each foot.
func _spawn_landing_effects() -> void:
	var ground := global_position
	# The large ring's widest frame matches the blast. Low on the ground and
	# from its first open frame, it rings the feet instead of hiding the legs.
	EFFECT.spawn(get_parent(), ground + Vector3.UP * 0.35, LANDING_RING, 96, 0.06, 0.3, 3)
	# The dust sits on its cell's bottom rows: lift the cell so they meet the ground.
	for side in [-1.0, 1.0]:
		var dust = EFFECT.spawn(get_parent(), ground + Vector3(side * 0.9, 24 * 0.12, 0), LANDING_DUST, 48, 0.12)
		dust.frame_rate = 12.0
		dust.flip_h = side < 0.0
		dust.modulate = LANDING_DUST_SHADE
	for side in [-1.0, 1.0]:
		var debris = EFFECT.spawn(get_parent(), ground + Vector3(side * 1.5, 1.1, 0), LANDING_DEBRIS, 48, 0.08)
		debris.frame_rate = 14.0
		debris.flip_h = side < 0.0
		debris.modulate = LANDING_DUST_SHADE


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
	if _recovery_from_jump and _chase_jump:
		chase_cooldown_remaining = chase_cooldown
	elif _recovery_from_jump:
		jump_cooldown_remaining = jump_cooldown
	elif state == State.LOB:
		firebomb_cooldown_remaining = firebomb_cooldown
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
	if phase == 1 and health.current > 0 \
			and health.current <= ceili(health.maximum * phase_two_health_fraction):
		phase = 2
		phase_changed.emit(phase)
	if health.current == 0:
		_release_escape_player()
		_charge_hit = null
		_ranged_followup = false
		state = State.DEFEATED
		_end_pass_up()
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
	elif state == State.LOB:
		firebomb_cooldown_remaining = maxf(firebomb_cooldown_remaining, firebomb_cooldown)
	_charge_hit = null
	_ranged_followup = false
	state = State.SMOKE_ESCAPE
	_end_pass_up()
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
	smoke_vented.emit(player.global_position)


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
	chase_cooldown_remaining = 0.0
	chase_leaps = 0
	phase = 1
	firebomb_cooldown_remaining = 0.0
	lobs_started = 0
	ground_punishes = 0
	ground_time = 0.0
	_next_lob = false
	_lob_released = false
	_lob_targets.clear()
	_noticing = false
	_chase_jump = false
	_jump_total_time = jump_duration
	_end_pass_up()
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

## Presentation only, while disabled: face a point and swivel the launcher to
## aim at it, holding the last frame. No attack starts.
func begin_notice(target_x: float) -> void:
	_face(target_x)
	_noticing = true
	_animation = ""

func end_notice() -> void:
	_noticing = false
	_animation = ""

## Presentation only: an encounter can stage the boss looking away first.
func face_toward(target_x: float) -> void:
	_face(target_x)

## A defeat restored from a save: the wreck stands where the boss started,
## without the explosion or the projectile clean-up of the live kill.
func restore_defeat() -> void:
	_release_escape_player()
	_end_pass_up()
	state = State.DEFEATED
	velocity = Vector3.ZERO
	_landing_remaining = 0.0
	_landing_hit = null
	collision_layer = 0
	health.reset(combat.maximum_hp, 0)
	# Straight to the last frame of the death animation.
	_animation = ""
	_tick_animation("death", 0.0, false)
	_animation_time = 99.0
	_tick_animation("death", 0.0, false)

## Fires the salvo an encounter showed the launcher readying, if it is free.
func start_opening_salvo(player: PlayerCharacter) -> bool:
	if not enabled or state != State.IDLE or is_defeated() or player.is_dead():
		return false
	_start_salvo(player)
	return true

func state_name() -> String:
	return State.keys()[state]
