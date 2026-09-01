extends SceneTree
## Proves the machine shaft cannot be climbed out of.
##
## The shaft is a full-height break, so its two rock faces run unbroken from the
## corridor to the top of the map. That is exactly the shape Wall Jump is for,
## and the player owns Wall Jump, Double Jump and Dash by the time they reach
## it. If those faces can be laddered, the player leaves the level and stands on
## its roof, where no camera region follows and no geometry is authored.
##
## This drives the real player against the real geometry rather than reasoning
## about the movement numbers, and fails if it gets meaningfully above the
## corridor it started in.

const CORRIDOR_CEILING_Y := 33.28
const CORRIDOR_FLOOR_Y := 28.16
## Above this the player is climbing the shaft rather than jumping inside the
## corridor, which is the thing that must not be reachable.
const ESCAPE_MARGIN := 3.0
const ATTEMPT_FRAMES := 600

var _completed := false


func _init() -> void:
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Shaft containment probe aborted before completing.")
	quit(1)


func _run() -> void:
	# A failed assert aborts only the function it is in, so without this a bad
	# call leaves the SceneTree running and holds the automation lock forever.
	var watchdog := Timer.new()
	watchdog.wait_time = 180.0
	watchdog.one_shot = true
	watchdog.autostart = true
	watchdog.timeout.connect(_on_watchdog_timeout)
	root.add_child(watchdog)

	var definition := load(
		"res://resources/dev/overgrown_coastal_ascent_interior_review.tres"
	) as LevelDefinition
	assert(definition != null)
	var game_root := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_developer_level(definition)
	for frame in 12:
		await physics_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	var player := level.player
	for ability in PlayerAbility.IMPLEMENTED:
		level.unlock_ability(ability)
	for frame in 2:
		await physics_frame
	assert(player.has_ability(PlayerAbility.WALL_JUMP))
	assert(player.has_ability(PlayerAbility.DASH))

	var terrain := level.get_node("Platforms/RockShell") as PixelInteriorTerrain3D
	var left_face_x := 68.0 * PixelPlatform3D.TILE_WORLD_SIZE
	var right_face_x := 79.0 * PixelPlatform3D.TILE_WORLD_SIZE
	assert(terrain.is_solid_cell(16, 67), "Shaft must have a left face above the corridor.")
	assert(terrain.is_solid_cell(16, 79), "Shaft must have a right face above the corridor.")

	var highest := await _climb(player, left_face_x + 0.36, -1.0)
	highest = maxf(highest, await _climb(player, right_face_x - 0.36, 1.0))
	# The attempt that actually threatens the shaft: kick off one face, Dash the
	# 10.24 m to the other, kick off that one, and repeat to climb the gap.
	highest = maxf(highest, await _ladder(player, left_face_x + 0.36))
	highest = maxf(highest, await _ladder(player, right_face_x - 0.36))

	var ceiling_limit := CORRIDOR_CEILING_Y + ESCAPE_MARGIN
	assert(
		highest < ceiling_limit,
		(
			"Player climbed the machine shaft to y %.2f, past the %.2f m limit. "
			+ "The shaft faces can be laddered and the level can be left."
		) % [highest, ceiling_limit]
	)
	print(
		"Shaft containment passed: best climb reached y %.2f, corridor ceiling %.2f."
		% [highest, CORRIDOR_CEILING_Y]
	)
	_completed = true
	quit(0)


## Hug one face and attempt every climb the kit allows: wall jumps into the
## wall, the saved Double Jump, and a Dash to cross toward the opposite face.
func _climb(player: PlayerCharacter, start_x: float, into_wall: float) -> float:
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(start_x, CORRIDOR_FLOOR_Y + 0.6, 0.0)))
	for frame in 4:
		await physics_frame
	var highest := player.global_position.y
	var press := "move_left" if into_wall < 0.0 else "move_right"
	Input.action_press(press)
	for frame in ATTEMPT_FRAMES:
		# Jump whenever anything is available: floor, wall contact, or the
		# aerial jump. Dash periodically to try to reach the opposite face.
		if frame % 6 == 0:
			Input.action_press("jump")
		elif frame % 6 == 2:
			Input.action_release("jump")
		if frame % 37 == 0:
			Input.action_press("dash")
		elif frame % 37 == 3:
			Input.action_release("dash")
		await physics_frame
		highest = maxf(highest, player.global_position.y)
		if player.is_dead():
			player.reset_at(
				Transform3D(Basis.IDENTITY, Vector3(start_x, CORRIDOR_FLOOR_Y + 0.6, 0.0))
			)
			for settle in 4:
				await physics_frame
	Input.action_release(press)
	Input.action_release("jump")
	Input.action_release("dash")
	return highest


func _ladder(player: PlayerCharacter, start_x: float) -> float:
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(start_x, CORRIDOR_FLOOR_Y + 0.6, 0.0)))
	for frame in 4:
		await physics_frame
	var highest := player.global_position.y
	var heading := 1.0 if start_x < 94.08 else -1.0
	var dash_delay := -1
	for frame in ATTEMPT_FRAMES:
		var contact := player.wall_contact_direction()
		if not is_zero_approx(contact):
			# On a face: kick off it and commit toward the opposite face.
			Input.action_press("jump")
			heading = -signf(contact)
			dash_delay = 4
		elif frame % 4 == 1:
			Input.action_release("jump")
		_hold_direction(heading)
		if dash_delay > 0:
			dash_delay -= 1
		elif dash_delay == 0:
			Input.action_press("dash")
			dash_delay = -1
		elif frame % 9 == 0:
			Input.action_release("dash")
		await physics_frame
		highest = maxf(highest, player.global_position.y)
		if player.is_dead():
			player.reset_at(
				Transform3D(Basis.IDENTITY, Vector3(start_x, CORRIDOR_FLOOR_Y + 0.6, 0.0))
			)
			heading = 1.0 if start_x < 94.08 else -1.0
			for settle in 4:
				await physics_frame
	_release()
	return highest


func _hold_direction(direction: float) -> void:
	if direction < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_press("move_right")


func _release() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
