extends SceneTree
## One-shot project setup kept in source control so default bindings are
## reproducible. Runtime rebinding will be a separate player-facing system.


func _init() -> void:
	_configure_action("move_left", 0.2, [
		_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0),
	])
	_configure_action("move_right", 0.2, [
		_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0),
	])
	_configure_action("jump", 0.2, [
		_key(KEY_SPACE), _key(KEY_W), _key(KEY_UP), _joy_button(JOY_BUTTON_A),
	])
	_configure_action("attack", 0.2, [
		_mouse_button(MOUSE_BUTTON_LEFT), _key(KEY_J), _joy_button(JOY_BUTTON_X),
	])
	_configure_action("dash", 0.2, [
		_key(KEY_SHIFT), _joy_button(JOY_BUTTON_B),
	])
	_configure_action("restart", 0.2, [])
	_configure_action("reload", 0.2, [
		_key(KEY_R), _joy_button(JOY_BUTTON_Y),
	])
	_configure_action("weapon_slot_1", 0.2, [
		_key(KEY_1),
	])
	_configure_action("weapon_slot_2", 0.2, [
		_key(KEY_2),
	])
	_configure_action("weapon_cycle_next", 0.2, [
		_mouse_button(MOUSE_BUTTON_WHEEL_DOWN),
		_joy_button(JOY_BUTTON_RIGHT_SHOULDER),
	])
	_configure_action("weapon_cycle_previous", 0.2, [
		_mouse_button(MOUSE_BUTTON_WHEEL_UP),
	])
	_configure_action("aim_up", 0.2, [
		_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0),
	])
	_configure_action("developer_fly_up", 0.2, [
		_key(KEY_W), _key(KEY_UP), _key(KEY_SPACE),
	])
	_configure_action("developer_fly_down", 0.2, [
		_key(KEY_S), _key(KEY_DOWN),
	])
	var error := ProjectSettings.save()
	assert(error == OK, "Could not save default input actions.")
	print("Default input actions configured.")
	quit(0)


func _configure_action(action: StringName, deadzone: float, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/%s" % action, {
		"deadzone": deadzone,
		"events": events,
	})


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _mouse_button(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
