extends SceneTree
## Completes the Green Zone finale through the production input actions.
## The last crossing must remain one airborne Wall Jump -> Double Jump -> Dash
## sequence with no landing between those three actions and the target.

const MAXIMUM_FRAMES := 2400
const MAXIMUM_STAGE_FRAMES := 300
const JUMP_HOLD_FRAMES := 14
const DOUBLE_JUMP_HOLD_FRAMES := 14
const PLAYER_HALF_WIDTH := 0.36
const LANDING_HEIGHT_TOLERANCE := 0.18


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"green_zone_finale")
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(player.has_ability(PlayerAbility.DASH))

	var death_count := [0]
	var ability_events: Array[StringName] = []
	var final_ability_events: Array[StringName] = []
	var record_final_sequence := [false]
	player.died.connect(func() -> void: death_count[0] += 1)
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			ability_events.append(ability_id)
			if record_final_sequence[0]:
				final_ability_events.append(ability_id)
	)

	var stage := &"opening_ground"
	var stage_frames := 0
	var jump_held := false
	var jump_hold_remaining := 0
	var release_dash := false
	var release_attack := false
	var crossing_double_sent := false
	var crossing_dash_sent := false
	var desired_wall_direction := 1.0
	var opening_spikes_cleared := false
	var final_double_sent := false
	var final_dash_sent := false
	var final_sequence_started := false
	var final_landing_reached := false
	var final_intermediate_landing := false
	_set_horizontal_input(1.0)

	for frame in MAXIMUM_FRAMES:
		if player.is_dead() or completion_label.visible:
			break

		if release_dash:
			Input.action_release("dash")
			release_dash = false
		if release_attack:
			Input.action_release("attack")
			release_attack = false
		elif _enemy_is_in_melee_range(level, player):
			Input.action_press("attack")
			release_attack = true

		var jump_released_this_frame := false
		if jump_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_held = false
				jump_released_this_frame = true

		stage_frames += 1
		match stage:
			&"opening_ground":
				_set_horizontal_input(1.0)
				if (
					not opening_spikes_cleared
					and player.is_on_floor()
					and player.global_position.x >= 6.2
					and not jump_held
					and not jump_released_this_frame
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
					opening_spikes_cleared = true
				elif _launch_near_right_edge(
					player,
					_platform(level, "OpeningGround"),
					jump_held
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if _is_on_platform(player, _platform(level, "FamiliarStep")):
					stage = &"familiar_step"
					stage_frames = 0

			&"familiar_step":
				_set_horizontal_input(1.0)
				if _launch_near_right_edge(
					player,
					_platform(level, "FamiliarStep"),
					jump_held
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					_is_on_platform(player, _platform(level, "OpeningRun"))
					and player.global_position.x >= 24.0
				):
					stage = &"double_jump_approach"
					stage_frames = 0

			&"double_jump_approach":
				_set_horizontal_input(1.0)
				var source := _platform(level, "OpeningRun")
				if _launch_near_right_edge(player, source, jump_held):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
					crossing_double_sent = false
					stage = &"double_jump_crossing"
					stage_frames = 0

			&"double_jump_crossing":
				_set_horizontal_input(1.0)
				if (
					not crossing_double_sent
					and not jump_held
					and not jump_released_this_frame
					and not player.is_on_floor()
					and player.global_position.x >= 37.4
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
					crossing_double_sent = true
				if _is_on_platform(player, _platform(level, "DoubleJumpRise")):
					assert(crossing_double_sent)
					stage = &"double_jump_drop"
					stage_frames = 0

			&"double_jump_drop":
				_set_horizontal_input(1.0)
				if _launch_near_right_edge(
					player,
					_platform(level, "DoubleJumpRise"),
					jump_held
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if _is_on_platform(player, _platform(level, "DoubleJumpCatch")):
					stage = &"hazard_entry"
					stage_frames = 0

			&"hazard_entry":
				_set_horizontal_input(1.0)
				if _launch_near_right_edge(
					player,
					_platform(level, "DoubleJumpCatch"),
					jump_held
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					_is_on_platform(
						player,
						_platform(level, "HazardAndShaftFloor")
					)
					and player.global_position.x >= 59.6
				):
					stage = &"hazard_run"
					stage_frames = 0

			&"hazard_run":
				_set_horizontal_input(1.0)
				if (
					player.is_on_floor()
					and player.global_position.x >= 60.0
					and not jump_held
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
					stage = &"hazard_crossing"
					stage_frames = 0
					desired_wall_direction = 1.0

			&"hazard_crossing":
				_set_horizontal_input(desired_wall_direction)
				if (
					not player.is_on_floor()
					and player.global_position.x < 72.0
					and player.aerial_jumps_remaining() > 0
					and not jump_held
					and not jump_released_this_frame
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
				if (
					player.is_on_floor()
					and player.global_position.x >= 74.8
					and player.global_position.x < 80.0
				):
					stage = &"review_shaft"
					stage_frames = 0

			&"review_shaft":
				_set_horizontal_input(desired_wall_direction)
				if (
					player.is_on_floor()
					and player.global_position.x >= 74.8
					and player.global_position.x < 80.0
					and not jump_held
					and not jump_released_this_frame
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				var review_wall := player.wall_contact_direction()
				if (
					not is_zero_approx(review_wall)
					and review_wall != player.blocked_wall_jump_direction()
					and not jump_held
					and not jump_released_this_frame
				):
					desired_wall_direction = -review_wall
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					_is_on_platform(player, _platform(level, "ReviewExit"))
					and player.global_position.x >= 81.8
				):
					stage = &"wall_exit_checkpoint"
					stage_frames = 0

			&"wall_exit_checkpoint":
				var wall_exit_checkpoint := level.get_node(
					"Checkpoints/CheckpointWallExit"
				) as LevelCheckpoint3D
				if wall_exit_checkpoint.is_activated():
					_set_horizontal_input(1.0)
					stage = &"dash_approach"
					stage_frames = 0
				elif (
					player.global_position.x
					< wall_exit_checkpoint.global_position.x - 0.25
				):
					_set_horizontal_input(1.0)
				elif (
					player.global_position.x
					> wall_exit_checkpoint.global_position.x + 0.25
				):
					_set_horizontal_input(-1.0)
				else:
					_set_horizontal_input(0.0)

			&"dash_approach":
				_set_horizontal_input(1.0)
				if _launch_near_right_edge(
					player,
					_platform(level, "ReviewExit"),
					jump_held
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
					crossing_double_sent = false
					crossing_dash_sent = false
					stage = &"dash_crossing"
					stage_frames = 0

			&"dash_crossing":
				_set_horizontal_input(1.0)
				var dash_source := _platform(level, "ReviewExit")
				var dash_progress := (
					player.global_position.x - _right_edge(dash_source)
				)
				if (
					not crossing_double_sent
					and not jump_held
					and not jump_released_this_frame
					and not player.is_on_floor()
					and dash_progress >= 4.8
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
					crossing_double_sent = true
				if (
					crossing_double_sent
					and not crossing_dash_sent
					and not player.is_on_floor()
					and dash_progress >= 8.8
				):
					Input.action_press("dash")
					release_dash = true
					crossing_dash_sent = true
				if _is_on_platform(player, _platform(level, "DashLanding")):
					assert(crossing_double_sent and crossing_dash_sent)
					stage = &"descent"
					stage_frames = 0

			&"descent":
				_set_horizontal_input(1.0)
				var descent_source := _platform(level, "DashLanding")
				if (
					_is_on_platform(player, descent_source)
					and _launch_near_right_edge(player, descent_source, jump_held)
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				elif (
					_is_on_platform(player, _platform(level, "DescentStep"))
					and _launch_near_right_edge(
						player,
						_platform(level, "DescentStep"),
						jump_held
					)
				):
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					_is_on_platform(player, _platform(level, "FinaleFloor"))
					and player.global_position.x >= 134.8
				):
					stage = &"finale_shaft"
					stage_frames = 0
					desired_wall_direction = 1.0

			&"finale_shaft":
				_set_horizontal_input(desired_wall_direction)
				if (
					player.is_on_floor()
					and player.global_position.x >= 145.8
					and player.global_position.x < 151.0
					and not jump_held
					and not jump_released_this_frame
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
				var finale_wall := player.wall_contact_direction()
				if (
					finale_wall < 0.0
					and player.global_position.y >= 9.5
					and finale_wall != player.blocked_wall_jump_direction()
					and not jump_held
					and not jump_released_this_frame
				):
					record_final_sequence[0] = true
					final_sequence_started = true
					desired_wall_direction = 1.0
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES
					stage = &"finale_flight"
					stage_frames = 0
				elif (
					not is_zero_approx(finale_wall)
					and finale_wall != player.blocked_wall_jump_direction()
					and not jump_held
					and not jump_released_this_frame
				):
					desired_wall_direction = -finale_wall
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES

			&"finale_flight":
				_set_horizontal_input(1.0)
				if (
					final_sequence_started
					and player.is_on_floor()
					and not _is_on_platform(
						player,
						_platform(level, "FinaleLanding")
					)
				):
					final_intermediate_landing = true
					break
				if (
					not final_double_sent
					and not jump_held
					and not jump_released_this_frame
					and not player.is_on_floor()
					and player.global_position.x >= 152.4
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
					final_double_sent = true
				if (
					final_double_sent
					and not final_dash_sent
					and not player.is_on_floor()
					and player.global_position.x >= 155.0
				):
					Input.action_press("dash")
					release_dash = true
					final_dash_sent = true
				if _is_on_platform(player, _platform(level, "FinaleLanding")):
					final_landing_reached = true
					record_final_sequence[0] = false
					stage = &"finish"
					stage_frames = 0

			&"finish":
				_set_horizontal_input(1.0)
				if (
					_is_on_platform(player, _platform(level, "FinishGround"))
					and player.global_position.x >= 194.0
					and not jump_held
					and not jump_released_this_frame
				):
					_press_jump()
					jump_held = true
					jump_hold_remaining = JUMP_HOLD_FRAMES

		var active_stage_limit := (
			300 if stage == &"finish" else MAXIMUM_STAGE_FRAMES
		)
		if stage_frames > active_stage_limit:
			_release_inputs()
			_fail("timed out", stage, level, player, final_ability_events)
			quit(1)
			return
		await physics_frame

	_release_inputs()
	if death_count[0] > 0 or player.is_dead():
		_fail("died", stage, level, player, final_ability_events)
		quit(1)
		return
	if final_intermediate_landing:
		_fail(
			"landed before the finale target",
			stage,
			level,
			player,
			final_ability_events
		)
		quit(1)
		return
	if not completion_label.visible:
		_fail("did not reach the goal", stage, level, player, final_ability_events)
		quit(1)
		return

	assert(final_landing_reached)
	assert(final_double_sent and final_dash_sent)
	assert(final_ability_events.size() == 3)
	assert(final_ability_events[0] == PlayerAbility.WALL_JUMP)
	assert(final_ability_events[1] == PlayerAbility.DOUBLE_JUMP)
	assert(final_ability_events[2] == PlayerAbility.DASH)
	assert(level.active_checkpoint_index() == 5)
	for checkpoint in level.get_node("Checkpoints").get_children():
		if not (checkpoint as LevelCheckpoint3D).is_activated():
			push_error("Level 6 playthrough missed checkpoint %s." % checkpoint.name)
			quit(1)
			return
	assert(PlayerAbility.DOUBLE_JUMP in ability_events)
	assert(PlayerAbility.WALL_JUMP in ability_events)
	assert(PlayerAbility.DASH in ability_events)
	print(
		"Level 6 full-kit playthrough passed; finale signature: %s."
		% [", ".join(final_ability_events.map(func(id: StringName) -> String: return String(id)))]
	)
	quit(0)


func _launch_near_right_edge(
	player: PlayerCharacter,
	platform: PixelPlatform3D,
	jump_held: bool
) -> bool:
	if jump_held or not _is_on_platform(player, platform):
		return false
	if player.global_position.x < _right_edge(platform) - 0.55:
		return false
	_press_jump()
	return true


func _press_jump() -> void:
	Input.action_press("jump")


func _is_on_platform(
	player: PlayerCharacter,
	platform: PixelPlatform3D
) -> bool:
	if not player.is_on_floor():
		return false
	var top := platform.global_position.y + platform.size.y * 0.5
	return (
		player.global_position.x >= _left_edge(platform) - PLAYER_HALF_WIDTH
		and player.global_position.x <= _right_edge(platform) + PLAYER_HALF_WIDTH
		and absf(player.feet_world_y() - top) <= LANDING_HEIGHT_TOLERANCE
	)


func _enemy_is_in_melee_range(
	level: LevelSession3D,
	player: PlayerCharacter
) -> bool:
	for candidate in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(candidate):
			continue
		var enemy := candidate as StompableEnemy3D
		if enemy == null or enemy.is_defeated():
			continue
		var offset := enemy.global_position - player.global_position
		if offset.x >= 0.0 and offset.x <= 1.1 and absf(offset.y) <= 0.9:
			return true
	return false


func _platform(level: LevelSession3D, node_name: String) -> PixelPlatform3D:
	return level.get_node("Platforms/%s" % node_name) as PixelPlatform3D


func _left_edge(platform: PixelPlatform3D) -> float:
	return platform.global_position.x - platform.size.x * 0.5


func _right_edge(platform: PixelPlatform3D) -> float:
	return platform.global_position.x + platform.size.x * 0.5


func _set_horizontal_input(direction: float) -> void:
	if direction < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_press("move_right")


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("attack")


func _fail(
	reason: String,
	stage: StringName,
	level: LevelSession3D,
	player: PlayerCharacter,
	final_events: Array[StringName]
) -> void:
	push_error(
		(
			"Level 6 playthrough %s in %s at (%.2f, %.2f), "
			+ "feet=%.2f, rail=%.2f, floor=%s, wall=%.1f, final=%s."
		)
		% [
			reason,
			stage,
			player.global_position.x,
			player.global_position.y,
			player.feet_world_y(),
			level.traversal_rail.offset_of(player.global_position.x),
			player.is_on_floor(),
			player.wall_contact_direction(),
			final_events,
		]
	)
