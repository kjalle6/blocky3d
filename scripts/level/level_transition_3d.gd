class_name LevelTransition3D
extends Area3D
## A threshold that hands the run to another level or section behind a fade.
##
## Most transitions continue one journey without completing it. A campaign
## boundary may explicitly complete its source level while preserving a matched
## run into the next level, avoiding a completion overlay between connected
## spaces.
##
## Joining two terrain grammars along a seam was the alternative, and it makes
## the boundary the hardest thing in the level. A fade makes it free.

signal entered(transition: LevelTransition3D)

enum SourceExitMode {
	STOP,
	RUN,
	HIDE,
}

@export_category("Destination")
@export var target_level: LevelDefinition
@export var target_scene: PackedScene
@export var completes_source_level := false
@export_category("Interstitial")
@export var interstitial_scene: PackedScene
@export_category("Matched run handoff")
@export var source_exit_mode: SourceExitMode = SourceExitMode.STOP
@export var run_destination_during_fade_in := false
@export_range(-1.0, 1.0, 1.0) var run_direction := 1.0
@export_range(0.1, 20.0, 0.1, "or_greater") var run_speed := 8.0
@export_range(0.05, 2.0, 0.01, "or_greater") var run_duration := 0.45


func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self): return
	add_to_group("level_transition")
	body_entered.connect(_on_body_entered)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_level == null and target_scene == null:
		errors.append("Level transition requires a target level or target scene.")
	elif target_level != null and target_scene != null:
		errors.append("Level transition cannot target a level and scene together.")
	if completes_source_level and target_level == null:
		errors.append("Only a transition to another level can complete its source level.")
	if target_scene != null:
		var section := target_scene.instantiate()
		if not section is LevelSession3D:
			errors.append("Transition target scene must instantiate a LevelSession3D.")
		section.free()
	if interstitial_scene != null:
		var interstitial := interstitial_scene.instantiate()
		if not interstitial is LevelInterstitial3D:
			errors.append(
				"Transition interstitial must instantiate a LevelInterstitial3D."
			)
		interstitial.free()
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
