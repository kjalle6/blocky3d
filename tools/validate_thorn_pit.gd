extends SceneTree
## Real falls and the existing double-jump crossing at the enclosed Level 1 pit.
var deaths := 0

func _init() -> void:
	call_deferred("_run")
	create_timer(35.0, true).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	var app := load("res://scenes/app/game_root.tscn").instantiate() as Node
	app.persist_progression = false
	root.add_child(app)
	app.load_level(&"arrival_shoreline")
	var level: LevelSession3D = app.current_level
	var player := level.player
	var pit := level.get_node("Platforms/ThornBasinA") as PixelPlatform3D
	var left := level.get_node("Platforms/ThornGardenEntry") as PixelPlatform3D
	var right := level.get_node("Platforms/ThornTerrace") as PixelPlatform3D
	assert(is_equal_approx(left.position.y + left.size.y * 0.5, 0.64))
	assert(is_equal_approx(right.position.y + right.size.y * 0.5, 1.92))
	assert(is_equal_approx(right.position.x - right.size.x * 0.5 - left.position.x - left.size.x * 0.5, 7.68))
	assert(is_equal_approx(pit.position.y + pit.size.y * 0.5, -2.4))
	assert(pit.position.y - pit.size.y * 0.5 < -10.0)
	# Hold death in place while testing, so no delayed respawn can mask a miss.
	player.died.disconnect(level._on_player_died)
	player.died.connect(func() -> void: deaths += 1)
	await physics_frame
	for x in [79.12, 80.64, 82.56, 84.48, 86.0]:
		player.reset_at(Transform3D(Basis.IDENTITY, Vector3(x, 0.3, 0)))
		var before := deaths
		for frame in 90:
			await physics_frame
			if player.is_dead(): break
		assert(player.is_dead() and deaths == before + 1, "Every part of the bed must kill, including beside either wall: %s" % x)
		assert(player.global_position.y > -2.0, "The pit must kill on its spikes, before the global kill plane.")
	# The backup lethal fill catches the entire pit bottom even without the row.
	var spikes := level.get_node("Hazards/ThornBasinASpikes") as PixelSpikeRow3D
	spikes.monitoring = false
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(82.56, 0.3, 0)))
	for frame in 90:
		await physics_frame
		if player.is_dead(): break
	assert(player.is_dead(), "The full-width pit fill must be lethal even without the spike row.")
	spikes.monitoring = true
	# The other lower beds share the same depth and remain lethal at both walls.
	for x in [94.48, 96.64, 98.8, 107.28, 109.12, 110.96, 127.12, 135.0, 142.72, 151.0, 158.32]:
		player.reset_at(Transform3D(Basis.IDENTITY, Vector3(x, 0.3, 0)))
		var before := deaths
		for frame in 90:
			await physics_frame
			if player.is_dead(): break
		assert(player.is_dead() and deaths == before + 1, "The selected pit bed must have no safe landing: %s" % x)
		assert(player.global_position.y > -2.0, "The bed must kill before the global kill plane.")
	level.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(75.5, 1.20, 0)))
	for frame in 4: await physics_frame
	assert(not player.is_dead() and player.is_on_floor())
	var first := false
	var second := false
	var held := 0
	var landed := false
	Input.action_press("move_right")
	for frame in 240:
		if held > 0:
			held -= 1
			if held == 0: Input.action_release("jump")
		if not first and player.is_on_floor() and player.global_position.x >= 77.2:
			Input.action_press("jump")
			first = true
			held = 16
		elif first and not second and held == 0 and not player.is_on_floor() and player.global_position.x >= 81.0:
			Input.action_press("jump")
			second = true
			held = 18
		if player.global_position.x >= 89.8: Input.action_release("move_right")
		await physics_frame
		if player.is_dead(): break
		if second and player.is_on_floor() and player.global_position.x > 86.4:
			landed = true
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	assert(landed and not player.is_dead(), "The established double-jump route must still land on the terrace.")
	assert(absf(player.feet_world_y() - 1.92) < 0.08)
	app.free()
	print("Lower pits passed: matching bed depths, lethal falls across all four pits, backup fill and real-input double-jump landing.")
	quit()
