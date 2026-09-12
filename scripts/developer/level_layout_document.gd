extends RefCounted
## An authoring document holds values, never live gameplay nodes.
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const SCHEMA := 3

var section := ""
var fingerprint := ""
var revision := 0
var base: Dictionary = {}
var saved: Dictionary = {}
var working: Dictionary = {}
var disk_hash := "missing"
var error := ""
var _catalog_signatures: Dictionary = {}

func open(level: Node, layout: Dictionary, source_hash := "missing", preview_fingerprint := "") -> String:
	section = REGISTRY.section_for(level)
	if section.is_empty(): return "Designer is not enabled for this section yet."
	fingerprint = REGISTRY.fingerprint(section) if REGISTRY.can_author() else ""
	if not preview_fingerprint.is_empty(): fingerprint = preview_fingerprint
	var inspection := OBJECTS.inspect(level)
	if not inspection.error.is_empty(): return inspection.error
	base = inspection.records
	_catalog_signatures = OBJECTS.CATALOG.signatures(OBJECTS.CATALOG.ENTRIES.keys()) if REGISTRY.can_author() else {}
	var resolved := resolve(layout)
	if not resolved.error.is_empty(): return resolved.error
	revision = int(layout.get("revision", 0))
	disk_hash = source_hash
	saved = resolved.records.duplicate(true)
	working = saved.duplicate(true)
	return ""

func resolve(layout: Dictionary) -> Dictionary:
	var records := base.duplicate(true)
	if layout.is_empty(): return {"error": "", "records": records}
	var allowed := ["schema", "section", "revision", "fingerprint", "overrides", "created", "removed"]
	if layout.get("schema") == SCHEMA: allowed.append("catalog")
	if layout.size() != allowed.size(): return _failure("Incomplete layout document.")
	for key in layout:
		if key not in allowed: return _failure("Unknown layout field: " + str(key))
	if (layout.schema != 1 and layout.schema != 2 and layout.schema != SCHEMA) or layout.section != section: return _failure("Layout version or section does not match.")
	if (not layout.revision is float and not layout.revision is int) or not is_finite(float(layout.revision)) or layout.revision < 0 or floorf(layout.revision) != layout.revision:
		return _failure("Invalid layout revision.")
	if not layout.fingerprint is String: return _failure("Invalid structural fingerprint.")
	if REGISTRY.can_author() and layout.fingerprint != fingerprint:
		return _failure("The base scene changed. Keep this draft for review with Codex before saving.")
	if not layout.overrides is Dictionary or not layout.created is Dictionary or not layout.removed is Array:
		return _failure("Invalid object collections.")
	if layout.created.size() > 4096: return _failure("A section supports at most 4096 added objects, including painted tiles.")
	var non_tile_count := 0
	var templates: Array = []
	var touched := {}
	for id in layout.overrides:
		var edit: Variant = layout.overrides[id]
		if not base.has(id) or not edit is Dictionary or edit.size() != 2 or not edit.has("expected") or not edit.has("values"):
			return _failure("Unrecognized edited object: " + str(id))
		if not edit.expected is Dictionary or not edit.values is Dictionary or edit.expected != base[id].values:
			return _failure("The original properties changed for " + str(id))
		var validation := OBJECTS.validate(base[id].kind, edit.values)
		if not validation.is_empty(): return _failure(str(id) + ": " + validation)
		records[id].values = edit.values.duplicate(true)
		touched[id] = true
	for id in layout.created:
		if not id is String or (not id.begins_with("platform_") and not id.begins_with("object_")) or not id.is_valid_identifier() or id.length() > 80 or base.has(id):
			return _failure("Invalid added object identity.")
		var payload: Variant = layout.created[id]
		if not payload is Dictionary: return _failure("Invalid added object properties.")
		var template := ""
		var values: Dictionary
		if layout.schema == 1:
			values = payload
			template = "sand_platform" if values.get("style", "") == "sand" else "grass_platform"
		else:
			if payload.size() != 2 or not payload.get("template") is String or not payload.get("values") is Dictionary:
				return _failure("Incomplete object template or properties.")
			template = payload.template
			values = payload.values
		if not OBJECTS.CATALOG.ENTRIES.has(template): return _failure("Unknown catalog object: " + template)
		if template not in templates: templates.append(template)
		var kind: String = OBJECTS.CATALOG.ENTRIES[template].kind
		if kind != "tile": non_tile_count += 1
		if non_tile_count > 512: return _failure("A section supports at most 512 added objects besides painted tiles.")
		var validation := OBJECTS.validate(kind, values)
		if not validation.is_empty(): return _failure(str(id) + ": " + validation)
		records[id] = OBJECTS.new_record(template, values)
	if layout.schema == SCHEMA:
		if not layout.catalog is Dictionary or layout.catalog.size() != templates.size(): return _failure("Invalid asset signatures.")
		for template in templates:
			if not layout.catalog.get(template) is String: return _failure("Missing asset signature: " + template)
		if REGISTRY.can_author() and OBJECTS.CATALOG.signatures(templates, true) != layout.catalog:
			return _failure("An asset used by this layout changed. Keep the layout for review with Codex before saving.")
	for id in layout.removed:
		if not id is String or not base.has(id) or not base[id].removable or touched.has(id):
			return _failure("Removal is not permitted for " + str(id))
		touched[id] = true
		records.erase(id)
	return {"error": "", "records": records}

func serialize(next_revision := -1) -> Dictionary:
	var overrides := {}
	var created := {}
	var removed := []
	var catalog := {}
	for id in base:
		if not working.has(id): removed.append(id)
		elif working[id].values != base[id].values:
			overrides[id] = {"expected": base[id].values.duplicate(true), "values": working[id].values.duplicate(true)}
	for id in working:
		if not base.has(id):
			created[id] = {"template": working[id].template, "values": working[id].values.duplicate(true)}
			catalog[working[id].template] = _catalog_signatures.get(working[id].template, "")
	removed.sort()
	return {"schema": SCHEMA, "section": section, "revision": revision if next_revision < 0 else next_revision,
		"fingerprint": fingerprint, "overrides": overrides, "created": created, "removed": removed, "catalog": catalog}

func has_changes() -> bool:
	return working != saved

func revert() -> void:
	working = saved.duplicate(true)

func mark_saved(new_hash: String, new_revision: int) -> void:
	disk_hash = new_hash
	revision = new_revision
	saved = working.duplicate(true)

static func new_platform_record(values: Dictionary) -> Dictionary:
	return OBJECTS.new_record("sand_platform" if values.style == "sand" else "grass_platform", values)

static func _failure(message: String) -> Dictionary:
	return {"error": message, "records": {}}
