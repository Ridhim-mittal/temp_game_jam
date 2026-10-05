extends RefCounted
## Shared look for the "depth" scenery: one colour family per zone, far things
## pale and near things dark, a near-black playfield whose edges catch light.
## Used by the backdrop (scripts/depth/depth_backdrop.gd), the terrain trims
## (depth_trim.gd) and the ledges (depth_ledge.gd).

enum { CAVERN, ARCHIVE, WORKS }

const PALETTES := [
	{  # the Dripping Margins: teal on near-black
		"top": Color(0.01, 0.03, 0.08), "bottom": Color(0.04, 0.17, 0.27), "fog": Color(0.25, 0.62, 0.68),
		"dark": Color(0.015, 0.03, 0.06), "glow": Color(0.45, 0.95, 0.9), "accent": Color(0.85, 1.0, 0.75)},
	{  # the Writer's Archive: deep indigo
		"top": Color(0.01, 0.015, 0.07), "bottom": Color(0.06, 0.1, 0.3), "fog": Color(0.38, 0.5, 0.9),
		"dark": Color(0.012, 0.016, 0.05), "glow": Color(0.75, 0.85, 1.0), "accent": Color(1.0, 0.9, 0.65)},
	{  # the Pencil Works: violet and lilac
		"top": Color(0.05, 0.02, 0.1), "bottom": Color(0.25, 0.15, 0.42), "fog": Color(0.66, 0.5, 0.95),
		"dark": Color(0.03, 0.015, 0.06), "glow": Color(0.9, 0.8, 1.0), "accent": Color(1.0, 0.7, 0.95)},
]


## Colour of something at depth k: 0 = lost in the fog, 1 = the playfield's dark.
static func depth(theme: int, k: float) -> Color:
	var pal: Dictionary = PALETTES[theme]
	return (pal.fog as Color).darkened(0.35).lerp(pal.dark, k)


static func ell(c: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		p.append(c + Vector2(cos(TAU * i / n) * rx, sin(TAU * i / n) * ry))
	return p


static func arc_pts(c: Vector2, rx: float, ry: float, a0: float, a1: float, n := 12) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, i / float(n))
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func spiral(ci: CanvasItem, c: Vector2, r: float, turns: float, col: Color, w: float, flip := 1.0) -> void:
	var p := PackedVector2Array()
	for i in 28:
		var u := i / 27.0
		var a := u * turns * TAU
		p.append(c + Vector2(cos(a) * flip, sin(a)) * r * (1.0 - u * 0.85))
	ci.draw_polyline(p, col, w, true)


## Lit edge along the top of a floor from x0 to x1 at height y.
static func floor_trim(ci: CanvasItem, x0: float, x1: float, y: float, theme: int, rng: RandomNumberGenerator) -> void:
	var pal: Dictionary = PALETTES[theme]
	var w := x1 - x0
	match theme:
		CAVERN:  # pebbled lip, glowing moss, blades of grass
			var x := x0
			while x < x1:
				var r := rng.randf_range(6.0, 11.0)
				ci.draw_colored_polygon(ell(Vector2(x, y + 7.0), r, r * 0.8, 10), depth(theme, 0.72))
				ci.draw_arc(Vector2(x, y + 7.0), r * 0.8, PI + 0.5, TAU - 0.9, 5, depth(theme, 0.5), 1.5)
				x += r * 1.5
			for i in int(w / 16.0):
				var bx := x0 + rng.randf() * w
				var h := rng.randf_range(8.0, 26.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 3, y + 2), Vector2(bx + rng.randf_range(-8, 8), y - h),
					Vector2(bx + 3, y + 2)]), depth(theme, 0.84))
			for i in int(w / 24.0):
				ci.draw_circle(Vector2(x0 + rng.randf() * w, y + rng.randf_range(-2, 4)), 1.6, Color(pal.accent, 0.85))
		ARCHIVE:  # rounded nosing, a carved wave, pierced roundels
			ci.draw_rect(Rect2(x0, y, w, 12), depth(theme, 0.62))
			ci.draw_line(Vector2(x0, y + 1), Vector2(x1, y + 1), depth(theme, 0.3), 2.0)
			var wave := PackedVector2Array()
			for i in int(w / 5.0) + 1:
				wave.append(Vector2(x0 + i * 5.0, y + 21.0 + sin((x0 + i * 5.0) * 0.085) * 4.5))
			if wave.size() > 1:
				ci.draw_polyline(wave, depth(theme, 0.5), 2.0, true)
			var rx := x0 + 30.0
			while rx < x1 - 20.0:
				ci.draw_arc(Vector2(rx, y + 35.0), 7.0, 0, TAU, 10, depth(theme, 0.58), 1.5)
				rx += 60.0
		WORKS:  # planks lashed with twine over a bed of pebbles
			ci.draw_rect(Rect2(x0, y, w, 14), Color(0.2, 0.12, 0.16))
			ci.draw_line(Vector2(x0, y + 1), Vector2(x1, y + 1), Color(0.5, 0.36, 0.5), 2.0)
			var px := x0 + 30.0
			while px < x1:
				ci.draw_line(Vector2(px, y), Vector2(px, y + 14), pal.dark, 2.0)
				ci.draw_line(Vector2(px + 12, y - 2), Vector2(px + 12, y + 16), Color(0.75, 0.65, 0.5), 2.0)
				px += 70.0
			var qx := x0
			while qx < x1:
				var r2 := rng.randf_range(8.0, 13.0)
				ci.draw_colored_polygon(ell(Vector2(qx, y + 26.0), r2, r2 * 0.8, 10), depth(theme, 0.82))
				ci.draw_arc(Vector2(qx, y + 26.0), r2 * 0.8, PI + 0.5, TAU - 0.9, 5, depth(theme, 0.62), 1.5)
				qx += r2 * 1.5
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(depth(theme, 0.5), 0.9), 1.5)


