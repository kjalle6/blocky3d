extends SceneTree
## Drives the production controller through Level 5's six authored Dash gaps.
## The bot uses the same Input actions as a player and must collect Dash,
## perform one deliberate Dash per gap, clear the optional flow enemies, and
## land on every named platform.

const MAXIMUM_FRAMES := 3600
const MAXIMUM_STAGE_FRAMES := 480
const FIRST_JUMP_HOLD_FRAMES := 14
const DOUBLE_JUMP_HOLD_FRAMES := 18
const JUMP_LAUNCH_INSET := 0.5
const LANDING_HEIGHT_TOLERANCE := 0.16
const PLAYER_HALF_WIDTH := 0.36
const SETTLE_FRAMES := 8

const ROUTE_STAGES := [
	{
		"name": "first Dash gap",
		"from": ^"Platforms/PickupRunway",
		"to": ^"Platforms/FirstDashLanding",
		"double_progress": 5.0,
		"dash_progress": 9.0,
	},
	{
		"name": "rising Dash gap",
		"from": ^"Platforms/FirstDashLanding",
		"to": ^"Platforms/RisingDashLanding",
		"double_progress": 5.2,
		"dash_progress": 9.0,
	},
	{
		"name": "Dash to the breather",
		"from": ^"Platforms/RisingDashLanding",
		"to": ^"Platforms/MidBreather",
		"double_progress": 5.0,
		"dash_progress": 9.0,
		"checkpoint": ^"Checkpoints/CheckpointMid",
	},
	{
		"name": "high Dash gap",
		"from": ^"Platforms/MidBreather",
		"to": ^"Platforms/HighDashLanding",
		"double_progress": 4.2,
		"dash_progress": 7.8,
		"checkpoint": ^"Checkpoints/CheckpointHigh",
	},
	{
		"name": "descending Dash gap",
		"from": ^"Platforms/HighDashLanding",
		"to": ^"Platforms/DescentLanding",
		"double_progress": 5.0,
		"dash_progress": 9.0,
		"checkpoint": ^"Checkpoints/CheckpointDescent",
	},
	{
		"name": "finish Dash gap",
		"from": ^"Platforms/DescentLanding",
		"to": ^"Platforms/FinishGround",
		"double_progress": 5.0,
		"dash_progress": 9.0,
	},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"dash")
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var pickup := level.get_node("DashPickup") as AbilityPickup3D
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	_validate_route(level)
	var death_count := [0]
	var dash_count := [0]
	var double_jump_count := [0]
	var enemy_defeat_count := [0]
	player.died.connect(func() -> void: death_count[0] += 1)
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DASH:
				dash_count[0] += 1
			elif ability_id == PlayerAbility.DOUBLE_JUMP:
				double_jump_count[0] += 1
	)
	for enemy_name in [
		"FirstFlowPatrol",
		"MidFlowPatrol",
		"FinishFlowPatrol",
	]:
		var enemy := level.get_node(enemy_name) as StompableEnemy3D
		enemy.defeated.connect(func(_position: Vector3) -> void: enemy_defeat_count[0] += 1)

	var stage_index := -1
	var stage_phase := &"opening"
	var stage_frames := 0
	var opening_jump_sent := false
	var stage_saw_airborne := false
	var stage_double_sent := false
	var stage_dash_sent := false
	var jump_hold_remaining := 0
	var jump_held := false
	var release_dash := false
	var release_attack := false
	var settle_frames := 0
	var landing_margins: Array[float] = []
	var landing_positions: Array[float] = []
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
		elif (
			stage_phase in [&"approach", &"finish"]
			and _enemy_is_in_melee_range(level, player)
		):
			Input.action_press("attack")
			release_attack = true
		var jump_released_this_frame := false
		if jump_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_held = false
				jump_released_this_frame = true

		match stage_phase:
			&"opening":
				_set_horizontal_input(1.0)
				var opening := level.get_node("Platforms/OpeningGround") as PixelPlatform3D
				var opening_right := _platform_right(opening)
				if (
					not opening_jump_sent
					and player.is_on_floor()
					and player.global_position.x >= opening_right - 0.55
				):
					Input.action_press("jump")
					jump_held = true
					jump_hold_remaining = FIRST_JUMP_HOLD_FRAMES
					opening_jump_sent = true
				var first_checkpoint := level.get_node(
					"Checkpoints/CheckpointDashReady"
				) as LevelCheckpoint3D
				if (
					pickup.is_claimed()
					and first_checkpoint.is_activated()
					and _is_on_platform(
						player,
						level.get_node("Platforms/PickupRunway") as PixelPlatform3D
					)
				):
					stage_index = 0
					stage_phase = &"approach"
					stage_frames = 0

			&"approach":
				stage_frames += 1
				_set_horizontal_input(1.0)
				var stage: Dictionary = ROUTE_STAGES[stage_index]
				var source := level.get_node(stage.from) as PixelPlatform3D
				if (
					player.is_on_floor()
					and _is_on_platform(player, source)
					and player.global_position.x
						>= _platform_right(source) - JUMP_LAUNCH_INSET
				):
					Input.action_press("jump")
					jump_held = true
					jump_hold_remaining = FIRST_JUMP_HOLD_FRAMES
					stage_saw_airborne = false
					stage_double_sent = false
					stage_dash_sent = false
					stage_phase = &"crossing"
					stage_frames = 0

			&"crossing":
				stage_frames += 1
				_set_horizontal_input(1.0)
				var stage: Dictionary = ROUTE_STAGES[stage_index]
				var source := level.get_node(stage.from) as PixelPlatform3D
				var target := level.get_node(stage.to) as PixelPlatform3D
				var progress := player.global_position.x - _platform_right(source)
				stage_saw_airborne = stage_saw_airborne or not player.is_on_floor()

				if (
					not stage_double_sent
					and not jump_held
					and not jump_released_this_frame
					and not player.is_on_floor()
					and progress >= float(stage.double_progress)
				):
					Input.action_press("jump")
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
					stage_double_sent = true

				if (
					stage_double_sent
					and not stage_dash_sent
					and not player.is_on_floor()
					and progress >= float(stage.dash_progress)
					and player.dash_available()
				):
					Input.action_press("dash")
					release_dash = true
					stage_dash_sent = true

				# Ease off after reaching the target's safe interior. This mirrors
				# a player releasing right after the commitment has succeeded.
				if player.global_position.x >= _platform_left(target) + 1.8:
					_stop_horizontal_input()

				if (
					stage_saw_airborne
					and stage_double_sent
					and stage_dash_sent
					and _is_on_platform(player, target)
				):
					var left_margin := (
						player.global_position.x
						+ PLAYER_HALF_WIDTH
						- _platform_left(target)
					)
					var right_margin := (
						_platform_right(target)
						- (player.global_position.x - PLAYER_HALF_WIDTH)
					)
					landing_margins.append(minf(left_margin, right_margin))
					landing_positions.append(player.global_position.x)
					_stop_horizontal_input()
					settle_frames = 0
					stage_phase = &"settle"
					stage_frames = 0

			&"settle":
				stage_frames += 1
				var stage: Dictionary = ROUTE_STAGES[stage_index]
				var target := level.get_node(stage.to) as PixelPlatform3D
				if not _is_on_platform(player, target):
					_fail(
						"left the landing while settling",
						level,
						player,
						stage_index,
						stage_phase,
						stage_double_sent,
						stage_dash_sent,
						dash_count[0],
						double_jump_count[0],
						landing_margins
					)
					quit(1)
					return
				settle_frames += 1
				var checkpoint_ready := true
				if stage.has("checkpoint"):
					var checkpoint := level.get_node(
						stage.checkpoint
					) as LevelCheckpoint3D
					checkpoint_ready = checkpoint.is_activated()
					if checkpoint_ready:
						_stop_horizontal_input()
					else:
						_set_horizontal_input(1.0)
				else:
					_stop_horizontal_input()
				if settle_frames >= SETTLE_FRAMES and checkpoint_ready:
					stage_index += 1
					if stage_index >= ROUTE_STAGES.size():
						stage_phase = &"finish"
					else:
						stage_phase = &"approach"
					stage_frames = 0

			&"finish":
				_set_horizontal_input(1.0)

		if (
			stage_phase != &"opening"
			and stage_phase != &"finish"
			and stage_frames > MAXIMUM_STAGE_FRAMES
		):
			_release_inputs()
			_fail(
				"timed out",
				level,
				player,
				stage_index,
				stage_phase,
				stage_double_sent,
				stage_dash_sent,
				dash_count[0],
				double_jump_count[0],
				landing_margins
			)
			quit(1)
			return

		await physics_frame

	_release_inputs()
	if death_count[0] > 0 or player.is_dead():
		_fail(
			"died",
			level,
			player,
			stage_index,
			stage_phase,
			stage_double_sent,
			stage_dash_sent,
			dash_count[0],
			double_jump_count[0],
			landing_margins
		)
		quit(1)
		return
	if not completion_label.visible:
		_fail(
			"did not reach the goal",
			level,
			player,
			stage_index,
			stage_phase,
			stage_double_sent,
			stage_dash_sent,
			dash_count[0],
			double_jump_count[0],
			landing_margins
		)
		quit(1)
		return

	assert(pickup.is_claimed(), "The playthrough must collect Dash normally.")
	assert(player.has_ability(PlayerAbility.DASH))
	assert(stage_index == ROUTE_STAGES.size())
	assert(dash_count[0] == ROUTE_STAGES.size(), "Every gap must perform one Dash.")
	assert(
		double_jump_count[0] == ROUTE_STAGES.size(),
		"Every 14.08 m gap must use its deliberate Double Jump."
	)
	assert(
		landing_margins.size() == ROUTE_STAGES.size(),
		"Every named landing must be reached before continuing."
	)
	assert(
		enemy_defeat_count[0] == 3,
		"The validation route should deliberately clear all three flow enemies."
	)
	assert(level.active_checkpoint_index() == 4)
	for checkpoint_path in [
		^"Checkpoints/CheckpointDashReady",
		^"Checkpoints/CheckpointMid",
		^"Checkpoints/CheckpointHigh",
		^"Checkpoints/CheckpointDescent",
	]:
		var checkpoint := level.get_node(checkpoint_path) as LevelCheckpoint3D
		assert(checkpoint.is_activated(), "%s must be activated." % checkpoint.name)

	root.remove_child(game_root)
	game_root.free()
	await process_frame
	await _validate_first_gap_requires_dash()

	var margin_text: Array[String] = []
	for index in landing_margins.size():
		margin_text.append(
			"%s %.2fm@x%.2f"
			% [
				ROUTE_STAGES[index].to,
				landing_margins[index],
				landing_positions[index],
			]
		)
	print(
		(
			"Level 5 six-gap playthrough passed with %d flow enemies cleared "
			+ "(and no-Dash control failed safely): %s"
		)
		% [enemy_defeat_count[0], ", ".join(margin_text)]
	)
	quit(0)


