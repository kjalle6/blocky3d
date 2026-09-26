class_name HandgunEnemy3D
extends CharacterBody3D
## Stationary ranged enemy used by the firearm review lab and, once its cadence
## is approved, the Level 3 encounter. Cover blocks its real projectiles.

signal defeated(impact_position: Vector3)
signal health_changed(current: int, maximum: int)

@export var combat: CombatProfile = preload("res://resources/combat/gunner.tres")
@export var group_paired_projectile_damage := true
var health := HealthState.new()
var _shot_hit: CombatHit
signal shot_fired(projectile: HandgunProjectile3D)
signal dual_shot_fired(world_position: Vector3)
signal volley_completed(pattern: FirePattern, shot_count: int)

enum FirePattern { TWIN, TRIPLE }
enum CombatState { IDLE, TELEGRAPH, FIRING, RECOVERY, DEFEATED }

const RECOVERY_AIM_HOLD := 0.12
const BLOCKED_SHOT_RECHECK := 0.08

@export var starts_enabled := true
@export var shot_sound_event := "combat/enemy_gunshot"
@export var projectile_hit_kind: StringName = &"enemy_bullet"
@export var starts_facing_right := false
@export var fire_pattern := FirePattern.TRIPLE
@export var projectile_scene: PackedScene
@export_range(2.0, 30.0, 0.5) var detection_range := 18.0
@export_range(0.5, 8.0, 0.1) var vertical_tolerance := 3.0
@export_range(0.1, 1.5, 0.05) var telegraph_duration := 0.55
@export_range(0.1, 1.0, 0.01) var twin_shot_interval := 0.55
@export_range(0.05, 0.6, 0.01) var triple_shot_interval := 0.18
@export_range(0.1, 3.0, 0.05) var recovery_duration := 0.85
@export_range(1.0, 30.0, 0.1) var projectile_speed := 8.5
@export_range(1.0, 50.0, 0.5) var projectile_distance := 22.0
@export_range(1.0, 100.0, 0.5) var gravity := 38.0
@export_range(1.0, 30.0, 0.1) var stomp_bounce_speed := 10.0
## Sprite head: 0.41 visual offset + 16 source pixels at 0.04 m/pixel.
@export_range(0.1, 3.0, 0.01) var stomp_head_height := 1.05

var _initial_transform: Transform3D
var _facing_sign := -1.0
var _engagement_enabled := true
var _state := CombatState.IDLE
var _phase_remaining := 0.0
var _sequence_shots_remaining := 0
var _sequence_shot_timer := 0.0
var _shot_direction := Vector3.LEFT
var _current_volley_shots := 0
var _shots_fired_total := 0
var _completed_volleys_total := 0
var _last_completed_volley_shot_count := 0
var _defeated := false
var _defeat_serial := 0
var _holding_notice_pose := false
var _holding_panic_pose := false
var _active_projectiles: Array[HandgunProjectile3D] = []

@onready var body_collision: CollisionShape3D = %BodyCollision
@onready var contact_area: Area3D = %ContactArea
@onready var contact_collision: CollisionShape3D = %ContactCollision
@onready var pixel_visual: PixelHandgunEnemyVisual3D = %PixelVisual


func _ready() -> void:
	# Load the default after scripts finish resolving: the projectile references
	# the player/session, whose layout catalog also includes enemy subclasses.
	if projectile_scene == null:
		projectile_scene = load("res://scenes/projectiles/handgun_projectile.tscn") as PackedScene
	health.changed.connect(func(current: int, maximum: int) -> void: health_changed.emit(current, maximum))
	health.reset(combat.maximum_hp)
	_initial_transform = global_transform
	_facing_sign = 1.0 if starts_facing_right else -1.0
	_engagement_enabled = starts_enabled
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self):
		pixel_visual.tick(0.0, &"idle", starts_facing_right)
		return
	add_to_group("run_resettable")
	add_to_group("melee_target")
	pixel_visual.shot_frame_reached.connect(_on_shot_frame_reached)


