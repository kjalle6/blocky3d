class_name HandgunProjectile3D
extends Node3D
## A deliberately readable side-view handgun round. Continuous ray checks keep
## fast shots from tunnelling through a target or authored cover. Allegiance is
## explicit so the accepted enemy round and the player's matching-family round
## can share collision/impact behavior without sharing damage ownership.

signal expired
signal impacted(world_position: Vector3, surface_normal: Vector3, collider: Object)

enum Allegiance { ENEMY, PLAYER }

@export_range(1.0, 40.0, 0.1) var speed := 8.5
@export_range(1.0, 50.0, 0.5) var maximum_distance := 22.0
@export_flags_3d_physics var collision_mask := 1
@export var allegiance := Allegiance.ENEMY
@export var horizontal_texture: Texture2D

var _direction := Vector3.LEFT
var _remaining_distance := 0.0
var _source: CollisionObject3D
var _launched := false
var _expired := false

@onready var visual: Sprite3D = %Visual


func _ready() -> void:
	_remaining_distance = maximum_distance
	add_to_group(
		"player_projectile"
		if allegiance == Allegiance.PLAYER
		else "enemy_projectile"
	)
	add_to_group("run_resettable")
	_apply_directional_visual()


func launch(direction: Vector3, source: CollisionObject3D = null) -> void:
	_direction = direction.normalized()
	_source = source
	_remaining_distance = maximum_distance
	_launched = not _direction.is_zero_approx()
	_apply_directional_visual()


func _physics_process(delta: float) -> void:
	if not _launched or _expired:
		return
	var travel_distance := minf(speed * delta, _remaining_distance)
	var start := global_position
	var destination := start + _direction * travel_distance
	var query := PhysicsRayQueryParameters3D.create(
		start,
		destination,
		collision_mask
	)
	query.collide_with_areas = allegiance == Allegiance.PLAYER
	if _source != null and is_instance_valid(_source):
		query.exclude = [_source.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var collider := hit.get("collider") as Object
		var surface_normal: Vector3 = hit.get("normal", -_direction)
		impacted.emit(global_position, surface_normal, collider)
		if allegiance == Allegiance.ENEMY and collider is PlayerCharacter:
			(collider as PlayerCharacter).receive_enemy_hit(global_position)
		elif (
			allegiance == Allegiance.PLAYER
			and collider != null
			and collider.has_method("receive_projectile_hit")
		):
			collider.call("receive_projectile_hit", global_position)
		_expire()
		return
	global_position = destination
	_remaining_distance -= travel_distance
	if _remaining_distance <= 0.0:
		_expire()


func reset_run() -> void:
	_expire()


func is_player_owned() -> bool:
	return allegiance == Allegiance.PLAYER


func travel_direction() -> Vector3:
	return _direction


func _apply_directional_visual() -> void:
	if visual == null:
		return
	if horizontal_texture != null:
		visual.texture = horizontal_texture
	# The same slim round follows its actual trajectory for both owners and
	# every input method. Keep nearest filtering for the rotated pixel art.
	visual.flip_h = false
	visual.flip_v = false
	visual.rotation.z = atan2(_direction.y, _direction.x)


func _expire() -> void:
	if _expired:
		return
	_expired = true
	expired.emit()
	queue_free()
