extends SceneTree
## Real-input technical traversal for the current Level 1 review slice.
##
## This is a smoke test, not a difficulty judge. Its only job is to prove the
## route can be crossed with the intended ability and without teleports,
## forbidden abilities, or deaths. Human playtesting owns the feel.

const MAXIMUM_FRAMES := 4200
const MAXIMUM_STAGE_FRAMES := 720
const FIRST_JUMP_HOLD_FRAMES := 16
const DOUBLE_JUMP_HOLD_FRAMES := 18
const PLAYER_HALF_WIDTH := 0.36
const LANDING_HEIGHT_TOLERANCE := 0.18

const CROSSINGS := [
	{
		"name": "shoreline into Green Zone",
		"from": ^"Platforms/ShorelineTransition",
		"to": ^"Platforms/GreenApproach",
		"launch_x": 12.4,
		"second_x": -1.0,
	},
	{
		"name": "Green Approach to Threshold",
		"from": ^"Platforms/GreenApproach",
		"to": ^"Platforms/ThresholdRun",
		"launch_x": 24.4,
		"second_x": -1.0,
	},
	{
		"name": "Threshold spike row",
		"from": ^"Platforms/ThresholdRun",
		"to": ^"Platforms/ThresholdRun",
		"launch_x": 29.7,
		"second_x": -1.0,
	},
	{
		"name": "Double Jump crown",
		"from": ^"Platforms/ThresholdRun",
		"to": ^"Platforms/ThresholdCrown",
		"launch_x": 39.0,
		"second_x": 42.0,
		"landing_brake_x": 47.0,
	},
	{
		"name": "Threshold landing",
		"from": ^"Platforms/ThresholdCrown",
		"to": ^"Platforms/ThresholdLanding",
		"launch_x": 48.7,
		"second_x": -1.0,
	},
	{
		"name": "Thorn Garden entry",
		"from": ^"Platforms/ThresholdLanding",
		"to": ^"Platforms/ThornGardenEntry",
		"launch_x": 63.4,
		"second_x": -1.0,
	},
	{
		"name": "first thorn basin",
		"from": ^"Platforms/ThornGardenEntry",
		"to": ^"Platforms/ThornTerrace",
		"launch_x": 77.2,
		"second_x": 81.0,
		"landing_brake_x": 89.8,
	},
	{
		"name": "second thorn pocket",
		"from": ^"Platforms/ThornTerrace",
		"to": ^"Platforms/ThornWall",
		"launch_x": 92.8,
		"second_x": 96.0,
		"landing_brake_x": 102.6,
	},
	{
		"name": "garden exit descent",
		"from": ^"Platforms/ThornWall",
		"to": ^"Platforms/ThornGardenExit",
		"launch_x": 105.7,
		"second_x": -1.0,
	},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/campaign/level_01.tres"
	) as LevelDefinition
	game_root.load_level(definition.level_id)
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var pickup := level.get_node("DoubleJumpPickup") as AbilityPickup3D
	var pickup_checkpoint := level.get_node(
		"Checkpoints/PickupCheckpoint"
	) as LevelCheckpoint3D
	var exit_checkpoint := level.get_node(
		"Checkpoints/ThornGardenExitCheckpoint"
	) as LevelCheckpoint3D
	var completion_label := game_root.get_node(
		"Interface/CompletionLabel"
	) as Label
	for frame in 12:
		await physics_frame

	var death_count := [0]
	var double_jump_count := [0]
	var wrong_ability_count := [0]
	player.died.connect(func() -> void: death_count[0] += 1)
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DOUBLE_JUMP:
				double_jump_count[0] += 1
			elif ability_id in [PlayerAbility.WALL_JUMP, PlayerAbility.DASH]:
				wrong_ability_count[0] += 1
	)

	var crossing_index := 0
	var phase := &"approach"
	var stage_frames := 0
	var jump_held := false
	var jump_hold_remaining := 0
	var saw_airborne := false
	var second_jump_sent := false
	var release_attack := false
	var landed_platforms := PackedStringArray()
	_set_horizontal_input(1.0)

	for frame in MAXIMUM_FRAMES:
		if player.is_dead() or completion_label.visible:
			break

		if release_attack:
			Input.action_release("attack")
			release_attack = false
		elif _enemy_is_approaching_melee_range(level, player):
			Input.action_press("attack")
			release_attack = true

		var jump_released_this_frame := false
		if jump_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_held = false
				jump_released_this_frame = true

		if crossing_index < CROSSINGS.size():
			var crossing: Dictionary = CROSSINGS[crossing_index]
			var source := level.get_node(crossing.from) as PixelPlatform3D
			var target := level.get_node(crossing.to) as PixelPlatform3D
			var direction := float(crossing.get("direction", 1.0))
			stage_frames += 1
			match phase:
				&"approach":
					_set_horizontal_input(direction)
					if (
						player.is_on_floor()
						and _is_on_platform(player, source)
						and _reached_x(
							player.global_position.x,
							float(crossing.launch_x),
							direction
						)
					):
						Input.action_press("jump")
						jump_held = true
						jump_hold_remaining = FIRST_JUMP_HOLD_FRAMES
						saw_airborne = false
						second_jump_sent = false
						phase = &"crossing"
						stage_frames = 0

				&"crossing":
					var should_brake := (
						crossing.has("landing_brake_x")
						and _reached_x(
							player.global_position.x,
							float(crossing.landing_brake_x),
							direction
						)
					)
					_set_horizontal_input(0.0 if should_brake else direction)
					saw_airborne = saw_airborne or not player.is_on_floor()
					if (
						float(crossing.second_x) >= 0.0
						and not second_jump_sent
						and not jump_held
						and not jump_released_this_frame
						and not player.is_on_floor()
						and _reached_x(
							player.global_position.x,
							float(crossing.second_x),
							direction
						)
					):
						Input.action_press("jump")
						jump_held = true
						jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
						second_jump_sent = true

					if saw_airborne and _is_on_platform(player, target):
						if float(crossing.second_x) >= 0.0 and not second_jump_sent:
							_fail(
								"landed without the authored Double Jump",
								player,
								crossing_index,
								phase
							)
							_release_inputs()
							quit(1)
							return
						landed_platforms.append(target.name)
						crossing_index += 1
						phase = &"approach"
						stage_frames = 0
		else:
			_set_horizontal_input(1.0)

		if stage_frames > MAXIMUM_STAGE_FRAMES:
			_fail("timed out", player, crossing_index, phase)
			_release_inputs()
			quit(1)
			return
		await physics_frame

	_release_inputs()
	if death_count[0] > 0 or player.is_dead():
		_fail("died", player, crossing_index, phase)
		quit(1)
		return
	if not completion_label.visible:
		_fail("did not reach the goal", player, crossing_index, phase)
		quit(1)
		return

	assert(crossing_index == CROSSINGS.size())
	assert(landed_platforms.size() == CROSSINGS.size())
	assert(pickup.is_claimed())
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup_checkpoint.is_activated())
	assert(exit_checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 3)
	assert(double_jump_count[0] >= 3)
	assert(wrong_ability_count[0] == 0)
	assert(death_count[0] == 0)

	print(
		"Arrival / Shoreline focused real-input traversal passed: %s"
		% ", ".join(landed_platforms)
	)
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _is_on_platform(
	player: PlayerCharacter,
	platform: PixelPlatform3D
) -> bool:
	if not player.is_on_floor():
		return false
	var left := platform.global_position.x - platform.size.x * 0.5
	var right := platform.global_position.x + platform.size.x * 0.5
	var top := platform.global_position.y + platform.size.y * 0.5
	return (
		player.global_position.x >= left - PLAYER_HALF_WIDTH
		and player.global_position.x <= right + PLAYER_HALF_WIDTH
		and absf(player.feet_world_y() - top) <= LANDING_HEIGHT_TOLERANCE
	)


func _enemy_is_approaching_melee_range(
	level: LevelSession3D,
	player: PlayerCharacter
) -> bool:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		var enemy := node as StompableEnemy3D
		if enemy.is_defeated():
			continue
		var offset := enemy.global_position - player.global_position
		if offset.x >= 0.0 and offset.x <= 1.25 and absf(offset.y) <= 1.6:
			return true
	return false


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


func _reached_x(current_x: float, target_x: float, direction: float) -> bool:
	return current_x >= target_x if direction > 0.0 else current_x <= target_x


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("attack")


func _fail(
	reason: String,
	player: PlayerCharacter,
	crossing_index: int,
	phase: StringName
) -> void:
	var crossing_name := "finish"
	if crossing_index < CROSSINGS.size():
		crossing_name = CROSSINGS[crossing_index].name
	push_error(
		(
			"Arrival playthrough %s during '%s' "
			+ "(phase=%s, x=%.2f, y=%.2f, feet=%.2f, grounded=%s, "
			+ "velocity=%s)."
		)
		% [
			reason,
			crossing_name,
			phase,
			player.global_position.x,
			player.global_position.y,
			player.feet_world_y(),
			player.is_on_floor(),
			player.velocity,
		]
	)
