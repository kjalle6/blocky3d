class_name LevelSession3D
extends Node3D
## Runtime wiring shared by authored levels and disposable test courses. The
## session owns run reset/completion, while gameplay behavior stays on entities.

signal run_completed
signal transition_requested(target: LevelDefinition)
signal run_reset
signal checkpoint_changed(route_index: int)
signal ability_unlocked(ability_id: StringName)

@export_range(0.0, 1.0, 0.01) var reset_delay := 0.18

@onready var route_extent: RouteExtent3D = %RouteExtent
@onready var player: PlayerCharacter = %Player
@onready var camera = %GameplayCamera
@onready var background := get_node_or_null("Background") as PixelBackgroundRig3D
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
var _developer_inspection_enabled := false
var _developer_measurement_grid: DeveloperMeasurementGrid3D
var _developer_collision_overlay: DeveloperCollisionOverlay3D


func configure(
	definition: LevelDefinition,
	progression_store: ProgressionStore = null,
	initial_session_abilities: Array[StringName] = []
) -> void:
	assert(not is_node_ready(), "Configure LevelSession3D before adding it to the scene tree.")
	_definition = definition
	_progression_store = progression_store
	_session_unlocked_abilities.clear()
	for ability_id in initial_session_abilities:
		assert(
			PlayerAbility.is_known(ability_id),
			"Test session requested unknown ability '%s'." % ability_id
		)
		assert(
			definition != null and definition.offers_ability(ability_id),
			"%s cannot start with unavailable ability '%s'."
			% [definition.level_id if definition != null else &"unconfigured", ability_id]
		)
		if ability_id not in _session_unlocked_abilities:
			_session_unlocked_abilities.append(ability_id)


func _ready() -> void:
	_initial_spawn_transform = spawn_point.global_transform
	_active_respawn_transform = _initial_spawn_transform
	_apply_ability_policy()
	camera.target = player
	var vertical_regions: Array[VerticalCameraRegion3D] = []
	for node in find_children("*", "VerticalCameraRegion3D", true, false):
		vertical_regions.append(node as VerticalCameraRegion3D)
	camera.bind_vertical_regions(vertical_regions)
	if background != null:
		background.bind_camera(camera)
	player.died.connect(_on_player_died)
	if combat_feedback != null:
		combat_feedback.bind_player(player)

	for node in get_tree().get_nodes_in_group("melee_target"):
		if combat_feedback != null and is_ancestor_of(node) and node is StompableEnemy3D:
			combat_feedback.bind_enemy(node as StompableEnemy3D)
	for node in get_tree().get_nodes_in_group("level_transition"):
		if is_ancestor_of(node) and node.has_signal("entered"):
			node.entered.connect(_on_transition_entered)
	for node in get_tree().get_nodes_in_group("level_goal"):
		if is_ancestor_of(node) and node.has_signal("reached"):
			node.reached.connect(_on_goal_reached)
	for node in get_tree().get_nodes_in_group("level_checkpoint"):
		if is_ancestor_of(node) and node.has_signal("activated"):
			node.activated.connect(_on_checkpoint_activated)
	for node in get_tree().get_nodes_in_group("ability_pickup"):
		if is_ancestor_of(node) and node.has_method("bind_to_level_session"):
			node.call("bind_to_level_session", self)

	_reset_run()
	camera.snap_to_target()
	if background != null:
		background.snap_to_camera(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset_run()
		camera.snap_to_target()
		if background != null:
			background.snap_to_camera()
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
	if background != null:
		background.snap_to_camera()
	_resetting = false


func _on_goal_reached(body: PlayerCharacter) -> void:
	if _completed or body != player:
		return
	_completed = true
	player.stop_for_completion()
	run_completed.emit()


## A threshold hands the run to another scene. The player is stopped exactly as
## a goal stops it, so nothing keeps simulating behind the fade.
func _on_transition_entered(target: LevelDefinition) -> void:
	if _completed or target == null:
		return
	_completed = true
	player.stop_for_completion()
	transition_requested.emit(target)


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


func set_developer_inspection_enabled(enabled: bool) -> void:
	if _developer_inspection_enabled == enabled:
		return
	_developer_inspection_enabled = enabled
	if enabled:
		_reset_request_serial += 1
		_resetting = false
		if player.is_dead():
			player.reset_at(player.global_transform)
		_grant_developer_inspection_abilities()
	player.set_developer_inspection_enabled(enabled)
	camera.set_developer_inspection_enabled(enabled)
	if background != null:
		background.snap_to_camera()


func is_developer_inspection_enabled() -> bool:
	return _developer_inspection_enabled


func _grant_developer_inspection_abilities() -> void:
	if _definition == null:
		return
	# F11 turns only this loaded session into a test run. Use the session-local
	# ability policy so exiting inspection, dying, or pressing R keeps every
	# mechanic available without collecting pickups or writing campaign data.
	for ability_id in _definition.available_abilities:
		if ability_id not in _session_unlocked_abilities:
			_session_unlocked_abilities.append(ability_id)
	_apply_ability_policy()


func set_developer_measurement_grid_enabled(enabled: bool) -> void:
	if enabled and _developer_measurement_grid == null:
		_developer_measurement_grid = DeveloperMeasurementGrid3D.new()
		_developer_measurement_grid.name = "DeveloperMeasurementGrid"
		add_child(_developer_measurement_grid)
		_developer_measurement_grid.bind_camera(camera)
	if _developer_measurement_grid != null:
		_developer_measurement_grid.visible = enabled
		_developer_measurement_grid.set_process(enabled)


func is_developer_measurement_grid_enabled() -> bool:
	return (
		_developer_measurement_grid != null
		and _developer_measurement_grid.visible
	)


func developer_measurement_grid() -> DeveloperMeasurementGrid3D:
	return _developer_measurement_grid


func set_developer_collision_overlay_enabled(enabled: bool) -> void:
	if enabled and _developer_collision_overlay == null:
		_developer_collision_overlay = DeveloperCollisionOverlay3D.new()
		_developer_collision_overlay.name = "DeveloperCollisionOverlay"
		add_child(_developer_collision_overlay)
		_developer_collision_overlay.bind_level(self)
	if _developer_collision_overlay != null:
		_developer_collision_overlay.visible = enabled
		_developer_collision_overlay.set_process(enabled)


func is_developer_collision_overlay_enabled() -> bool:
	return (
		_developer_collision_overlay != null
		and _developer_collision_overlay.visible
	)


func developer_collision_overlay() -> DeveloperCollisionOverlay3D:
	return _developer_collision_overlay


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
	var was_active := player.has_ability(ability_id)
	if ability_id not in _session_unlocked_abilities:
		_session_unlocked_abilities.append(ability_id)
	if _progression_store != null:
		_progression_store.unlock_ability(ability_id)
	player.enable_ability(ability_id)
	if not was_active and player.has_ability(ability_id):
		ability_unlocked.emit(ability_id)
	return player.has_ability(ability_id)


func level_definition() -> LevelDefinition:
	return _definition


func set_session_ability_enabled(ability_id: StringName, enabled: bool) -> void:
	assert(_definition != null, "A configured session must own ability policy.")
	assert(
		_definition.offers_ability(ability_id),
		"%s does not offer ability '%s'." % [_definition.level_id, ability_id]
	)
	if enabled:
		if ability_id not in _session_unlocked_abilities:
			_session_unlocked_abilities.append(ability_id)
	else:
		_session_unlocked_abilities.erase(ability_id)
	_apply_ability_policy()


func is_session_ability_enabled(ability_id: StringName) -> bool:
	return ability_id in _session_unlocked_abilities


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
