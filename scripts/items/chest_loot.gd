extends RefCounted
## Data-driven supplies. A local RNG leaves combat and cosmetic randomness alone.
const DATA_PATH := "res://resources/loot/chest_pools.json"
const LEVEL_POOLS := {
	"arrival_shoreline": "shoreline",
	"overgrown_coastal_ascent": "green_zone",
	"dev_green_zone_finale_wip": "firearms",
}
static var pools: Dictionary = _load_pools()

static func _load_pools() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data is Dictionary, "Missing chest loot pools.")
	for id in data:
		var pool: Dictionary = data[id]
		assert(pool.bonus_chance >= 0.0 and pool.bonus_chance <= 1.0 and not pool.entries.is_empty())
		var seen := {}
		var unconditional := false
		for entry in pool.entries:
			assert(ItemCatalog.definition(StringName(entry.item)) != null and not seen.has(entry.item))
			assert(entry.weight > 0 and SaveSnapshot.whole(entry.minimum, 1, 999) and SaveSnapshot.whole(entry.maximum, entry.minimum, 999))
			assert(not entry.has("weapon") or PlayerWeapon.is_known(StringName(entry.weapon)))
			unconditional = unconditional or not entry.has("weapon")
			seen[entry.item] = true
		assert(unconditional, "A pool needs a reward before any weapon is unlocked.")
	return data

static func pool_for_level(level_id: StringName) -> String:
	return LEVEL_POOLS.get(str(level_id), "shoreline")

static func roll(pool_id: String, campaign_seed: int, source_id: String, weapons: Array) -> Dictionary:
	assert(pools.has(pool_id), "Unknown chest loot pool.")
	var pool: Dictionary = pools[pool_id]
	var eligible: Array = []
	for entry in pool.entries:
		if not entry.has("weapon") or StringName(entry.weapon) in weapons:
			eligible.append(entry)
	# Full stable identity, not node order, process RNG state, time, or attempts.
	var rng := RandomNumberGenerator.new()
	rng.seed = (str(campaign_seed) + "/" + source_id + "/" + pool_id).sha256_text().substr(0, 15).hex_to_int()
	var contents := {}
	_draw(eligible, rng, contents)
	if rng.randf() < float(pool.bonus_chance) and not eligible.is_empty():
		_draw(eligible, rng, contents)
	return contents

static func _draw(entries: Array, rng: RandomNumberGenerator, contents: Dictionary) -> void:
	var total := 0.0
	for entry in entries: total += float(entry.weight)
	var target := rng.randf() * total
	var selected := entries.size() - 1
	for index in entries.size():
		target -= float(entries[index].weight)
		if target <= 0.0:
			selected = index
			break
	var entry: Dictionary = entries.pop_at(selected)
	contents[StringName(entry.item)] = rng.randi_range(int(entry.minimum), int(entry.maximum))
