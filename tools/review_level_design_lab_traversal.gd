extends SceneTree
## Real-input traversal and paired visual review for the Level Design Lab fixture.
## The bot starts at the authored spawn and crosses the room without teleports.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews/level_design_lab_review"
const MAXIMUM_FRAMES := 1800
const JUMP_HOLD_FRAMES := 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/dev/level_design_lab.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	for frame in 12:
		await physics_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var stage := 0
	var desired_direction := 1.0
	var jump_hold_remaining := 0
	var jump_is_held := false
	var dash_pressed := false
	var wall_jump_count := [0]
	var dash_count := [0]
	var death_count := [0]
	var captured_tunnel := false
	var captured_shaft := false
	var captured_upper := false
	var captured_dash := false
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.WALL_JUMP:
				wall_jump_count[0] += 1
			elif ability_id == PlayerAbility.DASH:
				dash_count[0] += 1
	)
	player.died.connect(func() -> void: death_count[0] += 1)
	await _capture_pair(game_root, level, "00_spawn")

	for frame in MAXIMUM_FRAMES:
		if player.is_dead():
			break
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
				if not captured_tunnel and player.global_position.x >= 18.0:
					captured_tunnel = true
					await _capture_pair(game_root, level, "01_entrance_tunnel")
				if player.is_on_floor() and player.global_position.x >= 33.3:
					stage = 1
					desired_direction = 1.0
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES

			1:
				_set_horizontal_input(desired_direction)
				if (
					not captured_shaft
					and player.global_position.y >= 5.5
				):
					captured_shaft = true
					await _capture_pair(game_root, level, "02_wall_jump_shaft")
				var wall_direction := player.wall_contact_direction()
				if (
					not is_zero_approx(wall_direction)
					and wall_direction != player.blocked_wall_jump_direction()
					and not jump_is_held
				):
					desired_direction = -wall_direction
					jump_is_held = _request_jump(jump_is_held)
					jump_hold_remaining = JUMP_HOLD_FRAMES
				if (
					player.is_on_floor()
					and player.global_position.y > 13.0
					and player.global_position.x > 35.8
				):
					stage = 2

			2:
				_set_horizontal_input(0.0)
				if not captured_upper:
					captured_upper = true
					await _capture_pair(game_root, level, "03_upper_landing")
				_set_horizontal_input(1.0)
				Input.action_press("dash")
				dash_pressed = true
				stage = 3

			3:
				_set_horizontal_input(1.0)
				if not captured_dash and player.global_position.x >= 43.0:
					captured_dash = true
					await _capture_pair(game_root, level, "04_dash_corridor")
				if player.global_position.x >= 54.0:
					stage = 4
					_set_horizontal_input(0.0)
					await _capture_pair(game_root, level, "05_corridor_end")
					break

		await physics_frame

	_release_inputs()
	if death_count[0] > 0 or player.is_dead():
		_fail(
			"Traversal died in stage %d near (%.2f, %.2f)."
			% [stage, player.global_position.x, player.global_position.y]
		)
		return
	if stage != 4:
		_fail(
			"Traversal stopped in stage %d near (%.2f, %.2f)."
			% [stage, player.global_position.x, player.global_position.y]
		)
		return
	if wall_jump_count[0] < 2:
		_fail("Traversal did not exercise repeated wall jumps.")
		return
	if dash_count[0] != 1:
		_fail("Traversal must perform exactly one dash.")
		return
	print(
		"Level Design Lab traversed with %d wall jumps and %d dash."
		% [wall_jump_count[0], dash_count[0]]
	)
	quit(0)


func _capture_pair(
	game_root: Node,
	level: LevelSession3D,
	beat_name: String
) -> void:
	var player_processing := level.player.is_physics_processing()
	level.player.set_physics_process(false)
	game_root.get_node("Interface").visible = false
	level.set_developer_collision_overlay_enabled(false)
	level.set_developer_measurement_grid_enabled(false)
	await _capture("%s_clean" % beat_name)

	game_root.get_node("Interface").visible = true
	level.set_developer_collision_overlay_enabled(true)
	level.set_developer_measurement_grid_enabled(true)
	game_root._update_developer_cursor_coordinate_at(OUTPUT_SIZE * 0.5)
	await _capture("%s_diagnostic" % beat_name)
	level.set_developer_collision_overlay_enabled(false)
	level.set_developer_measurement_grid_enabled(false)
	level.player.set_physics_process(player_processing)


func _capture(file_name: String) -> void:
	for frame in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null)
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png(
		"%s/%s.png" % [OUTPUT_DIRECTORY, file_name]
	)
	assert(error == OK)


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


func _fail(message: String) -> void:
	_release_inputs()
	push_error(message)
	quit(1)
