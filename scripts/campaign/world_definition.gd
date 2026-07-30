class_name WorldDefinition
extends Resource
## Typed campaign grouping. A world owns level order and presentation identity;
## it never owns level geometry or gameplay behavior.

@export var world_id: StringName
@export_range(1, 999, 1) var display_number := 1
@export var title := ""
@export_multiline var description := ""
@export var theme_id: StringName
@export var levels: Array[LevelDefinition] = []


func menu_heading() -> String:
	return "WORLD %d - %s" % [display_number, title.to_upper()]


func ordered_levels() -> Array[LevelDefinition]:
	var ordered: Array[LevelDefinition] = []
	for definition in levels:
		if definition != null:
			ordered.append(definition)
	ordered.sort_custom(
		func(left: LevelDefinition, right: LevelDefinition) -> bool:
			return left.display_number < right.display_number
	)
	return ordered


func find_level_by_id(level_id: StringName) -> LevelDefinition:
	for definition in levels:
		if definition != null and definition.level_id == level_id:
			return definition
	return null


func find_level_by_number(level_number: int) -> LevelDefinition:
	for definition in levels:
		if definition != null and definition.display_number == level_number:
			return definition
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if world_id.is_empty():
		errors.append("World definition requires a stable world_id.")
	if display_number < 1:
		errors.append("%s has an invalid world display number." % world_id)
	if title.strip_edges().is_empty():
		errors.append("%s requires a world title." % world_id)
	if theme_id.is_empty():
		errors.append("%s requires a stable theme_id." % world_id)
	if levels.is_empty():
		errors.append("%s must contain at least one authored level." % world_id)

	var seen_level_ids := {}
	var seen_level_numbers := {}
	for definition in levels:
		if definition == null:
			errors.append("%s contains an empty level entry." % world_id)
			continue
		errors.append_array(definition.validation_errors())
		if seen_level_ids.has(definition.level_id):
			errors.append(
				"%s contains duplicate level_id '%s'."
				% [world_id, definition.level_id]
			)
		else:
			seen_level_ids[definition.level_id] = true
		if seen_level_numbers.has(definition.display_number):
			errors.append(
				"%s contains duplicate level number %d."
				% [world_id, definition.display_number]
			)
		else:
			seen_level_numbers[definition.display_number] = true
		for prerequisite_id in definition.prerequisite_level_ids:
			if prerequisite_id == definition.level_id:
				errors.append("%s cannot require itself." % definition.level_id)
	return errors
