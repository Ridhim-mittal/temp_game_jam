extends Control
## Vesper falls into the Margins: the cutscene between the end of the Long
## Drop (the Eraser's chase, eraser_chase.gd) and the 2.5D Gutter. About
## 12 s, all drawn in code, Enter skips.
##  1. THE PAGE (0-1.8 s): the frozen moment shrinks into a panel at the top
##     of a printed comic page; under it, between the page's two columns of
##     panels, runs the gutter, the white strip between them, and the camera
##     dives into it after him.
##  2. THE FALL (1.8-7 s): we fall with Vesper down the gutter. The panels of
##     his story slide up past him on both sides, in colour at first (the
##     City, a lantern, the Beast, himself, the Eraser), then greying,
##     crossed out in red, torn along the edge that faces the gutter, then
##     only pencil, then nothing; the gutter itself darkens from paper white
##     to ink. The Eraser scrubs at the top of the gap and its crumbs rain
##     down with him. Shade: "LET THE MARGINS HAVE YOU."
##  3. THE DARK (7-9.6 s): no more panels. Pairs of Scribble eyes open in the
##     dark either side and watch him go by; Shade's lettering stamps THE END
##     below him. Then his Ember flares in his hand: the eyes flinch shut and
##     the light burns "END" away. Vesper: "NOT YET."
##  4. THE FLOOR (9.6-11.2 s): the floor of the Margins rushes up, its
##     Writer's marks glowing, and he lands in a burst of ink.
##  5. "THE MARGINS" on black (11.2-12.6 s), then World25 takes over
##     (fall_in_from_panel(): he drops out of the sky into the hub).
##
##   MarginsFall.start(any_node, platformer_player)

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const PlayerArt = preload("res://scripts/player/player_visual.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const EraserArt = preload("res://scripts/enemies/eraser_art.gd")
const CaptionStyle = preload("res://scripts/ui/caption_style.gd")
const PAPER := Color(0.96, 0.93, 0.86)
const INK := Color(0.04, 0.03, 0.07)
const DARK := Color(0.02, 0.018, 0.03)
const RED := Color(0.86, 0.16, 0.14)
const EMBER := Color(1.0, 0.62, 0.2)
const EMBER_CORE := Color(1.0, 0.93, 0.7)
const CAPTION := Color(1.0, 0.9, 0.45)
const PINK := Color(0.9, 0.45, 0.5)
## The gutter's width on screen once we're in it.
const GUTTER_W := 300.0
const PANEL_W := 360.0
const ROW_GAP := 28.0

const T_PAGE := 1.0     # the frame has become a panel
const T_DIVE := 1.8     # in the gutter
const T_DARK := 7.0     # past the last panel
const T_END_STAMP := 7.7
const T_EMBER := 8.5
const T_FLOOR := 9.6
const T_LAND := 10.6
const T_TITLE := 11.2
const T_DONE := 12.7

var _shot: Texture2D
var _health_frac := 1.0
var _t := 0.0
var _done := false
var _skip := false
var _batch := InkBatch.new()
var _vesper: Node2D
var _front: Control
var _fired := {}
var _bits: Array = []  # falling scraps alongside him: [x, y, speed, size, kind, spin]
var _rng := RandomNumberGenerator.new()


static func start(from: Node, player: Node) -> void:
	var tree := from.get_tree()
	var fx = load("res://scripts/effects/margins_fall.gd").new()
	fx._shot = ImageTexture.create_from_image(from.get_viewport().get_texture().get_image())
	if player and "health" in player and "max_health" in player:
		fx._health_frac = clampf(float(player.health) / maxf(float(player.max_health), 1.0), 0.0, 1.0)
	if player:
		player.remove_from_group("player")  # World25.go must not read platformer stats
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fx)
	tree.current_scene.add_child(layer)
	tree.paused = true


func _ready() -> void:
	_rng.seed = 41
	_vesper = PlayerArt.new()
	_vesper.velocity = Vector2(0, 700)
	_vesper.on_floor = false
	_vesper.visible = false
	add_child(_vesper)
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)
	for i in 26:
		_bits.append([_rng.randf_range(-1.0, 1.0), _rng.randf(), _rng.randf_range(0.4, 1.4), _rng.randf_range(4, 12),
			_rng.randi() % 3, _rng.randf_range(-6, 6)])


