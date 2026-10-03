extends Control
## Main menu, comic edition (layout after the reference: title on a pale
## paint strip at the left, diamond-icon menu bars, the hero squaring up to
## red-eyed monsters on the right), dressed with botched ink: splatters,
## scratch bundles, blinking red marks, corner blots in the foreground.
## Everything moves a little: letters bob and "line-boil", bars slide in and
## pop on hover, the burst turns and flickers, embers rise, layers shift with
## the mouse (parallax), Vesper slashes now and then.
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
	["2.5D clearing", "res://scenes/clearing/clearing.tscn", "map"],
	["Quit", "", "x"],
]
const SFX := ["SHNK!", "KRAK!", "SLASH!", "THWACK!"]
const BAR_POS := Vector2(70, 336)
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
var _bg_mat: ShaderMaterial
var _parallax := Vector2.ZERO  # -1..1, eased toward the mouse
var _flare := 1.0
var _flicker_t := 0.0
var _splats: Array = []     # botched ink blots (back layer)
var _blots: Array = []      # big dark blots framing the corners (front layer)
var _scratches: Array = []  # bundles of thin bright scratches
var _marks: Array = []      # tiny blinking red glyphs
var _embers: Array = []


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
	_bg_mat = mat
	_build_decor()

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
	_hero.set_meta("base", _hero.position)
	for spot in [Vector2(925, 600), Vector2(1110, 586)]:
		var g := _outlined_group(spot, Vector2(-3.2, 3.2), RED)
		var v := Node2D.new()
		v.set_script(CrawlerVisual)
		g.add_child(v)
		add_child(g)
		g.set_meta("base", spot)
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
	_update_atmosphere(delta)
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
	_draw_back_decor()
	_draw_title()
	_draw_menu_links()
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
		"map":  # a little plateau seen from above, like the clearing
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 1), c + Vector2(0, -5), c + Vector2(8, 1), c + Vector2(0, 7)]), col)
			draw_circle(c + Vector2(0, 1), 2.5, RED)
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
	_draw_front_decor(o)
	_draw_cover_badge(o)
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


# ------------------------------------------------------------ atmosphere

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# [centre, radius, kind]: black ink on the pale strip, faint pale/red ink in the dark
	var spots := [
		[Vector2(118, 470), 46.0, 0], [Vector2(330, 120), 30.0, 0], [Vector2(40, 300), 38.0, 0],
		[Vector2(250, 650), 34.0, 0], [Vector2(560, 160), 26.0, 1], [Vector2(980, 230), 40.0, 1],
		[Vector2(760, 90), 22.0, 2], [Vector2(1150, 330), 24.0, 2], [Vector2(620, 470), 18.0, 2],
		[Vector2(470, 40), 16.0, 0], [Vector2(1240, 520), 30.0, 1],
	]
	for sp in spots:
		_splats.append(_make_splat(rng, sp[0], sp[1], sp[2], 0.25))
	for sp in [[Vector2(-40, 790), 175.0], [Vector2(1340, 790), 185.0], [Vector2(-50, -60), 120.0]]:
		_blots.append(_make_splat(rng, sp[0], sp[1], 3, 1.6, 0.3))
	for c in [[Vector2(40, 140), -1.15], [Vector2(150, 610), -1.25], [Vector2(1120, 160), 1.95],
			[Vector2(520, 690), -0.35], [Vector2(880, 40), 2.6]]:
		_scratches.append({"c": c[0], "a": c[1], "seed": rng.randi()})
	for i in 26:
		_marks.append({"p": Vector2(rng.randf_range(480, 1260), rng.randf_range(30, 560)),
			"k": rng.randi() % 4, "s": rng.randf_range(3.0, 7.0), "ph": rng.randf() * TAU,
			"rate": rng.randf_range(0.6, 2.4)})
	for i in 46:
		_embers.append(_new_ember(rng, true))


