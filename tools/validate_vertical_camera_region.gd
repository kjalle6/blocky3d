extends SceneTree
## Focused contract for the opt-in vertical camera volume used by rising route
## sections. The production Arrival scene does not need to host test geometry.

const FRAME_DELTA := 1.0 / 60.0
const BASE_CAMERA_Y := 3.98
const PIXEL_EPSILON := 0.001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	var fixture := Node3D.new()
	root.add_child(fixture)

	var target := Node3D.new()
	fixture.add_child(target)
	var region := VerticalCameraRegion3D.new()
	region.position = Vector3(20.0, 2.0, 0.0)
	region.size = Vector2(32.0, 20.0)
	region.vertical_anchor_y = 1.98
	region.minimum_vertical_offset = 0.0
	region.maximum_vertical_offset = 4.0
	fixture.add_child(region)

	var camera := PixelSideCamera3D.new()
	camera.target = target
	camera.camera_height = BASE_CAMERA_Y
	camera.target_height = BASE_CAMERA_Y
	camera.minimum_center_x = -20.0
	camera.maximum_center_x = 60.0
	camera.look_ahead = 0.0
	camera.vertical_follow_response = 7.0
	camera.current = true
	fixture.add_child(camera)
	camera.bind_vertical_regions([region])
	await process_frame

	# Entering at ordinary ground height activates the volume without changing
	# the established framing.
	target.global_position = Vector3(5.0, 0.7, 0.0)
	camera.snap_to_target()
	_assert_camera_y(camera, BASE_CAMERA_Y)
	assert(camera.active_vertical_region() == region)

	# A genuine climb moves smoothly: no first-frame snap, monotonic response,
	# and no output-pixel phase drift.
	target.global_position = Vector3(18.0, 7.1, 0.0)
	var previous_y := camera.global_position.y
	for frame in 60:
		camera._process(FRAME_DELTA)
		assert(camera.global_position.y >= previous_y - PIXEL_EPSILON)
		assert(camera.global_position.y - previous_y < 0.5)
		_assert_pixel_phase(camera)
		previous_y = camera.global_position.y
	assert(camera.global_position.y > BASE_CAMERA_Y + 2.8)
	assert(camera.global_position.y <= BASE_CAMERA_Y + 4.01)

	# Moving back left inside the fold must not deactivate vertical framing.
	target.global_position = Vector3(9.0, 7.1, 0.0)
	for frame in 12:
		camera._process(FRAME_DELTA)
	assert(camera.active_vertical_region() == region)
	assert(camera.global_position.y > BASE_CAMERA_Y + 2.8)

	# Crossing the far boundary during a jump eases toward the normal frame; it
	# never teleports the rendered camera.
	target.global_position = Vector3(37.0, 7.1, 0.0)
	previous_y = camera.global_position.y
	camera._process(FRAME_DELTA)
	assert(camera.active_vertical_region() == null)
	assert(absf(camera.global_position.y - previous_y) < 0.5)
	_assert_pixel_phase(camera)

	# A checkpoint/death reset uses snap_to_target after relocating the player,
	# restoring the exact baseline instead of retaining stale region state.
	target.global_position = Vector3(2.0, 0.7, 0.0)
	camera.snap_to_target()
	_assert_camera_y(camera, BASE_CAMERA_Y)
	assert(camera.active_vertical_region() == null)

	# Region anchors are local to their section instance. Translating the whole
	# section preserves the same relative camera response.
	region.position.y += 10.0
	target.global_position = Vector3(18.0, 17.1, 0.0)
	camera.snap_to_target()
	_assert_camera_y(camera, BASE_CAMERA_Y + 3.12)
	# Region changes must ease their initial acceleration on both axes, including
	# quick boundary reversals. Normal tracking and explicit reset remain direct.
	for fps in [30.0, 60.0, 144.0]:
		_check_framing_handover(camera, target, region, 1.0 / fps)

	print("Vertical camera-region validation passed.")
	quit(0)