func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]) \
			or InputSetup.pad_skip(event):  # (a controller: A / Start)
		get_viewport().set_input_as_handled()
		if _t < T_TITLE:
			_t = T_TITLE
			_skip = true


func _at(t: float) -> bool:
	if _t >= t and not _fired.has(t):
		_fired[t] = true
		return not _skip or t >= T_TITLE
	return false


func _process(delta: float) -> void:
	_t += delta
	_sounds()
	_update_vesper()
	queue_redraw()
	_front.queue_redraw()
	if _t >= T_DONE and not _done:
		_done = true
		var world := get_node_or_null("/root/World25")
		if world:
			world.fall_in_from_panel(_health_frac)
		else:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/clearing/clearing.tscn")


func _sounds() -> void:
	var tree := get_tree()
	if _at(0.3):
		SfxSynth.play(tree, "whoosh", -2.0, 0.6)
	if _at(T_DIVE):
		SfxSynth.play(tree, "rumble", -4.0, 1.3)
	if _at(2.3) or _at(2.7) or _at(3.1):
		SfxSynth.play(tree, "scritch", -6.0, 0.7)
	if _at(4.4):
		SfxSynth.play(tree, "whoosh", -4.0, 0.5)
	if _at(T_DARK):
		SfxSynth.play(tree, "rumble", -6.0, 0.7)
	if _at(T_END_STAMP):
		SfxSynth.play(tree, "thud", -2.0, 1.4)
	if _at(T_EMBER):
		SfxSynth.play(tree, "whoosh", 0.0, 1.6)
	if _at(T_LAND):
		SfxSynth.play(tree, "thud", 2.0, 0.7)
		SfxSynth.play(tree, "splut", 0.0, 0.6)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## How far down we are (px of page fallen past since the dive).
func _depth() -> float:
	if _t < T_DIVE:
		return 0.0
	# fast at first, slowing into the dark, then dropping again at the floor
	var t := _t - T_DIVE
	return t * 900.0 - minf(t, 5.2) * minf(t, 5.2) * 40.0


## 0 = paper-white comic gutter .. 1 = the Margins' ink.
func _darkness() -> float:
	return _ease((_t - T_DIVE - 0.8) / (T_DARK - T_DIVE - 0.8))


func _update_vesper() -> void:
	var s := size
	var show := _t > T_PAGE * 0.6 and _t < T_TITLE
	_vesper.visible = show
	if not show:
		return
	var k := _ease((_t - T_PAGE * 0.6) / (T_DIVE - T_PAGE * 0.6))
	var sc := lerpf(0.7, 2.4, k)
	var pos := Vector2(s.x * 0.5, lerpf(s.y * 0.3, s.y * 0.44, k))
	var spin := sin(_t * 2.6) * 0.55 + _t * 0.4
	if _t > T_EMBER:
		# the Ember steadies him: he rights himself, reaching down
		var e := _ease((_t - T_EMBER) / 0.6)
		spin = lerpf(spin, 0.0, e)
		sc = lerpf(sc, 2.6, e)
	if _t > T_FLOOR:
		pos.y += (_t - T_FLOOR) * 60.0
	_vesper.position = pos
	_vesper.rotation = spin
	_vesper.scale = Vector2(sc, sc)
	_vesper.velocity = Vector2(sin(_t * 3.0) * 120.0, 900.0)
	_vesper.on_floor = false


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var s := size
	if _t < T_DIVE:
		_draw_page(s)
	else:
		_draw_shaft(s)
	_batch.flush(self)
	# the frozen frame as the top panel, on the page
	if _t < T_DIVE:
		var r := _panel_rect(s)
		draw_set_transform_matrix(_page_xf(s))
		draw_texture_rect(_shot, r, false)
		draw_rect(r, INK, false, 6.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Page space -> screen during the page part: shrink out to the page, then
## dive into the gutter under our panel.
func _page_xf(s: Vector2) -> Transform2D:
	var dive := _ease((_t - T_PAGE) / (T_DIVE - T_PAGE))
	var zoom := lerpf(1.0, 2.4, dive * dive)
	var focus := Vector2(s.x * 0.5, lerpf(s.y * 0.5, s.y * 0.95, dive))
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, s * 0.5 - focus * zoom)


