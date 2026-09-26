extends SceneTree
## Opt-in addon exploration, not a traversal runner. Uses a real orthographic
## viewport to exercise the addon, including its screen-space framing mode.
var results := {}

func _init() -> void:
	call_deferred("_run")
	create_timer(30).timeout.connect(func(): printerr("Phantom mode probe timed out"); quit(1))

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var target := Node3D.new()
	viewport.add_child(target)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.9375
	viewport.add_child(camera)
	camera.make_current()
	var host := PhantomCameraHost.new()
	host.interpolation_mode = PhantomCameraHost.InterpolationMode.MANUAL
	camera.add_child(host)
	var pcam := PhantomCamera3D.new()
	pcam.priority = 10
	pcam.tween_on_load = false
	pcam.follow_mode = PhantomCamera3D.FollowMode.SIMPLE
	pcam.follow_target = target
	pcam.follow_offset = Vector3(4, 2.7, 24)
	viewport.add_child(pcam)
	await process_frame
	await process_frame
	assert(host.get_active_pcam() == pcam)
	pcam.teleport_position()
	host.process(0)
	assert(camera.position.is_equal_approx(Vector3(4, 2.7, 24)))
	results.simple = "Exact target offset; no composition limits"
	# Damping should converge without overshoot and survive a mid-motion reversal.
	pcam.follow_damping = true
	pcam.follow_damping_value = Vector3(0.25, 0.35, 0.1)
	var fps_endpoints := []
	for fps in [30, 60, 144]:
		target.position = Vector3.ZERO
		pcam.teleport_position()
		var previous := camera.position.x
		target.position.x = 10
		for frame in fps:
			host.process(1.0 / fps)
			assert(camera.position.x >= previous - 0.001 and camera.position.x <= 14.001)
			previous = camera.position.x
		fps_endpoints.append(camera.position.x)
		target.position.x = -10
		for frame in fps:
			host.process(1.0 / fps)
			assert(camera.position.x >= -6.001)
	assert(absf(fps_endpoints[0] - fps_endpoints[2]) < 0.03)
	results.damping_endpoints_30_60_144 = fps_endpoints
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0, 2.7, 24))
	path.curve.add_point(Vector3(10, 2.7, 24))
	viewport.add_child(path)
	pcam.follow_mode = PhantomCamera3D.FollowMode.PATH
	pcam.follow_path = path
	target.position = Vector3(30, 10, 0)
	pcam.teleport_position()
	host.process(0)
	assert(camera.position.distance_to(Vector3(10, 2.7, 24)) < 0.001)
	results.path = "Clamps to authored rail; teleport resolves closest point"
	var other := Node3D.new()
	other.position = Vector3(20, 0, 0)
	viewport.add_child(other)
	pcam.follow_mode = PhantomCamera3D.FollowMode.GROUP
	pcam.follow_targets = [target, other]
	pcam.follow_offset = Vector3(0, 0, 0)
	pcam.follow_distance = 24
	pcam.teleport_position()
	host.process(0)
	assert(camera.position.distance_to(Vector3(25, 5, 24)) < 0.001)
	results.group = "Tracks bounds midpoint, including target vertical movement"
	# Measure Framed in our XY side-view orientation rather than assuming the
	# plugin's 3D defaults behave like its 2D version.
	pcam.free()
	pcam = PhantomCamera3D.new()
	pcam.position = Vector3(0, 0, 24)
	pcam.priority = 10
	pcam.tween_on_load = false
	pcam.follow_distance = 24
	pcam.follow_mode = PhantomCamera3D.FollowMode.FRAMED
	pcam.follow_target = target
	pcam.follow_damping = false
	pcam.follow_offset = Vector3.ZERO
	pcam.dead_zone_width = 0.3
	pcam.dead_zone_height = 0.3
	target.position = Vector3.ZERO
	camera.position = Vector3(0, 0, 24)
	viewport.add_child(pcam)
	await process_frame
	await process_frame
	pcam.teleport_position()
	host.process(0)
	var framed_start := camera.position
	target.position = Vector3(10, 8, 0)
	for frame in 60: host.process(1.0 / 60)
	results.framed_start = str(framed_start)
	results.framed_after_xy_movement = str(camera.position)
	results.framed_target_screen = str(camera.unproject_position(target.position))
	# Native priority blend, interruption, and teleport during an active blend.
	pcam.follow_mode = PhantomCamera3D.FollowMode.SIMPLE
	pcam.follow_offset = Vector3(0, 0, 24)
	target.position = Vector3.ZERO
	pcam.teleport_position()
	host.process(0)
	var alternate := PhantomCamera3D.new()
	alternate.position = Vector3(15, 4, 24)
	alternate.tween_resource = PhantomCameraTween.new()
	alternate.tween_resource.duration = 0.6
	viewport.add_child(alternate)
	await process_frame
	alternate.priority = 20
	host.process(1.0 / 60)
	assert(camera.position.x < 1, "Priority transition should not snap.")
	for frame in 12: host.process(1.0 / 60)
	var before := camera.position
	pcam.priority = 30
	host.process(1.0 / 60)
	assert(camera.position.distance_to(before) < 1, "Interrupted priority blend jumped.")
	pcam.teleport_position()
	host.process(0)
	results.teleport_during_priority_blend_error = camera.position.distance_to(Vector3(0, 0, 24))
	results.priority = "Blend and reversal passed; teleport does not cancel an in-progress priority tween in 0.11.0.3"
	var file := FileAccess.open("res://build/phantom_camera_modes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print(JSON.stringify(results))
	viewport.queue_free()
	await process_frame
	print("Phantom Camera mode probe passed.")
	quit(0)
