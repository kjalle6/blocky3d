extends Node3D
## Position-based room selection also works during jumps, teleports and respawns.
@export var environment: StringName = &"underground"
@export var size := Vector2(64.0, 28.16)
@export var priority := 0

func _ready() -> void:
	add_to_group("audio_environment_region")

func contains_world_position(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5
