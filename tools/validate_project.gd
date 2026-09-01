extends SceneTree
## Architectural smoke test for the production World 1 campaign.


func _init() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null, "The application root scene must load.")

	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	assert(
		game_root.get_node_or_null("Interface/LevelSelect") is Control,
		"GameRoot requires level selection."
	)
	await process_frame
	var world_list := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList"
	)
	var world_heading := world_list.get_node("World01Heading") as Label
	var level_01_button := world_list.get_node("World01Level01Button") as Button
	var level_02_button := world_list.get_node("World01Level02Button") as Button
	var developer_heading := world_list.get_node("DeveloperToolsHeading") as Label
	var animation_lab_button := world_list.get_node("AnimationLabButton") as Button
	var level_design_lab_button := world_list.get_node(
		"LevelDesignLabButton"
	) as Button

	assert(game_root.campaign is CampaignCatalog, "GameRoot requires typed campaign data.")
	assert(game_root.campaign.validation_errors().is_empty(), "Campaign data must validate.")
	assert(world_heading.text == "WORLD 1 - GREEN ZONE")
	assert(game_root.campaign.ordered_worlds().size() == 1)
	var green_zone: WorldDefinition = game_root.campaign.find_world_by_id(&"green_zone")
	assert(green_zone is WorldDefinition)
	assert(green_zone.ordered_levels().size() == 2)
	var arrival: LevelDefinition = game_root.campaign.find_by_id(&"arrival_shoreline")
	assert(arrival is LevelDefinition)
	assert(arrival.display_number == 1)
	assert(level_01_button.text == "1  -  ARRIVAL / SHORELINE")
	var level_2: LevelDefinition = game_root.campaign.find_by_id(
		&"overgrown_coastal_ascent"
	)
	assert(level_2 is LevelDefinition)
	assert(level_2.display_number == 2)
	assert(level_02_button.text == "2  -  OVERGROWN COASTAL ASCENT")
	assert(InputMap.has_action("dash"))
	assert(InputMap.has_action("developer_fly_up"))
	assert(InputMap.has_action("developer_fly_down"))
	assert(developer_heading.text == "DEVELOPER TOOLS")
	assert(animation_lab_button.text == "ANIMATION LAB")
	assert(level_design_lab_button.text == "LEVEL DESIGN LAB")
	assert(world_list.get_node_or_null("EnclosedTerrainLabButton") == null)
	assert(
		world_list.get_node_or_null(
			"OvergrownCoastalAscentInteriorReviewButton"
		) == null
	)
	assert(world_list.get_node_or_null("Level2SlideIntroLabButton") == null)
	assert(world_list.get_node_or_null("Level2WipButton") == null)
	assert(world_list.get_node_or_null("Level2WipInteriorSnapshotButton") == null)
	assert(world_list.get_node_or_null("ArrivalShorelineSliceButton") == null)
	assert(level_01_button.has_focus(), "The selector should initially focus Level 1.")

	var menu_up := InputEventKey.new()
	menu_up.physical_keycode = KEY_W
	menu_up.pressed = true
	game_root._unhandled_input(menu_up)
	assert(
		level_design_lab_button.has_focus(),
		"W should wrap Level 1 to the final developer level."
	)
	var menu_down := InputEventKey.new()
	menu_down.physical_keycode = KEY_S
	menu_down.pressed = true
	game_root._unhandled_input(menu_down)
	assert(
		level_01_button.has_focus(),
		"S should wrap selection from the final developer lab to Level 1."
	)
	var menu_enter := InputEventKey.new()
	menu_enter.physical_keycode = KEY_ENTER
	menu_enter.pressed = true
	game_root._unhandled_input(menu_enter)
	await process_frame
	assert(game_root.current_level_definition.level_id == &"arrival_shoreline")
	assert(game_root.current_level.name == "World01Level01")

	assert(game_root.get_node_or_null("World") is Node3D, "GameRoot requires a 3D world root.")
	assert(game_root.get_node_or_null("Interface") is CanvasLayer, "GameRoot requires a UI root.")
	var level := game_root.current_level as LevelSession3D
	assert(level != null, "World 1 / Level 1 must instantiate.")
	assert(game_root.current_world_definition.world_id == &"green_zone")
	assert(
		is_equal_approx(level.route_extent.length(), 203.52),
		"Level 1 must expose its complete production route."
	)
	assert(level.player.movement.ideal_jump_height() > 2.0)
	assert(level.get_node("Platforms").get_child_count() == 15)
	assert(level.get_node_or_null("ApproachPatrol") is StompableEnemy3D)
	assert(level.get_node_or_null("DoubleJumpPickup") is AbilityPickup3D)
	var level_2_transition := level.get_node_or_null(
		"Level2Transition"
	) as LevelTransition3D
	assert(level_2_transition != null)
	assert(level_2_transition.target_level == level_2)
	assert(level_2_transition.completes_source_level)
	assert(InputMap.has_action("move_left"))
	assert(InputMap.has_action("jump"))
	assert(InputMap.has_action("attack"))
	assert(
		FileAccess.file_exists("res://assets/art/green_zone/asset_manifest.json"),
		"The curated Green Zone asset manifest must exist."
	)

	game_root.show_level_select()
	level_02_button.pressed.emit()
	await process_frame
	assert(game_root.current_level_definition.level_id == &"overgrown_coastal_ascent")
	assert(game_root.current_level.name == "World01Level02")

	print("Project and production World 1 campaign validation passed.")
	quit(0)
