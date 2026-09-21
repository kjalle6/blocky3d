class_name StompableEnemy3D
extends CharacterBody3D
## Small horizontal patrol enemy. It reverses at walls and ledges, has a solid
## nonlethal passive body, damages through a telegraphed attack, and can be
## defeated by a stomp or melee hit.

signal defeated(impact_position: Vector3)
signal health_changed(current: int, maximum: int)

@export var combat: CombatProfile = preload("res://resources/combat/bat.tres")
var health := HealthState.new()
var _hurt_remaining := 0.0
var _defeat_serial := 0

const MINIMUM_PATROL_PROGRESS_RATIO := 0.25
const NAVIGATION := preload("res://scripts/enemies/ground_enemy_navigation.gd")
enum Behavior { PATROL, PURSUIT, RETURN }
var _behavior := Behavior.PATROL

## Close encounters and nonlethal hits start pursuit. Jumping over an enemy
## keeps its attention; terrain, authored limits and the camera cap the chase.
@export_range(1.0, 8.0, 0.1) var engagement_distance := 4.0
@export_range(1.0, 8.0, 0.1) var engagement_height := 3.5

@export_range(0.1, 10.0, 0.1) var patrol_speed := 2.0
@export var starts_moving_right := true
## Optional one-sided limits measured from the authored spawn. A zero value
## leaves that side to ordinary wall and ledge detection.
@export_range(0.0, 50.0, 0.05) var patrol_left_distance := 0.0
@export_range(0.0, 50.0, 0.05) var patrol_right_distance := 0.0
@export_range(1.0, 100.0, 0.5) var gravity := 38.0
@export_range(1.0, 30.0, 0.1) var stomp_bounce_speed := 10.0
## Stable head plane, within a few source pixels of the patrol/skater poses.
## The projectile box includes transparent padding above those heads.
@export_range(0.1, 3.0, 0.01) var stomp_head_height := 1.05
@export_range(0.1, 3.0, 0.05) var attack_trigger_distance := 1.65
@export_range(0.1, 3.0, 0.05) var attack_damage_distance := 1.25
@export_range(0.05, 2.0, 0.05) var attack_duration := 0.60
@export_range(0.0, 1.0, 0.01) var attack_impact_time := 0.38
@export_range(0.0, 2.0, 0.05) var attack_cooldown := 0.65
@export_range(0.1, 2.0, 0.05) var attack_vertical_tolerance := 0.9
## Optional rolling attack; ordinary walking enemies remain stationary.
@export_range(0.0, 10.0, 0.1) var attack_move_speed := 0.0

var _direction := 1.0
var _defeated := false
var _dying := false
var _initial_transform: Transform3D
var _attack_remaining := 0.0
var _attack_cooldown_remaining := 0.0
var _attack_damage_applied := false

@onready var body_collision: CollisionShape3D = %BodyCollision
@onready var contact_area: Area3D = %ContactArea
@onready var contact_collision: CollisionShape3D = %ContactCollision
@onready var pixel_visual: PixelEnemyVisual3D = get_node_or_null("PixelVisual") as PixelEnemyVisual3D


func _ready() -> void:
	health.changed.connect(func(current: int, maximum: int) -> void: health_changed.emit(current, maximum))
	health.reset(combat.maximum_hp)
	_initial_transform = global_transform
	_direction = 1.0 if starts_moving_right else -1.0
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self):
		if pixel_visual != null: pixel_visual.tick(0.0, "idle", starts_moving_right)
		return
	add_to_group("run_resettable")
	add_to_group("melee_target")


func _physics_process(delta: float) -> void:
	if _defeated:
		if _dying and pixel_visual != null:
			pixel_visual.tick(delta, "death", _direction > 0.0)
		return
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if _behavior == Behavior.PURSUIT and (
		player == null or player.is_dead() or not NAVIGATION.is_on_camera(self)
	):
		_behavior = Behavior.RETURN
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _hurt_remaining > 0.0:
		_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
		_tick_recovery(delta)
		return
	if _attack_remaining > 0.0:
		_tick_attack(delta)
		return
	if _attack_cooldown_remaining > 0.0:
		_tick_recovery(delta)
		return

	_update_behavior(player, delta)
	if _behavior == Behavior.PURSUIT and _try_start_attack():
		return
	if _behavior == Behavior.PATROL:
		_update_authored_patrol_bounds()
	# Look ahead before both chasing and patrolling, including recovery exits.
	# A reset must not simply resume walking into the same spike row.
	if _at_patrol_limit(_direction) or not NAVIGATION.can_step(self, _direction):
		_end_pursuit_at_barrier()
		_tick_recovery(delta)
		return
	if _behavior == Behavior.PURSUIT and absf(player.global_position.x - global_position.x) < 0.1:
		# Wait below an airborne player, rather than oscillating under their feet.
		_tick_recovery(delta)
		return

	velocity.x = patrol_speed * _direction
	velocity.z = 0.0
	velocity.y = maxf(velocity.y - gravity * delta, -25.0)
	var started_grounded := is_on_floor()
	var starting_position := global_position
	move_and_slide()
	var contact := _classify_horizontal_contact()
	var blocked_by_player: bool = contact.player
	var blocked_by_enemy: bool = contact.enemy
	var blocked_by_level: bool = contact.level
	var patrol_progress := (global_position.x - starting_position.x) * _direction
	var stalled_by_level := (
		started_grounded
		and is_on_floor()
		and not blocked_by_player
		and not blocked_by_enemy
		and patrol_progress < patrol_speed * delta * MINIMUM_PATROL_PROGRESS_RATIO
	)
	if blocked_by_level or stalled_by_level or (blocked_by_enemy and _behavior != Behavior.PURSUIT):
		_end_pursuit_at_barrier()
	if pixel_visual != null:
		var movement_state := "idle" if blocked_by_player or blocked_by_enemy or patrol_speed <= 0.0 else "walk"
		pixel_visual.tick(delta, movement_state, _direction > 0.0)


