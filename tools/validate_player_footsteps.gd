extends SceneTree
const SURFACES := preload("res://scripts/audio/footstep_surface_resolver.gd")

func _init() -> void:
	call_deferred("_run")
	create_timer(30.0).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	# Exercise the original fixture mix independently of user-saved tuning.
	preload("res://scripts/audio/movement_audio_mix.gd").initialize(false)
	var world := Node3D.new()
	root.add_child(world)
	var floor_platform := PixelPlatform3D.new()
	floor_platform.size = Vector3(51.2, 2.56, 2)
	floor_platform.position.y = -1.28
	floor_platform.style = load("res://resources/presentation/platform_styles/shoreline_sand.tres")
	world.add_child(floor_platform)
	var player := (load("res://scenes/player/pixel_player_character.tscn") as PackedScene).instantiate() as PlayerCharacter
	player.position.y = 0.7
	world.add_child(player)
	var audio := player.get_node("Footsteps")
	var contacts: Array[Dictionary] = []
	player.pixel_visual.footstep_contact.connect(func(contact: Dictionary) -> void: contacts.append(contact))
	for frame in 20:
		await physics_frame
	assert(audio.played_count == 0)
	Input.action_press("move_right")
	for frame in 35:
		await physics_frame
	Input.action_release("move_right")
	assert(audio.played_count >= 2 and audio.last_event.surface == "sand")
	var played_sand: Array = audio.history.filter(func(event: Dictionary) -> bool: return event.status == "played")
	assert(played_sand[0].clip == "nox_sand_walk_01.wav", "A fresh stride starts with Sand 01.")
	for event in played_sand:
		var expected := "01" if event.foot == "left" else "02"
		assert(event.clip == "nox_sand_walk_%s.wav" % expected)
	for contact in contacts:
		assert(contact.frame in [1, 4])
		assert(contact.foot in ["left", "right"])
	player.set_physics_process(false)
	player.horizontal_speed = 0.0
	_validate_markers(player.pixel_visual)
	_validate_selection(audio)
	# Three distinct voices survive changes of surface and gait.
	audio.reset_run()
	audio.play_step("grass", "run")
	var first_voice: AudioStreamPlayer = audio._voices[0]
	var first_stream := first_voice.stream
	for frame in 3:
		await physics_frame
	var first_position := first_voice.get_playback_position()
	audio.play_step("sand", "run")
	audio.play_step("grass", "walk")
	assert(audio.active_voice_count() == 3)
	assert(first_voice.stream == first_stream)
	assert(first_voice.get_playback_position() >= first_position)
	for frame in 3:
		await physics_frame
	assert(audio.active_voice_count() == 3, "Idle must let existing recordings finish.")
	var before: int = audio.played_count
	audio.play_step("cave")
	assert(audio.played_count == before and audio.active_voice_count() == 3)
	# One event is consumed once; stale animation events do not burst-play.
	audio.reset_run()
	player.horizontal_speed = 8.0
	audio._last_position = player.global_position - Vector3(0.1, 0, 0)
	var event := {"id": audio._last_contact_id + 1, "foot": "left", "frame": 1,
		"gait": "run", "age_seconds": 0.0}
	audio._on_footstep_contact(event)
	before = audio.played_count
	audio._on_footstep_contact(event)
	assert(audio.played_count == before and audio.last_event.status == "duplicate")
	event.id += 1
	event.age_seconds = 0.2
	audio._on_footstep_contact(event)
	assert(audio.played_count == before and audio.last_event.status == "late marker")
	event.id += 1
	event.age_seconds = 0.0
	audio._last_position = player.global_position
	audio._on_footstep_contact(event)
	assert(audio.played_count == before and audio.last_event.status == "blocked/teleport")
	# Leaving the floor blocks new steps, but the existing tail is independent.
	player.position.y = 5.0
	player.set_physics_process(true)
	for frame in 4:
		await physics_frame
	before = audio.played_count
	event.id += 1
	audio._on_footstep_contact(event)
	assert(audio.played_count == before and audio.last_event.status == "inactive")
	audio.reset_run()
	assert(audio.active_voice_count() == 0)
	world.queue_free()
	await process_frame
	await _validate_surfaces()
	print("Footsteps passed: marker crossings/feet, held and skipped frames, tapping/knife cadence, no-repeat banks, independent voices, and surface boundaries.")
	quit()

