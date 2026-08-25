class_name PixelRegionGrade3D
extends Node3D
## Regional colour grade for an interior, driven by the same authored zone the
## background uses.
##
## The art in this game is unshaded, so there is nothing for a light to fall on.
## "Lighting" here means grading the rendered image instead: the lower cave sits
## darker and slightly flatter, and it returns to the upper floor's brightness
## as the climb arrives. Reading the background rig's zone weight rather than
## recomputing a ramp means the grade and the background treatment change across
## the same boundary and cannot drift apart.
##
## The grade applies to the 3D image only. Interface nodes live on a separate
## canvas and are composited afterwards, so they stay at full brightness.

@export var world_environment_path: NodePath
@export var background_path: NodePath
## Zone whose reveal marks fully-lit conditions. Where its weight is 0 the
## values below are applied in full.
@export var zone_tag := &"upper"

@export_category("Lower cave")
@export_range(0.1, 1.0, 0.01) var dark_brightness := 0.74
@export_range(0.1, 2.0, 0.01) var dark_saturation := 0.88
@export_range(0.1, 3.0, 0.01) var dark_contrast := 1.04

@export_category("Upper floor")
@export_range(0.1, 1.0, 0.01) var lit_brightness := 1.0
@export_range(0.1, 2.0, 0.01) var lit_saturation := 1.0
@export_range(0.1, 3.0, 0.01) var lit_contrast := 1.0

var _environment: Environment
var _background: PixelBackgroundRig3D
var _camera: Camera3D


func _ready() -> void:
	# After the camera and the background rig, so the grade reflects the frame
	# being drawn rather than the previous one.
	process_priority = -70
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	assert(
		world_environment != null,
		"%s needs a WorldEnvironment to grade." % name
	)
	_environment = world_environment.environment
	assert(_environment != null, "%s found a WorldEnvironment with no environment." % name)
	_background = get_node_or_null(background_path) as PixelBackgroundRig3D
	assert(_background != null, "%s needs the background rig to read its zone from." % name)
	_environment.adjustment_enabled = true


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if dark_brightness > lit_brightness:
		errors.append("The lower cave grade must not be brighter than the upper floor.")
	if zone_tag.is_empty():
		errors.append("The grade needs a zone to follow.")
	return errors


## 0.0 in the lower cave, 1.0 on the upper floor.
func lit_amount() -> float:
	if _background == null:
		return 1.0
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return 1.0
	return _background.zone_weight_at(zone_tag, _camera.global_position)


func _process(_delta: float) -> void:
	if _environment == null:
		return
	var lit := lit_amount()
	_environment.adjustment_brightness = lerpf(dark_brightness, lit_brightness, lit)
	_environment.adjustment_saturation = lerpf(dark_saturation, lit_saturation, lit)
	_environment.adjustment_contrast = lerpf(dark_contrast, lit_contrast, lit)
