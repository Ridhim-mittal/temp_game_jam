extends CanvasLayer
## The Writer narrating: a yellow caption box in the top-left corner of the
## panel whose text is written in letter by letter by a fountain-pen nib,
## then it holds and fades. Plays once per run (GameState remembers), and
## the controls tutorial waits until it's done (busy()).
## Drop one into a level and set `text`.

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const CAPTION := Color(1.0, 0.9, 0.45)

@export_multiline var text := ""
@export var delay := 0.8
@export var letters_per_second := 34.0
@export var hold := 3.5
@export var font_size := 24
@export var width := 520.0

var _t := 0.0
var _done := false
var _lines: PackedStringArray = []
var _art: Control


func _enter_tree() -> void:
	add_to_group("narration")  # before the player's _ready asks for it


func _ready() -> void:
	layer = 3
	var state := get_node_or_null("/root/GameState")
	var id: String = "narration:" + (owner.scene_file_path if owner else String(name))
	if text == "" or (state and "seen" in state and state.seen.has(id)):
		_done = true
		return
	if state and "seen" in state:
		state.seen[id] = true
	_lines = _wrap(text)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_caption)
	add_child(_art)


## Read by the controls tutorial: it waits while the Writer is writing.
func busy() -> bool:
	return not _done


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > _total() + 0.5:
		_done = true
		_art.queue_free()
		return
	_art.queue_redraw()


func _total() -> float:
	return delay + text.length() / letters_per_second + hold


func _wrap(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var test := word if line == "" else line + " " + word
		if FONT.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


func _draw_caption() -> void:
	var c := _art
	var shown := int(maxf(_t - delay, 0.0) * letters_per_second)
	var fade_in := clampf((_t - delay + 0.3) / 0.3, 0.0, 1.0)
	var fade_out := clampf((_total() + 0.5 - _t) / 0.5, 0.0, 1.0)
	var a := fade_in * fade_out
	if a <= 0.0:
		return
	var lh := font_size * 1.2
	var box := Rect2(48, 104, width + 28, lh * _lines.size() + 20)  # under the HUD
	c.draw_set_transform(Vector2.ZERO, -0.015)
	c.draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(INK, 0.35 * a))
	c.draw_rect(box.grow(3.0), Color(INK, a))
	c.draw_rect(box, Color(CAPTION, a))
	# letters appear one by one; the nib sits at the newest one
	var left := shown
	var nib := Vector2.ZERO
	for i in _lines.size():
		var line: String = _lines[i]
		var part := line.substr(0, clampi(left, 0, line.length()))
		var base := box.position + Vector2(14, 12 + lh * (i + 0.8))
		c.draw_string(FONT, base, part, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(INK, a))
		if left > 0 and left <= line.length():
			nib = base + Vector2(FONT.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, -font_size * 0.3)
		left -= line.length() + 1
	if shown < text.length() and nib != Vector2.ZERO:
		_draw_nib(c, nib + Vector2(sin(_t * 30.0) * 1.5, cos(_t * 26.0) * 2.0), a)
	c.draw_set_transform(Vector2.ZERO)


## A gold fountain-pen nib writing, tip at `p`.
func _draw_nib(c: Control, p: Vector2, a: float) -> void:
	var tip := p
	var nib := PackedVector2Array([tip, tip + Vector2(10, -16), tip + Vector2(20, -12), tip + Vector2(6, 2)])
	var body := PackedVector2Array([tip + Vector2(10, -16), tip + Vector2(40, -58), tip + Vector2(52, -50), tip + Vector2(20, -12)])
	c.draw_colored_polygon(body, Color(0.86, 0.13, 0.15, a))
	c.draw_polyline(body + PackedVector2Array([body[0]]), Color(INK, a), 2.0)
	c.draw_colored_polygon(nib, Color(0.98, 0.76, 0.28, a))
	c.draw_polyline(nib + PackedVector2Array([nib[0]]), Color(INK, a), 2.0)
	c.draw_circle(tip, 2.5, Color(INK, a))
