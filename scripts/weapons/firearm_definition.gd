class_name FirearmDefinition
extends Resource
## Immutable authored tuning for one player firearm. Ammunition deliberately
## lives outside this resource until its pickup/drop economy is designed.

@export var weapon_id: StringName = &"handgun"
@export var display_name := "HANDGUN"
@export var projectile_scene: PackedScene

@export_category("Cadence")
@export_range(0.05, 2.0, 0.01) var fire_interval := 0.28

@export_category("Projectile")
@export_range(1.0, 40.0, 0.1) var projectile_speed := 13.0
@export_range(1.0, 60.0, 0.5) var projectile_distance := 26.0
@export var horizontal_direction := Vector2.RIGHT
@export var upward_direction := Vector2(1.0, 1.0).normalized()

@export_category("Muzzle offsets from PlayerCharacter")
@export var horizontal_muzzle_offset := Vector2(0.46, 0.54)
@export var upward_muzzle_offset := Vector2(0.37, 0.81)


func shot_direction(facing_sign: float, aim_up: bool) -> Vector3:
	var authored_direction := upward_direction if aim_up else horizontal_direction
	var direction := Vector3(
		absf(authored_direction.x) * _resolved_facing_sign(facing_sign),
		authored_direction.y,
		0.0
	)
	return direction.normalized()


func muzzle_offset(facing_sign: float, aim_up: bool) -> Vector3:
	var authored_offset := (
		upward_muzzle_offset if aim_up else horizontal_muzzle_offset
	)
	return Vector3(
		absf(authored_offset.x) * _resolved_facing_sign(facing_sign),
		authored_offset.y,
		0.0
	)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if weapon_id.is_empty():
		errors.append("Firearm definition requires a stable weapon id.")
	if display_name.strip_edges().is_empty():
		errors.append("%s requires a display name." % weapon_id)
	if projectile_scene == null:
		errors.append("%s requires a projectile scene." % weapon_id)
	if fire_interval <= 0.0:
		errors.append("%s requires a positive fire interval." % weapon_id)
	if projectile_speed <= 0.0 or projectile_distance <= 0.0:
		errors.append("%s requires positive projectile tuning." % weapon_id)
	if horizontal_direction.is_zero_approx() or upward_direction.is_zero_approx():
		errors.append("%s requires both authored shot directions." % weapon_id)
	if upward_direction.y <= 0.0:
		errors.append("%s upward direction must point above the player." % weapon_id)
	return errors


func _resolved_facing_sign(facing_sign: float) -> float:
	return -1.0 if facing_sign < 0.0 else 1.0
