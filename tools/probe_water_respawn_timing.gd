extends SceneTree

var impact_msec := 0
var reset_msec := 0

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
	var splash = level.get_node("WaterDeathSplash")
	level.player.death_started.connect(func(_kind, _position): impact_msec = Time.get_ticks_msec())
	level.run_reset.connect(func(): reset_msec = Time.get_ticks_msec())
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.2, 0)))
	for frame in 300:
		await physics_frame
		if reset_msec > 0:
			break
	assert(impact_msec > 0 and reset_msec > 0)
	var elapsed := float(reset_msec - impact_msec) / 1000.0
	print("Measured WATER IMPACT -> RESPAWN: %.3f seconds" % elapsed)
	print("Configured water delay: ", level.water_respawn_delay)
	print("Audio still playing at respawn: ", splash.splash_audio.playing)
	print("Clip duration: %.3f; skipped lead-in: %.3f; full playback duration: %.3f" % [
		splash.splash_audio.stream.get_length(), splash.audio_start_seconds,
		splash.splash_audio.stream.get_length() - splash.audio_start_seconds])
	assert(elapsed >= 1.65 and elapsed < 1.85)
	assert(splash.splash_audio.playing, "Respawn must occur before the clip ends.")
	quit()
