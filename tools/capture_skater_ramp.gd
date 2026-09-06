extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_level(&"arrival_shoreline")
	await process_frame
	var level = game.current_level
	level.player.set_developer_inspection_enabled(true)
	level.player.global_position = Vector3(130, 12, 0)
	level.camera.snap_to_target()
	var skater = level.get_node("SkateRampPatrol")
	var minimum_x: float = skater.position.x
	var maximum_x: float = skater.position.x
	for frame in 900:
		await physics_frame
		minimum_x = minf(minimum_x, skater.position.x)
		maximum_x = maxf(maximum_x, skater.position.x)
		assert(skater.position.y > 1.0)
	assert(minimum_x >= 111.7 and maximum_x <= 126.4)
	assert(maximum_x - minimum_x > 13.5)
	skater.set_physics_process(false)
	# Exercise an actual rolling attack, including facing on its first frame.
	skater.position = Vector3(120, 1.02, 0)
	level.player.global_position = Vector3(121.6, 1.34, 0)
	level.camera.snap_to_target()
	assert(skater._try_start_attack())
	assert(not skater.pixel_visual.flip_h)
	var attack_frames := {}
	for frame in 37:
		skater._tick_attack(1.0 / 60.0)
		attack_frames[skater.pixel_visual.frame] = true
		await physics_frame
		if frame == 20:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/previews/skater_attack.png")
	assert(attack_frames.size() == 4)
	assert(skater.pixel_visual.frame == 3, "Attack must hold its last frame instead of looping.")
	assert(skater.position.x > 120.1, "Skater must roll forward during its attack.")
	# A rolling attack must also stop at the platform's right ledge.
	skater.position = Vector3(126.1, 1.02, 0)
	for frame in 37:
		skater._tick_attack(1.0 / 60.0)
		await physics_frame
	assert(skater.position.x <= 126.2 and skater.position.y > 1.0)
	level.player.global_position = Vector3(118.5, 1.34, 0)
	level.camera.snap_to_target()
	skater.position = Vector3(123, 1.02, 0)
	skater.pixel_visual.tick(0.2, "walk", false)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/previews/skater_ramp.png")
	print("Skater traversed ramp patrol safely: ", minimum_x, " to ", maximum_x)
	quit()
