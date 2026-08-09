extends SceneTree
## Drives the production controller through the complete Level 4 route using
## ordinary movement input, including pickup collection and both wall shafts.

const MAXIMUM_FRAMES := 2400
const JUMP_HOLD_FRAMES := 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"wall_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var pickup := level.get_node("WallJumpPickup") as AbilityPickup3D
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	var stage := 0
	var desired_direction := 1.0
	var jump_hold_remaining := 0
	var jump_is_held := false
	var wall_jump_count := [0]
	var death_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.WALL_JUMP:
				wall_jump_count[0] += 1
	)
	player.died.connect(func() -> void: death_count[0] += 1)

	for frame in MAXIMUM_FRAMES:
		if player.is_dead():
			break

		if jump_is_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_is_held = false

		match stage:
			0:
				_set_horizontal_input(1.0)
				if pickup.is_claimed():
					assert(player.has_ability(PlayerAbility.WALL_JUMP))
					stage = 1
					desired_direction = 1.0
			1:
				_set_horizontal_input(desired_direction)
				if player.is_on_floor() and player.global_position.x < 6.2:
					jump_is_held = _request_jump(jump_is_held)
					if jump_is_held:
						jump_hold_remaining = JUMP_HOLD_FRAMES
				var wall_direction := player.wall_contact_direction()
				if (
					not is_zero_approx(wall_direction)
					and wall_direction != player.blocked_wall_jump_direction()
					and not jump_is_held
				):
					desired_direction = -wall_direction
					jump_is_held = _request_jump(jump_is_held)
					if jump_is_held:
						jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					player.is_on_floor()
					and player.global_position.x > 6.6
					and player.global_position.y > 10.0
				):
					stage = 2
					desired_direction = 1.0
			2:
				_set_horizontal_input(1.0)
				if player.global_position.x >= 46.5:
					stage = 3
					desired_direction = 1.0
			3:
				_set_horizontal_input(desired_direction)
				if player.is_on_floor() and player.global_position.x < 49.2:
					jump_is_held = _request_jump(jump_is_held)
					if jump_is_held:
						jump_hold_remaining = JUMP_HOLD_FRAMES
				var wall_direction := player.wall_contact_direction()
				if (
					not is_zero_approx(wall_direction)
					and wall_direction != player.blocked_wall_jump_direction()
					and not jump_is_held
				):
					desired_direction = -wall_direction
					jump_is_held = _request_jump(jump_is_held)
					if jump_is_held:
						jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					player.is_on_floor()
					and player.global_position.x > 50.7
					and player.global_position.y > 11.0
				):
					stage = 4
			4:
				_set_horizontal_input(1.0)

		if completion_label.visible:
			break
		await physics_frame

	_release_inputs()

	if death_count[0] > 0 or player.is_dead():
		push_error(
			"The scripted Level 4 route died in stage %d near (%.2f, %.2f)."
			% [stage, player.global_position.x, player.global_position.y]
		)
		quit(1)
		return
	if not completion_label.visible:
		push_error(
			"The scripted Level 4 route stopped in stage %d near (%.2f, %.2f)."
			% [stage, player.global_position.x, player.global_position.y]
		)
		quit(1)
		return
	assert(pickup.is_claimed(), "The playthrough must collect Wall Jump normally.")
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(stage == 4, "The playthrough must complete both authored wall shafts.")
	assert(
		wall_jump_count[0] >= 6,
		"The playthrough must exercise repeated alternating Wall Jumps."
	)
	assert(
		level.active_checkpoint_index() == 3,
		"The playthrough must activate every protected teaching checkpoint."
	)
	print(
		"Level 4 scripted playthrough validation passed with %d Wall Jumps."
		% wall_jump_count[0]
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
	else:
		Input.action_release("move_left")
		Input.action_press("move_right")


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