## Irregular ink splat, like ink hitting paper: a lumpy pool ringed with
## many thin splash spikes, streaks flung outward ending in droplets, a
## spray of loose droplets and a few thin drips running down.
## kind: 0 black, 1 pale, 2 red, 3 deep ink.
func _make_splat(rng: RandomNumberGenerator, c: Vector2, r: float, kind: int, depth: float, spray := 1.0) -> Dictionary:
	var body := PackedVector2Array()
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var n := 72
	var streaks: Array = []
	var drops: Array = []
	for i in n:
		var a := TAU * i / n
		var k: float = 1.0 + 0.16 * sin(3.0 * a + ph[0]) + 0.1 * sin(5.0 * a + ph[1]) + 0.05 * sin(11.0 * a + ph[2])
		if i % 2 == 1 and rng.randf() < 0.55:
			k *= rng.randf_range(1.12, 1.45)  # thin splash spike (one vertex wide)
		body.append(c + Vector2.from_angle(a) * r * k)
	for i in rng.randi_range(5, 9):
		# streak flung outward, thick at the pool, thin at the end, droplet on the tip
		var a := rng.randf() * TAU
		var from := c + Vector2.from_angle(a) * r * 0.85
		var to := c + Vector2.from_angle(a + rng.randf_range(-0.08, 0.08)) * r * (1.0 + spray * rng.randf_range(0.6, 1.6))
		var w := r * rng.randf_range(0.06, 0.12)
		streaks.append([from, to, w])
		drops.append([to, w * rng.randf_range(0.9, 1.5)])
	for i in rng.randi_range(10, 18):
		var d := 1.0 + spray * rng.randf_range(0.3, 2.2)
		drops.append([c + Vector2.from_angle(rng.randf() * TAU) * r * d, r * rng.randf_range(0.025, 0.09) / sqrt(d)])
	var drips: Array = []
	for i in rng.randi_range(2, 4):
		var x := c.x + rng.randf_range(-0.7, 0.7) * r
		drips.append([Vector2(x, c.y + r * 0.7), rng.randf_range(0.4, 1.6) * r, rng.randf_range(0.035, 0.07) * r, rng.randf() * TAU])
	return {"body": body, "streaks": streaks, "drops": drops, "drips": drips, "kind": kind, "depth": depth}


func _new_ember(rng: RandomNumberGenerator, anywhere: bool) -> Dictionary:
	return {"p": Vector2(rng.randf_range(480, 1280), rng.randf_range(80, 720) if anywhere else 730.0),
		"v": rng.randf_range(18.0, 55.0), "s": rng.randf_range(1.2, 3.2), "ph": rng.randf() * TAU,
		"life": rng.randf_range(4.0, 9.0), "age": rng.randf() * 4.0 if anywhere else 0.0}


