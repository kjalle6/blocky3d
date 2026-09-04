class_name HandgunProjectile3D
extends Node3D
## A deliberately readable side-view handgun round. Continuous ray checks keep
## fast shots from tunnelling through the player or authored cover.

signal expired
signal impacted(world_position: Vector3, surface_normal: Vector3, collider: Object)

@export_range(1.0, 30.0, 0.1) var speed := 8.5
@export_range(1.0, 50.0, 0.5) var maximum_distance := 22.0
@export_flags_3d_physics var collision_mask := 1

var _direction := Vector3.LEFT
var _remaining_distance := 0.0
var _source: CollisionObject3D
var _launched := false
var _expired := false

@onready var visual: Sprite3D = %Visual


func _ready() -> void:
	_remaining_distance = maximum_distance
	add_to_group("enemy_projectile")
	add_to_group("run_resettable")


func launch(direction: Vector3, source: CollisionObject3D = null) -> void:
	_direction = direction.normalized()
	_source = source
	_remaining_distance = maximum_distance
	_launched = not _direction.is_zero_approx()
	if visual != null:
		visual.flip_h = _direction.x < 0.0


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
	query.collide_with_areas = false
	if _source != null and is_instance_valid(_source):
		query.exclude = [_source.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var collider := hit.get("collider") as Object
		var surface_normal: Vector3 = hit.get("normal", -_direction)
		impacted.emit(global_position, surface_normal, collider)
		if collider is PlayerCharacter:
			(collider as PlayerCharacter).receive_enemy_hit(global_position)
		_expire()
		return
	global_position = destination
	_remaining_distance -= travel_distance
	if _remaining_distance <= 0.0:
		_expire()


func reset_run() -> void:
	_expire()


func _expire() -> void:
	if _expired:
		return
	_expired = true
	expired.emit()
	queue_free()
