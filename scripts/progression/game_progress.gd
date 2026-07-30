class_name GameProgress
extends RefCounted
## Versioned, engine-independent campaign progress payload.

const SAVE_VERSION := 1

var completed_level_ids: Array[StringName] = []
var unlocked_ability_ids: Array[StringName] = []


func complete_level(level_id: StringName) -> bool:
	if level_id.is_empty() or level_id in completed_level_ids:
		return false
	completed_level_ids.append(level_id)
	return true


func has_completed(level_id: StringName) -> bool:
	return level_id in completed_level_ids


func unlock_ability(ability_id: StringName) -> bool:
	assert(PlayerAbility.is_known(ability_id), "Cannot unlock an unknown ability.")
	if ability_id in unlocked_ability_ids:
		return false
	unlocked_ability_ids.append(ability_id)
	return true


func owns_ability(ability_id: StringName) -> bool:
	return ability_id in unlocked_ability_ids


func to_dictionary() -> Dictionary:
	var completed: Array[String] = []
	for level_id in completed_level_ids:
		completed.append(String(level_id))
	var abilities: Array[String] = []
	for ability_id in unlocked_ability_ids:
		abilities.append(String(ability_id))
	return {
		"version": SAVE_VERSION,
		"completed_levels": completed,
		"unlocked_abilities": abilities,
	}


static func from_dictionary(data: Dictionary) -> GameProgress:
	var loaded := GameProgress.new()
	if int(data.get("version", -1)) != SAVE_VERSION:
		return loaded
	var completed_value: Variant = data.get("completed_levels", [])
	if completed_value is Array:
		for value in completed_value:
			var level_id := StringName(str(value))
			if not level_id.is_empty() and level_id not in loaded.completed_level_ids:
				loaded.completed_level_ids.append(level_id)
	var abilities_value: Variant = data.get("unlocked_abilities", [])
	if abilities_value is Array:
		for value in abilities_value:
			var ability_id := StringName(str(value))
			if (
				PlayerAbility.is_known(ability_id)
				and ability_id not in loaded.unlocked_ability_ids
			):
				loaded.unlocked_ability_ids.append(ability_id)
	return loaded
