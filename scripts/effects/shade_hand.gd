extends Node2D
## Shade's hand (the final fight in Shade's City): a huge skeletal hand gripping
## a golden fountain pen, trailing ink from the wrist. It draws monsters into
## the world: the nib swoops down and traces the monster's outline stroke by
## stroke (the fingers flex as it writes, the tip glows), then the sketch flares
## with light and the monster is born: `drawn(kind, at)` fires and the caller
## spawns the real enemy there (`materialize()` gives it a pop-in).
##
##   hand.draw_monster("spider", Vector2(500, 600))   # kinds: spider bat blot eraser pen
##   hand.write_name(Vector2(300, 60))                # "SHADE" in huge dripping brush ink
##
## Place at the world origin; `rest` is where the hand hovers between drawings.
## Everything is drawn in code through InkBatch (one draw call per layer).

signal drawn(kind: String, at: Vector2)
## The hand finished writing its name (`write_name()`).
signal wrote_name

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
const BONE := Color(0.88, 0.85, 0.76)
const BONE_SHADE := Color(0.56, 0.52, 0.52)
const GOLD := Color(0.95, 0.76, 0.32)
const GOLD_DARK := Color(0.6, 0.42, 0.16)
const BARREL := Color(0.55, 0.38, 0.2)
const BARREL_LIGHT := Color(0.82, 0.62, 0.36)
const GLOW := Color(1.0, 0.86, 0.45)
const RIM_DARK := Color(0.24, 0.17, 0.4)
const PAPER := Color(0.93, 0.89, 0.78)
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
var _names: Array = []  # "SHADE" written in the sky: {strokes, done, age}
var _name_layer: Node2D
var _xf := Transform2D.IDENTITY  # hand space -> world, from the last draw
var _tips := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]  # claw points (hand space)
var _drips: Array = []  # {p, v, age, r} world space
var _drip_t := 0.0


func _ready() -> void:
	z_index = 40
	_nib = rest
	_sketch_layer = Node2D.new()
	_sketch_layer.z_index = -38  # the sketches sit in the world, under the hand (z 40 - 38 = 2)
	_sketch_layer.draw.connect(_paint_sketches)
	add_child(_sketch_layer)
	_name_layer = Node2D.new()
	_name_layer.z_index = -45  # far back: behind the street and the monsters (z -5), over the painting
	_name_layer.draw.connect(_paint_names)
	add_child(_name_layer)


## Queue a monster drawing. `at` = the monster's feet in world space.
func draw_monster(kind: String, at: Vector2) -> void:
	_queue.append([kind, at])


## Write "SHADE" across the sky in huge brush strokes; `at` = the top-left of
## the S, `size` scales the letters (1 = 200 px tall). It stays for good.
func write_name(at: Vector2, size := 1.0) -> void:
	_queue.append(["__name__", at, size])


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
	_drip_t -= delta
	if _drip_t <= 0.0:
		# ink drips off a claw now and then, and off the nib while it writes
		_drip_t = randf_range(0.18, 0.45)
		var from: Vector2 = _xf * (_tips[randi() % _tips.size()] if randf() < 0.6 or _job.is_empty() else Vector2.ZERO)
		_drips.append({"p": from, "v": Vector2(randf_range(-10, 10), 40.0), "age": 0.0, "r": randf_range(2.5, 4.5)})
	for d in _drips:
		d.age += delta
		d.v.y += 900.0 * delta
		d.p += d.v * delta
	_drips = _drips.filter(func(d): return d.age < 1.4)
	for s in _sketches:
		s.age += delta
		if s.born:
			s.life -= delta
	_sketches = _sketches.filter(func(s): return s.life > 0.0)
	for n in _names:
		n.age += delta
	queue_redraw()
	_sketch_layer.queue_redraw()
	_name_layer.queue_redraw()


