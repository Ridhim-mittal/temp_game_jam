extends Control
## Main menu, comic edition (layout after the reference: title on a pale
## paint strip at the left, diamond-icon menu bars, the hero squaring up to
## red-eyed monsters on the right, a hint bar along the bottom).
## Everything moves a little: letters bob and "line-boil", bars slide in and
## pop on hover, the burst turns, Vesper slashes now and then.
## Built in code; edit ENTRIES to change the options (logic is Kalp's).

const MenuShader = preload("res://shaders/menu_comic.gdshader")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const PlayerVisual = preload("res://scripts/player/player_visual.gd")
const CrawlerVisual = preload("res://scripts/enemies/crawler_visual.gd")
const SwordScene = preload("res://scenes/player/sword.tscn")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

const INK := Color(0.04, 0.03, 0.05)
const PAPER := Color(0.96, 0.93, 0.9)
const RED := Color(0.9, 0.22, 0.16)
const GOLD := Color(1.0, 0.82, 0.25)
const DIM := Color(0.62, 0.6, 0.62)

## [label, scene to load ("" = quit), icon]
const ENTRIES := [
	["Begin", "res://scenes/cutscenes/cs_opening.tscn", "play"],
	["Skip to the level", "res://scenes/levels/test_level.tscn", "skip"],
	["Monster test", "res://scenes/levels/monster_test.tscn", "eye"],
	["Quit", "", "x"],
]
const SFX := ["SHNK!", "KRAK!", "SLASH!", "THWACK!"]
const BAR_POS := Vector2(70, 372)
const BAR_SIZE := Vector2(400, 50)
const BAR_GAP := 64.0

@export var music := "margins"

var _buttons: Array[Button] = []
var _hover: Array[float] = []
var _time := 0.0
var _boil := 0  # changes ~8x a second: comic line boil
var _hero: Node2D
var _sword: Node2D
var _beetles: Array = []
var _overlay: Node2D
var _sfx: Array = []
var _next_slash := 2.0
var _leaving := ""
var _leave_t := -1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = MenuShader
	bg.material = mat
	bg.show_behind_parent = true
	add_child(bg)

	_build_tableau()

	for i in ENTRIES.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.position = BAR_POS + Vector2(0, i * BAR_GAP)
		b.size = BAR_SIZE
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, empty)
		b.pressed.connect(_choose.bind(ENTRIES[i][1]))
		b.mouse_entered.connect(b.grab_focus)
		add_child(b)
		_buttons.append(b)
		_hover.append(0.0)
	_buttons[0].grab_focus()

	# drawn above the tableau: eye glows, target tags, SFX words, hint bar, wipe
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	var player := get_node_or_null("/root/Music")
	if player and music != "":
		player.play(music)


func _build_tableau() -> void:
	_hero = _outlined_group(Vector2(690, 590), Vector2(3.0, 3.0), Color(1.0, 0.98, 0.9))
	var art := Node2D.new()
	art.name = "Art"
	art.set_script(PlayerVisual)
	_hero.add_child(art)
	_sword = SwordScene.instantiate()
	_hero.add_child(_sword)
	add_child(_hero)
	for spot in [Vector2(925, 600), Vector2(1110, 586)]:
		var g := _outlined_group(spot, Vector2(-3.2, 3.2), RED)
		var v := Node2D.new()
		v.set_script(CrawlerVisual)
		g.add_child(v)
		add_child(g)
		_beetles.append(v)


func _outlined_group(pos: Vector2, scl: Vector2, pop: Color) -> CanvasGroup:
	var g := CanvasGroup.new()
	g.position = pos
	g.scale = scl
	g.fit_margin = 40.0
	var m := ShaderMaterial.new()
	m.shader = OutlineShader
	m.set_shader_parameter("pop_color", pop)
	g.material = m
	return g


