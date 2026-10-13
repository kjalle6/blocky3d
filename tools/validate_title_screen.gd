extends SceneTree
## Regression: title-opening input cannot start a campaign; modals restore focus.
func _init() -> void:
	call_deferred("_run")
	create_timer(25.0, true).timeout.connect(func() -> void: quit(1))

func _key(pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	event.echo = echo
	root.push_input(event)

func _run() -> void:
	var store := root.get_node("GameProgression") as ProgressionStore
	store.save_path = "user://title_validation_" + str(Time.get_ticks_usec()) + "/progress.json"
	store.load_progress()
	var app := preload("res://scenes/app/game_root.tscn").instantiate()
	app.persist_progression = false
	root.add_child(app)
	await process_frame
	var title: CanvasLayer = app.title_screen
	assert(title.visible and not app.level_select.visible and app.current_level == null)
	assert(title.buttons[0].disabled, "A new profile must not offer Continue.")
	assert(not FileAccess.file_exists(store.save_path), "Viewing the title cannot create progress.")
	assert(title.logo.effects_enabled, "Main boot should use the effects entrance.")
	# Exercise all transient draw paths, including rewinding after the stamp.
	# This remains render-agnostic so the suite can also run headless; native
	# captures separately check appearance and the identical settled frame.
	title.set_process(false)
	for seconds in [0.5, 0.68, 1.85, 1.98, 2.11, 2.24, 3.59, 3.68, 4.19, 0.0]:
		title.elapsed = seconds
		title._update_composition()
		await process_frame
	title.set_process(true)
	# At the old 1.8-second end the longer entrance is still presenting the logo.
	title.present(true)
	title._process(1.8)
	assert(title.phase == title.Phase.ENTRANCE and not title.prompt.visible)
	title._process(3.0)
	assert(title.phase == title.Phase.READY and title.prompt.visible)
	# A replay must clear an active idle-sign fault before replaying the entrance.
	title.logo.set_neon_time(2.65)
	assert(title.logo._neon_level < 0.2)
	title.present(true)
	assert(is_zero_approx(title.logo._neon_time) and is_equal_approx(title.logo._neon_level, 1.0))
	# First press skips the entrance. Holding/echoing it cannot advance again.
	_key(true)
	assert(title.phase == title.Phase.READY)
	_key(true, true)
	assert(title.phase == title.Phase.READY)
	_key(false)
	_key(true)
	assert(title.phase == title.Phase.TRANSITION)
	title._process(1.0)
	assert(title.phase == title.Phase.TRANSITION, "Wait for release even after the move finishes.")
	assert(app.current_level == null and app.campaign_menu.page.is_empty())
	_key(false)
	title._process(0.01)
	assert(title.phase == title.Phase.MENU)
	assert(root.gui_get_focus_owner() == title.buttons[1])
	assert(app.current_level == null and app.campaign_menu.page.is_empty())
	# A fresh Enter deliberately opens confirmation; cancellation restores focus.
	_key(true)
	_key(false)
	assert(app.campaign_menu.page == "confirm" and paused)
	title._process(0.01)
	app.campaign_menu.close()
	title._process(0.01)
	assert(not paused and root.gui_get_focus_owner() == title.buttons[1])
	assert(not FileAccess.file_exists(store.save_path), "Cancel cannot write progress.")
	# A held mouse click on the future New Campaign button cannot activate it.
	title.present(true)
	title._process(5.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(960, 555)
	click.pressed = true
	root.push_input(click)
	title._process(1.0)
	assert(title.phase == title.Phase.TRANSITION)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	title._process(0.01)
	assert(title.phase == title.Phase.MENU and app.campaign_menu.page.is_empty())
	# Controller A uses the same release gate.
	title.present(true)
	title._process(5.0)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	root.push_input(pad)
	title._process(1.0)
	assert(title.phase == title.Phase.TRANSITION)
	pad = pad.duplicate()
	pad.pressed = false
	root.push_input(pad)
	title._process(0.01)
	assert(title.phase == title.Phase.MENU and app.campaign_menu.page.is_empty())
	title._activate(2)
	assert(app.campaign_menu.page == "load")
	title._process(0.01)
	app.campaign_menu._return()
	title._process(0.01)
	assert(not paused and title.visible)
	title._activate(4)
	assert(app.campaign_menu.page == "confirm")
	title._process(0.01)
	app.campaign_menu._return()
	title._process(0.01)
	assert(not paused and title.visible and app.campaign_menu.page.is_empty())
	# Developer selector remains reachable; returning skips the logo replay.
	app.show_level_select()
	assert(app.level_select.visible and not title.visible and not title.surface.visible)
	var city_time: float = title.background.elapsed
	var sign_time: float = title.logo._neon_time
	await process_frame
	await process_frame
	assert(is_equal_approx(city_time, title.background.elapsed), "Hidden city must stop animating.")
	assert(is_equal_approx(sign_time, title.logo._neon_time), "Hidden title must stop its idle sign effects.")
	app.show_main_menu()
	assert(title.phase == title.Phase.MENU and not app.level_select.visible)
	# Real campaign entry/return uses the same application lifecycle. This runner
	# has an isolated profile; never exercise this write in the user's playtest.
	assert(app.start_campaign(), store.last_error)
	assert(app.current_level != null and not title.visible)
	app.campaign_menu._main_menu()
	assert(app.current_level == null and title.visible and title.phase == title.Phase.MENU)
	app.queue_free()
	await process_frame
	# Player-facing preview uses the same application with developer access off.
	var player_app := preload("res://scenes/dev/main_menu_release_preview.tscn").instantiate()
	player_app.persist_progression = false
	root.add_child(player_app)
	await process_frame
	player_app.show_main_menu()
	var player_title: CanvasLayer = player_app.title_screen
	assert(not player_app.developer_tools_enabled)
	assert(not player_title.development.visible and player_title.development.disabled)
	assert(player_title.development.focus_mode == Control.FOCUS_NONE)
	for button in player_title.buttons:
		if not button.disabled:
			assert(button.get_node(button.focus_neighbor_bottom) != player_title.development)
	player_app.show_level_select()
	assert(player_title.visible and not player_app.level_select.visible, "Disabled selector must remain inaccessible.")
	player_app._campaign_mode = true
	player_app.load_developer_room()
	player_app.load_developer_level(player_app.developer_room_definition)
	assert(player_app.current_level == null and player_app._campaign_mode, "Developer entry must be a no-op outside development.")
	player_app.queue_free()
	await process_frame
	var clean_app := preload("res://scenes/dev/main_menu_clean_preview.tscn").instantiate()
	clean_app.persist_progression = false
	root.add_child(clean_app)
	await process_frame
	assert(not clean_app.title_screen.logo.effects_enabled and not clean_app.developer_tools_enabled)
	clean_app.title_screen._process(5.0)
	assert(clean_app.title_screen.prompt.visible and not clean_app.title_screen.development.visible)
	await process_frame
	await process_frame
	assert(is_zero_approx(clean_app.title_screen.logo._neon_time), "Clean comparison must not run idle interference.")
	clean_app.queue_free()
	await process_frame
	print("Title screen PASS: effects and clean previews, release-gated input, modal focus, campaign lifecycle and developer access guards.")
	quit(0)
