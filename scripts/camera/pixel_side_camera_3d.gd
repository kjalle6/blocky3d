class_name PixelSideCamera3D
extends Camera3D
## Orthographic side camera. Horizontal route following is always available;
## authored levels can opt into vertical framing without changing locomotion.

@export var target: Node3D
@export var look_ahead := 2.6
@export var camera_height := 2.7
@export var target_height := 2.7
@export var side_distance := 24.0
@export var follow_response := 8.0
@export var minimum_center_x := 6.47
@export var maximum_center_x := 44.73
@export_category("Vertical framing")
@export var vertical_follow_enabled := false
@export var vertical_anchor_y := 0.7
@export var minimum_vertical_offset := 0.0
@export var maximum_vertical_offset := 0.0
@export var vertical_follow_response := 7.0
## Ease changes between authored compositions without slowing ordinary follow.
@export_range(0.0, 2.0, 0.05) var region_transition_duration := 0.65
@export var pixel_snap_enabled := true

var _initialized := false
var _smoothed_x := 0.0
var _smoothed_vertical_offset := 0.0
var _vertical_regions: Array[VerticalCameraRegion3D] = []
var _active_vertical_region: VerticalCameraRegion3D
var _active_horizontal_focus_region: VerticalCameraRegion3D
var _developer_inspection_enabled := false
## Cutscenes own target, look-ahead and zoom until they release this flag.
var cinematic_override_enabled := false
var _framing_goal := Vector2.ZERO
var _region_blend_from := Vector2.ZERO
var _region_blend_elapsed := Vector2.ZERO


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 12.9375
	keep_aspect = Camera3D.KEEP_HEIGHT
	process_priority = -100


func _process(delta: float) -> void:
	if target == null:
		return
	var previous_vertical_region := _active_vertical_region
	var previous_horizontal_region := _active_horizontal_focus_region
	var desired_x := target.global_position.x
	var desired_vertical_offset := 0.0
	if _developer_inspection_enabled:
		_active_vertical_region = null
		_active_horizontal_focus_region = null
		desired_vertical_offset = target.global_position.y - target_height
	else:
		desired_x = clampf(
			target.global_position.x + look_ahead,
			minimum_center_x,
			maximum_center_x
		)
		_active_vertical_region = _find_active_vertical_region()
		_active_horizontal_focus_region = _find_active_horizontal_focus_region()
		if (
			_active_horizontal_focus_region != null
		):
			desired_x = clampf(
				_active_horizontal_focus_region.horizontal_focus_world_x(),
				minimum_center_x,
				maximum_center_x
			)
	if not _developer_inspection_enabled and _active_vertical_region != null:
		desired_vertical_offset = clampf(
			target.global_position.y
			- _active_vertical_region.vertical_anchor_world_y(),
			_active_vertical_region.minimum_vertical_offset,
			_active_vertical_region.maximum_vertical_offset
		)
	elif not _developer_inspection_enabled and vertical_follow_enabled:
		desired_vertical_offset = clampf(
			target.global_position.y - vertical_anchor_y,
			minimum_vertical_offset,
			maximum_vertical_offset
		)
	var desired_framing := Vector2(desired_x, desired_vertical_offset)
	if not _initialized or _developer_inspection_enabled:
		# Spawn, load and inspection jumps deliberately restore exact framing.
		_region_blend_elapsed = Vector2.ONE * region_transition_duration
		_region_blend_from = desired_framing
	else:
		# Retarget from the current blended goal, including when the player turns
		# back across a boundary before the previous handover has finished.
		if previous_horizontal_region != _active_horizontal_focus_region:
			_region_blend_from.x = _framing_goal.x
			_region_blend_elapsed.x = 0.0
		if previous_vertical_region != _active_vertical_region:
			_region_blend_from.y = _framing_goal.y
			_region_blend_elapsed.y = 0.0
		for axis in 2:
			_region_blend_elapsed[axis] += delta
			if _region_blend_elapsed[axis] < region_transition_duration:
				var weight := smoothstep(0.0, region_transition_duration, _region_blend_elapsed[axis])
				desired_framing[axis] = lerpf(_region_blend_from[axis], desired_framing[axis], weight)
	_framing_goal = desired_framing
	desired_x = desired_framing.x
	desired_vertical_offset = desired_framing.y
	if _developer_inspection_enabled:
		_smoothed_x = desired_x
		_smoothed_vertical_offset = desired_vertical_offset
		_initialized = true
	elif not _initialized:
		_smoothed_x = desired_x
		_smoothed_vertical_offset = desired_vertical_offset
		_initialized = true
	else:
		var horizontal_weight := 1.0 - exp(-follow_response * delta)
		var vertical_weight := 1.0 - exp(-vertical_follow_response * delta)
		_smoothed_x = lerpf(_smoothed_x, desired_x, horizontal_weight)
		_smoothed_vertical_offset = lerpf(
			_smoothed_vertical_offset,
			desired_vertical_offset,
			vertical_weight
		)
	var rendered_vertical_offset := snap_world_y(_smoothed_vertical_offset)
	global_position = Vector3(
		snap_world_x(_smoothed_x),
		camera_height + rendered_vertical_offset,
		side_distance
	)
	look_at(
		Vector3(
			global_position.x,
			target_height + rendered_vertical_offset,
			0.0
		),
		Vector3.UP
	)


func bind_vertical_regions(regions: Array[VerticalCameraRegion3D]) -> void:
	_vertical_regions = regions.duplicate()
	for region in _vertical_regions:
		assert(region != null)
		var errors := region.validation_errors()
		assert(
			errors.is_empty(),
			"%s has invalid vertical camera settings:\n%s"
			% [region.name, "\n".join(errors)]
		)


func active_vertical_region() -> VerticalCameraRegion3D:
	return _active_vertical_region


func active_horizontal_focus_region() -> VerticalCameraRegion3D:
	return _active_horizontal_focus_region


func set_developer_inspection_enabled(enabled: bool) -> void:
	_developer_inspection_enabled = enabled
	snap_to_target()


func is_developer_inspection_enabled() -> bool:
	return _developer_inspection_enabled


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


func snap_world_y(world_y: float) -> float:
	if not pixel_snap_enabled:
		return world_y
	var pixel_world_size := world_units_per_screen_pixel()
	if pixel_world_size <= 0.0:
		return world_y
	return snappedf(world_y, pixel_world_size)


func _find_active_vertical_region() -> VerticalCameraRegion3D:
	var best_region: VerticalCameraRegion3D
	for region in _vertical_regions:
		if not region.vertical_framing_enabled:
			continue
		if not region.contains_world_position(target.global_position):
			continue
		if best_region == null or region.priority > best_region.priority:
			best_region = region
	return best_region


func _find_active_horizontal_focus_region() -> VerticalCameraRegion3D:
	var best_region: VerticalCameraRegion3D
	for region in _vertical_regions:
		if not region.horizontal_focus_enabled:
			continue
		if not region.contains_world_position(target.global_position):
			continue
		if best_region == null or region.priority > best_region.priority:
			best_region = region
	return best_region
