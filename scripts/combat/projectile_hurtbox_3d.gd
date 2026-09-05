class_name ProjectileHurtbox3D
extends Area3D
## Projectile-only damage surface sized to the visible enemy instead of its
## deliberately compact movement body. Ordinary contact and stomp collision
## remain unchanged.

@export var target_path := NodePath("..")

var _authored_collision_layer := 0
var _target: Node


func _ready() -> void:
	_authored_collision_layer = collision_layer
	_target = get_node_or_null(target_path)
	assert(
		_target != null and _target.has_method("receive_projectile_hit"),
		"ProjectileHurtbox3D requires a projectile-damage target."
	)
	if _target.has_signal("defeated"):
		_target.connect("defeated", _on_target_defeated)
	add_to_group("run_resettable")


func receive_projectile_hit(source_position: Vector3) -> void:
	if _target != null and _target.has_method("receive_projectile_hit"):
		_target.call("receive_projectile_hit", source_position)


func reset_run() -> void:
	collision_layer = _authored_collision_layer


func _on_target_defeated(_impact_position: Vector3) -> void:
	# Damage may arrive during a physics query, so remove the target from future
	# raycasts after the current step instead of mutating space while locked.
	set_deferred("collision_layer", 0)
