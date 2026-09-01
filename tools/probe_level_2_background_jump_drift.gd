extends SceneTree
## Dynamic diagnostic for the Level 2 upper cave presentation.
##
## Unlike the still-frame review, this drives one ordinary standing jump over
## real physics frames and measures the camera, both global background tracks,
## one localized water vista, and a fixed foreground landmark after rendering.
## It intentionally changes no production state or resources.

const SAMPLE_X := 63.0
const SAMPLE_FEET_Y := 28.16
const PLAYER_CENTER_Y := SAMPLE_FEET_Y + 0.70
const HOLD_JUMP_FRAMES := 18
const MAX_JUMP_FRAMES := 150

var _completed := false
var _ranges := {}
var _samples: Array[Dictionary] = []
var _settled_player_y := 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# This probe waits on frame_post_draw, which never fires without a rendering
	# context: run it through the runner's -Visual switch, not -Headless. The
	# watchdog exists because the headless failure mode is a hang that holds the
	# automation lock rather than an error.
	var watchdog := Timer.new()
	watchdog.wait_time = 120.0
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

	var definition := load(
		"res://resources/dev/overgrown_coastal_ascent_interior_review.tres"
	) as LevelDefinition
	assert(definition != null)
	game_root.load_developer_level(definition)
	for frame in 8:
		await physics_frame

	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	var camera := level.camera as PixelSideCamera3D
	var background := level.background as PixelBackgroundRig3D
	var player := level.player as PlayerCharacter
	var vista := level.get_node(
		"MachineShaftWaterVista"
	) as PixelVistaWindow3D
	assert(camera != null and background != null and player != null)
	assert(vista != null)
	assert(background.runtime_layer_count() >= 2)

	_freeze_enemies(level)
	game_root.get_node("Interface").visible = false
	player.reset_at(
		Transform3D(
			Basis.IDENTITY,
			Vector3(SAMPLE_X, PLAYER_CENTER_Y, 0.0)
		)
	)
	player.velocity = Vector3.ZERO
	player.horizontal_speed = 0.0
	camera.snap_to_target()
	background.snap_to_camera(true)

	# Let floor contact and every camera-coupled presentation node settle before
	# establishing the baseline. Sampling happens after frame_post_draw, not at
	# process_frame, so it observes the frame a player actually sees.
	for frame in 8:
		await _rendered_frame()
	_settled_player_y = player.global_position.y
	_record_sample(level, &"baseline", 0)

	Input.action_press("jump")
	var landed_after_jump := false
	for frame in MAX_JUMP_FRAMES:
		if frame == HOLD_JUMP_FRAMES:
			Input.action_release("jump")
		await _rendered_frame()
		_record_sample(level, &"jump", frame + 1)
		if (
			frame > HOLD_JUMP_FRAMES + 5
			and player.is_on_floor()
			and absf(player.global_position.y - _settled_player_y) < 0.08
		):
			landed_after_jump = true
			break
	Input.action_release("jump")
	_print_report()
	assert(landed_after_jump, "Dynamic background probe never landed after its jump.")
	var camera_range := _range_size(&"camera_y")
	var foreground_screen_range := _range_size(&"floor_screen_y")
	assert(
		camera_range <= 0.02,
		(
			"An ordinary upper-floor jump moved the camera %.4f m; the cave "
			+ "shell must remain still after the shaft reaches its top clamp."
		) % camera_range
	)
	assert(
		foreground_screen_range <= 1.0,
		(
			"An ordinary upper-floor jump moved fixed cave terrain %.3f px "
			+ "on screen."
		) % foreground_screen_range
	)
	_completed = true
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _rendered_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _record_sample(
	level: LevelSession3D,
	phase: StringName,
	frame: int
) -> void:
	var camera := level.camera as PixelSideCamera3D
	var background := level.background as PixelBackgroundRig3D
	var player := level.player as PlayerCharacter
	var vista := level.get_node(
		"MachineShaftWaterVista"
	) as PixelVistaWindow3D
	var base_copy := background.runtime_copies(0)[0]
	var detail_copy := background.runtime_copies(1)[0]
	var fixed_floor_point := Vector3(SAMPLE_X, SAMPLE_FEET_Y, 0.0)
	var sample := {
		"phase": phase,
		"frame": frame,
		"player_y": player.global_position.y,
		"camera_y": camera.global_position.y,
		"floor_screen_y": camera.unproject_position(fixed_floor_point).y,
		"base_world_y": base_copy.global_position.y,
		"base_screen_y": camera.unproject_position(base_copy.global_position).y,
		"base_alpha": base_copy.modulate.a,
		"detail_world_y": detail_copy.global_position.y,
		"detail_screen_y": camera.unproject_position(detail_copy.global_position).y,
		"detail_alpha": detail_copy.modulate.a,
		"vista_world_y": vista.global_position.y,
		"vista_screen_y": camera.unproject_position(vista.global_position).y,
	}
	_samples.append(sample)
	for key in sample:
		if key in [&"phase", &"frame"]:
			continue
		_expand_range(StringName(key), float(sample[key]))


func _expand_range(key: StringName, value: float) -> void:
	if not _ranges.has(key):
		_ranges[key] = Vector2(value, value)
		return
	var current := _ranges[key] as Vector2
	_ranges[key] = Vector2(minf(current.x, value), maxf(current.y, value))


func _range_size(key: StringName) -> float:
	var measured := _ranges[key] as Vector2
	return measured.y - measured.x


func _print_report() -> void:
	print("LEVEL 2 DYNAMIC BACKGROUND JUMP PROBE")
	print("sample_count=%d" % _samples.size())
	for key in [
		&"player_y",
		&"camera_y",
		&"floor_screen_y",
		&"base_world_y",
		&"base_screen_y",
		&"base_alpha",
		&"detail_world_y",
		&"detail_screen_y",
		&"detail_alpha",
		&"vista_world_y",
		&"vista_screen_y",
	]:
		var measured := _ranges[key] as Vector2
		print(
			"%s min=%.6f max=%.6f range=%.6f"
			% [key, measured.x, measured.y, measured.y - measured.x]
		)
	print("SELECTED FRAMES")
	for index in _samples.size():
		if index % 6 != 0 and index != _samples.size() - 1:
			continue
		var sample := _samples[index]
		print(
			(
				"frame=%03d player_y=%.4f camera_y=%.4f floor_px=%.3f "
				+ "base_px=%.3f detail_px=%.3f detail_a=%.3f vista_px=%.3f"
			)
			% [
				int(sample.frame),
				float(sample.player_y),
				float(sample.camera_y),
				float(sample.floor_screen_y),
				float(sample.base_screen_y),
				float(sample.detail_screen_y),
				float(sample.detail_alpha),
				float(sample.vista_screen_y),
			]
		)


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
		"Background jump-drift probe never finished. It needs a rendering "
		+ "context: run it with -Visual rather than -Headless."
	)
	quit(1)