func _start(job: Array) -> void:
	var is_name: bool = job[0] == "__name__"
	var strokes: Array = _name_strokes(job[2]) if is_name else _strokes(job[0])
	var sk := {"strokes": [], "done": [], "at": job[1], "age": 0.0, "born": false, "life": 0.9, "flare": 0.0}
	for st in strokes:
		var world := PackedVector2Array()
		for p in st:
			world.append(job[1] + p)
		sk.strokes.append(world)
		sk.done.append(0.0)
	if is_name:
		_names.append(sk)
	else:
		_sketches.append(sk)
	_job = {"kind": job[0], "at": job[1], "sketch": sk, "stroke": 0, "lifting": true, "birth": 0.0,
		"speed": 2.4 if is_name else 1.0}


func _run_job(delta: float) -> void:
	var sk: Dictionary = _job.sketch
	var i: int = _job.stroke
	if i >= sk.strokes.size() and _job.kind == "__name__":
		_job = {}
		wrote_name.emit()
		return
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
	var left: float = draw_speed * delta * _job.speed
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


## "SHADE" as brush strokes, leaning forward, 200 px tall at size 1.
static func _name_strokes(size: float) -> Array:
	var letters := [
		[[Vector2(112, 22), Vector2(70, 0), Vector2(22, 18), Vector2(14, 62), Vector2(60, 98), Vector2(108, 128),
			Vector2(116, 172), Vector2(74, 200), Vector2(18, 192), Vector2(-4, 168)]],
		[[Vector2(14, 0), Vector2(4, 204)], [Vector2(118, -6), Vector2(122, 200)], [Vector2(-6, 104), Vector2(132, 92)]],
		[[Vector2(-8, 204), Vector2(62, -8), Vector2(132, 204)], [Vector2(20, 128), Vector2(112, 120)]],
		[[Vector2(12, -4), Vector2(4, 206)], [Vector2(0, 2), Vector2(70, 8), Vector2(118, 52), Vector2(126, 128),
			Vector2(96, 186), Vector2(30, 204), Vector2(-6, 198)]],
		[[Vector2(126, 4), Vector2(10, 0), Vector2(4, 204), Vector2(132, 196)], [Vector2(6, 100), Vector2(106, 92)]],
	]
	var out: Array = []
	for i in letters.size():
		for st in letters[i]:
			var pts: Array = []
			for q in st:
				# slant forward, a little ragged, letter by letter along the line
				var v: Vector2 = q
				pts.append((Vector2(i * 168.0 + v.x - v.y * 0.18, v.y + sin(i * 2.1) * 12.0)) * size)
			out.append(_line(pts))
	return out


