class_name PixelSideCamera3D
extends Camera3D
## Orthographic side camera. It follows only the route axis, preserving a
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
@export var pixel_snap_enabled := true

var _initialized := false
var _smoothed_x := 0.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 12.9375
	keep_aspect = Camera3D.KEEP_HEIGHT
	process_priority = -100


func _process(delta: float) -> void:
	if target == null:
		return
	var desired_x := clampf(
		target.global_position.x + look_ahead,
		minimum_center_x,
		maximum_center_x
	)
	if not _initialized:
		_smoothed_x = desired_x
		_initialized = true
	else:
		var weight := 1.0 - exp(-follow_response * delta)
		_smoothed_x = lerpf(_smoothed_x, desired_x, weight)
	global_position = Vector3(
		snap_world_x(_smoothed_x),
		camera_height,
		side_distance
	)
	look_at(Vector3(global_position.x, target_height, 0.0), Vector3.UP)


func snap_to_target() -> void:
	_initialized = false
	_process(0.0)


func world_units_per_screen_pixel() -> float:
	var viewport_height := get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0:
		return 0.0
	return size / viewport_height


func snap_world_x(world_x: float) -> float:
	if not pixel_snap_enabled:
		return world_x
	var pixel_world_size := world_units_per_screen_pixel()
	if pixel_world_size <= 0.0:
		return world_x
	return snappedf(world_x, pixel_world_size)
