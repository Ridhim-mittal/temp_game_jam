extends Node2D
## Hover cars drifting across the City's sky between the skylines
## (comic_background.tscn: a far layer, small and hazy, and a nearer one).
## Each lane runs one way; cars are spaced along it with gaps, bob a little,
## and carry a headlight beam, a cyan thruster glow and a red tail streak.
## Placed by deterministic hashing, so nothing is stored. One draw call.
## Lanes are in the parent Parallax2D's screen space (see comic_parallax.gd).

const ComicView = preload("res://scripts/background/comic_view.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")

## Height of each lane (local y); even lanes run right, odd ones left.
@export var lanes := PackedFloat32Array([220.0, 262.0])
@export var speed := 80.0
@export var car_scale := 1.0
## Distance between car slots along a lane; some slots stay empty.
@export var spacing := 420.0
@export_range(0.0, 1.0) var fill := 0.6
## How much the far haze washes the cars out (0 = full colour).
@export_range(0.0, 1.0) var haze := 0.0
@export var haze_color := Color(0.62, 0.62, 0.95)
@export var palette := PackedColorArray([Color(0.95, 0.42, 0.62), Color(0.42, 0.52, 0.95), Color(0.98, 0.72, 0.36),
	Color(0.55, 0.36, 0.82), Color(0.36, 0.82, 0.86)])
@export var ink := Color(0.06, 0.03, 0.13)
@export var seed := 1

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = ComicView.local_view(self).rect
	var b := InkBatch.new()
	var margin := 80.0 * car_scale
	for li in lanes.size():
		var dir := 1.0 if (li + seed) % 2 == 0 else -1.0
		var sp := speed * (0.85 + 0.3 * float(li))
		var base := fmod(_t * sp * dir, spacing * 64.0)
		var k0 := floori((rect.position.x - margin - base) / spacing)
		var k1 := ceili((rect.end.x + margin - base) / spacing)
		for k in range(k0, k1 + 1):
			var h := absi(hash(Vector3i(seed, li, k)))
			if float(h % 1000) / 1000.0 > fill:
				continue
			var x := base + k * spacing + float(h % 97) / 97.0 * spacing * 0.5
			var y := lanes[li] + sin(_t * 1.6 + float(h % 13)) * 2.5 * car_scale + float((h >> 4) % 11) - 5.0
			_car(b, Vector2(x, y), dir, palette[(h >> 8) % palette.size()], h)
	b.flush(self)


func _hz(c: Color) -> Color:
	return Color(c.lerp(haze_color, haze), c.a)


func _car(b: InkBatch, at: Vector2, dir: float, col: Color, h: int) -> void:
	var s := car_scale
	var pts := func(arr: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p: Vector2 in arr:
			out.append(at + Vector2(p.x * dir, p.y) * s)
		return out
	# the headlight beam ahead and the tail streak behind
	b.draw_polygon(pts.call([Vector2(17, -1), Vector2(62, -10), Vector2(62, 9)]),
		PackedColorArray([Color(1.0, 0.95, 0.7, 0.45 * (1.0 - haze)), Color(1.0, 0.95, 0.7, 0.0), Color(1.0, 0.95, 0.7, 0.0)]))
	b.draw_polygon(pts.call([Vector2(-17, -2), Vector2(-17, 1), Vector2(-54, 0)]),
		PackedColorArray([Color(1.0, 0.25, 0.3, 0.7 * (1.0 - haze)), Color(1.0, 0.25, 0.3, 0.7 * (1.0 - haze)), Color(1.0, 0.25, 0.3, 0.0)]))
	# thruster glow under it
	var glow := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		glow.append(at + Vector2(cos(a) * 13.0, 6.5 + sin(a) * 2.6) * s)
	b.draw_colored_polygon(glow, Color(0.45, 0.95, 1.0, 0.35 * (1.0 - haze)))
	# the body: a sleek wedge, a dark underside, a glass canopy
	var body: PackedVector2Array = pts.call([Vector2(-17, -3), Vector2(-12, -6), Vector2(8, -6), Vector2(17, -1),
		Vector2(17, 2), Vector2(12, 5), Vector2(-14, 5), Vector2(-18, 2)])
	b.draw_colored_polygon(body, _hz(col))
	b.draw_colored_polygon(pts.call([Vector2(-14, 2), Vector2(14, 2), Vector2(12, 5), Vector2(-14, 5)]), _hz(col.darkened(0.45)))
	b.draw_colored_polygon(pts.call([Vector2(-6, -6), Vector2(-3, -11), Vector2(5, -11), Vector2(9, -6)]),
		_hz(Color(0.75, 0.95, 1.0) if h % 3 else Color(0.95, 0.85, 1.0)))
	b.draw_line(at + Vector2(-2 * dir, -10) * s, at + Vector2(4 * dir, -10) * s, Color(1, 1, 1, 0.7 * (1.0 - haze)), 1.2 * s)
	var outline := body.duplicate()
	outline.append(body[0])
	b.draw_polyline(outline, _hz(ink), maxf(1.0, 1.8 * s))
	# lights: head (warm), tail (red), a stripe of the City's neon
	b.draw_circle(at + Vector2(16 * dir, 0) * s, 1.6 * s, Color(1.0, 0.97, 0.75))
	b.draw_circle(at + Vector2(-17 * dir, 0) * s, 1.5 * s, Color(1.0, 0.3, 0.35))
	b.draw_line(at + Vector2(-12 * dir, -1) * s, at + Vector2(10 * dir, -1) * s, _hz(Color(0.4, 0.95, 1.0, 0.8)), 1.0 * s)
