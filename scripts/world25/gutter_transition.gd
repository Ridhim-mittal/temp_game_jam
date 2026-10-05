extends Control
## "Down the gutter": the way from one Gutter room to the next (World25.go()
## with `through_gutter`, which a gate's way on uses). The Margins are the
## gutters between a comic's panels, so moving on is a trip down one:
##  1. the frozen frame shrinks into a panel on a comic page,
##  2. the view drops into the slit beside it (the gutter between two columns
##     of printed panels) and runs down it, the panels sliding past either
##     side, a tiny ink Vesper running ahead and a line of light drawing
##     itself behind him (the gates' line). The next room loads in the
##     background meanwhile,
##  3. it comes out beside the next panel, a pencil rough with the zone's
##     name; the new room is built behind the page (the tree is paused once
##     it has settled), ink floods the panel, which is a window onto the
##     live room, and the panel opens out to the screen.
## 3D can't be scaled like panel_turn.gd's 2D levels, so the window shows
## the room at its own size (the middle of the screen, where Vesper is) and
## simply grows. Lives on World25's layer, so it survives the scene change.
##
##   var fx := GutterTransition.new()
##   fx.target = "res://scenes/world25/rooms/darkwood_1.tscn"
##   fx.capture(get_viewport())   # the frame being left
##   layer.add_child(fx)
##   await fx.finished

signal finished

const ComicFrame = preload("res://scripts/ui/comic_frame.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.94, 0.91, 0.84)
const PANEL_PAPER := Color(0.99, 0.97, 0.92)
const PENCIL := Color(0.55, 0.53, 0.5)
const CAPTION := Color(1.0, 0.9, 0.45)
const LIGHT := Color(1.0, 0.88, 0.55)
const SCARF := Color(0.86, 0.2, 0.16)
const CLOAK := Color(0.2, 0.1, 0.28)
## The printed panels' inks (muted, like the Margins' comic backdrop).
const PRINT := [Color(0.25, 0.55, 0.6), Color(0.85, 0.66, 0.26), Color(0.82, 0.45, 0.55), Color(0.42, 0.33, 0.6),
	Color(0.62, 0.62, 0.6)]
const NIGHT := Color(0.13, 0.16, 0.3)
## The zones' names for the next panel's pencilled title, by room file prefix.
const ZONES := {"clearing": "THE SPINE", "darkwood": "THE INKWOOD", "shallows": "THE DROWNED MARGIN",
	"wastes": "THE TORN WASTES", "arena": "THE RUBBING ROOM"}

## A column's width (page units: screen pixels at zoom 1).
const CW := 460.0
## The gutters between the columns: the slits.
const SLIT := 56.0
## The gutters between the rows.
const ROW_GAP := 34.0
## Rows travelled down the slit.
const ROWS := 2
## Zoom while running down the slit.
const Z_SLIT := 2.2
const T_SHRINK := 0.45
const T_DIVE0 := 0.3  # the dive starts while the frame is still shrinking
const T_DIVE := 0.8  # in the slit
const T_RUN := 1.6  # at the next panel's row
const T_OUT := 1.95  # beside the next panel
const T_INK := 0.4
const T_OPEN0 := 0.28  # the panel starts opening before the ink is quite done
const T_OPEN := 0.65
const SETTLE_FRAMES := 3

## The room to load.
var target := ""
var _shot: Texture2D
var _title := ""
var _s := Vector2(640, 360)  # the screen's centre
var _p1 := Rect2()  # the panel being left
var _p2 := Rect2()  # the next one
var _gx := 640.0  # the slit's centre line
var _panels: Array[Rect2] = []
var _t := 0.0
var _stage := 0  # 0 the old room, 1 building the new one, 2 revealing it
var _t2 := 0.0
var _frames := 0
var _loading := false
var _page: Node2D  # the printed page (drawn once, moved with the view)
var _front: Node2D
var _dots: ImageTexture


## Freeze the frame being left (call before adding it to the tree).
func capture(vp: Viewport) -> void:
	var tex := vp.get_texture()
	var img: Image = tex.get_image() if tex else null
	if img and not img.is_empty():
		_shot = ImageTexture.create_from_image(img)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sz := size if size.x > 1.0 and size.y > 1.0 else Vector2(1280, 720)
	_s = sz * 0.5
	_gx = _s.x
	var ph := CW * sz.y / sz.x
	_p1 = Rect2(_gx - SLIT * 0.5 - CW, _s.y - ph * 0.5, CW, ph)
	_p2 = Rect2(_gx + SLIT * 0.5, _p1.position.y + ROWS * (ph + ROW_GAP), CW, ph)
	_title = ZONES.get(target.get_file().get_basename().get_slice("_", 0), "")
	_loading = ResourceLoader.load_threaded_request(target) == OK
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 9:
			var d := Vector2(x - 4, y - 4).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(2.4 - d, 0.0, 1.0)))
	_dots = ImageTexture.create_from_image(img)
	_layout()
	_page = Node2D.new()
	_page.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_page.draw.connect(_draw_page)
	add_child(_page)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)
	get_tree().paused = true
	Engine.time_scale = 1.0  # a hit-stop must not slow the page down
	_page.transform = _view()


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)  # a long frame (the room building) never skips the animation
	match _stage:
		0:
			_t += delta
			if _t >= T_OUT:
				_t = T_OUT
				var packed := _loaded()
				if packed:
					_stage = 1
					_frames = 0
					get_tree().paused = false
					get_tree().change_scene_to_packed(packed)
		1:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == target:
				# a few frames behind the page: the room places Vesper at the
				# gate and its camera finds him; then it holds still
				_frames += 1
				get_tree().paused = _frames > SETTLE_FRAMES
				if _frames > SETTLE_FRAMES:
					_stage = 2
					_t2 = 0.0
					for cam in get_tree().get_nodes_in_group("camera"):
						if cam.has_method("skip_fade"):
							cam.skip_fade()  # its fade from black would hang, paused, over the reveal
		2:
			_t2 += delta
			if _t2 >= T_OPEN0 + T_OPEN:
				get_tree().paused = false
				finished.emit()
				queue_free()
				return
	_page.transform = _view()
	queue_redraw()
	_front.queue_redraw()


