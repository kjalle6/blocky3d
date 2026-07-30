class_name PixelSideCamera3D
extends Camera3D
## Orthographic Level 1 camera. It follows only the route axis, preserving a
## stable 2D composition while remaining replaceable for later 2.5D sections.

@export var target: Node3D
@export var traversal_rail: TraversalRail3D
@export var look_ahead := 2.6
@export var camera_height := 5.2
@export var target_height := 2.7
@export var side_distance := 24.0
@export var follow_response := 8.0
@export var minimum_center_x := 6.47
@export var maximum_center_x := 44.73

var _initialized := false


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 12.9375
	keep_aspect = Camera3D.KEEP_HEIGHT


func _process(delta: float) -> void:
	if target == null:
		return
	var desired_x := clampf(
		target.global_position.x + look_ahead,
		minimum_center_x,
		maximum_center_x
	)
	var desired_position := Vector3(desired_x, camera_height, side_distance)
	if not _initialized:
		global_position = desired_position
		_initialized = true
	else:
		var weight := 1.0 - exp(-follow_response * delta)
		global_position = global_position.lerp(desired_position, weight)
	look_at(Vector3(global_position.x, target_height, 0.0), Vector3.UP)


func snap_to_target() -> void:
	_initialized = false
	_process(0.0)
