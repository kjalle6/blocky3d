class_name PixelCaveCeilingOverlay3D
extends Node3D
## World-anchored cave roof shared by every view of an authored background zone.
##
## The water vistas use a texture that contains both a roof and a lake. Keeping
## the roof here lets the upper floor share that formation without globalizing
## the lake, its rocks, or any hazard behavior. Opacity comes from the same
## spatial zone as the background and regional grade, so all three hand off on
## one curve. Horizontal placement stays authored in the level, as it did in
## the original water windows; only Y follows the camera to preserve the
## established ceiling line during vertical framing.

@export var background_path: NodePath
@export var zone_tag := &"upper"
@export var vertical_offset := 0.02
@export_range(1, 9, 2) var horizontal_panel_count := 5
@export var horizontal_panel_step := 23.04

var _background: PixelBackgroundRig3D
var _camera: Camera3D
var _authored_x := 0.0
var _authored_z := 0.0
var _sprites: Array[Sprite3D] = []


func _ready() -> void:
	# Camera -100, background -90, this overlay -80, regional grade -70.
	process_priority = -80
	_authored_x = global_position.x
	_authored_z = global_position.z
	_background = get_node_or_null(background_path) as PixelBackgroundRig3D
	assert(_background != null, "%s needs the background rig for zone opacity." % name)
	_build_horizontal_panels()
	for child in get_children():
		var sprite := child as Sprite3D
		if sprite != null:
			_sprites.append(sprite)
	assert(not _sprites.is_empty(), "%s needs at least one ceiling sprite." % name)
	_snap_to_camera()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if background_path.is_empty():
		errors.append("The cave ceiling needs a background rig path.")
	if zone_tag.is_empty():
		errors.append("The cave ceiling needs a background zone.")
	if horizontal_panel_count < 1 or horizontal_panel_count % 2 == 0:
		errors.append("The cave ceiling needs an odd positive panel count.")
	if horizontal_panel_step <= 0.0:
		errors.append("The cave ceiling panel step must be positive.")
	return errors


func zone_opacity() -> float:
	if _background == null or _camera == null:
		return 0.0
	return _background.zone_weight_at(zone_tag, _camera.global_position)


func _process(_delta: float) -> void:
	_snap_to_camera()


func _snap_to_camera() -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return
	global_position = Vector3(
		_authored_x,
		_camera.global_position.y + vertical_offset,
		_authored_z
	)
	var opacity := zone_opacity()
	for sprite in _sprites:
		sprite.modulate = Color(
			sprite.modulate.r,
			sprite.modulate.g,
			sprite.modulate.b,
			opacity
		)


func _build_horizontal_panels() -> void:
	var templates: Array[Sprite3D] = []
	for child in get_children():
		var sprite := child as Sprite3D
		if sprite != null:
			templates.append(sprite)
	assert(not templates.is_empty(), "%s needs ceiling panel templates." % name)
	var half_count := floori(horizontal_panel_count * 0.5)
	for panel_index in horizontal_panel_count:
		var slot := panel_index - half_count
		if slot == 0:
			continue
		for template in templates:
			var copy := template.duplicate() as Sprite3D
			copy.name = "%sPanel%d" % [template.name, slot]
			copy.position = (
				template.position
				+ Vector3(slot * horizontal_panel_step, 0.0, 0.0)
			)
			copy.flip_h = absi(slot) % 2 == 1
			add_child(copy)
