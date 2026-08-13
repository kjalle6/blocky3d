extends SceneTree
## Real-input contract for the development-only F11 inspection mode.

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
	var player := level.player
	var camera := level.camera as PixelSideCamera3D
	var label := game_root.get_node("Interface/DeveloperInspectionLabel") as Label
	var menu_hint := game_root.get_node("Interface/MenuHint") as Label
	var original_layer := player.collision_layer
	var original_mask := player.collision_mask
	var hazard_contact := player.get_node("HazardContact") as Area3D
	var original_hazard_layer := hazard_contact.collision_layer
	var start_position := player.global_position
	if player.has_ability(PlayerAbility.DOUBLE_JUMP):
		_fail("Arrival unexpectedly began with Double Jump before inspection.")
		return

	_send_key(KEY_F11)
	await process_frame
	if not level.is_developer_inspection_enabled():
		_fail("F11 did not enable level inspection mode.")
		return
	if not player.is_developer_inspection_enabled():
		_fail("F11 did not enable player inspection mode.")
		return
	if not camera.is_developer_inspection_enabled():
		_fail("F11 did not remove normal camera route clamps.")
		return
	if not label.visible or "GOD / NOCLIP / FREE FLIGHT" not in label.text:
		_fail("Inspection mode lacks an unmistakable on-screen warning.")
		return
	if "LEVEL ABILITIES STAY UNLOCKED UNTIL RELOAD" not in label.text:
		_fail("Inspection mode does not explain its session-local ability grant.")
		return
	if not player.has_ability(PlayerAbility.DOUBLE_JUMP):
		_fail("F11 did not grant Arrival's available Double Jump ability.")
		return
	if not level.is_session_ability_enabled(PlayerAbility.DOUBLE_JUMP):
		_fail("F11's ability grant was not stored in the loaded test session.")
		return
	if (
		menu_hint.text
		!= "F7: HITBOXES    F10: GRID    F11: EXIT INSPECTION    ESC: SELECT"
	):
		_fail("The compact HUD does not explain how to exit inspection mode.")
		return
	if player.collision_layer != 0 or player.collision_mask != 0:
		_fail("Inspection mode did not disable the player's gameplay body collision.")
		return
	if hazard_contact.collision_layer != 0:
		_fail("Inspection mode left the separate hazard-contact sensor active.")
		return

	Input.action_press("move_right")
	Input.action_press("developer_fly_up")
	for frame in 30:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("developer_fly_up")
	if player.global_position.x <= start_position.x + 2.0:
		_fail("Inspection flight did not move right.")
		return
	if player.global_position.y <= start_position.y + 2.0:
		_fail("Inspection flight did not move upward.")
		return
	if player.is_dead():
		_fail("The player died while inspection mode was active.")
		return
	if absf(camera.global_position.x - player.global_position.x) > 0.1:
		_fail("Inspection camera retained normal horizontal look-ahead or clamping.")
		return

	var inspection_exit_position := player.global_position
	_send_key(KEY_F11)
	await process_frame
	if level.is_developer_inspection_enabled() or player.is_developer_inspection_enabled():
		_fail("The second F11 press did not restore normal gameplay.")
		return
	if label.visible:
		_fail("The inspection warning remained visible after exit.")
		return
	if player.collision_layer != original_layer or player.collision_mask != original_mask:
		_fail("Normal player collision was not restored after inspection.")
		return
	if hazard_contact.collision_layer != original_hazard_layer:
		_fail("The hazard-contact sensor was not restored after inspection.")
		return
	if player.global_position.distance_to(inspection_exit_position) > 0.1:
		_fail("Inspection exit teleported the player instead of restoring in place.")
		return
	if not player.has_ability(PlayerAbility.DOUBLE_JUMP):
		_fail("Exiting F11 removed the ability needed for the real-physics test.")
		return
	level._reset_run(false)
	if not player.has_ability(PlayerAbility.DOUBLE_JUMP):
		_fail("The F11 test ability did not survive an in-session restart.")
		return
	game_root.load_level(LEVEL_ID)
	await process_frame
	level = game_root.current_level as LevelSession3D
	if level.player.has_ability(PlayerAbility.DOUBLE_JUMP):
		_fail("Reloading the level retained F11's session-only ability grant.")
		return
	game_root.developer_tools_enabled = false
	_send_key(KEY_F11)
	if level.is_developer_inspection_enabled() or label.visible:
		_fail("F11 inspection remained available after developer tools were disabled.")
		return
	print("Developer F11 god / noclip / free-flight inspection validation passed.")
	_release_inputs()
	quit(0)


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	root.get_node("GameRoot")._unhandled_input(event)


func _fail(message: String) -> void:
	_release_inputs()
	push_error(message)
	quit(1)


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("developer_fly_up")
	Input.action_release("developer_fly_down")
	Input.action_release("dash")
