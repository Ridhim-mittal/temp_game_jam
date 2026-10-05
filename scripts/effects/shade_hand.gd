extends Node2D
## Shade's hand (the final fight in Shade's City): a huge skeletal hand gripping
## a golden fountain pen, trailing ink from the wrist. It draws monsters into
## the world: the nib swoops down and traces the monster's outline stroke by
## stroke (the fingers flex as it writes, the tip glows), then the sketch flares
## with light and the monster is born: `drawn(kind, at)` fires and the caller
## spawns the real enemy there (`materialize()` gives it a pop-in).
##
##   hand.draw_monster("spider", Vector2(500, 600))   # kinds: spider bat blot eraser pen
##
## Place at the world origin; `rest` is where the hand hovers between drawings.
## Everything is drawn in code through InkBatch (one draw call per layer).

signal drawn(kind: String, at: Vector2)

const InkBatch = preload("res://scripts/depth/ink_batch.gd")

## World point the nib hovers at when idle (high above the arena).
@export var rest := Vector2(980, 140)
@export var hand_scale := 1.0
## Nib speed while inking a line (px/s) and while lifted between lines.
@export var draw_speed := 1100.0
@export var lift_speed := 1600.0
## Seconds the finished sketch glows before the monster is born.
@export var birth_time := 0.7

const INK := Color(0.03, 0.02, 0.05)
const BONE := Color(0.93, 0.9, 0.82)
const BONE_SHADE := Color(0.66, 0.62, 0.6)
const GOLD := Color(0.95, 0.76, 0.32)
const GOLD_DARK := Color(0.6, 0.42, 0.16)
const BARREL := Color(0.55, 0.38, 0.2)
const BARREL_LIGHT := Color(0.82, 0.62, 0.36)
const GLOW := Color(1.0, 0.86, 0.45)
const RIM := Color(0.55, 0.45, 0.85)
const FOLD := Color(0.2, 0.15, 0.32)
const U := Vector2(0.6, -0.8)  # pen axis, nib -> cap (hand space)
const N := Vector2(0.8, 0.6)  # across the pen, towards the back of the hand
const FOREARM := Vector2(0.894, -0.447)  # wrist -> elbow (up and right, off the screen)

var _nib := Vector2.ZERO  # world position of the nib tip
var _vel := Vector2.ZERO
var _tilt := 0.0
var _time := 0.0
var _flex := 0.0  # finger curl while writing
var _glow := 0.3
var _queue: Array = []  # [kind, at]
var _job: Dictionary = {}  # the drawing in progress
var _sketches: Array = []  # {strokes, done (pts drawn per stroke), at, age, born, life}
var _sketch_layer: Node2D


func _ready() -> void:
	z_index = 40
	_nib = rest
	_sketch_layer = Node2D.new()
	_sketch_layer.z_index = -38  # the sketches sit in the world, under the hand (z 40 - 38 = 2)
	_sketch_layer.draw.connect(_paint_sketches)
	add_child(_sketch_layer)


## Queue a monster drawing. `at` = the monster's feet in world space.
func draw_monster(kind: String, at: Vector2) -> void:
	_queue.append([kind, at])


## True while the hand is drawing (or has drawings queued).
func busy() -> bool:
	return not _job.is_empty() or not _queue.is_empty()


## Pop-in for a freshly drawn monster: grows out of the light.
static func materialize(node: CanvasItem) -> void:
	node.modulate = Color(1, 1, 1, 0)
	node.scale = Vector2(0.3, 0.3)
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	_time += delta
	var before := _nib
	if _job.is_empty() and not _queue.is_empty():
		_start(_queue.pop_front())
	if _job.is_empty():
		# idle: hover at rest, circling slowly like it's thinking what to draw next
		var hover := rest + Vector2(sin(_time * 0.9) * 40.0, sin(_time * 1.7) * 18.0)
		_nib = _nib.lerp(hover, 1.0 - exp(-delta * 3.0))
		_flex = move_toward(_flex, 0.0, delta * 2.0)
		_glow = move_toward(_glow, 0.35 + 0.1 * sin(_time * 3.0), delta * 2.0)
	else:
		_run_job(delta)
	_vel = _vel.lerp((_nib - before) / maxf(delta, 0.001), 1.0 - exp(-delta * 10.0))
	_tilt = lerpf(_tilt, clampf(_vel.x * 0.00035 - _vel.y * 0.0002, -0.25, 0.25), 1.0 - exp(-delta * 6.0))
	for s in _sketches:
		s.age += delta
		if s.born:
			s.life -= delta
	_sketches = _sketches.filter(func(s): return s.life > 0.0)
	queue_redraw()
	_sketch_layer.queue_redraw()


