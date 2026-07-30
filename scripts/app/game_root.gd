extends Node

@onready var level: LevelSession3D = $World/Level01
@onready var completion_label: Label = %CompletionLabel


func _ready() -> void:
	level.run_completed.connect(_on_run_completed)
	level.run_reset.connect(_on_run_reset)


func _on_run_completed() -> void:
	completion_label.visible = true


func _on_run_reset() -> void:
	completion_label.visible = false