## The name in the sky: thick dry-brush ink that swells and tapers, scratchy
## bristle streaks along it, splatters flung off the strokes, and ink running
## down from the letters in long drips.
func _paint_names() -> void:
	var b := InkBatch.new()
	for nm in _names:
		var age: float = nm.age
		for i in nm.strokes.size():
			var st: PackedVector2Array = nm.strokes[i]
			var done: float = nm.done[i]
			if done <= 0.0:
				continue
			var n := mini(int(done) + 1, st.size() - 1)
			for k in n:
				var t := float(k) / maxf(st.size() - 1, 1)
				var a := st[k]
				var c := st[k + 1] if k + 1 < n or done >= st.size() - 1 else st[k].lerp(st[k + 1], done - int(done))
				# fat in the middle, sharp at the ends, uneven like a loaded brush
				var wide := 30.0 * pow(sin(PI * clampf(t * 0.96 + 0.02, 0.0, 1.0)), 0.6) * (0.75 + 0.35 * sin(k * 1.7 + i))
				b.draw_line(a, c, INK, wide)
				b.draw_circle(c, wide * 0.42, INK)
				# dry-brush bristle streaks, broken here and there
				var d := (c - a).normalized()
				var nrm := d.orthogonal()
				for j in 3:
					if sin(k * (1.3 + j) + i * 2.0 + j) > -0.2:
						var off := nrm * (wide * 0.5 + 4.0 + j * 5.0) * (1.0 if j % 2 == 0 else -1.0)
						b.draw_line(a + off, c + off, INK, 2.0 - j * 0.4)
			# splatters flung off the stroke
			for k in 4:
				var q := st[int(fmod(k * 7.3 + i * 3.0, st.size()))]
				if (int(fmod(k * 7.3 + i * 3.0, st.size()))) > int(done):
					continue
				var fling := Vector2(sin(k * 2.7 + i), cos(k * 1.9 + i * 1.3)) * (30.0 + k * 9.0)
				b.draw_circle(q + fling, 3.0 + 3.0 * absf(sin(k + i)), INK)
				b.draw_line(q + fling * 0.6, q + fling, INK, 2.0)
			# drips running down from the lowest points, growing longer
			if done >= st.size() - 1:
				for k in [0, st.size() - 1, st.size() / 2]:
					var q: Vector2 = st[k]
					var grow := minf(age * 22.0, 40.0 + 70.0 * absf(sin(k + i * 1.7)))
					b.draw_line(q, q + Vector2(0, grow), INK, 5.0)
					b.draw_circle(q + Vector2(0, grow), 5.5, INK)
	b.flush(_name_layer)


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
	_xf = xf
	b.draw_set_transform_matrix(xf)
	_draw_aura(b)
	_draw_smoke(b)
	# nib glow
	var g := _glow * (0.85 + 0.15 * sin(_time * 18.0))
	b.draw_circle(Vector2.ZERO, 46.0 * g, Color(GLOW, 0.12))
	b.draw_circle(Vector2.ZERO, 24.0 * g, Color(GLOW, 0.3))
	b.draw_circle(Vector2.ZERO, 9.0 * g, Color(1.0, 0.98, 0.88, 0.85))
	_draw_thumb(b)
	_draw_pen(b)
	_draw_hand(b)
	_draw_scraps(b)
	# ink drips falling off the claws and the nib (world space)
	b.draw_set_transform_matrix(Transform2D.IDENTITY)
	for d in _drips:
		var a: float = 1.0 - d.age / 1.4
		var dp: Vector2 = d.p
		var r: float = d.r
		b.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -r * 3.2), dp + Vector2(r, 0), dp + Vector2(0, r),
			dp + Vector2(-r, 0)]), Color(INK, a))
	b.flush(self)


## A dark halo of ink-shadow round the hand, so it looms out of the city.
func _draw_aura(b) -> void:
	# many faint layers, so it fades softly instead of showing disc edges
	var c := _p(220, 70)
	for k in 10:
		b.draw_circle(c + Vector2(sin(_time * 0.8 + k) * 6.0, 0), 60.0 + k * 22.0, Color(0.05, 0.01, 0.08, 0.035))


