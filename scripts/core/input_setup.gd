extends Node
## Registers all input actions at startup (keyboard + gamepad) so the project
## works out of the box. You can still edit/override these in Project Settings.
## It also tracks which the player is using (`using_pad`): on-screen prompts ask
## `InputSetup.key(action)` / `InputSetup.words(text)` for the button to show,
## and menus use `pad_nav()` / `pad_skip()` so a controller can drive them.

## Set by the last input: a pad button or a stick pushed past half way, or a
## key / mouse button (mouse motion alone doesn't switch back).
var using_pad := false
var _stick := Vector2i.ZERO  # pad_nav(): the stick's last direction, to step once per push

## What each action is called on screen, keyboard / mouse and controller (Xbox names).
const KEY_NAMES := {
	"jump": "SPACE", "attack": "LEFT CLICK", "dash": "SHIFT", "flash": "RIGHT CLICK", "ember": "RIGHT CLICK",
	"heal": "F", "interact": "E", "shop": "B", "pause": "ESC", "skip": "ENTER", "accept": "ENTER", "back": "ESC",
	"choose": "W/S", "change": "A/D",
}
const PAD_NAMES := {
	"jump": "A", "attack": "X", "dash": "RB", "flash": "Y", "ember": "Y",
	"heal": "B", "interact": "LB", "shop": "SELECT", "pause": "START", "skip": "A", "accept": "A", "back": "B",
	"choose": "D-PAD", "change": "LEFT/RIGHT",
}

func _enter_tree() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("up", [KEY_W, KEY_UP])
	_add_keys("down", [KEY_S, KEY_DOWN])
	_add_keys("jump", [KEY_SPACE, KEY_Z])
	_add_keys("attack", [KEY_X])  # keyboard fallback (trackpads)
	_add_mouse_button("attack", MOUSE_BUTTON_LEFT)
	_add_keys("dash", [KEY_SHIFT, KEY_C])  # C: keyboard fallback
	_add_keys("pause", [KEY_ESCAPE])  # the pause screen (pause_menu.gd), 2D and 2.5D
	# The light is right click in both modes: hold it to raise the Ember.
	# 2.5D ("flash", clearing_player.gd); Shift dashes in both modes.
	_add_mouse_button("flash", MOUSE_BUTTON_RIGHT)
	_add_keys("heal", [KEY_F])
	_add_keys("interact", [KEY_E])
	# Quire's shop, anywhere in the game (scripts/ui/shop.gd)
	_add_keys("shop", [KEY_B])
	# platformer Ember: hold right click to raise it (light makes sketches real)
	_add_mouse_button("ember", MOUSE_BUTTON_RIGHT)

	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("attack", JOY_BUTTON_X)
	_add_joy_button("dash", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("flash", JOY_BUTTON_Y)
	_add_joy_button("heal", JOY_BUTTON_B)
	_add_joy_button("interact", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("ember", JOY_BUTTON_Y)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("shop", JOY_BUTTON_BACK)  # Select / View: B is heal on a pad
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("down", JOY_AXIS_LEFT_Y, 1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep listening under pause menus
	using_pad = not Input.get_connected_joypads().is_empty()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


## The button to show for `action` on screen, for whatever the player is using.
func key(action: String) -> String:
	return (PAD_NAMES if using_pad else KEY_NAMES).get(action, action.to_upper())


## A line of text with its mouse buttons swapped for the controller's, when a
## pad is in use ("HOLD RIGHT CLICK..." -> "HOLD Y...").
func words(text: String) -> String:
	if not using_pad:
		return text
	return text.replace("RIGHT CLICK", PAD_NAMES.ember).replace("LEFT CLICK", PAD_NAMES.attack)


## Menus on a controller: the d-pad or the left stick as one step per push
## (the stick has to come back towards the middle before it steps again).
func pad_nav(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: return Vector2i.UP
			JOY_BUTTON_DPAD_DOWN: return Vector2i.DOWN
			JOY_BUTTON_DPAD_LEFT: return Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT: return Vector2i.RIGHT
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var v := Vector2(Input.get_joy_axis(event.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(event.device, JOY_AXIS_LEFT_Y))
		var dir := Vector2i.ZERO
		if v.length() > 0.6:
			dir = Vector2i(signi(roundi(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, signi(roundi(v.y)))
		elif v.length() > 0.3:
			return Vector2i.ZERO  # in between: no step, no re-arm
		var step := dir if dir != _stick else Vector2i.ZERO
		_stick = dir
		return step
	return Vector2i.ZERO


## A controller's "skip this cutscene": A or Start.
func pad_skip(event: InputEvent) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)


func _add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _add_mouse_button(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
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