func _start(job: Array) -> void:
	var strokes := _strokes(job[0])
	var sk := {"strokes": [], "done": [], "at": job[1], "age": 0.0, "born": false, "life": 0.9, "flare": 0.0}
	for st in strokes:
		var world := PackedVector2Array()
		for p in st:
			world.append(job[1] + p)
		sk.strokes.append(world)
		sk.done.append(0.0)
	_sketches.append(sk)
	_job = {"kind": job[0], "at": job[1], "sketch": sk, "stroke": 0, "lifting": true, "birth": 0.0}


func _run_job(delta: float) -> void:
	var sk: Dictionary = _job.sketch
	var i: int = _job.stroke
	if i >= sk.strokes.size():
		# every line drawn: the sketch flares with light, then the monster is born
		_job.birth += delta
		sk.flare = clampf(_job.birth / birth_time, 0.0, 1.0)
		_glow = 1.0 + sk.flare
		_flex = move_toward(_flex, -0.3, delta * 2.0)
		_nib = _nib.lerp(_job.at + Vector2(80, -260), 1.0 - exp(-delta * 4.0))  # the pen lifts away
		if _job.birth >= birth_time:
			sk.born = true
			var kind: String = _job.kind
			var at: Vector2 = _job.at
			_job = {}
			if has_node("/root/Sfx"):
				get_node("/root/Sfx").play("teleport", -4.0, 1.4)
			drawn.emit(kind, at)
		return
	var stroke: PackedVector2Array = sk.strokes[i]
	if _job.lifting:
		# lifted: fly to the start of the next line
		var to := stroke[0] - _nib
		var step := lift_speed * delta
		_glow = move_toward(_glow, 0.5, delta * 3.0)
		if to.length() <= step:
			_nib = stroke[0]
			_job.lifting = false
		else:
			_nib += to.normalized() * step + Vector2(0, -sin(clampf(step / maxf(to.length(), 1.0), 0, 1) * PI) * 2.0)
		return
	# inking: run the nib along the stroke
	_glow = move_toward(_glow, 1.0, delta * 4.0)
	_flex = 0.12 * sin(_time * 16.0)
	var left := draw_speed * delta
	var done: float = sk.done[i]
	while left > 0.0 and done < stroke.size() - 1:
		var k := int(done)
		var a := stroke[k]
		var b := stroke[k + 1]
		var seg := a.distance_to(b)
		var f := done - k
		var remain := seg * (1.0 - f)
		if left >= remain:
			left -= remain
			done = k + 1
		else:
			done += left / maxf(seg, 0.001)
			left = 0.0
	sk.done[i] = done
	var k2 := mini(int(done), stroke.size() - 1)
	_nib = stroke[k2].lerp(stroke[mini(k2 + 1, stroke.size() - 1)], done - k2)
	if done >= stroke.size() - 1:
		_job.stroke = i + 1
		_job.lifting = true
		if has_node("/root/Sfx") and randf() < 0.5:
			get_node("/root/Sfx").play("sword_swing", -16.0, 1.9)


# --- the monsters' outlines (feet at the origin) ---------------------------------

