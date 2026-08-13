class_name VerticalCameraRegion3D
extends Node3D
## Scene-authored volume that enables vertical camera framing for one route
## section. It contains no physics state: the camera evaluates the target's
## world position directly, so teleports and checkpoint resets are deterministic.

@export var size := Vector2(24.0, 32.0)
@export var vertical_anchor_y := 0.7
@export var minimum_vertical_offset := 0.0
@export var maximum_vertical_offset := 24.0
@export var priority := 0


func contains_world_position(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	return (
		absf(local_position.x) <= size.x * 0.5
		and absf(local_position.y) <= size.y * 0.5
	)


func vertical_anchor_world_y() -> float:
	return global_position.y + vertical_anchor_y


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if size.x <= 0.0 or size.y <= 0.0:
		errors.append("Vertical camera region size must be positive.")
	if maximum_vertical_offset < minimum_vertical_offset:
		errors.append(
			"Vertical camera region maximum offset must not be below its minimum."
		)
	return errors
