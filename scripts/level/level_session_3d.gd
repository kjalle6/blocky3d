class_name LevelSession3D
extends Node3D
## Runtime wiring shared by authored levels and disposable test courses. The
## session owns run reset/completion, while gameplay behavior stays on entities.

signal run_completed
signal run_reset
signal checkpoint_changed(route_index: int)

@export_range(0.0, 1.0, 0.01) var reset_delay := 0.18

@onready var traversal_rail: TraversalRail3D = %TraversalRail
@onready var player: PlayerCharacter = %Player
@onready var camera = %RailCamera
@onready var spawn_point: Marker3D = %SpawnPoint
@onready var combat_feedback := get_node_or_null("%CombatFeedback")

var _resetting := false
var _completed := false
var _initial_spawn_transform := Transform3D.IDENTITY
var _active_respawn_transform := Transform3D.IDENTITY
var _active_checkpoint_index := -1
var _reset_request_serial := 0
var _definition: LevelDefinition
var _progression_store: ProgressionStore
var _session_unlocked_abilities: Array[StringName] = []


func configure(
	definition: LevelDefinition,
	progression_store: ProgressionStore = null
) -> void:
	assert(not is_node_ready(), "Configure LevelSession3D before adding it to the scene tree.")
	_definition = definition
	_progression_store = progression_store


func _ready() -> void:
	_initial_spawn_transform = spawn_point.global_transform
	_active_respawn_transform = _initial_spawn_transform
	player.traversal_rail = traversal_rail
	_apply_ability_policy()
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
	for node in get_tree().get_nodes_in_group("level_checkpoint"):
		if is_ancestor_of(node) and node.has_signal("activated"):
			node.activated.connect(_on_checkpoint_activated)

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
	_reset_request_serial += 1
	var request_serial := _reset_request_serial
	await get_tree().create_timer(reset_delay).timeout
	if request_serial != _reset_request_serial:
		return
	_reset_world()
	camera.snap_to_target()
	_resetting = false


func _on_goal_reached(body: PlayerCharacter) -> void:
	if _completed or body != player:
		return
	_completed = true
	player.stop_for_completion()
	run_completed.emit()


func _on_checkpoint_activated(checkpoint: LevelCheckpoint3D) -> void:
	if checkpoint.route_index <= _active_checkpoint_index:
		return
	_active_checkpoint_index = checkpoint.route_index
	_active_respawn_transform = checkpoint.respawn_transform()
	checkpoint_changed.emit(_active_checkpoint_index)


func _reset_run(clear_checkpoint := true) -> void:
	_reset_request_serial += 1
	_resetting = false
	if clear_checkpoint:
		_active_checkpoint_index = -1
		_active_respawn_transform = _initial_spawn_transform
		for node in get_tree().get_nodes_in_group("level_checkpoint"):
			if is_ancestor_of(node) and node.has_method("reset_checkpoint"):
				node.call("reset_checkpoint")
	_reset_world()


func _reset_world() -> void:
	_completed = false
	if combat_feedback != null:
		combat_feedback.reset_feedback()
	for node in get_tree().get_nodes_in_group("run_resettable"):
		if is_ancestor_of(node) and node.has_method("reset_run"):
			node.call("reset_run")
	player.reset_at(_active_respawn_transform)
	run_reset.emit()


func active_checkpoint_index() -> int:
	return _active_checkpoint_index


func unlock_ability(ability_id: StringName) -> bool:
	assert(_definition != null, "A configured level definition must own ability policy.")
	if not PlayerAbility.is_known(ability_id):
		push_error("Level requested unknown ability '%s'." % ability_id)
		return false
	if not _definition.offers_ability(ability_id):
		push_error(
			"%s cannot unlock unavailable ability '%s'."
			% [_definition.level_id, ability_id]
		)
		return false
	if ability_id not in _session_unlocked_abilities:
		_session_unlocked_abilities.append(ability_id)
	if _progression_store != null:
		_progression_store.unlock_ability(ability_id)
	player.enable_ability(ability_id)
	return player.has_ability(ability_id)


func level_definition() -> LevelDefinition:
	return _definition


func _apply_ability_policy() -> void:
	var owned_abilities: Array[StringName] = []
	if _progression_store != null:
		owned_abilities = _progression_store.unlocked_abilities()
	for ability_id in _session_unlocked_abilities:
		if ability_id not in owned_abilities:
			owned_abilities.append(ability_id)
	if _definition == null:
		player.configure_abilities([], [])
		return
	player.configure_abilities(owned_abilities, _definition.available_abilities)
