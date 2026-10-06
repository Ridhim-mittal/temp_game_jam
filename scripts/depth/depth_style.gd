extends RefCounted
## Shared look for the "depth" scenery: one colour family per zone, far things
## pale and near things dark, a near-black playfield whose edges catch light.
## Drawing helpers take a CanvasItem or an InkBatch (ink_batch.gd).
## Used by the backdrop (scripts/depth/depth_backdrop.gd), the terrain trims
## (depth_trim.gd) and the ledges (depth_ledge.gd).
## Story detail on the trims: torn pages of Shade's script nailed to the walls
## (scrawled lines, a word struck out in red), fallen pages on the floors, paper
## strips hanging from ceilings, and per zone glowing mushrooms (Cavern), candle
## stubs (Archive) or dropped pencil stubs (Works).

enum { CAVERN, ARCHIVE, WORKS }

const PAPER := Color(0.6, 0.58, 0.53)
const RED_INK := Color(0.62, 0.1, 0.1)

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


static func spiral(ci, c: Vector2, r: float, turns: float, col: Color, w: float, flip := 1.0) -> void:
	var p := PackedVector2Array()
	for i in 28:
		var u := i / 27.0
		var a := u * turns * TAU
		p.append(c + Vector2(cos(a) * flip, sin(a)) * r * (1.0 - u * 0.85))
	ci.draw_polyline(p, col, w, true)


## Lit edge along the top of a floor from x0 to x1 at height y.
static func floor_trim(ci, x0: float, x1: float, y: float, theme: int, rng: RandomNumberGenerator) -> void:
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
	_floor_details(ci, x0, x1, y, theme, rng)


## Things hanging from a ceiling from x0 to x1 at height y.
static func ceiling_trim(ci, x0: float, x1: float, y: float, theme: int, rng: RandomNumberGenerator) -> void:
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
	# torn paper strips dangling here and there
	var px := x0 + rng.randf_range(80, 260)
	while px < x1 - 30.0:
		if rng.randf() < 0.55:
			var l := rng.randf_range(34, 80)
			var bend := rng.randf_range(-6, 6)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 5, y), Vector2(px + 5, y),
				Vector2(px + 5 + bend, y + l * 0.6), Vector2(px + 1 + bend * 1.6, y + l), Vector2(px - 5 + bend * 1.4, y + l * 0.85),
				Vector2(px - 5 + bend, y + l * 0.5)]), PAPER.darkened(0.25))
			for k in 2:
				ci.draw_line(Vector2(px - 1.5 + bend * (0.3 + k * 0.3), y + 6 + k * 9), Vector2(px + 1.5 + bend * (0.3 + k * 0.3), y + 7 + k * 9),
					Color(0.1, 0.08, 0.1, 0.7), 1.0)
			ci.draw_circle(Vector2(px, y + 2), 1.6, Color(0.2, 0.2, 0.24))
		px += rng.randf_range(220, 480)


## A torn page of Shade's script nailed up (or lying flat when `fallen`):
## scrawled lines of handwriting, now and then a word struck out in red.
static func page(ci, c: Vector2, rot: float, scale: float, rng: RandomNumberGenerator, fallen := false) -> void:
	var w := 16.0 * scale
	var h := (22.0 if not fallen else 7.0) * scale
	var xf := Transform2D(rot, c)
	var torn := PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.2), Vector2(w * 0.3, h * 0.35), Vector2(w * 0.42, h * 0.5), Vector2(w * 0.05, h * 0.42),
		Vector2(-w * 0.2, h * 0.5), Vector2(-w * 0.5, h * 0.38)])
	var poly := PackedVector2Array()
	for p in torn:
		poly.append(xf * p)
	ci.draw_colored_polygon(poly, PAPER.darkened(0.12 if fallen else 0.0))
	poly.append(poly[0])
	ci.draw_polyline(poly, Color(0.05, 0.04, 0.08), 1.2)
	if fallen:
		return
	var rows := 5
	for k in rows:
		var ly := -h * 0.5 + 4.0 * scale + k * (h - 8.0 * scale) / rows
		var lx0 := -w * 0.5 + 2.5 * scale
		var lx1 := w * 0.5 - rng.randf_range(2.5, 6.0) * scale
		ci.draw_line(xf * Vector2(lx0, ly), xf * Vector2(lx1, ly + rng.randf_range(-0.6, 0.6)), Color(0.12, 0.1, 0.14, 0.75), 1.0)
	if rng.randf() < 0.6:  # a word struck out in red
		var ry := -h * 0.5 + 4.0 * scale + rng.randi_range(1, rows - 2) * (h - 8.0 * scale) / rows
		ci.draw_line(xf * Vector2(-w * 0.35, ry - 1.5), xf * Vector2(w * 0.25, ry + 1.5), RED_INK, 1.6)
	ci.draw_circle(xf * Vector2(0, -h * 0.5 + 2.5 * scale), 1.6 * scale, Color(0.25, 0.25, 0.3))  # the nail


