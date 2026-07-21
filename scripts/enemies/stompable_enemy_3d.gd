class_name StompableEnemy3D
extends CharacterBody3D
## Small rail-bound patrol enemy for the Level 1 blockout. It reverses at walls
## and ledges, damages on contact, and can be defeated from above.

@export_range(0.1, 10.0, 0.1) var patrol_speed := 2.0
@export_range(1.0, 100.0, 0.5) var gravity := 38.0
@export_range(1.0, 30.0, 0.1) var stomp_bounce_speed := 10.0

var traversal_rail: TraversalRail3D
var _direction := 1.0
var _defeated := false
var _initial_transform: Transform3D

@onready var body_collision: CollisionShape3D = %BodyCollision
@onready var contact_area: Area3D = %ContactArea
@onready var contact_collision: CollisionShape3D = %ContactCollision


func _ready() -> void:
	_initial_transform = global_transform
	add_to_group("rail_bound")
	add_to_group("run_resettable")
	contact_area.body_entered.connect(_on_body_entered)


func bind_to_traversal_rail(rail: TraversalRail3D) -> void:
	traversal_rail = rail


func _physics_process(delta: float) -> void:
	if _defeated or traversal_rail == null:
		return
	var tangent := traversal_rail.tangent_at_world_position(global_position)
	velocity.x = tangent.x * patrol_speed * _direction
	velocity.z = tangent.z * patrol_speed * _direction
	velocity.y = maxf(velocity.y - gravity * delta, -25.0)
	move_and_slide()
	global_position = traversal_rail.constrain_world_position(global_position)
	if is_on_wall() or (is_on_floor() and not _has_floor_ahead(tangent)):
		_direction *= -1.0


func _has_floor_ahead(tangent: Vector3) -> bool:
	var ahead := global_position + tangent * _direction * 0.72 + Vector3.UP * 0.15
	var query := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 1.35, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
	else:
		player.kill()


func _defeat(player: PlayerCharacter) -> void:
	_defeated = true
	player.bounce(stomp_bounce_speed)
	visible = false
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	set_physics_process(false)


func reset_run() -> void:
	global_transform = _initial_transform
	velocity = Vector3.ZERO
	_direction = 1.0
	_defeated = false
	visible = true
	body_collision.set_deferred("disabled", false)
	contact_collision.set_deferred("disabled", false)
	set_physics_process(true)
