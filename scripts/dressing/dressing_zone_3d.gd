class_name DressingZone3D
extends Node3D
## Designer-authored visual intent. It never changes collision or gameplay.

enum Intent {
	LANDMARK,
	GROUND_CLUSTER,
	EDGE_ACCENT,
	REAR_MASS,
	QUIET,
}

@export var zone_id: StringName
@export var intent := Intent.GROUND_CLUSTER
@export_range(0.0, 1.0, 0.05) var density := 0.5
@export var deterministic_seed := 1
@export var size := Vector2(4.0, 2.0)
@export var protected_rects: Array[Rect2] = []


func world_rect() -> Rect2:
	return Rect2(
		Vector2(global_position.x, global_position.y) - size * 0.5,
		size
	)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if zone_id.is_empty():
		errors.append("Dressing zone requires an id.")
	if size.x <= 0.0 or size.y <= 0.0:
		errors.append("Dressing zone '%s' requires a positive size." % zone_id)
	return errors