func _process(delta: float) -> void:
	_time += delta
	_boil = int(_time * 8.0)
	var focused := get_viewport().gui_get_focus_owner()
	for i in _buttons.size():
		var target := 1.0 if _buttons[i] == focused else 0.0
		_hover[i] = move_toward(_hover[i], target, delta * 6.0)
	# monsters stay angry and twitchy
	for k in _beetles.size():
		var v = _beetles[k]
		v.aggro = true
		v.bristle = 0.75 + 0.25 * sin(_time * 3.0 + k)
		v.look = Vector2(1.0, 0.15 * sin(_time * 1.3 + k))
		v.walk_phase += delta * (1.5 + k)
		v.mouth_open = clampf(sin(_time * 0.9 + k * 2.0) * 2.0 - 1.2, 0.0, 1.0)
	# hero strikes every few seconds
	_next_slash -= delta
	if _next_slash <= 0.0:
		_next_slash = randf_range(2.2, 3.6)
		_sword.swing(Vector2.RIGHT)
		_sfx.append({"text": SFX.pick_random(), "p": Vector2(randf_range(780, 860), randf_range(400, 470)), "t": 0.0, "rot": randf_range(-0.3, 0.2)})
	for s in _sfx:
		s.t += delta
	_sfx = _sfx.filter(func(s): return s.t < 0.9)
	if _leave_t >= 0.0:
		_leave_t += delta
		if _leave_t >= 0.45:
			_leave_t = -1.0
			if _leaving == "quit":
				get_tree().quit()
			else:
				get_tree().change_scene_to_file(_leaving)
	queue_redraw()
	_overlay.queue_redraw()


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
	if _leave_t >= 0.0:
		return
	# ink wipe first, then change scene (see _process)
	_leaving = "quit" if scene == "" else scene
	_leave_t = 0.0


# ------------------------------------------------------------------ drawing

func _jitter(seed_i: int, amount: float) -> Vector2:
	var h := absi(hash(Vector2i(seed_i, _boil)))
	return Vector2(float(h % 1000) / 1000.0 - 0.5, float((h >> 10) % 1000) / 1000.0 - 0.5) * amount


func _draw() -> void:
	_draw_ledge()
	_draw_title()
	_draw_caption()
	for i in _buttons.size():
		_draw_bar(i)


func _draw_ledge() -> void:
	# the rooftop the fight stands on
	var pts := PackedVector2Array([Vector2(560, 720), Vector2(575, 598), Vector2(760, 604),
		Vector2(900, 612), Vector2(1060, 598), Vector2(1280, 590), Vector2(1280, 720)])
	draw_colored_polygon(pts, INK)
	draw_polyline(pts.slice(1, 6), Color(RED, 0.7), 2.0)


