extends Control
## Story text for 2.5D rooms:
##  - title card: the room's name in big comic letters as you enter
##  - captions: the Writer's yellow caption boxes, typed out one at a time
##
##   ui.title_card("DARKWOOD MARGINS", "1 / 3")
##   ui.caption("Where did you go?")            # queued, auto-hides
##   ui.caption("THERE.", "shaky")              # the Writer losing it

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)
const CAPTION := Color(1.0, 0.88, 0.4)
const SHAKY := Color(0.95, 0.93, 0.88)

var _title := ""
var _subtitle := ""
var _title_t := -1.0
var _queue: Array = []
var _text := ""
var _who := "writer"
var _shown := 0.0
var _hold := 0.0
var _alpha := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func title_card(title: String, subtitle := "") -> void:
	_title = title
	_subtitle = subtitle
	_title_t = 0.0


func caption(text: String, who := "writer") -> void:
	_queue.append([text, who])


func _process(delta: float) -> void:
	_time += delta
	if _title_t >= 0.0:
		_title_t += delta
		if _title_t > 3.2:
			_title_t = -1.0
	if _text == "" and not _queue.is_empty():
		var next: Array = _queue.pop_front()
		_text = next[0]
		_who = next[1]
		_shown = 0.0
		_hold = 2.2 + _text.length() * 0.035
	if _text != "":
		_shown += delta * 40.0
		_alpha = move_toward(_alpha, 1.0, delta * 5.0)
		if _shown >= _text.length():
			_hold -= delta
			if _hold <= 0.0:
				_alpha = move_toward(_alpha, 0.0, delta * 5.0)
				if _alpha <= 0.0:
					_text = ""
	queue_redraw()


func _draw() -> void:
	_draw_title()
	_draw_caption()


func _draw_title() -> void:
	if _title_t < 0.0:
		return
	var a := clampf(_title_t / 0.3, 0.0, 1.0) * clampf((3.2 - _title_t) / 0.6, 0.0, 1.0)
	var slide := (1.0 - clampf(_title_t / 0.35, 0.0, 1.0)) * 40.0
	var size_px := 64
	var w := TITLE_FONT.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var pos := Vector2((size.x - w) * 0.5, 170.0 - slide)
	draw_string_outline(TITLE_FONT, pos, _title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 14, Color(INK, a))
	draw_string(TITLE_FONT, pos, _title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(PAPER, a))
	draw_line(Vector2(pos.x, pos.y + 14), Vector2(pos.x + w, pos.y + 14), Color(1.0, 0.25, 0.18, a), 4.0)
	if _subtitle != "":
		var sw := TITLE_FONT.get_string_size(_subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var sp := Vector2((size.x - sw) * 0.5, pos.y + 52)
		draw_string_outline(TITLE_FONT, sp, _subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 10, Color(INK, a))
		draw_string(TITLE_FONT, sp, _subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(CAPTION, a))


func _draw_caption() -> void:
	if _text == "" or _alpha <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var fs := 22
	var shown := _text.substr(0, int(_shown))
	var max_w := 620.0
	var lines := _wrap(font, _text, fs, max_w)
	var line_h := fs + 8.0
	var box := Rect2(Vector2((size.x - max_w - 40.0) * 0.5, 96.0), Vector2(max_w + 40.0, lines.size() * line_h + 26.0))
	var shaky := _who == "shaky"
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 1.5 if shaky else Vector2.ZERO
	draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(INK, 0.5 * _alpha))
	draw_rect(box, Color(SHAKY if shaky else CAPTION, _alpha))
	draw_rect(box, Color(INK, _alpha), false, 3.0)
	# type the text out line by line
	var left := shown.length()
	var y := box.position.y + 13.0 + fs
	for line in lines:
		var part: String = line.substr(0, maxi(left, 0))
		left -= line.length() + 1
		draw_string(font, Vector2(box.position.x + 20.0, y) + jitter, part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, _alpha))
		y += line_h


static func _wrap(font: Font, text: String, fs: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
