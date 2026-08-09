extends SceneTree
## Focused Dash contract: direction, fixed burst speed, gravity suspension,
## charge consumption, jump cancellation, wall impact, refresh, and lab policy.


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

	assert(player.has_ability(PlayerAbility.DASH))
	assert(player.dash_available())
	var performed_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DASH:
				performed_count[0] += 1
	)

	# Held direction chooses the burst, which suspends vertical movement and
	# consumes the one current Dash charge.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(8.0, 5.0, 0)))
	for frame in 8:
		await physics_frame
	player.velocity.y = -8.0
	Input.action_press("move_left")
	Input.action_press("dash")
	for frame in 2:
		await physics_frame
	Input.action_release("dash")
	assert(player.is_dashing())
	assert(player.dash_direction() < -0.5)
	assert(player.horizontal_speed < -17.0)
	assert(absf(player.velocity.y) < 0.01)
	assert(not player.dash_available())
	assert(performed_count[0] == 1)
	assert(player.is_dash_airborne())
	assert(player.pixel_visual.current_state() == "air_dash")
	assert(
		player.pixel_visual.body.frame in PixelPlayerVisual3D.AIR_DASH_FRAMES,
		"Air Dash displayed an upright ground-only frame."
	)

	# A second airborne request cannot manufacture another charge.
	Input.action_press("dash")
	for frame in 2:
		await physics_frame
	Input.action_release("dash")
	Input.action_release("move_left")
	assert(performed_count[0] == 1)
	assert(player.pixel_visual.current_state() == "air_dash")
	assert(
		player.pixel_visual.body.frame in PixelPlayerVisual3D.AIR_DASH_FRAMES,
		"Air Dash left the active burst-frame sequence."
	)

	# Double Jump cancels the burst into its ordinary vertical impulse without
	# refreshing Dash.
	Input.action_press("jump")
	for frame in 2:
		await physics_frame
	Input.action_release("jump")
	assert(not player.is_dashing())
	assert(player.velocity.y > 12.0)
	assert(player.aerial_jumps_remaining() == 0)
	assert(not player.dash_available())

	# Touching the ground restores the charge.
	player.global_position = Vector3(12.0, 0.8, 0)
	player.velocity = Vector3.ZERO
	player.horizontal_speed = 0.0
	for frame in 8:
		await physics_frame
	assert(player.is_on_floor())
	assert(player.dash_available())

	# Dash overrides an attack presentation; it is not an accidental
	# high-speed melee strike.
	Input.action_press("attack")
	for frame in 2:
		await physics_frame
	Input.action_release("attack")
	assert(
		player.pixel_visual.current_state() in ["attack", "run_attack"],
		"Expected attack presentation, got '%s'."
		% player.pixel_visual.current_state()
	)
	Input.action_press("move_right")
	Input.action_press("dash")
	for frame in 2:
		await physics_frame
	Input.action_release("dash")
	Input.action_release("move_right")
	assert(player.is_dashing())
	assert(not player.is_dash_airborne())
	assert(player.pixel_visual.current_state() == "dash")
	for frame in 2:
		await process_frame

	# A solid wall ends the burst instead of retaining hidden forward force.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(28.2, 0.7, 0)))
	for frame in 4:
		await physics_frame
	assert(player.dash_available())
	assert(not Input.is_action_pressed("dash"))
	Input.action_press("move_right")
	assert(player._try_start_dash(1.0))
	assert(
		performed_count[0] == 3,
		"The wall-impact test must begin with a real Dash; count is %d."
		% performed_count[0]
	)
	for frame in 20:
		await physics_frame
		if not player.is_dashing():
			break
	Input.action_release("move_right")
	assert(not player.is_dashing())
	assert(
		absf(player.horizontal_speed) < 0.01,
		"Wall Dash retained speed %.2f at x=%.2f."
		% [player.horizontal_speed, player.global_position.x]
	)

	# A complete airborne burst must use motion frames throughout, then hand
	# back to the ordinary airborne pose instead of holding its recovery frame.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(18.0, 5.0, 0)))
	for frame in 4:
		await physics_frame
	assert(player._try_start_dash(-1.0))
	assert(performed_count[0] == 4)
	var observed_air_dash := false
	for frame in 30:
		await physics_frame
		if player.is_dashing():
			observed_air_dash = true
			assert(player.pixel_visual.current_state() == "air_dash")
			assert(
				player.pixel_visual.body.frame in PixelPlayerVisual3D.AIR_DASH_FRAMES
			)
		else:
			break
	assert(observed_air_dash)
	assert(not player.is_dashing())
	assert(player.pixel_visual.current_state() == "jump")
	assert(player.velocity.y < 0.0)

	room.set_session_ability_enabled(PlayerAbility.DASH, false)
	assert(not player.has_ability(PlayerAbility.DASH))
	assert(not player.dash_available())
	Input.action_press("dash")
	for frame in 2:
		await physics_frame
	Input.action_release("dash")
	assert(performed_count[0] == 4)

	room.set_session_ability_enabled(PlayerAbility.DASH, true)
	assert(player.has_ability(PlayerAbility.DASH))
	assert(player.dash_available())
	print("Dash movement and Animation Lab toggle validation passed.")
	quit(0)
