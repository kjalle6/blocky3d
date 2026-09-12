extends RefCounted
## All supported loaders and direct scene entry use this before child ready.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")

static func apply_saved(level: Node) -> String:
	var section := REGISTRY.section_for(level)
	if section.is_empty(): return ""
	var saved := STORE.read(REGISTRY.save_path(section))
	if not saved.error.is_empty(): return saved.error
	return apply_layout(level, saved.data)

static func apply_layout(level: Node, layout: Dictionary, preview_fingerprint := "") -> String:
	if level.is_node_ready(): return "Layouts must be applied before initialization."
	var document := DOCUMENT.new()
	var error: String = document.open(level, layout, "missing", preview_fingerprint)
	if not error.is_empty(): return error
	var inspection := OBJECTS.inspect(level)
	# Complete validation above precedes every mutation.
	for id in document.base:
		var node: Node3D = inspection.nodes[id]
		if not document.working.has(id):
			node.get_parent().remove_child(node)
			node.free()
			inspection.nodes.erase(id)
		elif document.working[id].values != document.base[id].values:
			OBJECTS.apply(node, document.working[id].kind, document.working[id].values)
	for id in document.working:
		if not document.base.has(id): inspection.nodes[id] = OBJECTS.create_object(level, id, document.working[id])
	OBJECTS.order_decorations(inspection.nodes)
	level.set_meta("layout_applied", true)
	return ""
