extends SceneTree
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const MENU := preload("res://scripts/developer/level_designer_context_menu.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0, true).timeout.connect(func() -> void: quit(1))
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	await process_frame
	var definition := load("res://resources/dev/level_designer_sandbox.tres") as LevelDefinition
	app.load_developer_level(definition)
	await process_frame
	var designer: CanvasLayer = app.level_designer
	app.audio_tuning_panel.open_panel()
	assert(app.audio_tuning_panel.is_open)
	designer.open_panel()
	assert(designer.is_editing() and paused)
	assert(not app.audio_tuning_panel.is_open)
	assert(app.current_level.get_meta("layout_preview", false))
	app.audio_tuning_panel.open_panel()
	assert(not app.audio_tuning_panel.is_open)
	assert(designer.document.working.is_empty())
	# Create a platform above the foundation; then round-trip through undo/test.
	designer.add_platform(Rect2(Vector2(17.92, 1.28), Vector2(5.12, 1.28)))
	assert(designer.document.working.size() == 1)
	var id: String = designer.selection[0]
	var original: Dictionary = designer.document.working.duplicate(true)
	designer.update_values({"width": 7.68})
	assert(designer.document.working[id].values.width == 7.68)
	designer.undo()
	assert(designer.document.working == original)
	designer.redo()
	designer.undo()
	var before_test: Dictionary = designer.document.working.duplicate(true)
	designer.test_layout()
	assert(not paused and designer.mode == designer.Mode.TESTING)
	assert(not app.current_level.get_meta("layout_preview", false))
	for frame in 3: await physics_frame
	assert(app.current_level.player.test_move(Transform3D(Basis.IDENTITY, Vector3(20, 3.3, 0)), Vector3.DOWN))
	designer.return_to_editing()
	assert(paused and designer.document.working == before_test)
	designer.undo()
	assert(designer.document.working.is_empty())
	designer.redo()
	assert(designer.document.working.size() == 1)
	designer.duplicate_selected()
	# Undo clears a removed selection, so explicitly reselect before duplicating.
	designer.choose(id)
	designer.duplicate_selected()
	assert(designer.document.working.size() == 2)
	assert(designer.selection[0] != id)
	var duplicate_id: String = designer.selection[0]
	designer.choose(id, true)
	var group_before: Dictionary = designer.document.working.duplicate(true)
	var history_count: int = designer.history.get_history_count()
	designer.nudge(Vector2(1, 1))
	assert(designer.history.get_history_count() == history_count + 1)
	for selected in [id, duplicate_id]:
		assert(is_equal_approx(designer.document.working[selected].values.x - group_before[selected].values.x, 0.64))
	designer.undo()
	assert(designer.document.working == group_before)
	designer.choose(duplicate_id)
	designer.remove_selected()
	assert(designer.document.working.size() == 1)
	# Input projection and gesture cancellation at both supported viewport sizes.
	designer.choose(id)
	for viewport in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport
		root.content_scale_size = viewport
		designer.frame_selection()
		await process_frame
		var record: Dictionary = designer.document.working[id]
		var center := OBJECTS.bounds(record).get_center()
		var screen: Vector2 = designer.canvas.screen_at(center)
		assert(designer.canvas.world_at(screen).distance_to(center) < 0.0001)
		assert(id in designer.canvas.hit_objects(screen))
		var baseline: Dictionary = designer.document.working.duplicate(true)
		designer.canvas._press(screen, false)
		designer.canvas._motion(screen + Vector2(60, -40))
		designer.canvas.cancel_gesture()
		assert(designer.document.working == baseline and designer.history.has_undo())
		# Route a real mouse click through the viewport, not a direct choose call.
		designer.choose("")
		var mouse := InputEventMouseButton.new()
		mouse.position = screen
		mouse.global_position = screen
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		root.push_input(mouse)
		mouse = mouse.duplicate()
		mouse.pressed = false
		root.push_input(mouse)
		assert(id in designer.selection, "The viewport click must reach the object under the cursor.")
		# A real right-click targets the pointed object, with the same coordinates.
		_mouse_click(screen, MOUSE_BUTTON_RIGHT)
		assert(designer.context_menu.visible and designer.selection == [id])
		assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.REVERT)), "New unsaved objects are removed or undone, not reverted to a nonexistent save.")
		designer.context_menu.hide()
		await process_frame
		# Right-click while dragging only cancels; it must not move or open a menu.
		designer.canvas._press(screen, false)
		designer.canvas._motion(screen + Vector2(45, 20))
		_mouse_click(screen + Vector2(45, 20), MOUSE_BUTTON_RIGHT)
		assert(not designer.context_menu.visible and designer.canvas.gesture.is_empty())
		assert(designer.document.working == baseline)
	# Close must offer a real cancel path without destroying draft/history.
	designer.request_close()
	assert(designer.dialog_open())
	designer._dialog.canceled.emit()
	assert(designer.is_editing() and designer.document.has_changes())
	designer.revert_layout()
	assert(not designer.document.has_changes())
	designer.request_close()
	assert(not designer.is_active() and not paused)
	# Audit the populated production section, including guarded script callbacks.
	app.load_developer_level(load("res://resources/dev/green_zone_finale_wip.tres"))
	designer.open_panel()
	assert(designer.is_editing())
	assert(designer.document.working.size() >= 7, "Keep authored objects and user-added layout objects.")
	var level: LevelSession3D = app.current_level
	var initial_position: Vector3 = level.get_node("OpeningPatrol").position
	for frame in 4: await process_frame
	assert(level.get_node("OpeningPatrol").position == initial_position)
	assert(not level.get_node("ShooterAreaTransition").body_entered.is_connected(level.get_node("ShooterAreaTransition")._on_body_entered))
	assert(not level.get_node("Hazards/FinalLandingSpikes").monitoring)
	var preview_player := level.player
	preview_player.ground_jump_started.emit()
	preview_player.landed.emit(12.0)
	for node in level.find_children("*", "AudioStreamPlayer", true, false): assert(not node.playing)
	assert(not preview_player.is_dead())
	assert(designer.locked.size() > 5)
	designer.choose("outdoors_dash_patrol")
	designer.update_values({"x": 51.2, "left": 1.28, "right": 2.56, "facing_right": false})
	var authored_records: Dictionary = designer.document.working.duplicate(true)
	designer.test_layout()
	var actor: StompableEnemy3D = app.current_level.get_node("DashLandingPatrol")
	actor.receive_melee_hit(Vector3.ZERO, CombatHit.new(actor.health.current, &"fixture"))
	assert(actor.is_defeated())
	designer.return_to_editing()
	assert(designer.document.working == authored_records)
	assert(not app.current_level.get_node("DashLandingPatrol").is_defeated())
	assert(is_equal_approx(app.current_level.get_node("DashLandingPatrol").position.x, 51.2))
	# Revert restores only the clicked saved object; other edits and undo survive.
	designer.choose("outdoors_opening_patrol")
	designer.nudge(Vector2.RIGHT)
	var other_edit: Dictionary = designer.document.working.outdoors_opening_patrol.duplicate(true)
	designer.choose("outdoors_dash_patrol")
	designer.context_menu.open_at(Vector2(400, 300))
	assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.DUPLICATE)))
	assert(designer.context_menu.is_item_disabled(designer.context_menu.get_item_index(MENU.Action.REMOVE)))
	designer.context_menu.id_pressed.emit(MENU.Action.REVERT)
	assert(designer.document.working.outdoors_dash_patrol == designer.document.saved.outdoors_dash_patrol)
	assert(designer.document.working.outdoors_opening_patrol == other_edit)
	designer.undo()
	assert(designer.document.working.outdoors_dash_patrol == authored_records.outdoors_dash_patrol)
	designer.revert_layout()
	designer.request_close()
	app.free()
	print("Level designer passed: preview isolation, palette, undo/redo, fresh testing, locks and audio ownership.")
	quit(0)

func _mouse_click(point: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
