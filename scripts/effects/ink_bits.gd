extends Node2D
## Loose paper and ink-splat particles ("PARTICLE FX: fragmented bits" on the
## Scary Scribbles sheet): torn paper scraps with a ruled line, jagged ink
## shards, ink drops and short scribble strokes, flung out, tumbling and
## falling, then fading. They move smoothly but re-draw their jagged edges
## at 12 fps, like the monsters. One draw call (ink_batch.gd).
##
##   InkBits.burst(tree, pos, 30, 420.0)                  # all round
##   InkBits.burst(tree, pos, 12, 300.0, Vector2.LEFT)    # mostly one way

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const INK := Color(0.04, 0.03, 0.07)
const PAPER := Color(0.93, 0.9, 0.82)
const RULE := Color(0.55, 0.68, 0.85)

enum Kind { SHARD, PAPER, DROP, STROKE }

## [pos, vel, rot, spin, life, max_life, kind, size, seed]
var _bits: Array = []
var _time := 0.0
var _batch := InkBatch.new()


## Spawns `count` bits at `pos` (world), flung at up to `power` px/s, biased
## towards `dir` when it isn't zero. `paper` 0..1 is the share of paper scraps.
static func burst(tree: SceneTree, pos: Vector2, count: int, power: float, dir := Vector2.ZERO, paper := 0.35) -> Node2D:
	var scene := tree.current_scene
	if scene == null:
		return null
	var fx: Node2D = load("res://scripts/effects/ink_bits.gd").new()
	fx.z_index = 6
	scene.add_child(fx)
	fx.add(pos, count, power, dir, paper)
	return fx


func add(pos: Vector2, count: int, power: float, dir := Vector2.ZERO, paper := 0.35) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2.from_angle(a) * randf_range(0.25, 1.0) * power
		if dir != Vector2.ZERO:
			v = (v * 0.55 + dir.normalized() * randf_range(0.4, 1.0) * power).limit_length(power * 1.3)
		v.y -= power * 0.35  # a little upward kick
		var kind: int = Kind.PAPER if randf() < paper else [Kind.SHARD, Kind.DROP, Kind.STROKE, Kind.SHARD].pick_random()
		var life := randf_range(0.6, 1.4) * (1.6 if kind == Kind.PAPER else 1.0)
		var size := randf_range(4.0, 11.0) * (1.4 if kind == Kind.PAPER else 1.0)
		_bits.append([pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), v, randf() * TAU,
			randf_range(-9.0, 9.0), life, life, kind, size, randi() % 997])


func _process(delta: float) -> void:
	_time += delta
	var i := _bits.size() - 1
	while i >= 0:
		var b: Array = _bits[i]
		b[4] -= delta
		if b[4] <= 0.0:
			_bits.remove_at(i)
			i -= 1
			continue
		var paper: bool = b[6] == Kind.PAPER
		# paper flutters down slowly; ink falls fast
		var g := 260.0 if paper else 1100.0
		var drag := 2.6 if paper else 0.8
		b[1] = b[1] * maxf(1.0 - drag * delta, 0.0) + Vector2(0, g * delta)
		if paper:
			b[1].x += sin(_time * 7.0 + b[8]) * 140.0 * delta
		b[0] += b[1] * delta
		b[2] += b[3] * delta
		i -= 1
	if _bits.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var frame := int(_time * 12.0)
	var rng := RandomNumberGenerator.new()
	for b in _bits:
		var pos: Vector2 = b[0]
		var a: float = b[2]
		var s: float = b[7]
		var k: float = clampf(b[4] / b[5] * 2.0, 0.0, 1.0)  # fades over the last half
		rng.seed = b[8] * 31 + frame
		match b[6]:
			Kind.PAPER:
				var pts := PackedVector2Array()
				var corners := [Vector2(-1, -0.7), Vector2(1, -0.8), Vector2(0.9, 0.7), Vector2(-0.8, 0.8)]
				for c in corners:
					pts.append(pos + (c * s + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))).rotated(a))
				_batch.draw_colored_polygon(pts, Color(PAPER, k))
				_batch.draw_line(pos + Vector2(-s * 0.8, 0).rotated(a), pos + Vector2(s * 0.8, 0).rotated(a), Color(RULE, k * 0.8), 1.0)
				pts.append(pts[0])
				_batch.draw_polyline(pts, Color(INK, k * 0.7), 1.0)
			Kind.SHARD:
				var pts := PackedVector2Array()
				for j in 5:
					var r := s * rng.randf_range(0.35, 1.0)
					pts.append(pos + Vector2.from_angle(a + TAU * j / 5.0) * r)
				_batch.draw_colored_polygon(pts, Color(INK, k))
			Kind.DROP:
				_batch.draw_circle(pos, s * 0.45, Color(INK, k))
				_batch.draw_line(pos, pos - b[1] * 0.02, Color(INK, k * 0.8), s * 0.5)
			Kind.STROKE:
				var pts := PackedVector2Array()
				for j in 4:
					pts.append(pos + Vector2(j * s * 0.6 - s, rng.randf_range(-s, s) * 0.5).rotated(a))
				_batch.draw_polyline(pts, Color(INK, k), 1.8)
	_batch.flush(self)
