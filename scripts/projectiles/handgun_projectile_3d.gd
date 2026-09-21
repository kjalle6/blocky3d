class_name HandgunProjectile3D
extends Node3D
## A deliberately readable side-view handgun round. Continuous ray checks keep
## fast shots from tunnelling through a target or authored cover. Allegiance is
## explicit for player damage and feedback. Both owners can hit enemy targets.

signal expired
signal impacted(world_position: Vector3, surface_normal: Vector3, collider: Object)

enum Allegiance { ENEMY, PLAYER }
const ENEMY_HURTBOX_LAYER := 4

@export_range(1.0, 40.0, 0.1) var speed := 8.5
@export_range(1.0, 50.0, 0.5) var maximum_distance := 22.0
@export_flags_3d_physics var collision_mask := 5
@export var allegiance := Allegiance.ENEMY
@export var horizontal_texture: Texture2D

@export_range(1, 1000, 1) var damage := 25
var damage_hit: CombatHit
var _direction := Vector3.LEFT
var _remaining_distance := 0.0
var _excluded: Array[RID] = []
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


func launch(direction: Vector3, source: CollisionObject3D = null, attack: CombatHit = null) -> void:
	damage_hit = attack if attack != null else CombatHit.new(damage, &"bullet", global_position)
	_direction = direction.normalized()
	_excluded = source_exclusions(source)
	_remaining_distance = maximum_distance
	_launched = not _direction.is_zero_approx()
	_apply_directional_visual()


func _physics_process(delta: float) -> void:
	if not _launched or _expired:
		return
	var travel_distance := minf(speed * delta, _remaining_distance)
	var start := global_position
	var destination := start + _direction * travel_distance
	var hit := cast_shot(get_world_3d().direct_space_state, start, destination, collision_mask, _excluded)
	if not hit.is_empty():
		global_position = hit.position
		var collider := hit.get("collider") as Object
		var surface_normal: Vector3 = hit.get("normal", -_direction)
		impacted.emit(global_position, surface_normal, collider)
		if allegiance == Allegiance.ENEMY and collider is PlayerCharacter:
			(collider as PlayerCharacter).receive_enemy_hit(global_position, damage_hit)
		elif (
			collider != null
			and collider.has_method("receive_projectile_hit")
		):
			collider.call("receive_projectile_hit", global_position, damage_hit)
		_expire()
		return
	global_position = destination
	_remaining_distance -= travel_distance
	if _remaining_distance <= 0.0:
		_expire()


static func source_exclusions(source: CollisionObject3D) -> Array[RID]:
	var excluded: Array[RID] = []
	if source == null: return excluded
	excluded.append(source.get_rid())
	for child in source.find_children("*", "CollisionObject3D", true, false):
		excluded.append(child.get_rid())
	return excluded


static func cast_shot(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3, mask: int, excluded: Array[RID]) -> Dictionary:
	# Contact/attack/trigger areas share the world's layer. Only projectile hurt
	# areas should intercept bullets; query them separately from solid bodies.
	var query := PhysicsRayQueryParameters3D.create(start, end, mask, excluded)
	query.hit_from_inside = true
	var solid := space.intersect_ray(query)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	query.collision_mask = mask & ENEMY_HURTBOX_LAYER
	var target := space.intersect_ray(query) if query.collision_mask != 0 else {}
	if target.is_empty(): return solid
	if solid.is_empty() or start.distance_squared_to(target.position) < start.distance_squared_to(solid.position): return target
	return solid


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