## The next room, once the background load is done (null while it's still loading).
func _loaded() -> PackedScene:
	if not _loading:
		return load(target) as PackedScene
	var st := ResourceLoader.load_threaded_get_status(target)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(target) as PackedScene
	return load(target) as PackedScene  # the thread failed: load it here


## The page: columns of panels either side of the slit, rows above and below.
func _layout() -> void:
	_panels.clear()
	var ph := _p1.size.y
	var xs := [_p1.position.x - SLIT - CW, _p1.position.x, _p2.position.x, _p2.end.x + SLIT]
	for col in xs.size():
		for row in range(-3, ROWS + 4):
			if (col == 1 and row == 0) or (col == 2 and row == ROWS):
				continue
			var r := Rect2(xs[col], _p1.position.y + row * (ph + ROW_GAP), CW, ph)
			var h := absi(hash(Vector2i(col, row)))
			if h % 3 == 0:
				# split in two, a narrow panel and a wide one
				var cut := r.size.x * (0.38 if h % 2 == 0 else 0.6)
				_panels.append(Rect2(r.position, Vector2(cut - ROW_GAP * 0.4, ph)))
				_panels.append(Rect2(r.position.x + cut + ROW_GAP * 0.4, r.position.y, r.size.x - cut - ROW_GAP * 0.4, ph))
			else:
				_panels.append(r)


# ------------------------------------------------------------------ timing

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _shrink() -> float:
	return _ease(_t / T_SHRINK)


func _ink() -> float:
	return _ease(_t2 / T_INK) if _stage == 2 else 0.0


func _open() -> float:
	return _smoother((_t2 - T_OPEN0) / T_OPEN) if _stage == 2 else 0.0


