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

## Unit circles and their fan indices by segment count (draw_circle).
static var _rings := {}
static var _fans := {}


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
		_pts.append_array(_xf * c)
		_cols.append_array(PackedColorArray([color, color, color, color]))
		_idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	else:
		c.append(rect.position)
		_stroke(c, color, width, antialiased)


func draw_circle(center: Vector2, radius: float, color: Color, filled := true, width := -1.0, antialiased := false) -> void:
	var n := clampi(int(radius * 0.6) + 10, 10, 48)
	if not _rings.has(n):
		var unit := PackedVector2Array()
		var fan := PackedInt32Array()
		for i in n:
			unit.append(Vector2.from_angle(TAU * i / n))
			fan.append_array(PackedInt32Array([0, 1 + i, 1 + (i + 1) % n]))
		_rings[n] = unit
		_fans[n] = fan
	# the ring placed and transformed in two native multiplies
	var ring: PackedVector2Array = Transform2D(0.0, Vector2(radius, radius), 0.0, center) * (_rings[n] as PackedVector2Array)
	if filled:
		var b := _pts.size()
		_pts.append(_xf * center)
		_pts.append_array(_xf * ring)
		var cols := PackedColorArray()
		cols.resize(n + 1)
		cols.fill(color)
		_cols.append_array(cols)
		_offset_indices(_fans[n], b)
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
	_pts.append_array(_xf * poly)
	if colors.size() == poly.size():
		_cols.append_array(colors)
	else:
		var cols := PackedColorArray()
		cols.resize(poly.size())
		cols.fill(colors[0])
		_cols.append_array(cols)
	if tri.is_empty():  # self-touching outline: a fan is close enough
		for i in range(1, poly.size() - 1):
			tri.append_array(PackedInt32Array([0, i, i + 1]))
	_offset_indices(tri, b)


## Appends `local` (indices into the shape just added) shifted by `b`.
func _offset_indices(local: PackedInt32Array, b: int) -> void:
	var start := _idx.size()
	var n := local.size()
	_idx.resize(start + n)
	for i in n:
		_idx[start + i] = local[i] + b


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
	var feather := antialiased
	var per := 4 if feather else 2
	var verts := PackedVector2Array()
	verts.resize(n * per)
	for i in n:
		var d0 := (p[i] - p[i - 1]).normalized() if i > 0 else (p[1] - p[0]).normalized()
		var d1 := (p[i + 1] - p[i]).normalized() if i < n - 1 else d0
		var nrm := (d0 + d1).orthogonal()
		if nrm.length_squared() < 0.000001:
			nrm = d0.orthogonal()
		nrm = nrm.normalized()
		var m := hw / maxf(nrm.dot(d0.orthogonal()), 1.0 / MITER_LIMIT)
		var k := i * per
		verts[k] = p[i] + nrm * m
		verts[k + 1] = p[i] - nrm * m
		if feather:
			var mf := m * (hw + 1.0) / hw
			verts[k + 2] = p[i] + nrm * mf
			verts[k + 3] = p[i] - nrm * mf
	var b := _pts.size()
	_pts.append_array(_xf * verts)
	var cols := PackedColorArray()
	cols.resize(n * per)
	cols.fill(color)
	if feather:
		var clear := Color(color, 0.0)
		for i in n:
			cols[i * 4 + 2] = clear
			cols[i * 4 + 3] = clear
	_cols.append_array(cols)
	var start := _idx.size()
	var tris := 18 if feather else 6
	_idx.resize(start + (n - 1) * tris)
	var j := start
	for i in n - 1:
		var a := b + i * per
		var c := a + per
		_idx[j] = a  # core
		_idx[j + 1] = a + 1
		_idx[j + 2] = c + 1
		_idx[j + 3] = a
		_idx[j + 4] = c + 1
		_idx[j + 5] = c
		if feather:
			_idx[j + 6] = a + 2  # left feather
			_idx[j + 7] = a
			_idx[j + 8] = c
			_idx[j + 9] = a + 2
			_idx[j + 10] = c
			_idx[j + 11] = c + 2
			_idx[j + 12] = a + 1  # right feather
			_idx[j + 13] = a + 3
			_idx[j + 14] = c + 3
			_idx[j + 15] = a + 1
			_idx[j + 16] = c + 3
			_idx[j + 17] = c + 1
		j += tris
