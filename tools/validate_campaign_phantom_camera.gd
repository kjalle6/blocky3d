extends SceneTree
## Deterministic framing checks at walking, jumping and terminal-fall speeds.
## No input bot or route completion attempts.
const ADAPTER = preload("res://scripts/camera/phantom_pixel_camera_3d.gd")
const CASES = [
	[
		"res://scenes/levels/arrival_shoreline.tscn",
		"res://resources/campaign/level_01.tres",
		[Vector3(4, 0.55, 0), Vector3(35, 1.19, 0), Vector3(47, 4.39, 0), Vector3(73, 1.19, 0), Vector3(103, 3.75, 0), Vector3(119, 1.19, 0), Vector3(132, 4.39, 0), Vector3(142, 11, 0), Vector3(151, 5.03, 0), Vector3(160, 13, 0), Vector3(181, 1.19, 0), Vector3(196, 1.19, 0)]
	],
	[
		"res://scenes/levels/overgrown_coastal_ascent.tscn",
		"res://resources/campaign/level_02.tres",
		[Vector3(4, 0.55, 0), Vector3(20, 0.55, 0), Vector3(35, 0.55, 0)]
	],
	[
		"res://scenes/levels/overgrown_coastal_ascent_interior.tscn",
		"res://resources/campaign/level_02.tres",
		[Vector3(4.48, 0.7, 0), Vector3(37, 3.26, 0), Vector3(47.36, 5.18, 0), Vector3(57.6, 7.1, 0), Vector3(56.72, 14, 0), Vector3(61.04, 21, 0), Vector3(56.72, 26, 0), Vector3(58, 29, 0), Vector3(48.64, 28.7, 0), Vector3(80.64, 28.7, 0), Vector3(94.08, 33, 0), Vector3(104.32, 28.7, 0), Vector3(120.96, 33, 0), Vector3(132, 28.7, 0), Vector3(172, 28.7, 0)]
	],
	[
		"res://scenes/dev/green_zone_finale_wip.tscn",
		"res://resources/dev/green_zone_finale_wip.tres",
		[Vector3(4, 0.55, 0), Vector3(84, 0.55, 0), Vector3(110, 0.55, 0), Vector3(120, -12, 0), Vector3(132.48, -24.9, 0), Vector3(150, -24.9, 0), Vector3(157.44, -19, 0), Vector3(157.44, -8, 0), Vector3(157.44, 0.55, 0), Vector3(169, 0.55, 0)]
	]
]
var report := {}

func _init() -> void:
	call_deferred("_run")
	create_timer(40).timeout.connect(func(): printerr("Campaign camera checks timed out"); quit(1))

func _run() -> void:
	for entry in CASES:
		var level = load(entry[0]).instantiate()
		var definition: LevelDefinition = load(entry[1])
		level.configure(definition, null, definition.assumed_owned_abilities.duplicate())
		root.add_child(level)
		await process_frame
		await process_frame
		level.process_mode = Node.PROCESS_MODE_DISABLED
		var camera = level.camera
		var normal_offset: Vector3 = camera.phantom_camera.follow_offset
		assert(camera.get_script() == ADAPTER)
		assert(camera.phantom_host.get_active_pcam() == camera.phantom_camera)
		assert(camera.process_priority < level.background.process_priority)
		var pixel: float = camera.world_units_per_screen_pixel()
		for fps in [30, 60, 144]:
			level.player.position = entry[2][0]
			camera.snap_to_target()
			var max_step := 0.0
			for direction in [1, -1]:
				var points: Array = entry[2].duplicate()
				if direction < 0: points.reverse()
				for i in range(1, points.size()):
					var duration: float = maxf(0.8, points[i].distance_to(points[i - 1]) / 6.0)
					var frames := ceili(duration * fps)
					for frame in range(1, frames + 1):
						level.player.position = points[i - 1].lerp(points[i], float(frame) / frames)
						var before: Vector3 = camera.position
						camera._process(1.0 / fps)
						max_step = maxf(max_step, camera.position.distance_to(before))
						assert(camera.position.distance_to(before) < 0.75, "Camera lurch %s %d FPS player=%s before=%s after=%s" % [entry[0], fps, level.player.position, before, camera.position])
						_check_frame(level, pixel)
				for frame in fps * 2: camera._process(1.0 / fps)
			report[entry[0] + "_" + str(fps)] = max_step
		# Saves/restarts and inspection must reconstruct the same composition.
		for point in entry[2]:
			level.player.position = point
			camera.snap_to_target()
			_check_frame(level, pixel)
			var before: Vector3 = camera.position
			for frame in 120: camera._process(1.0 / 60)
			assert(camera.position.distance_to(before) <= pixel * 2)
			camera.set_developer_inspection_enabled(true)
			camera.set_developer_inspection_enabled(false)
			assert(camera.position.distance_to(before) <= pixel * 2)
		if "interior" in entry[0]: _check_cave(level)
		if "finale_wip" in entry[0]: _check_drop(level)
		level.player.position = entry[2][0]
		camera.snap_to_target()
		assert(camera.phantom_camera.follow_offset.is_equal_approx(normal_offset), "Reloading a branch must preserve the surface offset")
		level.queue_free()
		await process_frame
	FileAccess.open("res://build/campaign_camera_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("Campaign Phantom cameras passed: four sections, both directions at 30/60/144 FPS, visibility, pixel alignment, restart/inspection, shaft focus, upper cave holds, and terminal-speed drop.")
	quit()

func _check_frame(level, pixel: float) -> void:
	var camera = level.camera
	var phase: Vector2 = Vector2(camera.position.x, camera.position.y - camera.camera_height) / pixel
	assert(phase.distance_to(phase.round()) < 0.002)
	assert(camera.basis.is_equal_approx(Basis.IDENTITY) and is_equal_approx(camera.position.z, 24))
	for offset in [Vector3.DOWN * 0.4, Vector3.UP * 0.8]:
		var screen: Vector2 = camera.unproject_position(level.player.position + offset)
		assert(camera.get_viewport().get_visible_rect().has_point(screen), "Lost player %s at %s camera %s" % [level.name, level.player.position, camera.position])

func _check_cave(level) -> void:
	for x in [56.72, 58.88, 61.04]:
		level.player.position = Vector3(x, 18, 0)
		level.camera.snap_to_target()
		assert(absf(level.camera.position.x - 58.88) < 0.02, "Shaft must not sway between walls")
	for point in [Vector3(48.64, 28.7, 0), Vector3(94.08, 23, 0), Vector3(120.96, 23, 0), Vector3(132, 34, 0), Vector3(172, 39, 0)]:
		level.player.position = point
		level.camera.snap_to_target()
		assert(absf(level.camera.position.y - 30.7) < 0.02, "Upper jumps, lethal water and lift must hold the cave framing")

func _check_drop(level) -> void:
	for fps in [30, 60, 144]:
		for drop_x in [110.6, 120.0, 129.0]:
			level.player.position = Vector3(drop_x, 0.55, 0)
			level.camera.snap_to_target()
			var speed := 0.0
			for frame in fps * 3:
				if level.player.position.y <= -24.89: break
				speed = minf(speed + level.player.movement.gravity / fps, level.player.movement.maximum_fall_speed)
				level.player.position.y = maxf(-24.9, level.player.position.y - speed / fps)
				level.camera._process(1.0 / fps)
				_check_frame(level, level.camera.world_units_per_screen_pixel())