## Page space -> screen: on the old panel, down into the slit and along it,
## out beside the next panel, then into it until it fills the screen.
func _view() -> Transform2D:
	var dive := _smoother((_t - T_DIVE0) / (T_DIVE - T_DIVE0))
	var run := _smoother((_t - T_DIVE) / (T_RUN - T_DIVE))
	var out := _smoother((_t - T_RUN) / (T_OUT - T_RUN))
	var focus := _p1.get_center().lerp(Vector2(_gx, _p1.get_center().y), dive)
	focus.y = lerpf(focus.y, _p2.get_center().y, run)
	focus = focus.lerp(_p2.get_center(), out)
	var z := lerpf(lerpf(1.0, Z_SLIT, dive), 1.0, out)
	z = lerpf(z, _s.x * 2.0 / _p2.size.x, _open())
	return Transform2D(0.0, Vector2(z, z), 0.0, _s - focus * z)


## The next panel on screen.
func _hole() -> Rect2:
	var v := _view()
	return Rect2(v * _p2.position, _p2.size * v.get_scale())


## The inked (see-through) part of the next panel, on screen.
func _open_rect() -> Rect2:
	if _stage < 2:
		return Rect2()
	var h := _hole()
	return Rect2(h.position, Vector2(h.size.x * _ink(), h.size.y))


## Where tiny Vesper is (page space): out of the old panel, down the slit,
## into the next one.
func _vesper_path() -> Array:
	return [Vector2(_p1.end.x - 40.0, _p1.get_center().y + 30.0), Vector2(_gx, _p1.get_center().y + 46.0),
		Vector2(_gx, _p2.get_center().y - 14.0), Vector2(_p2.position.x + 46.0, _p2.get_center().y + 24.0)]


func _vesper_at() -> Vector2:
	var p := _vesper_path()
	if _t < T_DIVE:
		return (p[0] as Vector2).lerp(p[1], _ease((_t - T_DIVE0) / (T_DIVE - T_DIVE0)))
	if _t < T_RUN:
		return (p[1] as Vector2).lerp(p[2], _smoother((_t - T_DIVE) / (T_RUN - T_DIVE)))
	return (p[2] as Vector2).lerp(p[3], _ease((_t - T_RUN) / (T_OUT - T_RUN)))


# ------------------------------------------------------------------ drawing

## Paper over everything except the inked part of the next panel (the live
## room shows through there).
func _draw() -> void:
	var outer := Rect2(-50, -50, _s.x * 2.0 + 100, _s.y * 2.0 + 100)
	var r := _open_rect()
	if r.size.x > 0.5 and r.size.y > 0.5:
		draw_rect(Rect2(outer.position, Vector2(outer.size.x, r.position.y - outer.position.y)), PAPER)
		draw_rect(Rect2(outer.position.x, r.end.y, outer.size.x, outer.end.y - r.end.y), PAPER)
		draw_rect(Rect2(outer.position.x, r.position.y, r.position.x - outer.position.x, r.size.y), PAPER)
		draw_rect(Rect2(r.end.x, r.position.y, outer.end.x - r.end.x, r.size.y), PAPER)
	else:
		draw_rect(outer, PAPER)


## The printed page round the slit, drawn once (one batched draw for the
## art, one for the lines) and moved with the view.
func _draw_page() -> void:
	var art := InkBatch.new()
	var lines := InkBatch.new()
	var dots: Array = []
	for i in _panels.size():
		_panel_art(art, lines, dots, _panels[i], i)
	art.flush(_page)
	for d in dots:
		_page.draw_texture_rect(_dots, d[0], true, d[1])
	for i in _panels.size():
		_border(lines, _panels[i], 5.0, i)
	# the pencilled ruling line down the middle of the slit
	var y := _p1.position.y - 900.0
	while y < _p2.end.y + 900.0:
		lines.draw_line(Vector2(_gx, y), Vector2(_gx, y + 14.0), Color(PENCIL, 0.45), 1.5)
		y += 26.0
	lines.flush(_page)