## Where the frozen frame ends up: the top-left panel of the page.
func _panel_rect(s: Vector2) -> Rect2:
	var k := _ease(_t / T_PAGE)
	var full := Rect2(Vector2.ZERO, s)
	var gx := s.x * 0.5
	var small := Rect2(gx - GUTTER_W * 0.15 - s.x * 0.36, s.y * 0.08, s.x * 0.36, s.y * 0.42)
	return Rect2(full.position.lerp(small.position, k), full.size.lerp(small.size, k))


func _draw_page(s: Vector2) -> void:
	var xf := _page_xf(s)
	_batch.draw_set_transform_matrix(xf)
	var k := _ease(_t / T_PAGE)
	_batch.draw_rect(Rect2(-s.x, -s.y, s.x * 3.0, s.y * 4.0), PAPER)
	# the page's other panels: the right column, and the rows below ours
	var gx := s.x * 0.5
	var gw := GUTTER_W * 0.3
	var col_r := Rect2(gx + gw * 0.5, s.y * 0.08, s.x * 0.36, s.y * 0.42)
	var panels := [col_r, Rect2(col_r.position.x, col_r.end.y + 20, col_r.size.x, s.y * 0.5),
		Rect2(gx - gw * 0.5 - s.x * 0.36, s.y * 0.08 + s.y * 0.42 + 20, s.x * 0.36, s.y * 0.5)]
	for i in panels.size():
		var r: Rect2 = panels[i]
		_vignette(r, i + 1, 0.0, k)
		_batch.draw_rect(r, Color(INK, k), false, 5.0)
	# tiny Vesper slipping out of the bottom of our panel into the gutter
	_batch.draw_set_transform_matrix(Transform2D.IDENTITY)


## The fall: the gutter down the middle, columns of panels either side.
func _draw_shaft(s: Vector2) -> void:
	var dk := _darkness()
	var depth := _depth()
	var cx := s.x * 0.5
	var gl := cx - GUTTER_W * 0.5
	var gr := cx + GUTTER_W * 0.5
	# the gutter (and everything behind the panels): paper white, greying to ink
	_batch.draw_rect(Rect2(Vector2.ZERO, s), PAPER.lerp(DARK, dk))
	# panels: two columns either side, scrolling up as we fall
	if _t < T_DARK + 0.6:
		for side: float in [-1.0, 1.0]:
			var x0 := gl - PANEL_W if side < 0.0 else gr
			var y := -depth
			var i := 0
			while y < s.y + 40.0 and i < 200:
				var h := 170.0 + 140.0 * _hash(i * 7 + (3 if side > 0.0 else 0))
				if y + h > -40.0:
					var pd := clampf((depth + y) / 4200.0, 0.0, 1.0)  # how deep this panel sits
					var r := Rect2(x0 + (12.0 if side < 0.0 else 0.0), y, PANEL_W - 12.0, h)
					_dead_panel(r, i * 2 + (1 if side > 0.0 else 0), pd, side)
				y += h + ROW_GAP
				i += 1
	# the inner edges of the gutter: the panels' ink borders, fraying as it darkens
	var edge_a := 1.0 - dk * 0.7
	for x: float in [gl, gr]:
		_batch.draw_line(Vector2(x, 0), Vector2(x, s.y), Color(INK, edge_a), 5.0)
	# speed lines down the gutter
	var streaks := 22
	for i in streaks:
		var x := gl + GUTTER_W * _hash(i * 13 + 1)
		var ln := 60.0 + 120.0 * _hash(i * 5 + 2)
		var y := fposmod(-depth * (1.4 + _hash(i) * 0.8) + i * 97.0, s.y + ln) - ln
		var col := INK.lerp(Color(0.8, 0.82, 0.9), dk)
		_batch.draw_line(Vector2(x, y), Vector2(x, y + ln), Color(col, 0.25 + 0.15 * dk), 1.5)
	# the dark: eyes opening either side, flinching from the Ember
	if _t > T_DARK - 0.6:
		_eyes(s)
	# the Ember's light round him
	if _t > T_EMBER:
		var e := _ease((_t - T_EMBER) / 0.4) * (1.0 - _ease((_t - T_LAND) / 0.4))
		var at := _hand()
		for k in 14:
			_batch.draw_circle(at, (360.0 - k * 24.0) * e, Color(EMBER, 0.035 * e))
	# the floor of the Margins rushing up
	if _t > T_FLOOR:
		_floor(s)