func _update_atmosphere(delta: float) -> void:
	# parallax toward the mouse
	var m := (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
	_parallax = _parallax.lerp(m.clamp(Vector2(-1, -1), Vector2(1, 1)), 1.0 - exp(-3.0 * delta))
	_hero.position = _hero.get_meta("base") + _parallax * -10.0
	for v in _beetles:
		var g: Node2D = v.get_parent()
		g.position = g.get_meta("base") + _parallax * -12.0
	# failing light: mostly steady, with sudden flickers and surges
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		var burst := randf() < 0.3
		_flicker_t = randf_range(0.05, 0.12) if burst else randf_range(1.5, 4.0)
		_flare = randf_range(0.35, 1.5) if burst else 1.0
	_bg_mat.set_shader_parameter("flare", _flare)
	# embers drift up and respawn at the bottom
	var rng := RandomNumberGenerator.new()
	for e in _embers:
		e.age += delta
		e.p.y -= e.v * delta
		e.p.x += sin(_time * 1.3 + e.ph) * 12.0 * delta
		if e.age > e.life or e.p.y < -10.0:
			rng.randomize()
			var fresh := _new_ember(rng, false)
			for key in fresh:
				e[key] = fresh[key]


func _splat_color(kind: int) -> Color:
	match kind:
		0: return Color(INK, 0.82)
		1: return Color(PAPER, 0.1)
		2: return Color(RED, 0.3)
	return Color(0.02, 0.015, 0.025, 0.96)


func _draw_splat(ci: CanvasItem, sp: Dictionary, offset: Vector2) -> void:
	var col := _splat_color(sp.kind)
	ci.draw_set_transform(offset)
	ci.draw_colored_polygon(sp.body, col)
	for st in sp.streaks:
		var dir: Vector2 = (st[1] - st[0]).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		ci.draw_colored_polygon(PackedVector2Array([st[0] + nrm * st[2], st[1] + nrm * st[2] * 0.3,
			st[1] - nrm * st[2] * 0.3, st[0] - nrm * st[2]]), col)
	for d in sp.drops:
		ci.draw_circle(d[0], d[1], col)
	for d in sp.drips:
		# drips slowly creep down and back
		var len: float = d[1] * (0.85 + 0.15 * sin(_time * 0.5 + d[3]))
		ci.draw_line(d[0], d[0] + Vector2(0, len), col, d[2] * 2.0)
		ci.draw_circle(d[0] + Vector2(0, len), d[2] * 1.4, col)
	ci.draw_set_transform(Vector2.ZERO)


func _draw_back_decor() -> void:
	var off := _parallax * 4.0
	for sp in _splats:
		_draw_splat(self, sp, off * sp.depth * 4.0)
	# scratch bundles, re-scratched every ~1.5 s
	var epoch := int(_time / 1.5)
	for sc in _scratches:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(sc.seed, epoch))
		for k in rng.randi_range(5, 11):
			var a: float = sc.a + rng.randf_range(-0.12, 0.12)
			var start: Vector2 = sc.c + off + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
			var len := rng.randf_range(80.0, 330.0)
			var dir := Vector2.from_angle(a)
			var c := Color(PAPER, rng.randf_range(0.25, 0.85))
			draw_line(start, start + dir * len, c, rng.randf_range(0.8, 1.8), true)
			if rng.randf() < 0.3:  # splintered tail
				var mid := start + dir * len * 0.7
				draw_line(mid, mid + Vector2.from_angle(a + 0.25) * len * 0.3, Color(c, c.a * 0.6), 0.8, true)
	# blinking red glyphs in the dark
	for m in _marks:
		if sin(_time * m.rate + m.ph) < -0.3:
			continue
		var p: Vector2 = m.p + off * 2.0 + _jitter(300 + int(m.ph * 100.0), 1.5)
		var s: float = m.s
		var c := Color(RED, 0.75)
		match m.k:
			0:
				draw_rect(Rect2(p, Vector2(s * 2.2, s * 0.5)), c)
			1:
				draw_polyline(PackedVector2Array([p + Vector2(-s, s * 0.6), p + Vector2(0, -s), p + Vector2(s, s * 0.6), p + Vector2(-s, s * 0.6)]), c, 1.5)
			2:
				draw_line(p + Vector2(-s, -s), p + Vector2(s, s), c, 1.5)
				draw_line(p + Vector2(s, -s), p + Vector2(-s, s), c, 1.5)
			_:
				draw_rect(Rect2(p, Vector2(s * 0.6, s * 0.6)), c)


## Red dashed line threading the menu diamonds (node-map look), with a
## teal run down to the focused one.
func _draw_menu_links() -> void:
	var intro := clampf((_time - 0.9) / 0.5, 0.0, 1.0)
	if intro <= 0.0:
		return
	var x := BAR_POS.x + 26.0
	var top := BAR_POS.y + BAR_SIZE.y * 0.5
	var bottom := lerpf(top, top + (ENTRIES.size() - 1) * BAR_GAP, intro)
	var dash := 8.0
	var y := top + fmod(_time * 20.0, dash * 2.0) - dash * 2.0
	while y < bottom:
		var a := maxf(y, top)
		var b := minf(y + dash, bottom)
		if b > a:
			draw_line(Vector2(x, a), Vector2(x, b), Color(RED, 0.55), 2.0)
		y += dash * 2.0
	var fi := _buttons.find(get_viewport().gui_get_focus_owner())
	if fi > 0:
		draw_line(Vector2(x - 4, top), Vector2(x - 4, top + fi * BAR_GAP), Color(0.38, 0.85, 0.7, 0.7), 2.0)


func _draw_front_decor(o: Node2D) -> void:
	# embers in front of the fight
	for e in _embers:
		var a := clampf(e.age / 0.8, 0.0, 1.0) * clampf((e.life - e.age) / 1.5, 0.0, 1.0)
		var flick := 0.6 + 0.4 * sin(_time * 9.0 + e.ph * 5.0)
		var p: Vector2 = e.p + _parallax * -16.0
		o.draw_circle(p, e.s * 2.4, Color(RED, 0.15 * a * flick))
		o.draw_circle(p, e.s, Color(1.0, 0.55, 0.3, 0.85 * a * flick))
	# big dark corner blots, closest to the camera = most parallax
	for b in _blots:
		_draw_splat(o, b, _parallax * -22.0)