## One printed panel: rays, halftone, a night skyline, a pencil sketch or a
## speech bubble, picked by its index.
func _panel_art(art: InkBatch, lines: InkBatch, dots: Array, r: Rect2, i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + i * 31
	var col: Color = PRINT[rng.randi() % PRINT.size()]
	var corners := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	match rng.randi() % 5:
		0:  # a sunburst
			art.draw_rect(r, col)
			var c := r.position + r.size * Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.3, 0.9))
			for k in 12:
				var a0 := TAU * k / 12.0
				var a1 := a0 + TAU / 24.0
				var tri := PackedVector2Array([c, c + Vector2.from_angle(a0) * 2000.0, c + Vector2.from_angle(a1) * 2000.0])
				for poly in Geometry2D.intersect_polygons(tri, corners):
					art.draw_colored_polygon(poly, col.lightened(0.3))
		1:  # halftone
			art.draw_rect(r, col.lightened(0.45))
			dots.append([r, col.darkened(0.05)])
		2:  # a night skyline under a moon
			art.draw_rect(r, NIGHT)
			art.draw_circle(r.position + r.size * Vector2(rng.randf_range(0.6, 0.85), 0.28), r.size.y * 0.12, PAPER.darkened(0.05))
			var x := r.position.x
			while x < r.end.x:
				var w := minf(rng.randf_range(26.0, 60.0), r.end.x - x)
				var h := r.size.y * rng.randf_range(0.2, 0.55)
				art.draw_rect(Rect2(x, r.end.y - h, w, h), Color(0.07, 0.06, 0.13))
				if rng.randf() < 0.6:
					art.draw_rect(Rect2(x + w * 0.3, r.end.y - h * 0.7, 6, 7), Color(0.95, 0.8, 0.4))
				x += w
		3:  # still a pencil sketch
			art.draw_rect(r, PANEL_PAPER.darkened(0.05))
			var x := r.position.x + 12.0
			while x < r.end.x - 30.0:
				lines.draw_line(Vector2(x + 30.0, r.position.y + 14.0), Vector2(x, r.position.y + 44.0), Color(PENCIL, 0.35), 1.0)
				x += 16.0
			lines.draw_line(Vector2(r.position.x + 16, r.end.y - r.size.y * 0.3), Vector2(r.end.x - 16, r.end.y - r.size.y * 0.32),
				Color(PENCIL, 0.5), 1.4)
		_:  # a speech bubble
			art.draw_rect(r, col.lightened(0.5))
			var c := r.position + r.size * Vector2(rng.randf_range(0.35, 0.65), 0.38)
			var rad := Vector2(minf(r.size.x * 0.32, 110.0), r.size.y * 0.22)
			var bubble := PackedVector2Array()
			for k in 24:
				bubble.append(c + Vector2(cos(TAU * k / 24.0) * rad.x, sin(TAU * k / 24.0) * rad.y))
			art.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad.x * 0.2, rad.y * 0.8), c + Vector2(rad.x * 0.1, rad.y * 0.8),
				c + Vector2(-rad.x * 0.45, rad.y * 1.9)]), Color.WHITE)
			art.draw_colored_polygon(bubble, Color.WHITE)
			bubble.append(bubble[0])
			lines.draw_polyline(bubble, INK, 2.5)
			for k in 2:
				var y := c.y - rad.y * 0.25 + k * rad.y * 0.5
				lines.draw_line(Vector2(c.x - rad.x * 0.55, y), Vector2(c.x + rad.x * (0.5 - k * 0.25), y), Color(INK, 0.7), 3.0)


