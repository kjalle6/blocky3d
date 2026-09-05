class_name HandgunEnemy3D
extends CharacterBody3D
## Stationary ranged enemy used by the firearm review lab and, once its cadence
## is approved, the Level 3 encounter. Cover blocks its real projectiles.

signal defeated(impact_position: Vector3)
signal shot_fired(projectile: HandgunProjectile3D)
signal volley_completed(pattern: FirePattern, shot_count: int)

enum FirePattern { TWIN, TRIPLE }
enum CombatState { IDLE, TELEGRAPH, FIRING, RECOVERY, DEFEATED }

@export var starts_enabled := true
@export var starts_facing_right := false
@export var fire_pattern := FirePattern.TRIPLE
@export var projectile_scene: PackedScene = preload(
	"res://scenes/projectiles/handgun_projectile.tscn"
)
@export_range(2.0, 30.0, 0.5) var detection_range := 18.0
@export_range(0.5, 8.0, 0.1) var vertical_tolerance := 3.0
@export_range(0.1, 1.5, 0.05) var telegraph_duration := 0.55
@export_range(1.0, 30.0, 0.5) var attack_frame_rate := 14.0
@export_range(1, 30, 1) var attack_frame_count := 9
## Zero-based frames in the selected nine-frame attack strip. Frames 1 and 7
## begin the two outward muzzle flashes; the downward flash on frame 4 is
## intentionally omitted from gameplay.
@export var forward_fire_frames := PackedInt32Array([1, 7])
@export_range(0.0, 0.5, 0.01) var projectile_lane_spacing := 0.18
@export_range(0.1, 1.0, 0.01) var twin_shot_interval := 0.55
@export_range(0.05, 0.6, 0.01) var triple_shot_interval := 0.18
## Starting at attack frame 1, this duration ends on frame 3 before the
## downward muzzle-flash frame 4 can appear.
@export_range(0.05, 0.5, 0.01) var forward_visual_duration := 0.18
@export_range(0.1, 3.0, 0.05) var recovery_duration := 0.85
@export_range(1.0, 30.0, 0.1) var projectile_speed := 8.5
@export_range(1.0, 50.0, 0.5) var projectile_distance := 22.0
@export_range(1.0, 100.0, 0.5) var gravity := 38.0
@export_range(1.0, 30.0, 0.1) var stomp_bounce_speed := 10.0

var _initial_transform: Transform3D
var _facing_sign := -1.0
var _engagement_enabled := true
var _state := CombatState.IDLE
var _phase_remaining := 0.0
var _sequence_shots_remaining := 0
var _sequence_shot_timer := 0.0
var _forward_visual_remaining := 0.0
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
@onready var muzzle: Marker3D = %Muzzle
@onready var pixel_visual: PixelHandgunEnemyVisual3D = %PixelVisual


func _ready() -> void:
	_initial_transform = global_transform
	_facing_sign = 1.0 if starts_facing_right else -1.0
	_engagement_enabled = starts_enabled
	add_to_group("run_resettable")
	add_to_group("melee_target")
	contact_area.body_entered.connect(_on_body_entered)


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
			_tick_forward_shot_visual(delta)
			_tick_dual_shot_sequence(delta)
		CombatState.RECOVERY:
			pixel_visual.tick(delta, &"idle", _facing_sign > 0.0)
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
	return forward_fire_frames.size() if fire_pattern == FirePattern.TWIN else 3


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


func receive_melee_hit(source_position: Vector3) -> void:
	if _defeated:
		return
	_defeat(source_position, null)


func receive_projectile_hit(source_position: Vector3) -> void:
	receive_melee_hit(source_position)


func play_impact_flash() -> void:
	pixel_visual.flash_impact()


func reset_combat_cycle(clear_projectiles := true) -> void:
	_state = CombatState.IDLE
	_phase_remaining = 0.0
	_sequence_shots_remaining = 0
	_sequence_shot_timer = 0.0
	_forward_visual_remaining = 0.0
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


