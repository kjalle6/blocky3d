extends SceneTree
## Long camera travel must keep static world art on a stable output-pixel phase.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"gaps_and_spikes")
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var camera := level.camera as PixelSideCamera3D
	var reference_platform := level.get_node("Platforms/GroundMid") as PixelPlatform3D
	player.set_physics_process(false)
	camera.follow_response = 8.0
	camera.snap_to_target()

	var pixel_world_size := camera.world_units_per_screen_pixel()
	assert(pixel_world_size > 0.0)
	var previous_screen_x := camera.unproject_position(
		reference_platform.global_position
	).x
	for frame in 240:
		player.global_position.x = 8.0 + frame * 0.12
		camera._process(1.0 / 60.0)
		var camera_pixel_x := camera.global_position.x / pixel_world_size
		assert(
			absf(camera_pixel_x - roundf(camera_pixel_x)) < 0.001,
			"Rendered camera position left the output-pixel grid."
		)
		var screen_x := camera.unproject_position(reference_platform.global_position).x
		var screen_delta := screen_x - previous_screen_x
		assert(
			absf(screen_delta - roundf(screen_delta)) < 0.001,
			"Static platform changed fractional screen-pixel phase during camera travel."
		)
		previous_screen_x = screen_x

	print("Camera pixel-stability validation passed.")
	quit(0)
