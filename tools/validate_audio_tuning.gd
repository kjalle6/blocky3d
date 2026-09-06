extends SceneTree
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const TEST_PATH := "res://build/audio_tuning_test/mix.tres"
const TEST_ASSETS := "res://build/audio_tuning_test/recordings"

func _init() -> void:
	call_deferred("_run")
	create_timer(35.0).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	var original_hash := FileAccess.get_sha256(MIX.SAVE_PATH)
	MIX.initialize(false)
	var random := RandomNumberGenerator.new()
	var bank := MIX.bank_for("grass/run")
	assert(not MIX.has_changes())
	MIX.working_ambience.volume_db = -9.0
	MIX.working_ambience.enabled = false
	assert(MIX.saved_ambience.volume_db == -6.0 and MIX.saved_ambience.enabled)
	assert(MIX.has_changes(), "Ambience-only edits must enable saving.")
	bank.volume_db = -22.5
	bank.disabled_indices = PackedInt32Array([0, 2])
	for attempt in 12:
		assert(bank.choose_clip(random, 1) == 1, "A one-recording pool must repeat safely.")
	bank.disabled_indices = PackedInt32Array([0, 1, 2])
	assert(bank.choose_clip(random) == -1, "An empty enabled pool must be silent.")
	bank.disabled_indices = PackedInt32Array([0, 2])
	assert(MIX.saved["grass/run"].disabled_indices.is_empty(), "Working arrays must not modify saved defaults.")
	MIX.working_reverb.amount = 0.27
	MIX.working_reverb.room_size = 0.61
	MIX.working_reverb.damping = 0.73
	assert(MIX.saved_reverb.amount == 0.16)
	assert(MIX.has_changes())
	MIX.listening_to_saved = true
	assert(MIX.bank_for("grass/run").volume_db == -10.0)
	MIX.listening_to_saved = false
	assert(MIX.bank_for("grass/run").volume_db == -22.5)

	# Promote one deliberately selected recording; no external folder is needed
	# by the saved resource. All writes stay in a disposable build directory.
	DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir())
	var external := MIX.load_recording("res://assets/audio/footsteps/nox_sand_walk_01.wav")
	assert(external != null)
	var cave := MIX.bank_for("cave/step")
	cave.clips.append(external)
	cave.clips.append(MIX.bank_for("sand/step").clips[1])
	cave.labels = PackedStringArray(["one", "two"])
	cave.foot_indices = {"left": 1, "right": 0}
	assert(MIX.save_defaults(TEST_PATH, TEST_ASSETS) == OK)
	assert(not MIX.has_changes())
	var loaded := ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(loaded.banks["grass/run"].volume_db == -22.5)
	assert(loaded.banks["grass/run"].disabled_indices == PackedInt32Array([0, 2]))
	assert(loaded.cave_reverb.amount == 0.27 and loaded.cave_reverb.room_size == 0.61 and loaded.cave_reverb.damping == 0.73)
	assert(loaded.cave_ambience.volume_db == -9.0 and not loaded.cave_ambience.enabled)
	assert(loaded.banks["cave/step"].foot_indices == {"left": 1, "right": 0})
	var promoted: AudioStream = loaded.banks["cave/step"].clips[0]
	assert(promoted.resource_path.begins_with(TEST_ASSETS))
	assert(promoted.has_meta("source_sha256"))
	assert(is_equal_approx(promoted.get_length(), external.get_length()))
	# Replacing an existing file must work too, not just the first save.
	MIX.working["grass/run"].volume_db = -21.0
	MIX.working_ambience.enabled = true
	assert(MIX.save_defaults(TEST_PATH, TEST_ASSETS) == OK)
	loaded = ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(loaded.banks["grass/run"].volume_db == -21.0)
	MIX.working["grass/run"].volume_db = -20.0
	assert(MIX.save_defaults("res://build/audio_tuning_missing/child/mix.tres", TEST_ASSETS) != OK)
	assert(MIX.saved["grass/run"].volume_db == -21.0 and MIX.has_changes())
	MIX.revert()
	assert(MIX.bank_for("grass/run").volume_db == -21.0)
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash)
	await _validate_reverb_audio()

	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_level(&"arrival_shoreline")
	for frame in 8:
		await physics_frame
	game._set_gameplay_tools_visible(true)
	assert(game._audio_tools_button.visible)
	game._audio_tools_button.pressed.emit()
	var panel: CanvasLayer = game.audio_tuning_panel
	assert(panel.is_open and paused)
	assert(is_equal_approx(panel.RUN_STEP_INTERVAL, 0.30))
	assert(panel._pace.get_item_text(0) == "Running · 3.3 steps/sec")
	# Exercise the actual controls and their signal bindings, including a
	# rebuild after selecting a different action.
	var slider: HSlider = panel._body.find_child("VolumeSlider", true, false)
	slider.value = -19.5
	assert(MIX.bank_for("grass/run").volume_db == -19.5)
	assert(MIX.saved["grass/run"].volume_db == -21.0)
	assert(not panel._save.disabled, "An editor project run must allow explicit saving.")
	var checkbox: CheckBox = panel._body.find_children("*", "CheckBox", true, false)[0]
	checkbox.button_pressed = true
	assert(not 0 in MIX.bank_for("grass/run").disabled_indices)
	for button: Button in panel._body.find_children("*", "Button", true, false):
		if button.text == "Use for both run & walk":
			button.pressed.emit()
	assert(MIX.bank_for("grass/walk").volume_db == -19.5)
	assert(MIX.bank_for("grass/walk").gait == &"walk")
	panel._kind_picker.item_selected.emit(1)
	assert(panel.kind == "walk" and panel._pace.selected == 1)
	panel._surface_picker.item_selected.emit(1)
	assert(panel.surface == "sand" and panel.kind == "step")
	panel._remove_clip(0)
	assert(MIX.bank_for("sand/step").foot_indices == {"left": -1, "right": 0})
	assert(MIX.saved["sand/step"].clips.size() == 2)
	panel._add_files(PackedStringArray(["res://assets/audio/footsteps/nox_sand_walk_01.wav"]))
	assert(MIX.bank_for("sand/step").clips.size() == 2)
	MIX.revert()
	panel._surface_picker.item_selected.emit(2)
	await _validate_ambience_preview(game, panel)
	var reverb_slider: HSlider = panel._body.find_child("ReverbAmount", true, false)
	reverb_slider.value = 38
	assert(MIX.working_reverb.amount == 0.38 and MIX.saved_reverb.amount == 0.27)
	var cave_room: HSlider = panel._body.find_child("ReverbRoomSize", true, false)
	cave_room.value = 44
	var damping: HSlider = panel._body.find_child("ReverbDamping", true, false)
	damping.value = 82
	assert(MIX.working_reverb.room_size == 0.44 and MIX.working_reverb.damping == 0.82)
	var preview_effect := AudioServer.get_bus_effect(AudioServer.get_bus_index(MIX.PREVIEW_BUS), 0) as AudioEffectReverb
	assert(is_equal_approx(preview_effect.wet, 0.38))
	assert(is_equal_approx(preview_effect.room_size, 0.44))
	assert(is_equal_approx(preview_effect.damping, 0.82))
	panel._toggle_comparison()
	assert(MIX.reverb_settings().amount == 0.27)
	assert(is_equal_approx((AudioServer.get_bus_effect(AudioServer.get_bus_index(MIX.PREVIEW_BUS), 0) as AudioEffectReverb).wet, 0.27))
	assert(not (panel._body.find_child("ReverbAmount", true, false) as HSlider).editable)
	panel._toggle_comparison()
	assert(MIX.reverb_settings().amount == 0.38)
	var reverb_toggle: CheckBox = panel._body.find_child("CaveReverbEnabled", true, false)
	reverb_toggle.button_pressed = false
	assert(not MIX.reverb_settings().enabled)
	MIX.revert()
	panel._surface_picker.item_selected.emit(0)
	var position: Vector3 = game.current_level.player.position
	Input.action_press("move_right")
	for frame in 8:
		await process_frame
	assert(game.current_level.player.position == position, "Preview mode must freeze gameplay.")
	Input.action_release("move_right")
	panel._preview_contact()
	assert(panel._voices[0].playing, "Preview must play while gameplay is paused.")
	assert(panel._voices[0].volume_db == -21.0)
	await create_timer(0.06).timeout
	assert(panel._voices[0].get_playback_position() > 0.0)
	panel._toggle_comparison()
	assert(MIX.listening_to_saved)
	panel._toggle_comparison()
	assert(not MIX.listening_to_saved)
	panel.close_panel()
	assert(not paused and not panel._voices[0].playing)
	assert(not game._gameplay_tools_visible)
	var footsteps: Node = game.current_level.player.get_node("Footsteps")
	footsteps.reset_run()
	footsteps.play_step("grass", "run")
	assert(footsteps._voices[0].volume_db == -21.0)
	assert(footsteps._voices[0].stream == MIX.bank_for("grass/run").clips[1])
	footsteps.reset_run()
	footsteps.play_step("cave", "run", {"foot": "right"})
	assert(footsteps._voices[0].stream == MIX.bank_for("cave/step").clips[0])
	assert(footsteps._voices[0].bus == &"Master", "A cave recording outdoors must stay dry.")
	game.current_level.set_meta("audio_environment", &"cave")
	await create_timer(0.5).timeout
	assert(game.cave_ambience.playing, "Entering a cave must start its ambience.")
	var ambience_position: float = game.cave_ambience.get_playback_position()
	game.current_level._reset_run()
	await create_timer(0.1).timeout
	assert(game.cave_ambience.get_playback_position() > ambience_position, "Respawning must not restart the room ambience.")
	footsteps.reset_run()
	footsteps.play_step("grass", "run")
	assert(footsteps._voices[0].bus == MIX.CAVE_BUS, "A grass patch inside the cave must share its room acoustics.")
	var jumps: Node = game.current_level.player.get_node("JumpAudio")
	jumps._play_contact(MIX.bank_for("grass/jump_start"), {"surface": "grass"})
	assert(jumps._voices[0].bus == MIX.CAVE_BUS)
	var gameplay_bus := AudioServer.get_bus_index(MIX.CAVE_BUS)
	panel.open_panel()
	assert(AudioServer.is_bus_mute(gameplay_bus), "Paused gameplay echoes must not leak into the preview.")
	panel._space.item_selected.emit(1)
	panel._preview_contact()
	assert(panel._voices[0].bus == MIX.PREVIEW_BUS)
	assert(MIX.environment_for(game.current_level.player) == &"cave")
	game.show_level_select()
	assert(not paused and not panel.is_open, "Leaving the level must release the preview pause.")
	assert(not AudioServer.is_bus_mute(gameplay_bus))
	await create_timer(0.5).timeout
	assert(not game.cave_ambience.playing, "Leaving the cave must fade out and stop ambience.")
	var cave_level: Node = load("res://scenes/levels/overgrown_coastal_ascent_interior.tscn").instantiate()
	assert(cave_level.get_meta("audio_environment") == &"cave")
	cave_level.free()
	# Respect an existing pause owned by another tool.
	paused = true
	panel.open_panel()
	panel.close_panel()
	assert(paused)
	paused = false
	game.free()
	MIX.initialize(false)
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash)
	print("Audio tuning passed: isolated edits, A/B, selection, persistence, reverb DSP, ambience looping/preview/respawn/cleanup, room routing and pause ownership.")
	quit()