func _strokes(kind: String) -> Array:
	var s: Array = []
	match kind:
		"spider":
			s.append(_ellipse(Vector2(0, -78), 44, 32))
			s.append(_ellipse(Vector2(0, -122), 20, 17))
			for side in [-1.0, 1.0]:
				for i in 4:
					var root := Vector2(side * 30.0, -84.0 + i * 8.0)
					var knee := Vector2(side * (76.0 + i * 10.0), -142.0 + i * 16.0)
					var foot := Vector2(side * (96.0 + i * 14.0), 0.0)
					s.append(_line([root, knee, foot]))
			s.append(_ellipse(Vector2(-7, -124), 4, 4))
			s.append(_ellipse(Vector2(7, -124), 4, 4))
		"bat":
			s.append(_ellipse(Vector2(0, -60), 16, 18))
			for side in [-1.0, 1.0]:
				s.append(_line([Vector2(side * 12, -66), Vector2(side * 44, -88), Vector2(side * 74, -76),
					Vector2(side * 62, -58), Vector2(side * 48, -66), Vector2(side * 36, -50), Vector2(side * 14, -54)]))
				s.append(_line([Vector2(side * 6, -74), Vector2(side * 10, -92), Vector2(side * 14, -76)]))
		"blot":
			var blob := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				var r := 72.0 + 9.0 * sin(a * 5.0) + 5.0 * sin(a * 9.0 + 1.0)
				blob.append(Vector2(cos(a) * r, -76.0 + sin(a) * r * 0.95))
			s.append(blob)
			s.append(_ellipse(Vector2(0, -96), 20, 20))
			s.append(_ellipse(Vector2(0, -96), 7, 9))
			for side in [-1.0, 1.0]:
				s.append(_line([Vector2(side * 66, -86), Vector2(side * 102, -64), Vector2(side * 96, -30)]))
		"eraser":
			s.append(_line([Vector2(-80, 0), Vector2(-80, -86), Vector2(80, -86), Vector2(80, 0), Vector2(-80, 0)]))
			s.append(_line([Vector2(-80, -30), Vector2(80, -30)]))
			s.append(_line([Vector2(-40, -66), Vector2(-14, -56)]))
			s.append(_line([Vector2(40, -66), Vector2(14, -56)]))
			s.append(_line([Vector2(-26, -42), Vector2(26, -42)]))
		"pen":
			s.append(_line([Vector2(-20, -10), Vector2(-20, -150), Vector2(20, -150), Vector2(20, -10)]))
			s.append(_line([Vector2(-20, -10), Vector2(0, 0), Vector2(20, -10)]))
			s.append(_line([Vector2(-22, -150), Vector2(-22, -184), Vector2(22, -184), Vector2(22, -150)]))
			s.append(_line([Vector2(0, -150), Vector2(30, -168), Vector2(30, -120)]))
			s.append(_ellipse(Vector2(-8, -110), 5, 6))
			s.append(_ellipse(Vector2(8, -110), 5, 6))
	return s


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 29:
		var a := -PI * 0.5 + TAU * i / 28.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## A polyline with extra points so the nib moves smoothly along it.
