extends SceneTree
## Development ability state is isolated to one loaded lab session: death and
## manual restart retain its toggles, while selecting the lab again restores
## its definition seed without reading or changing the campaign save.


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

	var level_design_lab := load(
		"res://resources/dev/level_design_lab.tres"
	) as LevelDefinition
	game_root.load_developer_level(level_design_lab)
	await process_frame
	var first_session := game_root.current_level as LevelSession3D
	_assert_complete_kit(first_session, "Level Design Lab entry")
	first_session.set_session_ability_enabled(PlayerAbility.WALL_JUMP, false)
	assert(not first_session.player.has_ability(PlayerAbility.WALL_JUMP))
	assert(not first_session.is_session_ability_enabled(PlayerAbility.WALL_JUMP))

	first_session._reset_run()
	await physics_frame
	assert(
		not first_session.player.has_ability(PlayerAbility.WALL_JUMP),
		"Manual restart inside the loaded lab must retain its session toggle."
	)

	first_session.player.kill()
	for frame in 40:
		await physics_frame
	assert(not first_session.player.is_dead())
	assert(
		not first_session.player.has_ability(PlayerAbility.WALL_JUMP),
		"Death inside the loaded lab must retain its session toggle."
	)

	game_root.show_level_select()
	game_root.load_developer_level(level_design_lab)
	await process_frame
	var fresh_session := game_root.current_level as LevelSession3D
	_assert_complete_kit(fresh_session, "fresh Level Design Lab reload")

	game_root.show_level_select()
	game_root.load_developer_room()
	await process_frame
	var finale_session := game_root.current_level as LevelSession3D
	_assert_complete_kit(finale_session, "Firearm Review Lab entry")
	_assert_firearm_loadout(finale_session)
	assert(finale_session.player.request_weapon(PlayerWeapon.KNIFE))

	finale_session._reset_run()
	await physics_frame
	_assert_complete_kit(finale_session, "Firearm Review Lab manual restart")
	_assert_firearm_loadout(finale_session)

	finale_session.player.kill()
	for frame in 40:
		await physics_frame
	assert(not finale_session.player.is_dead())
	_assert_complete_kit(finale_session, "Firearm Review Lab death reset")
	_assert_firearm_loadout(finale_session)

	game_root.show_level_select()
	game_root.load_developer_room()
	await process_frame
	var fresh_finale_session := game_root.current_level as LevelSession3D
	_assert_complete_kit(fresh_finale_session, "fresh Firearm Review Lab reload")
	_assert_firearm_loadout(fresh_finale_session)

	game_root.load_level(&"arrival_shoreline")
	await process_frame
	assert(game_root.current_level.owned_weapon_ids() == [PlayerWeapon.KNIFE])
	assert(game_root.current_level.player.equipped_weapon_id() == PlayerWeapon.KNIFE,
		"The lab handgun must not carry into campaign levels.")

	game_root.free()
	print("Fresh-per-level developer progression validation passed.")
	quit(0)


func _assert_firearm_loadout(level: LevelSession3D) -> void:
	assert(level.owned_weapon_ids() == [PlayerWeapon.KNIFE, PlayerWeapon.HANDGUN])
	assert(level.player.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.HANDGUN,
		"Firearm Review Lab must start with the handgun equipped.")


func _assert_complete_kit(level: LevelSession3D, context: String) -> void:
	for ability_id in PlayerAbility.IMPLEMENTED:
		assert(
			level.player.has_ability(ability_id),
			"%s must provide %s." % [context, PlayerAbility.display_name(ability_id)]
		)
		assert(
			level.is_session_ability_enabled(ability_id),
			"%s must seed %s as a session ability."
			% [context, PlayerAbility.display_name(ability_id)]
		)