## Detail along a floor: fallen pages and the zone's own clutter.
static func _floor_details(ci, x0: float, x1: float, y: float, theme: int, rng: RandomNumberGenerator) -> void:
	var pal: Dictionary = PALETTES[theme]
	var x := x0 + rng.randf_range(40, 200)
	while x < x1 - 30.0:
		var r := rng.randf()
		if r < 0.3:
			page(ci, Vector2(x, y - 4.0), rng.randf_range(-0.12, 0.12), 1.7, rng, true)
		elif r < 0.75:
			match theme:
				CAVERN:  # a cluster of glowing mushrooms
					for k in rng.randi_range(2, 4):
						var mx := x + k * rng.randf_range(8, 13)
						var mh := rng.randf_range(8, 22)
						ci.draw_line(Vector2(mx, y), Vector2(mx + rng.randf_range(-3, 3), y - mh), depth(theme, 0.4), 2.4)
						ci.draw_circle(Vector2(mx, y - mh), 11.0, Color(pal.glow, 0.12))
						ci.draw_colored_polygon(arc_pts(Vector2(mx, y - mh + 1), rng.randf_range(5.5, 8.5), 5.5, PI, TAU, 7), Color(pal.glow, 0.9))
				ARCHIVE:  # a burnt-down candle stub
					var ch := rng.randf_range(10, 22)
					ci.draw_rect(Rect2(x - 4.5, y - ch, 9, ch), Color(0.62, 0.58, 0.5))
					ci.draw_colored_polygon(ell(Vector2(x, y - 1), 9, 3, 10), Color(0.55, 0.5, 0.42))
					ci.draw_line(Vector2(x, y - ch), Vector2(x, y - ch - 3), Color(0.1, 0.08, 0.08), 1.0)
					ci.draw_circle(Vector2(x, y - ch - 9), 15.0, Color(pal.accent, 0.12))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, y - ch - 4), Vector2(x, y - ch - 15), Vector2(x + 3, y - ch - 4)]),
						Color(pal.accent, 0.95))
				WORKS:  # a dropped pencil stub
					var len := rng.randf_range(26, 40)
					var dir := 1.0 if rng.randf() < 0.5 else -1.0
					ci.draw_rect(Rect2(x - len * 0.5, y - 7.0, len, 7.0), Color(0.82, 0.62, 0.3))
					ci.draw_line(Vector2(x - len * 0.5, y - 3.5), Vector2(x + len * 0.5, y - 3.5), Color(0.6, 0.42, 0.2), 1.0)
					var tip := x + dir * len * 0.5
					ci.draw_colored_polygon(PackedVector2Array([Vector2(tip, y - 7.0), Vector2(tip + dir * 11, y - 3.5), Vector2(tip, y)]),
						Color(0.85, 0.75, 0.6))
					ci.draw_circle(Vector2(tip + dir * 9.5, y - 3.5), 1.5, Color(0.15, 0.12, 0.15))
		x += rng.randf_range(150, 360)


## Faint lit edge down a wall at x from y0 to y1. facing: +1 = open air to the right.
static func wall_trim(ci, x: float, y0: float, y1: float, facing: float, theme: int, rng: RandomNumberGenerator) -> void:
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
	# torn pages of the script nailed to the rock
	var py := y0 + rng.randf_range(60, 220)
	while py < y1 - 30.0:
		if rng.randf() < 0.55:
			page(ci, Vector2(x + facing * rng.randf_range(16, 24), py), rng.randf_range(-0.3, 0.3), rng.randf_range(1.8, 2.3), rng)
		py += rng.randf_range(260, 520)
