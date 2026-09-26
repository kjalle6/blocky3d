extends SceneTree
## Bounded camera trajectories, not simulated attempts at platforming.
const FIXTURE := preload("res://tools/level_3_shooter_area_fixture.gd")
const TRACK := [Vector3(46.5, 0.55, 0), Vector3(61.5, 0.55, 0), Vector3(69.3, 0.55, 0), Vector3(71, 26.15, 0), Vector3(76, 26.15, 0), Vector3(92, 26.15, 0)]
const TIMES := [0.0, 2.0, 3.0, 9.0, 10.0, 12.0]
var level: LevelSession3D
var report := {}

func _init() -> void:
	call_deferred("_run")
	create_timer(25).timeout.connect(func(): printerr("Phantom camera checks timed out."); quit(1))

func _at(time: float) -> Vector3:
	for i in range(1, TIMES.size()):
		if time <= TIMES[i]:
			return TRACK[i - 1].lerp(TRACK[i], inverse_lerp(TIMES[i - 1], TIMES[i], time))
	return TRACK.back()

func _run() -> void:
	level = FIXTURE.instantiate_session()
	root.add_child(level)
	await process_frame
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var player := level.player
	var camera = level.camera
	var host: PhantomCameraHost = camera.phantom_host
	var pcam: PhantomCamera3D = camera.phantom_camera
	assert(host.get_active_pcam() == pcam)
	assert(host.interpolation_mode == PhantomCameraHost.InterpolationMode.MANUAL)
	assert(camera.process_priority < level.background.process_priority)
	assert(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, 12.9375))
	var pixel: float = camera.world_units_per_screen_pixel()
	var endpoints := []
	for fps in [30, 60, 144]:
		player.position = TRACK[0]
		camera.snap_to_target()
		var previous: Vector3 = camera.position
		var max_step := 0.0
		for frame in range(1, 24 * fps + 1):
			var time := frame / float(fps)
			player.position = _at(time if time <= 12 else 24 - time)
			camera._process(1.0 / fps)
			max_step = maxf(max_step, camera.position.distance_to(previous))
			assert(camera.position.distance_to(previous) < 0.65, "Abrupt rail movement at %s FPS, t=%s" % [fps, time])
			var phase := Vector2(camera.position.x, camera.position.y - camera.camera_height) / pixel
			assert(phase.distance_to(phase.round()) < 0.002, "Pixel grid drift")
			var screen: Vector2 = camera.unproject_position(player.position + Vector3(0, 0.5, 0))
			assert(camera.get_viewport().get_visible_rect().has_point(screen), "Rail lost player at %s FPS t=%s player=%s camera=%s mode=%s screen=%s" % [fps, time, player.position, camera.position, pcam.follow_mode, screen])
			assert(is_equal_approx(camera.position.z, 24) and camera.basis.is_equal_approx(Basis.IDENTITY))
			previous = camera.position
		endpoints.append(camera.position.x)
		report[str(fps) + "fps_max_step"] = max_step
	assert(absf(endpoints[0] - endpoints[2]) < 0.2)
	# The old hard boundary no longer dictates the composition.
	player.position = Vector3(62.71, 0.55, 0)
	camera.snap_to_target()
	var before: Vector3 = camera.position
	player.position.x = 62.73
	camera._process(1.0 / 60)
	assert(camera.position.distance_to(before) <= pixel * 2)
	# Both characters remain visible while wall-jumping, including a high apex.
	for point in [Vector3(69.3, 5.5, 0), Vector3(71.8, 8.2, 0), Vector3(70, 8.6, 0)]:
		player.position = point
		camera.snap_to_target()
		var screen: Vector2 = camera.unproject_position(Vector3(70.72, 1.2, 0))
		assert(camera.get_viewport().get_visible_rect().has_point(screen), "Tank lost before reaching cover")
	# Stationary targets settle completely; teleports wipe the old velocity.
	player.position = Vector3(76, 26.15, 0)
	for frame in 180: camera._process(1.0 / 60)
	before = camera.position
	for frame in 120: camera._process(1.0 / 60)
	assert(camera.position == before, "Camera drifts while standing still")
	player.position = TRACK[0]
	camera.snap_to_target()
	before = camera.position
	camera._process(1.0 / 60)
	assert(camera.position.distance_to(before) <= pixel)
	# Optional climb: ascend, cross the roof and descend without losing the
	# player or changing pixel phase. No traversal input simulation is needed.
	for fps in [30, 60, 144]:
		player.position = Vector3(70, 6.23, 0)
		camera.snap_to_target()
		var previous: Vector3 = camera.position
		for frame in range(1, 16 * fps + 1):
			var time := frame / float(fps)
			var altitude := 6.23 + 35.0 * sin(PI * time / 16.0)
			player.position = Vector3(68 + 2 * cos(time * 2), altitude, 0)
			camera._process(1.0 / fps)
			var head: Vector2 = camera.unproject_position(player.position + Vector3(0, 0.8, 0))
			assert(camera.get_viewport().get_visible_rect().has_point(head), "Upper climb lost player head")
			assert(camera.position.distance_to(previous) < 0.65, "Upper follow handover jumped")
			var phase := Vector2(camera.position.x, camera.position.y - camera.camera_height) / pixel
			assert(phase.distance_to(phase.round()) < 0.002)
			previous = camera.position
		assert(pcam.follow_mode == PhantomCamera3D.FollowMode.PATH)
	for altitude in [36.39, 41.0, 0.55, 36.39, 6.23]:
		player.position = Vector3(65.28, altitude, 0)
		camera.snap_to_target()
		if altitude >= 11:
			assert(pcam.follow_mode == PhantomCamera3D.FollowMode.SIMPLE)
			assert(absf(camera.position.y - (altitude - 1)) <= pixel)
		else:
			assert(pcam.follow_mode == PhantomCamera3D.FollowMode.PATH)
	assert(pcam.follow_offset.is_equal_approx(Vector3(4, 1.7, 24)), "Upper saves must not overwrite route offset")
	# The chest stays above the ordinary exit's frame until the player climbs.
	player.position = Vector3(76, 26.15, 0)
	camera.snap_to_target()
	var roof: Vector3 = level.get_node("TankEncounter/Climb/ScaffoldReward").global_position
	assert(camera.unproject_position(roof).y < 0, "The roof reward should be discovered by climbing higher")
	# Returning along the raised ground resumes the bounded route rail. A reload
	# at that point must produce the same composition as walking there.
	player.position = Vector3(92, 26.15, 0)
	for frame in 240: camera._process(1.0 / 60)
	assert(pcam.follow_mode == PhantomCamera3D.FollowMode.PATH)
	before = camera.position
	camera.snap_to_target()
	assert(camera.position.distance_to(before) <= pixel)
	player.position = TRACK[0]
	camera.snap_to_target()
	before = camera.position
	# Inspection ignores the rail and comes back to exactly the rail on exit.
	camera.set_developer_inspection_enabled(true)
	player.position = Vector3(150, 30, 0)
	camera._process(1.0 / 60)
	assert(absf(camera.position.x - 150) < pixel)
	player.position = TRACK[0]
	camera.set_developer_inspection_enabled(false)
	assert(camera.position.distance_to(before) <= pixel)
	# The existing cinematic owns a marker, zoom and look-ahead, without a
	# second autonomous host update moving the camera later in the frame.
	var marker := Node3D.new()
	level.add_child(marker)
	marker.position = Vector3(23.04, 0.7, 0)
	camera.target = marker
	camera.cinematic_override_enabled = true
	camera.look_ahead = 0
	camera.size = 8
	camera.snap_to_target()
	assert(absf(camera.position.x - marker.position.x) <= pixel)
	assert(is_equal_approx(camera.size, 8))
	camera.target = player
	camera.cinematic_override_enabled = false
	camera.size = 12.9375
	camera._process(1.0 / 60)
	assert(pcam.follow_mode == PhantomCamera3D.FollowMode.PATH)
	# Disabling processing really hands off the physical camera.
	camera.position = Vector3(30, 4, 24)
	before = camera.position
	await process_frame
	await process_frame
	assert(camera.position == before)
	level.queue_free()
	await process_frame
	# New sessions must bind their own camera after the previous one is freed.
	level = FIXTURE.instantiate_session()
	root.add_child(level)
	await process_frame
	await process_frame
	assert(level.camera.phantom_host.get_active_pcam() == level.camera.phantom_camera)
	assert(level.camera.phantom_camera.follow_target == level.player)
	level.queue_free()
	await process_frame
	FileAccess.open("res://build/phantom_camera_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("Phantom camera passed: 30/60/144 FPS rail and optional upper climb, pixel grid, visibility, boundary crossing, settling, roof/ground respawn, inspection, cinematic ownership, disabled processing, and reload.")
	quit(0)
