extends Control
## "Down the gutter": the way from one Gutter room to the next (World25.go()
## with `through_gutter`, which a gate's way on uses). The Margins are the
## dead gutters between a comic's panels, so moving on is a trip from one
## gutter to the next, and it never leaves the dark:
##  1. the frozen frame tears down the middle and its halves part, greying,
##     opening a dark slit between them,
##  2. the view runs down that slit: the halves slide away up and dead
##     panels slide past either side (greyed, faded, torn along the edge
##     that faces the gutter, their ink borders broken), dust drifting, a
##     tiny ink Vesper running ahead and a line of light drawing itself
##     behind him (the gates' line). The next room loads meanwhile,
##  3. the new room is built behind the dark (the tree is paused once it has
##     settled); the slit between the last two dead panels clears, showing
##     the room through it, and the two walls part to let it in.
## Lives on World25's layer, so it survives the scene change.
##
##   var fx := GutterTransition.new()
##   fx.target = "res://scenes/world25/rooms/darkwood_1.tscn"
##   fx.capture(get_viewport())   # the frame being left
##   layer.add_child(fx)
##   await fx.finished

signal finished

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
## The gutter itself.
const DARK := Color(0.035, 0.03, 0.045)
const INK := Color(0.01, 0.01, 0.02)
## The dead panels: greyed, faded.
const DEAD := [Color(0.17, 0.165, 0.18), Color(0.14, 0.135, 0.155), Color(0.2, 0.19, 0.19), Color(0.12, 0.12, 0.14)]
const LIGHT := Color(1.0, 0.88, 0.55)
const SCARF := Color(0.75, 0.16, 0.13)
const CLOAK := Color(0.12, 0.07, 0.16)
## The slit's width on screen.
const SLIT := 210.0
## Gutters between the stacked dead panels.
const ROW_GAP := 30.0
## How far the run goes, in screens (after the first, the old frame).
const TRAVEL := 1.6
const T_TEAR := 0.45  # the frame parts
const T_RUN0 := 0.3  # the run starts while it is still parting
const T_RUN := 1.6  # at the next gutter
const T_CLEAR := 0.3  # the slit clears onto the new room
const T_OPEN0 := 0.18
const T_OPEN := 0.7  # the walls part
const SETTLE_FRAMES := 3

## The room to load.
var target := ""
var _shot: Texture2D
var _size := Vector2(1280, 720)
var _cx := 640.0
var _t := 0.0
var _stage := 0  # 0 the old room, 1 building the new one, 2 revealing it
var _t2 := 0.0
var _frames := 0
var _loading := false
var _walls: Node2D  # the dead panels (drawn once, scrolled)
var _front: Node2D


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
	_size = size if size.x > 1.0 and size.y > 1.0 else Vector2(1280, 720)
	_cx = _size.x * 0.5
	_loading = ResourceLoader.load_threaded_request(target) == OK
	_walls = Node2D.new()
	_walls.draw.connect(_draw_walls)
	add_child(_walls)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)
	get_tree().paused = true
	Engine.time_scale = 1.0  # a hit-stop must not slow the trip down
	_update()


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)  # a long frame (the room building) never skips the animation
	match _stage:
		0:
			_t += delta
			if _t >= T_RUN:
				_t = T_RUN
				var packed := _loaded()
				if packed:
					_stage = 1
					_frames = 0
					get_tree().paused = false
					get_tree().change_scene_to_packed(packed)
		1:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == target:
				# a few frames behind the dark: the room places Vesper at the
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
	_update()


func _update() -> void:
	_walls.position = Vector2(0, -_scroll())
	queue_redraw()
	if _stage == 2:
		_walls.queue_redraw()  # parting: each wall moves its own way
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


# ------------------------------------------------------------------ timing

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


## 0 -> 1: the old frame tearing apart.
func _tear() -> float:
	return _ease(_t / T_TEAR)


## How far down the gutter the view has run, in pixels.
func _scroll() -> float:
	return _smoother((_t - T_RUN0) / (T_RUN - T_RUN0)) * _size.y * (TRAVEL + 1.0)


func _clear() -> float:
	return _ease(_t2 / T_CLEAR) if _stage == 2 else 0.0


func _part() -> float:
	return _smoother((_t2 - T_OPEN0) / T_OPEN) if _stage == 2 else 0.0


## The slit between the walls, on screen: the window onto the new room.
func _hole() -> Rect2:
	var w := SLIT + _part() * (_size.x + 80.0)
	return Rect2(_cx - w * 0.5, -10.0, w, _size.y + 20.0)


## A torn edge's wobble at height `y` (the same for the same y and seed).
func _jag(y: float, seed: int) -> float:
	return float(absi(hash(Vector2i(int(y / 16.0), seed))) % 100) / 100.0 * 22.0 - 6.0


# ------------------------------------------------------------------ drawing