func _update_behavior(player: PlayerCharacter, delta: float) -> void:
	if _behavior != Behavior.PURSUIT and player != null and not player.is_dead():
		var offset := player.global_position - global_position
		if (
			absf(offset.x) <= engagement_distance
			and absf(offset.y) <= engagement_height
			and NAVIGATION.is_on_camera(self)
			and _within_patrol_limits(player.global_position.x)
			and NAVIGATION.can_reach(self, player.global_position.x)
		):
			_behavior = Behavior.PURSUIT
	if _behavior == Behavior.PURSUIT:
		var offset_x := player.global_position.x - global_position.x
		if absf(offset_x) >= 0.1:
			_direction = signf(offset_x)
	elif _behavior == Behavior.RETURN:
		var home_offset := _initial_transform.origin.x - global_position.x
		if absf(home_offset) <= maxf(0.1, patrol_speed * delta):
			_behavior = Behavior.PATROL
			_direction = 1.0 if starts_moving_right else -1.0
		else:
			_direction = signf(home_offset)


func _within_patrol_limits(position_x: float) -> bool:
	return (
		(patrol_left_distance <= 0.0 or position_x >= _initial_transform.origin.x - patrol_left_distance)
		and (patrol_right_distance <= 0.0 or position_x <= _initial_transform.origin.x + patrol_right_distance)
	)


func _at_patrol_limit(direction: float) -> bool:
	return (
		(direction < 0.0 and patrol_left_distance > 0.0
			and global_position.x <= _initial_transform.origin.x - patrol_left_distance)
		or (direction > 0.0 and patrol_right_distance > 0.0
			and global_position.x >= _initial_transform.origin.x + patrol_right_distance)
	)


func _end_pursuit_at_barrier() -> void:
	_behavior = Behavior.RETURN if _behavior == Behavior.PURSUIT else Behavior.PATROL
	_direction *= -1.0


func is_pursuing() -> bool:
	return _behavior == Behavior.PURSUIT


func _update_authored_patrol_bounds() -> void:
	if (
		_direction < 0.0
		and patrol_left_distance > 0.0
		and global_position.x <= _initial_transform.origin.x - patrol_left_distance
	):
		_direction = 1.0
	elif (
		_direction > 0.0
		and patrol_right_distance > 0.0
		and global_position.x >= _initial_transform.origin.x + patrol_right_distance
	):
		_direction = -1.0


func _classify_horizontal_contact() -> Dictionary:
	var result := {"player": false, "enemy": false, "level": false}
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if absf(collision.get_normal().y) > 0.7:
			continue
		if collision.get_collider() is PlayerCharacter:
			result.player = true
		elif collision.get_collider() is CharacterBody3D:
			result.enemy = true
		else:
			result.level = true
	return result


func receive_stomp(player: PlayerCharacter) -> void:
	if _defeated or player.is_dead():
		return
	var hit := CombatHit.new(player.stomp_attack.damage, &"stomp", player.global_position)
	if receive_melee_hit(player.global_position, hit):
		player.bounce(stomp_bounce_speed)


func receive_melee_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	if _defeated:
		return false
	if hit == null:
		hit = CombatHit.new(preload("res://resources/combat/knife.tres").damage, &"knife", source_position)
	if not health.damage(hit):
		return false
	_attack_remaining = 0.0
	_attack_damage_applied = true
	_hurt_remaining = combat.hurt_duration
	_attack_cooldown_remaining = maxf(attack_cooldown, _hurt_remaining)
	play_impact_flash()
	if health.current > 0:
		_behavior = Behavior.PURSUIT
		if pixel_visual != null:
			pixel_visual.set_state("idle", true)
		return true
	_defeated = true
	_dying = true
	_defeat_serial += 1
	defeated.emit(source_position)
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	if pixel_visual == null:
		visible = false
	else:
		pixel_visual.set_state("death", true)
	get_tree().create_timer(0.6).timeout.connect(_finish_defeat.bind(_defeat_serial))
	return true


