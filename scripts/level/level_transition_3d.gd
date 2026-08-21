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

signal entered(transition: LevelTransition3D)

enum SourceExitMode {
	STOP,
	RUN,
	HIDE,
}

@export var target_level: LevelDefinition
@export_category("Matched run handoff")
@export var source_exit_mode: SourceExitMode = SourceExitMode.STOP
@export var run_destination_during_fade_in := false
@export_range(-1.0, 1.0, 1.0) var run_direction := 1.0
@export_range(0.1, 20.0, 0.1, "or_greater") var run_speed := 8.0
@export_range(0.05, 2.0, 0.01, "or_greater") var run_duration := 0.45


func _ready() -> void:
	add_to_group("level_transition")
	body_entered.connect(_on_body_entered)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_level == null:
		errors.append("Level transition requires a target level definition.")
	if source_exit_mode == SourceExitMode.RUN or run_destination_during_fade_in:
		if not is_equal_approx(absf(run_direction), 1.0):
			errors.append("Matched transition direction must be -1 or 1.")
		if run_speed <= 0.0:
			errors.append("Matched transition speed must be positive.")
		if run_duration <= 0.0:
			errors.append("Matched transition duration must be positive.")
	return errors


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		entered.emit(self)
