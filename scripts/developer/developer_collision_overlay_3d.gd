class_name DeveloperCollisionOverlay3D
extends Node3D
## Development-only 2D projection of the collision contracts that drive play.

const OVERLAY_DEPTH := 2.2
const FILL_ALPHA := 0.14
const EDGE_ALPHA := 0.92
const TERRAIN_COLOR := Color(0.32, 0.72, 1.0)
const PLAYER_COLOR := Color(0.25, 1.0, 0.95)
const PLAYER_CONTACT_COLOR := Color(1.0, 0.72, 0.2)
const ENEMY_COLOR := Color(1.0, 0.35, 0.82)
const ENEMY_CONTACT_COLOR := Color(1.0, 0.56, 0.22)
const HAZARD_COLOR := Color(1.0, 0.18, 0.22)
const CHECKPOINT_COLOR := Color(1.0, 0.9, 0.2)
const PICKUP_COLOR := Color(0.72, 0.42, 1.0)
const EXIT_COLOR := Color(0.3, 1.0, 0.38)
const ATTACK_COLOR := Color(1.0, 0.55, 0.12)
const OTHER_COLOR := Color(0.84, 0.86, 0.92)

var _level: LevelSession3D
var _mesh_instance: MeshInstance3D
var _category_counts := {}
var _dynamic_attack_region_count := 0


func _ready() -> void:
	process_priority = 80
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "CollisionProjection"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func bind_level(level: LevelSession3D) -> void:
	_level = level
	_rebuild()


func _process(_delta: float) -> void:
	_rebuild()


func displayed_shape_count() -> int:
	var total := 0
	for count in _category_counts.values():
		total += count as int
	return total


func category_count(category: StringName) -> int:
	return int(_category_counts.get(category, 0))


func dynamic_attack_region_count() -> int:
	return _dynamic_attack_region_count


func _rebuild() -> void:
	if _level == null or not is_instance_valid(_level) or _mesh_instance == null:
		return
	_category_counts.clear()
	_dynamic_attack_region_count = 0
	var fill_mesh := ImmediateMesh.new()
	var fill_material := _material(true)
	fill_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill_material)
	var edge_vertices: Array[Dictionary] = []
	for node in _level.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if not _is_drawable_box(collision):
			continue
		var category := _collision_category(collision)
		var color := _category_color(category)
		_add_collision_box(fill_mesh, edge_vertices, collision, color)
		_category_counts[category] = category_count(category) + 1
	_add_dynamic_attack_regions(fill_mesh, edge_vertices)
	fill_mesh.surface_end()
	if not edge_vertices.is_empty():
		fill_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material(false))
		for entry in edge_vertices:
			fill_mesh.surface_set_color(entry.color)
			fill_mesh.surface_add_vertex(entry.position)
		fill_mesh.surface_end()
	_mesh_instance.mesh = fill_mesh


func _is_drawable_box(collision: CollisionShape3D) -> bool:
	return (
		collision.shape is BoxShape3D
		and not collision.disabled
		and collision.is_visible_in_tree()
	)


func _collision_category(collision: CollisionShape3D) -> StringName:
	var owner := collision.get_parent()
	while owner != null and owner != _level:
		if owner is PlayerCharacter:
			return (
				&"player_contact"
				if collision.get_parent() is Area3D
				else &"player"
			)
		if owner is StompableEnemy3D or owner.is_in_group("melee_target"):
			return (
				&"enemy_contact"
				if collision.get_parent() is Area3D
				else &"enemy"
			)
		if owner is Hazard3D:
			return &"hazard"
		if owner is LevelCheckpoint3D:
			return &"checkpoint"
		if owner is AbilityPickup3D or owner.is_in_group("weapon_pickup"):
			return &"pickup"
		if owner is LevelGoal3D or owner is LevelTransition3D:
			return &"exit"
		if owner is StaticBody3D:
			return &"terrain"
		owner = owner.get_parent()
	return &"other"


func _category_color(category: StringName) -> Color:
	match category:
		&"terrain":
			return TERRAIN_COLOR
		&"player":
			return PLAYER_COLOR
		&"player_contact":
			return PLAYER_CONTACT_COLOR
		&"enemy":
			return ENEMY_COLOR
		&"enemy_contact":
			return ENEMY_CONTACT_COLOR
		&"hazard":
			return HAZARD_COLOR
		&"checkpoint":
			return CHECKPOINT_COLOR
		&"pickup":
			return PICKUP_COLOR
		&"exit":
			return EXIT_COLOR
	return OTHER_COLOR


func _add_collision_box(
	mesh: ImmediateMesh,
	edges: Array[Dictionary],
	collision: CollisionShape3D,
	color: Color
) -> void:
	var box := collision.shape as BoxShape3D
	var half_size := box.size * 0.5
	var transform := collision.global_transform
	var corners := PackedVector3Array([
		_overlay_point(transform * Vector3(-half_size.x, -half_size.y, 0.0)),
		_overlay_point(transform * Vector3(half_size.x, -half_size.y, 0.0)),
		_overlay_point(transform * Vector3(half_size.x, half_size.y, 0.0)),
		_overlay_point(transform * Vector3(-half_size.x, half_size.y, 0.0)),
	])
	_add_quad(mesh, corners, color)
	_add_edges(edges, corners, color)


func _add_dynamic_attack_regions(
	mesh: ImmediateMesh,
	edges: Array[Dictionary]
) -> void:
	if _level.player.is_attacking():
		_add_rect(mesh, edges, _level.player.developer_melee_bounds(), ATTACK_COLOR)
		_dynamic_attack_region_count += 1
	for node in _level.find_children("*", "StompableEnemy3D", true, false):
		var enemy := node as StompableEnemy3D
		if enemy.is_attacking():
			_add_rect(mesh, edges, enemy.developer_attack_bounds(), ATTACK_COLOR)
			_dynamic_attack_region_count += 1


func _add_rect(
	mesh: ImmediateMesh,
	edges: Array[Dictionary],
	rect: Rect2,
	color: Color
) -> void:
	var corners := PackedVector3Array([
		Vector3(rect.position.x, rect.position.y, OVERLAY_DEPTH),
		Vector3(rect.end.x, rect.position.y, OVERLAY_DEPTH),
		Vector3(rect.end.x, rect.end.y, OVERLAY_DEPTH),
		Vector3(rect.position.x, rect.end.y, OVERLAY_DEPTH),
	])
	_add_quad(mesh, corners, color)
	_add_edges(edges, corners, color)


func _add_quad(mesh: ImmediateMesh, corners: PackedVector3Array, color: Color) -> void:
	var fill_color := Color(color.r, color.g, color.b, FILL_ALPHA)
	for index in [0, 1, 2, 0, 2, 3]:
		mesh.surface_set_color(fill_color)
		mesh.surface_add_vertex(corners[index])


func _add_edges(
	edges: Array[Dictionary],
	corners: PackedVector3Array,
	color: Color
) -> void:
	var edge_color := Color(color.r, color.g, color.b, EDGE_ALPHA)
	for pair in [[0, 1], [1, 2], [2, 3], [3, 0]]:
		edges.append({"position": corners[pair[0]], "color": edge_color})
		edges.append({"position": corners[pair[1]], "color": edge_color})


func _overlay_point(point: Vector3) -> Vector3:
	return Vector3(point.x, point.y, OVERLAY_DEPTH)


func _material(fill: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 28 if fill else 29
	return material
