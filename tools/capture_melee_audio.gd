extends SceneTree
## Actual mixer output from knife misses, knife contacts and a falling stomp.
const AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const OUTPUT := "res://build/previews/melee_audio"
var _capture := AudioEffectCapture.new()
var _report: Dictionary = {}


func _init() -> void:
	call_deferred("_run")
	create_timer(25.0).timeout.connect(func() -> void:
		push_error("Melee audio capture timed out.")
		quit(1))


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use -Visual for this capture.")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	var level := AREA.load_into(game)
	var player := level.player
	level.get_node("ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy").set_engagement_enabled(false)
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(12, 0.7, 0)))
	player._facing_sign = 1.0
	level.camera.snap_to_target()
	for tick in 12:
		await physics_frame
	_capture.buffer_length = 6.0
	AudioServer.add_bus_effect(0, _capture)
	_capture.clear_buffer()
	await _attack()
	_save_audio("knife_miss")

	var target := load("res://scenes/enemies/pixel_skater_enemy.tscn").instantiate() as StompableEnemy3D
	target.position = player.position + Vector3(1.05, 0, 0)
	level.add_child(target)
	target.set_physics_process(false)
	level.combat_feedback.bind_enemy(target)
	for tick in 3:
		await physics_frame
	_capture.clear_buffer()
	await _attack()
	assert(target.is_defeated())
	_save_audio("knife_hit")
	target.free()

	target = load("res://scenes/enemies/pixel_skater_enemy.tscn").instantiate()
	target.position = player.position
	level.add_child(target)
	target.set_physics_process(false)
	level.combat_feedback.bind_enemy(target)
	player.reset_at(Transform3D(Basis.IDENTITY, target.position + Vector3(0, 3.5, 0)))
	_capture.clear_buffer()
	for tick in 90:
		await physics_frame
		if target.is_defeated(): break
	assert(target.is_defeated())
	# Stop the follow-on landing so this sample contains only the stomp cue.
	player.set_physics_process(false)
	await create_timer(0.8).timeout
	_save_audio("stomp")
	target.free()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	game.audio_tuning_panel.open_panel()
	for event_id in ["combat/knife_swing", "combat/knife_hit", "combat/stomp"]:
		game.audio_tuning_panel.select_event(event_id)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUTPUT + "/" + event_id.get_slice("/", 1) + ".png") == OK)
	game.audio_tuning_panel.close_panel()
	var report := FileAccess.open(OUTPUT + "/mixer_levels.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(_report, "\t"))
	print("Captured real melee/stomp output and three connected tuning pages: ", _report)
	game.free()
	quit(0)


func _attack() -> void:
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await create_timer(0.9).timeout


func _save_audio(name: String) -> void:
	var frames := _capture.get_buffer(_capture.get_frames_available())
	assert(frames.size() > 1000, "The real audio mixer must supply captured frames.")
	var peak := 0.0
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for index in frames.size():
		var frame := frames[index]
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		data.encode_s16(index * 4, roundi(clampf(frame.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(index * 4 + 2, roundi(clampf(frame.y, -1.0, 1.0) * 32767.0))
	assert(peak > 0.001 and peak < 0.98, "Live cues must reach the output with headroom.")
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = roundi(AudioServer.get_mix_rate())
	recording.data = data
	assert(recording.save_to_wav(OUTPUT + "/" + name + ".wav") == OK)
	_report[name] = {"duration": recording.get_length(), "peak_db": linear_to_db(peak)}