## The dark of the gutter everywhere, thinning to nothing in the slit as it
## clears onto the new room.
func _draw() -> void:
	var outer := Rect2(-50, -50, _size.x + 100, _size.y + 100)
	var h := _hole()
	var a := 1.0 - _clear()
	draw_rect(Rect2(outer.position, Vector2(h.position.x - outer.position.x, outer.size.y)), DARK)
	draw_rect(Rect2(h.end.x, outer.position.y, outer.end.x - h.end.x, outer.size.y), DARK)
	if a > 0.0:
		draw_rect(h, Color(DARK, a))


## The dead panels either side of the slit, stacked from the bottom of the
## first screen (the old frame is the first pair) to the last screen. Each
## wall moves out as they part.
func _draw_walls() -> void:
	var b := InkBatch.new()
	var lines := InkBatch.new()
	var half := SLIT * 0.5
	var shift := _part() * (_size.x * 0.5 + 40.0)
	var y := _size.y + ROW_GAP
	var end := _size.y * (TRAVEL + 2.0) + 40.0
	var i := 0
	while y < end:
		var h := _size.y * (0.42 + 0.3 * float(absi(hash(i * 7 + 3)) % 100) / 100.0)
		if y + h > end - ROW_GAP * 2.0:
			h = end - y  # the last pair fills the last screen
		for side in [-1, 1]:
			var inner: float = _cx + side * half + side * shift
			var outer: float = inner + side * (_size.x * 0.5 + 60.0)
			_dead_panel(b, lines, Rect2(minf(inner, outer), y, absf(outer - inner), h), side, i * 2 + (side + 1) / 2)
		y += h + ROW_GAP
		i += 1
	b.flush(_walls)
	lines.flush(_walls)


## One dead panel: greyed and faded, a ghost of what was printed in it,
## a torn hole or two, its edge on the gutter side torn, its ink border
## broken, a drip of ink running off its bottom into the gutter.
func _dead_panel(b: InkBatch, lines: InkBatch, r: Rect2, side: int, k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6007 + k * 31
	var col: Color = DEAD[rng.randi() % DEAD.size()]
	# the outline, torn along the inner edge (the one facing the slit)
	var inner_x := r.position.x if side > 0 else r.end.x
	var outer_x := r.end.x if side > 0 else r.position.x
	var poly := PackedVector2Array([Vector2(outer_x, r.position.y), Vector2(inner_x, r.position.y)])
	var y := r.position.y + 16.0
	while y < r.end.y:
		poly.append(Vector2(inner_x - side * _jag(y, k), y))
		y += 16.0
	poly.append(Vector2(inner_x, r.end.y))
	poly.append(Vector2(outer_x, r.end.y))
	b.draw_colored_polygon(poly, col)
	# what was printed there, faded nearly away
	var ghost := col.lightened(0.1)
	match rng.randi() % 3:
		0:  # hatching
			var x := r.position.x + 20.0
			while x < r.end.x - 40.0:
				lines.draw_line(Vector2(x + 30.0, r.position.y + 24.0), Vector2(x, r.position.y + 60.0 + rng.randf() * 40.0), ghost, 1.5)
				x += 22.0
		1:  # a pale moon over a broken skyline
			b.draw_circle(r.position + r.size * Vector2(rng.randf_range(0.3, 0.7), 0.3), r.size.y * 0.1, ghost)
			var x := r.position.x
			while x < r.end.x:
				var w := rng.randf_range(30.0, 70.0)
				b.draw_rect(Rect2(x, r.end.y - r.size.y * rng.randf_range(0.15, 0.4), minf(w, r.end.x - x), r.size.y * 0.4), col.darkened(0.3))
				x += w
		_:  # a speech bubble with nothing left in it
			var c := r.position + r.size * Vector2(rng.randf_range(0.3, 0.7), 0.35)
			var pts := PackedVector2Array()
			for a in 20:
				pts.append(c + Vector2(cos(TAU * a / 20.0) * 90.0, sin(TAU * a / 20.0) * 40.0))
			pts.append(pts[0])
			lines.draw_polyline(pts, ghost, 2.0)
	# torn holes right through it
	for h in rng.randi() % 3:
		var c := r.position + r.size * Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.25, 0.8))
		var hole := PackedVector2Array()
		var rad := rng.randf_range(14.0, 34.0)
		for a in 9:
			hole.append(c + Vector2.from_angle(TAU * a / 9.0) * rad * rng.randf_range(0.55, 1.2))
		b.draw_colored_polygon(hole, DARK)
	# the ink border, broken: pieces of it, some gone
	var inset := 10.0
	var top := r.position.y + inset
	var bottom := r.end.y - inset
	var ex := outer_x - side * inset
	var ix := inner_x + side * 26.0
	for e in [[Vector2(ix, top), Vector2(ex, top)], [Vector2(ix, bottom), Vector2(ex, bottom)], [Vector2(ex, top), Vector2(ex, bottom)],
			[Vector2(ix, top), Vector2(ix, bottom)]]:
		var a: Vector2 = e[0]
		var z: Vector2 = e[1]
		var n := maxi(int(a.distance_to(z) / 70.0), 1)
		for s in n:
			if rng.randf() < 0.3:
				continue
			lines.draw_line(a.lerp(z, float(s) / n), a.lerp(z, (s + rng.randf_range(0.6, 1.0)) / n), INK, 4.0)
	# ink run off its bottom into the gutter
	if rng.randf() < 0.6:
		var x := inner_x + side * 40.0
		var ln := rng.randf_range(20.0, 60.0)
		b.draw_rect(Rect2(x - 2.5, r.end.y - 4.0, 5.0, ln), INK)
		b.draw_circle(Vector2(x, r.end.y - 4.0 + ln), 5.0, INK)


