extends SceneTree
## Real-input proof that the candidate flows from fundamentals into two
## deliberate Double Jumps without teleports, deaths, Dash, or Wall Jump.

const MAXIMUM_FRAMES := 1800
const MAXIMUM_STAGE_FRAMES := 420
const FIRST_JUMP_HOLD_FRAMES := 16
const DOUBLE_JUMP_HOLD_FRAMES := 18
const PLAYER_HALF_WIDTH := 0.36
const LANDING_HEIGHT_TOLERANCE := 0.18

const CROSSINGS := [
	{
		"name": "sand to Green Zone bank",
		"from": ^"Platforms/ShorelineTransition",
		"to": ^"Platforms/GreenApproach",
		"launch_x": 12.4,
		"second_x": -1.0,
	},
	{
		"name": "patrol approach to pickup",
		"from": ^"Platforms/GreenApproach",
		"to": ^"Platforms/PickupIsland",
		"launch_x": 24.6,
		"second_x": -1.0,
	},
	{
		"name": "Double Jump height proof",
		"from": ^"Platforms/PickupIsland",
		"to": ^"Platforms/HeightProof",
		"launch_x": 37.55,
		"second_x": 40.15,
	},
	{
		"name": "Double Jump distance proof",
		"from": ^"Platforms/HeightProof",
		"to": ^"Platforms/DistanceProof",
		"launch_x": 46.65,
		"second_x": 51.5,
	},
	{
		"name": "finish landing",
		"from": ^"Platforms/DistanceProof",
		"to": ^"Platforms/FinishGround",
		"launch_x": 59.35,
		"second_x": -1.0,
	},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/dev/arrival_shoreline_slice.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var pickup := level.get_node("DoubleJumpPickup") as AbilityPickup3D
	var checkpoint := level.get_node(
		"Checkpoints/PickupCheckpoint"
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

		if crossing_index < CROSSINGS.size():
			var crossing: Dictionary = CROSSINGS[crossing_index]
			var source := level.get_node(crossing.from) as PixelPlatform3D
			var target := level.get_node(crossing.to) as PixelPlatform3D
			stage_frames += 1
			match phase:
				&"approach":
					_set_horizontal_input(1.0)
					if (
						player.is_on_floor()
						and _is_on_platform(player, source)
						and player.global_position.x >= float(crossing.launch_x)
					):
						Input.action_press("jump")
						jump_held = true
						jump_hold_remaining = FIRST_JUMP_HOLD_FRAMES
						saw_airborne = false
						second_jump_sent = false
						phase = &"crossing"
						stage_frames = 0

				&"crossing":
					_set_horizontal_input(1.0)
					saw_airborne = saw_airborne or not player.is_on_floor()
					if (
						float(crossing.second_x) >= 0.0
						and not second_jump_sent
						and not jump_held
						and not jump_released_this_frame
						and not player.is_on_floor()
						and player.global_position.x >= float(crossing.second_x)
					):
						Input.action_press("jump")
						jump_held = true
						jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
						second_jump_sent = true

					if saw_airborne and _is_on_platform(player, target):
						var expects_double := float(crossing.second_x) >= 0.0
						if expects_double and not second_jump_sent:
							_fail("landed without the authored Double Jump", player, crossing_index, phase)
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
	assert(pickup.is_claimed(), "The route must collect Double Jump naturally.")
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(checkpoint.is_activated(), "The post-pickup checkpoint must activate naturally.")
	assert(level.active_checkpoint_index() == 2)
	assert(double_jump_count[0] == 2, "Both proof jumps must perform Double Jump once.")
	assert(wrong_ability_count[0] == 0)
	assert(death_count[0] == 0)

	root.remove_child(game_root)
	game_root.free()
	await process_frame
	await _assert_proof_requires_double_jump(
		definition,
		^"Platforms/PickupIsland",
		^"Platforms/HeightProof",
		37.55,
		"height proof"
	)
	await _assert_proof_requires_double_jump(
		definition,
		^"Platforms/HeightProof",
		^"Platforms/DistanceProof",
		46.65,
		"distance proof"
	)
	print(
		"Arrival / Shoreline real-input playthrough passed, including "
		+ "two no-Double-Jump controls: %s"
		% ", ".join(landed_platforms)
	)
	quit(0)


func _assert_proof_requires_double_jump(
	definition: LevelDefinition,
	source_path: NodePath,
	target_path: NodePath,
	launch_x: float,
	proof_name: String
) -> void:
	_release_inputs()
	var control := definition.scene.instantiate() as LevelSession3D
	control.configure(definition, null, [])
	root.add_child(control)
	await process_frame
	for frame in 8:
		await physics_frame
	var player := control.player
	var source := control.get_node(source_path) as PixelPlatform3D
	var target := control.get_node(target_path) as PixelPlatform3D
	var source_top := source.global_position.y + source.size.y * 0.5
	player.reset_at(
		Transform3D(
			Basis.IDENTITY,
			Vector3(launch_x - 1.5, source_top + 0.7, 0)
		)
	)
	for frame in 6:
		await physics_frame
	assert(not player.has_ability(PlayerAbility.DOUBLE_JUMP))

	var jump_sent := false
	var saw_airborne := false
	var contacted_target := false
	var fell_below_route := false
	_set_horizontal_input(1.0)
	for frame in 360:
		if not jump_sent and player.is_on_floor() and player.global_position.x >= launch_x:
			Input.action_press("jump")
			jump_sent = true
		if jump_sent:
			saw_airborne = saw_airborne or not player.is_on_floor()
			if _is_on_platform(player, target):
				contacted_target = true
				break
			if saw_airborne and player.feet_world_y() < -2.3:
				fell_below_route = true
				break
		await physics_frame
	_release_inputs()
	assert(jump_sent, "%s control never started its Jump." % proof_name)
	assert(saw_airborne)
	assert(
		not contacted_target,
		"A maximum ordinary Jump unexpectedly cleared the %s." % proof_name
	)
	assert(
		fell_below_route,
		"The %s control did not conclusively fall beneath the route." % proof_name
	)
	root.remove_child(control)
	control.free()
	await process_frame


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


func _enemy_is_in_melee_range(
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
		if offset.x >= 0.0 and offset.x <= 1.1 and absf(offset.y) <= 0.9:
			return true
	return false


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
	player: PlayerCharacter,
	crossing_index: int,
	phase: StringName
) -> void:
	var crossing_name := "finish"
	if crossing_index < CROSSINGS.size():
		crossing_name = CROSSINGS[crossing_index].name
	push_error(
		(
			"Arrival / Shoreline playthrough %s during '%s' "
			+ "(phase=%s, x=%.2f, y=%.2f, feet=%.2f, grounded=%s, "
			+ "path_speed=%.2f, velocity=%s, slides=%d)."
		)
		% [
			reason,
			crossing_name,
			phase,
			player.global_position.x,
			player.global_position.y,
			player.feet_world_y(),
			player.is_on_floor(),
			player.path_speed,
			player.velocity,
			player.get_slide_collision_count(),
		]
	)
