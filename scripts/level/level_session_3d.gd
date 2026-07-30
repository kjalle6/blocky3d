class_name LevelSession3D
extends Node3D
## Runtime wiring shared by authored levels and disposable test courses. The
## session owns run reset/completion, while gameplay behavior stays on entities.

signal run_completed
signal run_reset

@export_range(0.0, 1.0, 0.01) var reset_delay := 0.18

@onready var traversal_rail: TraversalRail3D = %TraversalRail
@onready var player: PlayerCharacter = %Player
@onready var camera = %RailCamera
@onready var spawn_point: Marker3D = %SpawnPoint
@onready var combat_feedback := get_node_or_null("%CombatFeedback")

var _resetting := false
var _completed := false


func _ready() -> void:
	player.traversal_rail = traversal_rail
	camera.target = player
	camera.traversal_rail = traversal_rail
	player.died.connect(_on_player_died)
	if combat_feedback != null:
		combat_feedback.bind_player(player)

	for node in get_tree().get_nodes_in_group("rail_bound"):
		if is_ancestor_of(node) and node.has_method("bind_to_traversal_rail"):
			node.call("bind_to_traversal_rail", traversal_rail)
	for node in get_tree().get_nodes_in_group("melee_target"):
		if combat_feedback != null and is_ancestor_of(node) and node is StompableEnemy3D:
			combat_feedback.bind_enemy(node as StompableEnemy3D)
	for node in get_tree().get_nodes_in_group("level_goal"):
		if is_ancestor_of(node) and node.has_signal("reached"):
			node.reached.connect(_on_goal_reached)

	_reset_run()
	camera.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset_run()
		camera.snap_to_target()
		get_viewport().set_input_as_handled()


func _on_player_died() -> void:
	if _resetting:
		return
	_resetting = true
	await get_tree().create_timer(reset_delay).timeout
	_reset_run()
	camera.snap_to_target()
	_resetting = false


func _on_goal_reached(body: PlayerCharacter) -> void:
	if _completed or body != player:
		return
	_completed = true
	player.stop_for_completion()
	run_completed.emit()


func _reset_run() -> void:
	_completed = false
	if combat_feedback != null:
		combat_feedback.reset_feedback()
	for node in get_tree().get_nodes_in_group("run_resettable"):
		if is_ancestor_of(node) and node.has_method("reset_run"):
			node.call("reset_run")
	player.reset_at(spawn_point.global_transform)
	run_reset.emit()
