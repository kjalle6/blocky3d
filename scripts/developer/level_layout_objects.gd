extends RefCounted
## The whole-object contracts shared by the resolver and the designer.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const TILE := 1.28
const FIELDS := {
	"platform": ["x", "y", "width", "height", "style", "surface", "left_cap", "right_cap", "bottom_cap"],
	"enemy": ["x", "y", "speed", "left", "right", "facing_right"],
	"spikes": ["x", "y", "width"],
	"checkpoint": ["x", "y", "width", "height"],
	"gunner": ["x", "y", "facing_right"],
	"flyer": ["x", "y"],
	"decoration": ["x", "y", "flip_h"],
	"tile": ["x", "y", "flip_h", "surface"],
}

static func inspect(level: Node) -> Dictionary:
	var records := {}
	var nodes := {}
	var error := ""
	for node in level.find_children("*", "", true, false):
		if not node.has_meta("layout_id"):
			continue
		var id := str(node.get_meta("layout_id"))
		var kind := str(node.get_meta("layout_kind", ""))
		if id.is_empty() or records.has(id):
			error = "Missing or repeated object ID: " + id
			break
		if not FIELDS.has(kind) or not _matches(node, kind):
			error = "Unsupported registered object: " + id
			break
		var parent := node.get_parent() as Node3D
		var offset := Vector2.ZERO
		while parent != null and parent != level:
			if not parent.basis.is_equal_approx(Basis.IDENTITY) or parent.has_meta("layout_id"):
				error = "A registered object has a transformed or editable parent: " + id
				break
			offset += Vector2(parent.position.x, parent.position.y)
			parent = parent.get_parent() as Node3D
		if not node.basis.is_equal_approx(Basis.IDENTITY):
			error = "Rotated/scaled objects remain locked: " + id
		if not error.is_empty():
			break
		var values := read_values(node, kind)
		records[id] = {"kind": kind, "values": values, "name": str(node.name).capitalize(),
			"path": str(level.get_path_to(node)), "offset": offset,
			"removable": bool(node.get_meta("layout_removable", false)), "created": false}
		nodes[id] = node
	return {"records": records, "nodes": nodes, "error": error}

static func _matches(node: Node, kind: String) -> bool:
	match kind:
		"platform": return node is PixelPlatform3D
		"enemy": return node is StompableEnemy3D
		"gunner": return node is HandgunEnemy3D
		"flyer": return node is HoveringHazard3D
		"decoration": return node is Node3D and node.has_meta("layout_template")
		"tile": return node is StaticBody3D and node.has_method("layout_floor_y_at")
		"spikes": return node is PixelSpikeRow3D
		"checkpoint": return node is LevelCheckpoint3D and node.get_node_or_null("Trigger") is CollisionShape3D and node.get_node("Trigger").shape is BoxShape3D
	return false

static func read_values(node: Node3D, kind: String) -> Dictionary:
	var values := {"x": node.position.x, "y": node.position.y}
	match kind:
		"platform":
			var style_id := ""
			for key in REGISTRY.STYLES:
				if node.style.resource_path == REGISTRY.STYLES[key].resource_path:
					style_id = key
			values.merge({"width": node.size.x, "height": node.size.y, "style": style_id,
				"surface": str(node.get_meta("footstep_surface", node.style.footstep_surface)),
				"left_cap": node.cap_left_edge, "right_cap": node.cap_right_edge, "bottom_cap": node.cap_bottom_edge})
		"enemy": values.merge({"speed": node.patrol_speed, "left": node.patrol_left_distance,
			"right": node.patrol_right_distance, "facing_right": node.starts_moving_right})
		"spikes": values.width = node.row_width
		"gunner": values.facing_right = node.starts_facing_right
		"decoration": values.flip_h = node.get_node("Visual").flip_h
		"tile": values.merge({"flip_h": node.get_node("Visual").flip_h, "surface": str(node.get_meta("footstep_surface", "silent"))})
		"checkpoint":
			var shape := node.get_node("Trigger").shape as BoxShape3D
			values.merge({"width": shape.size.x, "height": shape.size.y})
	# Match disk precision once, so JSON round trips do not create false conflicts.
	return JSON.parse_string(JSON.stringify(values, "", true)) as Dictionary

