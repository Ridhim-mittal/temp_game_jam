extends Control
## Settings screen in the menu's comic style. Opens from the main menu (as
## its own scene) or over the game from the pause menu (`overlay = true`,
## then "Back" closes it). W/S pick a row, A/D or a click change it.

signal closed

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const MENU := "res://scenes/ui/main_menu.tscn"
const INK := Color(0.05, 0.03, 0.08)
const PAPER := Color(0.97, 0.95, 0.9)
const RED := Color(0.9, 0.22, 0.16)
const DIM := Color(0.62, 0.6, 0.62)
const GOLD := Color(1.0, 0.82, 0.25)

## [label, Settings key ("" = action), {value: [shown, description]}]
const ROWS := [
	["VOLUME", "volume", {}],
	["FULLSCREEN", "fullscreen", {"off": ["OFF", "Play in a window."], "on": ["ON", "Fill the screen."]}],
	["SCREEN SHAKE", "screen_shake", {"off": ["OFF", "No camera shake."], "low": ["LOW", "Gentle shake on hits."],
		"full": ["FULL", "Big comic-book impacts."]}],
	["HIT WORDS", "hit_text", {"on": ["ON", "THWACK! POW! over every hit."], "off": ["OFF", "No sound-effect words."]}],
	["DIFFICULTY", "difficulty", {"relaxed": ["RELAXED", "+2 ink drops and longer safety after hits."],
		"normal": ["NORMAL", "As designed."], "hard": ["HARD", "Monsters hit harder and take more beating."]}],
	["SCRIBBLES", "scribble_style", {"hopper": ["HOPPER", "Hops along the ground and pounces (2.5D design)."],
		"diver": ["DIVE-BOMBER", "Flies, shakes, then dive-bombs you; flees light (platformer design)."]}],
	["TUTORIALS", "!tutorials", {}],
	["RESET PROGRESS", "!reset", {}],
	["BACK", "", {}],
]

## true when shown over the game (from the pause menu)
var overlay := false

var _row := 0
var _time := 0.0
var _rects: Array[Rect2] = []
var _confirm_reset := false
var _tutorials_reset := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_back()
			KEY_W, KEY_UP:
				_row = (_row - 1 + ROWS.size()) % ROWS.size()
				_confirm_reset = false
			KEY_S, KEY_DOWN:
				_row = (_row + 1) % ROWS.size()
				_confirm_reset = false
			KEY_A, KEY_LEFT:
				_change(-1)
			KEY_D, KEY_RIGHT, KEY_ENTER, KEY_SPACE:
				_change(1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point(event.position) and _row != i:
				_row = i
				_confirm_reset = false
	elif event is InputEventMouseButton and event.pressed:
		for i in _rects.size():
			if _rects[i].has_point(event.position):
				_row = i
				_change(-1 if event.button_index == MOUSE_BUTTON_RIGHT else 1)


func _change(step: int) -> void:
	var key: String = ROWS[_row][1]
	if key == "":
		_back()
	elif key == "!tutorials":
		var profile := get_node_or_null("/root/Profile")
		if profile:
			profile.reset_tutorials()
		_tutorials_reset = true
	elif key == "!reset":
		if _confirm_reset:
			var profile := get_node_or_null("/root/Profile")
			if profile:
				profile.reset()
			_confirm_reset = false
		else:
			_confirm_reset = true
	else:
		var settings := get_node_or_null("/root/Settings")
		if settings:
			settings.cycle(key, step)


func _back() -> void:
	if overlay:
		closed.emit()
		queue_free()
	else:
		get_tree().change_scene_to_file(MENU)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.94) if overlay else INK)
	for i in 14:
		var a := -0.5 + i * 0.09 + sin(_time * 0.3) * 0.02
		var from := Vector2(size.x * 0.82, size.y * 0.55)
		draw_line(from, from + Vector2(cos(a + PI), sin(a + PI)) * 1400.0, Color(RED, 0.1), 26.0)
	draw_string_outline(TITLE_FONT, Vector2(76, 108), "SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 14, Color(RED, 0.9))
	draw_string(TITLE_FONT, Vector2(70, 102), "SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, PAPER)
	_rects.clear()
	var settings := get_node_or_null("/root/Settings")
	var desc := ""
	for i in ROWS.size():
		var row: Array = ROWS[i]
		var focused := i == _row
		var rect := Rect2(70, 140.0 + i * 50.0, 700, 42)
		_rects.append(rect)
		var bar := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end - Vector2(18, 0), rect.position + Vector2(0, rect.size.y)])
		draw_colored_polygon(bar, Color(RED, 0.85) if focused else Color(0.12, 0.1, 0.14))
		draw_polyline(bar + PackedVector2Array([bar[0]]), RED, 2.0)
		draw_string(TITLE_FONT, rect.position + Vector2(18, 32), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			PAPER if focused else DIM)
		var key: String = row[1]
		var shown := ""
		if key == "volume" and settings:
			var v: int = settings.get_value("volume")
			shown = "<  " + "■".repeat(v) + "□".repeat(10 - v) + "  >"
			if focused:
				desc = "Master volume (%d / 10)." % v
		elif key == "!tutorials":
			shown = "WILL PLAY AGAIN" if _tutorials_reset else ""
			if focused:
				desc = "Show the controls tutorials again the next time you play."
		elif key == "!reset":
			shown = "PRESS AGAIN TO WIPE" if _confirm_reset else ""
			if focused:
				desc = "Forget Lumens, skills and shop items. This can't be undone."
		elif key != "" and settings:
			var value = settings.get_value(key)
			var info: Array = row[2].get(value, [str(value), ""])
			shown = "<  %s  >" % info[0]
			if focused:
				desc = info[1]
		if shown != "":
			draw_string(TITLE_FONT, rect.position + Vector2(300, 32), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
				RED.lightened(0.4) if key == "!reset" else GOLD)
	if desc != "":
		draw_string(ThemeDB.fallback_font, Vector2(80, size.y - 64), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(PAPER, 0.85))
	draw_string(TITLE_FONT, Vector2(70, size.y - 26), "W/S  CHOOSE     A/D  CHANGE     ESC  BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
