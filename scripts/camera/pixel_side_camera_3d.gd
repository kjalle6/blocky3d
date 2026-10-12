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
@export_category("Aim look")
## While the handgun follows the mouse, raise the view by this fraction of the
## cursor's height above the player. Below 1 the view settles instead of
## chasing a still cursor; aiming level or down never moves it.
@export_range(0.0, 0.9, 0.05) var aim_look_fraction := 0.25
@export_range(0.0, 6.0, 0.1) var aim_look_maximum := 2.5
@export_category("Shake")
## Screen pixels a shake of strength 1 can reach. Offsets are whole pixels on
## top of the snapped view, so the pixel art never goes soft.
@export_range(0.0, 32.0, 1.0) var shake_pixels := 8.0
## New shake offsets per second; fewer reads chunkier.
@export_range(10.0, 60.0, 1.0) var shake_rate := 30.0

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
var _shake_strength := 0.0
var _shake_duration := 0.0
var _shake_remaining := 0.0
var _shake_step := 0.0
var _shake_offset := Vector2.ZERO
var _shake_random := RandomNumberGenerator.new()
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
	# The aim lift stays inside the authored vertical limits.
	var aim_lift := aim_look_offset()
	if not _developer_inspection_enabled and _active_vertical_region != null:
		desired_vertical_offset = clampf(
			target.global_position.y + aim_lift
			- _active_vertical_region.vertical_anchor_world_y(),
			_active_vertical_region.minimum_vertical_offset,
			_active_vertical_region.maximum_vertical_offset
		)
	elif not _developer_inspection_enabled and vertical_follow_enabled:
		desired_vertical_offset = clampf(
			target.global_position.y + aim_lift - vertical_anchor_y,
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
	# Shake rides on top of the snapped view and never feeds the smoothing.
	var shake := _advance_shake(delta)
	global_position = Vector3(
		snap_world_x(_smoothed_x) + shake.x,
		camera_height + rendered_vertical_offset + shake.y,
		side_distance
	)
	look_at(
		Vector3(
			global_position.x,
			target_height + rendered_vertical_offset + shake.y,
			0.0
		),
		Vector3.UP
	)


## A brief jolt that dies away over duration, such as a heavy landing. A new
## shake never weakens one that is still stronger.
func add_shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0 or strength < _current_shake_strength():
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_remaining = duration
	_shake_step = 0.0


## The current shake, in whole screen pixels.
func shake_offset_pixels() -> Vector2:
	return _shake_offset


func _current_shake_strength() -> float:
	if _shake_remaining <= 0.0:
		return 0.0
	var fade := _shake_remaining / _shake_duration
	return _shake_strength * fade * fade


func _advance_shake(delta: float) -> Vector2:
	if _shake_remaining <= 0.0 or _developer_inspection_enabled:
		_shake_remaining = 0.0
		_shake_offset = Vector2.ZERO
		return Vector2.ZERO
	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	_shake_step -= delta
	if _shake_remaining <= 0.0:
		_shake_offset = Vector2.ZERO
	elif _shake_step <= 0.0:
		_shake_step = 1.0 / shake_rate
		var reach := roundf(shake_pixels * _current_shake_strength())
		_shake_offset = Vector2(
			roundf(_shake_random.randf_range(-reach, reach)),
			roundf(_shake_random.randf_range(-reach, reach))
		)
	return _shake_offset * world_units_per_screen_pixel()


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


## Upward framing lift for a mouse-aimed handgun; zero in every other state.
func aim_look_offset() -> float:
	var player := target as PlayerCharacter
	if player == null or _developer_inspection_enabled or cinematic_override_enabled:
		return 0.0
	var handgun := player.player_handgun
	if handgun == null or not handgun.mouse_aim_active:
		return 0.0
	return clampf((handgun.crosshair_world.y - player.global_position.y) * aim_look_fraction,
		0.0, aim_look_maximum)


## Cutscene return framing may differ from the temporary cinematic look-ahead.
func gameplay_look_ahead() -> float:
	return look_ahead


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
