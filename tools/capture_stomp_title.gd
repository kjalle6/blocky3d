extends SceneTree
## Actual boss entrance/title-card video and mixer output. Run with -Visual.
## Runtime-only fixture: uses the Level 3 boss entry with progression disabled.
const OUTPUT := "res://build/stomp_title_capture"
const SIZE := Vector2i(1920, 1080)
var _started_usec := 0
var _markers: Dictionary = {}
var _audio := AudioEffectCapture.new()

func _init() -> void:
	call_deferred("_run")
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("S.T.O.M.P. title capture timed out.")
		quit(1))

func _seconds() -> float:
	return float(Time.get_ticks_usec() - _started_usec) / 1000000.0

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use the runner's -Visual mode.")
	Engine.max_fps = 30
	root.content_scale_size = SIZE
	root.size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var output := ProjectSettings.globalize_path(OUTPUT)
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_developer_level(load("res://resources/dev/green_zone_finale_wip.tres"), &"boss_encounter")
	var level: LevelSession3D = game.current_level
	assert(level != null and level.scene_file_path.ends_with("green_zone_finale_boss_pit.tscn"))
	var encounter: Node = level.get_node("BossEncounter")
	var boss: Node = level.get_node("GreenZoneBoss")
	paused = true
	for warmup in 5:
		await process_frame
	_audio.buffer_length = 30.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, _audio)
	var raw := FileAccess.open(output.path_join("frames.rgb"), FileAccess.WRITE)
	assert(raw != null)
	var timestamps: Array[float] = []
	encounter.reveal_started.connect(func() -> void: _markers["reveal_started"] = _seconds())
	encounter.intro_finished.connect(func() -> void: _markers["intro_finished"] = _seconds())
	_audio.clear_buffer()
	_started_usec = Time.get_ticks_usec()
	paused = false
	while _seconds() < 18.0:
		await process_frame
		await RenderingServer.frame_post_draw
		var stamp := _seconds()
		var capture := root.get_texture().get_image()
		assert(capture.get_size() == SIZE)
		capture.convert(Image.FORMAT_RGB8)
		raw.store_buffer(capture.get_data())
		assert(raw.get_error() == OK)
		timestamps.append(stamp)
		if timestamps.size() % 90 == 0:
			print("STOMP_CAPTURE frames=%d time=%.2f" % [timestamps.size(), stamp])
		if _markers.has("intro_finished") and stamp > float(_markers["intro_finished"]) + 2.0:
			break
	var end_seconds := _seconds()
	raw.close()
	var samples := _audio.get_buffer(_audio.get_frames_available())
	var discarded := _audio.get_discarded_frames()
	AudioServer.remove_bus_effect(0, effect_index)
	assert(discarded == 0 and samples.size() > 1000)
	assert(_markers.has("reveal_started") and _markers.has("intro_finished"))
	assert(not encounter.reveal_active() and not encounter.in_cutscene())
	assert(boss.missiles_fired > 0, "Record through the first salvo.")
	var data := PackedByteArray()
	data.resize(samples.size() * 4)
	var peak := 0.0
	for index in samples.size():
		var sample := samples[index]
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		data.encode_s16(index * 4, roundi(clampf(sample.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(index * 4 + 2, roundi(clampf(sample.y, -1.0, 1.0) * 32767.0))
	assert(peak > 0.001, "The native mixer must contain the encounter sounds.")
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = roundi(AudioServer.get_mix_rate())
	recording.data = data
	assert(recording.save_to_wav(output.path_join("mixer.wav")) == OK)
	var report := {"width": SIZE.x, "height": SIZE.y, "raw_frames": timestamps.size(),
		"timestamps_seconds": timestamps, "end_seconds": end_seconds, "markers": _markers,
		"audio_seconds": recording.get_length(), "audio_peak": peak, "audio_discarded_frames": discarded,
		"pixel_format": "rgb24", "raw_file": "frames.rgb", "audio_file": "mixer.wav",
		"scene": level.scene_file_path, "entry_id": "boss_encounter",
		"missiles_fired": boss.missiles_fired,
		"method": "Real-time native rendered frames with wall-clock timestamps and live master-bus audio. No title-card timing or encounter changes; no skip input."}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("STOMP_TITLE_CAPTURE PASS: reveal, full hold, return to gameplay and opening salvo; %d frames, %.3f seconds, audio %.3f seconds." % [timestamps.size(), end_seconds, recording.get_length()])
	game.free()
	quit(0)
