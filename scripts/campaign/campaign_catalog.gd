class_name CampaignCatalog
extends Resource
## Ordered source of truth for campaign levels and level-select presentation.

@export var levels: Array[LevelDefinition] = []


func ordered_levels() -> Array[LevelDefinition]:
	var ordered: Array[LevelDefinition] = []
	ordered.assign(levels)
	ordered.sort_custom(
		func(left: LevelDefinition, right: LevelDefinition) -> bool:
			return left.display_number < right.display_number
	)
	return ordered


func find_by_id(level_id: StringName) -> LevelDefinition:
	for definition in levels:
		if definition != null and definition.level_id == level_id:
			return definition
	return null


func find_by_number(display_number: int) -> LevelDefinition:
	for definition in levels:
		if definition != null and definition.display_number == display_number:
			return definition
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids := {}
	var seen_numbers := {}
	for definition in levels:
		if definition == null:
			errors.append("Campaign catalog contains an empty level entry.")
			continue
		errors.append_array(definition.validation_errors())
		if seen_ids.has(definition.level_id):
			errors.append("Duplicate level_id '%s'." % definition.level_id)
		else:
			seen_ids[definition.level_id] = true
		if seen_numbers.has(definition.display_number):
			errors.append("Duplicate display number %d." % definition.display_number)
		else:
			seen_numbers[definition.display_number] = true
		for prerequisite_id in definition.prerequisite_level_ids:
			if prerequisite_id == definition.level_id:
				errors.append("%s cannot require itself." % definition.level_id)
	for definition in levels:
		if definition == null:
			continue
		for prerequisite_id in definition.prerequisite_level_ids:
			if not seen_ids.has(prerequisite_id):
				errors.append(
					"%s requires unknown level '%s'."
					% [definition.level_id, prerequisite_id]
				)
	return errors