## A panel's hand-inked border (comic_frame.gd's, into a batch).
func _border(b: InkBatch, r: Rect2, width: float, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + seed_i
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var e: Vector2 = corners[(k + 1) % 4]
		var pts := PackedVector2Array()
		var n := maxi(2, int(a.distance_to(e) / 60.0))
		var side := (e - a).normalized().orthogonal()
		for i in n + 1:
			var t := float(i) / n
			var j := 0.0 if i == 0 or i == n else rng.randf_range(-0.8, 0.8)
			pts.append(a.lerp(e, t) + side * j)
		b.draw_polyline(pts, INK, width)
	for p in corners:
		b.draw_rect(Rect2(p - Vector2(width, width) * 0.5, Vector2(width, width)), INK)


func _draw_front() -> void:
	var c := _front
	var view := _view()
	var hole := _hole()
	var open := _open_rect()
	# the next panel: the pencil rough until the ink floods it
	if _ink() < 1.0:
		var rest := hole
		if open.size.x > 0.5:
			rest = Rect2(open.end.x, hole.position.y, hole.end.x - open.end.x, hole.size.y)
		c.draw_rect(rest, PANEL_PAPER)
		c.draw_set_transform_matrix(view)
		_draw_sketch(c, 1.0 - _ease(_ink() / 0.25))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		if open.size.x > 0.5:
			_draw_ink_front(c, open)
	var bw := 6.0 * (1.0 - _open())
	if bw > 0.3:
		ComicFrame.draw_border(c, hole, bw, 2)
	c.draw_set_transform_matrix(view)
	# the old frame, shrinking into its panel
	var shrink := _shrink()
	var full := Rect2(_p1.get_center() - _s, _s * 2.0)
	var p1 := Rect2(full.position.lerp(_p1.position, shrink), full.size.lerp(_p1.size, shrink))
	if _shot:
		c.draw_texture_rect(_shot, p1, false)
	else:
		c.draw_rect(p1, INK)
	if shrink > 0.05:
		ComicFrame.draw_border(c, p1, 5.0 * shrink, 1)
	# the line of light drawing itself down the slit behind tiny Vesper
	var fade := 1.0 - _ease(_ink() / 0.5)
	if _t > T_DIVE0 and fade > 0.0:
		var path := _vesper_path()
		var at := _vesper_at()
		var trail := PackedVector2Array([path[0]])
		var legs := 1 if _t < T_DIVE else (2 if _t < T_RUN else 3)
		for k in range(1, legs):
			trail.append(path[k])
		trail.append(at)
		c.draw_polyline(trail, Color(LIGHT, 0.22 * fade), 10.0)
		c.draw_polyline(trail, Color(LIGHT.lightened(0.4), 0.9 * fade), 2.5)
		_draw_vesper(c, at, fade)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the narrator's caption in the corner of the next panel
	if shrink > 0.6 and _ink() < 0.3:
		var a := clampf((shrink - 0.6) / 0.4, 0.0, 1.0) * (1.0 - _ink() / 0.3)
		var text := "MEANWHILE, FURTHER DOWN THE GUTTER..."
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var box := Rect2(view * (_p2.position + Vector2(-14, -18)), Vector2(w + 24, 36))
		c.draw_rect(Rect2(box.position + Vector2(4, 4), box.size), Color(INK, 0.35 * a))
		c.draw_rect(box.grow(3.0), Color(INK, a))
		c.draw_rect(box, Color(CAPTION, a))
		c.draw_string(FONT, box.position + Vector2(12, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, a))


## Tiny Vesper running down the page (front on: hat, egg head, red scarf
## streaming up behind him, open cloak), in page space.
func _draw_vesper(c: Node2D, at: Vector2, a: float) -> void:
	var step := _t * 16.0 if _stage == 0 else 0.0
	var view := _view()
	var bob := absf(sin(step)) * 2.0
	c.draw_set_transform_matrix(view * Transform2D(sin(step) * 0.08, Vector2.ONE, 0.0, at + Vector2(0, -bob)))
	var stride := sin(step) * 3.5
	c.draw_line(Vector2(-3, 7), Vector2(-3 + stride, 15), Color(INK, a), 2.6)
	c.draw_line(Vector2(3, 7), Vector2(3 - stride, 15), Color(INK, a), 2.6)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(11, 11), Vector2(-11, 11)]), Color(CLOAK, a))
	c.draw_polyline(PackedVector2Array([Vector2(-5, -4), Vector2(-11, 11)]), Color(INK, a), 1.5)
	c.draw_polyline(PackedVector2Array([Vector2(5, -4), Vector2(11, 11)]), Color(INK, a), 1.5)
	var wave := sin(_t * 20.0) * 2.0
	c.draw_polyline(PackedVector2Array([Vector2(-3, -4), Vector2(-7 + wave, -12), Vector2(-4 - wave, -20)]), Color(SCARF, a), 2.6)
	c.draw_rect(Rect2(-5, -5, 10, 3), Color(SCARF, a))
	c.draw_circle(Vector2(0, -10), 6.0, Color(INK, a))
	c.draw_circle(Vector2(0, -10), 5.0, Color(0.98, 0.96, 0.9, a))
	c.draw_rect(Rect2(-2.6, -11, 1.4, 2.4), Color(INK, a))
	c.draw_rect(Rect2(1.2, -11, 1.4, 2.4), Color(INK, a))
	c.draw_rect(Rect2(-8.5, -16.5, 17, 2.4), Color(INK, a))  # brim
	c.draw_rect(Rect2(-5, -25, 10, 9), Color(INK, a))
	c.draw_rect(Rect2(-5, -18.5, 10, 2), Color(SCARF, a))  # the hat's red band
	# speed lines above him (he runs down the page)
	for k in 3:
		var x := -7.0 + k * 7.0
		c.draw_line(Vector2(x, -30.0 - k * 3.0), Vector2(x, -44.0 - k * 5.0), Color(INK, 0.45 * a), 1.5)
	c.draw_set_transform_matrix(view)


