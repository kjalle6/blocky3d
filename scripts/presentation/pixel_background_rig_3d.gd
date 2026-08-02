class_name PixelBackgroundRig3D
extends Node3D
## Camera-aware pixel background with deterministic horizontal recycling.
## The rig evaluates every position from one stable camera reference, so death,
## checkpoints, captures, and direct teleports always reproduce the same phase.

class RuntimeLayer:
	var profile: PixelBackgroundLayerProfile
	var root: Node3D
	var copies: Array[Sprite3D] = []
	var reference_center := Vector3.ZERO


## Scene-load configuration. Authored levels select a profile resource before
## this node enters the tree; live profile replacement is intentionally absent.
@export var profile: PixelBackgroundProfile

var _camera: PixelSideCamera3D
var _runtime_layers: Array[RuntimeLayer] = []
var _reference_ready := false
var _generated_root: Node3D


func _ready() -> void:
	process_priority = -90
	assert(profile != null, "%s requires a background profile." % name)
	var profile_errors := profile.validation_errors()
	assert(
		profile_errors.is_empty(),
		"%s has an invalid background profile:\n%s"
		% [name, "\n".join(profile_errors)]
	)
	_build_layers()


func bind_camera(camera: PixelSideCamera3D) -> void:
	assert(camera != null, "Background rig requires a PixelSideCamera3D.")
	if _camera == camera:
		return
	_camera = camera
	_reference_ready = false


func snap_to_camera(capture_reference := false) -> void:
	if _camera == null:
		return
	if capture_reference:
		_reference_ready = false
	_update_background()


func runtime_layer_count() -> int:
	return _runtime_layers.size()


func runtime_copies(layer_index: int) -> Array[Sprite3D]:
	assert(layer_index >= 0 and layer_index < _runtime_layers.size())
	return _runtime_layers[layer_index].copies


func _process(_delta: float) -> void:
	if _camera == null:
		var active_camera := get_viewport().get_camera_3d() as PixelSideCamera3D
		if active_camera == null:
			return
		bind_camera(active_camera)
	_update_background()


func _build_layers() -> void:
	if _generated_root != null:
		_generated_root.queue_free()
	_runtime_layers.clear()
	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedLayers"
	add_child(_generated_root)
	for index in profile.layers.size():
		var runtime := RuntimeLayer.new()
		runtime.profile = profile.layers[index]
		runtime.root = Node3D.new()
		runtime.root.name = "Layer%02d" % (index + 1)
		_generated_root.add_child(runtime.root)
		_runtime_layers.append(runtime)


func _update_background() -> void:
	if not _reference_ready:
		_capture_reference_centers()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var visible_width := _camera.size * viewport_size.x / viewport_size.y
	for index in _runtime_layers.size():
		_update_layer(_runtime_layers[index], index, visible_width)


func _capture_reference_centers() -> void:
	for runtime in _runtime_layers:
		runtime.reference_center = _screen_center_on_depth(runtime.profile.depth)
	_reference_ready = true


func _update_layer(
	runtime: RuntimeLayer,
	layer_index: int,
	visible_width: float
) -> void:
	var layer := runtime.profile
	var texture_width := float(layer.texture.get_width()) * profile.pixel_size
	var repeat_step := layer.repeat_step_pixels() * profile.pixel_size
	var required_copies := maxi(3, ceili(visible_width / repeat_step) + 2)
	_ensure_copy_count(runtime, required_copies, layer_index)

	var screen_center := _screen_center_on_depth(layer.depth)
	var camera_delta := screen_center - runtime.reference_center
	var content_center_x := _layer_center_x(runtime, screen_center, camera_delta)
	content_center_x = _camera.snap_world_x(content_center_x)
	var content_center_y := _layer_center_y(runtime, screen_center, camera_delta)
	content_center_y = _camera.snap_world_y(content_center_y)

	var view_left := screen_center.x - visible_width * 0.5
	var first_panel_index := floori(
		(view_left - content_center_x + texture_width * 0.5) / repeat_step
	) - 1
	var opacity := layer.opacity_at(_camera.global_position.x)
	for copy_index in runtime.copies.size():
		var sprite := runtime.copies[copy_index]
		if copy_index >= required_copies:
			sprite.visible = false
			continue
		var panel_index := first_panel_index + copy_index
		sprite.visible = opacity > 0.001
		sprite.global_position = Vector3(
			content_center_x + panel_index * repeat_step,
			content_center_y,
			layer.depth
		)
		sprite.flip_h = (
			layer.horizontal_repeat
			== PixelBackgroundLayerProfile.HorizontalRepeat.MIRROR
			and posmod(panel_index, 2) == 1
		)
		sprite.modulate = Color(layer.tint.r, layer.tint.g, layer.tint.b, opacity)


func _layer_center_x(
	runtime: RuntimeLayer,
	screen_center: Vector3,
	camera_delta: Vector3
) -> float:
	var layer := runtime.profile
	var offset := layer.offset_pixels.x * profile.pixel_size
	match layer.horizontal_policy:
		PixelBackgroundLayerProfile.HorizontalPolicy.SCREEN_LOCKED:
			return screen_center.x + offset
		PixelBackgroundLayerProfile.HorizontalPolicy.PARALLAX:
			return (
				runtime.reference_center.x
				+ camera_delta.x * (1.0 - layer.horizontal_parallax)
				+ offset
			)
		PixelBackgroundLayerProfile.HorizontalPolicy.WORLD_LOCKED:
			return runtime.reference_center.x + offset
	return runtime.reference_center.x + offset


func _layer_center_y(
	runtime: RuntimeLayer,
	screen_center: Vector3,
	camera_delta: Vector3
) -> float:
	var layer := runtime.profile
	var offset := layer.offset_pixels.y * profile.pixel_size
	match layer.vertical_policy:
		PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED:
			return screen_center.y + offset
		PixelBackgroundLayerProfile.VerticalPolicy.PARALLAX:
			return (
				runtime.reference_center.y
				+ camera_delta.y * (1.0 - layer.vertical_parallax)
				+ offset
			)
		PixelBackgroundLayerProfile.VerticalPolicy.WORLD_LOCKED:
			return runtime.reference_center.y + offset
	return screen_center.y + offset


func _ensure_copy_count(
	runtime: RuntimeLayer,
	required_copies: int,
	layer_index: int
) -> void:
	while runtime.copies.size() < required_copies:
		var sprite := Sprite3D.new()
		sprite.name = "Copy%02d" % (runtime.copies.size() + 1)
		sprite.texture = runtime.profile.texture
		sprite.pixel_size = profile.pixel_size
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.render_priority = -100 + layer_index
		runtime.root.add_child(sprite)
		runtime.copies.append(sprite)


func _screen_center_on_depth(depth: float) -> Vector3:
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := _camera.project_ray_origin(viewport_center)
	var ray_direction := _camera.project_ray_normal(viewport_center)
	assert(
		absf(ray_direction.z) > 0.0001,
		"Side camera must intersect background Z planes."
	)
	var distance := (depth - ray_origin.z) / ray_direction.z
	return ray_origin + ray_direction * distance