static func _line(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(int(a.distance_to(b) / 12.0), 1)
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(pts[pts.size() - 1])
	return out


# --- drawing ------------------------------------------------------------------------

func _paint_sketches() -> void:
	var b := InkBatch.new()
	for sk in _sketches:
		var flare: float = sk.flare
		var fade: float = clampf(sk.life / 0.9, 0.0, 1.0) if sk.born else 1.0
		var col := INK.lerp(GLOW, flare)
		if sk.born:
			col = GLOW
		for i in sk.strokes.size():
			var st: PackedVector2Array = sk.strokes[i]
			var done: float = sk.done[i]
			if done <= 0.0:
				continue
			var n := mini(int(done) + 2, st.size())
			var part := st.slice(0, n)
			if n >= 2 and done < st.size() - 1:
				part[n - 1] = st[n - 2].lerp(st[n - 1], done - int(done))
			# ink "boils" a little, like it's still wet
			var wob := PackedVector2Array()
			for k in part.size():
				var p := part[k]
				wob.append(p + Vector2(sin(k * 1.7 + sk.age * 9.0), cos(k * 2.3 + sk.age * 7.0)) * 1.2)
			if part.size() >= 2:
				if flare > 0.0 or sk.born:
					b.draw_polyline(wob, Color(GLOW, 0.35 * fade * maxf(flare, 0.4)), 18.0)
				b.draw_polyline(wob, Color(1.0, 0.96, 0.86, 0.75 * fade), 11.0)  # paper halo: reads on the painting
				b.draw_polyline(wob, Color(col, fade), 6.0)
		if flare > 0.0:
			# the light the monster is born from
			var c: Vector2 = sk.at + Vector2(0, -70)
			var r := 40.0 + 120.0 * flare
			b.draw_circle(c, r, Color(GLOW, 0.12 * flare * fade))
			b.draw_circle(c, r * 0.5, Color(1.0, 0.97, 0.85, 0.25 * flare * fade))
		if sk.born:
			# burst rays as it comes alive
			var t: float = 1.0 - fade
			for k in 12:
				var a := TAU * k / 12.0 + 0.3
				var d := Vector2(cos(a), sin(a))
				var c2: Vector2 = sk.at + Vector2(0, -70)
				b.draw_line(c2 + d * (60.0 + 140.0 * t), c2 + d * (90.0 + 200.0 * t), Color(GLOW, fade), 4.0)
	b.flush(_sketch_layer)


func _p(s: float, d: float) -> Vector2:
	return U * s + N * d


func _draw() -> void:
	var b := InkBatch.new()
	var xf := Transform2D(_tilt + sin(_time * 1.3) * 0.02, Vector2.ONE * hand_scale, 0.0, _nib)
	b.draw_set_transform_matrix(xf)
	# nib glow
	var g := _glow * (0.85 + 0.15 * sin(_time * 18.0))
	b.draw_circle(Vector2.ZERO, 46.0 * g, Color(GLOW, 0.12))
	b.draw_circle(Vector2.ZERO, 24.0 * g, Color(GLOW, 0.3))
	b.draw_circle(Vector2.ZERO, 9.0 * g, Color(1.0, 0.98, 0.88, 0.85))
	_draw_sleeve(b)
	_draw_thumb(b)
	_draw_pen(b)
	_draw_hand(b)
	b.flush(self)


func _draw_sleeve(b) -> void:
	# a ragged ink cuff round the forearm, and long wisps of ink pouring off it
	var w := _p(282, 126)  # the wrist
	var f := FOREARM
	var side := Vector2(-f.y, f.x)
	# forearm bones (radius and ulna) running up into the cuff
	_bone(b, w + side * 10.0, w + side * 14.0 + f * 130.0, 15.0)
	_bone(b, w - side * 12.0, w - side * 10.0 + f * 120.0, 12.0)
	var cuff := PackedVector2Array()
	for k in 7:
		var t := k / 6.0
		cuff.append(w + f * (90.0 + 420.0 * t) + side * (34.0 + 26.0 * t + sin(_time * 2.0 + k * 1.7) * 4.0))
	for k in range(6, -1, -1):
		var t := k / 6.0
		var rag := 10.0 * sin(k * 2.9) + sin(_time * 2.6 + k) * 5.0
		cuff.append(w + f * (70.0 + 420.0 * t + rag) - side * (36.0 + 30.0 * t))
	b.draw_colored_polygon(cuff, INK)
	# a cold violet rim where the moonlight catches it, and folds in the cloth
	var rim := PackedVector2Array()
	for k in 7:
		rim.append(cuff[k] - side * 4.0)
	b.draw_polyline(rim, RIM, 4.0)
	for k in 5:
		var t := 0.15 + k * 0.17
		var a0 := w + f * (100.0 + 420.0 * t) + side * (22.0 + 20.0 * t)
		var a1 := w + f * (130.0 + 420.0 * t) - side * (18.0 + 22.0 * t)
		var mid := a0.lerp(a1, 0.5) + f * (14.0 + 6.0 * sin(_time * 1.5 + k))
		b.draw_polyline(PackedVector2Array([a0, mid, a1]), FOLD, 3.0)
	# the torn edge at the wrist
	for k in 5:
		var e := w + f * (84.0 + k * 3.0) + side * (-30.0 + k * 15.0)
		b.draw_colored_polygon(PackedVector2Array([e - f * 2.0 + side * 6.0, e - f * (22.0 + 10.0 * (k % 2)) + side * sin(_time * 3.0 + k) * 4.0,
			e - f * 2.0 - side * 6.0]), INK)
	# wisps hang off the cuff and stream away, thinning to nothing
	for k in 8:
		var t0 := 0.1 + k * 0.11
		var start := w + f * (60.0 + 380.0 * t0) + side * (24.0 if k % 2 == 0 else -28.0)
		var down := (Vector2(0.15, 1.0) if k % 2 == 0 else Vector2(-0.6, 0.75)).normalized()
		var length := 110.0 + 70.0 * absf(sin(k * 1.3))
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for j in 9:
			var t := j / 8.0
			var c := start + down * length * t + down.orthogonal() * sin(_time * 2.2 + j * 0.7 + k * 1.1) * 16.0 * t
			var wide := (9.0 - (k % 3) * 2.0) * (1.0 - t)
			left.append(c + down.orthogonal() * wide)
			right.append(c - down.orthogonal() * wide)
		right.reverse()
		b.draw_colored_polygon(left + right, INK)
		b.draw_circle(left[left.size() - 1].lerp(right[0], 0.5) + down * 4.0, 2.5, INK)


func _bone(b, a: Vector2, c: Vector2, w: float) -> void:
	b.draw_line(a, c, INK, w + 6.0)
	b.draw_circle(a, w * 0.62 + 3.0, INK)
	b.draw_circle(c, w * 0.62 + 3.0, INK)
	b.draw_line(a, c, BONE, w)
	b.draw_circle(a, w * 0.62, BONE)
	b.draw_circle(c, w * 0.62, BONE)
	var d := (c - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	b.draw_line(a + nrm * w * 0.25 + d * w * 0.4, c + nrm * w * 0.25 - d * w * 0.4, BONE_SHADE, maxf(w * 0.18, 1.5))


func _finger(b, pts: Array, w: float, curl: float) -> void:
	# knuckle -> joints -> tip; curl pulls the outer joints in towards the knuckle
	var k0: Vector2 = pts[0]
	var out: Array = [k0]
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i]
		out.append(p.lerp(k0, curl * i / (pts.size() - 1.0) * 0.35))
	for i in out.size() - 1:
		_bone(b, out[i], out[i + 1], w * (1.0 - i * 0.16))
	# a pointed tip, like a nib
	var tip: Vector2 = out[out.size() - 1]
	var dir: Vector2 = (tip - out[out.size() - 2]).normalized()
	b.draw_colored_polygon(PackedVector2Array([tip + dir.orthogonal() * w * 0.4, tip + dir * w * 1.1,
		tip - dir.orthogonal() * w * 0.4]), INK)


func _draw_thumb(b) -> void:
	_finger(b, [_p(222, 102), _p(170, 84), _p(128, 52), _p(100, 24)], 15.0, _flex)


func _draw_pen(b) -> void:
	# nib (gold, with its slit and breather hole)
	var nib := PackedVector2Array([_p(0, 0), _p(30, -9), _p(50, -11), _p(50, 11), _p(30, 9)])
	b.draw_colored_polygon(_grow(nib, 3.0), INK)
	b.draw_colored_polygon(nib, GOLD)
	b.draw_colored_polygon(PackedVector2Array([_p(8, 1), _p(30, 8), _p(50, 10), _p(50, 2)]), GOLD_DARK)
	b.draw_line(_p(4, 0), _p(30, 0), INK, 2.0)
	b.draw_circle(_p(32, 0), 3.0, INK)
	# grip section
	var grip := PackedVector2Array([_p(50, -11), _p(104, -12), _p(104, 12), _p(50, 11)])
	b.draw_colored_polygon(_grow(grip, 3.0), INK)
	b.draw_colored_polygon(grip, Color(0.1, 0.08, 0.1))
	b.draw_line(_p(56, -6), _p(100, -6), Color(0.4, 0.36, 0.42), 2.0)
	# barrel
	var barrel := PackedVector2Array([_p(104, -14), _p(372, -13), _p(384, -8), _p(384, 8), _p(372, 13), _p(104, 14)])
	b.draw_colored_polygon(_grow(barrel, 3.0), INK)
	b.draw_colored_polygon(barrel, BARREL)
	b.draw_line(_p(112, -7), _p(370, -7), BARREL_LIGHT, 4.0)
	b.draw_line(_p(112, 8), _p(370, 8), Color(0.32, 0.2, 0.1), 3.0)
	for s in [104.0, 116.0, 350.0, 362.0]:
		b.draw_line(_p(s, -14), _p(s, 14), GOLD, 5.0)
		b.draw_line(_p(s + 2.5, -14), _p(s + 2.5, 14), INK, 1.0)
	# filigree on the barrel
	for k in 5:
		var s := 150.0 + k * 40.0
		b.draw_arc(_p(s, 0), 8.0, -1.0, 2.2, 6, Color(GOLD, 0.7), 1.6)
	# the clip
	b.draw_line(_p(300, -16), _p(372, -18), GOLD, 4.0)


func _draw_hand(b) -> void:
	# carpals: a cluster of knobbly little bones
	for c in [Vector2(238, 96), Vector2(258, 84), Vector2(250, 110), Vector2(272, 98), Vector2(232, 80)]:
		var p := _p(c.x, c.y)
		b.draw_circle(p, 13.0, INK)
		b.draw_circle(p, 10.0, BONE)
	# metacarpals + fingers, back (pinky) to front (index); each wraps over the pen
	var knuckles := [Vector2(204, 38), Vector2(224, 48), Vector2(242, 60), Vector2(256, 74)]
	var fingers := [
		[Vector2(204, 38), Vector2(164, 22), Vector2(130, 4), Vector2(110, -12)],
		[Vector2(224, 48), Vector2(200, 18), Vector2(186, -6), Vector2(176, -24)],
		[Vector2(242, 60), Vector2(232, 30), Vector2(222, 2), Vector2(214, -18)],
		[Vector2(256, 74), Vector2(252, 46), Vector2(246, 22), Vector2(240, 6)],
	]
	for i in range(3, -1, -1):
		var kn: Vector2 = knuckles[i]
		_bone(b, _p(250 + i * 6, 90 + i * 4), _p(kn.x, kn.y), 13.0 - i)
		var pts: Array = []
		for q in fingers[i]:
			pts.append(_p(q.x, q.y))
		var curl := _flex * (1.0 + i * 0.2) + 0.04 * sin(_time * 2.0 + i)
		_finger(b, pts, 13.0 - i * 1.4, curl)


static func _grow(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var g := Geometry2D.offset_polygon(poly, by)
	return g[0] if not g.is_empty() else poly
