extends SceneTree

var player: PlayerCharacter
var audio: Node
var events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")
	create_timer(35.0).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	# Exercise the original fixture mix independently of user-saved tuning.
	preload("res://scripts/audio/movement_audio_mix.gd").initialize(false)
	var world := Node3D.new()
	root.add_child(world)
	_floor(world, Vector3(-10, -0.5, 0), Vector3(20, 1, 2), "grass")
	_floor(world, Vector3(10, -0.5, 0), Vector3(20, 1, 2), "sand")
	_floor(world, Vector3(-12, 2.5, 0), Vector3(3, 1, 2), "grass")
	player = load("res://scenes/player/pixel_player_character.tscn").instantiate()
	player.position = Vector3(-4, 3, 0)
	world.add_child(player)
	audio = player.get_node("JumpAudio")
	audio.contact_played.connect(func(event: Dictionary) -> void:
		if event.kind == "jump_land":
			assert(player.is_on_floor(), "Landing audio must occur on physical touchdown.")
		events.append(event))
	await _frames(40)
	assert(player.is_on_floor() and events.is_empty(), "Initial spawn settling must be silent.")

	# Holding the input produces exactly one start and one physical landing.
	Input.action_press("jump")
	await _frames(3)
	assert(not player.is_on_floor() and events.size() == 1 and events[0].kind == "jump_start")
	await _frames(60)
	assert(player.is_on_floor() and events.size() == 2 and events[1].kind == "jump_land")
	Input.action_release("jump")
	await _frames(10)
	assert(events.size() == 2)

	# Sand uses its own five-clip takeoff and landing pools.
	await _place(Vector3(4, 0.65, 0))
	Input.action_press("jump")
	await _frames(3)
	assert(not player.is_on_floor() and events.size() == 1)
	assert(events[0].clip.begins_with("nox_sand_jump_start_"))
	await _frames(60)
	assert(player.is_on_floor() and events.size() == 2)
	assert(events[1].clip.begins_with("nox_sand_jump_land_"))

	# Takeoff uses the departure surface; landing queries the destination.
	await _place(Vector3(-2, 0.65, 0))
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(55)
	assert(player.is_on_floor() and player.global_position.x > 0)
	assert(events.size() == 2)
	assert(events[0].clip.begins_with("nox_grass_jump_start_"))
	assert(events[1].clip.begins_with("nox_sand_jump_land_"))
	await _place(Vector3(2, 0.65, 0))
	Input.action_press("move_left")
	Input.action_press("jump")
	await _frames(55)
	assert(player.is_on_floor() and player.global_position.x < 0)
	assert(events.size() == 2)
	assert(events[0].clip.begins_with("nox_sand_jump_start_"))
	assert(events[1].clip.begins_with("nox_grass_jump_land_"))

	# A fall from a supported ledge lands audibly without a takeoff sound.
	await _place(Vector3(-12, 3.65, 0))
	Input.action_press("move_right")
	await _frames(65)
	assert(player.is_on_floor() and events.size() == 1 and events[0].kind == "jump_land")

	# Coyote takeoff retains the last grass support after leaving its edge.
	await _place(Vector3(-12, 3.65, 0))
	Input.action_press("move_right")
	for frame in 40:
		await _frames(1)
		if not player.is_on_floor():
			break
	assert(not player.is_on_floor())
	Input.action_press("jump")
	await _frames(2)
	assert(events.size() == 1 and events[0].kind == "jump_start")

	# Air abilities do not replay a grass push-off recording.
	await _place(Vector3(-4, 0.65, 0))
	player.configure_abilities([PlayerAbility.DOUBLE_JUMP, PlayerAbility.WALL_JUMP], [PlayerAbility.DOUBLE_JUMP, PlayerAbility.WALL_JUMP])
	Input.action_press("jump")
	await _frames(4)
	assert(events.size() == 1)
	player._perform_double_jump()
	player._last_wall_contact_direction = 1.0
	player._perform_wall_jump()
	await _frames(2)
	assert(events.size() == 1, "Double/wall jumps must not replay grass takeoff.")

	# Reset while airborne must stop tails and suppress the next spawn landing.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-4, 3, 0)))
	Input.action_release("jump")
	for voice in audio._voices:
		assert(not voice.playing)
	events.clear()
	await _frames(40)
	assert(player.is_on_floor() and events.is_empty())
	player.set_developer_inspection_enabled(true)
	player.position.y = 3.0
	player.set_developer_inspection_enabled(false)
	await _frames(40)
	assert(events.is_empty(), "Inspection settling must be silent.")

	# Tiny support interruptions must not produce repeated landing impacts.
	audio._air_time = 0.01
	audio._on_landed(10.0)
	assert(events.is_empty())
	await _validate_banks()
	print("Jump audio passed: grass 10+10 and sand 5+5 original clips, no-repeat pools, takeoff/touchdown, cross-surface jumps, ledge/coyote contacts, air abilities, and reset/inspection silence.")
	quit()

func _validate_banks() -> void:
	player.set_physics_process(false)
	audio.set_physics_process(false)
	audio._random.seed = 592
	# Disconnect the physical-contact assertion for direct bank auditions.
	for connection in audio.contact_played.get_connections():
		audio.contact_played.disconnect(connection.callable)
	for bank in audio.START_BANKS.values() + audio.LAND_BANKS.values():
		var expected_count := 10 if bank.surface == &"grass" else 5
		var expected_volume := -16.0 if bank.surface == &"sand" else -10.0
		assert(bank.clips.size() == expected_count)
		var seen := {}
		var previous := ""
		for step in 100:
			audio.reset_run()
			audio._play_contact(bank, {"surface": str(bank.surface)})
			var chosen: String = audio.last_event.clip
			assert(chosen != previous)
			assert(chosen.begins_with("nox_%s_%s_" % [bank.surface, bank.gait]))
			assert(audio._voices[0].pitch_scale == 1.0 and audio._voices[0].volume_db == expected_volume)
			seen[chosen] = true
			previous = chosen
		assert(seen.size() == expected_count)
	audio.reset_run()
	audio._play_contact(audio.START_BANKS["grass"], {"surface": "grass"})
	var first: AudioStreamPlayer = audio._voices[0]
	var stream := first.stream
	await _frames(2)
	audio._play_contact(audio.LAND_BANKS["sand"], {"surface": "sand"})
	assert(first.playing and first.stream == stream and audio._voices[1].playing)
	var before: int = audio.played_count
	audio._play_contact(audio.LAND_BANKS["grass"], {"surface": "sand"})
	audio._play_contact(audio.LAND_BANKS.get("cave"), {"surface": "cave"})
	assert(audio.played_count == before)
	player.kill(PlayerCharacter.DEATH_KIND_WATER)
	for voice in audio._voices:
		assert(not voice.playing, "Death must stop jump-contact voices.")

func _place(at: Vector3) -> void:
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	player.reset_at(Transform3D(Basis.IDENTITY, at))
	await _frames(15)
	assert(player.is_on_floor())
	events.clear()

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _floor(world: Node3D, at: Vector3, size: Vector3, surface: String) -> void:
	var body := StaticBody3D.new()
	body.name = surface + "Floor"
	body.position = at
	body.set_meta("footstep_surface", surface)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