## Where his Ember burns: by his hand, in front of him.
func _hand() -> Vector2:
	return _vesper.position + Vector2(16, -22).rotated(_vesper.rotation) * _vesper.scale.x


## A dead panel: what it shows, then greyed, crossed out, torn, pencil, gone.
func _dead_panel(r: Rect2, i: int, pd: float, side: float) -> void:
	var alive := 1.0 - _ease(pd / 0.35)
	var gone := _ease((pd - 0.7) / 0.25)
	if gone >= 1.0:
		return
	var a := 1.0 - gone
	var kind := i % 6
	var torn := _ease((pd - 0.4) / 0.2)
	var pencil := _ease((pd - 0.55) / 0.15)
	if pencil < 1.0:
		_vignette(r, kind, 1.0 - alive, a * (1.0 - pencil))
	# torn along the edge that faces the gutter
	if torn > 0.0:
		var edge := r.end.x if side < 0.0 else r.position.x
		var pts := PackedVector2Array()
		var n := int(r.size.y / 16.0)
		for k in n + 1:
			var y := r.position.y + r.size.y * k / n
			var bite := (10.0 + 26.0 * _hash(i * 31 + k)) * torn
			pts.append(Vector2(edge - side * bite, y))
		pts.append(Vector2(edge + side * 4.0, r.end.y))
		pts.append(Vector2(edge + side * 4.0, r.position.y))
		_batch.draw_colored_polygon(pts, PAPER.lerp(DARK, _darkness()))
	# the border: inked, then only pencil, dashed
	if pencil < 1.0:
		_batch.draw_rect(r, Color(INK, a * (1.0 - pencil)), false, 4.0)
	if pencil > 0.0:
		var pc := Color(0.55, 0.55, 0.6, a * pencil * 0.7)
		var y := r.position.y
		while y < r.end.y:
			_batch.draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + 14, r.end.y)), pc, 1.2)
			_batch.draw_line(Vector2(r.end.x, y), Vector2(r.end.x, minf(y + 14, r.end.y)), pc, 1.2)
			y += 24.0
		var x := r.position.x
		while x < r.end.x:
			_batch.draw_line(Vector2(x, r.position.y), Vector2(minf(x + 14, r.end.x), r.position.y), pc, 1.2)
			x += 24.0
	# crossed out in red, the Writer's way
	var cross := _ease((pd - 0.25) / 0.12) * (1.0 - pencil)
	if cross > 0.0:
		var c := Color(RED, 0.85 * cross * a)
		_batch.draw_line(r.position + Vector2(14, 14), r.end - Vector2(14, 14), c, 7.0)
		_batch.draw_line(Vector2(r.end.x - 14, r.position.y + 14), Vector2(r.position.x + 14, r.end.y - 14), c, 7.0)


