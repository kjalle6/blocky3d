class_name RailCamera3D
extends Camera3D
## Maintains a readable side view while the traversal rail turns through the
## world. The player never has to manage the camera directly.

@export var target: Node3D
@export var traversal_rail: TraversalRail3D
@export_range(2.0, 30.0, 0.1) var side_distance := 11.0
@export_range(0.0, 12.0, 0.1) var height := 3.3
@export_range(0.0, 8.0, 0.1) var target_height := 0.8
@export_range(0.0, 8.0, 0.1) var look_ahead := 1.8
@export_range(1.0, 30.0, 0.5) var position_response := 10.0
@export_range(1.0, 30.0, 0.5) var rotation_response := 8.0

var _initialized := false


func _process(delta: float) -> void:
	if target == null or traversal_rail == null:
		return
	var tangent := traversal_rail.tangent_at_world_position(target.global_position)
	var camera_side := tangent.cross(Vector3.UP).normalized()
	var desired_position := target.global_position + camera_side * side_distance + Vector3.UP * height
	var look_target := target.global_position + Vector3.UP * target_height + tangent * look_ahead
	var desired_basis := Basis.looking_at((look_target - desired_position).normalized(), Vector3.UP)
	var desired_transform := Transform3D(desired_basis, desired_position)
	if not _initialized:
		global_transform = desired_transform
		_initialized = true
		return
	var position_weight := 1.0 - exp(-position_response * delta)
	var rotation_weight := 1.0 - exp(-rotation_response * delta)
	global_position = global_position.lerp(desired_position, position_weight)
	global_basis = global_basis.slerp(desired_basis, rotation_weight).orthonormalized()


func snap_to_target() -> void:
	_initialized = false