## Things hanging from a ceiling from x0 to x1 at height y.
static func ceiling_trim(ci: CanvasItem, x0: float, x1: float, y: float, theme: int, rng: RandomNumberGenerator) -> void:
	var pal: Dictionary = PALETTES[theme]
	var w := x1 - x0
	var dark: Color = pal.dark
	match theme:
		CAVERN:  # ink drips of every length
			for i in int(w / 22.0) + 1:
				var x := x0 + rng.randf() * w
				var l := 8.0 + pow(rng.randf(), 2.4) * 150.0
				var hw := rng.randf_range(4.0, 12.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - hw, y - 1), Vector2(x + hw, y - 1),
					Vector2(x + rng.randf_range(-3, 3), y + l)]), dark)
		ARCHIVE:  # a scalloped cornice with the odd sagging chain
			var sx := x0
			while sx < x1 - 1.0:
				var sw := minf(34.0, x1 - sx)
				ci.draw_colored_polygon(arc_pts(Vector2(sx + sw * 0.5, y - 1), sw * 0.5, 12, 0, PI, 8), dark)
				ci.draw_arc(Vector2(sx + sw * 0.5, y - 1), sw * 0.5, 0.2, PI - 0.2, 8, depth(theme, 0.62), 1.5)
				sx += 34.0
			var cx := x0 + rng.randf_range(60, 200)
			while cx < x1 - 180.0:
				var span := rng.randf_range(120, 220)
				var sag := rng.randf_range(30, 70)
				var pts := PackedVector2Array()
				for i in 13:
					pts.append(Vector2(cx + span * i / 12.0, y + sin(i / 12.0 * PI) * sag))
				ci.draw_polyline(pts, dark, 2.5, true)
				cx += span + rng.randf_range(160, 420)
		WORKS:  # a beam with frayed twine ends
			ci.draw_rect(Rect2(x0, y - 2, w, 12), Color(0.14, 0.08, 0.12))
			ci.draw_line(Vector2(x0, y + 10), Vector2(x1, y + 10), Color(0.42, 0.3, 0.42), 1.5)
			var tx := x0 + rng.randf_range(20, 80)
			while tx < x1 - 10.0:
				var l2 := rng.randf_range(14, 60)
				ci.draw_line(Vector2(tx, y + 10), Vector2(tx + rng.randf_range(-4, 4), y + 10 + l2), Color(0.6, 0.52, 0.42), 1.5)
				tx += rng.randf_range(60, 160)


## Faint lit edge down a wall at x from y0 to y1. facing: +1 = open air to the right.
static func wall_trim(ci: CanvasItem, x: float, y0: float, y1: float, facing: float, theme: int, rng: RandomNumberGenerator) -> void:
	ci.draw_line(Vector2(x, y0), Vector2(x, y1), Color(depth(theme, 0.62), 0.8), 1.5)
	var y := y0 + rng.randf_range(10, 60)
	while y < y1 - 10.0:
		match theme:
			CAVERN:
				var r := rng.randf_range(7.0, 16.0)
				ci.draw_colored_polygon(ell(Vector2(x - facing * r * 0.3, y), r, r * 0.9, 10), depth(theme, 0.86))
				ci.draw_arc(Vector2(x - facing * r * 0.3, y), r * 0.8, -1.2 if facing > 0 else PI - 1.2, 0.2 if facing > 0 else PI + 0.2, 5,
					depth(theme, 0.62), 1.5)
			ARCHIVE:
				ci.draw_arc(Vector2(x, y), 9.0, -PI * 0.5 if facing > 0 else PI * 0.5, PI * 0.5 if facing > 0 else PI * 1.5, 8, depth(theme, 0.6), 1.5)
			WORKS:
				ci.draw_line(Vector2(x - facing * 12.0, y), Vector2(x + facing * 4.0, y), Color(0.6, 0.52, 0.42), 2.0)
		y += rng.randf_range(50, 130)
