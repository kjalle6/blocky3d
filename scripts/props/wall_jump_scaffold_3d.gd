extends StaticBody3D
## Open steel frame. Only its foreground uprights and girders are solid;
## rear legs and diagonal bracing remain behind the gameplay plane.
@export_range(2.56, 20.48, 0.32) var width := 5.12
@export_range(2.56, 51.2, 0.32) var height := 11.52
@export_range(0.0, 49.92, 0.32) var underpass_height := 3.84
## Optional right-hand service bracket for an authored climb above its opposite wall.
@export_range(0.0, 49.92, 0.32) var maintenance_ledge_y := 0.0
const BEAM_WIDTH := 0.32
var _generated: Array[Node] = []

func _ready() -> void:
	rebuild_geometry()

func rebuild_geometry() -> void:
	for child in _generated:
		remove_child(child)
		child.free()
	_generated.clear()
	var low := underpass_height
	var high := height
	var left := -width * 0.5 + BEAM_WIDTH * 0.5
	var right := width * 0.5 - BEAM_WIDTH * 0.5
	# The recess of the rear supports leaves an open lateral tank entrance.
	for x in [left + 0.32, right - 1.6]:
		_beam(Vector2(x, 0), Vector2(x, high - 0.16), 0.16, 0.58, false)
	for y in range(ceili((high - low) / 2.56)):
		var bottom := low + y * 2.56
		var top := minf(high - 0.32, bottom + 2.56)
		_beam(Vector2(left + 0.16, bottom), Vector2(right - 0.16, top), 0.12, 0.64, false)
		_beam(Vector2(left + 0.16, top), Vector2(right - 0.16, bottom), 0.12, 0.62, false)
	for x in [left, right]:
		_beam(Vector2(x, low + 0.16), Vector2(x, high - 0.16), BEAM_WIDTH, 1.05, true)
		_solid(Vector2(x, (low + high) * 0.5), Vector2(BEAM_WIDTH, high - low))
	for y in [low + 0.16, high - 0.16]:
		_beam(Vector2(-width * 0.5, y), Vector2(width * 0.5, y), BEAM_WIDTH, 1.07, true)
		_solid(Vector2(0, y), Vector2(width, BEAM_WIDTH))
		for x in [left, right]:
			_plate(Vector2(x, y), Vector2(0.4, 0.4), Color("344859"), 1.09)
			for dx in [-0.1, 0.1]:
				for dy in [-0.1, 0.1]:
					_plate(Vector2(x + dx, y + dy), Vector2(0.04, 0.04), Color("9fb6be"), 1.11)
	if maintenance_ledge_y > low and maintenance_ledge_y < high:
		var edge := width * 0.5
		var ledge_y := maintenance_ledge_y - BEAM_WIDTH * 0.5
		_beam(Vector2(edge - 0.32, ledge_y), Vector2(edge + 1.28, ledge_y), BEAM_WIDTH, 1.07, true)
		_solid(Vector2(edge + 0.48, ledge_y), Vector2(1.6, BEAM_WIDTH))
		_beam(Vector2(edge - 0.16, ledge_y - 1.28), Vector2(edge + 1.12, ledge_y - 0.16), 0.16, 1.05, false)

func _solid(center: Vector2, dimensions: Vector2) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(dimensions.x, dimensions.y, 1.2)
	collision.shape = shape
	collision.position = Vector3(center.x, center.y, 0)
	add_child(collision)
	_generated.append(collision)

func _beam(start: Vector2, end: Vector2, thickness: float, depth: float, foreground: bool) -> void:
	var center := (start + end) * 0.5
	var length := start.distance_to(end)
	var angle := (end - start).angle()
	_plate(center, Vector2(length, thickness), Color("111c30"), depth, angle)
	_plate(center, Vector2(length, thickness - 0.08), Color("4b6277") if foreground else Color("293c4c"), depth + 0.01, angle)
	var normal := Vector2(0, thickness * 0.5 - 0.04).rotated(angle)
	_plate(center + normal, Vector2(length, 0.04), Color("839caa") if foreground else Color("3b5260"), depth + 0.02, angle)

func _plate(center: Vector2, dimensions: Vector2, color: Color, depth: float, angle := 0.0) -> void:
	var mesh := QuadMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = Vector3(center.x, center.y, depth)
	visual.rotation.z = angle
	add_child(visual)
	_generated.append(visual)
