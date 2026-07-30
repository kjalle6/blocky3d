extends SceneTree
## Architectural smoke test for the curated pixel-art Level 1 replacement.


func _init() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null, "The application root scene must load.")

	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	assert(game_root.get_node_or_null("Interface/LevelSelect") is Control, "GameRoot requires level selection.")
	await process_frame
	var level_01_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/Level01Button"
	) as Button
	var level_02_button := game_root.get_node(
		"Interface/LevelSelect/Center/Panel/Margin/Options/Level02Button"
	) as Button
	assert(level_01_button.has_focus(), "The selector should initially focus Level 1.")
	var menu_up := InputEventKey.new()
	menu_up.physical_keycode = KEY_W
	menu_up.pressed = true
	game_root._unhandled_input(menu_up)
	assert(level_02_button.has_focus(), "W should wrap selection from Level 1 to Level 2.")
	var menu_down := InputEventKey.new()
	menu_down.physical_keycode = KEY_S
	menu_down.pressed = true
	game_root._unhandled_input(menu_down)
	assert(level_01_button.has_focus(), "S should wrap selection from Level 2 to Level 1.")
	game_root._unhandled_input(menu_down)
	assert(level_02_button.has_focus(), "S should move selection from Level 1 to Level 2.")
	var menu_enter := InputEventKey.new()
	menu_enter.physical_keycode = KEY_ENTER
	menu_enter.pressed = true
	game_root._unhandled_input(menu_enter)
	assert(game_root.current_level_number == 2, "Enter should launch the focused level.")
	game_root.show_level_select()
	game_root.load_level(1)
	await process_frame

	assert(game_root.get_node_or_null("World") is Node3D, "GameRoot requires a 3D world root.")
	assert(game_root.get_node_or_null("Interface") is CanvasLayer, "GameRoot requires a UI root.")
	var level := game_root.current_level as LevelSession3D
	assert(level != null, "The current milestone requires the pixel-art Level 1.")
	assert(level.traversal_rail.length() > 50.0, "Level 1 route length should match the approved layout.")
	assert(level.player.movement.ideal_jump_height() > 2.0, "The movement profile should retain a useful platforming jump.")
	assert(level.get_node("Platforms").get_child_count() == 6, "Level 1 should preserve the approved six-platform rhythm.")
	assert(level.get_node_or_null("GreenZonePatrol") is StompableEnemy3D, "Level 1 needs its introductory patrol.")
	assert(level.get_node_or_null("Goal") is PixelGoal3D, "Level 1 needs the pixel chest goal.")
	assert(InputMap.has_action("move_left"), "Default movement input must exist.")
	assert(InputMap.has_action("jump"), "Default jump input must exist.")
	assert(InputMap.has_action("attack"), "Default attack input must exist.")
	assert(
		FileAccess.file_exists("res://assets/art/level01/asset_manifest.json"),
		"The curated Level 1 asset manifest must exist."
	)

	print("Project and pixel Level 1 validation passed.")
	quit(0)
