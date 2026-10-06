@tool
extends StaticBody2D
## The City's solid ground, rooftops and walls: the top of a futuristic
## building. Dark indigo metal fading to navy, chamfered top corners, a slim
## neon edge along the walking surface (with a soft glow above it), a metal
## cap band with clean panel seams and small indicator lights, and on tall
## pieces a facade of faint panels and lit window slits. Ink outline, so it
## sits in the comic. One draw call (ink_batch.gd). Collision = `size`.
## Wide pieces (roofs, the street) carry rooftop clutter behind the walkway
## (`props`): AC units with turning fans, steaming vents, antennas with a
## blinking light, dishes, a water tank, a flickering neon sign, railings,
## crates and the odd pigeon. Placed by hash, animated at 12 fps on screen.

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const INK := Color(0.05, 0.03, 0.1)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
## Rooftop props are drawn this much bigger than their numbers (about Vesper's scale).
const PROP_SCALE := 1.4
const SIGNS := ["NOODLES", "24/7", "INK", "OPEN", "HOTEL", "COMICS", "BAR", "ARCADE"]

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
## Rooftop clutter behind the walkway (only on pieces wide enough to be a roof).
@export var props := true

var _glow: Node2D
var _props: Node2D
var _prop_t := 0.0
var _prop_frame := -1


func _ready() -> void:
	collision_layer = 1
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	if props and size.x >= 220.0 and size.y <= size.x * 1.2:
		_props = Node2D.new()
		_props.z_index = -1  # behind the walkway and the player; feet hidden behind the cap
		_props.draw.connect(_draw_props)
		add_child(_props)
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)


func _process(delta: float) -> void:
	if _props == null:
		return
	_prop_t += delta
	var f := int(_prop_t * 12.0)
	if f == _prop_frame:
		return
	_prop_frame = f
	if Engine.is_editor_hint():
		_props.queue_redraw()
		return
	var on := get_global_transform_with_canvas() * Rect2(-size * 0.5 - Vector2(0, 110), size + Vector2(0, 110))
	if get_viewport_rect().grow(80.0).intersects(on):
		_props.queue_redraw()


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


# ---------------------------------------------------------------- rooftop props

