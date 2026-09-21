extends RefCounted
## Prepared gameplay objects only. Saves refer to these IDs, never asset paths.
const CORE_ENTRIES := {
	"grass_platform": {"name": "Grass platform", "category": "Platforms", "kind": "platform", "style": "grass", "description": "Solid grass blocks. Choose a size, then click to place.", "anchor": "ground"},
	"sand_platform": {"name": "Sand platform", "category": "Platforms", "kind": "platform", "style": "sand", "description": "Solid sand blocks with the sand footstep sound.", "anchor": "ground"},
	"patrol_enemy": {"name": "Patrol enemy", "category": "Enemies", "kind": "enemy", "scene": "res://scenes/enemies/pixel_patrol_enemy.tscn", "image": "res://assets/art/green_zone/enemies/green_idle.png", "frames": 4, "description": "Walks, turns at edges, and attacks nearby players. Edit its patrol after placing.", "anchor": "ground", "feet": 0.38},
	"skater_enemy": {"name": "Skater", "category": "Enemies", "kind": "enemy", "scene": "res://scenes/enemies/pixel_skater_enemy.tscn", "image": "res://assets/art/green_zone/enemies/skater/Idle.png", "frames": 0, "description": "The skating melee enemy, including its attack and death animations.", "anchor": "ground", "feet": 0.38},
	"gunner_enemy": {"name": "Dual-gun enemy", "category": "Enemies", "kind": "gunner", "scene": "res://scenes/enemies/handgun_enemy.tscn", "image": "res://assets/art/green_zone/enemies/handgun_idle.png", "frames": 4, "description": "A stationary gunner with the existing aiming, firing, and projectile behaviour.", "anchor": "ground", "feet": 0.55},
	"spike_row": {"name": "Spikes", "category": "Hazards", "kind": "spikes", "scene": "res://scenes/hazards/pixel_spike_row.tscn", "image": "res://assets/art/shared/hazards/spike.svg", "description": "A lethal spike row. Adjust its width after placing.", "anchor": "ground"},
	"flying_hazard": {"name": "Flying machine", "category": "Hazards", "kind": "flyer", "scene": "res://scenes/enemies/green_zone_flyer.tscn", "image": "res://assets/art/green_zone/enemies/flyer_idle.png", "frames": 4, "description": "An indestructible flying hazard. Its existing bob and electrical discharge stay active.", "anchor": "air"},
	"checkpoint": {"name": "Autosave point", "category": "Autosaves", "kind": "checkpoint", "scene": "res://scenes/level/level_checkpoint.tscn", "description": "Stand safely here to autosave without healing. The marked area is visible only in the designer.", "anchor": "ground"},
	"bush": {"name": "Bush", "category": "Decorations", "kind": "decoration", "image": "res://assets/art/green_zone/props/bush.png", "description": "Scenery only. Players and projectiles pass through it.", "anchor": "ground"},
	"stone": {"name": "Small stone", "category": "Decorations", "kind": "decoration", "image": "res://assets/art/green_zone/props/stone_small.png", "description": "A small scenery stone. It does not block movement or bullets.", "anchor": "ground"},
	"tree": {"name": "Small tree", "category": "Decorations", "kind": "decoration", "image": "res://assets/art/green_zone/props/tree_small_grounded.png", "description": "A tree drawn at the game's native pixel scale. Scenery only.", "anchor": "ground"},
	"bench": {"name": "Bench", "category": "Decorations", "kind": "decoration", "image": "res://assets/art/green_zone/props/bench.png", "description": "A decorative bench. It is not a platform or bullet cover.", "anchor": "ground"},
}
const CATEGORIES := ["All objects", "Platforms", "Enemies", "Hazards", "Autosaves", "Decorations", "Terrain tiles", "Scenery tiles", "Animated scenery"]
static var PACK_PATHS: Array[String] = _pack_paths()
static var ENTRIES: Dictionary = _load_entries()
static var _icons: Dictionary = {}

static func _pack_paths() -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at("res://resources/level_catalogs"):
		if file.ends_with(".json"): paths.append("res://resources/level_catalogs/" + file)
	paths.sort()
	return paths

static func _load_entries() -> Dictionary:
	var entries := CORE_ENTRIES.duplicate(true)
	for id in entries:
		entries[id].zone = "Beach" if id == "sand_platform" else "Shared" if id in ["checkpoint", "spike_row"] else "Green Zone"
	for path in _pack_paths():
		var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(pack is Dictionary, "Invalid asset catalog: " + path)
		for id in pack:
			assert(not entries.has(id), "Repeated catalog ID: " + id)
			entries[id] = pack[id]
	return entries

static func signatures(ids: Array, from_disk := false) -> Dictionary:
	var entries := _load_entries() if from_disk else ENTRIES
	var result := {}
	for id in ids:
		if result.has(id): continue
		if not entries.has(id):
			result[id] = "missing"
			continue
		var definition: Dictionary = entries[id].duplicate(true)
		# Display labels and extra unrelated catalog entries do not change a level.
		for key in ["name", "description", "category", "zone"]: definition.erase(key)
		if definition.has("image"): definition["image_hash"] = FileAccess.get_sha256(definition.image)
		result[id] = JSON.stringify(definition, "", true, true).sha256_text()
	return result

static func zones() -> Array[String]:
	var result: Array[String] = ["All zones"]
	for entry in ENTRIES.values():
		if entry.zone not in result: result.append(entry.zone)
	return result

static func matches(entry: Dictionary, zone: String, category: String, query: String) -> bool:
	return (zone == "All zones" or entry.zone == zone) and (category == "All objects" or entry.category == category) and (query.strip_edges().is_empty() or (entry.name + " " + entry.description).to_lower().contains(query.strip_edges().to_lower()))

static func defaults(id: String) -> Dictionary:
	var entry: Dictionary = ENTRIES[id]
	var values := {"x": 0.0, "y": 0.0}
	match entry.kind:
		"platform": values.merge({"width": 5.12, "height": 1.28, "style": entry.style, "surface": entry.style, "left_cap": true, "right_cap": true, "bottom_cap": true})
		"enemy": values.merge({"speed": 2.0, "left": 2.56, "right": 2.56, "facing_right": false})
		"gunner": values.facing_right = false
		"spikes": values.width = 2.56
		"checkpoint": values.merge({"width": 2.4, "height": 2.2})
		"decoration": values.flip_h = false
		"tile": values.merge({"flip_h": false, "surface": "grass" if entry.solid else "silent"})
	return values

static func icon(id: String) -> Texture2D:
	if _icons.has(id): return _icons[id]
	var entry: Dictionary = ENTRIES[id]
	if not entry.has("image"): return null
	var texture := load(entry.image) as Texture2D
	var frames := int(entry.get("frames", 1))
	var frame_width := texture.get_width() / frames if frames > 0 else texture.get_height()
	var region := Rect2i(0, 0, frame_width, texture.get_height())
	if entry.has("frame_region"):
		var r: Array = entry.frame_region
		region = Rect2i(r[0], r[1], r[2], r[3])
	# Trim the empty sheet margins for readable cards and grounded decorations.
	var pixels := texture.get_image()
	if pixels != null and entry.get("crop", true) and not entry.has("frame_region"):
		if pixels.is_compressed(): pixels.decompress()
		var used := pixels.get_region(region).get_used_rect()
		if used.has_area(): region = used
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	_icons[id] = atlas
	return atlas
