class_name LevelGoal3D
extends Area3D

signal reached(body: PlayerCharacter)


func _ready() -> void:
	add_to_group("level_goal")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		reached.emit(body)