func _return_to_idle() -> void:
	_state = CombatState.IDLE
	_phase_remaining = 0.0
	_sequence_shots_remaining = 0
	_sequence_shot_timer = 0.0
	_forward_visual_remaining = 0.0
	_current_volley_shots = 0
	pixel_visual.set_state(&"idle", true)


func _begin_volley() -> void:
	_state = CombatState.FIRING
	_current_volley_shots = 0
	_sequence_shots_remaining = fire_beat_count()
	_sequence_shot_timer = 0.0
	_forward_visual_remaining = 0.0
	_fire_next_dual_shot()


func _tick_forward_shot_visual(delta: float) -> void:
	if _forward_visual_remaining <= 0.0:
		pixel_visual.tick(delta, &"idle", _facing_sign > 0.0)
		return
	pixel_visual.tick(delta, &"attack", _facing_sign > 0.0)
	_forward_visual_remaining = maxf(0.0, _forward_visual_remaining - delta)
	if _forward_visual_remaining <= 0.0:
		pixel_visual.set_state(&"idle", true)


func _tick_dual_shot_sequence(delta: float) -> void:
	if _sequence_shots_remaining > 0:
		_sequence_shot_timer = maxf(0.0, _sequence_shot_timer - delta)
		if _sequence_shot_timer <= 0.0:
			_fire_next_dual_shot()
		return
	if _forward_visual_remaining <= 0.0:
		_enter_recovery()


func _fire_next_dual_shot() -> void:
	if _sequence_shots_remaining <= 0:
		return
	pixel_visual.begin_forward_shot()
	_fire_forward_beat()
	_forward_visual_remaining = forward_visual_duration
	_sequence_shots_remaining -= 1
	_sequence_shot_timer = active_shot_interval()


func _fire_forward_beat() -> void:
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	var shot_direction := Vector3(_facing_sign, 0.0, 0.0)
	if player != null and not player.is_dead():
		var player_offset := player.global_position - global_position
		player_offset.z = 0.0
		if not player_offset.is_zero_approx():
			shot_direction = player_offset.normalized()
			if not is_zero_approx(shot_direction.x):
				_facing_sign = 1.0 if shot_direction.x > 0.0 else -1.0
	var lane_axis := Vector3(-shot_direction.y, shot_direction.x, 0.0)
	var projectile_count := projectiles_per_fire_beat()
	for index in projectile_count:
		var centered_index := float(index) - float(projectile_count - 1) * 0.5
		_spawn_projectile(
			shot_direction,
			lane_axis * centered_index * projectile_lane_spacing
		)


func _spawn_projectile(shot_direction: Vector3, lane_offset: Vector3) -> void:
	var projectile := projectile_scene.instantiate() as HandgunProjectile3D
	assert(projectile != null, "HandgunEnemy3D requires a HandgunProjectile3D scene.")
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(
		absf(muzzle.position.x) * _facing_sign,
		muzzle.position.y,
		0.0
	) + lane_offset
	projectile.speed = projectile_speed
	projectile.maximum_distance = projectile_distance
	projectile.launch(shot_direction, self)
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
	pixel_visual.set_state(&"idle", true)


func _on_projectile_expired(projectile: HandgunProjectile3D) -> void:
	_active_projectiles.erase(projectile)


func _on_body_entered(body: Node3D) -> void:
	if _defeated or not body is PlayerCharacter:
		return
	var player := body as PlayerCharacter
	var from_above := (
		player.was_descending_before_slide()
		and player.global_position.y > global_position.y + 0.55
	)
	if from_above:
		_defeat(player.global_position, player)


func _defeat(impact_position: Vector3, stomping_player: PlayerCharacter) -> void:
	_defeated = true
	_state = CombatState.DEFEATED
	_defeat_serial += 1
	var request_serial := _defeat_serial
	clear_active_projectiles()
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