func _draw_props() -> void:
	var r := Rect2(-size * 0.5, size)
	var y := r.position.y + 3.0
	var t := float(_prop_frame) / 12.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position))
	var b := InkBatch.new()
	var sil := top_color.darkened(0.3)
	var lit := Color(trim, 0.55)
	var texts: Array = []
	var x := r.position.x + rng.randf_range(50.0, 140.0)
	var sign_done := false
	var tank_done := false
	while x < r.end.x - 60.0:
		var kind := rng.randi() % 9
		var ph := rng.randf() * 10.0
		var w := 30.0
		var ps := PROP_SCALE
		b.draw_set_transform(Vector2(x, y) * (1.0 - ps), 0.0, Vector2.ONE * ps)  # scale each prop about its foot
		match kind:
			0:  # AC unit, its fan turning
				w = 30.0
				_box(b, Rect2(x, y - 17, 30, 17), sil, lit)
				b.draw_circle(Vector2(x + 10, y - 8.5), 5.5, sil.darkened(0.4))
				for k in 3:
					var a := t * 9.0 + k * TAU / 3.0 + ph
					b.draw_line(Vector2(x + 10, y - 8.5), Vector2(x + 10, y - 8.5) + Vector2.from_angle(a) * 4.5, sil.lightened(0.25), 1.5)
				for k in 3:
					b.draw_line(Vector2(x + 18, y - 13 + k * 4), Vector2(x + 27, y - 13 + k * 4), Color(INK, 0.6), 1.0)
			1:  # vent pipes, steaming
				w = 22.0
				for k in 2:
					var px := x + k * 11.0
					var ph2 := 16.0 + k * 9.0
					_box(b, Rect2(px, y - ph2, 7, ph2), sil, lit)
					b.draw_rect(Rect2(px - 2, y - ph2 - 3, 11, 4), sil.lightened(0.1))
					for q in 3:
						var u := fmod(t * 0.6 + q / 3.0 + ph * 0.1 + k * 0.17, 1.0)
						b.draw_circle(Vector2(px + 3.5 + sin(u * 5.0 + ph) * 3.0, y - ph2 - 6 - u * 26.0), 3.0 + u * 5.0,
							Color(0.9, 0.92, 1.0, 0.16 * (1.0 - u)))
			2:  # antenna mast, a red light blinking on top
				w = 18.0
				var hgt := rng.randf_range(44.0, 78.0)
				b.draw_line(Vector2(x + 9, y), Vector2(x + 9, y - hgt), INK, 2.5)
				b.draw_line(Vector2(x + 9, y), Vector2(x + 9, y - hgt), sil.lightened(0.15), 1.2)
				for k in 2:
					var cy := y - hgt * (0.45 + 0.3 * k)
					b.draw_line(Vector2(x + 3, cy), Vector2(x + 15, cy), INK, 1.5)
				b.draw_line(Vector2(x + 9, y - hgt * 0.7), Vector2(x - 6, y), Color(INK, 0.5), 1.0)
				b.draw_line(Vector2(x + 9, y - hgt * 0.7), Vector2(x + 24, y), Color(INK, 0.5), 1.0)
				if fmod(t + ph, 1.6) < 0.3:
					b.draw_circle(Vector2(x + 9, y - hgt - 2), 6.0, Color(1.0, 0.2, 0.25, 0.3))
					b.draw_circle(Vector2(x + 9, y - hgt - 2), 2.4, Color(1.0, 0.35, 0.35))
				else:
					b.draw_circle(Vector2(x + 9, y - hgt - 2), 2.0, Color(0.45, 0.1, 0.12))
			3:  # satellite dish
				w = 26.0
				b.draw_line(Vector2(x + 12, y), Vector2(x + 12, y - 12), INK, 3.0)
				var dish := PackedVector2Array()
				for k in 9:
					var a := lerpf(-0.2, PI + 0.2, k / 8.0)
					dish.append(Vector2(x + 12, y - 18) + Vector2(cos(a) * 12.0, sin(a) * 5.0).rotated(-0.55))
				b.draw_colored_polygon(dish, sil.lightened(0.12))
				b.draw_polyline(dish, INK, 1.5)
				b.draw_line(Vector2(x + 12, y - 18), Vector2(x + 18, y - 28), INK, 1.5)
				b.draw_circle(Vector2(x + 18, y - 28), 1.8, Color(trim, 0.9))
			4:  # water tank on legs
				if tank_done:
					x += 10.0
					continue
				tank_done = true
				w = 34.0
				for k in 4:
					b.draw_line(Vector2(x + 4 + k * 8.5, y), Vector2(x + 6 + k * 7.0, y - 18), INK, 2.0)
				_box(b, Rect2(x + 2, y - 44, 30, 26), sil.lightened(0.05), lit)
				for k in 2:
					b.draw_line(Vector2(x + 2, y - 36 + k * 10), Vector2(x + 32, y - 36 + k * 10), Color(INK, 0.6), 1.2)
				var roof := PackedVector2Array([Vector2(x, y - 44), Vector2(x + 17, y - 56), Vector2(x + 34, y - 44)])
				b.draw_colored_polygon(roof, sil.darkened(0.15))
				roof.append(roof[0])
				b.draw_polyline(roof, INK, 1.5)
			5:  # a neon sign on legs, flickering
				if sign_done:
					x += 10.0
					continue
				sign_done = true
				var text: String = SIGNS[rng.randi() % SIGNS.size()]
				w = 18.0 + text.length() * 10.0
				var col := accent if rng.randf() < 0.5 else trim
				var on := fmod(t * 1.3 + ph, 7.0) > 0.35 and not (fmod(t * 1.3 + ph, 7.0) > 0.9 and fmod(t * 1.3 + ph, 7.0) < 1.05)
				for k in 2:
					b.draw_line(Vector2(x + 6 + k * (w - 12), y), Vector2(x + 6 + k * (w - 12), y - 22), INK, 2.5)
				var panel := Rect2(x, y - 46, w, 24)
				if on:
					b.draw_rect(panel.grow(6), Color(col, 0.16))
				b.draw_rect(panel, INK.lightened(0.05))
				b.draw_rect(panel.grow(-2), Color(col, 0.9 if on else 0.25), false, 1.6)
				var at := Vector2(x, y) + (Vector2(x + 9, y - 28.5) - Vector2(x, y)) * ps
				texts.append([at, text, Color(col.lightened(0.35), 1.0 if on else 0.3), int(16 * ps)])
			6:  # a stretch of railing
				w = rng.randf_range(48.0, 90.0)
				b.draw_line(Vector2(x, y - 12), Vector2(x + w, y - 12), INK, 2.5)
				b.draw_line(Vector2(x, y - 12), Vector2(x + w, y - 12), sil.lightened(0.2), 1.0)
				var px := x
				while px <= x + w:
					b.draw_line(Vector2(px, y), Vector2(px, y - 12), INK, 2.0)
					px += 14.0
			7:  # crates
				w = 34.0
				for k in 2 + rng.randi() % 2:
					var cs := 14.0 - k * 1.5
					var cr := Rect2(x + k * 9.0 + (0.0 if k < 2 else -6.0), y - cs - (0.0 if k < 2 else 13.0), cs, cs)
					_box(b, cr, Color(0.36, 0.26, 0.3), Color(1, 1, 1, 0.12))
					b.draw_line(cr.position, cr.end, Color(INK, 0.6), 1.0)
					b.draw_line(Vector2(cr.end.x, cr.position.y), Vector2(cr.position.x, cr.end.y), Color(INK, 0.6), 1.0)
			8:  # a pigeon, pecking now and then
				w = 12.0
				var peck := 3.0 if fmod(t + ph, 2.6) < 0.25 else 0.0
				b.draw_colored_polygon(_oval(Vector2(x + 6, y - 4), 5.0, 3.5), Color(0.55, 0.55, 0.65))
				b.draw_circle(Vector2(x + 10, y - 8 + peck), 2.4, Color(0.6, 0.6, 0.7))
				b.draw_line(Vector2(x + 12, y - 8 + peck), Vector2(x + 14, y - 7.5 + peck), Color(1.0, 0.7, 0.3), 1.2)
				b.draw_line(Vector2(x + 1, y - 4), Vector2(x - 2, y - 6), Color(0.4, 0.4, 0.5), 1.5)
		x += w * ps + rng.randf_range(70.0, 200.0)
	b.draw_set_transform(Vector2.ZERO)
	b.flush(_props)
	for tx in texts:
		_props.draw_string(FONT, tx[0], tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tx[3], tx[2])


func _box(b: InkBatch, rect: Rect2, fill: Color, edge: Color) -> void:
	b.draw_rect(rect, fill)
	b.draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), edge, 1.2)
	b.draw_rect(rect, INK, false, 1.5)


func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		out.append(c + Vector2(cos(TAU * i / 10.0) * rx, sin(TAU * i / 10.0) * ry))
	return out
