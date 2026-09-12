extends SceneTree
## Visual-review frames for the player firearm and contextual
## two-slot HUD. This is presentation evidence, not gameplay acceptance.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews"
const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame

	var shooter := level.get_node(
		"ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy"
	) as HandgunEnemy3D
	var pickup := level.get_node(
		"ShooterEncounterStaging/GunDropAnchor/HandgunPickup"
	) as HandgunPickup3D
	assert(shooter != null and pickup != null)
	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	shooter.receive_melee_hit(level.player.global_position)
	pickup.mark_claimed()
	for frame in 45:
		await physics_frame

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(20.48, 0.7, 0.0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture("player_handgun_idle_and_hud")

	Input.action_press("move_right")
	for frame in 12:
		await physics_frame
	await _capture("player_handgun_run")
	Input.action_release("move_right")
	for frame in 18:
		await physics_frame

	Input.action_press("attack")
	for frame in 20:
		await physics_frame
		if level.player.pixel_visual.shot_effect.visible:
			break
	Input.action_release("attack")
	assert(level.player.pixel_visual.shot_effect.visible)
	await _capture("player_handgun_fire_horizontal")
	for frame in 28:
		await physics_frame

	Input.action_press("aim_up")
	Input.action_press("attack")
	for frame in 20:
		await physics_frame
		if level.player.pixel_visual.shot_effect.visible:
			break
	Input.action_release("attack")
	assert(level.player.pixel_visual.shot_effect.visible)
	await _capture("player_handgun_fire_upward")
	Input.action_release("aim_up")
	for frame in 28:
		await physics_frame

	Input.action_press("jump")
	for frame in 10:
		await physics_frame
	Input.action_release("jump")
	await _capture("player_handgun_jump")

	for frame in 60:
		await physics_frame
	level.player.projectile_fired.connect(func(round: HandgunProjectile3D) -> void:
		if level.player.player_handgun.mouse_aim_active:
			assert(round.travel_direction().is_equal_approx(level.player.player_handgun.aim_direction))
			assert(round.global_position.is_equal_approx(level.player.pixel_visual.handgun_muzzle_world()))
			assert(round.travel_direction().is_equal_approx((level.player.player_handgun.crosshair_world - round.global_position).normalized()))
	)
	for facing in [1.0, -1.0]:
		level.player._facing_sign = facing
		for height in [7.0, -7.0]:
			var target := level.player.global_position + Vector3(-1 * facing, height, 0)
			root.warp_mouse(level.camera.unproject_position(target))
			level.player.player_handgun._mouse_requested = true
			for frame in 8:
				await physics_frame
			Input.action_press("attack")
			for frame in 20:
				await physics_frame
				if level.player.pixel_visual.shot_effect.visible:
					break
			Input.action_release("attack")
			await _capture("player_mouse_aim_%s_%s" % ["right" if facing > 0 else "left", "up" if height > 0 else "down"])
			for frame in 28:
				await physics_frame

	for aim_side in [1.0, -1.0]:
		var target := level.player.global_position + Vector3(6 * aim_side, 1, 0)
		root.warp_mouse(level.camera.unproject_position(target))
		level.player.player_handgun._mouse_requested = true
		var move_action := "move_left" if aim_side > 0 else "move_right"
		Input.action_press(move_action)
		for frame in 12:
			await physics_frame
		assert(level.player.horizontal_speed * aim_side < 0)
		assert(is_equal_approx(absf(level.player.horizontal_speed), level.player.movement.maximum_speed * level.player.handgun_backpedal_speed_ratio))
		assert(level.player.pixel_visual.current_state() == "backpedal")
		assert(level.player.pixel_visual.body.texture.resource_path.ends_with("player_handgun_walk_one_hand.png"))
		assert(level.player.pixel_visual.body.flip_h == (aim_side < 0))
		await _capture("player_mouse_retreat_%s" % ["right" if aim_side > 0 else "left"])
		Input.action_release(move_action)
		for frame in 20:
			await physics_frame

	_release_input()
	await _capture_shot_sequences(level, shooter)
	quit(0)


func _capture(file_name: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Player-handgun review requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIRECTORY, file_name])
	assert(error == OK, "Could not save player-handgun review '%s'." % file_name)


func _release_input() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"attack", &"aim_up"]:
		Input.action_release(action)


func _capture_shot_sequences(level: LevelSession3D, shooter: HandgunEnemy3D) -> void:
	# Render real shot events at known simulation times. Pausing automatic
	# processing prevents screenshot readback time from changing the animation.
	var player := level.player
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(20.48, 0.7, 0.0)))
	player.player_handgun._mouse_requested = false
	player.player_handgun.reset_run()
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	paused = true
	player._facing_sign = 1.0
	player.pixel_visual.set_state("idle", true)
	player._update_pixel_visual(0.0)
	var round := player.player_handgun.fire(1.0, false, player)
	assert(round != null)
	player.pixel_visual.tick_authored_state(0.0, "idle", true)
	for step in 16:
		await _capture_sequence_frame(level, "player_shot", step)
		for tick in 2:
			player.pixel_visual.tick_authored_state(1.0 / 60.0, "idle", true)
			if is_instance_valid(round):
				round._physics_process(1.0 / 60.0)
	if is_instance_valid(round):
		round.reset_run()
	paused = false
	shooter.reset_run()
	# Reset restores collisions through deferred calls. Let those apply and
	# the body settle normally before freezing the enemy's review sequence.
	for frame in 8:
		await physics_frame
	paused = true
	shooter.set_engagement_enabled(true)
	# Keep the review target visible for the full volley without a respawn
	# moving the camera midway through this paused, tool-only capture.
	player.collision_layer = 0
	shooter._begin_volley()
	for step in 25:
		await _capture_sequence_frame(level, "enemy_volley", step)
		for tick in 2:
			shooter._physics_process(1.0 / 60.0)
			for projectile in shooter._active_projectiles.duplicate():
				if is_instance_valid(projectile):
					projectile._physics_process(1.0 / 60.0)
	shooter.clear_active_projectiles()
	paused = false


func _capture_sequence_frame(level: LevelSession3D, prefix: String, step: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Shot sequences require a graphical renderer.")
	var center: Vector2 = level.camera.unproject_position(level.player.global_position + Vector3(2.5, 0.5, 0.0))
	var crop := Rect2i(Vector2i(center) - Vector2i(360, 160), Vector2i(720, 320))
	var error := image.get_region(crop).save_png(
		"%s/%s_%02d.png" % [OUTPUT_DIRECTORY, prefix, step]
	)
	assert(error == OK)