func _draw_title() -> void:
	var text := "VESPER"
	var size_px := 150
	var x := 72.0
	var base_y := 230.0
	for i in text.length():
		var ch := text[i]
		var w := TITLE_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var bob := sin(_time * 2.2 + i * 0.8) * 5.0
		var rot := sin(_time * 1.4 + i * 1.1) * 0.05
		var p := Vector2(x + w * 0.5, base_y + bob) + _jitter(i, 2.5)
		draw_set_transform(p, rot)
		var o := Vector2(-w * 0.5, 0)
		# red misregistration shadow, then ink letter with a paper outline
		draw_string(TITLE_FONT, o + Vector2(7, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, RED)
		draw_string_outline(TITLE_FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 10, PAPER)
		draw_string(TITLE_FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, INK)
		x += w - 2.0
	draw_set_transform(Vector2.ZERO)
	# brush underline
	var pts := PackedVector2Array()
	for k in 24:
		var t := k / 23.0
		pts.append(Vector2(76 + t * 400.0, 254 + sin(t * 9.0 + _time * 2.0) * 2.5) + _jitter(100 + k, 1.2))
	draw_polyline(pts, INK, 6.0, true)


func _draw_caption() -> void:
	# yellow narrator caption box, swaying
	var rot := -0.035 + sin(_time * 1.1) * 0.012
	draw_set_transform(Vector2(84, 280), rot)
	var r := Rect2(Vector2.ZERO, Vector2(380, 40))
	draw_rect(r.grow(3.0), INK)
	draw_rect(r, Color(1.0, 0.9, 0.45))
	draw_string(TITLE_FONT, Vector2(14, 29), "HE WAS MEANT TO DIE ON PAGE THREE...", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_set_transform(Vector2.ZERO)


func _draw_bar(i: int) -> void:
	var h: float = _hover[i]
	var intro := clampf((_time - 0.35 - i * 0.12) / 0.45, 0.0, 1.0)
	var slide := (1.0 - pow(1.0 - intro, 3.0)) - 1.0  # ease-out from off screen
	var pos := BAR_POS + Vector2(slide * 520.0 + h * 14.0, i * BAR_GAP) + _jitter(200 + i, h * 2.0)
	var len := BAR_SIZE.x * (0.82 + 0.18 * h)
	var y := pos.y + BAR_SIZE.y * 0.5
	var icon_c := Vector2(pos.x + 26.0, y)
	# slanted bar
	var bar := PackedVector2Array([Vector2(pos.x + 30, pos.y + 6), Vector2(pos.x + len + 18, pos.y + 6),
		Vector2(pos.x + len, pos.y + BAR_SIZE.y - 6), Vector2(pos.x + 30, pos.y + BAR_SIZE.y - 6)])
	draw_colored_polygon(bar, INK.lerp(Color(0.32, 0.05, 0.06), h))
	draw_polyline(bar + PackedVector2Array([bar[0]]), Color(PAPER, 0.25 + 0.5 * h), 1.5)
	if h > 0.01:
		# comic burst star behind the diamond
		var star := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0 + _time * 1.5
			star.append(icon_c + Vector2.from_angle(a) * (k % 2 * 14.0 + 20.0) * h * 1.25)
		draw_colored_polygon(star, Color(GOLD, h))
	# diamond icon
	var dsz := 21.0 + 4.0 * h
	var diamond := PackedVector2Array([icon_c + Vector2(0, -dsz), icon_c + Vector2(dsz, 0), icon_c + Vector2(0, dsz), icon_c + Vector2(-dsz, 0)])
	draw_colored_polygon(diamond, RED)
	var inner := PackedVector2Array()
	for p in diamond:
		inner.append(icon_c + (p - icon_c) * 0.78)
	draw_colored_polygon(inner, INK)
	_draw_icon(ENTRIES[i][2], icon_c, PAPER if h < 0.5 else GOLD)
	# label
	var label: String = ENTRIES[i][0].to_upper()
	var tc := DIM.lerp(PAPER, h)
	draw_string_outline(TITLE_FONT, Vector2(pos.x + 62, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, INK)
	draw_string(TITLE_FONT, Vector2(pos.x + 62, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, tc)


func _draw_icon(kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(8, 0), c + Vector2(-5, 8)]), col)
		"skip":
			for dx in [-7.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(dx, -7), c + Vector2(dx + 7, 0), c + Vector2(dx, 7)]), col)
		"eye":
			draw_circle(c, 7.0, col)
			draw_circle(c, 3.5, RED)
		_:
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), col, 3.0)
			draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), col, 3.0)


func _draw_overlay() -> void:
	var o := _overlay
	# glowing red eyes over the beetles (eye sits at local (11, -15), mirrored)
	for k in _beetles.size():
		var g: Node2D = _beetles[k].get_parent()
		var eye := g.position + Vector2(11.0 * g.scale.x, -15.0 * g.scale.y)
		var pulse := 0.75 + 0.25 * sin(_time * 4.0 + k * 1.7)
		for ring in 3:
			o.draw_circle(eye, (14.0 + ring * 10.0) * pulse, Color(RED, 0.16 - ring * 0.045))
		o.draw_circle(eye, 6.0, Color(1.0, 0.25, 0.2))
		o.draw_circle(eye, 2.5, Color(1.0, 0.85, 0.7))
		_draw_target_tag(o, g.position + Vector2(-70, -150 - 6.0 * sin(_time * 1.8 + k)), k)
	# comic SFX words around the slashes
	for s in _sfx:
		var t: float = s.t
		var sc := 0.6 + 0.6 * minf(t / 0.12, 1.0)
		o.draw_set_transform(s.p + Vector2(0, -t * 30.0), s.rot, Vector2(sc, sc))
		var a := clampf((0.9 - t) / 0.3, 0.0, 1.0)
		o.draw_string_outline(TITLE_FONT, Vector2(-50, 0), s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 10, Color(INK, a))
		o.draw_string(TITLE_FONT, Vector2(-50, 0), s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(GOLD, a))
	o.draw_set_transform(Vector2.ZERO)
	_draw_cover_badge(o)
	_draw_hint_bar(o)
	if _leave_t >= 0.0:
		_draw_wipe(o)


