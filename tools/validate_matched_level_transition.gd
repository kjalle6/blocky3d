extends SceneTree
## Proves both production handoffs: Level 1 completes into Level 2 as one
## matched run, then Level 2 preserves its campaign identity and abilities
## through the cave-slide transition into the interior section.

const LEVEL_1_ID: StringName = &"arrival_shoreline"
const LEVEL_2_ID: StringName = &"overgrown_coastal_ascent"
const LEVEL_2_INTERIOR := preload("res://tools/level_2_interior_fixture.gd")
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
	game_root.persist_progression = true
	game_root.developer_fresh_level_runs = false
	root.add_child(game_root)
	await process_frame

	var store := root.get_node("GameProgression") as ProgressionStore
	assert(store != null)
	var validation_save := "user://matched_level_transition_validation.json"
	if FileAccess.file_exists(validation_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(validation_save))
	store.save_path = validation_save
	store.progress = GameProgress.new()

	game_root.load_level(LEVEL_1_ID)
	await process_frame
	var level_1 := game_root.current_level as LevelSession3D
	assert(level_1 != null)
	assert(level_1.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	var level_1_player := level_1.player
	var campaign_threshold := level_1.get_node(
		"Level2Transition"
	) as LevelTransition3D
	assert(campaign_threshold != null)
	assert(campaign_threshold.validation_errors().is_empty())
	assert(campaign_threshold.target_level != null)
	assert(campaign_threshold.target_level.level_id == LEVEL_2_ID)
	assert(campaign_threshold.target_scene == null)
	assert(campaign_threshold.completes_source_level)
	assert(
		campaign_threshold.source_exit_mode
		== LevelTransition3D.SourceExitMode.RUN
	)
	assert(campaign_threshold.run_destination_during_fade_in)
	_assert_run_contract(campaign_threshold)

	campaign_threshold._on_body_entered(level_1_player)
	await physics_frame
	assert(level_1_player.visible)
	assert(level_1_player.is_transition_running())
	assert(level_1_player.horizontal_speed > 0.0)
	assert(not game_root.completion_label.visible)
	await create_timer(0.65).timeout
	assert(store.has_completed(LEVEL_1_ID))
	assert(game_root.current_level_definition.level_id == LEVEL_2_ID)
	assert(game_root.current_world_definition.world_id == &"green_zone")
	var approach := game_root.current_level as LevelSession3D
	assert(approach != null and approach != level_1)
	var approach_player := approach.player
	assert(approach_player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not approach_player.has_ability(PlayerAbility.WALL_JUMP))
	assert(not approach_player.has_ability(PlayerAbility.DASH))
	assert(approach_player.is_transition_running())
	assert(approach_player.global_position.x > approach.spawn_point.global_position.x + EPSILON)
	assert(not game_root.completion_label.visible)
	await create_timer(EXPECTED_DURATION + 0.1).timeout
	assert(not approach_player.is_transition_running())

	var cave_threshold := approach.get_node("CaveThreshold") as LevelTransition3D
	assert(cave_threshold != null)
	assert(cave_threshold.validation_errors().is_empty())
	assert(cave_threshold.target_level == null)
	assert(cave_threshold.target_scene != null)
	assert(
		cave_threshold.target_scene.resource_path
		== "res://scenes/levels/overgrown_coastal_ascent_interior.tscn"
	)
	assert(not cave_threshold.completes_source_level)
	assert(cave_threshold.interstitial_scene != null)
	assert(
		cave_threshold.interstitial_scene.resource_path
		== "res://scenes/cutscenes/level_2_cave_slide_intro.tscn"
	)
	assert(cave_threshold.source_exit_mode == LevelTransition3D.SourceExitMode.HIDE)
	assert(cave_threshold.run_destination_during_fade_in)
	_assert_run_contract(cave_threshold)

	cave_threshold._on_body_entered(approach_player)
	await physics_frame
	assert(not approach_player.visible)
	assert(not approach_player.is_transition_running())
	assert(is_zero_approx(approach_player.horizontal_speed))
	assert(not approach_player.is_physics_processing())

	await create_timer(1.0).timeout
	assert(game_root.current_level == null)
	var slide_intro := game_root.active_interstitial() as Level2CaveSlideIntro3D
	assert(slide_intro != null)
	assert(not slide_intro.has_finished())
	assert(slide_intro.slide_progress() > 0.0)
	assert(absf(slide_intro.terminal_horizontal_speed() - EXPECTED_SPEED) < 0.15)
	slide_intro.skip_to_end()
	await create_timer(0.3).timeout
	assert(game_root.active_interstitial() == null)
	assert(game_root.current_level_definition.level_id == LEVEL_2_ID)
	assert(game_root.current_world_definition.world_id == &"green_zone")
	var interior := game_root.current_level as LevelSession3D
	assert(interior != null and interior != approach)
	var interior_player := interior.player
	assert(interior_player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not interior_player.has_ability(PlayerAbility.WALL_JUMP))
	assert(not interior_player.has_ability(PlayerAbility.DASH))
	assert(interior_player.is_transition_running())
	assert(interior_player.global_position.x > interior.spawn_point.global_position.x + EPSILON)
	assert(interior_player.is_physics_processing())

	await create_timer(EXPECTED_DURATION + 0.1).timeout
	assert(not interior_player.is_transition_running())
	assert(interior_player.is_physics_processing())
	assert(not store.has_completed(LEVEL_2_ID))

	game_root.show_level_select()
	var direct_interior := LEVEL_2_INTERIOR.load_into(game_root)
	await process_frame
	assert(game_root.current_level_definition.level_id == LEVEL_2_ID)
	assert(game_root.current_world_definition.world_id == &"green_zone")
	assert(
		not direct_interior.player.is_transition_running(),
		"Direct production-interior tool loads must remain stationary."
	)

	if FileAccess.file_exists(validation_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(validation_save))
	game_root.free()
	print(
		"Matched transitions passed: Level 1 completion run, then Level 2 slide and interior run-in."
	)
	quit(0)


func _assert_run_contract(transition: LevelTransition3D) -> void:
	assert(is_equal_approx(transition.run_direction, EXPECTED_DIRECTION))
	assert(is_equal_approx(transition.run_speed, EXPECTED_SPEED))
	assert(is_equal_approx(transition.run_duration, EXPECTED_DURATION))
