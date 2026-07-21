class_name MovementLab
extends Node3D
## Owns only the disposable lab session: wiring and fast reset. It does not own
## player movement, camera behavior, or future game progression.

@export_range(0.0, 1.0, 0.01) var reset_delay := 0.18

@onready var traversal_rail: TraversalRail3D = %TraversalRail
@onready var player: PlayerCharacter = %Player
@onready var camera: RailCamera3D = %RailCamera
@onready var spawn_point: Marker3D = %SpawnPoint

var _resetting := false


func _ready() -> void:
	player.traversal_rail = traversal_rail
	camera.target = player
	camera.traversal_rail = traversal_rail
	player.died.connect(_on_player_died)
	player.reset_at(spawn_point.global_transform)
	camera.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset_player()
		get_viewport().set_input_as_handled()


func _on_player_died() -> void:
	if _resetting:
		return
	_resetting = true
	await get_tree().create_timer(reset_delay).timeout
	_reset_player()
	_resetting = false


func _reset_player() -> void:
	player.reset_at(spawn_point.global_transform)
	camera.snap_to_target()
