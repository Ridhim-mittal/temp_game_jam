extends Control
## Settings screen (main menu -> Settings), drawn in the menu's comic style.
## W/S or up/down pick a row, A/D, left/right or a click change it, Esc or
## "Back" returns to the menu. Values live in the Settings autoload.

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const MENU := "res://scenes/ui/main_menu.tscn"
const INK := Color(0.05, 0.03, 0.08)
const PAPER := Color(0.97, 0.95, 0.9)
const RED := Color(0.9, 0.22, 0.16)
const DIM := Color(0.62, 0.6, 0.62)

## [label, Settings key ("" = back), {value: [name, description]}]
const ROWS := [
	["SCRIBBLES", "scribble_style", {
		"hopper": ["HOPPER", "Hops along the ground and pounces (2.5D design)"],
		"diver": ["DIVE-BOMBER", "Flies, shakes, then dive-bombs you; flees light (platformer design)"],
	}],
	["BACK", "", {}],
]

var _row := 0
var _time := 0.0
var _rects: Array[Rect2] = []


func _ready() -> void:
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
			KEY_S, KEY_DOWN:
				_row = (_row + 1) % ROWS.size()
			KEY_A, KEY_LEFT:
				_change(-1)
			KEY_D, KEY_RIGHT, KEY_ENTER, KEY_SPACE:
				_change(1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point(event.position):
				_row = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if _rects[i].has_point(event.position):
				_row = i
				_change(1)


func _change(step: int) -> void:
	var key: String = ROWS[_row][1]
	if key == "":
		_back()
		return
	var settings := get_node_or_null("/root/Settings")
	if settings:
		settings.cycle(key, step)


func _back() -> void:
	get_tree().change_scene_to_file(MENU)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	# halftone speed lines, like the menu's backdrop
	for i in 14:
		var a := -0.5 + i * 0.09 + sin(_time * 0.3) * 0.02
		var from := Vector2(size.x * 0.8, size.y * 0.55)
		draw_line(from, from + Vector2(cos(a + PI), sin(a + PI)) * 1400.0, Color(RED, 0.12), 26.0)
	var title := "SETTINGS"
	draw_string_outline(TITLE_FONT, Vector2(76, 170), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 16, Color(RED, 0.9))
	draw_string(TITLE_FONT, Vector2(70, 164), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, PAPER)
	draw_line(Vector2(70, 186), Vector2(470, 182), PAPER, 5.0)
	_rects.clear()
	var settings := get_node_or_null("/root/Settings")
	for i in ROWS.size():
		var row: Array = ROWS[i]
		var y := 270.0 + i * 120.0
		var focused := i == _row
		var rect := Rect2(70, y, 760, 64 if row[1] != "" else 52)
		_rects.append(rect)
		var bar := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end - Vector2(24, 0), rect.position + Vector2(0, rect.size.y)])
		draw_colored_polygon(bar, Color(RED, 0.85) if focused else Color(0.12, 0.1, 0.14))
		draw_polyline(bar + PackedVector2Array([bar[0]]), RED, 2.0)
		draw_string(TITLE_FONT, rect.position + Vector2(24, 42 if row[1] != "" else 37), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
			PAPER if focused else DIM)
		if row[1] != "" and settings:
			var value: String = settings.get(row[1])
			var info: Array = row[2].get(value, [value, ""])
			var text := "<  %s  >" % info[0]
			draw_string(TITLE_FONT, rect.position + Vector2(300, 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1.0, 0.82, 0.25))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, rect.size.y + 26), info[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				Color(PAPER, 0.8))
	draw_string(TITLE_FONT, Vector2(70, size.y - 40), "W/S  CHOOSE     A/D  CHANGE     ESC  BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