func _validate_route(level: LevelSession3D) -> void:
	assert(ROUTE_STAGES.size() == 6)
	for stage in ROUTE_STAGES:
		var source := level.get_node_or_null(stage.from) as PixelPlatform3D
		var target := level.get_node_or_null(stage.to) as PixelPlatform3D
		assert(source != null)
		assert(target != null)
		assert(
			is_equal_approx(_platform_left(target) - _platform_right(source), 14.08),
			"%s must retain its authored 14.08 m Dash gap." % stage.name
		)


func _validate_first_gap_requires_dash() -> void:
	# A separate session proves the first authored gap is not merely a long
	# Double Jump wearing a Dash tutorial's clothes. No state or death counter
	# from this control run can weaken the successful six-gap contract above.
	_release_inputs()
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var control_root := packed_scene.instantiate()
	control_root.campaign = load(
		"res://resources/regression/main_campaign.tres"
	) as CampaignCatalog
	control_root.persist_progression = false
	root.add_child(control_root)
	control_root.load_level(&"dash")
	await process_frame

	var level := control_root.current_level as LevelSession3D
	var player := level.player
	var pickup := level.get_node("DashPickup") as AbilityPickup3D
	var source := level.get_node("Platforms/PickupRunway") as PixelPlatform3D
	var target := level.get_node("Platforms/FirstDashLanding") as PixelPlatform3D
	var checkpoint := level.get_node(
		"Checkpoints/CheckpointDashReady"
	) as LevelCheckpoint3D
	for frame in 12:
		await physics_frame

	var death_count := [0]
	var dash_count := [0]
	var double_jump_count := [0]
	player.died.connect(func() -> void: death_count[0] += 1)
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DASH:
				dash_count[0] += 1
			elif ability_id == PlayerAbility.DOUBLE_JUMP:
				double_jump_count[0] += 1
	)

	var phase := &"opening"
	var opening_jump_sent := false
	var attempt_started := false
	var double_sent := false
	var contacted_target := false
	var fell_short := false
	var jump_held := false
	var jump_hold_remaining := 0
	_set_horizontal_input(1.0)

	for frame in 900:
		if death_count[0] > 0:
			break
		if jump_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_held = false

		_set_horizontal_input(1.0)
		match phase:
			&"opening":
				var opening := level.get_node(
					"Platforms/OpeningGround"
				) as PixelPlatform3D
				if (
					not opening_jump_sent
					and player.is_on_floor()
					and player.global_position.x >= _platform_right(opening) - 0.55
				):
					Input.action_press("jump")
					jump_held = true
					jump_hold_remaining = FIRST_JUMP_HOLD_FRAMES
					opening_jump_sent = true
				if (
					pickup.is_claimed()
					and checkpoint.is_activated()
					and _is_on_platform(player, source)
				):
					phase = &"approach"

			&"approach":
				if (
					player.is_on_floor()
					and _is_on_platform(player, source)
					and player.global_position.x
						>= _platform_right(source) - JUMP_LAUNCH_INSET
				):
					Input.action_press("jump")
					jump_held = true
					jump_hold_remaining = FIRST_JUMP_HOLD_FRAMES
					attempt_started = true
					phase = &"crossing"

			&"crossing":
				var progress := player.global_position.x - _platform_right(source)
				if (
					not double_sent
					and not jump_held
					and not player.is_on_floor()
					and progress >= 5.2
				):
					Input.action_press("jump")
					jump_held = true
					jump_hold_remaining = DOUBLE_JUMP_HOLD_FRAMES
					double_sent = true
				if _is_on_platform(player, target):
					contacted_target = true
					break
				if (
					double_sent
					and player.feet_world_y() <= -2.0
					and player.global_position.x
						< _platform_left(target) - PLAYER_HALF_WIDTH
				):
					fell_short = true
					break

		await physics_frame

	_release_inputs()
	assert(pickup.is_claimed(), "The no-Dash control must collect Dash normally.")
	assert(checkpoint.is_activated())
	assert(attempt_started)
	assert(double_sent and double_jump_count[0] == 1)
	assert(dash_count[0] == 0, "The control attempt must never press Dash.")
	assert(
		not contacted_target,
		"A full Jump + Double Jump unexpectedly crossed the first 14.08 m gap."
	)
	assert(
		fell_short,
		"The no-Dash control did not conclusively fall below the landing."
	)
	assert(
		death_count[0] == 0,
		"The isolated control should stop before scheduling a production reset."
	)
	root.remove_child(control_root)
	control_root.free()
	await process_frame


