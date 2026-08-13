extends SceneTree
## Runtime contract for the F10 world-space measurement grid.

const LEVEL_ID: StringName = &"arrival_shoreline"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	if packed_scene == null:
		_fail("The application root could not be loaded.")
		return
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_level(LEVEL_ID)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	if level == null:
		_fail("Arrival / Shoreline did not instantiate.")
		return
	var label := game_root.get_node("Interface/DeveloperMeasurementLabel") as Label
	var cursor_label := (
		game_root.get_node("Interface/DeveloperCursorCoordinateLabel") as Label
	)
	var menu_hint := game_root.get_node("Interface/MenuHint") as Label
	_send_key(game_root, KEY_F10)
	await process_frame
	game_root._update_developer_cursor_coordinate_at(
		root.get_visible_rect().size * 0.5
	)
	var grid := level.developer_measurement_grid()
	if grid == null or not level.is_developer_measurement_grid_enabled():
		_fail("F10 did not create and enable the world measurement grid.")
		return
	if not label.visible or "GRID 1.28 m / 0.64 m" not in label.text:
		_fail("The grid lacks its live measurement readout.")
		return
	if not cursor_label.visible or "X " not in cursor_label.text or "Y " not in cursor_label.text:
		_fail("The grid lacks its mouse-adjacent world-coordinate readout.")
		return
	var viewport_center := root.get_visible_rect().size * 0.5
	var center_world: Vector2 = game_root.developer_world_position_at_screen_position(
		viewport_center
	)
	var camera_center := Vector2(level.camera.global_position.x, level.camera.global_position.y)
	if not center_world.is_equal_approx(camera_center):
		_fail("The cursor probe does not intersect the gameplay plane at camera center.")
		return
	if not is_equal_approx(grid.major_step(), PixelPlatform3D.TILE_WORLD_SIZE):
		_fail("The grid's major cells do not match one terrain tile.")
		return
	if not is_equal_approx(grid.minor_step(), PixelPlatform3D.TILE_WORLD_SIZE * 0.5):
		_fail("The grid's minor cells do not match half a terrain tile.")
		return
	var initial_bounds := grid.displayed_bounds()
	if not initial_bounds.has_point(Vector2.ZERO):
		_fail("The world-locked grid does not include the origin near the opening.")
		return
	if "F10: HIDE GRID" not in menu_hint.text:
		_fail("The compact HUD does not explain how to hide the active grid.")
		return
	_send_key(game_root, KEY_F11)
	await process_frame
	if not level.is_developer_inspection_enabled():
		_fail("The measurement grid could not remain active with F11 inspection.")
		return
	if (
		menu_hint.text
		!= "F7: HITBOXES    F10: HIDE GRID    F11: EXIT INSPECTION    ESC: SELECT"
	):
		_fail("The compact HUD did not report both active development tools.")
		return
	_send_key(game_root, KEY_F11)
	await process_frame
	if level.is_developer_inspection_enabled() or not level.is_developer_measurement_grid_enabled():
		_fail("Exiting inspection incorrectly disabled the independent grid.")
		return
	level.player.global_position += Vector3(40.0, 10.0, 0.0)
	level.player.set_developer_inspection_enabled(true)
	level.camera.set_developer_inspection_enabled(true)
	level.camera.snap_to_target()
	await process_frame
	await process_frame
	var moved_bounds := grid.displayed_bounds()
	if moved_bounds == initial_bounds:
		_fail("The grid did not recycle around a distant camera position.")
		return
	var expected_x := snappedf(level.player.global_position.x, 0.01)
	var expected_feet_y := snappedf(level.player.feet_world_y(), 0.01)
	if (
		"PLAYER FEET" not in label.text
		or "X %.2f" % expected_x not in label.text
		or "Y %.2f" % expected_feet_y not in label.text
	):
		_fail("The grid readout did not track the player's feet position.")
		return
	_send_key(game_root, KEY_F10)
	await process_frame
	if (
		level.is_developer_measurement_grid_enabled()
		or label.visible
		or cursor_label.visible
	):
		_fail("The second F10 press did not hide the grid and readout.")
		return
	game_root.developer_tools_enabled = false
	_send_key(game_root, KEY_F10)
	if level.is_developer_measurement_grid_enabled():
		_fail("F10 grid remained available after developer tools were disabled.")
		return
	print("Developer F10 world measurement-grid validation passed.")
	quit(0)


func _send_key(game_root: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	game_root._unhandled_input(event)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
