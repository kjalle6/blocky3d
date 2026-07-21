class_name Hazard3D
extends Area3D
## Reusable lethal contact. Presentation and collision remain authored by the
## owning scene so future spikes are not forced into one primitive shape.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		body.kill()