## The arm: forearm bones vanishing into boiling ink smoke, with ink tendrils
## curling out of it like hooks and splatters flung round it.
func _draw_smoke(b) -> void:
	var w := _p(262, 104)  # the wrist (the carpals sit just below)
	var f := FOREARM
	var side := Vector2(-f.y, f.x)
	# radius and ulna, long and knobbly, running up into the smoke
	_bone(b, w + side * 12.0, w + side * 16.0 + f * 190.0, 17.0)
	_bone(b, w - side * 13.0, w - side * 9.0 + f * 175.0, 13.0)
	# tendrils first, so the smoke sits over their roots
	for k in 9:
		var t0 := 0.15 + k * 0.09
		var start := w + f * (110.0 + 420.0 * t0) + side * (30.0 if k % 2 == 0 else -34.0)
		var ang := (Vector2(0.1, 1.0) if k % 3 == 0 else (Vector2(-0.8, 0.55) if k % 3 == 1 else Vector2(0.3, -1.0))).angle()
		var turn := (1.0 if k % 2 == 0 else -1.0) * (2.4 + 0.6 * sin(k * 1.7))
		var length := 150.0 + 90.0 * absf(sin(k * 2.1))
		_tendril(b, start, ang, turn, length, 11.0 - (k % 3) * 2.0, k)
	# a torrent of ragged ink along the forearm: spiky edges that flicker like black flame
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var n := 26
	for k in n + 1:
		var t := float(k) / n
		var along := w + f * (90.0 + 470.0 * t)
		var thick := 22.0 + 34.0 * t
		var spike := 1.0 if k % 2 == 0 else 0.0
		var flick := sin(_time * 7.0 + k * 1.9) * 0.5 + 0.5
		var lick_top := thick + spike * (16.0 + 26.0 * flick) * (0.4 + t)
		var lick_bot := thick + (1.0 - spike) * (14.0 + 30.0 * flick) * (0.4 + t)
		top.append(along + side * lick_top + f * spike * 10.0 * sin(_time * 3.0 + k))
		bottom.append(along - side * lick_bot - f * (1.0 - spike) * 12.0)
	var rim := top.duplicate()
	for k in rim.size():
		rim[k] += side * 3.0
	bottom.reverse()
	b.draw_colored_polygon(rim + bottom, RIM_DARK)  # a cold violet edge where the moon catches it
	b.draw_colored_polygon(top + bottom, INK)
	# brush streaks tearing off the ink, dragged back along the arm
	for k in 10:
		var t := 0.1 + k * 0.085
		var off := (1.0 if k % 2 == 0 else -1.0) * (60.0 + 40.0 * t + 10.0 * sin(_time * 2.0 + k))
		var a0 := w + f * (100.0 + 470.0 * t) + side * off
		var a1 := a0 + f * (80.0 + 60.0 * absf(sin(k * 1.3))) + side * sin(_time * 1.5 + k) * 10.0
		var wide := 5.0 + 4.0 * absf(sin(k * 2.3))
		b.draw_colored_polygon(PackedVector2Array([a0 - side * wide * 0.3, a0.lerp(a1, 0.35) + side * wide,
			a1, a0.lerp(a1, 0.5) - side * wide * 0.6]), INK)
	# the ragged front of the smoke, licking down over the wrist bones
	for k in 6:
		var e := w + f * (80.0 + k * 6.0) + side * (-36.0 + k * 14.0)
		var lick := f * -(26.0 + 14.0 * (k % 2) + sin(_time * 3.0 + k) * 6.0)
		b.draw_colored_polygon(PackedVector2Array([e + side * 9.0, e + lick, e - side * 9.0, e + f * 20.0]), INK)
	# splatters flung off it
	for k in 14:
		var t := fmod(k * 0.37, 1.0)
		var c := w + f * (120.0 + 400.0 * t) + side * (90.0 + 50.0 * sin(k * 3.1)) * (1.0 if k % 2 == 0 else -1.0)
		b.draw_circle(c, 2.0 + 4.0 * absf(sin(k * 1.9)), INK)


## One ink tendril: a tapering ribbon that bends harder and harder until it
## curls into a hook at the end (the swirls in the painting).
func _tendril(b, start: Vector2, ang: float, turn: float, length: float, width: float, seed: int) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var p := start
	var steps := 16
	var a := ang
	for j in steps + 1:
		var t := float(j) / steps
		var dir := Vector2.from_angle(a)
		var wide := width * (1.0 - t * 0.9)
		left.append(p + dir.orthogonal() * wide)
		right.append(p - dir.orthogonal() * wide)
		a += turn * t * t * 0.32 + sin(_time * 2.0 + seed + j * 0.5) * 0.05
		p += dir * length / steps
	right.reverse()
	b.draw_colored_polygon(left + right, INK)


## Torn pages caught in the smoke, fluttering round the arm.
func _draw_scraps(b) -> void:
	var w := _p(262, 104)
	for k in 5:
		var c := w + FOREARM * (160.0 + k * 75.0) + Vector2(-FOREARM.y, FOREARM.x) * (70.0 * sin(_time * 0.6 + k * 2.2))
		c += Vector2(0, sin(_time * 1.7 + k) * 14.0)
		var rot := _time * (0.7 + k * 0.2) * (1.0 if k % 2 == 0 else -1.0)
		var flip := absf(sin(_time * 2.2 + k))  # pages tumbling: squash one way
		var x := Vector2.from_angle(rot) * 16.0 * maxf(flip, 0.2)
		var y := Vector2.from_angle(rot + PI * 0.5) * 11.0
		var quad := PackedVector2Array([c - x - y, c + x - y + y * 0.2, c + x + y, c - x + y - y * 0.3])
		b.draw_colored_polygon(_grow(quad, 2.0), INK)
		b.draw_colored_polygon(quad, PAPER)
		b.draw_line(c - x * 0.7 - y * 0.4, c + x * 0.6 - y * 0.5, Color(INK, 0.7), 1.2)
		b.draw_line(c - x * 0.7 + y * 0.1, c + x * 0.4, Color(INK, 0.7), 1.2)
		b.draw_line(c - x * 0.5 + y * 0.5, c + x * 0.7 + y * 0.45, Color(0.6, 0.05, 0.08, 0.8), 1.2)


