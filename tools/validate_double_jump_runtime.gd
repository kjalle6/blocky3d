extends SceneTree
## Focused movement contract for Double Jump: coyote jumps preserve it,
## one aerial reset is available, release still shortens it, and horizontal
## momentum is never secretly replaced.
##
## Runs in Firearm Review Lab, which retains the ability-contract fixtures.
## The lab grants the ability outright, so unlocking it is not tested here -
## that path belongs to the pickups in an authored level.

var _finished := false


func _init() -> void:
	call_deferred("_run")
	create_timer(12.0).timeout.connect(_on_watchdog_timeout)


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_developer_room()
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	for frame in 12:
		await physics_frame

	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.aerial_jumps_remaining() == 1)

	var performed_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DOUBLE_JUMP:
				performed_count[0] += 1
	)

	# Run off the retained left boundary wall's top, then use coyote time. This remains the
	# ground jump and must not consume the aerial jump.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.64, 8.38, 0)))
	for frame in 4:
		await physics_frame
	assert(player.is_on_floor())
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if not player.is_on_floor():
			break
	assert(not player.is_on_floor(), "The test should have run off the boundary wall.")
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	Input.action_release("jump")
	assert(player.velocity.y > 0.0, "Coyote input should still produce the ground jump.")
	assert(
		player.aerial_jumps_remaining() == 1,
		"Coyote jumping must preserve the available aerial jump."
	)

	# Allow the coyote window to expire, then reset vertical velocity once.
	for frame in 10:
		await physics_frame
	var horizontal_speed_before := player.horizontal_speed
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	assert(player.velocity.y > 12.0, "Double Jump should reset vertical speed to the jump impulse.")
	assert(player.aerial_jumps_remaining() == 0, "Double Jump should consume exactly one aerial jump.")
	assert(performed_count[0] == 1, "Double Jump should emit one explicit ability-use event.")
	assert(
		absf(player.horizontal_speed - horizontal_speed_before) < 0.2,
		"Double Jump must preserve horizontal momentum."
	)

	# Releasing the same button shortens the second jump just like the first.
	Input.action_release("jump")
	for frame in 2:
		await physics_frame
	assert(
		player.velocity.y < 8.0,
		"Early release should shorten the Double Jump instead of forcing a full arc."
	)

	# A third airborne press cannot manufacture another impulse.
	for frame in 4:
		await physics_frame
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	Input.action_release("jump")
	assert(performed_count[0] == 1, "Only one Double Jump is allowed before refresh.")
	assert(player.aerial_jumps_remaining() == 0)

	Input.action_release("move_right")
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(5.0, 0.7, 0)))
	for frame in 12:
		await physics_frame
	assert(player.is_on_floor())
	assert(player.aerial_jumps_remaining() == 1, "Landing should refresh Double Jump.")
	await _validate_double_jump_fire(level)

	game_root.free()
	_finished = true
	print("Double Jump movement and firearm pose/aim/timing contracts passed.")
	quit(0)


func _validate_double_jump_fire(level: LevelSession3D) -> void:
	var player := level.player
	var visual := player.pixel_visual
	(level.get_node("HandgunEnemy") as HandgunEnemy3D).set_engagement_enabled(false)
	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	var shots: Array[Dictionary] = []
	player.projectile_fired.connect(func(round: HandgunProjectile3D) -> void:
		assert(visual.current_state() == "double_jump")
		assert(visual.gun.visible and visual.gun_grip.visible)
		assert(round.global_position.is_equal_approx(visual.handgun_muzzle_world()))
		assert(player.aerial_jumps_remaining() == 0)
		if player.player_handgun.mouse_aim_active:
			assert(round.travel_direction().is_equal_approx(player.player_handgun.aim_direction))
			assert(round.travel_direction().is_equal_approx(
				(player.player_handgun.crosshair_world - round.global_position).normalized()
			))
		shots.append({"frame": visual.body.frame, "direction": round.travel_direction()})
	)
	# A real input shot on every flip frame, including jump + fire together.
	# Reset between trials isolates pose coverage from the normal gun cooldown.
	for requested_frame in 6:
		player.reset_at(Transform3D(Basis.IDENTITY, Vector3(5.0, 10.0, 0.0)))
		player.player_handgun.reset_run()
		player.player_handgun._mouse_requested = true
		for tick in 10:
			await physics_frame
		assert(player._coyote_remaining <= 0.0)
		Input.action_press("jump")
		if requested_frame == 0:
			Input.action_press("attack")
		await physics_frame
		await physics_frame
		assert(visual.current_state() == "double_jump")
		assert(player.player_handgun.mouse_aim_active, "Mouse aiming must stay active through the flip.")
		if requested_frame > 0:
			while visual.body.frame < requested_frame:
				await physics_frame
			Input.action_press("attack")
			await physics_frame
			await physics_frame
		Input.action_release("attack")
		Input.action_release("jump")
		assert(shots.size() == requested_frame + 1)
		assert(shots.back().frame == requested_frame, "Shooting must use the current flip pose without restarting it.")
		assert(visual.body.texture.resource_path.ends_with("player_handgun_double_jump.png"))
		assert(player.aerial_jumps_remaining() == 0, "Shooting must not grant another jump.")
		while player._double_jump_visual_remaining > 0.0:
			await physics_frame
		await physics_frame
		assert(visual.current_state() == "jump")
		assert(visual.gun.visible and player.player_handgun.mouse_aim_active)

	# Keyboard/gamepad fallback can shoot upward during the same flip too.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(5.0, 10.0, 0.0)))
	player.player_handgun.reset_run()
	player.player_handgun._mouse_requested = false
	for tick in 3:
		await physics_frame
	Input.action_press("aim_up")
	Input.action_press("jump")
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	Input.action_release("jump")
	Input.action_release("aim_up")
	assert(shots.size() == 7)
	assert(shots.back().direction.y > 0.6)
	assert(visual.gun.flip_v)

	# Exercise every shoulder registration and cursor side/height without
	# depending on a physical cursor in headless automation.
	player.set_physics_process(false)
	for facing in [-1.0, 1.0]:
		for frame in 6:
			visual.set_mouse_aim(false, 0.0)
			visual.set_state("double_jump", true)
			visual.tick_authored_state((frame + 0.1) / 14.0, "double_jump", facing > 0.0)
			for height in [-20.0, 0.0, 20.0]:
				var target := player.global_position + Vector3(facing * 8.0, height, 0.0)
				player.player_handgun.update_mouse_aim(facing, target)
				assert(player.player_handgun.mouse_aim_active)
				assert(visual.body.frame == frame)
				assert(visual.gun.visible and visual.gun_grip.visible)
				var muzzle := visual.handgun_muzzle_world()
				assert(player.player_handgun.aim_direction.is_equal_approx(
					(target - muzzle).normalized()
				))
				assert(visual.body.flip_h == (facing < 0.0))


func _on_watchdog_timeout() -> void:
	if _finished:
		return
	push_error("Double Jump validator timed out after an earlier failure.")
	quit(9)
