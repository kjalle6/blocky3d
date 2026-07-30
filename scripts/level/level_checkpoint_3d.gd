class_name LevelCheckpoint3D
extends Area3D
## Invisible for now, but strict: progress is earned only after stable grounded
## contact at this checkpoint's authored support height.

signal activated(checkpoint: LevelCheckpoint3D)

@export_range(0, 100, 1) var route_index := 0
@export_range(0.0, 0.5, 0.01) var required_grounded_time := 0.1
@export_range(0.01, 0.5, 0.01) var feet_height_tolerance := 0.12
@export_range(0.1, 2.0, 0.01) var respawn_height := 0.7

var _activated := false
var _grounded_time := 0.0


func _ready() -> void:
	add_to_group("level_checkpoint")


func _physics_process(delta: float) -> void:
	if _activated:
		return
	var player := _overlapping_player()
	if (
		player == null
		or player.is_dead()
		or not player.is_on_floor()
		or absf(player.feet_world_y() - global_position.y) > feet_height_tolerance
	):
		_grounded_time = 0.0
		return
	_grounded_time += delta
	if _grounded_time >= required_grounded_time:
		_activated = true
		activated.emit(self)


func respawn_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, global_position + Vector3.UP * respawn_height)


func reset_checkpoint() -> void:
	_activated = false
	_grounded_time = 0.0


func is_activated() -> bool:
	return _activated


func _overlapping_player() -> PlayerCharacter:
	for body in get_overlapping_bodies():
		if body is PlayerCharacter:
			return body as PlayerCharacter
	return null