## A gnarled bone: knobbly joint ends, a thin waist, one side in shadow with
## comic hatching, a crack, and ink stains seeping in from the joints.
func _bone(b, a: Vector2, c: Vector2, w: float, stained := 0.0) -> void:
	var d := (c - a).normalized()
	var n := d.orthogonal()
	var len := a.distance_to(c)
	var cap := minf(w * 0.45, len * 0.3)
	var outline := PackedVector2Array([
		a - d * cap * 0.8, a + n * w * 0.62 - d * cap * 0.2, a + n * w * 0.5 + d * cap,
		a.lerp(c, 0.5) + n * w * 0.3,
		c + n * w * 0.5 - d * cap, c + n * w * 0.66 + d * cap * 0.1, c + d * cap * 0.9,
		c - n * w * 0.66 + d * cap * 0.1, c - n * w * 0.5 - d * cap,
		a.lerp(c, 0.5) - n * w * 0.3,
		a - n * w * 0.5 + d * cap, a - n * w * 0.62 - d * cap * 0.2])
	b.draw_colored_polygon(_grow(outline, 3.0), INK)
	b.draw_colored_polygon(outline, BONE)
	# shadow side
	b.draw_colored_polygon(PackedVector2Array([a - n * w * 0.62 - d * cap * 0.2, a - n * w * 0.05 + d * cap,
		c - n * w * 0.05 - d * cap, c - n * w * 0.66 + d * cap * 0.1, c - n * w * 0.5 - d * cap,
		a.lerp(c, 0.5) - n * w * 0.3, a - n * w * 0.5 + d * cap]), BONE_SHADE)
	# hatching across the shadow
	var hatch := int(len / 9.0)
	for k in hatch:
		var t := (k + 0.5) / hatch
		var q := a.lerp(c, t)
		b.draw_line(q - n * w * 0.12, q - n * w * 0.36 + d * 3.0, Color(INK, 0.55), 1.2)
	# a crack
	if len > 40.0:
		var q0 := a.lerp(c, 0.35) + n * w * 0.15
		b.draw_polyline(PackedVector2Array([q0, q0 + d * 6.0 - n * 3.0, q0 + d * 11.0 + n * 1.0, q0 + d * 17.0 - n * 2.0]), INK, 1.4)
	# ink seeping out of the joints
	b.draw_circle(a + d * cap * 0.3, w * 0.22, Color(INK, 0.55))
	if stained > 0.0:
		b.draw_colored_polygon(PackedVector2Array([c.lerp(a, stained) + n * w * 0.3, c + n * w * 0.6, c + d * cap * 0.9,
			c - n * w * 0.6, c.lerp(a, stained) - n * w * 0.3]), Color(INK, 0.85))


