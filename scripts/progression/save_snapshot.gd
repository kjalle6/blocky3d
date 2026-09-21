class_name SaveSnapshot
extends RefCounted
## Validate disk data before loading scenes or touching live progression.
const VERSION := 1
const LEVEL_SECTIONS := {
	"arrival_shoreline": ["arrival_shoreline"],
	"overgrown_coastal_ascent": ["overgrown_coastal_ascent", "overgrown_coastal_ascent_interior"],
	"dev_green_zone_finale_wip": ["green_zone_finale_outdoors", "green_zone_shooter_area"],
}
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")


static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func string_list(value: Variant, known: Array = []) -> bool:
	if not value is Array or value.size() > 4096:
		return false
	var seen := {}
	for id in value:
		if not (id is String or id is StringName) or str(id).is_empty() or str(id).length() > 200 or seen.has(str(id)):
			return false
		if not known.is_empty() and StringName(id) not in known:
			return false
		seen[str(id)] = true
	return true


static func progress_error(data: Variant) -> String:
	if not data is Dictionary or not whole(data.get("version"), 1, GameProgress.SAVE_VERSION):
		return "Unsupported progress version."
	if not string_list(data.get("completed_levels")) or not string_list(data.get("unlocked_abilities"), PlayerAbility.ALL):
		return "Invalid campaign progress."
	if int(data.version) >= 2:
		if not string_list(data.get("owned_weapons"), PlayerWeapon.ALL) or not string_list(data.get("completed_bosses")):
			return "Invalid permanent unlocks."
		if "knife" not in data.owned_weapons or not whole(data.get("maximum_hp"), 100, 1000000):
			return "Invalid permanent player state."
	return ""


static func player_error(data: Variant) -> String:
	if not data is Dictionary:
		return "Missing player state."
	var hp: Variant = data.get("health")
	if not hp is Dictionary or not whole(hp.get("maximum"), 1, 1000000):
		return "Invalid maximum HP."
	if not whole(hp.get("current"), 1, int(hp.maximum)):
		return "Invalid saved HP."
	if not string_list(data.get("weapons"), PlayerWeapon.ALL) or "knife" not in data.weapons:
		return "Invalid owned weapons."
	if not data.get("equipped_weapon") is String or data.equipped_weapon not in data.weapons:
		return "Invalid equipped weapon."
	if not string_list(data.get("abilities"), PlayerAbility.ALL):
		return "Invalid abilities."
	if not whole(data.get("facing"), -1, 1) or is_zero_approx(float(data.facing)):
		return "Invalid facing."
	if data.has("handgun_ammo"):
		var ammo: Variant = data.handgun_ammo
		# Defer scene-bearing tuning until validation. Preloading it from this
		# autoload dependency loops through the projectile, player and enemy scripts.
		var handgun: FirearmDefinition = load("res://resources/weapons/first_handgun.tres")
		if not ammo is Dictionary or not whole(ammo.get("loaded"), 0, handgun.magazine_capacity):
			return "Invalid loaded handgun ammunition."
		if "handgun" not in data.weapons and int(ammo.loaded) != 0:
			return "Loaded ammunition requires an owned handgun."
	var inventory: Variant = data.get("inventory")
	if not inventory is Dictionary or not inventory.get("quantities") is Dictionary:
		return "Invalid inventory."
	if inventory.quantities.size() > ItemCatalog.ITEMS.size():
		return "Unknown inventory items."
	for id in inventory.quantities:
		if not id is String or ItemCatalog.definition(StringName(id)) == null or not whole(inventory.quantities[id], 1, 2147483647):
			return "Invalid item quantity or identity."
	var slots: Variant = inventory.get("quick_slots")
	if not slots is Array or slots.size() != 2:
		return "Invalid quick slots."
	for id in slots:
		if not (id is String or id is StringName) or (not str(id).is_empty() and ItemCatalog.definition(StringName(id)) == null):
			return "Unknown quick-slot item."
		if not str(id).is_empty() and not ItemCatalog.definition(StringName(id)).quick_usable:
			return "This item cannot be assigned to a quick slot."
	return ""


static func validation_error(data: Variant) -> String:
	if not data is Dictionary or data.get("version") != VERSION:
		return "Unsupported or incomplete save."
	if data.get("kind") not in ["manual", "auto"] or not whole(data.get("slot"), 1, 3):
		return "Invalid save slot."
	if not (data.get("saved_at") is float or data.get("saved_at") is int) or not is_finite(float(data.saved_at)):
		return "Invalid save time."
	if not data.get("level_id") is String or str(data.level_id).is_empty():
		return "Missing level identity."
	if not data.get("section") is String or not REGISTRY.SECTIONS.has(data.section):
		return "Unknown saved section."
	if not LEVEL_SECTIONS.has(data.level_id) or data.section not in LEVEL_SECTIONS[data.level_id]:
		return "This save does not match a known campaign section."
	var position: Variant = data.get("position")
	if not position is Array or position.size() != 3:
		return "Missing safe position."
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 100000:
			return "Invalid safe position."
	if absf(float(position[2])) > 0.001:
		return "Saved position is outside the gameplay plane."
	if not data.get("point_id") is String or str(data.point_id).length() > 200:
		return "Invalid save-point identity."
	var error := player_error(data.get("player"))
	if not error.is_empty():
		return error
	error = progress_error(data.get("progress"))
	if not error.is_empty():
		return error
	for field in ["rewards", "world_flags"]:
		if not data.get(field) is Dictionary:
			return "Invalid world state."
		for key in data[field]:
			if not key is String or key.length() > 240 or not data[field][key] is bool:
				return "Invalid world-state entry."
	return ""
