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
	var player = level.player
	var skater = level.get_node("SkateRampPatrol")
	skater.set_physics_process(false)
	for direction in [-1.0, 1.0]:
		player.reset_at(Transform3D(Basis.IDENTITY, Vector3(120, 1.19, 0)))
		player.set_developer_inspection_enabled(true)
		player.set_physics_process(false)
		player.pixel_visual.tick_authored_state(0.0, "idle", direction < 0.0)
		skater.position = Vector3(120 - direction * 0.75, 1.02, 0)
		skater._direction = direction
		skater.pixel_visual.set_state("attack", true)
		skater.pixel_visual.tick(0.3, "attack", direction > 0.0)
		# Source torso centers sit 11px left of the centered frame origin.
		var enemy_torso_x: float = skater.pixel_visual.global_position.x - direction * 11.0 * skater.pixel_visual.pixel_size
		var player_direction: float = -direction
		var player_torso_x: float = player.pixel_visual.global_position.x - player_direction * 11.0 * player.pixel_visual.body.pixel_size
		assert(absf(enemy_torso_x - skater.position.x) < 0.01)
		assert(absf(player_torso_x - player.position.x) < 0.01)
		level.camera.snap_to_target()
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var suffix := "left" if direction < 0.0 else "right"
		root.get_texture().get_image().save_png("res://build/previews/skater_contact_" + suffix + ".png")
		player.set_developer_inspection_enabled(false)
		player.set_physics_process(false)
		skater.position.x = 120 - direction * 1.0
		skater._apply_attack_damage()
		assert(not player.is_dead(), "Weapon-length separation must not damage the player.")
		skater.position.x = 120 - direction * 0.75
		skater._apply_attack_damage()
		assert(player.is_dead(), "Near body contact must still damage the player.")
	print("Skater contact passed from both sides: torso alignment, distant miss, close hit.")
	quit()