## What a panel shows, flat and simple; `grey` 0..1 drains its colour.
func _vignette(r: Rect2, kind: int, grey: float, a: float) -> void:
	if a <= 0.0:
		return
	var c := func(col: Color) -> Color:
		var l := col.get_luminance()
		return Color(col.lerp(Color(l, l, l), grey), col.a * a)
	var mid := r.get_center()
	match kind:
		0:  # the City at night
			_batch.draw_rect(r, c.call(Color(0.12, 0.2, 0.42)))
			_batch.draw_circle(r.position + r.size * Vector2(0.75, 0.25), r.size.y * 0.1, c.call(Color(0.98, 0.95, 0.8)))
			for k in 6:
				var bw := r.size.x / 6.0
				var bh := r.size.y * (0.3 + 0.4 * _hash(k + 3))
				var b := Rect2(r.position.x + k * bw, r.end.y - bh, bw - 4, bh)
				_batch.draw_rect(b, c.call(Color(0.05, 0.06, 0.14)))
				_batch.draw_rect(Rect2(b.position + Vector2(6, 10), Vector2(6, 8)), c.call(Color(1.0, 0.85, 0.4)))
		1:  # a lantern
			_batch.draw_rect(r, c.call(Color(0.1, 0.08, 0.12)))
			for k in 6:
				_batch.draw_circle(mid, r.size.y * (0.4 - k * 0.055), c.call(Color(1.0, 0.6, 0.3, 0.07)))
			_batch.draw_rect(Rect2(mid - Vector2(18, 24), Vector2(36, 48)), c.call(Color(0.92, 0.3, 0.24)))
			_batch.draw_line(mid - Vector2(0, 24), Vector2(mid.x, r.position.y + 6), c.call(INK), 2.0)
		2:  # the Beast's stare
			_batch.draw_rect(r, c.call(Color(0.04, 0.04, 0.07)))
			for k in 3:
				var e := mid + Vector2((k - 1) * r.size.x * 0.22, -r.size.y * 0.12 + (k % 2) * 16.0)
				_batch.draw_circle(e, 13.0, c.call(Color(0.98, 0.97, 0.92)))
				_batch.draw_circle(e, 3.0, c.call(INK))
			for k in 9:
				var x := mid.x - r.size.x * 0.3 + k * r.size.x * 0.075
				_batch.draw_colored_polygon(PackedVector2Array([Vector2(x, mid.y + 20), Vector2(x + 12, mid.y + 20), Vector2(x + 6, mid.y + 40)]), c.call(Color(0.98, 0.97, 0.92)))
		3:  # Vesper himself: the hat and the egg head
			_batch.draw_rect(r, c.call(Color(0.96, 0.82, 0.55)))
			_batch.draw_circle(mid + Vector2(0, 16), r.size.y * 0.16, c.call(Color(0.98, 0.96, 0.9)))
			_batch.draw_rect(Rect2(mid + Vector2(-r.size.y * 0.24, -r.size.y * 0.08), Vector2(r.size.y * 0.48, 10)), c.call(Color(0.14, 0.11, 0.16)))
			_batch.draw_rect(Rect2(mid + Vector2(-r.size.y * 0.13, -r.size.y * 0.3), Vector2(r.size.y * 0.26, r.size.y * 0.22)), c.call(Color(0.14, 0.11, 0.16)))
			_batch.draw_rect(Rect2(mid + Vector2(-r.size.y * 0.13, -r.size.y * 0.13), Vector2(r.size.y * 0.26, 7)), c.call(Color(0.92, 0.3, 0.2)))
		4:  # the Eraser (eraser_art.gd), scrubbing the paper behind it blank
			_batch.draw_rect(r, c.call(Color(0.86, 0.84, 0.8)))
			_batch.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.3, r.size.x, r.size.y * 0.3), c.call(Color(0.98, 0.97, 0.94)))
			var k := minf(r.size.y * 0.64, r.size.x * 0.5) / EraserArt.H
			EraserArt.draw_into(_batch, Transform2D(0.0, Vector2(k, k), 0.0, Vector2(mid.x, r.end.y - r.size.y * 0.1)),
				{"time": _t, "rubbing": 1.0, "roar": 0.6}, c)
		_:  # the Sketchbook: a page of pencil and blue
			_batch.draw_rect(r, c.call(Color(0.93, 0.92, 0.88)))
			var y := r.position.y + 12.0
			while y < r.end.y:
				_batch.draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y), c.call(Color(0.6, 0.72, 0.9, 0.6)), 1.0)
				y += 18.0
			_batch.draw_line(r.position + Vector2(20, r.size.y * 0.7), r.end - Vector2(20, r.size.y * 0.3), c.call(Color(0.3, 0.5, 0.95)), 3.0)


