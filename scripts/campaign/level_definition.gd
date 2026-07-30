class_name LevelDefinition
extends Resource
## Authored campaign metadata. Runtime code resolves levels through this
## resource instead of branching on level numbers.

@export var level_id: StringName
@export_range(1, 999, 1) var display_number := 1
@export var title := ""
@export_multiline var lesson := ""
@export var scene: PackedScene
@export var available_abilities: Array[StringName] = []
@export var assumed_owned_abilities: Array[StringName] = []
@export var required_abilities: Array[StringName] = []
@export var prerequisite_level_ids: Array[StringName] = []


func menu_label() -> String:
	return "%d  -  %s" % [display_number, title.to_upper()]


func heading() -> String:
	return "LEVEL %d - %s" % [display_number, title.to_upper()]


func offers_ability(ability_id: StringName) -> bool:
	return ability_id in available_abilities


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if level_id.is_empty():
		errors.append("Level definition requires a stable level_id.")
	if display_number < 1:
		errors.append("%s has an invalid display number." % level_id)
	if title.strip_edges().is_empty():
		errors.append("%s requires a title." % level_id)
	if scene == null:
		errors.append("%s requires a PackedScene." % level_id)
	for ability_id in available_abilities:
		if not PlayerAbility.is_known(ability_id):
			errors.append("%s offers unknown ability '%s'." % [level_id, ability_id])
	for ability_id in assumed_owned_abilities:
		if not PlayerAbility.is_known(ability_id):
			errors.append("%s assumes unknown ability '%s'." % [level_id, ability_id])
		elif ability_id not in available_abilities:
			errors.append(
				"%s assumes ability '%s' without making it available."
				% [level_id, ability_id]
			)
	for ability_id in required_abilities:
		if not PlayerAbility.is_known(ability_id):
			errors.append("%s requires unknown ability '%s'." % [level_id, ability_id])
		elif ability_id not in available_abilities:
			errors.append(
				"%s requires ability '%s' without making it available."
				% [level_id, ability_id]
			)
	return errors
