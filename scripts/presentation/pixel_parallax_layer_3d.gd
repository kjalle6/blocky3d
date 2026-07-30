class_name PixelParallaxLayer3D
extends Sprite3D
## Moves a large background plane relative to the active camera. A factor of
## zero is screen-locked; one moves like normal world geometry.

@export_range(0.0, 1.0, 0.01) var parallax_factor := 0.2

var _base_position := Vector3.ZERO
var _initial_camera_x := 0.0
var _initial_camera_y := 0.0
var _initialized := false


func _ready() -> void:
	_base_position = global_position
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if not _initialized:
		_initial_camera_x = camera.global_position.x
		_initial_camera_y = camera.global_position.y
		_initialized = true
	var next_position := _base_position
	next_position.x += (
		(camera.global_position.x - _initial_camera_x)
		* (1.0 - parallax_factor)
	)
	next_position.y += (
		(camera.global_position.y - _initial_camera_y)
		* (1.0 - parallax_factor)
	)
	var pixel_camera := camera as PixelSideCamera3D
	if pixel_camera != null:
		next_position.x = pixel_camera.snap_world_x(next_position.x)
		next_position.y = pixel_camera.snap_world_y(next_position.y)
	global_position = next_position