func _check_framing_handover(camera: PixelSideCamera3D, target: Node3D, region: VerticalCameraRegion3D, delta: float) -> void:
	region.position = Vector3(10.0, 2.0, 0.0)
	region.size = Vector2(20.0, 20.0)
	region.horizontal_focus_enabled = true
	camera.look_ahead = 2.6
	target.position = Vector3(-0.05, 7.1, 0)
	camera.snap_to_target()
	var before := camera.global_position
	target.position.x = 0.05
	camera._process(delta)
	assert(camera.active_horizontal_focus_region() == region)
	assert(absf(camera.global_position.x - before.x) < 0.04,
		"Entering focus should ease in, not lurch toward its new centre.")
	assert(absf(camera.global_position.y - before.y) < 0.04)
	for frame in ceili(1.8 / delta):
		camera._process(delta)
		_assert_pixel_phase(camera)
	assert(absf(camera.global_position.x - 10.0) < 0.03)
	_assert_camera_y(camera, BASE_CAMERA_Y + 3.12)
	# A larger exit shift, like leaving the tank shaft, needs the same easing.
	target.position.x = 20.05
	before = camera.global_position
	camera._process(delta)
	assert(absf(camera.global_position.x - before.x) < 0.04)
	assert(absf(camera.global_position.y - before.y) < 0.04)
	for frame in ceili(0.1 / delta): camera._process(delta)
	target.position.x = 19.95
	before = camera.global_position
	camera._process(delta)
	assert(camera.global_position.distance_to(before) < 0.25, "Re-entry must continue from the in-flight framing.")
	for frame in ceili(0.1 / delta): camera._process(delta)
	target.position.x = 20.05
	for frame in ceili(1.8 / delta): camera._process(delta)
	assert(absf(camera.global_position.x - 22.65) < 0.03)
	_assert_camera_y(camera, BASE_CAMERA_Y)
	# An X-only framing change must not defer a simultaneous vertical climb.
	region.vertical_framing_enabled = false
	camera.vertical_follow_enabled = true
	camera.vertical_anchor_y = 0.7
	camera.maximum_vertical_offset = 8.0
	target.position = Vector3(-0.05, 0.7, 0)
	camera.snap_to_target()
	target.position = Vector3(0.05, 1.7, 0)
	camera._process(delta)
	_assert_camera_y(camera, BASE_CAMERA_Y + (1.0 - exp(-7.0 * delta)))
	# Loading within a handover restores the exact authored composition.
	region.vertical_framing_enabled = true
	camera.vertical_follow_enabled = false
	target.position = Vector3(5, 7.1, 0)
	camera.snap_to_target()
	assert(absf(camera.global_position.x - 10.0) < 0.02)
	_assert_camera_y(camera, BASE_CAMERA_Y + 3.12)
	target.position = Vector3(40, 0.7, 0)
	camera.snap_to_target()
	target.position.x = 41
	camera._process(delta)
	var expected_x := 42.6 + (1.0 - exp(-camera.follow_response * delta))
	assert(absf(camera.global_position.x - expected_x) <= camera.world_units_per_screen_pixel(),
		"Ordinary follow response must remain unchanged.")


func _assert_camera_y(camera: PixelSideCamera3D, expected_y: float) -> void:
	var tolerance := camera.world_units_per_screen_pixel() + PIXEL_EPSILON
	assert(absf(camera.global_position.y - expected_y) <= tolerance)
	_assert_pixel_phase(camera)


func _assert_pixel_phase(camera: PixelSideCamera3D) -> void:
	var pixel_world_size := camera.world_units_per_screen_pixel()
	assert(pixel_world_size > 0.0)
	var pixel_y := (
		camera.global_position.y - camera.camera_height
	) / pixel_world_size
	assert(absf(pixel_y - roundf(pixel_y)) < PIXEL_EPSILON)