func _physics_process(delta: float) -> void:
	_settle_on_floor(delta)
	if _defeated:
		pixel_visual.tick(delta, &"death", _facing_sign > 0.0)
		return
	if not _engagement_enabled:
		if _holding_panic_pose:
			pixel_visual.tick_panic(delta, _facing_sign > 0.0)
		else:
			pixel_visual.tick(
				delta,
				&"telegraph" if _holding_notice_pose else &"idle",
				_facing_sign > 0.0
			)
		return
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	match _state:
		CombatState.IDLE:
			pixel_visual.tick(delta, &"idle", _facing_sign > 0.0)
			if _can_engage(player):
				_face_player(player)
				_state = CombatState.TELEGRAPH
				_phase_remaining = telegraph_duration
				pixel_visual.set_state(&"telegraph", true)
		CombatState.TELEGRAPH:
			if not _can_engage(player):
				_return_to_idle()
				return
			_face_player(player)
			pixel_visual.tick(delta, &"telegraph", _facing_sign > 0.0)
			_phase_remaining = maxf(0.0, _phase_remaining - delta)
			if _phase_remaining <= 0.0:
				_begin_volley()
		CombatState.FIRING:
			_tick_shot_visual(delta)
			_tick_dual_shot_sequence(delta)
		CombatState.RECOVERY:
			var holding_aim := recovery_duration - _phase_remaining < RECOVERY_AIM_HOLD
			pixel_visual.tick(delta, &"telegraph" if holding_aim else &"idle", _facing_sign > 0.0)
			_phase_remaining = maxf(0.0, _phase_remaining - delta)
			if _phase_remaining <= 0.0:
				_return_to_idle()


func set_fire_pattern(next_pattern: FirePattern) -> void:
	fire_pattern = next_pattern
	reset_combat_cycle(true)


func set_engagement_enabled(enabled: bool) -> void:
	if _engagement_enabled == enabled:
		if not enabled:
			_holding_notice_pose = false
			_holding_panic_pose = false
			reset_combat_cycle(true)
		return
	_engagement_enabled = enabled
	_holding_notice_pose = false
	_holding_panic_pose = false
	reset_combat_cycle(true)


func engagement_enabled() -> bool:
	return _engagement_enabled


func begin_encounter(initial_telegraph_duration := -1.0) -> void:
	var had_staged_pose := _holding_notice_pose or _holding_panic_pose
	set_engagement_enabled(true)
	if had_staged_pose:
		_state = CombatState.TELEGRAPH
		_phase_remaining = (
			initial_telegraph_duration
			if initial_telegraph_duration > 0.0
			else telegraph_duration
		)
		pixel_visual.set_state(&"telegraph", true)
		pixel_visual.set_aim_direction(_resolve_shot_direction(), _facing_sign > 0.0)


func notice_player() -> void:
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player == null or player.is_dead():
		return
	_face_player(player)
	_holding_notice_pose = not _engagement_enabled
	_holding_panic_pose = false
	pixel_visual.tick(
		0.0,
		&"telegraph" if _holding_notice_pose else &"idle",
		_facing_sign > 0.0
	)


func panic_at_player() -> void:
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player == null or player.is_dead() or _engagement_enabled:
		return
	_face_player(player)
	_holding_notice_pose = false
	_holding_panic_pose = true
	pixel_visual.tick_panic(0.0, _facing_sign > 0.0)


func is_holding_panic_pose() -> bool:
	return _holding_panic_pose


func facing_direction() -> float:
	return _facing_sign


func current_fire_pattern() -> FirePattern:
	return fire_pattern


func pattern_display_name() -> String:
	return "TWO DUAL SHOTS" if fire_pattern == FirePattern.TWIN else "THREE DUAL SHOTS"


func pattern_description() -> String:
	if fire_pattern == FirePattern.TWIN:
		return "Two animation-timed shots; both guns fire together."
	return "Three quick shots; both guns fire together each time."


func projectiles_per_fire_beat() -> int:
	return 2


func fire_beat_count() -> int:
	return 2 if fire_pattern == FirePattern.TWIN else 3


func active_shot_interval() -> float:
	if fire_pattern == FirePattern.TWIN:
		return twin_shot_interval
	return triple_shot_interval


func expected_projectiles_per_attack() -> int:
	return projectiles_per_fire_beat() * fire_beat_count()


func shots_fired_total() -> int:
	return _shots_fired_total


func completed_volleys_total() -> int:
	return _completed_volleys_total


func last_completed_volley_shot_count() -> int:
	return _last_completed_volley_shot_count


func active_projectile_count() -> int:
	var count := 0
	for projectile in _active_projectiles:
		if is_instance_valid(projectile):
			count += 1
	return count


func is_defeated() -> bool:
	return _defeated


