class_name Hazard3D
extends Area3D
## Reusable lethal contact. Presentation and collision remain authored by the
## owning scene so future spikes are not forced into one primitive shape.


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		body.kill()


func _on_area_entered(area: Area3D) -> void:
	if not area.is_in_group("player_hazard_contact"):
		return
	var player := area.get_parent() as PlayerCharacter
	if player != null:
		player.kill()
