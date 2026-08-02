extends SceneTree
## Focused contract for the disposable animation test room.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame

	game_root.load_developer_room()
	await process_frame
	var room := game_root.current_level as LevelSession3D
	assert(room != null)
	assert(game_root.current_world_definition == null)
	assert(game_root.current_level_definition.level_id == &"dev_animation_lab")
	assert(
		game_root.current_level_definition.available_abilities
		== PlayerAbility.IMPLEMENTED,
		"Every implemented ability must be exposed in the Animation Lab."
	)
	assert(room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(room.player.aerial_jumps_remaining() == 1)
	assert(room.get_node("Platforms").get_child_count() == 5)
	assert(room.get_node_or_null("Platforms/Floor") is StaticBody3D)
	assert(room.get_node_or_null("Platforms/LeftWall") is StaticBody3D)
	assert(room.get_node_or_null("Platforms/RightWall") is StaticBody3D)
	assert(room.get_node_or_null("Platforms/LandingBlock") is StaticBody3D)
	assert(room.get_node_or_null("Platforms/HighBlock") is StaticBody3D)
	assert(room.get_node("Hazards").get_child_count() == 0)
	assert(room.get_tree().get_nodes_in_group("level_goal").filter(
		func(node: Node) -> bool:
			return room.is_ancestor_of(node)
	).is_empty())
	var instructions := game_root.get_node("Interface/Instructions") as Control
	var ability_panel := game_root.get_node(
		"Interface/DeveloperAbilityPanel"
	) as Control
	assert(not instructions.visible)
	assert(not ability_panel.visible)
	_toggle_gameplay_tools(game_root)
	assert(instructions.visible)
	assert(ability_panel.visible)
	_toggle_gameplay_tools(game_root)
	assert(not instructions.visible)
	assert(not ability_panel.visible)

	var double_jump_toggle := game_root.get_node(
		"Interface/DeveloperAbilityPanel/Margin/Options"
		+ "/DeveloperAbilityToggles/DoubleJumpToggle"
	) as CheckButton
	var wall_jump_toggle := game_root.get_node(
		"Interface/DeveloperAbilityPanel/Margin/Options"
		+ "/DeveloperAbilityToggles/WallJumpToggle"
	) as CheckButton
	var dash_toggle := game_root.get_node(
		"Interface/DeveloperAbilityPanel/Margin/Options"
		+ "/DeveloperAbilityToggles/DashToggle"
	) as CheckButton
	assert(double_jump_toggle != null)
	assert(wall_jump_toggle != null)
	assert(dash_toggle != null)
	assert(double_jump_toggle.button_pressed)
	assert(wall_jump_toggle.button_pressed)
	assert(dash_toggle.button_pressed)
	double_jump_toggle.button_pressed = false
	double_jump_toggle.toggled.emit(false)
	assert(not room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not room.is_session_ability_enabled(PlayerAbility.DOUBLE_JUMP))
	double_jump_toggle.button_pressed = true
	double_jump_toggle.toggled.emit(true)
	assert(room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(room.is_session_ability_enabled(PlayerAbility.DOUBLE_JUMP))
	dash_toggle.button_pressed = false
	dash_toggle.toggled.emit(false)
	assert(not room.player.has_ability(PlayerAbility.DASH))
	assert(not room.is_session_ability_enabled(PlayerAbility.DASH))
	dash_toggle.button_pressed = true
	dash_toggle.toggled.emit(true)
	assert(room.player.has_ability(PlayerAbility.DASH))
	assert(room.is_session_ability_enabled(PlayerAbility.DASH))

	room._reset_run()
	await process_frame
	assert(
		room.player.has_ability(PlayerAbility.DOUBLE_JUMP),
		"Room reset must retain session-local test abilities."
	)
	assert(room.player.has_ability(PlayerAbility.DASH))

	print("Animation Lab structure and ability validation passed.")
	quit(0)


func _toggle_gameplay_tools(game_root: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F1
	game_root._unhandled_input(event)