## The wet edge of the ink flooding the panel from the slit side: a thick
## band with drips.
func _draw_ink_front(c: Node2D, open: Rect2) -> void:
	var x := open.end.x
	c.draw_rect(Rect2(x - 3.0, open.position.y, 6.0, open.size.y), INK)
	var y := open.position.y + 10.0
	var i := 0
	while y < open.end.y - 6.0:
		var ln := 6.0 + 12.0 * absf(sin(i * 2.7 + _t2 * 9.0))
		c.draw_rect(Rect2(x, y - 2.5, ln, 5.0), INK)
		c.draw_circle(Vector2(x + ln, y), 4.5, INK)
		y += 23.0 + 9.0 * absf(sin(i * 1.3))
		i += 1


## The next panel's pencil rough (page space): the floor of the next room
## seen from above, the gutter coming into it, its zone's name.
func _draw_sketch(c: Node2D, a: float) -> void:
	if a <= 0.0:
		return
	var p := _p2
	var col := Color(PENCIL, 0.7 * a)
	var boil := Time.get_ticks_msec() / 160  # the lines boil a little, even while it loads
	var j := func(k: int) -> float: return (float(absi(hash(Vector2i(k, boil))) % 100) / 100.0 - 0.5) * 2.5
	var cen := p.get_center() + Vector2(30, 34)
	var rim := PackedVector2Array()
	for i in 21:
		var ang := TAU * i / 20.0
		rim.append(cen + Vector2(cos(ang) * 150.0 + j.call(i), sin(ang) * 58.0 + j.call(i + 40)))
	c.draw_polyline(rim, col, 1.6)
	# the gutter coming in from the slit: two ruled lines, dashed
	for y in [cen.y - 12.0, cen.y + 12.0]:
		var x := p.position.x + 8.0
		while x < cen.x - 150.0:
			c.draw_line(Vector2(x, y + j.call(int(x)) * 0.4), Vector2(x + 10.0, y), col, 1.4)
			x += 18.0
	# a desk lamp roughed in on the floor
	var lb := cen + Vector2(70, -6)
	c.draw_line(lb + Vector2(-10, 0), lb + Vector2(10, 0), col, 1.6)
	c.draw_line(lb, lb + Vector2(-12 + j.call(90), -32), col, 1.4)
	c.draw_line(lb + Vector2(-12, -32), lb + Vector2(8, -52 + j.call(91)), col, 1.4)
	c.draw_arc(lb + Vector2(14, -50), 9.0, PI * 0.9, PI * 2.1, 8, col, 1.4)
	if _title != "":
		var fs := 34
		var w := FONT.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(FONT, Vector2(p.get_center().x - w * 0.5, p.position.y + 78.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(PENCIL, 0.8 * a))