func _finger(b, pts: Array, w: float, curl: float, claw := 1.0) -> Vector2:
	# knuckle -> joints -> tip; curl pulls the outer joints in towards the knuckle
	var k0: Vector2 = pts[0]
	var out: Array = [k0]
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i]
		out.append(p.lerp(k0, curl * i / (pts.size() - 1.0) * 0.35))
	for i in out.size() - 1:
		var last := i == out.size() - 2
		var a0: Vector2 = out[i]
		var a1: Vector2 = out[i + 1]
		var bw := w * (1.0 - i * 0.16)
		var d := (a1 - a0).normalized()
		var n := d.orthogonal()
		_bone(b, a0, a1, bw, 0.55 if last else 0.0)
		# a sinew strung along the inside of the bone, sagging between the joints
		b.draw_polyline(PackedVector2Array([a0 - n * bw * 0.55, a0.lerp(a1, 0.5) - n * bw * 0.85, a1 - n * bw * 0.55]),
			Color(0.35, 0.08, 0.1), 2.2)
		b.draw_polyline(PackedVector2Array([a0 - n * bw * 0.45, a0.lerp(a1, 0.5) - n * bw * 0.7, a1 - n * bw * 0.45]),
			Color(INK, 0.8), 1.0)
		# a bony spur on the back of each joint
		b.draw_colored_polygon(PackedVector2Array([a1 + n * bw * 0.45 - d * 4.0, a1 + n * bw * 1.25 - d * 2.0,
			a1 + n * bw * 0.45 + d * 5.0]), INK)
		b.draw_colored_polygon(PackedVector2Array([a1 + n * bw * 0.5 - d * 2.0, a1 + n * bw * 1.05 - d * 1.5,
			a1 + n * bw * 0.5 + d * 3.0]), BONE_SHADE)
		# a dark joint socket
		b.draw_circle(a1, bw * 0.28, Color(INK, 0.8))
		# tattered strips of ink-black skin still clinging to the middle bone
		if i == 1:
			var m := a0.lerp(a1, 0.45)
			var rag := PackedVector2Array([m - d * bw * 0.5 + n * bw * 0.75, m + d * bw * 0.6 + n * bw * 0.7,
				m + d * bw * 0.9 - n * bw * 0.1, m + d * bw * 0.4 - n * (bw * 0.8 + 5.0 + 3.0 * sin(_time * 4.0 + w)),
				m - n * bw * 0.6, m - d * bw * 0.7 - n * (bw * 0.9 + 4.0)])
			b.draw_colored_polygon(rag, INK)
			b.draw_line(m - d * bw * 0.4 + n * bw * 0.5, m + d * bw * 0.5 + n * bw * 0.45, RIM_DARK, 1.5)
	# a long black claw, hooked like a nib, curling round the pen
	var tip: Vector2 = out[out.size() - 1]
	var dir: Vector2 = (tip - out[out.size() - 2]).normalized()
	var hook := dir.rotated(0.9 * (1.0 if claw > 0.0 else -1.0))
	var l := w * 3.4 * absf(claw)
	var c1 := tip + dir * l * 0.55
	var c2 := c1 + hook * l * 0.55
	var o := dir.orthogonal()
	var claw_pts := PackedVector2Array([tip + o * w * 0.45, c1 + o * w * 0.24, c2,
		c1 - o * w * 0.1, tip.lerp(c1, 0.7) - o * w * 0.42, tip.lerp(c1, 0.55) - o * w * 0.2,
		tip.lerp(c1, 0.4) - o * w * 0.5, tip.lerp(c1, 0.25) - o * w * 0.3, tip - o * w * 0.48])  # serrated inner edge
	b.draw_colored_polygon(_grow(claw_pts, 1.5), Color(0.9, 0.85, 0.8, 0.6))
	b.draw_colored_polygon(claw_pts, INK)
	b.draw_line(tip + dir * l * 0.15, c1, Color(0.4, 0.32, 0.5), 1.4)  # a glint on the claw
	return c2


func _draw_thumb(b) -> void:
	_tips[4] = _finger(b, [_p(222, 102), _p(170, 84), _p(128, 52), _p(100, 24)], 19.0, _flex, -1.0)


