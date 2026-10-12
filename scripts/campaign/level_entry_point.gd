class_name LevelEntryPoint
extends Resource
## A menu shortcut into an authored section of the same level. The owning
## definition supplies its movement kit and progression policy.

@export var entry_id: StringName
@export var title := ""
@export var scene: PackedScene
## Weapons the player would have collected earlier in the level by this point.
@export var starting_weapons: Array[StringName] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if entry_id.is_empty():
		errors.append("Level entry point requires a stable entry_id.")
	if title.strip_edges().is_empty():
		errors.append("Level entry point requires a menu title.")
	if scene == null:
		errors.append("Level entry point requires a PackedScene.")
	for weapon_id in starting_weapons:
		if not PlayerWeapon.is_known(weapon_id):
			errors.append("Level entry point names unknown weapon '%s'." % weapon_id)
	return errors