func _validate_markers(visual: PixelPlayerVisual3D) -> void:
	var track = load("res://resources/audio/markers/player_run.tres")
	var crossed: Array = track.contacts_between(0.0, 7.1)
	assert(crossed.size() == 3)
	assert([crossed[0].frame, crossed[1].frame, crossed[2].frame] == [1, 4, 1])
	assert(track.contacts_between(7.1, 7.1).is_empty())
	var reverse_track = load("res://resources/audio/markers/player_backpedal.tres")
	var reverse: Array = reverse_track.contacts_between(0.0, 6.0)
	assert(reverse.size() == 2 and reverse[0].frame == 3 and reverse[1].frame == 0)
	assert(reverse[0].foot == "left" and reverse[1].foot == "right")
	var steady := _stride_contacts(visual, false, false)
	assert(steady.size() == 7)
	for index in range(1, steady.size()):
		var interval := steady[index].get_slice(":", 0).to_int() - steady[index - 1].get_slice(":", 0).to_int()
		assert(absi(interval - 18) <= 1, "Running contacts must be 0.30 seconds apart at 60 Hz.")
	assert(_stride_contacts(visual, true, false) == steady, "Knife attacks must preserve stride events.")
	assert(_stride_contacts(visual, false, true) == steady, "Short stops must pause the stride, not restart it.")

func _stride_contacts(visual: PixelPlayerVisual3D, attacks: bool, tapping: bool) -> Array[String]:
	visual.set_state("idle", true)
	var contacts: Array[String] = []
	var clock := [0]
	var listener := func(event: Dictionary) -> void: contacts.append("%d:%s" % [clock[0], event.foot])
	visual.footstep_contact.connect(listener)
	for frame in 120:
		clock[0] = frame
		var attacking := attacks and frame % 24 < 20
		visual.tick(1.0 / 60.0, true, 8.0, 0.0, attacking, false, true)
		if attacking and frame % 24 == 19:
			assert(visual.weapon.frame == 5)
		if tapping and frame % 5 == 4:
			for idle in 5:
				visual.tick(1.0 / 60.0, true, 0.0, 0.0, false, false, true)
	visual.footstep_contact.disconnect(listener)
	return contacts

func _validate_selection(audio: Node) -> void:
	audio._random.seed = 12345
	for mix in [["grass", "run", 3], ["grass", "walk", 3]]:
		var seen := {}
		var previous := ""
		for step in 24:
			audio.reset_run()
			audio.play_step(mix[0], mix[1])
			var chosen: String = audio.last_event.clip
			assert(chosen != previous, "Random selection must avoid consecutive repeats.")
			seen[chosen] = true
			previous = chosen
			assert(audio._voices[0].pitch_scale == 1.0 and audio._voices[0].volume_db == -10.0)
			assert(not audio._voices[0].stream.resource_path.contains("tight_run"))
		assert(seen.size() == mix[2])
	# Sand is bound to the foot, not a random choice or a playback counter.
	# Repeated foot identities model interruptions or a change of gait phase.
	for gait in ["run", "walk"]:
		for foot in ["left", "right", "left", "left", "right", "right"]:
			audio.reset_run()
			audio.play_step("sand", gait, {"foot": foot})
			var expected := "01" if foot == "left" else "02"
			assert(audio.last_event.clip == "nox_sand_walk_%s.wav" % expected)
			assert(audio._voices[0].pitch_scale == 1.0 and audio._voices[0].volume_db == -13.0)
	_press(audio, KEY_F9)
	assert(audio._debug_label.visible)
	_press(audio, KEY_F9)

func _press(audio: Node, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	audio._unhandled_key_input(key)

func _validate_surfaces() -> void:
	var game := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_level(&"arrival_shoreline")
	for frame in 10:
		await physics_frame
	var level := game.current_level as LevelSession3D
	for sample in [[5.0, "sand"], [10.0, "sand"], [13.9, "sand"], [14.2, "grass"], [19.0, "grass"], [34.0, "grass"]]:
		var probe := PhysicsRayQueryParameters3D.create(Vector3(sample[0], 3, 0), Vector3(sample[0], -2, 0), 1, [level.player.get_rid()])
		var hit := level.get_world_3d().direct_space_state.intersect_ray(probe)
		assert(not hit.is_empty())
		assert(SURFACES.surface_at(hit.collider, hit.position) == sample[1])
	var terrain := PixelInteriorTerrain3D.new()
	terrain.style = PixelInteriorTerrainStyle.new()
	assert(SURFACES.surface_at(terrain, Vector3.ZERO) == "cave")
	terrain.set_meta("footstep_surface", "sand")
	assert(SURFACES.surface_at(terrain, Vector3.ZERO) == "sand")
	terrain.free()
