class_name LevelTransition3D
extends Area3D
## A doorway that hands the run to another level behind a fade.
##
## This is deliberately not a goal. A goal ends a run and marks progress; a
## transition is a threshold inside a journey — running into a cave mouth, a
## door, or a tunnel — where the space on the other side is authored as its own
## scene rather than joined to this one geometrically.
##
## Joining two terrain grammars along a seam was the alternative, and it makes
## the boundary the hardest thing in the level. A fade makes it free.

signal entered(target: LevelDefinition)

@export var target_level: LevelDefinition


func _ready() -> void:
	add_to_group("level_transition")
	body_entered.connect(_on_body_entered)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_level == null:
		errors.append("Level transition requires a target level definition.")
	return errors


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		entered.emit(target_level)
