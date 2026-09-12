extends "res://tools/validate_enemy_friendly_fire.gd"
## Temporary visual fixture; does not add encounters or save a user's layout.

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Run this capture through the runner's -Visual mode.")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("050b20"))
	_world = Node3D.new()
	root.add_child(_world)
	var ground := PixelPlatform3D.new()
	ground.style = load("res://resources/presentation/platform_styles/green_zone.tres")
	ground.size = Vector3(25.6, 3.84, 2)
	ground.position = Vector3(12.8, -1.92, 0)
	_world.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9
	camera.position = Vector3(12, 2, 20)
	_world.add_child(camera)
	camera.make_current()
	var player := (load("res://scenes/player/pixel_player_character.tscn") as PackedScene).instantiate() as PlayerCharacter
	player.position = Vector3(18, 0.55, 0)
	_world.add_child(player)
	player.set_physics_process(false)
	var shooter := _gunner(Vector3(5, 0.55, 0))
	var ally := _gunner(Vector3(11, 0.55, 0))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	label.position = Vector2(30, 25)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("73ffbc"))
	layer.add_child(label)
	for frame in 65:
		shooter._physics_process(1.0 / 60.0)
		await physics_frame
	assert(shooter.shots_fired_total() == 0)
	label.text = "Teammate in the firing line: the gunner holds fire"
	await _capture("enemy_holding_fire")
	ally.position.x = 40
	var skater := SKATER.instantiate() as StompableEnemy3D
	skater.position = Vector3(9, 4, 0)
	skater.patrol_speed = 0
	_world.add_child(skater)
	skater.set_physics_process(false)
	await physics_frame
	for frame in 10:
		shooter._physics_process(1.0 / 60.0)
		await physics_frame
		if shooter.shots_fired_total() > 0: break
	assert(shooter.shots_fired_total() == 2)
	skater.set_physics_process(true)
	for frame in 55:
		await physics_frame
		if skater.is_defeated(): break
	assert(skater.is_defeated())
	label.text = "The skater enters an already-fired shot and gets hit"
	await _capture("enemy_friendly_fire_hit")
	_world.free()
	layer.free()
	quit(0)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/previews/%s.png" % name) == OK)
