@tool
extends StaticBody2D
## The City's solid ground, rooftops and walls: the top of a futuristic
## building. Dark indigo metal fading to navy, chamfered top corners, a slim
## neon edge along the walking surface (with a soft glow above it), a metal
## cap band with clean panel seams and small indicator lights, and on tall
## pieces a facade of faint panels and lit window slits. Ink outline, so it
## sits in the comic. One draw call (ink_batch.gd). Collision = `size`.

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const INK := Color(0.05, 0.03, 0.1)

@export var size := Vector2(128, 32):
	set(value):
		size = value
		queue_redraw()
		if _glow:
			_glow.queue_redraw()
## The neon edge along the top.
@export var trim := Color(0.38, 0.95, 1.0)
## The second indicator colour.
@export var accent := Color(1.0, 0.42, 0.75)
@export var top_color := Color(0.22, 0.2, 0.42)
@export var bottom_color := Color(0.07, 0.06, 0.15)

var _glow: Node2D


func _ready() -> void:
	collision_layer = 1
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)


func _chamfer() -> float:
	return minf(8.0, minf(size.x, size.y) * 0.25)


func _draw() -> void:
	var b := InkBatch.new()
	var r := Rect2(-size * 0.5, size)
	var ch := _chamfer()
	var body := PackedVector2Array([r.position + Vector2(ch, 0), Vector2(r.end.x - ch, r.position.y), Vector2(r.end.x, r.position.y + ch),
		r.end, Vector2(r.position.x, r.end.y), r.position + Vector2(0, ch)])
	# metal body, lighter at the top
	var fade := clampf(size.y / 260.0, 0.0, 1.0)  # short pieces stay lighter all the way down
	var low := top_color.lerp(bottom_color, fade)
	var cols := PackedColorArray()
	for p in body:
		cols.append(top_color.lerp(low, clampf((p.y - r.position.y) / maxf(size.y, 1.0), 0.0, 1.0)))
	b.draw_polygon(body, cols)
	# cap band under the walking surface, with panel seams and indicator lights
	var cap := minf(14.0, size.y * 0.45)
	b.draw_rect(Rect2(r.position.x + 1.5, r.position.y + 3.0, size.x - 3.0, cap - 3.0), top_color.lightened(0.12))
	b.draw_line(Vector2(r.position.x + 2, r.position.y + cap), Vector2(r.end.x - 2, r.position.y + cap), Color(INK, 0.55), 1.5)
	var sx := r.position.x + 96.0
	while sx < r.end.x - 20.0:
		b.draw_line(Vector2(sx, r.position.y + 3), Vector2(sx, r.position.y + cap), Color(INK, 0.6), 1.5)
		sx += 96.0
	var lx := r.position.x + 30.0
	var k := 0
	while lx < r.end.x - 14.0 and cap > 8.0:
		var lc := trim if k % 3 != 2 else accent
		b.draw_rect(Rect2(lx - 3, r.position.y + cap * 0.5, 6, 2.5), Color(lc, 0.9))
		lx += 48.0
		k += 1
	# facade: faint panel lines and, on tall pieces, rows of lit window slits
	if size.y > 60.0:
		var px := r.position.x + 64.0
		while px < r.end.x - 8.0:
			b.draw_line(Vector2(px, r.position.y + cap + 2), Vector2(px, r.end.y), Color(1, 1, 1, 0.05), 1.5)
			px += 64.0
		var y := r.position.y + cap + 34.0
		var row := 0
		while y < r.end.y - 20.0:
			var x := r.position.x + 18.0
			while x < r.end.x - 40.0:
				var h := absi(hash(Vector3i(int(position.x), row, int(x)))) % 100
				var w := 22.0 + float(h % 3) * 12.0
				if h < 62:
					var lit := trim if h % 5 != 0 else accent
					b.draw_rect(Rect2(x, y, w, 3.0), Color(lit, 0.22 + 0.12 * float(h % 2)))
				x += w + 14.0
			y += 46.0
			row += 1
	# ink outline, then the neon edge on the walking surface
	var outline := body.duplicate()
	outline.append(body[0])
	b.draw_polyline(outline, INK, 3.0)
	var e0 := Vector2(r.position.x + ch, r.position.y + 1.0)
	var e1 := Vector2(r.end.x - ch, r.position.y + 1.0)
	b.draw_line(e0, e1, trim, 3.5)
	b.draw_line(e0 + Vector2(2, -0.5), e1 + Vector2(-2, -0.5), Color(1, 1, 1, 0.85), 1.2)
	b.flush(self)


func _draw_glow() -> void:
	# a soft neon haze over the top edge
	var r := Rect2(-size * 0.5, size)
	var ch := _chamfer()
	var x0 := r.position.x + ch
	var x1 := r.end.x - ch
	var y := r.position.y
	_glow.draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y - 16), Vector2(x0, y - 16)]),
		PackedColorArray([Color(trim, 0.28), Color(trim, 0.28), Color(trim, 0.0), Color(trim, 0.0)]))
	_glow.draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + 8), Vector2(x0, y + 8)]),
		PackedColorArray([Color(trim, 0.2), Color(trim, 0.2), Color(trim, 0.0), Color(trim, 0.0)]))
