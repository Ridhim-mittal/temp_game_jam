extends Node
## Registers all input actions at startup (keyboard + gamepad) so the project
## works out of the box. You can still edit/override these in Project Settings.

func _enter_tree() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("up", [KEY_W, KEY_UP])
	_add_keys("down", [KEY_S, KEY_DOWN])
	_add_keys("jump", [KEY_SPACE, KEY_Z])
	_add_keys("attack", [KEY_J, KEY_X])
	_add_keys("dash", [KEY_K, KEY_C, KEY_SHIFT])
	_add_keys("restart", [KEY_R])

	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("attack", JOY_BUTTON_X)
	_add_joy_button("dash", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("down", JOY_AXIS_LEFT_Y, 1.0)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)


func _add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
