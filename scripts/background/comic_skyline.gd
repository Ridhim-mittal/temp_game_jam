@tool
extends Node2D
## Infinite procedural comic skyline drawn in one-point perspective.
## Every building is a box: a flat front face plus the side wall that faces
## the vanishing point, so as the camera moves the side walls swing around
## like a real 3D street (buildings left of centre show their right wall,
## buildings right of centre show their left wall).
##
## Put this inside a ComicParallax and give it the comic_halftone material:
## side walls get halftone shading through vertex alpha (see ComicView).
## Coordinates are "screen space at the reference camera" (see ComicParallax).

const ComicView = preload("res://scripts/background/comic_view.gd")
const MAX_BUILDINGS := 160

@export var seed := 1
## Buildings are placed one per slot, so generation is O(visible).
@export var slot_width := 150.0
## Building width as a fraction of the slot (> 1 overlaps neighbours).
@export var width_range := Vector2(0.7, 1.05)
@export var height_range := Vector2(140.0, 320.0)
## Where the buildings meet the street (below the horizon).
@export var street_y := 440.0
## Box depth D / (z + D). Bigger = chunkier side walls. Near layers > far.
@export var depth_range := Vector2(0.08, 0.15)
@export var palette := PackedColorArray([Color(0.88, 0.33, 0.6), Color(0.55, 0.3, 0.72), Color(0.3, 0.4, 0.85)])
@export var ink := Color(0.1, 0.05, 0.2)
@export var outline_width := 3.0
@export var street_color := Color(0.14, 0.08, 0.26)
@export_group("Atmosphere")
## Aerial perspective: 0 = full colour, 1 = melted into the haze.
@export_range(0.0, 1.0) var haze := 0.0
@export var haze_color := Color(0.62, 0.9, 0.93)
## Halftone strength on the side walls (top, bottom).
@export var side_shade := Vector2(0.45, 1.0)
@export_group("Windows")
## Set x to 0 to disable windows (far layers).
@export var window_size := Vector2(8.0, 12.0)
@export var window_gap := Vector2(7.0, 9.0)
@export_range(0.0, 1.0) var lit_chance := 0.3
@export var lit_color := Color(1.0, 0.95, 0.6)
@export var side_windows := true
@export_group("Roofs")
@export_range(0.0, 1.0) var detail_chance := 0.55

var _cache := {}
var _last_xf := Transform2D()


func _process(_delta: float) -> void:
	var xf := get_global_transform_with_canvas()
	if Engine.is_editor_hint() or xf != _last_xf:
		_last_xf = xf
		queue_redraw()


func _draw() -> void:
	if palette.is_empty() or slot_width < 4.0:
		return
	if Engine.is_editor_hint() or _cache.size() > 1024:
		_cache.clear()
	var view := ComicView.local_view(self)
	var rect: Rect2 = view.rect
	var vp: Vector2 = view.vp
	var margin := slot_width * 2.0 + rect.size.x * depth_range.y
	var i0 := floori((rect.position.x - margin) / slot_width)
	var i1 := mini(ceili((rect.end.x + margin) / slot_width), i0 + MAX_BUILDINGS)

	# Street / ground plane receding toward the horizon, behind everything.
	var bottom := maxf(rect.end.y, street_y) + 8.0
	var street_top := ComicView.recede(Vector2(0, street_y), vp, depth_range.y).y
	if bottom > street_top:
		draw_rect(Rect2(rect.position.x - 8.0, street_top, rect.size.x + 16.0, bottom - street_top), _hz(street_color))

	# Painter's order: buildings farthest from the centre line first, so the
	# ones nearer the centre cover the side walls that recede behind them.
	var list: Array = []
	for i in range(i0, i1):
		list.append(_building(i))
	list.sort_custom(func(a, b): return absf(a.cx - vp.x) > absf(b.cx - vp.x))
	for b in list:
		_draw_building(b, vp)


# ------------------------------------------------------------------ data

