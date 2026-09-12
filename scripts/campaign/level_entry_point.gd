class_name LevelEntryPoint
extends Resource
## A menu shortcut into an authored section of the same level. The owning
## definition supplies its movement kit and progression policy.

@export var entry_id: StringName
@export var title := ""
@export var scene: PackedScene


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if entry_id.is_empty():
		errors.append("Level entry point requires a stable entry_id.")
	if title.strip_edges().is_empty():
		errors.append("Level entry point requires a menu title.")
	if scene == null:
		errors.append("Level entry point requires a PackedScene.")
	return errors
