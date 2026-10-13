extends SceneTree
## Opt-in full title/menu frames; isolated saves via run_godot_tool.ps1 -Visual.
const OUTPUT_SIZE := Vector2i(1920, 1080)
const FRAME_RATE := 30.0
const FRAME_COUNT := 630
const PRESS_FRAME := 198 # 6.6 seconds: complete entrance and readable prompt hold.
const RELEASE_FRAME := 201
const OUTPUT_DIR := "res://build/protocol_title_capture"

func _init() -> void:
	call_deferred("_run")

func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	root.push_input(event)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Title capture requires the runner's -Visual mode.")
		quit(1)
		return
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var app := preload("res://scenes/dev/main_menu_release_preview.tscn").instantiate()
	app.persist_progression = false
	root.add_child(app)
	var title: CanvasLayer = app.title_screen
	title.set_process(false)
	title.logo.set_process(false)
	title.background.set_process(false)
	for warmup in 4:
		await process_frame
	title.present(true)
	title.background.set_preview_time(0.0)
	var output := ProjectSettings.globalize_path(OUTPUT_DIR)
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var raw := FileAccess.open(output.path_join("frames.rgb"), FileAccess.WRITE)
	assert(raw != null)
	var markers: Array[Dictionary] = []
	for frame in FRAME_COUNT:
		var seconds := float(frame) / FRAME_RATE
		if frame == PRESS_FRAME:
			assert(title.phase == title.Phase.READY and title.prompt.visible)
			_key(true)
		elif frame == RELEASE_FRAME:
			_key(false)
		if frame > 0:
			title._process(1.0 / FRAME_RATE)
		title.background.set_preview_time(seconds)
		title.logo.set_neon_time(maxf(0.0, seconds - 4.8))
		assert(app.current_level == null and app.campaign_menu.page.is_empty())
		assert(not title.development.visible)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		assert(capture.get_size() == OUTPUT_SIZE)
		capture.convert(Image.FORMAT_RGB8)
		raw.store_buffer(capture.get_data())
		assert(raw.get_error() == OK)
		if frame % 90 == 0:
			print("PROTOCOL_CAPTURE %d/%d" % [frame, FRAME_COUNT])
		if frame in [0, 150, PRESS_FRAME, RELEASE_FRAME, 210, FRAME_COUNT - 1]:
			markers.append({"frame": frame, "seconds": seconds, "phase": title.phase,
				"prompt": title.prompt.visible, "menu": title.menu.visible,
				"menu_alpha": title.menu.modulate.a, "gate_active": title._gate_event != null})
	assert(title.phase == title.Phase.MENU and title._gate_event == null)
	raw.close()
	var report := {"width": OUTPUT_SIZE.x, "height": OUTPUT_SIZE.y, "fps": FRAME_RATE,
		"frames": FRAME_COUNT, "duration_seconds": FRAME_COUNT / FRAME_RATE,
		"press_seconds": PRESS_FRAME / FRAME_RATE, "release_seconds": RELEASE_FRAME / FRAME_RATE,
		"scene": "res://scenes/dev/main_menu_release_preview.tscn", "markers": markers,
		"audio": "Silent presentation capture; no audio rendered.",
		"pixel_format": "rgb24", "raw_file": "frames.rgb",
		"method": "Native lossless RGB frames on fixed 30 fps timeline; real Enter press/release opens menu."}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("PROTOCOL_TITLE_CAPTURE PASS: %d native frames, real press/release, menu reached, no campaign activation." % FRAME_COUNT)
	quit(0)
