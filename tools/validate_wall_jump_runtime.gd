extends SceneTree
## Focused Wall Jump contract: airborne wall contact slows descent, a buffered
## jump kicks away with a short control lock, and the lab toggle is isolated.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_developer_room()
	await process_frame
	var room := game_root.current_level as LevelSession3D
	var player := room.player
	for frame in 8:
		await physics_frame

	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	var performed_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.WALL_JUMP:
				performed_count[0] += 1
	)

	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(28.35, 4.2, 0)))
	player.velocity.y = -7.0
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if player.is_wall_sliding():
			break
	assert(player.is_wall_sliding(), "Falling wall contact should enter the slide.")
	assert(player.wall_contact_direction() > 0.5, "The test should contact the right wall.")
	assert(
		player.velocity.y >= -player.movement.wall_slide_max_fall_speed - 0.1,
		"Wall sliding must cap downward speed."
	)

	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	assert(performed_count[0] == 1)
	assert(
		player.velocity.y > 15.0,
		"Wall Jump should provide its stronger dedicated vertical impulse."
	)
	assert(
		player.horizontal_speed < -9.0,
		"A right-wall jump should kick decisively left."
	)
	assert(
		player.aerial_jumps_remaining() == 1,
		"An unused Double Jump should remain available after Wall Jump."
	)
	assert(player.blocked_wall_jump_direction() > 0.5)
	Input.action_release("jump")
	Input.action_release("move_right")
	for frame in 10:
		await physics_frame

	# Returning to the same wall may spend the one existing Double Jump, but
	# must not manufacture another Wall Jump or refill the aerial jump.
	player.global_position = Vector3(28.9, 4.2, 0)
	player.velocity = Vector3(0, -7.0, 0)
	player.horizontal_speed = 0.0
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if player.is_wall_sliding():
			break
	assert(player.is_wall_sliding())
	for frame in 8:
		await physics_frame
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	assert(performed_count[0] == 1, "The same wall must not provide another Wall Jump.")
	assert(
		player.aerial_jumps_remaining() == 0,
		"The permitted same-wall recovery must consume Double Jump."
	)
	Input.action_release("jump")
	Input.action_release("move_right")

	# With Double Jump spent, returning to that wall again cannot climb.
	player.global_position = Vector3(28.9, 4.2, 0)
	player.velocity = Vector3(0, -7.0, 0)
	player.horizontal_speed = 0.0
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if player.is_wall_sliding():
			break
	assert(player.is_wall_sliding())
	for frame in 8:
		await physics_frame
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	assert(performed_count[0] == 1)
	assert(player.velocity.y <= 0.0, "Same-wall jump spam must remain finite.")
	Input.action_release("jump")
	Input.action_release("move_right")

	# Touching the opposite wall releases the lockout, but still does not
	# refill the already-spent Double Jump.
	player.global_position = Vector3(1.82, 4.2, 0)
	player.velocity = Vector3(0, -7.0, 0)
	player.horizontal_speed = 0.0
	Input.action_press("move_left")
	for frame in 60:
		await physics_frame
		if player.is_wall_sliding():
			break
	assert(player.is_wall_sliding())
	assert(player.wall_contact_direction() < -0.5)
	for frame in 8:
		await physics_frame
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	assert(performed_count[0] == 2)
	assert(player.horizontal_speed > 9.0)
	assert(
		player.aerial_jumps_remaining() == 0,
		"Wall Jump must not refill a spent Double Jump."
	)
	Input.action_release("jump")
	Input.action_release("move_left")

	room.set_session_ability_enabled(PlayerAbility.WALL_JUMP, false)
	assert(not player.has_ability(PlayerAbility.WALL_JUMP))
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(28.35, 4.2, 0)))
	player.velocity.y = -7.0
	Input.action_press("move_right")
	for frame in 24:
		await physics_frame
	assert(
		not player.is_wall_sliding(),
		"Disabling Wall Jump in the lab must disable its wall slide."
	)
	Input.action_release("move_right")

	room.set_session_ability_enabled(PlayerAbility.WALL_JUMP, true)
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	print("Wall Jump movement and Animation Lab toggle validation passed.")
	quit(0)
