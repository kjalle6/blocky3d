extends RefCounted
## Deliberate opt-in: scene identity and palette are never supplied by a save.

const SECTIONS := {
	"sandbox": "res://scenes/dev/level_designer_sandbox.tscn",
	"green_zone_finale_outdoors": "res://scenes/dev/green_zone_finale_wip.tscn",
	"designer_fixture": "res://scenes/dev/level_designer_fixture.tscn",
	"arrival_shoreline": "res://scenes/levels/arrival_shoreline.tscn",
	"overgrown_coastal_ascent": "res://scenes/levels/overgrown_coastal_ascent.tscn",
	"overgrown_coastal_ascent_interior": "res://scenes/levels/overgrown_coastal_ascent_interior.tscn",
	"green_zone_shooter_area": "res://scenes/dev/green_zone_finale_shooter_area_wip.tscn",
	"level_design_lab": "res://scenes/dev/level_design_lab.tscn",
	"animation_lab": "res://scenes/dev/animation_lab.tscn",
}
const TITLES := {"sandbox": "Sandbox", "green_zone_finale_outdoors": "Level 3 outdoors", "designer_fixture": "Test fixture", "arrival_shoreline": "Level 1", "overgrown_coastal_ascent": "Level 2 outdoors", "overgrown_coastal_ascent_interior": "Level 2 cave", "green_zone_shooter_area": "Level 3 gun encounter", "level_design_lab": "Level design lab", "animation_lab": "Animation lab"}
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const STYLES := {
	"grass": preload("res://resources/presentation/platform_styles/green_zone.tres"),
	"sand": preload("res://resources/presentation/platform_styles/shoreline_sand.tres"),
}
const STRUCTURAL_SCRIPTS := [
	"res://resources/level_scenery.json",
	"res://scripts/enemies/route_gunner_3d.gd",
	"res://scripts/enemies/tank_enemy_3d.gd",
	"res://scripts/props/breakable_crate_3d.gd",
	"res://scripts/props/wall_jump_scaffold_3d.gd",
	"res://scripts/developer/level_layout_objects.gd",
	"res://scripts/pickups/item_reward_3d.gd",
	"res://scripts/presentation/pixel_platform_3d.gd",
	"res://scripts/hazards/pixel_spike_row_3d.gd",
	"res://scripts/enemies/stompable_enemy_3d.gd",
	"res://scripts/level/level_checkpoint_3d.gd",
	"res://scripts/developer/level_object_catalog.gd",
	"res://scripts/developer/level_catalog_tile_3d.gd",
	"res://scripts/developer/level_catalog_animation.gd",
	"res://scripts/enemies/handgun_enemy_3d.gd",
	"res://scripts/enemies/hovering_hazard_3d.gd",
]

static func can_author() -> bool:
	return OS.has_feature("editor") and not OS.has_feature("blocky_export")

static func section_for(node: Node) -> String:
	var section := str(node.get_meta("layout_section", ""))
	return section if SECTIONS.has(section) else ""

static func save_path(section: String) -> String:
	return "res://resources/level_layouts/%s.json" % section if SECTIONS.has(section) else ""

static func fingerprint(section: String) -> String:
	var sources: Dictionary = {}
	_collect_scenes(SECTIONS.get(section, ""), sources)
	for entry in CATALOG.ENTRIES.values():
		if entry.has("scene"): _collect_scenes(entry.scene, sources)
	for path in STRUCTURAL_SCRIPTS:
		sources[path] = FileAccess.get_sha256(path)
	for style in STYLES.values():
		sources[style.resource_path] = FileAccess.get_sha256(style.resource_path)
	return JSON.stringify(sources, "", true).sha256_text()

static func _collect_scenes(path: String, sources: Dictionary) -> void:
	if path.is_empty() or sources.has(path):
		return
	sources[path] = FileAccess.get_sha256(path)
	var expression := RegEx.new()
	expression.compile('path="(res://[^"\\n]+\\.tscn)"')
	for found in expression.search_all(FileAccess.get_file_as_string(path)):
		_collect_scenes(found.get_string(1), sources)
