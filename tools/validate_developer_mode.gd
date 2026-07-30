extends SceneTree
## Development progression is isolated to one loaded level session: death and
## manual restart retain earned abilities, while selecting a level creates a
## fresh state without reading or changing the campaign save.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	assert(game_root.developer_fresh_level_runs)
	assert(game_root.persist_progression)
	root.add_child(game_root)
	await process_frame
	assert(
		(game_root.get_node("Interface/LevelSelect/Center/Panel/Margin/Options/DeveloperModeLabel") as Label).visible
	)

	game_root.load_level(&"double_jump")
	await process_frame
	var first_session := game_root.current_level as LevelSession3D
	var first_pickup := first_session.get_node("DoubleJumpPickup") as AbilityPickup3D
	assert(not first_session.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not first_pickup.is_claimed())

	assert(first_session.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	assert(first_session.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(first_pickup.is_claimed())

	first_session._reset_run()
	await physics_frame
	assert(
		first_session.player.has_ability(PlayerAbility.DOUBLE_JUMP),
		"Manual restart inside the loaded level must retain its session unlock."
	)
	assert(first_pickup.is_claimed())

	first_session.player.kill()
	for frame in 40:
		await physics_frame
	assert(not first_session.player.is_dead())
	assert(
		first_session.player.has_ability(PlayerAbility.DOUBLE_JUMP),
		"Death inside the loaded level must retain its session unlock."
	)

	game_root.show_level_select()
	game_root.load_level(&"double_jump")
	await process_frame
	var fresh_session := game_root.current_level as LevelSession3D
	var fresh_pickup := fresh_session.get_node("DoubleJumpPickup") as AbilityPickup3D
	assert(
		not fresh_session.player.has_ability(PlayerAbility.DOUBLE_JUMP),
		"Loading a level from the selector must create fresh development progression."
	)
	assert(not fresh_pickup.is_claimed(), "The fresh level load must restore its pickup.")

	game_root.free()
	print("Fresh-per-level developer progression validation passed.")
	quit(0)