func _draw_front() -> void:
	var c := _front
	var s := _scroll()
	# the old frame, torn down the middle, its halves parting and greying
	var tear := _tear()
	if s < _size.y + 10.0:
		var gap := tear * (SLIT * 0.5 + 6.0)
		var k := lerpf(1.0, 0.45, tear)
		for side in [-1, 1]:
			var poly := PackedVector2Array()
			var outer_x: float = _cx + side * (_size.x * 0.5 + 2.0)
			poly.append(Vector2(outer_x, 0))
			# both halves share the one torn line, so they fit until they part
			var y := 0.0
			while y <= _size.y:
				poly.append(Vector2(_cx + _jag(y, 900) - 8.0, y))
				y += 16.0
			poly.append(Vector2(outer_x, _size.y))
			if side < 0:
				poly.reverse()
			var uvs := PackedVector2Array()
			var placed := PackedVector2Array()
			for p in poly:
				uvs.append(p / _size)
				placed.append(p + Vector2(side * gap, -s))
			if _shot:
				c.draw_polygon(placed, PackedColorArray([Color(k, k, k * 1.04)]), uvs, _shot)
			else:
				c.draw_colored_polygon(placed, Color(0.1, 0.1, 0.12))
	# dust drifting up the slit
	var fade := 1.0 - _clear()
	if fade > 0.0:
		for i in 26:
			var px := _cx + (float(absi(hash(i * 3 + 1)) % 100) / 100.0 - 0.5) * SLIT * 0.9
			var py := fposmod(float(absi(hash(i * 5 + 2)) % 1000) / 1000.0 * _size.y - s * 1.25 - _t * 40.0, _size.y)
			c.draw_rect(Rect2(px, py, 2.0, 2.0), Color(0.6, 0.58, 0.55, 0.35 * fade))
	# the line of light drawing itself down the slit behind tiny Vesper
	var v := _vesper_at()
	var lit := 1.0 - _ease(_t2 / 0.35) if _stage == 2 else 1.0
	if _t > T_RUN0 * 0.5 and lit > 0.0:
		var top := Vector2(_cx, minf(-s + _size.y * 0.5, v.y))
		c.draw_line(top, v, Color(LIGHT, 0.18 * lit), 10.0)
		c.draw_line(top, v, Color(LIGHT.lightened(0.4), 0.85 * lit), 2.5)
		_draw_vesper(c, v, lit)


## Tiny Vesper's spot on screen: out of the tear, then running down the
## middle of the slit, then off its bottom as the walls part.
func _vesper_at() -> Vector2:
	var run := _ease((_t - T_RUN0 * 0.5) / 0.35)
	var p := Vector2(_cx, lerpf(_size.y * 0.5, _size.y * 0.42, run))
	if _stage == 2:
		p.y += _ease(_t2 / 0.5) * _size.y * 0.7
	return p


## Tiny Vesper running down the gutter (front on: hat, egg head, red scarf
## streaming up behind him, open cloak), dark against the dark, `a` faded.
func _draw_vesper(c: Node2D, at: Vector2, a: float) -> void:
	var step := (_t + _t2) * 16.0
	var bob := absf(sin(step)) * 3.0
	c.draw_set_transform(at + Vector2(0, -bob), sin(step) * 0.08, Vector2(2.2, 2.2))
	var stride := sin(step) * 3.5
	c.draw_line(Vector2(-3, 7), Vector2(-3 + stride, 15), Color(INK, a), 2.6)
	c.draw_line(Vector2(3, 7), Vector2(3 - stride, 15), Color(INK, a), 2.6)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(11, 11), Vector2(-11, 11)]), Color(CLOAK, a))
	var wave := sin(step * 1.25) * 2.0
	c.draw_polyline(PackedVector2Array([Vector2(-3, -4), Vector2(-7 + wave, -12), Vector2(-4 - wave, -20)]), Color(SCARF, a), 2.6)
	c.draw_rect(Rect2(-5, -5, 10, 3), Color(SCARF, a))
	c.draw_circle(Vector2(0, -10), 6.0, Color(INK, a))
	c.draw_circle(Vector2(0, -10), 5.0, Color(0.9, 0.88, 0.84, a))
	c.draw_rect(Rect2(-2.6, -11, 1.4, 2.4), Color(INK, a))
	c.draw_rect(Rect2(1.2, -11, 1.4, 2.4), Color(INK, a))
	c.draw_rect(Rect2(-8.5, -16.5, 17, 2.4), Color(INK, a))  # brim
	c.draw_rect(Rect2(-5, -25, 10, 9), Color(INK, a))
	c.draw_rect(Rect2(-5, -18.5, 10, 2), Color(SCARF, a))  # the hat's red band
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
