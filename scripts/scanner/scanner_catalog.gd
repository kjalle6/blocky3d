extends RefCounted
## Scanner definitions and read-only stat bindings. No input, saves or live hooks.
const DATA_PATH := "res://resources/scanner/catalog.json"
var _data: Dictionary = {}
var _entries: Dictionary = {}
var _errors := PackedStringArray()


func _init(path: String = DATA_PATH) -> void:
	if not FileAccess.file_exists(path):
		_errors.append("Missing scanner catalog: " + path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		_errors.append("Invalid scanner catalog schema.")
		return
	_data = parsed
	for item in _data.get("entries", []):
		if not item is Dictionary or str(item.get("id", "")).is_empty():
			_errors.append("Scanner entry needs an id.")
			continue
		var id := str(item.id)
		if _entries.has(id):
			_errors.append("Duplicate scanner entry: " + id)
		_entries[id] = item


func entry_ids() -> PackedStringArray:
	return PackedStringArray(_entries.keys())


func definition(entry_id: String) -> Dictionary:
	return _entries.get(entry_id, {}).duplicate(true)


func fact_definitions(entry_id: String) -> Array:
	var entry := definition(entry_id)
	var facts: Array = []
	for set_id in entry.get("fact_sets", []):
		facts.append_array(_data.get("fact_sets", {}).get(set_id, []).duplicate(true))
	facts.append_array(entry.get("facts", []).duplicate(true))
	return facts


func learned_entry(entry_id: String, known_fact_ids: Array, scanned: bool) -> Dictionary:
	var entry := definition(entry_id)
	if not scanned or entry.get("status") != "implemented":
		return {}
	var visible := {"id": entry_id, "game_name": entry.game_name, "facts": []}
	for fact in fact_definitions(entry_id):
		if fact.id in known_fact_ids and fact.get("discovery_status") == "experience":
			visible.facts.append({"id": fact.id, "label": fact.label, "value": fact.value})
	# Exact-number reveal policy is undecided. Neither stat values nor source
	# metadata may leak through the first-scan/learned view.
	return visible


func qualifying_fact_ids(entry_id: String, event: Dictionary) -> PackedStringArray:
	var matched := PackedStringArray()
	if definition(entry_id).get("status") != "implemented":
		return matched
	if event.get("entry_id") != entry_id or event.get("confirmed") != true \
			or event.get("after_scan") != true:
		return matched
	for fact in fact_definitions(entry_id):
		if fact.get("discovery_status") != "experience":
			continue
		var qualifies := true
		for key in fact.evidence:
			if event.get(key) != fact.evidence[key]:
				qualifies = false
				break
		if qualifies:
			matched.append(fact.id)
	return matched


func resolve_stats(entry_id: String, target: Node = null) -> Dictionary:
	var entry := definition(entry_id)
	var result := {"id": entry_id, "values": {}, "errors": [],
		"origin": "live_target" if target != null else "authored_default"}
	if entry.is_empty():
		result.errors.append("Unknown scanner entry: " + entry_id)
		return result
	if target != null:
		var script := target.get_script() as Script
		if script == null or script.resource_path != entry.get("actor_script", ""):
			result.errors.append("Target script does not match " + entry_id)
			return result
	var roots: Dictionary = {}
	var actor: Node = target
	if actor == null and entry.has("default_source"):
		actor = _scene_node(entry.default_source.scene, entry.default_source.get("node", "."), roots, result.errors)
	for stat_id in entry.get("stats", {}):
		var binding: Dictionary = entry.stats[stat_id]
		var value: Variant = null
		match binding.source:
			"actor":
				value = _property(actor, binding.property, result.errors)
			"scene":
				var node := _scene_node(binding.path, binding.get("node", "."), roots, result.errors)
				value = _property(node, binding.property, result.errors)
			"script_constant":
				var script := load(str(binding.path)) as Script
				var constants: Dictionary = script.get_script_constant_map() if script != null else {}
				if not constants.has(binding.constant):
					result.errors.append("Missing constant: " + str(binding.constant))
				else:
					value = constants[binding.constant]
					if binding.get("transform") == "count":
						if value is Array:
							value = value.size()
						else:
							result.errors.append("Count requires an array: " + str(stat_id))
							value = null
			_:
				result.errors.append("Unknown stat source: " + str(binding.source))
		if value == null:
			continue
		result.values[stat_id] = {"value": value, "unit": binding.unit}
		for key in ["balance_status", "target_value", "current_role"]:
			if binding.has(key):
				result.values[stat_id][key] = binding[key]
	for node in roots.values():
		node.free()
	return result


func _scene_node(path: String, node_path: String, roots: Dictionary, errors: Array) -> Node:
	if not roots.has(path):
		var scene := load(path) as PackedScene
		if scene == null:
			errors.append("Missing scene: " + path)
			return null
		roots[path] = scene.instantiate()
	var root: Node = roots[path]
	var node := root.get_node_or_null(NodePath(node_path))
	if node == null:
		errors.append("Missing node: " + path + ":" + node_path)
	return node


func _property(object: Object, path: String, errors: Array) -> Variant:
	var value: Variant = object
	for part in path.split("."):
		if not value is Object or not is_instance_valid(value):
			errors.append("Missing object while reading " + path)
			return null
		var found := false
		for property in value.get_property_list():
			if property.name == part:
				found = true
				break
		if not found:
			errors.append("Missing stat property: " + path)
			return null
		value = value.get(part)
	return value


func validation_errors() -> PackedStringArray:
	var errors := _errors.duplicate()
	for id in entry_ids():
		var entry := definition(id)
		if str(entry.get("game_name", "")).is_empty() or entry.get("kind") not in ["enemy", "boss", "hazard"]:
			errors.append("Invalid scanner identity: " + id)
		if entry.get("status") not in ["implemented", "planned"]:
			errors.append("Invalid scanner status: " + id)
		for set_id in entry.get("fact_sets", []):
			if not _data.get("fact_sets", {}).has(set_id):
				errors.append("Unknown fact set: " + str(set_id))
		var seen := {}
		for fact in fact_definitions(id):
			var fact_id := str(fact.get("id", ""))
			if fact_id.is_empty() or seen.has(fact_id):
				errors.append("Duplicate or empty fact id in " + id)
			seen[fact_id] = true
			if not fact.has("label") or not fact.has("value") or fact.get("evidence", {}).get("event", "").is_empty():
				errors.append("Incomplete fact: " + id + "/" + fact_id)
			if fact.get("discovery_status") not in ["experience", "pending_policy"]:
				errors.append("Invalid discovery status: " + id + "/" + fact_id)
		for stat_id in entry.get("stats", {}):
			var stat: Dictionary = entry.stats[stat_id]
			if not stat.has("unit") or stat.get("source") not in ["actor", "scene", "script_constant"]:
				errors.append("Invalid stat binding: " + id + "/" + str(stat_id))
	return errors
