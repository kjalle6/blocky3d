extends SceneTree
## Proves the Level 2 WIP cave handoff uses doorway-appropriate halves: the
## source player disappears into the black cave mouth, the destination player
## enters moving right, and ordinary input control resumes afterwards.

const SOURCE_LEVEL_ID: StringName = &"dev_level_2_wip"
const TARGET_LEVEL_ID: StringName = &"dev_level_2_interior_wip"
const EXPECTED_DIRECTION := 1.0
const EXPECTED_SPEED := 8.0
const EXPECTED_DURATION := 0.45
const EPSILON := 0.001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root = packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame

	var source_definition := _developer_definition(game_root, SOURCE_LEVEL_ID)
	game_root.load_developer_level(source_definition)
	await process_frame
	var source_session := game_root.current_level as LevelSession3D
	assert(source_session != null)
	var source_player := source_session.player
	var threshold := source_session.get_node("CaveThreshold") as LevelTransition3D
	assert(threshold != null)
	assert(threshold.validation_errors().is_empty())
	assert(threshold.source_exit_mode == LevelTransition3D.SourceExitMode.HIDE)
	assert(threshold.run_destination_during_fade_in)
	assert(is_equal_approx(threshold.run_direction, EXPECTED_DIRECTION))
	assert(is_equal_approx(threshold.run_speed, EXPECTED_SPEED))
	assert(is_equal_approx(threshold.run_duration, EXPECTED_DURATION))

	threshold._on_body_entered(source_player)
	await physics_frame
	assert(not source_player.visible)
	assert(not source_player.is_transition_running())
	assert(is_zero_approx(source_player.horizontal_speed))
	assert(not source_player.is_physics_processing())

	await create_timer(0.5).timeout
	assert(game_root.current_level_definition != null)
	assert(game_root.current_level_definition.level_id == TARGET_LEVEL_ID)
	var target_session := game_root.current_level as LevelSession3D
	assert(target_session != null and target_session != source_session)
	var target_player := target_session.player
	assert(target_player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not target_player.has_ability(PlayerAbility.WALL_JUMP))
	assert(not target_player.has_ability(PlayerAbility.DASH))
	var target_spawn_x := target_session.spawn_point.global_position.x
	assert(target_player.is_transition_running())
	assert(target_player.horizontal_speed > 0.0)
	assert(
		target_player.global_position.x > target_spawn_x + EPSILON,
		"Destination player must already be running right while black lifts."
	)
	assert(target_player.is_physics_processing())

	await create_timer(EXPECTED_DURATION + 0.1).timeout
	assert(not target_player.is_transition_running())
	assert(target_player.is_physics_processing())

	game_root.show_level_select()
	game_root.load_developer_level(_developer_definition(game_root, TARGET_LEVEL_ID))
	await process_frame
	assert(
		not game_root.current_level.player.is_transition_running(),
		"Direct menu loads must remain stationary; only a threshold owns a handoff."
	)

	game_root.free()
	print("Matched level transition passed: cave hide, run-in, then control.")
	quit(0)


func _developer_definition(game_root: Node, level_id: StringName) -> LevelDefinition:
	for definition in game_root.developer_level_definitions:
		if definition != null and definition.level_id == level_id:
			return definition
	assert(false, "Missing developer level definition: %s" % level_id)
	return null
