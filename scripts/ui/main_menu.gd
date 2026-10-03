extends Control
## Main menu. Builds itself in code: ink-wash backdrop (menu_ink.gdshader),
## title, and a list of entries you can drive with keyboard, gamepad or
## mouse. Edit ENTRIES to add or change options.

const InkShader = preload("res://shaders/menu_ink.gdshader")
const RED := Color(0.9, 0.22, 0.16)
const PALE := Color(0.96, 0.93, 0.9)
const DIM := Color(0.62, 0.6, 0.62)
const TEAL := Color(0.38, 0.85, 0.7)

## [label, scene to load ("" = quit)]
const ENTRIES := [
	["Begin", "res://scenes/cutscenes/cs_opening.tscn"],
	["Skip to the level", "res://scenes/levels/test_level.tscn"],
	["Monster test", "res://scenes/levels/monster_test.tscn"],
	["Quit", ""],
]

@export var music := "margins"

var _buttons: Array[Button] = []
var _time := 0.0
var _marks: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = InkShader
	bg.material = mat
	bg.show_behind_parent = true
	add_child(bg)

	var title := Label.new()
	title.text = "VESPER"
	title.position = Vector2(560, 120)
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", PALE)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	title.add_theme_constant_override("outline_size", 14)
	add_child(title)

	var tag := Label.new()
	tag.text = "he was meant to die on page three"
	tag.position = Vector2(568, 262)
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", RED)
	add_child(tag)

	var list := VBoxContainer.new()
	list.position = Vector2(600, 350)
	list.add_theme_constant_override("separation", 6)
	add_child(list)
	var empty := StyleBoxEmpty.new()
	for entry in ENTRIES:
		var b := Button.new()
		b.text = entry[0]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 32)
		b.add_theme_color_override("font_color", DIM)
		b.add_theme_color_override("font_hover_color", PALE)
		b.add_theme_color_override("font_focus_color", PALE)
		b.add_theme_color_override("font_pressed_color", RED)
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, empty)
		b.pressed.connect(_choose.bind(entry[1]))
		b.mouse_entered.connect(b.grab_focus)
		list.add_child(b)
		_buttons.append(b)
	_buttons[0].grab_focus()

	var hint := Label.new()
	hint.text = "W / S or arrows: choose      Space / Enter / click: accept      Esc in game: back here"
	hint.position = Vector2(600, 676)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", DIM)
	add_child(hint)

	# scattered red scribble marks, like notes scratched on the page
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 9:
		_marks.append({"p": Vector2(rng.randf_range(40, 1240), rng.randf_range(40, 680)),
			"r": rng.randf_range(0.0, TAU), "s": rng.randf_range(7.0, 15.0), "k": rng.randi() % 3})

	var player := get_node_or_null("/root/Music")
	if player and music != "":
		player.play(music)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# W/S and the game's own jump/attack keys also work in the menu
	var focused := get_viewport().gui_get_focus_owner()
	var i := _buttons.find(focused)
	if i < 0:
		return
	var pick := event.is_action_pressed("jump")
	var step := 0
	if event.is_action_pressed("up"):
		step = -1
	elif event.is_action_pressed("down"):
		step = 1
	if not pick and step == 0:
		return
	get_viewport().set_input_as_handled()  # before the scene can change
	if pick:
		_buttons[i].pressed.emit()
	else:
		_buttons[(i + step + _buttons.size()) % _buttons.size()].grab_focus()


func _choose(scene: String) -> void:
	if scene == "":
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(scene)


func _draw() -> void:
	# red scratch marks
	for m in _marks:
		draw_set_transform(m.p, m.r + sin(_time * 0.6 + m.s) * 0.05)
		var s: float = m.s
		var c := Color(RED, 0.75)
		match m.k:
			0:
				draw_polyline(PackedVector2Array([Vector2(-s, s * 0.6), Vector2(0, -s), Vector2(s, s * 0.6), Vector2(-s, s * 0.6)]), c, 2.0)
			1:
				draw_line(Vector2(-s, -s), Vector2(s, s), c, 2.0)
				draw_line(Vector2(s, -s), Vector2(-s, s), c, 2.0)
			_:
				draw_polyline(PackedVector2Array([Vector2(-s, 0), Vector2(-s * 0.3, -s * 0.7), Vector2(s * 0.2, s * 0.5), Vector2(s, -s * 0.2)]), c, 2.0)
	draw_set_transform(Vector2.ZERO)

	# ink-brush underline under the title
	var pts := PackedVector2Array()
	for i in 24:
		var k := i / 23.0
		pts.append(Vector2(566 + k * 470.0, 252 + sin(k * 9.0 + 1.0) * 2.5))
	draw_polyline(pts, PALE, 4.0, true)

	# marker beside the focused entry: a small teal diamond with a line to it
	var focused := get_viewport().gui_get_focus_owner()
	if focused in _buttons:
		var y: float = focused.global_position.y + focused.size.y * 0.5
		var x := 572.0 + sin(_time * 5.0) * 3.0
		var d := 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d), Vector2(x - d, y)]), TEAL)
		draw_line(Vector2(120, y), Vector2(x - d - 6.0, y), Color(TEAL, 0.5), 2.0)