func _is_on_platform(
	player: PlayerCharacter,
	platform: PixelPlatform3D
) -> bool:
	if not player.is_on_floor():
		return false
	var platform_top := platform.global_position.y + platform.size.y * 0.5
	return (
		player.global_position.x >= _platform_left(platform) - PLAYER_HALF_WIDTH
		and player.global_position.x <= _platform_right(platform) + PLAYER_HALF_WIDTH
		and absf(player.feet_world_y() - platform_top) <= LANDING_HEIGHT_TOLERANCE
	)


func _platform_left(platform: PixelPlatform3D) -> float:
	return platform.global_position.x - platform.size.x * 0.5


func _platform_right(platform: PixelPlatform3D) -> float:
	return platform.global_position.x + platform.size.x * 0.5


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


func _fail(
	reason: String,
	level: LevelSession3D,
	player: PlayerCharacter,
	stage_index: int,
	phase: StringName,
	double_sent: bool,
	dash_sent: bool,
	dash_count: int,
	double_jump_count: int,
	landing_margins: Array[float]
) -> void:
	var stage_name := "opening"
	var gap_text := ""
	if stage_index >= 0 and stage_index < ROUTE_STAGES.size():
		var stage: Dictionary = ROUTE_STAGES[stage_index]
		stage_name = stage.name
		var source := level.get_node(stage.from) as PixelPlatform3D
		var target := level.get_node(stage.to) as PixelPlatform3D
		gap_text = (
			", gap=%.2f, source_top=%.2f, target_top=%.2f"
			% [
				_platform_left(target) - _platform_right(source),
				source.global_position.y + source.size.y * 0.5,
				target.global_position.y + target.size.y * 0.5,
			]
		)
	push_error(
		(
			"Level 5 six-gap playthrough %s during '%s' "
			+ "(phase=%s, position=(%.2f, %.2f)%s, double=%s, Dash=%s, "
			+ "Double Jumps=%d, Dashes=%d, landed=%d)."
		)
		% [
			reason,
			stage_name,
			phase,
			player.global_position.x,
			player.global_position.y,
			gap_text,
			double_sent,
			dash_sent,
			double_jump_count,
			dash_count,
			landing_margins.size(),
		]
	)


func _set_horizontal_input(direction: float) -> void:
	if direction < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_press("move_right")


func _stop_horizontal_input() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("attack")