static func validate(kind: String, values: Dictionary) -> String:
	if not FIELDS.has(kind) or values.size() != FIELDS[kind].size():
		return "Incomplete or unsupported object properties."
	for key in values:
		if key not in FIELDS[kind]: return "Unsupported property: " + str(key)
		var value: Variant = values[key]
		if key in ["style", "surface"]:
			if not value is String: return "Invalid style/surface."
		elif key in ["left_cap", "right_cap", "bottom_cap", "facing_right", "flip_h"]:
			if not value is bool: return "Expected an on/off value."
		elif (not value is float and not value is int) or not is_finite(float(value)):
			return "Expected a finite number for " + str(key)
	if absf(values.x) > 10000.0 or absf(values.y) > 10000.0: return "Position is outside the supported workspace."
	if values.has("width") and (values.width < 0.1 or values.width > 327.68): return "Width must be between 0.1 and 327.68 m."
	if values.has("height") and (values.height < 0.1 or values.height > 81.92): return "Height must be between 0.1 and 81.92 m."
	if kind == "platform":
		if not REGISTRY.STYLES.has(values.style) or values.surface not in ["grass", "sand", "silent"]:
			return "Choose an approved grass/sand style and surface."
		for key in ["width", "height"]:
			if values[key] < TILE - 0.0001 or absf(values[key] / TILE - roundf(values[key] / TILE)) > 0.001:
				return "Platform dimensions must be whole tiles."
		if values.width * values.height / (TILE * TILE) > 4096: return "Keep each platform below 4096 tiles."
	if kind == "enemy":
		if values.speed < 0.1 or values.speed > 10.0: return "Patrol speed must be 0.1–10 m/s."
		if values.left < 0.0 or values.left > 50.0 or values.right < 0.0 or values.right > 50.0:
			return "Patrol limits must be automatic (0) or up to 50 m from the spawn."
	if kind == "spikes" and values.width < 0.6: return "A spike row must be at least 0.6 m wide."
	if kind == "tile" and values.surface not in ["grass", "sand", "cave", "silent"]: return "Choose an approved footstep surface."
	return ""

static func apply(node: Node3D, kind: String, values: Dictionary, rebuild := false) -> void:
	node.position.x = values.x
	node.position.y = values.y
	match kind:
		"platform":
			node.size = Vector3(values.width, values.height, node.size.z)
			node.style = REGISTRY.STYLES[values.style]
			node.set_meta("footstep_surface", StringName(values.surface))
			node.cap_left_edge = values.left_cap
			node.cap_right_edge = values.right_cap
			node.cap_bottom_edge = values.bottom_cap
			if rebuild: node.rebuild_geometry()
		"enemy":
			node.patrol_speed = values.speed
			node.patrol_left_distance = values.left
			node.patrol_right_distance = values.right
			node.starts_moving_right = values.facing_right
			if rebuild and node.pixel_visual != null:
				node.pixel_visual.tick(0.0, "idle", values.facing_right)
		"spikes":
			node.row_width = values.width
			if rebuild: node.rebuild_geometry()
		"gunner":
			node.starts_facing_right = values.facing_right
			if rebuild and node.pixel_visual != null: node.pixel_visual.tick(0.0, &"idle", values.facing_right)
		"decoration": node.get_node("Visual").flip_h = values.flip_h
		"tile":
			node.set_horizontal_flip(values.flip_h)
			node.set_meta("footstep_surface", StringName(values.surface))
		"checkpoint":
			var trigger := node.get_node("Trigger") as CollisionShape3D
			trigger.shape = trigger.shape.duplicate()
			trigger.shape.size = Vector3(values.width, values.height, trigger.shape.size.z)
			trigger.position.y = values.height * 0.5

