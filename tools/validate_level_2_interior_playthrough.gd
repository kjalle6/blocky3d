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
	var machine := level.get_node_or_null("ShaftFlyer") as HoveringHazard3D
	var machine_previous_y := 0.0
	if machine != null:
		machine_previous_y = machine.position.y
	var flyer_jump_requested := false
	var flyer_second_jump_requested := false
	var flyer_second_jump_frame := -1
	var flyer_dash_requested := false
	var dual_rising := level.get_node_or_null(
		"DualShaftFlyerRising"
	) as HoveringHazard3D
	var dual_falling := level.get_node_or_null(
		"DualShaftFlyerFalling"
	) as HoveringHazard3D
	var dual_rising_previous_y := 0.0
	if dual_rising != null:
		dual_rising_previous_y = dual_rising.position.y
	var dual_jump_requested := false
	var dual_second_jump_requested := false
	var dual_second_jump_frame := -1
	var dual_dash_requested := false
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

			13:
				# Approach along the authored run-up and stop short of the drop.
				_set_horizontal_input(1.0)
				if player.global_position.x >= 82.0:
					_set_horizontal_input(0.0)
					stage = 14

			14:
				# The machine now sweeps the full corridor, sealing one lane at a
				# time, so the crossing has to be timed rather than just executed.
				# Commit while it is descending and already low: by the time the
				# jump peaks it is at the bottom and the ceiling lane is open.
				_set_horizontal_input(0.0)
				if machine == null:
					stage = 15
				else:
					# The flight now takes about 1.4 s to reach the middle, and
					# the bot passes low while Dashing out of the second jump.
					# Commit as the machine bottoms out and starts climbing, so
					# it is near the ceiling by the time the player is under it.
					var ascending := machine.position.y > machine_previous_y
					if ascending and machine.position.y <= 29.6:
						stage = 15

			15:
				_set_horizontal_input(1.0)
				if (
					not flyer_jump_requested
					and player.is_on_floor()
					and not jump_is_held
					and player.global_position.x >= 86.2
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					flyer_jump_requested = true
					stage = 16

			16:
				# Same jump-and-Dash shape as the crossing before it: the ability
				# just earned stays required rather than lapsing for one beat.
				_set_horizontal_input(1.0)
				# Spend the aerial jump at the end of the first arc and Dash
				# straight after it: that is the longest the kit can carry, and
				# 14.08 m needs most of it.
				if (
					not flyer_second_jump_requested
					and not player.is_on_floor()
					and not jump_is_held
					and player.velocity.y < 0.0
					and player.global_position.y <= 29.0
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					flyer_second_jump_requested = true
					flyer_second_jump_frame = frame
				# Dash at the apex, not off the jump: Dash flattens vertical
				# motion, so dashing straight after the second jump throws away
				# the height it just bought and drops the player into the gap.
				if (
					not flyer_dash_requested
					and flyer_second_jump_requested
					and frame > flyer_second_jump_frame + 3
					and player.velocity.y <= 0.0
				):
					Input.action_press("dash")
					dash_pressed = true
					flyer_dash_requested = true
				if (
					player.is_on_floor()
					and player.global_position.x >= 101.5
					and player.global_position.y >= 28.7
				):
					stage = 17

			17:
				# Give the pair the same full 12.8 m reveal runway as the first
				# machine, then stop short enough to choose the timing window.
				_set_horizontal_input(1.0)
				if player.global_position.x >= 109.0:
					_set_horizontal_input(0.0)
					stage = 18

			18:
				# The pair occupies the outer thirds and starts in opposite
				# directions. Commit while the left machine is low and rising: by
				# the time the player reaches its third it is high, while the right
				# machine has fallen out of the later part of the route.
				_set_horizontal_input(0.0)
				if dual_rising == null or dual_falling == null:
					stage = 19
				else:
					var dual_left_ascending := (
						dual_rising.position.y > dual_rising_previous_y
					)
					if dual_left_ascending and dual_rising.position.y <= 27.7:
						stage = 19

			19:
				_set_horizontal_input(1.0)
				if (
					not dual_jump_requested
					and player.is_on_floor()
					and not jump_is_held
					and player.global_position.x >= 113.0
				):
					jump_is_held = _request_jump(false)
					# Stay low under the first-third flyer, then spend the full
					# aerial jump once that obstacle is behind the player.
					jump_hold_remaining = 10
					dual_jump_requested = true
					stage = 20

			20:
				_set_horizontal_input(1.0)
				if (
					not dual_second_jump_requested
					and not player.is_on_floor()
					and not jump_is_held
					and player.velocity.y < 0.0
					and player.global_position.y <= 29.0
				):
					jump_is_held = _request_jump(false)
					jump_hold_remaining = JUMP_HOLD_FRAMES
					dual_second_jump_requested = true
					dual_second_jump_frame = frame
				if (
					not dual_dash_requested
					and dual_second_jump_requested
					and frame > dual_second_jump_frame + 3
					and player.velocity.y <= 0.0
				):
					Input.action_press("dash")
					dash_pressed = true
					dual_dash_requested = true
				if (
					player.is_on_floor()
					and player.global_position.x >= 128.4
					and player.global_position.y >= 28.7
				):
					stage = 21
					_set_horizontal_input(0.0)
					break

		if machine != null:
			machine_previous_y = machine.position.y
		if dual_rising != null:
			dual_rising_previous_y = dual_rising.position.y
		await physics_frame

	_release_inputs()
	if death_count[0] > 0 or player.is_dead():
		var dual_rising_y := NAN if dual_rising == null else dual_rising.position.y
		var dual_falling_y := NAN if dual_falling == null else dual_falling.position.y
		_fail(
			(
				"Level 2 traversal died in stage %d near (%.2f, %.2f), wall %.0f "
				+ "blocked %.0f, dual flyers %.2f/%.2f, after %d Double Jumps."
			)
			% [
				stage,
				player.global_position.x,
				player.global_position.y,
				player.wall_contact_direction(),
				player.blocked_wall_jump_direction(),
				dual_rising_y,
				dual_falling_y,
				double_jump_count[0],
			]
		)
		return
	if stage != 21:
		_fail(
			"Level 2 traversal stopped in stage %d near (%.2f, %.2f), peaked at %.2f, after %d Wall Jumps."
			% [stage, player.global_position.x, player.global_position.y, maximum_height, wall_jump_count[0]]
		)
		return
	if wall_jump_count[0] < 2:
		_fail("Level 2 traversal did not exercise repeated wall jumps.")
		return
	if dash_count[0] != 3:
		_fail("Level 2 traversal must Dash across all three crossings.")
		return
	print(
		"Level 2 opening traversed with %d wall jumps and %d Dashes."
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
