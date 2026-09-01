class_name LevelGoal3D
extends Area3D

signal reached(body: PlayerCharacter)

@export var trigger_on_body_entry := true


func _ready() -> void:
	add_to_group("level_goal")
	body_entered.connect(_on_body_entered)


## Scripted exits such as the cave lift can keep the ordinary completion
## contract without exposing a live floor trigger before their animation begins.
func reach(body: PlayerCharacter) -> void:
	if body == null:
		return
	reached.emit(body)


func _on_body_entered(body: Node3D) -> void:
	if trigger_on_body_entry and body is PlayerCharacter:
		reach(body as PlayerCharacter)
