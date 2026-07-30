extends SceneTree
## Architectural smoke test for the curated pixel-art Level 1 replacement.


func _init() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null, "The application root scene must load.")

	var game_root := packed_scene.instantiate()
	root.add_child(game_root)
	await process_frame

	assert(game_root.get_node_or_null("World") is Node3D, "GameRoot requires a 3D world root.")
	assert(game_root.get_node_or_null("Interface") is CanvasLayer, "GameRoot requires a UI root.")
	var level := game_root.get_node_or_null("World/Level01") as LevelSession3D
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
