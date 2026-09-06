extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Audio panel capture requires -Visual.")
		quit(1)
		return
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_level(&"arrival_shoreline")
	for frame in 20:
		await physics_frame
	game._set_gameplay_tools_visible(true)
	game.audio_tuning_panel.open_panel()
	DirAccess.make_dir_recursive_absolute("res://build/previews/audio_tuning")
	for surface in ["grass", "sand", "cave", "underground"]:
		game.audio_tuning_panel._surface_picker.item_selected.emit(["grass", "sand", "cave", "underground"].find(surface))
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/previews/audio_tuning/%s.png" % surface)
	game.audio_tuning_panel.close_panel()
	game.free()
	quit()
