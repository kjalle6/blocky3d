class_name PixelVistaWindow3D
extends Node3D
## A localized background composition whose horizontal opening is authored in
## world space. Vertical behavior is explicit because a physical horizon must
## not accidentally follow a jumping player, while some future decorative
## windows may still need guaranteed viewport coverage during a long climb.

enum VerticalPolicy {
	WORLD_LOCKED,
	CAMERA_LOCKED,
}

@export var vertical_policy := VerticalPolicy.WORLD_LOCKED
@export var vertical_offset := 0.0

var _authored_world_y := 0.0


func _ready() -> void:
	process_priority = -80
	_authored_world_y = snappedf(
		global_position.y,
		PixelPlatform3D.TILE_PIXEL_SIZE
	)
	if vertical_policy == VerticalPolicy.WORLD_LOCKED:
		global_position.y = _authored_world_y
		set_process(false)
	else:
		_snap_to_camera()


func _process(_delta: float) -> void:
	if vertical_policy == VerticalPolicy.CAMERA_LOCKED:
		_snap_to_camera()


func _snap_to_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	global_position.y = snappedf(
		camera.global_position.y + vertical_offset,
		PixelPlatform3D.TILE_PIXEL_SIZE
	)


func authored_world_y() -> float:
	return _authored_world_y