func _validate_ambience_preview(game: Node, panel: CanvasLayer) -> void:
	var ambience: AudioStreamPlayer = game.cave_ambience
	await create_timer(0.5).timeout
	assert(ambience.stream.stereo and ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(is_equal_approx(ambience.stream.get_length(), 29.99875))
	assert(ambience.bus == &"Ambience")
	assert(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(ambience.bus)) == 0)
	await create_timer(0.5).timeout
	assert(ambience.playing and not ambience.stream_paused, "Cave listening must work while gameplay is paused.")
	var volume: HSlider = panel._body.find_child("AmbienceVolume", true, false)
	volume.value = -16.0
	await process_frame
	await process_frame
	assert(is_equal_approx(ambience.volume_db, -16.0))
	assert(MIX.saved_ambience.volume_db == -9.0)
	panel._toggle_comparison()
	await process_frame
	await process_frame
	assert(is_equal_approx(ambience.volume_db, -9.0))
	assert(not (panel._body.find_child("AmbienceVolume", true, false) as HSlider).editable)
	panel._toggle_comparison()
	# Cross the real recording boundary without waiting a full thirty seconds.
	ambience.seek(ambience.stream.get_length() - 0.1)
	await create_timer(0.3).timeout
	assert(ambience.playing and ambience.get_playback_position() < 1.0, "The stereo recording must wrap without stopping.")
	var position := ambience.get_playback_position()
	panel._preview_contact()
	assert(panel._voices[0].playing and ambience.playing)
	panel._stop_preview()
	panel._kind_picker.item_selected.emit(1)
	await create_timer(0.1).timeout
	assert(ambience.get_playback_position() > position, "Changing/stopping footstep previews must not restart ambience.")
	var enabled: CheckBox = panel._body.find_child("CaveAmbienceEnabled", true, false)
	enabled.button_pressed = false
	await create_timer(0.5).timeout
	assert(not ambience.playing and not MIX.working_ambience.enabled)
	assert(MIX.saved_ambience.enabled)
	MIX.revert()
	panel._kind_picker.item_selected.emit(0)
	await create_timer(0.5).timeout
	assert(ambience.playing and is_equal_approx(ambience.volume_db, -9.0))
	panel._space.item_selected.emit(0)
	await create_timer(0.5).timeout
	assert(not ambience.playing, "Outdoor previews must not keep cave ambience.")
	panel._space.item_selected.emit(1)

