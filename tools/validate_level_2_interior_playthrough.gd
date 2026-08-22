extends SceneTree
## Real-input technical traversal of the first production Level 2 slice.
## Human playtesting still owns difficulty and feel; this guards reachability.

const MAXIMUM_FRAMES := 2400
const JUMP_HOLD_FRAMES := 18


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := load(
		"res://resources/dev/level_2_interior_wip.tres"
	) as LevelDefinition
	if definition == null:
		_fail("Level 2 interior definition did not load.")
		return
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	if packed_scene == null:
		_fail("GameRoot did not load for the Level 2 traversal.")
		return
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_developer_level(definition)
	for frame in 12:
		await physics_frame
	var level := game_root.current_level as LevelSession3D
	if level == null:
		_fail("Level 2 interior scene did not instantiate.")
		return

	var player := level.player
	var recap_enemy := level.get_node("RecapEnemy") as StompableEnemy3D
	if recap_enemy == null:
		_fail("Level 2 recap enemy is missing.")
		return
	for frame in 90:
		if not player.is_transition_running():
			break
		await physics_frame
	var stage := 0
	var jump_hold_remaining := 0
	var jump_is_held := false
	var attack_pressed := false
	var recap_enemy_attacked := false
	var dash_pressed := false
	var second_jump_requested := false
	var dash_crossing_requested := false
	var desired_wall_direction := 1.0
	var shaft_exit_committed := false
	var double_jump_count := [0]
	var wall_jump_count := [0]
	var dash_count := [0]
	var death_count := [0]
	var maximum_height := player.global_position.y
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DOUBLE_JUMP:
				double_jump_count[0] += 1
			elif ability_id == PlayerAbility.WALL_JUMP:
				wall_jump_count[0] += 1
			elif ability_id == PlayerAbility.DASH:
				dash_count[0] += 1
	)
	player.died.connect(func() -> void: death_count[0] += 1)

	for frame in MAXIMUM_FRAMES:
		maximum_height = maxf(maximum_height, player.global_position.y)
		if death_count[0] > 0 or player.is_dead():
			break
		if attack_pressed:
			Input.action_release("attack")
			attack_pressed = false
		if dash_pressed:
			Input.action_release("dash")
			dash_pressed = false
		if jump_is_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_is_held = false

		match stage:
			0:
				_set_horizontal_input(1.0)
				if player.global_position.x >= 9.8:
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					stage = 1

			1:
				_set_horizontal_input(1.0)
				if (
					not recap_enemy_attacked
					and absf(recap_enemy.global_position.x - player.global_position.x) <= 1.2
				):
					Input.action_press("attack")
					attack_pressed = true
					recap_enemy_attacked = true
				if player.global_position.x >= 22.8:
					stage = 2

			2:
				_set_horizontal_input(1.0)
				if player.is_on_floor() and player.global_position.x >= 31.8:
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = false
					stage = 3

			3:
				_set_horizontal_input(1.0)
				if (
					not second_jump_requested
					and not player.is_on_floor()
					and not jump_is_held
					and player.global_position.x >= 34.0
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = true
				if (
					player.is_on_floor()
					and player.global_position.x >= 34.2
					and player.global_position.x <= 40.0
					and player.global_position.y >= 3.0
				):
					stage = 4
					second_jump_requested = false

			4:
				_set_horizontal_input(1.0)
				var landed_on_p2 := (
					player.is_on_floor()
					and player.global_position.x >= 41.9
					and player.global_position.x <= 47.7
					and player.global_position.y >= 4.9
				)
				if landed_on_p2:
					stage = 5
					second_jump_requested = false
				elif player.is_on_floor() and not jump_is_held:
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES
				elif (
					not second_jump_requested
					and not jump_is_held
					and player.global_position.x >= 40.5
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = true
			5:
				# P3 is intentionally a human-readable braking landing rather than a
				# full-speed runway. Run near P2's edge before jumping, then reverse
				# briefly near P3's center so the bot does not overshoot into the shaft.
				_set_horizontal_input(
					-1.0 if player.global_position.x >= 58.0 else 1.0
				)
				if (
					player.is_on_floor()
					and player.global_position.x >= 48.6
					and not jump_is_held
				):
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES
				elif (
					not second_jump_requested
					and not player.is_on_floor()
					and not jump_is_held
					and player.global_position.x >= 48.0
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = true
				if (
					player.is_on_floor()
					and player.global_position.x >= 54.8
					and player.global_position.x <= 60.3
					and player.global_position.y >= 6.8
				):
					stage = 6

			6:
				# The accepted landing can finish on P3's right half; step back to the
				# pickup instead of walking directly off the platform into the shaft.
				if player.global_position.x > 57.9:
					_set_horizontal_input(-1.0)
				elif player.global_position.x < 57.3:
					_set_horizontal_input(1.0)
				else:
					_set_horizontal_input(0.0)
				if player.has_ability(PlayerAbility.WALL_JUMP):
					stage = 7
					desired_wall_direction = 1.0

			7:
				if player.global_position.y < 7.8 and player.global_position.x < 53.7:
					desired_wall_direction = 1.0
				if (
					player.is_on_floor()
					and player.global_position.y < 7.8
					and not jump_is_held
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
				var wall_direction := player.wall_contact_direction()
				if (
					not shaft_exit_committed
					and player.global_position.y >= 26.0
					and wall_direction > 0.5
					and wall_direction != player.blocked_wall_jump_direction()
				):
					if jump_is_held:
						Input.action_release("jump")
						jump_is_held = false
					shaft_exit_committed = true
					desired_wall_direction = -1.0
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
				elif (
					not shaft_exit_committed
					and not is_zero_approx(wall_direction)
					and wall_direction != player.blocked_wall_jump_direction()
					and not jump_is_held
				):
					desired_wall_direction = -wall_direction
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if shaft_exit_committed:
					desired_wall_direction = -1.0
				_set_horizontal_input(desired_wall_direction)
				if (
					shaft_exit_committed
					and player.is_on_floor()
					and player.global_position.y >= 28.7
				):
					stage = 8

			8:
				_set_horizontal_input(-1.0)
				if player.has_ability(PlayerAbility.DASH):
					stage = 9

			9:
				_set_horizontal_input(1.0)
				if (
					player.is_on_floor()
					and player.global_position.y >= 28.7
					and player.global_position.x >= 54.8
				):
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = false
					stage = 10

			10:
				_set_horizontal_input(1.0)
				if (
					not second_jump_requested
					and not player.is_on_floor()
					and not jump_is_held
					and player.global_position.x >= 57.5
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = true
				if (
					player.is_on_floor()
					and player.global_position.y >= 28.7
					and player.global_position.x >= 61.6
					and player.global_position.x <= 63.9
				):
					stage = 11

			11:
				_set_horizontal_input(1.0)
				if player.is_on_floor() and not jump_is_held:
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = false
					stage = 12

			12:
				_set_horizontal_input(1.0)
				if (
					not second_jump_requested
					and not player.is_on_floor()
					and not jump_is_held
					and player.global_position.x >= 64.0
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					second_jump_requested = true
				if (
					not dash_crossing_requested
					and second_jump_requested
					and player.global_position.x >= 66.5
				):
					Input.action_press("dash")
					dash_pressed = true
					dash_crossing_requested = true
				if (
					player.is_on_floor()
					and player.global_position.x >= 74.5
					and player.global_position.y >= 28.7
				):
					stage = 13
					_set_horizontal_input(0.0)
					break

		await physics_frame

	_release_inputs()
	if death_count[0] > 0 or player.is_dead():
		_fail(
			"Level 2 traversal died in stage %d near (%.2f, %.2f), wall %.0f blocked %.0f, after %d Double Jumps."
			% [
				stage,
				player.global_position.x,
				player.global_position.y,
				player.wall_contact_direction(),
				player.blocked_wall_jump_direction(),
				double_jump_count[0],
			]
		)
		return
	if stage != 13:
		_fail(
			"Level 2 traversal stopped in stage %d near (%.2f, %.2f), peaked at %.2f, after %d Wall Jumps."
			% [stage, player.global_position.x, player.global_position.y, maximum_height, wall_jump_count[0]]
		)
		return
	if wall_jump_count[0] < 2:
		_fail("Level 2 traversal did not exercise repeated wall jumps.")
		return
	if dash_count[0] != 1:
		_fail("Level 2 traversal must perform exactly one Dash.")
		return
	print(
		"Level 2 opening traversed with %d wall jumps and %d Dash."
		% [wall_jump_count[0], dash_count[0]]
	)
	quit(0)


func _request_jump(jump_is_held: bool) -> bool:
	if jump_is_held:
		return true
	Input.action_press("jump")
	return true


func _set_horizontal_input(direction: float) -> void:
	if direction < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	elif direction > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("attack")


func _fail(message: String) -> void:
	_release_inputs()
	push_error(message)
	quit(1)
