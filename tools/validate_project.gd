extends SceneTree
## Architectural smoke test for the curated pixel-art Level 1 replacement.


func _init() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null, "The application root scene must load.")

	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	assert(game_root.get_node_or_null("Interface/LevelSelect") is Control, "GameRoot requires level selection.")
	await process_frame
	var world_heading := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Heading"
	) as Label
	var level_01_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Level01Button"
	) as Button
	var level_02_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Level02Button"
	) as Button
	var level_03_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Level03Button"
	) as Button
	var level_04_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Level04Button"
	) as Button
	var level_05_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Level05Button"
	) as Button
	var level_06_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/World01Level06Button"
	) as Button
	var developer_heading := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/DeveloperToolsHeading"
	) as Label
	var arrival_slice_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/ArrivalShorelineSliceButton"
	) as Button
	var animation_lab_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/WorldList/AnimationLabButton"
	) as Button
	assert(game_root.campaign is CampaignCatalog, "GameRoot requires typed campaign data.")
	assert(game_root.campaign.validation_errors().is_empty(), "Campaign data must validate.")
	assert(world_heading.text == "WORLD 1 - GREEN ZONE")
	assert(game_root.campaign.ordered_worlds().size() == 1)
	assert(game_root.campaign.find_world_by_id(&"green_zone") is WorldDefinition)
	assert(game_root.campaign.find_by_id(&"fundamentals").display_number == 1)
	assert(game_root.campaign.find_by_id(&"gaps_and_spikes").display_number == 2)
	assert(game_root.campaign.find_by_id(&"double_jump").display_number == 3)
	assert(game_root.campaign.find_by_id(&"wall_jump").display_number == 4)
	assert(level_04_button.text == "4  -  WALL JUMP")
	assert(game_root.campaign.find_by_id(&"dash").display_number == 5)
	assert(level_05_button.text == "5  -  DASH")
	assert(game_root.campaign.find_by_id(&"green_zone_finale").display_number == 6)
	assert(level_06_button.text == "6  -  GREEN ZONE FINALE")
	assert(InputMap.has_action("dash"))
	assert(developer_heading.text == "DEVELOPER TOOLS")
	assert(arrival_slice_button.text == "ARRIVAL / SHORELINE SLICE")
	assert(animation_lab_button.text == "ANIMATION LAB")
	assert(game_root.campaign.find_by_id(&"dev_arrival_shoreline_slice") == null)
	assert(level_01_button.has_focus(), "The selector should initially focus Level 1.")
	var menu_up := InputEventKey.new()
	menu_up.physical_keycode = KEY_W
	menu_up.pressed = true
	game_root._unhandled_input(menu_up)
	assert(
		animation_lab_button.has_focus(),
		"W should wrap selection from Level 1 to the final developer option."
	)
	var menu_down := InputEventKey.new()
	menu_down.physical_keycode = KEY_S
	menu_down.pressed = true
	game_root._unhandled_input(menu_down)
	assert(
		level_01_button.has_focus(),
		"S should wrap selection from the developer option to Level 1."
	)
	game_root._unhandled_input(menu_down)
	assert(level_02_button.has_focus(), "S should move selection from Level 1 to Level 2.")
	var menu_enter := InputEventKey.new()
	menu_enter.physical_keycode = KEY_ENTER
	menu_enter.pressed = true
	game_root._unhandled_input(menu_enter)
	assert(
		game_root.current_level_definition.level_id == &"gaps_and_spikes",
		"Enter should launch the focused level."
	)
	game_root.show_level_select()
	var menu_six := InputEventKey.new()
	menu_six.physical_keycode = KEY_6
	menu_six.pressed = true
	game_root._unhandled_input(menu_six)
	assert(
		game_root.current_level_definition.level_id == &"green_zone_finale",
		"6 should launch the sixth campaign level."
	)
	assert(
		game_root.current_level.name == "World01Level06",
		"Level 6 should retain its catalog-derived runtime identity."
	)
	game_root.show_level_select()
	game_root.load_level(&"fundamentals")
	await process_frame

	assert(game_root.get_node_or_null("World") is Node3D, "GameRoot requires a 3D world root.")
	assert(game_root.get_node_or_null("Interface") is CanvasLayer, "GameRoot requires a UI root.")
	var level := game_root.current_level as LevelSession3D
	assert(level != null, "The current milestone requires the pixel-art Level 1.")
	assert(game_root.current_world_definition.world_id == &"green_zone")
	assert(level.route_extent.length() > 50.0, "Level 1 route length should match the approved layout.")
	assert(level.player.movement.ideal_jump_height() > 2.0, "The movement profile should retain a useful platforming jump.")
	assert(level.get_node("Platforms").get_child_count() == 6, "Level 1 should preserve the approved six-platform rhythm.")
	assert(level.get_node_or_null("GreenZonePatrol") is StompableEnemy3D, "Level 1 needs its introductory patrol.")
	assert(level.get_node_or_null("Goal") is PixelGoal3D, "Level 1 needs the pixel chest goal.")
	assert(InputMap.has_action("move_left"), "Default movement input must exist.")
	assert(InputMap.has_action("jump"), "Default jump input must exist.")
	assert(InputMap.has_action("attack"), "Default attack input must exist.")
	assert(
		FileAccess.file_exists("res://assets/art/green_zone/asset_manifest.json"),
		"The curated green-zone asset manifest must exist."
	)

	game_root.show_level_select()
	game_root._load_button_level(arrival_slice_button)
	await process_frame
	assert(game_root.current_world_definition == null)
	assert(game_root.current_level_definition.level_id == &"dev_arrival_shoreline_slice")
	assert(game_root.current_level.name == "DeveloperArrivalShorelineSlice")

	print("Project, campaign catalog, and pixel Level 1 validation passed.")
	quit(0)
