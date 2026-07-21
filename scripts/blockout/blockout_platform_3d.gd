@tool
class_name BlockoutPlatform3D
extends StaticBody3D
## Disposable editor-visible platform geometry. Authored production assets will
## replace the meshes; the simple collision dimensions remain useful reference.

@export var size := Vector3(4.0, 1.0, 4.0):
	set(value):
		size = Vector3(maxf(0.1, value.x), maxf(0.1, value.y), maxf(0.1, value.z))
		_rebuild()
@export var body_color := Color(0.42, 0.27, 0.16):
	set(value):
		body_color = value
		_rebuild()
@export var top_color := Color(0.30, 0.68, 0.27):
	set(value):
		top_color = value
		_rebuild()
@export_range(0.02, 0.4, 0.01) var top_thickness := 0.16:
	set(value):
		top_thickness = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "Collision"
		add_child(collision)
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape

	var body_mesh := get_node_or_null("BodyMesh") as MeshInstance3D
	if body_mesh == null:
		body_mesh = MeshInstance3D.new()
		body_mesh.name = "BodyMesh"
		add_child(body_mesh)
	var cap_mesh := get_node_or_null("TopMesh") as MeshInstance3D
	if cap_mesh == null:
		cap_mesh = MeshInstance3D.new()
		cap_mesh.name = "TopMesh"
		add_child(cap_mesh)

	var cap_height := minf(top_thickness, size.y)
	var body_height := maxf(0.01, size.y - cap_height)
	body_mesh.mesh = _box_mesh(Vector3(size.x, body_height, size.z), body_color)
	body_mesh.position.y = -cap_height * 0.5
	cap_mesh.mesh = _box_mesh(Vector3(size.x + 0.02, cap_height, size.z + 0.02), top_color)
	cap_mesh.position.y = size.y * 0.5 - cap_height * 0.5


func _box_mesh(mesh_size: Vector3, color: Color) -> BoxMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	mesh.material = material
	return mesh
