extends SceneTree
## Focused movement contract for Double Jump: coyote jumps preserve it,
## one aerial reset is available, release still shortens it, and horizontal
## momentum is never secretly replaced.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"double_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	for frame in 12:
		await physics_frame

	assert(not player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(level.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(player.aerial_jumps_remaining() == 1)

	var performed_count := [0]
	player.ability_performed.connect(
		func(ability_id: StringName) -> void:
			if ability_id == PlayerAbility.DOUBLE_JUMP:
				performed_count[0] += 1
	)

	# Run off the opening edge, then use coyote time. This remains the ground
	# jump and must not consume the aerial jump.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(9.1, 0.7, 0)))
	for frame in 4:
		await physics_frame
	assert(player.is_on_floor())
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if not player.is_on_floor():
			break
	assert(not player.is_on_floor(), "The test should have run beyond the opening ledge.")
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
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(3.0, 0.7, 0)))
	for frame in 12:
		await physics_frame
	assert(player.is_on_floor())
	assert(player.aerial_jumps_remaining() == 1, "Landing should refresh Double Jump.")

	game_root.free()
	print("Double Jump movement contract validation passed.")
	quit(0)
