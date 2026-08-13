extends SceneTree
## Runtime contract for the independent F7 gameplay-collision projection.

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
	var legend := game_root.get_node("Interface/DeveloperCollisionLegend") as Label
	var menu_hint := game_root.get_node("Interface/MenuHint") as Label
	_send_key(game_root, KEY_F7)
	await process_frame
	var overlay := level.developer_collision_overlay()
	if overlay == null or not level.is_developer_collision_overlay_enabled():
		_fail("F7 did not create and enable the collision overlay.")
		return
	if (
		not legend.visible
		or "MAGENTA enemy" not in legend.text
		or "RED lethal" not in legend.text
	):
		_fail("The collision overlay does not expose its colour legend.")
		return
	for category in [
		&"terrain",
		&"player",
		&"player_contact",
		&"enemy",
		&"enemy_contact",
		&"hazard",
		&"checkpoint",
		&"pickup",
		&"goal",
	]:
		if overlay.category_count(category) <= 0:
			_fail("The collision overlay omitted category '%s'." % category)
			return
	if overlay.displayed_shape_count() < 20:
		_fail("The collision overlay did not discover the authored level shapes.")
		return
	if "F7: HIDE HITBOXES" not in menu_hint.text:
		_fail("The compact HUD does not explain how to hide hitboxes.")
		return
	Input.action_press("attack")
	level.player.call("_update_attack", 0.0)
	Input.action_release("attack")
	await process_frame
	if overlay.dynamic_attack_region_count() != 1:
		_fail("An active knife swing did not expose its transient damage region.")
		return
	_send_key(game_root, KEY_F10)
	_send_key(game_root, KEY_F11)
	await process_frame
	if (
		not level.is_developer_collision_overlay_enabled()
		or not level.is_developer_measurement_grid_enabled()
		or not level.is_developer_inspection_enabled()
	):
		_fail("F7, F10, and F11 could not coexist independently.")
		return
	_send_key(game_root, KEY_F7)
	await process_frame
	if level.is_developer_collision_overlay_enabled() or legend.visible:
		_fail("The second F7 press did not hide the overlay and legend.")
		return
	game_root.developer_tools_enabled = false
	_send_key(game_root, KEY_F7)
	if level.is_developer_collision_overlay_enabled():
		_fail("F7 remained available after developer tools were disabled.")
		return
	print("Developer F7 collision-overlay validation passed.")
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