func receive_melee_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	if _defeated:
		return false
	if hit == null:
		hit = CombatHit.new(preload("res://resources/combat/knife.tres").damage, &"knife", source_position)
	if not health.damage(hit):
		return false
	_sequence_shots_remaining = 0
	_sequence_shot_timer = 0.0
	if health.current == 0:
		_defeat(source_position, null)
	else:
		_state = CombatState.RECOVERY
		_phase_remaining = maxf(recovery_duration, combat.hurt_duration)
		pixel_visual.set_state(&"idle", true)
		play_impact_flash()
	return true


func receive_projectile_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	return receive_melee_hit(source_position, hit)


func play_impact_flash() -> void:
	pixel_visual.flash_impact()


func reset_combat_cycle(clear_projectiles := true) -> void:
	_state = CombatState.IDLE
	_phase_remaining = 0.0
	_sequence_shots_remaining = 0
	_sequence_shot_timer = 0.0
	_current_volley_shots = 0
	_shots_fired_total = 0
	_completed_volleys_total = 0
	_last_completed_volley_shot_count = 0
	if clear_projectiles:
		clear_active_projectiles()
	if not _defeated:
		pixel_visual.reset_feedback()
		pixel_visual.set_state(&"idle", true)


func clear_active_projectiles() -> void:
	var projectiles := _active_projectiles.duplicate()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.reset_run()
	_active_projectiles.clear()


func reset_run() -> void:
	health.reset(combat.maximum_hp)
	_shot_hit = null
	_defeat_serial += 1
	clear_active_projectiles()
	global_transform = _initial_transform
	velocity = Vector3.ZERO
	_facing_sign = 1.0 if starts_facing_right else -1.0
	_defeated = false
	_holding_notice_pose = false
	_holding_panic_pose = false
	visible = true
	body_collision.set_deferred("disabled", false)
	contact_collision.set_deferred("disabled", false)
	set_physics_process(true)
	_engagement_enabled = starts_enabled
	reset_combat_cycle(false)


