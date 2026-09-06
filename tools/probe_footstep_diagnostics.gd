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
	for enemy in get_nodes_in_group("melee_target"):
		if enemy is StompableEnemy3D:
			enemy.set_physics_process(false)
			enemy.body_collision.disabled = true
			enemy.contact_collision.disabled = true
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(14.8, 1.2, 0)))
	for frame in 8:
		await physics_frame
	var footsteps = level.player.get_node("Footsteps")
	footsteps.diagnostics_enabled = true
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
	Input.action_release("move_right")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/previews/footstep_diagnostics.png")
	var records: Array = footsteps.history
	var previous_foot := ""
	var played := 0
	for event in records:
		if event.status != "played":
			continue
		assert(event.surface == "grass")
		assert(event.foot != previous_foot)
		if played > 0:
			assert(absf(event.interval - 0.30) < 0.04)
		previous_foot = event.foot
		played += 1
	assert(played >= 3)
	print("Actual running contact log: ", JSON.stringify(records))
	footsteps.diagnostics_enabled = false
	quit()