## Pairs of Scribble eyes in the dark, either side of the gutter; they open
## as he passes and flinch shut when the Ember flares.
func _eyes(s: Vector2) -> void:
	var open := _ease((_t - T_DARK + 0.6) / 0.8)
	var flinch := _ease((_t - T_EMBER) / 0.25)
	for i in 12:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := s.x * 0.5 + side * (GUTTER_W * 0.5 + 60.0 + 260.0 * _hash(i * 3 + 7))
		var y := fposmod(s.y * _hash(i * 11 + 5) - (_depth() - 4200.0) * 0.35, s.y + 120.0) - 60.0
		var o := clampf(open * 1.6 - _hash(i) * 0.6, 0.0, 1.0) * (1.0 - flinch)
		if o <= 0.02:
			continue
		var red := i % 4 == 1
		var col := Color(1.0, 0.25, 0.18) if red else Color(0.96, 0.95, 0.9)
		var blink := 1.0 if fmod(_t * 0.7 + _hash(i * 2), 1.0) > 0.06 else 0.1
		for e: float in [-1.0, 1.0]:
			var c := Vector2(x + e * 13.0, y)
			var pts := PackedVector2Array()
			for k in 8:
				var a := TAU * k / 8.0
				pts.append(c + Vector2(cos(a) * 8.0, sin(a) * 5.0 * o * blink))
			# the angry slant: the inner corner pulled down
			pts[4 if e > 0.0 else 0] += Vector2(0, 3.0)
			_batch.draw_colored_polygon(pts, Color(col, 0.85 * o))
		# a scribble round them, barely there
		for k in 3:
			var a0 := _hash(i * 5 + k) * TAU
			_batch.draw_arc(Vector2(x, y), 26.0 + k * 4.0, a0, a0 + 4.0, 10, Color(0.3, 0.3, 0.36, 0.35 * o), 1.4)


## The floor of the Margins: dark ground with the Writer's marks glowing.
func _floor(s: Vector2) -> void:
	var k := _ease((_t - T_FLOOR) / (T_LAND - T_FLOOR))
	var top := lerpf(s.y + 40.0, s.y * 0.62, k)
	_batch.draw_rect(Rect2(0, top, s.x, s.y - top + 10), Color(0.05, 0.045, 0.07))
	_batch.draw_line(Vector2(0, top), Vector2(s.x, top), Color(0.35, 0.3, 0.45, 0.8), 2.0)
	for i in 9:
		var x := s.x * (i + 0.5) / 9.0 + (_hash(i) - 0.5) * 60.0
		var y := top + 18.0 + _hash(i + 9) * 30.0
		var glow := Color(0.6, 0.85, 1.0, 0.35 + 0.25 * sin(_t * 3.0 + i))
		# a mark: the watching eye
		_batch.draw_arc(Vector2(x, y), 9.0, PI * 1.1, PI * 1.9, 6, glow, 1.6)
		_batch.draw_arc(Vector2(x, y - 10.0), 9.0, PI * 0.1, PI * 0.9, 6, glow, 1.6)
		_batch.draw_circle(Vector2(x, y - 5.0), 2.0, glow)
	# the landing: an ink splash
	if _t > T_LAND:
		var sp := _ease((_t - T_LAND) / 0.35)
		var at := Vector2(s.x * 0.5, top)
		for i in 14:
			var a := PI + PI * (i + 0.5) / 14.0
			var ln := (60.0 + 120.0 * _hash(i + 30)) * sp
			_batch.draw_circle(at + Vector2.from_angle(a) * ln, (9.0 + 8.0 * _hash(i)) * (1.0 - sp * 0.5), INK)
		_batch.draw_circle(at, 70.0 * sp, Color(INK, 1.0 - sp * 0.3))
		_batch.draw_arc(at, 40.0 + 260.0 * sp, PI, TAU, 32, Color(0.85, 0.9, 1.0, 0.8 * (1.0 - sp)), 4.0)
		for i in 10:
			var a := PI + PI * (i + 0.5) / 10.0
			_batch.draw_line(at + Vector2.from_angle(a) * (30.0 + 80.0 * sp), at + Vector2.from_angle(a) * (60.0 + 200.0 * sp),
				Color(0.9, 0.92, 1.0, 0.6 * (1.0 - sp)), 2.0)


