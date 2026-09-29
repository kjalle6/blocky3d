extends SceneTree
## Promote original passive scenery into exact, reusable designer templates.
## Run deliberately when adding legacy scene sprites; saved layouts require review.
const REGISTRY = preload("res://scripts/developer/level_layout_registry.gd")
const MAP_PATH := "res://resources/level_scenery.json"
const CATALOG_PATH := "res://resources/level_catalogs/authored_scenery.json"
const SCENE_DIR := "res://scenes/props/authored_scenery"

func _init() -> void:
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH)) if FileAccess.file_exists(MAP_PATH) else {}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) if FileAccess.file_exists(CATALOG_PATH) else {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var count := 0
	for section in REGISTRY.SECTIONS:
		var root: Node = load(REGISTRY.SECTIONS[section]).instantiate()
		if not mapping.has(section): mapping[section] = {}
		for candidate in root.find_children("*", "Sprite3D", true, false):
			var sprite := candidate as Sprite3D
			if not _is_scenery(sprite, root): continue
			var path := str(root.get_path_to(sprite))
			if mapping[section].has(path): continue
			var texture: Texture2D = sprite.texture
			var region := Rect2()
			if texture is AtlasTexture:
				region = texture.region
				texture = texture.atlas
			# Keep native scale, color, depth, crop and all Sprite3D presentation.
			var visual := sprite.duplicate() as Sprite3D
			visual.name = "AuthoredScenery"
			visual.position.x = 0.0
			visual.position.y = 0.0
			visual.flip_h = false
			var packed := PackedScene.new()
			assert(packed.pack(visual) == OK)
			var temporary := "res://build/authored_scenery_template.tscn"
			assert(ResourceSaver.save(packed, temporary) == OK)
			var identity := FileAccess.get_sha256(temporary).left(16)
			var template := "authored_scenery_" + identity
			var scene_path := SCENE_DIR.path_join(identity + ".tscn")
			assert(ResourceSaver.save(packed, scene_path) == OK)
			var rect := sprite.get_item_rect()
			var bounds := Rect2()
			for corner in [rect.position, Vector2(rect.end.x,rect.position.y), rect.end,Vector2(rect.position.x,rect.end.y)]:
				var point: Vector3 = sprite.basis * Vector3(corner.x,-corner.y,0) * sprite.pixel_size
				var xy := Vector2(point.x,point.y)
				bounds = Rect2(xy,Vector2.ZERO) if corner == rect.position else bounds.expand(xy)
			var entry := {"name":str(sprite.name).capitalize(),
				"zone":"Green Zone", "category":"Decorations", "kind":"decoration", "authored_sprite":true,
				"scene":scene_path,"image":texture.resource_path,"anchor":"ground","feet":-bounds.position.y,
				"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
				"description":"Original scenery, with its authored scale and appearance. Move, flip, duplicate or remove freely."}
			if region.has_area(): entry.frame_region = [region.position.x,region.position.y,region.size.x,region.size.y]
			catalog[template] = entry
			mapping[section][path] = {"id":"scenery_" + path.sha256_text().left(20), "template":template}
			visual.free()
			count += 1
		root.free()
	for pair in [[MAP_PATH,mapping],[CATALOG_PATH,catalog]]:
		var file := FileAccess.open(pair[0],FileAccess.WRITE)
		file.store_string(JSON.stringify(pair[1],"\t",true,true) + "\n")
	print("Prepared %d original scenery objects; %d reusable appearances." % [count,catalog.size()])
	quit()

func _is_scenery(sprite: Sprite3D, root: Node) -> bool:
	if sprite.texture == null or sprite.get_script() != null or sprite.has_meta("layout_id") or sprite.get_child_count() != 0: return false
	var texture: Texture2D = sprite.texture.atlas if sprite.texture is AtlasTexture else sprite.texture
	if not "/props/" in texture.resource_path or "/cave_lift/" in texture.resource_path: return false
	var parent := sprite.get_parent()
	while parent != root:
		# Collision assemblies, pickups and actor sprites are gameplay components.
		if parent is CollisionObject3D or parent.has_meta("layout_id"): return false
		parent = parent.get_parent()
	return true
