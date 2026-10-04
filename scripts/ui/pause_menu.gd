extends Control
## Pause menu for 2.5D rooms (Esc): Resume, Skill Tree, Settings, Main Menu.
## The game is paused while it (or anything it opens) is up. room.gd opens
## it and the overlays it leads to.

signal chosen(action: String)

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.08)
const PAPER := Color(0.97, 0.95, 0.9)
const RED := Color(0.9, 0.22, 0.16)
const DIM := Color(0.62, 0.6, 0.62)
const GOLD := Color(1.0, 0.82, 0.25)

const ITEMS := [["RESUME", "resume"], ["SKILL TREE", "skills"], ["SETTINGS", "settings"], ["MAIN MENU", "menu"]]

var _row := 0
var _rects: Array[Rect2] = []
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				chosen.emit("resume")
			KEY_W, KEY_UP:
				_row = (_row - 1 + ITEMS.size()) % ITEMS.size()
			KEY_S, KEY_DOWN:
				_row = (_row + 1) % ITEMS.size()
			KEY_ENTER, KEY_SPACE, KEY_E:
				chosen.emit(ITEMS[_row][1])
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	for i in _rects.size():
		if _rects[i].has_point(event.position if "position" in event else Vector2(-1, -1)):
			_row = i
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(ITEMS[i][1])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.78))
	draw_string_outline(TITLE_FONT, Vector2(86, 186), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 14, Color(RED, 0.9))
	draw_string(TITLE_FONT, Vector2(80, 180), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, PAPER)
	_rects.clear()
	var profile := get_node_or_null("/root/Profile")
	for i in ITEMS.size():
		var rect := Rect2(80, 240.0 + i * 70.0, 420, 52)
		_rects.append(rect)
		var focused := i == _row
		var bar := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end - Vector2(20, 0), rect.position + Vector2(0, rect.size.y)])
		draw_colored_polygon(bar, Color(RED, 0.85) if focused else Color(0.12, 0.1, 0.14))
		draw_polyline(bar + PackedVector2Array([bar[0]]), RED, 2.0)
		var label: String = ITEMS[i][0]
		draw_string(TITLE_FONT, rect.position + Vector2(22, 38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, PAPER if focused else DIM)
		if ITEMS[i][1] == "skills" and profile and profile.skill_points > 0:
			var pulse := 0.6 + 0.4 * sin(_time * 5.0)
			draw_string(TITLE_FONT, rect.position + Vector2(250, 38), "%d POINT%s" % [profile.skill_points, "" if profile.skill_points == 1 else "S"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(GOLD, pulse))
	draw_string(TITLE_FONT, Vector2(80, size.y - 40), "W/S  CHOOSE     ENTER  SELECT     ESC  RESUME", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
