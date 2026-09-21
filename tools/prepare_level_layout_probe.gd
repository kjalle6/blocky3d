extends SceneTree
## Creates one disposable fixture save for a subsequent process / export check.
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const PATH := "res://resources/level_layouts/designer_fixture.json"

func _init() -> void:
	var scene := load("res://scenes/dev/level_designer_fixture.tscn") as PackedScene
	var base := scene.instantiate()
	var document := DOCUMENT.new()
	var error: String = document.open(base, {})
	base.free()
	if error.is_empty() and FileAccess.file_exists(PATH): error = "A fixture save already exists; preserve it before preparing this probe."
	if error.is_empty():
		document.working.fixture_platform.values.x = 25.6
		document.working.fixture_skater.values.x = 35.84
		document.working.fixture_checkpoint.values.x = 28.8
		document.working["platform_probe"] = DOCUMENT.new_platform_record({"x": 50.56, "y": 1.92, "width": 5.12, "height": 1.28,
			"style": "sand", "surface": "sand", "left_cap": true, "right_cap": true, "bottom_cap": true})
		var x := 58.88
		for template in ["skater_enemy", "gunner_enemy", "spike_row", "flying_hazard", "checkpoint", "bush", "gz_tile_42", "gz_tile_75", "gz_animated_fountain", "gz_prop_other_tree1", "supply_chest"]:
			var values := CATALOG.defaults(template)
			values.x = x
			values.y = 3.84 if template == "flying_hazard" else float(CATALOG.ENTRIES[template].get("feet", 0))
			document.working["object_probe_" + template] = OBJECTS.new_record(template, values)
			x += 2.56
		error = STORE.save(document)
	if not error.is_empty():
		printerr(error)
		quit(1)
	else:
		print("Disposable fixture save prepared for a fresh-process reload.")
		quit(0)
