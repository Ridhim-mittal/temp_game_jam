extends RefCounted
## Collects many small shapes and draws them as ONE triangle array (one draw
## call). In the Compatibility renderer every draw_colored_polygon,
## draw_polyline, draw_arc and draw_circle is its own draw call, and the
## depth scenery is made of thousands of them; this keeps the same look at a
## fraction of the cost. Same method names as CanvasItem, so drawing code can
## take either:
##
##   var b := InkBatch.new()
##   b.draw_colored_polygon(pts, col)   # ... draw_line, draw_arc, draw_rect ...
##   b.flush(self)                      # from inside _draw()
##
## draw_texture_rect only knows the depth backdrop's glow texture (a radial
## white fade, see depth_backdrop.gd) and draws it as a fan.

## The glow texture's gradient: alpha 1 at the centre, 0.35 at 35% out, 0 at the rim.
const GLOW_MID := 0.35
const GLOW_SEGMENTS := 20
## Miters longer than this many half-widths are cut (sharp turns).
const MITER_LIMIT := 3.0

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _xf := Transform2D.IDENTITY


func draw_set_transform(pos: Vector2, rot := 0.0, scale := Vector2.ONE) -> void:
	_xf = Transform2D(rot, scale, 0.0, pos)


func draw_set_transform_matrix(xf: Transform2D) -> void:
	_xf = xf


func is_empty() -> bool:
	return _idx.is_empty()


## Hand everything over as one draw call on `ci`'s canvas item, and start again.
func flush(ci: CanvasItem) -> void:
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _idx, _pts, _cols)
	_pts = PackedVector2Array()
	_cols = PackedColorArray()
	_idx = PackedInt32Array()
	_xf = Transform2D.IDENTITY


# ------------------------------------------------------------------ fills

func draw_colored_polygon(poly: PackedVector2Array, color: Color, _uvs := PackedVector2Array(), _texture: Texture2D = null) -> void:
	_fill(poly, PackedColorArray([color]))


func draw_polygon(poly: PackedVector2Array, colors: PackedColorArray, _uvs := PackedVector2Array(), _texture: Texture2D = null) -> void:
	_fill(poly, colors)


func draw_rect(rect: Rect2, color: Color, filled := true, width := -1.0, antialiased := false) -> void:
	var c := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	if filled:
		var b := _pts.size()
		for p in c:
			_add(p, color)
		_idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	else:
		c.append(rect.position)
		_stroke(c, color, width, antialiased)


func draw_circle(center: Vector2, radius: float, color: Color, filled := true, width := -1.0, antialiased := false) -> void:
	var n := clampi(int(radius * 0.6) + 10, 10, 48)
	var ring := PackedVector2Array()
	for i in n:
		ring.append(center + Vector2.from_angle(TAU * i / n) * radius)
	if filled:
		_fan(center, ring, color, color)
	else:
		ring.append(ring[0])
		_stroke(ring, color, width, antialiased)


# ---------------------------------------------------------------- strokes

func draw_line(from: Vector2, to: Vector2, color: Color, width := -1.0, antialiased := false) -> void:
	_stroke(PackedVector2Array([from, to]), color, width, antialiased)


func draw_polyline(points: PackedVector2Array, color: Color, width := -1.0, antialiased := false) -> void:
	_stroke(points, color, width, antialiased)


func draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color,
		width := -1.0, antialiased := false) -> void:
	var p := PackedVector2Array()
	for i in point_count:
		var a := lerpf(start_angle, end_angle, i / float(maxi(point_count - 1, 1)))
		p.append(center + Vector2.from_angle(a) * radius)
	_stroke(p, color, width, antialiased)


# ------------------------------------------------------------------- glow