func _draw_target_tag(o: Node2D, p: Vector2, k: int) -> void:
	var font := TITLE_FONT
	o.draw_string_outline(font, p + Vector2(22, 0), "INK BEETLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, INK)
	o.draw_string(font, p + Vector2(22, 0), "INK BEETLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RED)
	var c := p + Vector2(8, -8)
	o.draw_arc(c, 8.0, 0, TAU, 16, RED, 2.0)
	o.draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), RED, 1.5)
	o.draw_line(c + Vector2(0, -12), c + Vector2(0, 12), RED, 1.5)
	o.draw_rect(Rect2(p + Vector2(22, 8), Vector2(110, 7)), INK)
	o.draw_rect(Rect2(p + Vector2(23, 9), Vector2(108.0 * (0.55 + 0.25 * k), 5)), RED)


func _draw_cover_badge(o: Node2D) -> void:
	# comic-book cover corner box: issue number and price
	var c := Vector2(1196, 70)
	var rot := 0.08 + sin(_time * 1.3) * 0.02
	o.draw_set_transform(c, rot)
	var r := Rect2(Vector2(-62, -44), Vector2(124, 88))
	o.draw_rect(r.grow(3.0), INK)
	o.draw_rect(r, PAPER)
	o.draw_rect(Rect2(r.position, Vector2(r.size.x, 26)), RED)
	o.draw_string(TITLE_FONT, Vector2(-44, -24), "ISSUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	o.draw_string(TITLE_FONT, Vector2(-40, 26), "#1", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, INK)
	o.draw_string(TITLE_FONT, Vector2(16, 26), "25¢", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RED)
	o.draw_set_transform(Vector2.ZERO)


func _draw_hint_bar(o: Node2D) -> void:
	o.draw_rect(Rect2(0, 682, 1280, 38), Color(INK, 0.92))
	o.draw_line(Vector2(0, 682), Vector2(1280, 682), Color(RED, 0.8), 2.0)
	var x := 70.0
	for hint in [["W/S", "CHOOSE"], ["ENTER / CLICK", "ACCEPT"], ["ESC", "IN GAME: BACK HERE"]]:
		var c := Vector2(x, 701)
		var d := 11.0
		o.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), RED)
		o.draw_string(TITLE_FONT, c + Vector2(18, 8), hint[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
		var kw := TITLE_FONT.get_string_size(hint[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		o.draw_string(TITLE_FONT, c + Vector2(24 + kw, 8), hint[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
		x += 70.0 + kw + TITLE_FONT.get_string_size(hint[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	o.draw_string(TITLE_FONT, Vector2(1030, 709), "A CD PROJECT BLAXK COMIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(PAPER, 0.6))


func _draw_wipe(o: Node2D) -> void:
	# ink diamond bursting out of the chosen entry, covering the screen
	var i := maxi(_buttons.find(get_viewport().gui_get_focus_owner()), 0)
	var c := BAR_POS + Vector2(26, i * BAR_GAP + BAR_SIZE.y * 0.5)
	var k := clampf(_leave_t / 0.42, 0.0, 1.0)
	var s := k * k * 2600.0 + 20.0
	var dm := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	o.draw_colored_polygon(dm, RED)
	var inner := PackedVector2Array()
	for p in dm:
		inner.append(c + (p - c) * 0.92)
	o.draw_colored_polygon(inner, INK)