func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 4.1) * 43758.5453, 1.0)


# ------------------------------------------------------------------ foreground

func _draw_front() -> void:
	var c := _front
	var s := size
	var fb := InkBatch.new()
	# scraps of paper and the Eraser's crumbs falling with him
	if _t > T_DIVE - 0.3 and _t < T_TITLE:
		for b in _bits:
			var x: float = s.x * 0.5 + b[0] * GUTTER_W * 0.7
			var y: float = fposmod(b[1] * s.y - _depth() * (b[2] - 1.0) * 0.4, s.y + 40.0) - 20.0
			var a := 1.0 - _ease((_t - T_DARK) / 1.5) * 0.6
			match b[4]:
				0:
					var r := Rect2(Vector2(x, y), Vector2(b[3] * 1.4, b[3])).grow(1.0)
					fb.draw_set_transform(r.get_center(), _t * b[5] * 0.3)
					fb.draw_rect(Rect2(-r.size * 0.5, r.size), Color(PAPER.lerp(Color(0.5, 0.5, 0.55), _darkness()), a))
					fb.draw_set_transform(Vector2.ZERO)
				1:
					fb.draw_circle(Vector2(x, y), b[3] * 0.4, Color(PINK, a * (1.0 - _darkness() * 0.5)))
				_:
					fb.draw_circle(Vector2(x, y), b[3] * 0.35, Color(INK.lerp(Color(0.6, 0.6, 0.7), _darkness()), a))
	# the Eraser up at the top of the gap, scrubbing, shrinking away
	if _t > T_DIVE and _t < 4.6:
		var k := _ease((_t - T_DIVE) / 2.6)
		var w := lerpf(380.0, 60.0, k)
		var cx := s.x * 0.5 + sin(_t * 20.0) * 24.0 * (1.0 - k)
		var top := lerpf(-60.0, -10.0, k)
		# hanging over the lip of the gap, scrubbing it: the skull glaring down after
		# him, red-eyed, claws raking at the edge (eraser_art.gd)
		var ks := w / EraserArt.W
		EraserArt.draw_into(fb, Transform2D(0.0, Vector2(ks, ks), 0.0, Vector2(cx, top + EraserArt.H * ks * 0.62)),
			{"time": _t, "rubbing": 1.0, "roar": 0.8, "rage": 1.0, "windup": 0.4})
	if _t > T_EMBER and _t < T_LAND + 0.3:
		var e := _ease((_t - T_EMBER) / 0.3)
		var h := _hand()
		var fl := sin(_t * 30.0) * 2.0
		fb.draw_colored_polygon(PackedVector2Array([h + Vector2(-9, 4) * e, h + Vector2(0, -26 + fl) * e, h + Vector2(9, 4) * e, h + Vector2(0, 10) * e]), EMBER)
		fb.draw_colored_polygon(PackedVector2Array([h + Vector2(-4, 4) * e, h + Vector2(0, -12 + fl) * e, h + Vector2(4, 4) * e, h + Vector2(0, 7) * e]), EMBER_CORE)
	fb.flush(c)
	# captions
	if _t > 2.9 and _t < 5.8:
		_balloon_shade(c, s, "LET THE MARGINS HAVE YOU.", (_t - 2.9), 5.8 - 2.9)
	if _t > T_END_STAMP and _t < T_LAND:
		_the_end(c, s)
	if _t > T_EMBER + 0.5 and _t < T_LAND + 0.2:
		_balloon_vesper(c, "NOT YET.", _t - T_EMBER - 0.5, T_LAND + 0.2 - T_EMBER - 0.5)
	# "THE MARGINS"
	if _t > T_TITLE:
		_title(c, s)


