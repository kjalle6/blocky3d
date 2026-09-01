class_name VerticalCameraRegion3D
extends Node3D
## Scene-authored volume that enables vertical camera framing for one route
## section. It contains no physics state: the camera evaluates the target's
## world position directly, so teleports and checkpoint resets are deterministic.

@export var size := Vector2(24.0, 32.0)
@export var vertical_framing_enabled := true
@export var vertical_anchor_y := 0.7
@export var minimum_vertical_offset := 0.0
@export var maximum_vertical_offset := 24.0
@export var priority := 0
@export_category("Horizontal focus")
## Holds the camera on the region's authored X while the target remains inside.
## This is useful for narrow climbs where rapidly alternating wall jumps should
## not make the entire composition sway left and right.
@export var horizontal_focus_enabled := false
@export var horizontal_focus_offset := 0.0


func contains_world_position(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	return (
		absf(local_position.x) <= size.x * 0.5
		and absf(local_position.y) <= size.y * 0.5
	)


func vertical_anchor_world_y() -> float:
	return global_position.y + vertical_anchor_y


func horizontal_focus_world_x() -> float:
	return global_position.x + horizontal_focus_offset


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if size.x <= 0.0 or size.y <= 0.0:
		errors.append("Vertical camera region size must be positive.")
	if (
		vertical_framing_enabled
		and maximum_vertical_offset < minimum_vertical_offset
	):
		errors.append(
			"Vertical camera region maximum offset must not be below its minimum."
		)
	if not vertical_framing_enabled and not horizontal_focus_enabled:
		errors.append("Camera region must affect vertical framing or horizontal focus.")
	return errors