func _validate_reverb_audio() -> void:
	# Test actual processed samples as well as property wiring. Capture stays
	# after the reverb while its delay buffers are replaced between previews.
	var bus_name := MIX.preview_bus(&"cave")
	var index := AudioServer.get_bus_index(bus_name)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(index, capture)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 48000
	var data := PackedByteArray()
	data.resize(960)
	for frame in 480:
		data.encode_s16(frame * 2, 6000 if frame % 8 < 4 else -6000)
	stream.data = data
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.bus = bus_name
	root.add_child(voice)
	MIX.working_reverb.enabled = true
	MIX.working_reverb.amount = 0.4
	MIX.refresh_reverb_buses()
	MIX.clear_reverb_tail(bus_name)
	capture.clear_buffer()
	voice.play()
	await create_timer(0.55).timeout
	var wet := capture.get_buffer(capture.get_frames_available())
	assert(wet.size() > 1000, "DSP capture needs an active audio mixer.")
	assert(_late_energy(wet) > 0.00000001, "An enabled reverb must produce a tail after a short contact.")
	MIX.working_reverb.enabled = false
	MIX.clear_reverb_tail(bus_name)
	capture.clear_buffer()
	voice.play()
	await create_timer(0.55).timeout
	var dry := capture.get_buffer(capture.get_frames_available())
	assert(_peak(dry) > 0.01, "Bypassing reverb must retain the original contact.")
	assert(_late_energy(dry) < 0.0000000001, "Disabled reverb must be dry.")
	MIX.working_reverb.enabled = true
	MIX.clear_reverb_tail(bus_name)
	capture.clear_buffer()
	voice.play()
	await create_timer(0.1).timeout
	voice.stop()
	MIX.clear_reverb_tail(bus_name)
	# Drain in-flight mixer/output blocks before measuring the cleared tail.
	await create_timer(0.1).timeout
	capture.clear_buffer()
	await create_timer(0.2).timeout
	assert(_peak(capture.get_buffer(capture.get_frames_available())) < 0.000001, "Stopped previews must clear their reverb buffers.")
	voice.free()
	AudioServer.remove_bus_effect(index, 1)
	MIX.revert()

func _peak(frames: PackedVector2Array) -> float:
	var peak := 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak

func _late_energy(frames: PackedVector2Array) -> float:
	var first := -1
	for index in frames.size():
		if frames[index].length_squared() > 0.000001:
			first = index
			break
	assert(first >= 0, "The original test contact must be present.")
	var energy := 0.0
	for index in range(first + int(AudioServer.get_mix_rate() * 0.04), frames.size()):
		energy += frames[index].length_squared()
	return energy / maxf(frames.size(), 1.0)