func receive_projectile_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	return receive_melee_hit(source_position, hit)


func is_defeated() -> bool:
	return _defeated


func facing_sign() -> float:
	return _direction


func is_attacking() -> bool:
	return _attack_remaining > 0.0


func developer_attack_bounds() -> Rect2:
	var minimum_x := global_position.x
	if _direction < 0.0:
		minimum_x -= attack_damage_distance
	return Rect2(
		Vector2(minimum_x, global_position.y - attack_vertical_tolerance),
		Vector2(attack_damage_distance, attack_vertical_tolerance * 2.0)
	)


func authored_patrol_bounds_x() -> Vector2:
	return Vector2(
		_initial_transform.origin.x - patrol_left_distance,
		_initial_transform.origin.x + patrol_right_distance
	)


func play_impact_flash() -> void:
	if pixel_visual != null:
		pixel_visual.flash_impact()


func _finish_defeat(request_serial: int) -> void:
	if request_serial != _defeat_serial or not _defeated:
		return
	_dying = false
	visible = false


func _tick_recovery(delta: float) -> void:
	# Recovery is an opening after a swing or interruption. Resuming patrol here
	# walks into the player and can trigger a stalled-patrol reversal.
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = maxf(velocity.y - gravity * delta, -25.0)
	move_and_slide()
	if pixel_visual != null:
		pixel_visual.tick(delta, "idle", _direction > 0.0)


func _try_start_attack() -> bool:
	if _attack_cooldown_remaining > 0.0:
		return false
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player == null or player.is_dead():
		return false
	var offset := player.global_position - global_position
	# A stationary swing starts within reach; a rolling attack may close the
	# gap during windup. The trigger distance remains the detection ceiling.
	var reachable_distance := attack_damage_distance + attack_move_speed * minf(attack_impact_time, attack_duration)
	var start_distance := minf(attack_trigger_distance, reachable_distance)
	if absf(offset.x) > start_distance or absf(offset.y) > attack_vertical_tolerance:
		return false
	if not NAVIGATION.can_reach(self, player.global_position.x):
		_behavior = Behavior.RETURN
		return false
	_behavior = Behavior.PURSUIT
	_direction = 1.0 if offset.x >= 0.0 else -1.0
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_remaining = attack_duration
	_attack_damage_applied = false
	if pixel_visual != null:
		pixel_visual.set_state("attack", true)
		pixel_visual.tick(0.0, "attack", _direction > 0.0)
	return true


func _tick_attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if attack_move_speed > 0.0:
		if not _at_patrol_limit(_direction) and NAVIGATION.can_step(self, _direction):
			velocity.x = attack_move_speed * _direction
		else:
			# Finish the committed animation without rolling into the obstacle.
			_behavior = Behavior.RETURN
	velocity.y = maxf(velocity.y - gravity * delta, -25.0)
	move_and_slide()
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	var elapsed := attack_duration - _attack_remaining
	if not _attack_damage_applied and elapsed >= attack_impact_time:
		_attack_damage_applied = true
		_apply_attack_damage()
	if pixel_visual != null:
		pixel_visual.tick(delta, "attack", _direction > 0.0)
	if _attack_remaining <= 0.0:
		_attack_cooldown_remaining = attack_cooldown


func _apply_attack_damage() -> void:
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player == null or player.is_dead():
		return
	var offset := player.global_position - global_position
	var forward_distance := offset.x * _direction
	if (
		forward_distance >= 0.0
		and forward_distance <= attack_damage_distance
		and absf(offset.y) <= attack_vertical_tolerance
	):
		player.receive_enemy_hit(global_position, CombatHit.new(combat.attack_damage, &"enemy_melee", global_position))


func reset_run() -> void:
	_behavior = Behavior.PATROL
	_defeat_serial += 1
	_hurt_remaining = 0.0
	health.reset(combat.maximum_hp)
	global_transform = _initial_transform
	velocity = Vector3.ZERO
	_direction = 1.0 if starts_moving_right else -1.0
	_defeated = false
	_dying = false
	_attack_remaining = 0.0
	_attack_cooldown_remaining = 0.0
	_attack_damage_applied = false
	visible = true
	body_collision.set_deferred("disabled", false)
	contact_collision.set_deferred("disabled", false)
	set_physics_process(true)
	if pixel_visual != null:
		pixel_visual.reset_feedback()
		pixel_visual.set_state("walk" if patrol_speed > 0.0 else "idle", true)
