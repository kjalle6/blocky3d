extends SceneTree
## Regression: closing the designer must not restore the previous session's
## hidden aiming cursor after that session and its crosshair have gone away.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0, true).timeout.connect(func() -> void: quit(1))
	preload("res://scripts/developer/level_layout_store.gd").clear_recovery("sandbox")
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	await process_frame
	var definition := load("res://resources/dev/level_designer_sandbox.tres") as LevelDefinition
	var designer: CanvasLayer = app.level_designer
	var hud: WeaponStatusHUD = app.weapon_status_hud
	for to_menu in [false, true]:
		app.load_developer_level(definition)
		await _aim_with_mouse(app)
		designer.open_panel()
		assert(designer.is_editing() and paused)
		_assert_pointer_visible(hud, "Opening the designer")
		designer.request_close(to_menu)
		await process_frame
		_assert_pointer_visible(hud, "Closing the designer")
		assert(not designer.is_active() and not paused)

	app.load_developer_level(definition)
	await _aim_with_mouse(app)
	designer.open_panel()
	designer.test_layout()
	await process_frame
	_assert_pointer_visible(hud, "Starting a draft with the knife")
	await _aim_with_mouse(app)
	designer.return_to_editing()
	_assert_pointer_visible(hud, "Returning from a handgun draft")
	designer.request_close()
	await process_frame
	_assert_pointer_visible(hud, "Closing after a draft")

	# Pausing a fresh aiming session must still release the native cursor, and
	# resuming must restore the crosshair before hiding it again.
	await _aim_with_mouse(app)
	paused = true
	_assert_pointer_visible(hud, "Pausing handgun aim")
	paused = false
	await process_frame
	hud._process(0.0)
	assert(hud._crosshair_visible and hud._cursor_hidden)
	designer.open_panel()
	app.remove_child(designer)
	designer.free()
	_assert_pointer_visible(hud, "Removing an active designer")
	app.free()
	print("Cursor lifecycle passed: designer exit to play/menu, draft round trip, pause/resume and teardown.")
	quit(0)

func _aim_with_mouse(app: Node) -> void:
	var level: LevelSession3D = app.current_level
	if not level.owns_weapon(PlayerWeapon.HANDGUN):
		assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.request_weapon(PlayerWeapon.HANDGUN))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(960, 450)
	motion.global_position = motion.position
	motion.relative = Vector2(10, 0)
	root.push_input(motion)
	for frame in 3: await physics_frame
	await process_frame
	var hud: WeaponStatusHUD = app.weapon_status_hud
	hud._process(0.0)
	assert(hud._crosshair_visible and hud._cursor_hidden, "Aiming must own a visible crosshair before opening the designer.")
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN)

func _assert_pointer_visible(hud: WeaponStatusHUD, context: String) -> void:
	assert(not hud._crosshair_visible and not hud._cursor_hidden, context + " must release the aiming crosshair.")
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, context + " must leave a usable mouse pointer.")