## Shade's lettering stamped below him: THE END. The Ember burns "END" away.
func _the_end(c: Control, s: Vector2) -> void:
	var stamp := _ease((_t - T_END_STAMP) / 0.15)
	var burn := _ease((_t - T_EMBER - 0.2) / 0.7)
	var fs := int(lerpf(140.0, 92.0, stamp))
	var a := stamp * (1.0 - _ease((_t - T_FLOOR) / 0.6))
	var y := s.y * 0.82 - (_t - T_END_STAMP) * 30.0
	var w1 := FONT.get_string_size("THE ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := FONT.get_string_size("END", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (s.x - w1 - w2) * 0.5
	c.draw_string_outline(FONT, Vector2(x, y), "THE ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.6, 0.05, 0.05, a))
	c.draw_string(FONT, Vector2(x, y), "THE ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.02, 0.03, a))
	if burn < 1.0:
		var ea := a * (1.0 - burn)
		var col := Color(0.08, 0.02, 0.03).lerp(EMBER, burn * 1.6)
		c.draw_string_outline(FONT, Vector2(x + w1, y), "END", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.6, 0.05, 0.05, ea))
		c.draw_string(FONT, Vector2(x + w1, y), "END", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, ea))
	if burn > 0.0 and burn < 1.0:
		# embers flying off the burning word
		for i in 18:
			var p := Vector2(x + w1 + w2 * _hash(i), y - fs * 0.4 - burn * 120.0 * _hash(i + 3))
			c.draw_circle(p, 3.0 * (1.0 - burn), Color(EMBER_CORE, 1.0 - burn))


## Shade's black balloon with blood-red letters, top centre, shaking.
func _balloon_shade(c: Control, s: Vector2, text: String, t: float, dur: float) -> void:
	var a := clampf(t / 0.2, 0.0, 1.0) * clampf((dur - t) / 0.3, 0.0, 1.0)
	var shown := text.substr(0, int(t * 30.0))
	var fs := 34
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var shake := Vector2(randf_range(-2, 2), randf_range(-2, 2))
	var box := Rect2(s.x * 0.5 - w * 0.5 - 30.0, 52.0, w + 60.0, 66.0)
	box.position += shake
	CaptionStyle.panel(c, box, "shade", a)  # Shade's red caption panel
	c.draw_string(FONT, box.position + Vector2(30, 46), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CaptionStyle.text_color("shade", a))


## Vesper's yellow caption panel, over his head.
func _balloon_vesper(c: Control, text: String, t: float, dur: float) -> void:
	var a := clampf(t / 0.15, 0.0, 1.0) * clampf((dur - t) / 0.2, 0.0, 1.0)
	var fs := 30
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := _vesper.position + Vector2(90, -150)
	var box := Rect2(at - Vector2(w * 0.5 + 20, 26), Vector2(w + 40, 52))
	c.draw_colored_polygon(PackedVector2Array([Vector2(box.position.x + 24, box.end.y - 2), Vector2(box.position.x + 50, box.end.y - 2),
		_vesper.position + Vector2(30, -70)]), Color(CaptionStyle.YELLOW, a))
	CaptionStyle.panel(c, box, "vesper", a)  # Vesper's yellow caption panel
	c.draw_string(FONT, box.position + Vector2(20, 37), text.substr(0, int(t * 24.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CaptionStyle.text_color("vesper", a))


func _title(c: Control, s: Vector2) -> void:
	var k := _t - T_TITLE
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(DARK, clampf(k / 0.25, 0.0, 1.0)))
	var a := clampf((k - 0.2) / 0.4, 0.0, 1.0) * clampf((T_DONE - _t) / 0.35, 0.0, 1.0)
	var title := "THE MARGINS"
	var fs := 96
	var w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2((s.x - w) * 0.5, s.y * 0.48)
	c.draw_string_outline(FONT, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0, 0, 0, a))
	c.draw_string(FONT, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.9, 0.84, a))
	c.draw_line(p + Vector2(0, 18), p + Vector2(w * clampf((k - 0.3) / 0.5, 0.0, 1.0), 14), Color(0.86, 0.2, 0.18, a), 5.0)
	var sub := "WHERE THE WRITER'S MISTAKES GO"
	var sw := FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(FONT, Vector2((s.x - sw) * 0.5, s.y * 0.48 + 64.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.62, 0.6, 0.7, a))