func _draw_pen(b) -> void:
	# nib (gold, with its slit and breather hole), a bead of ink on the tip
	var nib := PackedVector2Array([_p(0, 0), _p(30, -9), _p(50, -11), _p(50, 11), _p(30, 9)])
	b.draw_colored_polygon(_grow(nib, 3.0), INK)
	b.draw_colored_polygon(nib, GOLD)
	b.draw_colored_polygon(PackedVector2Array([_p(8, 1), _p(30, 8), _p(50, 10), _p(50, 2)]), GOLD_DARK)
	b.draw_line(_p(4, 0), _p(30, 0), INK, 2.0)
	b.draw_circle(_p(32, 0), 3.0, INK)
	b.draw_arc(_p(42, 0), 6.0, PI * 0.5, PI * 1.5, 6, INK, 1.2)  # engraving on the nib
	b.draw_circle(_p(2, 0), 4.0 + sin(_time * 5.0) * 1.0, INK)
	# grip section
	var grip := PackedVector2Array([_p(50, -11), _p(104, -12), _p(104, 12), _p(50, 11)])
	b.draw_colored_polygon(_grow(grip, 3.0), INK)
	b.draw_colored_polygon(grip, Color(0.08, 0.06, 0.08))
	b.draw_line(_p(56, -6), _p(100, -6), Color(0.4, 0.36, 0.42), 2.0)
	# barrel: old engraved brass
	var barrel := PackedVector2Array([_p(104, -14), _p(372, -13), _p(384, -8), _p(384, 8), _p(372, 13), _p(104, 14)])
	b.draw_colored_polygon(_grow(barrel, 3.0), INK)
	b.draw_colored_polygon(barrel, BARREL)
	b.draw_line(_p(112, -8), _p(370, -8), BARREL_LIGHT, 4.0)
	b.draw_line(_p(112, 9), _p(370, 9), Color(0.28, 0.17, 0.08), 4.0)
	for s in [104.0, 116.0, 350.0, 362.0]:
		b.draw_line(_p(s, -14), _p(s, 14), GOLD, 5.0)
		b.draw_line(_p(s + 2.5, -14), _p(s + 2.5, 14), INK, 1.0)
	# engraved scrollwork all along the barrel
	for k in 9:
		var sx := 132.0 + k * 25.0
		b.draw_arc(_p(sx, -1), 7.0, -1.2 + k, 2.0 + k, 7, Color(INK, 0.55), 1.4)
		b.draw_arc(_p(sx + 12, 2), 4.0, 0.5 + k, 3.6 + k, 5, Color(GOLD, 0.65), 1.2)
	# the clip
	b.draw_line(_p(300, -16), _p(372, -18), GOLD, 4.0)
	b.draw_line(_p(300, -16), _p(372, -18), Color(INK, 0.6), 1.0)


func _draw_hand(b) -> void:
	# carpals: a cluster of knobbly little bones, ink pooled between them
	b.draw_circle(_p(252, 94), 26.0, Color(INK, 0.9))
	for c in [Vector2(238, 96), Vector2(258, 84), Vector2(250, 110), Vector2(272, 98), Vector2(232, 80), Vector2(266, 114)]:
		var p := _p(c.x, c.y)
		b.draw_circle(p, 12.5, INK)
		b.draw_circle(p, 9.5, BONE)
		b.draw_circle(p + N * 3.0, 6.0, BONE_SHADE)
	# metacarpals + fingers, back (pinky) to front (index); each wraps over the pen
	var knuckles := [Vector2(204, 38), Vector2(224, 48), Vector2(242, 60), Vector2(256, 74)]
	var fingers := [
		[Vector2(204, 38), Vector2(164, 22), Vector2(130, 4), Vector2(110, -12)],
		[Vector2(224, 48), Vector2(200, 18), Vector2(186, -6), Vector2(176, -24)],
		[Vector2(242, 60), Vector2(232, 30), Vector2(222, 2), Vector2(214, -18)],
		[Vector2(256, 74), Vector2(256, 44), Vector2(254, 18), Vector2(250, -2)],
	]
	# now and then the pinky twitches, like the hand is impatient
	var twitch := maxf(sin(_time * 0.9) - 0.9, 0.0) * 6.0 * sin(_time * 40.0)
	for i in range(3, -1, -1):
		var kn: Vector2 = knuckles[i]
		_bone(b, _p(250 + i * 6, 90 + i * 4), _p(kn.x, kn.y), 16.0 - i)
		b.draw_circle(_p(kn.x, kn.y), 12.0 - i * 0.8, INK)  # swollen knuckle
		b.draw_circle(_p(kn.x, kn.y), 9.0 - i * 0.8, BONE)
		b.draw_circle(_p(kn.x, kn.y) + N * 3.0, 5.0 - i * 0.5, BONE_SHADE)
		var pts: Array = []
		for q in fingers[i]:
			pts.append(_p(q.x, q.y))
		var curl := _flex * (1.0 + i * 0.2) + 0.04 * sin(_time * 2.0 + i) + (twitch if i == 3 else 0.0)
		_tips[i] = _finger(b, pts, 17.0 - i * 1.6, curl)


static func _grow(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var g := Geometry2D.offset_polygon(poly, by)
	return g[0] if not g.is_empty() else poly
