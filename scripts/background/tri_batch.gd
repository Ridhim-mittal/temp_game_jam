extends RefCounted
## Collects flat-coloured shapes as one triangle list and submits it with a
## single RenderingServer call: one draw call for a whole layer instead of
## one per rectangle/line/circle. Vertex colours are kept, so the halftone
## alpha encoding (ComicView.halftone) still works.
##
##   var b := TriBatch.new()
##   b.rect(r, col); b.line(a, b, col, 3.0); ...
##   b.flush(self)   # inside _draw()

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


func _tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var i := points.size()
	points.append(a)
	points.append(b)
	points.append(c)
	colors.append(ca)
	colors.append(cb)
	colors.append(cc)
	indices.append(i)
	indices.append(i + 1)
	indices.append(i + 2)


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_tri(a, b, c, col, col, col)
	_tri(a, c, d, col, col, col)


func quad_colors(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(a, b, c, ca, cb, cc)
	_tri(a, c, d, ca, cc, cd)


func rect(r: Rect2, col: Color) -> void:
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


func rect_outline(r: Rect2, col: Color, w: float) -> void:
	var h := w * 0.5
	rect(Rect2(r.position - Vector2(h, h), Vector2(r.size.x + w, w)), col)
	rect(Rect2(Vector2(r.position.x - h, r.end.y - h), Vector2(r.size.x + w, w)), col)
	rect(Rect2(r.position - Vector2(h, h), Vector2(w, r.size.y + w)), col)
	rect(Rect2(Vector2(r.end.x - h, r.position.y - h), Vector2(w, r.size.y + w)), col)


func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := Vector2(-d.y, d.x).normalized() * w * 0.5
	quad(a + n, b + n, b - n, a - n, col)


func polyline(pts: PackedVector2Array, col: Color, w: float) -> void:
	for i in pts.size() - 1:
		line(pts[i], pts[i + 1], col, w)
	if w > 2.0:  # round-ish joints so thick outlines have no notches
		for i in range(1, pts.size() - 1):
			circle(pts[i], w * 0.5, col, 6)


## Convex polygon (or any polygon that is a fan from its first vertex).
func convex(pts: PackedVector2Array, col: Color) -> void:
	for i in range(1, pts.size() - 1):
		_tri(pts[0], pts[i], pts[i + 1], col, col, col)


func convex_colors(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	for i in range(1, pts.size() - 1):
		_tri(pts[0], pts[i], pts[i + 1], cols[0], cols[i], cols[i + 1])


## Star-shaped polygon around `center` (stars, splats).
func fan(center: Vector2, pts: PackedVector2Array, col: Color) -> void:
	for i in pts.size():
		_tri(center, pts[i], pts[(i + 1) % pts.size()], col, col, col)


## segments 0 = automatic (more for bigger circles, so halos stay round).
func circle(c: Vector2, r: float, col: Color, segments := 0) -> void:
	if segments <= 0:
		segments = clampi(int(r * 0.5), 10, 48)
	var prev := c + Vector2(r, 0)
	for i in range(1, segments + 1):
		var p := c + Vector2.from_angle(TAU * i / segments) * r
		_tri(c, prev, p, col, col, col)
		prev = p


func flush(item: CanvasItem) -> void:
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), indices, points, colors)
	points = PackedVector2Array()
	colors = PackedColorArray()
	indices = PackedInt32Array()