func _settle_velocity(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = maxf(velocity.y - gravity * delta, -25.0)


func _settle_on_floor(delta: float) -> void:
	_settle_velocity(delta)
	move_and_slide()


func _can_engage(player: PlayerCharacter) -> bool:
	if not _engagement_enabled or player == null or player.is_dead():
		return false
	var offset := player.global_position - global_position
	return absf(offset.x) <= detection_range and absf(offset.y) <= vertical_tolerance


func _face_player(player: PlayerCharacter) -> void:
	_facing_sign = 1.0 if player.global_position.x >= global_position.x else -1.0
	pixel_visual.set_aim_direction(player.global_position - global_position, _facing_sign > 0.0)


func _return_to_idle() -> void:
	_state = CombatState.IDLE
	_phase_remaining = 0.0
	_sequence_shots_remaining = 0
	_sequence_shot_timer = 0.0
	_current_volley_shots = 0
	pixel_visual.set_state(&"idle", true)


func _begin_volley() -> void:
	_state = CombatState.FIRING
	_current_volley_shots = 0
	_sequence_shots_remaining = fire_beat_count()
	_sequence_shot_timer = 0.0
	_fire_next_dual_shot()


func _tick_shot_visual(delta: float) -> void:
	if not pixel_visual.is_shot_playing():
		pixel_visual.set_aim_direction(_resolve_shot_direction(), _facing_sign > 0.0)
	pixel_visual.tick(
		delta,
		&"attack" if pixel_visual.is_shot_playing() else &"telegraph",
		_facing_sign > 0.0
	)


func _tick_dual_shot_sequence(delta: float) -> void:
	if _sequence_shots_remaining > 0:
		_sequence_shot_timer = maxf(0.0, _sequence_shot_timer - delta)
		if _sequence_shot_timer <= 0.0:
			_fire_next_dual_shot()
		return
	if not pixel_visual.is_shot_playing():
		_enter_recovery()


func _fire_next_dual_shot() -> void:
	if _sequence_shots_remaining <= 0:
		return
	_shot_direction = _resolve_shot_direction()
	if _teammate_blocks_shot(_shot_direction):
		# Keep aiming; do not spend a beat or play a false flash/gunshot. Once the
		# lane opens the pending beat continues with a fresh aim at the player.
		pixel_visual.set_aim_direction(_shot_direction, _facing_sign > 0.0)
		_sequence_shot_timer = BLOCKED_SHOT_RECHECK
		return
	pixel_visual.begin_shot(_shot_direction, _facing_sign > 0.0)
	_sequence_shots_remaining -= 1
	_sequence_shot_timer = active_shot_interval()


func _teammate_blocks_shot(direction: Vector3) -> bool:
	var excluded := HandgunProjectile3D.source_exclusions(self)
	for gun_index in projectiles_per_fire_beat():
		var start := pixel_visual.aimed_muzzle_world_position(gun_index, direction, _facing_sign > 0.0)
		start.z = global_position.z
		var hit := HandgunProjectile3D.cast_shot(get_world_3d().direct_space_state, start,
			start + direction * projectile_distance, 1 | HandgunProjectile3D.ENEMY_HURTBOX_LAYER, excluded)
		var collider: Object = hit.get("collider")
		if (collider is ProjectileHurtbox3D and collider.is_enemy_target()) or (collider is Node and collider.is_in_group("melee_target")):
			return true
	return false


func _resolve_shot_direction() -> Vector3:
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	var shot_direction := Vector3(_facing_sign, 0.0, 0.0)
	if player != null and not player.is_dead():
		var player_offset := player.global_position - global_position
		player_offset.z = 0.0
		if not player_offset.is_zero_approx():
			shot_direction = player_offset.normalized()
			if not is_zero_approx(shot_direction.x):
				_facing_sign = 1.0 if shot_direction.x > 0.0 else -1.0
	return shot_direction


func _on_shot_frame_reached() -> void:
	if _state != CombatState.FIRING or _defeated or not _engagement_enabled:
		return
	_shot_hit = CombatHit.new(combat.attack_damage, projectile_hit_kind, global_position)
	for gun_index in projectiles_per_fire_beat():
		_spawn_projectile(_shot_direction, gun_index)
	# One sound event represents both simultaneous guns. Per-projectile events
	# remain separate for impacts, so a pair does not double the shot volume.
	dual_shot_fired.emit(global_position)


func _spawn_projectile(shot_direction: Vector3, gun_index: int) -> void:
	var projectile := projectile_scene.instantiate() as HandgunProjectile3D
	assert(projectile != null, "HandgunEnemy3D requires a HandgunProjectile3D scene.")
	get_parent().add_child(projectile)
	# Project each real barrel from the sprite's depth onto the gameplay plane.
	var barrel := pixel_visual.muzzle_world_position(gun_index)
	barrel.z = global_position.z
	projectile.global_position = barrel
	projectile.speed = projectile_speed
	projectile.maximum_distance = projectile_distance
	projectile.damage = combat.attack_damage
	projectile.launch(shot_direction, self, _shot_hit if group_paired_projectile_damage else null)
	projectile.expired.connect(_on_projectile_expired.bind(projectile))
	_active_projectiles.append(projectile)
	_current_volley_shots += 1
	_shots_fired_total += 1
	shot_fired.emit(projectile)


func _enter_recovery() -> void:
	_state = CombatState.RECOVERY
	_last_completed_volley_shot_count = _current_volley_shots
	_completed_volleys_total += 1
	volley_completed.emit(fire_pattern, _current_volley_shots)
	_phase_remaining = recovery_duration
	pixel_visual.set_state(&"telegraph", true)


func _on_projectile_expired(projectile: HandgunProjectile3D) -> void:
	_active_projectiles.erase(projectile)


func receive_stomp(player: PlayerCharacter) -> void:
	if _defeated or player.is_dead():
		return
	var hit := CombatHit.new(player.stomp_attack.damage, &"stomp", player.global_position)
	if receive_melee_hit(player.global_position, hit):
		player.bounce(stomp_bounce_speed)


func _defeat(impact_position: Vector3, stomping_player: PlayerCharacter) -> void:
	_defeated = true
	_state = CombatState.DEFEATED
	_defeat_serial += 1
	var request_serial := _defeat_serial
	# A released bullet remains dangerous after its shooter dies. Run reset,
	# encounter reset, and scene teardown still clear outstanding projectiles.
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	pixel_visual.flash_impact()
	pixel_visual.set_state(&"death", true)
	defeated.emit(impact_position)
	if stomping_player != null:
		stomping_player.bounce(stomp_bounce_speed)
	get_tree().create_timer(0.6).timeout.connect(_finish_defeat.bind(request_serial))


func _finish_defeat(request_serial: int) -> void:
	if request_serial != _defeat_serial or not _defeated:
		return
	visible = false
	set_physics_process(false)