## Only for the backdrop's radial glow texture: a soft fan, brightest in the middle.
func draw_texture_rect(_texture: Texture2D, rect: Rect2, _tile: bool, modulate := Color.WHITE, _transpose := false) -> void:
	var c := rect.get_center()
	var r := rect.size * 0.5
	var b := _pts.size()
	_add(c, modulate)
	for k in [GLOW_MID, 1.0]:
		var a: float = modulate.a * (GLOW_MID if k == GLOW_MID else 0.0)
		for i in GLOW_SEGMENTS:
			var d := Vector2.from_angle(TAU * i / GLOW_SEGMENTS)
			_add(c + d * r * k, Color(modulate, a))
	for i in GLOW_SEGMENTS:
		var j := (i + 1) % GLOW_SEGMENTS
		_idx.append_array([b, b + 1 + i, b + 1 + j])  # centre to the mid ring
		var m0 := b + 1 + i
		var m1 := b + 1 + j
		var o0 := m0 + GLOW_SEGMENTS
		var o1 := m1 + GLOW_SEGMENTS
		_idx.append_array([m0, o0, o1, m0, o1, m1])   # mid ring to the rim


# -------------------------------------------------------------- internals

func _add(p: Vector2, c: Color) -> void:
	_pts.append(_xf * p)
	_cols.append(c)


func _fill(poly: PackedVector2Array, colors: PackedColorArray) -> void:
	if poly.size() < 3 or colors.is_empty():
		return
	var tri := Geometry2D.triangulate_polygon(poly)
	var b := _pts.size()
	for i in poly.size():
		_add(poly[i], colors[i] if colors.size() == poly.size() else colors[0])
	if tri.is_empty():  # self-touching outline: a fan is close enough
		for i in range(1, poly.size() - 1):
			_idx.append_array([b, b + i, b + i + 1])
		return
	for i in tri:
		_idx.append(b + i)


func _fan(center: Vector2, ring: PackedVector2Array, inner: Color, outer: Color) -> void:
	var b := _pts.size()
	_add(center, inner)
	for p in ring:
		_add(p, outer)
	var n := ring.size()
	for i in n:
		_idx.append_array([b, b + 1 + i, b + 1 + (i + 1) % n])


## A thick line through `points` with mitred joins; antialiased adds a 1 px
## feather that fades to clear on both sides (like Godot's antialiased lines).
func _stroke(points: PackedVector2Array, color: Color, width: float, antialiased: bool) -> void:
	var p := PackedVector2Array()
	for q in points:  # drop repeated points: they have no direction
		if p.is_empty() or p[p.size() - 1].distance_squared_to(q) > 0.0001:
			p.append(q)
	var n := p.size()
	if n < 2:
		return
	var hw := maxf(width, 1.0) * 0.5
	var feather := 1.0 if antialiased else 0.0
	var clear := Color(color, 0.0)
	var b := _pts.size()
	for i in n:
		var d0 := (p[i] - p[i - 1]).normalized() if i > 0 else (p[1] - p[0]).normalized()
		var d1 := (p[i + 1] - p[i]).normalized() if i < n - 1 else d0
		var nrm := (d0 + d1).orthogonal()
		if nrm.length_squared() < 0.000001:
			nrm = d0.orthogonal()
		nrm = nrm.normalized()
		var m := hw / maxf(nrm.dot(d0.orthogonal()), 1.0 / MITER_LIMIT)
		_add(p[i] + nrm * m, color)
		_add(p[i] - nrm * m, color)
		if feather > 0.0:
			var mf := m * (hw + feather) / hw
			_add(p[i] + nrm * mf, clear)
			_add(p[i] - nrm * mf, clear)
	var per := 4 if feather > 0.0 else 2
	for i in n - 1:
		var a := b + i * per
		var c := a + per
		_idx.append_array([a, a + 1, c + 1, a, c + 1, c])          # core
		if feather > 0.0:
			_idx.append_array([a + 2, a, c, a + 2, c, c + 2])      # left feather
			_idx.append_array([a + 1, a + 3, c + 3, a + 1, c + 3, c + 1])  # right feather
