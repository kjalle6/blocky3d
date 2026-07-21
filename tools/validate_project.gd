extends SceneTree
## Minimal architectural smoke test. It intentionally validates only the root
## contract; gameplay contracts will be added alongside real gameplay systems.


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
	var level := game_root.get_node_or_null("World/Level1Blockout") as LevelSession3D
	assert(level != null, "The current milestone requires the Level 1 blockout.")
	assert(level.traversal_rail.length() > 100.0, "Level 1 should provide a meaningful movement run.")
	assert(level.player.movement.ideal_jump_height() > 2.0, "The movement profile should produce a useful platforming jump.")
	assert(InputMap.has_action("move_left"), "Default movement input must exist.")
	assert(InputMap.has_action("jump"), "Default jump input must exist.")

	print("Project and Level 1 blockout validation passed.")
	quit(0)
