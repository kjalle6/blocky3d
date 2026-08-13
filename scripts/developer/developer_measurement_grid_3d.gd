class_name DeveloperMeasurementGrid3D
extends Node3D
## World-locked development grid drawn behind gameplay presentation.

const MAJOR_STEP := PixelPlatform3D.TILE_WORLD_SIZE
const MINOR_STEP := MAJOR_STEP * 0.5
const LABEL_INTERVAL_IN_MAJOR_CELLS := 4
const VIEW_MARGIN_IN_MINOR_CELLS := 3
const GRID_DEPTH := 0.72
const LABEL_DEPTH := 1.42
const MINOR_COLOR := Color(0.46, 0.9, 1.0, 0.10)
const MAJOR_COLOR := Color(0.55, 0.95, 1.0, 0.24)
const AXIS_COLOR := Color(1.0, 0.75, 0.3, 0.42)
const LABEL_COLOR := Color(0.76, 0.94, 1.0, 0.78)

var _camera: Camera3D
var _last_bounds := Rect2()
var _mesh_instance: MeshInstance3D
var _labels: Node3D


func _ready() -> void:
	process_priority = -90
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Lines"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_labels = Node3D.new()
	_labels.name = "CoordinateLabels"
	add_child(_labels)


func bind_camera(camera: Camera3D) -> void:
	_camera = camera
	_last_bounds = Rect2()
	_rebuild_if_needed(true)


func _process(_delta: float) -> void:
	_rebuild_if_needed()


func major_step() -> float:
	return MAJOR_STEP


func minor_step() -> float:
	return MINOR_STEP


func displayed_bounds() -> Rect2:
	return _last_bounds


func _rebuild_if_needed(force := false) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_extents := Vector2(_camera.size * aspect, _camera.size) * 0.5
	var margin := MINOR_STEP * VIEW_MARGIN_IN_MINOR_CELLS
	var view_minimum := Vector2(
		_camera.global_position.x - half_extents.x,
		_camera.global_position.y - half_extents.y
	)
	var view_maximum := Vector2(
		_camera.global_position.x + half_extents.x,
		_camera.global_position.y + half_extents.y
	)
	var minimum := Vector2(
		floorf((view_minimum.x - margin) / MINOR_STEP)
		* MINOR_STEP,
		floorf((view_minimum.y - margin) / MINOR_STEP)
		* MINOR_STEP
	)
	var maximum := Vector2(
		ceilf((view_maximum.x + margin) / MINOR_STEP)
		* MINOR_STEP,
		ceilf((view_maximum.y + margin) / MINOR_STEP)
		* MINOR_STEP
	)
	var next_bounds := Rect2(minimum, maximum - minimum)
	if not force and next_bounds == _last_bounds:
		return
	_last_bounds = next_bounds
	_build_lines(minimum, maximum)
	_build_labels(view_minimum, view_maximum)


func _build_lines(minimum: Vector2, maximum: Vector2) -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.render_priority = -10
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var minimum_x_index := roundi(minimum.x / MINOR_STEP)
	var maximum_x_index := roundi(maximum.x / MINOR_STEP)
	for index in range(minimum_x_index, maximum_x_index + 1):
		var world_x := index * MINOR_STEP
		var color := _line_color(index, world_x)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(world_x, minimum.y, GRID_DEPTH))
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(world_x, maximum.y, GRID_DEPTH))
	var minimum_y_index := roundi(minimum.y / MINOR_STEP)
	var maximum_y_index := roundi(maximum.y / MINOR_STEP)
	for index in range(minimum_y_index, maximum_y_index + 1):
		var world_y := index * MINOR_STEP
		var color := _line_color(index, world_y)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(minimum.x, world_y, GRID_DEPTH))
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(maximum.x, world_y, GRID_DEPTH))
	mesh.surface_end()
	_mesh_instance.mesh = mesh


func _line_color(minor_index: int, world_coordinate: float) -> Color:
	if is_zero_approx(world_coordinate):
		return AXIS_COLOR
	return MAJOR_COLOR if minor_index % 2 == 0 else MINOR_COLOR


func _build_labels(view_minimum: Vector2, view_maximum: Vector2) -> void:
	for child in _labels.get_children():
		child.queue_free()
	var interval := MAJOR_STEP * LABEL_INTERVAL_IN_MAJOR_CELLS
	var minimum_x_index := ceili(view_minimum.x / interval)
	var maximum_x_index := floori(view_maximum.x / interval)
	var label_y := view_minimum.y + MINOR_STEP * 1.15
	for index in range(minimum_x_index, maximum_x_index + 1):
		var world_x := index * interval
		_add_label("X %.2f" % world_x, Vector3(world_x, label_y, LABEL_DEPTH))
	var minimum_y_index := ceili(view_minimum.y / interval)
	var maximum_y_index := floori(view_maximum.y / interval)
	var label_x := view_minimum.x + MINOR_STEP * 1.55
	for index in range(minimum_y_index, maximum_y_index + 1):
		var world_y := index * interval
		_add_label("Y %.2f" % world_y, Vector3(label_x, world_y, LABEL_DEPTH))


func _add_label(text_value: String, world_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = world_position
	label.font_size = 18
	label.pixel_size = 0.012
	label.modulate = LABEL_COLOR
	label.outline_modulate = Color(0.015, 0.025, 0.05, 0.95)
	label.outline_size = 2
	label.no_depth_test = true
	label.render_priority = 20
	_labels.add_child(label)
