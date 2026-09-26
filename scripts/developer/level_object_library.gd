extends RefCounted
## Browser organization is separate from the saved catalog/runtime contract.
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const CATEGORIES := ["All objects", "Blocks", "Enemies", "Hazards", "Autosaves", "Supplies", "Decorations", "Animated scenery"]

static func category(entry: Dictionary) -> String:
	return "Blocks" if entry.kind == "tile" else str(entry.category)

static func matches(entry: Dictionary, zone: String, group: String, query: String) -> bool:
	# Existing rectangular platforms still load and remain editable. New building
	# uses blocks; do not offer a second platform creation workflow in the browser.
	if entry.kind == "platform": return false
	return (zone == "All zones" or entry.zone == zone) and (group == "All objects" or category(entry) == group) and (query.strip_edges().is_empty() or (str(entry.name) + " " + str(entry.zone) + " " + str(entry.description)).to_lower().contains(query.strip_edges().to_lower().replace("block", "tile")))

static func title(id: String) -> String:
	return str(CATALOG.ENTRIES[id].name).replace(" tile ", " block ")

static func defaults(id: String) -> Dictionary:
	var values := CATALOG.defaults(id)
	var entry: Dictionary = CATALOG.ENTRIES[id]
	if entry.kind == "tile": values.surface = entry.get("surface", values.surface)
	return values

static func description(id: String) -> String:
	var entry: Dictionary = CATALOG.ENTRIES[id]
	if entry.kind == "tile":
		return ("Solid block." if entry.solid else "Scenery block. Players and bullets pass through it.") + " Click or drag to build. The brush stays active until you press Esc or right-click."
	return entry.description
