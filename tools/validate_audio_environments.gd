extends SceneTree
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const SURFACES := preload("res://scripts/audio/footstep_surface_resolver.gd")
const TEST_PATH := "res://build/audio_environment_test/mix.tres"
const TEST_ASSETS := "res://build/audio_environment_test/recordings"

func _init() -> void:
	call_deferred("_run")
	create_timer(35.0).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	var original_hash := FileAccess.get_sha256(MIX.SAVE_PATH)
	MIX.initialize(false)
	assert(MIX.ambience_settings(&"cave").recording != null)
	assert(MIX.ambience_settings(&"underground").recording == null)
	assert(MIX.bank_for("underground/step").clips.is_empty())
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_developer_level(load("res://resources/dev/green_zone_finale_wip.tres"))
	await physics_frame
	var level: LevelSession3D = game.current_level
	var player: PlayerCharacter = level.player
	player.set_physics_process(false)
	for sample in [
		[Vector3(4, 0.7, 0), &"outdoors"],
		[Vector3(119, -0.5, 0), &"outdoors"],
		[Vector3(119, -1.5, 0), &"underground"],
		[Vector3(120, -24.9, 0), &"underground"],
		[Vector3(157.44, -12, 0), &"underground"],
		[Vector3(157.44, 0.7, 0), &"outdoors"],
		[Vector3(169, 0.7, 0), &"outdoors"],
		[Vector3(50, -12, 0), &"outdoors"],
	]:
		player.position = sample[0]
		assert(MIX.environment_for(player) == sample[1], "Room selection must follow location, including direct respawns.")
	player.position = Vector3(120, -24.9, 0)
	await physics_frame
	assert(SURFACES.sample(player).surface == "underground")
	# The new terrain bank and room are independently selected.
	var underground := MIX.bank_for("underground/step")
	underground.clips = MIX.bank_for("sand/step").clips.duplicate()
	var footsteps: Node = player.get_node("Footsteps")
	footsteps.reset_run()
	footsteps.play_step("underground", "run", {"foot": "left"})
	assert(footsteps._voices[0].bus == &"UndergroundSFX")
	var landing := MIX.bank_for("underground/jump_land")
	landing.clips = MIX.bank_for("grass/jump_land").clips.duplicate()
	player.get_node("JumpAudio")._play_contact(landing, {"surface": "underground"})
	assert(player.get_node("JumpAudio")._voices[0].bus == &"UndergroundSFX")
	var underground_bus := AudioServer.get_bus_index(&"UndergroundSFX")
	var cave_bus := AudioServer.get_bus_index(MIX.preview_bus(&"cave"))
	var cave_effect := AudioServer.get_bus_effect(cave_bus, 0) as AudioEffectReverb
	var cave_amount := cave_effect.wet
	var panel: CanvasLayer = game.audio_tuning_panel
	panel.open_panel()
	assert(AudioServer.is_bus_mute(underground_bus))
	panel._surface_picker.item_selected.emit(3)
	assert(panel.surface == "underground" and panel.listening_environment() == &"underground")
	(panel._body.find_child("ReverbAmount", true, false) as HSlider).value = 39
	(panel._body.find_child("ReverbRoomSize", true, false) as HSlider).value = 81
	(panel._body.find_child("ReverbDamping", true, false) as HSlider).value = 42
	var settings := MIX.reverb_settings(&"underground")
	assert(settings.amount == 0.39 and settings.room_size == 0.81 and settings.damping == 0.42)
	assert(is_equal_approx(cave_effect.wet, cave_amount), "Underground tuning must not change Cave.")
	panel._preview_contact()
	assert(panel._voices[0].bus == &"UndergroundPreview")
	var preview_index := AudioServer.get_bus_index(&"UndergroundPreview")
	assert(is_equal_approx((AudioServer.get_bus_effect(preview_index, 0) as AudioEffectReverb).wet, 0.39))
	panel._toggle_comparison()
	assert(is_equal_approx((AudioServer.get_bus_effect(preview_index, 0) as AudioEffectReverb).wet, 0.24))
	assert(not (panel._body.find_child("ReverbAmount", true, false) as HSlider).editable)
	panel._toggle_comparison()
	var ambience: AudioStreamPlayer = game.cave_ambience
	# Exercise the picker's captured target, its signals, and all supported formats.
	var recordings := [
		"res://assets/audio/footsteps/nox_sand_walk_01.wav",
		"res://assets/audio/footsteps/sand_gravel_006.ogg",
		"res://assets/audio/water/heavy-water-splash.mp3",
	]
	for path in recordings:
		for button: Button in panel._body.find_children("*", "Button", true, false):
			if button.text == "Choose ambience…":
				button.pressed.emit()
		assert(panel._ambience_file_dialog.visible)
		panel._ambience_file_dialog.file_selected.emit(path)
		panel._ambience_file_dialog.hide()
		await create_timer(0.9).timeout
		assert(ambience.playing)
		assert(MIX.ambience_settings(&"underground").recording.get_meta("source_file") == path)
		assert(MIX.ambience_settings(&"cave").recording.resource_path.ends_with("nox_cave_drips_loop.wav"))
		if ambience.stream is AudioStreamWAV:
			assert(ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		else:
			assert(ambience.stream.loop and ambience.stream.loop_offset == 0.0)
		ambience.seek(ambience.stream.get_length() - 0.05)
		await create_timer(0.2).timeout
		assert(ambience.playing and ambience.get_playback_position() < ambience.stream.get_length())
	(panel._body.find_child("AmbienceVolume", true, false) as HSlider).value = -17.5
	await process_frame
	await process_frame
	assert(is_equal_approx(ambience.volume_db, -17.5))
	assert(MIX.saved_underground_ambience.recording == null)
	DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir())
	assert(MIX.save_defaults(TEST_PATH, TEST_ASSETS) == OK)
	var loaded := ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(loaded.underground_reverb.amount == 0.39 and loaded.underground_reverb.room_size == 0.81 and loaded.underground_reverb.damping == 0.42)
	assert(loaded.underground_ambience.volume_db == -17.5)
	assert(loaded.underground_ambience.recording.resource_path.begins_with(TEST_ASSETS))
	assert(loaded.underground_ambience.recording.has_meta("source_sha256"))
	assert(loaded.cave_ambience.recording.resource_path.ends_with("nox_cave_drips_loop.wav"))
	# The ambience picker also works for Cave, and an intentional empty slot
	# must stay empty after save/reload rather than restoring the old drip track.
	panel._surface_picker.item_selected.emit(2)
	panel._set_ambience_recording(recordings[1], &"cave")
	assert(MIX.working_ambience.recording.get_meta("source_file") == recordings[1])
	assert(MIX.working_underground_ambience.recording != MIX.working_ambience.recording)
	for button: Button in panel._body.find_children("*", "Button", true, false):
		if button.text == "Remove ambience":
			button.pressed.emit()
	assert(MIX.ambience_settings(&"cave").recording == null)
	assert(MIX.save_defaults(TEST_PATH, TEST_ASSETS) == OK)
	loaded = ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(loaded.cave_ambience.recording == null and loaded.cave_ambience.recording_configured)
	assert(loaded.underground_ambience.recording != null)
	panel._surface_picker.item_selected.emit(3)
	await create_timer(0.9).timeout
	assert(ambience.playing)
	var position := ambience.get_playback_position()
	panel.close_panel()
	await create_timer(0.05).timeout
	assert(ambience.get_playback_position() >= position, "Closing the panel in the same room must preserve its bed.")
	assert(not AudioServer.is_bus_mute(underground_bus))
	level._reset_run()
	player.set_physics_process(false)
	assert(MIX.environment_for(player) == &"outdoors")
	await create_timer(0.5).timeout
	assert(not ambience.playing)
	# Loading the next scene cannot retain the underground zone.
	game.show_level_select()
	await process_frame
	game.load_level(&"arrival_shoreline")
	assert(MIX.environment_for(game.current_level.player) == &"outdoors")
	game.free()
	MIX.initialize(false)
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash)
	print("Audio environments passed: underground boundaries, terrain/buses, independent settings, picker WAV/OGG/MP3 loops, saved assets/empty slots, and respawn/exit cleanup.")
	quit()
