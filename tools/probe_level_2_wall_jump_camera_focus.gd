extends SceneTree
## Rendered-frame regression probe for the Level 2 wall-jump camera focus.
##
## It drives the real player from the Wall Jump pickup to the upper landing,
## then measures the camera and the newly appearing ceiling only while that
## ceiling is visible. Run through run_godot_tool.ps1 with -Visual.

const START_POSITION := Vector3(57.6, 7.1, 0.0)
const JUMP_HOLD_FRAMES := 18
const MAXIMUM_FRAMES := 600
const LEVEL_2_INTERIOR := preload("res://tools/level_2_interior_fixture.gd")

var _completed := false
var _visible_sample_count := 0
var _minimum_player_x := INF
var _maximum_player_x := -INF
var _minimum_camera_x := INF
var _maximum_camera_x := -INF
var _minimum_ceiling_screen_x := INF
var _maximum_ceiling_screen_x := -INF


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 45.0
	watchdog.one_shot = true
	watchdog.autostart = true
	watchdog.timeout.connect(_on_watchdog_timeout)
	root.add_child(watchdog)

	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 6:
		await process_frame

	var level := LEVEL_2_INTERIOR.load_into(game_root)
	for frame in 12:
		await physics_frame
	assert(level != null)
	var player := level.player as PlayerCharacter
	var camera := level.camera as PixelSideCamera3D
	var background := level.background as PixelBackgroundRig3D
	var focus_region := Rect2(56.32, 13, 5.12, 13)
	var ceiling_sprite := level.get_node(
		"UpperCaveCeiling/CaveCeiling"
	) as Sprite3D
	assert(player != null and camera != null and background != null)
	assert(ceiling_sprite != null)

	for frame in 90:
		if not player.is_transition_running():
			break
		await physics_frame
	level.set_session_ability_enabled(PlayerAbility.WALL_JUMP, true)
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	_freeze_enemies(level)
	game_root.get_node("Interface").visible = false
	player.reset_at(Transform3D(Basis.IDENTITY, START_POSITION))
	player.velocity = Vector3.ZERO
	player.horizontal_speed = 0.0
	camera.snap_to_target()
	background.snap_to_camera(true)
	for frame in 8:
		await _rendered_physics_frame()

	var wall_jump_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.WALL_JUMP:
				wall_jump_count[0] += 1
	)
	var desired_wall_direction := 1.0
	var jump_hold_remaining := 0
	var jump_is_held := false
	var shaft_exit_committed := false
	var reached_upper_landing := false

	for frame in MAXIMUM_FRAMES:
		if jump_is_held:
			jump_hold_remaining -= 1
			if jump_hold_remaining <= 0:
				Input.action_release("jump")
				jump_is_held = false
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
		await _rendered_physics_frame()
		_record_visible_sample(player, camera, focus_region, ceiling_sprite)
		if (
			shaft_exit_committed
			and player.is_on_floor()
			and player.global_position.y >= 28.7
		):
			reached_upper_landing = true
			break

	_release_inputs()
	assert(reached_upper_landing, "Wall-jump focus probe never reached the upper landing.")
	assert(wall_jump_count[0] >= 2, "Wall-jump focus probe needs repeated wall jumps.")
	assert(
		_visible_sample_count >= 8,
		"Wall-jump focus probe did not observe enough visible ceiling frames."
	)
	var player_x_range := _maximum_player_x - _minimum_player_x
	var camera_x_range := _maximum_camera_x - _minimum_camera_x
	var ceiling_screen_x_range := (
		_maximum_ceiling_screen_x - _minimum_ceiling_screen_x
	)
	assert(
		player_x_range >= 2.0,
		"The probe did not cross enough of the shaft to test alternating movement."
	)
	assert(
		camera_x_range <= camera.world_units_per_screen_pixel() * 2.0,
		"Wall-jump focus allowed %.4f m of horizontal camera sway."
		% camera_x_range
	)
	assert(
		ceiling_screen_x_range <= 2.0,
		"The visible ceiling drifted %.3f px during the wall-jump focus."
		% ceiling_screen_x_range
	)
	print(
		(
			"Level 2 wall-jump camera focus passed: %d jumps, %d visible frames, "
			+ "player X range %.3f m, camera X range %.4f m, ceiling drift %.3f px."
		)
		% [
			wall_jump_count[0],
			_visible_sample_count,
			player_x_range,
			camera_x_range,
			ceiling_screen_x_range,
		]
	)
	_completed = true
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _rendered_physics_frame() -> void:
	await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _record_visible_sample(
	player: PlayerCharacter,
	camera: PixelSideCamera3D,
	focus_region: Rect2,
	ceiling_sprite: Sprite3D
) -> void:
	if not focus_region.has_point(Vector2(player.global_position.x, player.global_position.y)):
		return
	if ceiling_sprite.modulate.a < 0.05:
		return
	var ceiling_screen_x := camera.unproject_position(
		ceiling_sprite.global_position
	).x
	_visible_sample_count += 1
	_minimum_player_x = minf(_minimum_player_x, player.global_position.x)
	_maximum_player_x = maxf(_maximum_player_x, player.global_position.x)
	_minimum_camera_x = minf(_minimum_camera_x, camera.global_position.x)
	_maximum_camera_x = maxf(_maximum_camera_x, camera.global_position.x)
	_minimum_ceiling_screen_x = minf(
		_minimum_ceiling_screen_x,
		ceiling_screen_x
	)
	_maximum_ceiling_screen_x = maxf(
		_maximum_ceiling_screen_x,
		ceiling_screen_x
	)


func _request_jump(jump_is_held: bool) -> bool:
	if jump_is_held:
		return true
	Input.action_press("jump")
	return true


func _set_horizontal_input(direction: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if direction < -0.5:
		Input.action_press("move_left")
	elif direction > 0.5:
		Input.action_press("move_right")


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")


func _freeze_enemies(level: LevelSession3D) -> void:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		if node.has_method("reset_run"):
			node.call("reset_run")
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		node.set_physics_process(false)


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr(
		"Wall-jump camera focus probe timed out. Run it with -Visual through "
		+ "tools/run_godot_tool.ps1."
	)
	_release_inputs()
	quit(1)
