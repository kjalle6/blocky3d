extends Node3D
## Temporary lab presentation only. The real character will own its facing and
## animation through a dedicated presentation component and authored assets.

@export_range(1.0, 40.0, 0.5) var turn_response := 18.0

@onready var player := get_parent() as PlayerCharacter

var _facing_sign := 1.0


func _process(delta: float) -> void:
	if player == null or player.traversal_rail == null:
		return
	if absf(player.path_speed) > 0.05:
		_facing_sign = signf(player.path_speed)
	var tangent := player.traversal_rail.tangent_at_world_position(player.global_position)
	var facing_direction := tangent * _facing_sign
	var desired_yaw := atan2(facing_direction.x, facing_direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-turn_response * delta))
