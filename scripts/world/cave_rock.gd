@tool
extends StaticBody2D
## Rock of the Ink Cave (ink_cave.tscn): dark violet stone with a lip lit by
## the ink-fire (hot pink, with cyan and yellow glints) so the line Vesper
## stands on reads against the busy painting, cracks, and ink dripping off the
## underside. `one_way` makes it a ledge he can jump up through; `ground` draws
## the ground instead (thick, with glowing ink puddles along the top).
## Origin = top-left corner of the walkable top.

const InkBatch = preload("res://scripts/depth/ink_batch.gd")

@export var size := Vector2(300, 40):
	set(value):
		size = value
		queue_redraw()
		_update_shape()
@export var one_way := false:
	set(value):
		one_way = value
		_update_shape()
@export var ground := false:
	set(value):
		ground = value
		queue_redraw()
@export var rim := Color(1.0, 0.27, 0.66)

const INK := Color(0.03, 0.01, 0.05)
const STONE := Color(0.17, 0.13, 0.22)
const DEEP := Color(0.08, 0.06, 0.11)
const GLINTS := [Color(0.3, 0.85, 1.0), Color(1.0, 0.85, 0.25)]

var _shape: CollisionShape2D
var _time := 0.0


func _ready() -> void:
	collision_layer = 1
	_update_shape()


func _process(delta: float) -> void:
	_time += delta
	if not ground:
		queue_redraw()  # drips


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var r := RectangleShape2D.new()
	r.size = Vector2(size.x, size.y if not one_way else 16.0)
	_shape.shape = r
	_shape.position = Vector2(size.x * 0.5, r.size.y * 0.5)
	_shape.one_way_collision = one_way


func _draw() -> void:
	var b := InkBatch.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x * 7.0 + size.y * 13.0 + position.x)
	# body: a rough-edged slab (ledges taper underneath)
	var pts := PackedVector2Array([Vector2(-4, 0), Vector2(size.x + 4, 0)])
	if ground:
		pts.append(Vector2(size.x + 4, size.y))
		pts.append(Vector2(-4, size.y))
	else:
		var n := maxi(int(size.x / 40.0), 2)
		for i in range(n, -1, -1):
			var x := size.x * i / n
			var edge := minf(x, size.x - x) / (size.x * 0.5)
			pts.append(Vector2(x + rng.randf_range(-6, 6), size.y * (0.45 + 0.55 * sqrt(edge)) + rng.randf_range(-6, 8)))
	b.draw_colored_polygon(_grow(pts, 3.0), INK)
	b.draw_colored_polygon(pts, DEEP)
	# a lighter stone band under the lip
	b.draw_rect(Rect2(0, 0, size.x, minf(26.0, size.y * 0.5)), STONE)
	b.draw_rect(Rect2(0, 18, size.x, 6), Color(STONE, 0.5))
	# cracks
	var x0 := rng.randf_range(20, 80)
	while x0 < size.x - 20:
		var c := PackedVector2Array([Vector2(x0, 6)])
		var p := Vector2(x0, 6)
		for k in 3:
			p += Vector2(rng.randf_range(-10, 10), rng.randf_range(6, 12))
			c.append(p)
		b.draw_polyline(c, INK, 2.0)
		x0 += rng.randf_range(90, 180)
	# halftone shading into the dark (ground only)
	if ground:
		var y := 40.0
		while y < minf(size.y, 130.0):
			var k := 1.0 - (y - 40.0) / 90.0
			var xx := fmod(y, 24.0) * 0.5
			while xx < size.x:
				b.draw_circle(Vector2(xx, y), 2.6 * k, Color(rim, 0.12), true)
				xx += 12.0
			y += 10.0
	# the fire-lit lip, with glints of the other inks
	b.draw_rect(Rect2(-2, 0, size.x + 4, 4), rim)
	b.draw_rect(Rect2(-2, 4, size.x + 4, 2), INK)
	var gx := rng.randf_range(10, 60)
	while gx < size.x - 10:
		var w := rng.randf_range(14, 40)
		b.draw_rect(Rect2(gx, 0, w, 3), GLINTS[rng.randi() % 2])
		gx += rng.randf_range(80, 200)
	# glowing ink puddles on the ground
	if ground:
		var px := rng.randf_range(100, 300)
		while px < size.x - 60:
			var w := rng.randf_range(40, 110)
			var col: Color = [rim, GLINTS[0], GLINTS[1]][rng.randi() % 3]
			b.draw_colored_polygon(_ellipse(Vector2(px, 2), w * 0.5, 3.0), Color(col, 0.7))
			px += rng.randf_range(260, 520)
	# ink dripping off the underside (ledges)
	if not ground:
		for i in maxi(int(size.x / 90.0), 1):
			var dx := size.x * (i + 0.5) / maxf(int(size.x / 90.0), 1) + rng.randf_range(-20, 20)
			var bottom := size.y * 0.7
			var cyc := fmod(_time * 0.4 + rng.randf() * 3.0, 3.0)
			var l := 6.0 + 18.0 * minf(cyc / 2.0, 1.0)
			b.draw_colored_polygon(PackedVector2Array([Vector2(dx - 4, bottom - 4), Vector2(dx + 4, bottom - 4),
				Vector2(dx + 1.5, bottom + l), Vector2(dx - 1.5, bottom + l)]), INK)
			b.draw_circle(Vector2(dx, bottom + l), 3.0, INK)
			if cyc > 2.0:
				b.draw_circle(Vector2(dx, bottom + l + (cyc - 2.0) * 160.0), 2.5, INK)
	b.flush(self)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _grow(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var g := Geometry2D.offset_polygon(poly, by)
	return g[0] if not g.is_empty() else poly
