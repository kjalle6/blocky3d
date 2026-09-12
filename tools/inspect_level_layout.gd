extends SceneTree
## Codex and authoring tools inspect the same effective values the game loads.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")

func _init() -> void:
	var report := {}
	var failed := false
	for section in REGISTRY.SECTIONS:
		var packed := ResourceLoader.load(REGISTRY.SECTIONS[section], "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var base := packed.instantiate()
		var document := DOCUMENT.new()
		var saved := STORE.read(REGISTRY.save_path(section))
		var error: String = saved.error if not saved.error.is_empty() else document.open(base, saved.data, saved.hash)
		base.free()
		var objects := {}
		for id in document.working:
			var record: Dictionary = document.working[id]
			objects[id] = {"kind": record.kind, "template": record.get("template", ""), "path_hint": record.path, "values": record.values,
				"created": record.created, "removable": record.removable}
		report[section] = {"scene": REGISTRY.SECTIONS[section], "layout": REGISTRY.save_path(section),
			"error": error, "revision": document.revision, "objects": objects}
		failed = failed or not error.is_empty()
		print("%s: %s" % [section, "%d supported objects, revision %d" % [objects.size(), document.revision] if error.is_empty() else error])
	var output := FileAccess.open("res://build/level_layouts_resolved.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	output.close()
	print("Resolved layout report: build/level_layouts_resolved.json")
	quit(1 if failed else 0)
