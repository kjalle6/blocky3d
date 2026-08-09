class_name StompableEnemy3D
extends CharacterBody3D
## Small horizontal patrol enemy. It reverses at walls and ledges, has a solid
## nonlethal passive body, damages through a telegraphed attack, and can be
## defeated by a stomp or melee hit.

signal defeated(impact_position: Vector3)

const MINIMUM_PATROL_PROGRESS_RATIO := 0.25

@export_range(0.1, 10.0, 0.1) var patrol_speed := 2.0
@export var starts_moving_right := true
@export_range(1.0, 100.0, 0.5) var gravity := 38.0
@export_range(1.0, 30.0, 0.1) var stomp_bounce_speed := 10.0
@export_range(0.1, 3.0, 0.05) var attack_trigger_distance := 1.65
@export_range(0.1, 3.0, 0.05) var attack_damage_distance := 1.25
@export_range(0.05, 2.0, 0.05) var attack_duration := 0.60
@export_range(0.0, 1.0, 0.01) var attack_impact_time := 0.38
@export_range(0.0, 2.0, 0.05) var attack_cooldown := 0.65
@export_range(0.1, 2.0, 0.05) var attack_vertical_tolerance := 0.9

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
	_initial_transform = global_transform
	_direction = 1.0 if starts_moving_right else -1.0
	add_to_group("run_resettable")
	add_to_group("melee_target")
	contact_area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _defeated:
		if _dying and pixel_visual != null:
			pixel_visual.tick(delta, "death", _direction > 0.0)
		return
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _attack_remaining > 0.0:
		_tick_attack(delta)
		return
	if _try_start_attack():
		return
	velocity.x = patrol_speed * _direction
	velocity.z = 0.0
	velocity.y = maxf(velocity.y - gravity * delta, -25.0)
	var started_grounded := is_on_floor()
	var starting_position := global_position
	move_and_slide()
	var contact := _classify_horizontal_contact()
	var blocked_by_player: bool = contact.player
	var blocked_by_level: bool = contact.level
	var patrol_progress := (
		(global_position.x - starting_position.x) * _direction
	)
	var stalled_by_level := (
		started_grounded
		and is_on_floor()
		and not blocked_by_player
		and patrol_progress < patrol_speed * delta * MINIMUM_PATROL_PROGRESS_RATIO
	)
	if (
		blocked_by_level
		or (is_on_floor() and not _has_floor_ahead())
		or stalled_by_level
	):
		_direction *= -1.0
	if pixel_visual != null:
		var movement_state := "idle" if blocked_by_player or patrol_speed <= 0.0 else "walk"
		pixel_visual.tick(delta, movement_state, _direction > 0.0)


func _has_floor_ahead() -> bool:
	var ahead := global_position + Vector3.RIGHT * _direction * 0.72 + Vector3.UP * 0.15
	var query := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 1.35, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _classify_horizontal_contact() -> Dictionary:
	var result := {"player": false, "level": false}
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if absf(collision.get_normal().y) > 0.7:
			continue
		if collision.get_collider() is PlayerCharacter:
			result.player = true
		else:
			result.level = true
	return result


func _on_body_entered(body: Node3D) -> void:
	if _defeated or not body is PlayerCharacter:
		return
	var player := body as PlayerCharacter
	var from_above := (
		player.was_descending_before_slide()
		and player.global_position.y > global_position.y + 0.55
	)
	if from_above:
		_defeat(player)
	# Passive body contact is solid and non-lethal. The authored attack frame
	# below is the enemy's only side-contact damage source.


func _defeat(player: PlayerCharacter) -> void:
	_defeated = true
	_dying = true
	defeated.emit(player.global_position)
	player.bounce(stomp_bounce_speed)
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	if pixel_visual == null:
		visible = false
	else:
		pixel_visual.set_state("death", true)
	get_tree().create_timer(0.6).timeout.connect(_finish_defeat)


func receive_melee_hit(_source_position: Vector3) -> void:
	if _defeated:
		return
	_defeated = true
	_dying = true
	defeated.emit(_source_position)
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	if pixel_visual == null:
		visible = false
	else:
		pixel_visual.set_state("death", true)
	get_tree().create_timer(0.6).timeout.connect(_finish_defeat)


func is_defeated() -> bool:
	return _defeated


func facing_sign() -> float:
	return _direction


func play_impact_flash() -> void:
	if pixel_visual != null:
		pixel_visual.flash_impact()


func _finish_defeat() -> void:
	if not _defeated:
		return
	_dying = false
	visible = false


func _try_start_attack() -> bool:
	if _attack_cooldown_remaining > 0.0:
		return false
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player == null or player.is_dead():
		return false
	var offset := player.global_position - global_position
	if absf(offset.x) > attack_trigger_distance or absf(offset.y) > attack_vertical_tolerance:
		return false
	_direction = 1.0 if offset.x >= 0.0 else -1.0
	_attack_remaining = attack_duration
	_attack_damage_applied = false
	if pixel_visual != null:
		pixel_visual.set_state("attack", true)
	return true


func _tick_attack(delta: float) -> void:
	velocity = Vector3.ZERO
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
		player.receive_enemy_hit(global_position)


func reset_run() -> void:
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