static func bounds(record: Dictionary) -> Rect2:
	var v: Dictionary = record.values
	var center: Vector2 = Vector2(v.x, v.y) + record.get("offset", Vector2.ZERO)
	match record.kind:
		"tile": return Rect2(center - Vector2.ONE * TILE * 0.5, Vector2.ONE * TILE)
		"platform": return Rect2(center - Vector2(v.width, v.height) * 0.5, Vector2(v.width, v.height))
		"enemy": return Rect2(center - Vector2(0.55, 0.45), Vector2(1.1, 1.5))
		"gunner": return Rect2(center - Vector2(0.6, 0.55), Vector2(1.2, 1.95))
		"flyer": return Rect2(center - Vector2(0.55, 0.92), Vector2(1.1, 1.6))
		"decoration":
			var extent: Vector2 = CATALOG.icon(record.template).get_size() * 0.04
			return Rect2(center - Vector2(extent.x * 0.5, 0), extent)
		"spikes": return Rect2(center - Vector2(v.width * 0.5, 0.0), Vector2(v.width, 0.76))
		"checkpoint": return Rect2(center - Vector2(v.width * 0.5, 0.0), Vector2(v.width, v.height))
	return Rect2()

static func create_platform(level: Node, id: String, values: Dictionary) -> Node3D:
	return create_object(level, id, new_record("sand_platform" if values.style == "sand" else "grass_platform", values))

static func new_record(template: String, values: Dictionary) -> Dictionary:
	var entry: Dictionary = CATALOG.ENTRIES[template]
	return {"template": template, "kind": entry.kind, "values": values.duplicate(true),
		"name": entry.name, "path": "", "offset": Vector2.ZERO, "removable": true, "created": true}

static func instantiate_record(record: Dictionary) -> Node3D:
	var entry: Dictionary = CATALOG.ENTRIES[record.template]
	var node: Node3D
	if entry.kind == "platform": node = PixelPlatform3D.new()
	elif entry.kind == "tile":
		node = preload("res://scripts/developer/level_catalog_tile_3d.gd").new()
		node.configure(entry)
	elif entry.kind == "decoration":
		node = Node3D.new()
		var visual: Sprite3D
		if entry.has("fps"):
			visual = preload("res://scripts/developer/level_catalog_animation.gd").new()
			visual.configure(entry)
		else: visual = Sprite3D.new()
		visual.name = "Visual"
		visual.texture = CATALOG.icon(record.template)
		visual.pixel_size = 0.04
		visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		visual.shaded = false
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.position = Vector3(0, visual.texture.get_height() * 0.02, 1.0)
		visual.render_priority = -1
		node.add_child(visual)
	else: node = (load(entry.scene) as PackedScene).instantiate()
	node.set_meta("layout_template", record.template)
	if entry.kind == "checkpoint": node.set_meta("layout_added_checkpoint", true)
	apply(node, entry.kind, record.values)
	return node

static func create_object(level: Node, id: String, record: Dictionary) -> Node3D:
	var node := instantiate_record(record)
	node.name = record.name.to_pascal_case() + "_" + id.right(8)
	node.set_meta("layout_id", id)
	node.set_meta("layout_kind", record.kind)
	node.set_meta("layout_removable", true)
	var parent := level.get_node_or_null("Platforms" if record.kind == "platform" else "DesignerObjects")
	if parent == null:
		parent = Node3D.new()
		parent.name = "DesignerObjects"
		level.add_child(parent)
	parent.add_child(node)
	return node

static func order_decorations(nodes: Dictionary) -> void:
	var ids := nodes.keys()
	ids.sort()
	var rank := 0
	for id in ids:
		var node: Node = nodes[id]
		if node.get_meta("layout_kind", "") == "decoration":
			# Stable separate depths avoid ties between overlapping translucent props.
			node.get_node("Visual").position.z = 1.0 + rank * 0.0001
			rank += 1

static func nearby_floor(level: Node, point: Vector2, tolerance: float, ignore: Node = null) -> float:
	var height := INF
	for collision in level.find_children("*", "CollisionShape3D", true, false):
		if ignore != null and ignore.is_ancestor_of(collision): continue
		var body: Node = collision.get_parent()
		if not (body is StaticBody3D or body is AnimatableBody3D): continue
		var top := INF
		if body.has_method("layout_floor_y_at"):
			top = body.layout_floor_y_at(point.x)
		elif collision.shape is BoxShape3D:
			var half: Vector3 = collision.shape.size * collision.global_basis.get_scale().abs() * 0.5
			var center: Vector3 = collision.global_position
			if point.x >= center.x - half.x and point.x <= center.x + half.x: top = center.y + half.y
		if absf(point.y - top) < tolerance:
			height = top
			tolerance = absf(point.y - top)
	return height
