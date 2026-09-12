class_name Hazard3D
extends Area3D
## Reusable lethal contact. Presentation and collision remain authored by the
## owning scene so future spikes are not forced into one primitive shape.

@export var death_kind := PlayerCharacter.DEATH_KIND_GENERIC
## Optional node whose height this hazard follows, for a surface that is not at
## a fixed world height - water drawn by a camera-locked vista, say. Without it
## the hazard would be correct for one instant of a fall and wrong for the rest.
@export var height_source_path: NodePath
@export var height_source_offset := 0.0

var _height_source: Node3D


func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self): return
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_height_source = get_node_or_null(height_source_path) as Node3D
	set_process(_height_source != null)


func _process(_delta: float) -> void:
	global_position.y = _height_source.global_position.y + height_source_offset


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		body.kill(death_kind)


func _on_area_entered(area: Area3D) -> void:
	if not area.is_in_group("player_hazard_contact"):
		return
	var player := area.get_parent() as PlayerCharacter
	if player != null:
		player.kill(death_kind)