func _building(i: int) -> Dictionary:
	if _cache.has(i):
		return _cache[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed, i, 7919))
	var w := slot_width * rng.randf_range(width_range.x, width_range.y)
	var x := i * slot_width + (slot_width - w) * rng.randf()
	var b := {
		"x": x,
		"w": w,
		"cx": x + w * 0.5,
		"h": rng.randf_range(height_range.x, height_range.y),
		"depth": rng.randf_range(depth_range.x, depth_range.y),
		"color": palette[rng.randi() % palette.size()],
		"windows": rng.randi() % 3,  # 0 grid, 1 vertical strips, 2 bands
		"roof": rng.randi() % 4 if rng.randf() < detail_chance else -1,
		"seed": rng.randi(),
	}
	_cache[i] = b
	return b


# --------------------------------------------------------------- drawing

func _draw_building(b: Dictionary, vp: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = b.seed
	var col: Color = b.color
	var front := Rect2(b.x, street_y - b.h, b.w, b.h)
	_draw_box(front, b.depth, col, vp, b.windows, rng)
	match b.roof:
		0:  # setback tower
			var tw: float = b.w * rng.randf_range(0.4, 0.65)
			var th: float = b.h * rng.randf_range(0.12, 0.28)
			var tx: float = b.x + (b.w - tw) * rng.randf()
			_draw_box(Rect2(tx, front.position.y - th, tw, th), b.depth, col.darkened(0.08), vp, -1, rng)
		1:  # antenna
			var ax: float = b.x + b.w * rng.randf_range(0.25, 0.75)
			var top := front.position.y - rng.randf_range(28.0, 70.0)
			draw_line(Vector2(ax, front.position.y), Vector2(ax, top), _hz(ink), maxf(outline_width * 0.7, 1.0))
			draw_line(Vector2(ax - 6, top + 12), Vector2(ax + 6, top + 12), _hz(ink), maxf(outline_width * 0.5, 1.0))
			draw_circle(Vector2(ax, top), maxf(outline_width, 2.0), _hz(Color(1.0, 0.35, 0.35)))
		2:  # water tower
			_draw_water_tower(Vector2(b.x + b.w * rng.randf_range(0.25, 0.75), front.position.y), b.w, vp, b.depth)
		3:  # art-deco spire
			var sw: float = b.w * rng.randf_range(0.3, 0.55)
			var sx: float = b.cx - sw * 0.5
			var sh := rng.randf_range(30.0, 80.0)
			var tri := PackedVector2Array([
				Vector2(sx, front.position.y), Vector2(sx + sw * 0.5, front.position.y - sh),
				Vector2(sx + sw, front.position.y)])
			draw_colored_polygon(tri, _hz(col.lightened(0.12)))
			tri.append(tri[0])
			draw_polyline(tri, _hz(ink), outline_width)


## Front rectangle + the one side wall visible from the centre line.
func _draw_box(front: Rect2, depth: float, col: Color, vp: Vector2, window_style: int, rng: RandomNumberGenerator) -> void:
	var ink_c := _hz(ink)
	var side_x := NAN
	if front.end.x < vp.x:
		side_x = front.end.x
	elif front.position.x > vp.x:
		side_x = front.position.x
	if not is_nan(side_x) and absf(side_x - vp.x) * depth > 1.0:
		var ft := Vector2(side_x, front.position.y)
		var fb := Vector2(side_x, front.end.y)
		var bt := ComicView.recede(ft, vp, depth)
		var bb := ComicView.recede(fb, vp, depth)
		var sc := _hz(col.darkened(0.38))
		var top_c := ComicView.halftone(sc, side_shade.x)
		var bot_c := ComicView.halftone(sc, side_shade.y)
		draw_polygon(PackedVector2Array([ft, bt, bb, fb]), PackedColorArray([top_c, top_c, bot_c, bot_c]))
		if side_windows and window_style >= 0 and window_size.x > 0.0 and absf(bt.x - ft.x) > 14.0:
			_draw_side_windows(ft, fb, bt, bb, front, sc, rng)
		draw_polyline(PackedVector2Array([ft, bt, bb]), ink_c, outline_width * 0.75)

	draw_rect(front, _hz(col))
	# sky-reflection rim along the roof line
	draw_rect(Rect2(front.position, Vector2(front.size.x, minf(4.0, front.size.y))), _hz(col.lightened(0.25)))
	if window_style >= 0 and window_size.x > 0.0:
		_draw_front_windows(front, col, window_style, rng)
	draw_rect(front, ink_c, false, outline_width)


func _draw_front_windows(front: Rect2, col: Color, style: int, rng: RandomNumberGenerator) -> void:
	var cell := window_size + window_gap
	var cols := int((front.size.x - window_gap.x) / cell.x)
	var rows := int((front.size.y - window_gap.y * 2.0) / cell.y)
	if cols <= 0 or rows <= 0:
		return
	var x0 := front.position.x + (front.size.x - (cols * cell.x - window_gap.x)) * 0.5
	var y0 := front.position.y + window_gap.y * 1.5
	var dark := _hz(col.darkened(0.3))
	var lit := _hz(lit_color)
	match style:
		1:  # vertical strips
			for c in cols:
				var h := rows * cell.y - window_gap.y
				draw_rect(Rect2(x0 + c * cell.x, y0, window_size.x, h), lit if rng.randf() < lit_chance * 0.6 else dark)
		2:  # horizontal bands
			var w := cols * cell.x - window_gap.x
			for r in rows:
				draw_rect(Rect2(x0, y0 + r * cell.y, w, window_size.y * 0.6), lit if rng.randf() < lit_chance * 0.6 else dark)
		_:  # grid
			for r in rows:
				for c in cols:
					var on := rng.randf() < lit_chance
					draw_rect(Rect2(x0 + c * cell.x, y0 + r * cell.y, window_size.x, window_size.y), lit if on else dark)


## Windows mapped bilinearly onto the receding side wall, so they foreshorten.
func _draw_side_windows(ft: Vector2, fb: Vector2, bt: Vector2, bb: Vector2, front: Rect2, sc: Color, rng: RandomNumberGenerator) -> void:
	var cell_y := window_size.y + window_gap.y
	var rows := int((front.size.y - window_gap.y * 2.0) / cell_y)
	var cols := clampi(int(absf(bt.x - ft.x) / (window_size.x * 2.5)), 1, 3)
	var dark := sc.darkened(0.25)
	var lit := _hz(lit_color.darkened(0.2))
	for r in rows:
		var v0 := (window_gap.y * 1.5 + r * cell_y) / front.size.y
		var v1 := v0 + window_size.y / front.size.y
		for c in cols:
			var u0 := (c + 0.25) / cols
			var u1 := (c + 0.75) / cols
			var quad := PackedVector2Array([
				_bilerp(ft, fb, bt, bb, u0, v0), _bilerp(ft, fb, bt, bb, u1, v0),
				_bilerp(ft, fb, bt, bb, u1, v1), _bilerp(ft, fb, bt, bb, u0, v1)])
			draw_colored_polygon(quad, lit if rng.randf() < lit_chance else dark)


func _draw_water_tower(base: Vector2, bw: float, vp: Vector2, depth: float) -> void:
	var r := clampf(bw * 0.12, 6.0, 16.0)
	var leg_h := r * 1.2
	var tank := Rect2(base.x - r, base.y - leg_h - r * 1.8, r * 2.0, r * 1.8)
	var ink_c := _hz(ink)
	var lw := maxf(outline_width * 0.6, 1.0)
	draw_line(Vector2(tank.position.x + 2, tank.end.y), Vector2(tank.position.x, base.y), ink_c, lw)
	draw_line(Vector2(tank.end.x - 2, tank.end.y), Vector2(tank.end.x, base.y), ink_c, lw)
	var wood := Color(0.62, 0.38, 0.3)
	_draw_box(tank, depth * 0.5, wood, vp, -1, null)
	var roof := PackedVector2Array([
		Vector2(tank.position.x - 3, tank.position.y), Vector2(base.x, tank.position.y - r),
		Vector2(tank.end.x + 3, tank.position.y)])
	draw_colored_polygon(roof, _hz(wood.darkened(0.3)))
	roof.append(roof[0])
	draw_polyline(roof, ink_c, lw)


func _bilerp(ft: Vector2, fb: Vector2, bt: Vector2, bb: Vector2, u: float, v: float) -> Vector2:
	return ft.lerp(fb, v).lerp(bt.lerp(bb, v), u)


func _hz(c: Color) -> Color:
	var h := c.lerp(haze_color, haze)
	h.a = 1.0
	return h
