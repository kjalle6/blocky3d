extends SceneTree
## Record the real output mixer during shots/cover hits, plus the four live
## tuning pages. These are listening samples, not a claim of audible approval.
const AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const OUTPUT := "res://build/previews/combat_audio"

var _capture := AudioEffectCapture.new()
var _report: Dictionary = {}


func _init() -> void:
	call_deferred("_run")
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Combat audio capture timed out.")
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
	var shooter := level.get_node("ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy") as HandgunEnemy3D
	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(12.0, 0.7, 0.0)))
	player.player_handgun._mouse_requested = false
	player._facing_sign = 1.0
	level.camera.snap_to_target()
	for tick in 12:
		await physics_frame
	_capture.buffer_length = 6.0
	AudioServer.add_bus_effect(0, _capture)
	_capture.clear_buffer()
	for shot in 3:
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		Input.action_release("attack")
		await create_timer(0.30).timeout
	await create_timer(0.9).timeout
	_save_audio("player_shots_and_cover")

	_capture.clear_buffer()
	shooter.set_engagement_enabled(true)
	shooter._begin_volley()
	while shooter.completed_volleys_total() == 0:
		await physics_frame
	shooter.set_physics_process(false)
	await create_timer(2.0).timeout
	_save_audio("enemy_pair_volley_and_cover")
	shooter.set_engagement_enabled(false)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	game.audio_tuning_panel.open_panel()
	for event_id in ["combat/player_gunshot", "combat/enemy_gunshot", "combat/bullet_scenery", "combat/bullet_character"]:
		game.audio_tuning_panel.select_event(event_id)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUTPUT + "/" + event_id.get_slice("/", 1) + ".png") == OK)
	game.audio_tuning_panel.close_panel()
	var report := FileAccess.open(OUTPUT + "/mixer_levels.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(_report, "\t"))
	print("Captured player/enemy gunfire with real impacts and all four connected tuning pages: ", _report)
	game.free()
	quit(0)


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
	assert(peak > 0.001, "A playing 3D voice must actually reach the output mixer.")
	assert(peak < 0.98, "The starting combat mix must leave output headroom.")
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = roundi(AudioServer.get_mix_rate())
	recording.data = data
	assert(recording.save_to_wav(OUTPUT + "/" + name + ".wav") == OK)
	_report[name] = {"duration": recording.get_length(), "peak_db": linear_to_db(peak)}
