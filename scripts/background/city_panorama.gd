extends Node2D
## Shade's corrupted comic city, redrawn in code from the concept painting
## (one 1280 x 720 screen, tiled sideways by its Parallax2D). Every shape is
## placed in the painting's own pixel coordinates (1699 x 926, panel from
## x 85 / y 20) and mapped onto the screen by _p() / _r(), so the start screen
## matches the painting. `part` picks what this copy draws:
##   "city"  buildings, redaction bars, graffiti, posters (far, slow scroll)
##   "junk"  lamp post, debris heaps, machines, paper stacks, ink spill (near)

const INK := Color(0.07, 0.05, 0.12)
const RED := Color(0.76, 0.1, 0.16)
const REDACT := Color(0.04, 0.03, 0.05)
const PAPER := Color(0.92, 0.9, 0.84)
const TEAL := Color(0.36, 0.5, 0.56)
const TEAL_D := Color(0.22, 0.32, 0.38)
const CYAN := Color(0.15, 0.78, 0.92)
const MAGENTA := Color(0.95, 0.24, 0.62)
const YELLOW := Color(1.0, 0.88, 0.25)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const CHEWY = preload("res://assets/fonts/Chewy-Regular.ttf")
const K := 1280.0 / 1545.0  # painting px -> screen px

@export_enum("city", "junk") var part := "city"


func _p(x: float, y: float) -> Vector2:
	return Vector2((x - 85.0) * K, (y - 20.0) * K)


func _r(x1: float, y1: float, x2: float, y2: float) -> Rect2:
	return Rect2(_p(x1, y1), _p(x2, y2) - _p(x1, y1))


func _draw() -> void:
	if part == "city":
		_city()
	else:
		_junk()


# ------------------------------------------------------------------ city

func _city() -> void:
	var lav := Color(0.72, 0.66, 0.9)
	var pink := Color(0.95, 0.62, 0.78)
	var pink_d := Color(0.86, 0.45, 0.68)
	var blue := Color(0.55, 0.72, 0.95)
	var blue_l := Color(0.68, 0.82, 0.98)
	var salmon := Color(0.97, 0.6, 0.55)
	var peach := Color(0.98, 0.7, 0.62)
	var violet := Color(0.6, 0.52, 0.85)
	# far row, pale and hazy
	_bldg(_r(960, 145, 1068, 760), blue_l, "stripes")
	_spire(_p(965, 160), 44.0, Color(0.85, 0.62, 0.86))
	_bldg(_r(1350, 140, 1468, 760), blue_l, "stripes")
	_antenna(_p(1408, 140), 40.0)
	_bldg(_r(1240, 255, 1335, 760), blue, "stripes")
	_spire(_p(1287, 175), 70.0, blue)
	_bldg(_r(1468, 300, 1640, 760), Color(0.66, 0.6, 0.88), "stripes")
	_spire(_p(1500, 290), 40.0, Color(0.85, 0.55, 0.8))
	_bldg(_r(530, 210, 640, 760), Color(0.6, 0.66, 0.95), "stripes")
	_bldg(_r(720, 235, 830, 760), lav, "stripes")
	_bldg(_r(830, 250, 905, 760), Color(0.78, 0.62, 0.9), "stripes")
	_bldg(_r(160, 240, 250, 760), Color(0.36, 0.4, 0.62), "dots")
	# middle row
	_bldg(_r(365, 240, 535, 760), pink, "stripes")
	_bldg(_r(885, 255, 960, 760), Color(0.92, 0.6, 0.78), "stripes")
	_bldg(_r(1050, 265, 1290, 760), salmon, "windows")
	_roof_box(_r(1060, 250, 1110, 268), Color(0.8, 0.5, 0.48))
	_bldg(_r(1335, 375, 1615, 760), pink_d, "windows")
	_bldg(_r(85, 380, 240, 760), Color(0.45, 0.52, 0.85), "windows")
	_house(_r(95, 355, 200, 420))
	_bldg(_r(240, 395, 370, 760), Color(0.55, 0.66, 0.95), "windows")
	_bldg(_r(585, 330, 750, 760), peach, "stripes")
	_roof_box(_r(625, 330, 712, 352), Color(0.9, 0.55, 0.55))
	_antenna(_p(557, 385), 34.0)
	_bldg(_r(880, 405, 1065, 760), violet, "windows")
	_water_tower(_p(958, 380))
	_bldg(_r(1110, 520, 1300, 760), Color(0.98, 0.66, 0.62), "stripes")
	_bldg(_r(1440, 470, 1640, 760), Color(0.42, 0.36, 0.56), "dots")
	# light streaks top right
	for k in 3:
		var a := _p(1640, 70 + k * 45)
		var b := _p(1380, 150 + k * 60)
		draw_line(a, b, Color(0.82, 0.8, 0.95, 0.35 - k * 0.08), 14.0 - k * 3.0)
	# redaction bars
	for b in [[390, 338, 502, 356], [250, 472, 460, 500], [575, 466, 742, 490], [950, 306, 1165, 333],
			[1410, 392, 1570, 425], [350, 626, 500, 655], [418, 660, 505, 672], [1490, 495, 1630, 560],
			[1445, 655, 1525, 680], [1520, 683, 1620, 700], [960, 640, 1035, 660], [918, 512, 1005, 528],
			[920, 565, 1015, 580], [925, 428, 975, 446], [555, 268, 615, 280], [80, 488, 130, 520]]:
		draw_rect(_r(b[0], b[1], b[2], b[3]), REDACT)
	# graffiti, posters
	_graffiti(_p(372, 330), "DELETE", 46, -0.06, RED)
	_graffiti(_p(272, 530), "SCRAPPED_BUILDING_04", 20, 0.0, RED, false)
	_graffiti(_p(272, 553), "NOT FOUND", 20, 0.0, RED, false)
	_graffiti(_p(110, 528), "ERROR: SUBMITTER", 14, 0.03, RED, false)
	_graffiti(_p(110, 553), "NOT FOUND", 14, 0.03, RED, false)
	_graffiti(_p(596, 560), "CORRUPTED", 30, -0.12, RED)
	_graffiti(_p(1110, 458), "SCRAAPPER +", 30, 0.02, RED)
	_graffiti(_p(1098, 494), "BUILDING_04", 30, 0.0, RED)
	_graffiti(_p(1148, 668), "CORRAPTED", 18, 0.0, RED, false)
	_graffiti(_p(1492, 630), "CORRUPTED", 22, -0.12, RED)
	_graffiti(_p(1530, 660), "DATA", 22, -0.12, RED)
	_poster(_r(102, 570, 228, 720))


func _bldg(r: Rect2, col: Color, style: String) -> void:
	draw_rect(r.grow(2.0), INK)
	draw_rect(r, col)
	var shade := Rect2(r.end.x - r.size.x * 0.28, r.position.y, r.size.x * 0.28, r.size.y)
	draw_rect(shade, col.darkened(0.12))
	_dots(shade, col.darkened(0.3), 5.0, 1.4)
	match style:
		"stripes":
			var x := r.position.x + 6.0
			while x < r.end.x - 4.0:
				draw_line(Vector2(x, r.position.y + 6), Vector2(x, r.end.y), col.lightened(0.18), 2.0)
				x += 9.0
		"windows":
			var y := r.position.y + 10.0
			while y < r.end.y - 8.0:
				var x := r.position.x + 8.0
				while x < r.end.x - 12.0:
					var lit := fmod(x * 7.0 + y * 3.0, 5.0) < 2.4
					draw_rect(Rect2(x, y, 9, 11), Color(1.0, 0.92, 0.55) if lit else col.darkened(0.25))
					x += 16.0
				y += 18.0
		"dots":
			_dots(r, col.lightened(0.25), 6.0, 1.6)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), col.lightened(0.25))


func _dots(r: Rect2, col: Color, step: float, rad: float) -> void:
	var y := r.position.y + step * 0.5
	var row := 0
	while y < r.end.y:
		var x := r.position.x + step * 0.5 + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			draw_circle(Vector2(x, y), rad, col)
			x += step
		y += step
		row += 1


func _spire(base: Vector2, h: float, col: Color) -> void:
	var pts := PackedVector2Array([base + Vector2(-h * 0.6, h * 0.15), base + Vector2(0, -h * 0.8), base + Vector2(h * 0.6, h * 0.15)])
	draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array([pts[0] + Vector2(2, -1), pts[1] + Vector2(0, 3), pts[2] + Vector2(-2, -1)])
	draw_colored_polygon(inner, col)


func _antenna(top: Vector2, h: float) -> void:
	draw_line(top, top + Vector2(0, h), INK, 2.0)
	draw_circle(top, 3.0, Color(0.95, 0.3, 0.3))


func _roof_box(r: Rect2, col: Color) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, col)


func _house(r: Rect2) -> void:
	var roof := PackedVector2Array([Vector2(r.position.x - 4, r.position.y + r.size.y * 0.45), Vector2(r.get_center().x, r.position.y),
		Vector2(r.end.x + 4, r.position.y + r.size.y * 0.45)])
	draw_rect(Rect2(r.position + Vector2(4, r.size.y * 0.4), Vector2(r.size.x - 8, r.size.y * 0.6)).grow(2), INK)
	draw_rect(Rect2(r.position + Vector2(4, r.size.y * 0.4), Vector2(r.size.x - 8, r.size.y * 0.6)), Color(0.6, 0.48, 0.5))
	draw_colored_polygon(roof, Color(0.42, 0.3, 0.36))


func _water_tower(base: Vector2) -> void:
	draw_rect(Rect2(base + Vector2(-12, -26), Vector2(24, 20)).grow(2), INK)
	draw_rect(Rect2(base + Vector2(-12, -26), Vector2(24, 20)), Color(0.5, 0.42, 0.5))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-15, -26), base + Vector2(0, -36), base + Vector2(15, -26)]), INK)
	for sx in [-8.0, 8.0]:
		draw_line(base + Vector2(sx, -6), base + Vector2(sx * 1.3, 4), INK, 2.0)


func _poster(r: Rect2) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, Color(0.78, 0.74, 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 9:
		var p := Vector2(rng.randf_range(r.position.x + 8, r.end.x - 24), rng.randf_range(r.position.y + 6, r.end.y - 24))
		draw_set_transform(p, rng.randf_range(-0.3, 0.3))
		draw_rect(Rect2(-1, -1, 26, 22), INK)
		draw_rect(Rect2(0, 0, 24, 20), PAPER)
		draw_line(Vector2(4, 6), Vector2(20, 6), Color(0.4, 0.4, 0.5), 1.0)
		draw_line(Vector2(4, 11), Vector2(18, 11), Color(0.4, 0.4, 0.5), 1.0)
		draw_set_transform(Vector2.ZERO)
	_graffiti(r.position + Vector2(10, r.size.y * 0.62), "ESCAPED", 14, -0.04, RED, false)
	_graffiti(r.position + Vector2(10, r.size.y * 0.62 + 16), "NOT FOUND", 14, -0.04, RED, false)


func _graffiti(p: Vector2, text: String, size: int, rot: float, col: Color, drips := true) -> void:
	draw_set_transform(p, rot)
	var font: Font = FONT if drips else CHEWY
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if drips:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		for k in int(w / 12.0):
			var x := 5.0 + k * 12.0 + sin(k * 3.7) * 3.0
			var l := 6.0 + absf(sin(k * 2.3)) * size * 0.9
			draw_line(Vector2(x, 2), Vector2(x, 2 + l), col, 2.0)
			draw_circle(Vector2(x, 3 + l), 1.8, col)
	draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ junk

func _junk() -> void:
	# lamp post hooking over the left
	draw_rect(_r(228, 240, 242, 760), INK)
	draw_rect(_r(222, 700, 248, 760), INK)
	draw_line(_p(235, 244), _p(150, 244), INK, 7.0)
	draw_colored_polygon(PackedVector2Array([_p(128, 244), _p(176, 244), _p(166, 268), _p(138, 268)]), INK)
	draw_circle(_p(152, 272), 6.0, Color(1.0, 0.95, 0.7))
	draw_circle(_p(152, 272), 16.0, Color(1.0, 0.95, 0.7, 0.18))
	# left debris: heap, desk and papers
	_heap([[85, 760], [85, 700], [170, 690], [260, 640], [330, 600], [420, 640], [470, 700], [500, 760]], 21)
	_crate(_r(85, 700, 240, 760), Color(0.58, 0.6, 0.64))
	_sheets(_p(300, 640), 6, 31)
	_sheets(_p(420, 700), 5, 32)
	# centre-left machine with CMYK stacks
	_machine(_r(470, 640, 700, 760))
	_stack(_r(535, 560, 625, 615), 6)
	_stack(_r(600, 660, 790, 760), 9)
	_stack(_r(745, 670, 805, 760), 7)
	# the glowing cyan ink spill and its CLUNK!
	_spill([[700, 760], [740, 715], [820, 705], [930, 712], [1010, 735], [1030, 760]])
	_graffiti(_p(790, 768), "CLUNK!", 24, -0.05, RED)
	_graffiti(_p(870, 640), "SAFE ZONE", 28, -0.12, Color(1.0, 0.95, 0.7, 0.85), false)
	# centre-right machinery and stacks
	_stack(_r(905, 690, 1020, 760), 6)
	_machine(_r(1020, 640, 1130, 760))
	_roller(_p(1050, 750), 70.0, 12.0)
	# right: broken scaffold with cables, paper heap, CMYK slab
	_heap([[1120, 760], [1140, 680], [1210, 640], [1300, 650], [1350, 700], [1380, 760]], 22)
	_scaffold()
	_sheets(_p(1260, 660), 8, 33)
	_sheets(_p(1180, 700), 6, 34)
	_crate(_r(1250, 735, 1450, 760), Color(0.88, 0.86, 0.82))
	draw_rect(_r(1450, 735, 1630, 760).grow(2), INK)
	draw_rect(_r(1450, 735, 1540, 760), MAGENTA)
	draw_rect(_r(1540, 735, 1630, 760), YELLOW)


func _heap(pts_in: Array, seed: int) -> void:
	var pts := PackedVector2Array()
	for q in pts_in:
		pts.append(_p(q[0], q[1]))
	draw_colored_polygon(pts, TEAL_D)
	draw_polyline(pts, INK, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lo := pts[0].x
	var hi := pts[pts.size() - 1].x
	for k in 40:
		var x := rng.randf_range(lo, hi)
		var y := rng.randf_range(pts[0].y - 70.0, pts[0].y - 4.0)
		if Geometry2D.is_point_in_polygon(Vector2(x, y), pts):
			draw_set_transform(Vector2(x, y), rng.randf_range(-0.9, 0.9))
			var s := rng.randf_range(8.0, 20.0)
			draw_rect(Rect2(-s * 0.5 - 1, -s * 0.35 - 1, s + 2, s * 0.7 + 2), INK)
			draw_rect(Rect2(-s * 0.5, -s * 0.35, s, s * 0.7), PAPER.darkened(rng.randf_range(0.0, 0.3)) if rng.randf() < 0.6 else TEAL)
			draw_set_transform(Vector2.ZERO)


func _crate(r: Rect2, col: Color) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, col)
	draw_line(r.position + Vector2(0, r.size.y * 0.35), Vector2(r.end.x, r.position.y + r.size.y * 0.35), INK, 1.5)


func _sheets(c: Vector2, n: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in n:
		draw_set_transform(c + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 10)), rng.randf_range(-0.7, 0.7))
		draw_rect(Rect2(-13, -9, 26, 18), INK)
		draw_rect(Rect2(-12, -8, 24, 16), PAPER)
		draw_line(Vector2(-8, -3), Vector2(8, -3), Color(0.5, 0.5, 0.6), 1.0)
		draw_line(Vector2(-8, 2), Vector2(6, 2), Color(0.5, 0.5, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO)


func _machine(r: Rect2) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, TEAL)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), TEAL.lightened(0.3))
	for k in 3:
		var c := Vector2(r.position.x + r.size.x * (0.25 + k * 0.25), r.position.y + r.size.y * 0.4)
		draw_circle(c, 11.0, INK)
		draw_circle(c, 8.0, TEAL_D)
	draw_rect(Rect2(r.position.x + 6, r.end.y - 14, r.size.x - 12, 6), TEAL_D)


func _stack(r: Rect2, n: int) -> void:
	var h := r.size.y / n
	for k in n:
		var y := r.end.y - (k + 1) * h
		var x := r.position.x + sin(k * 1.7) * 3.0
		draw_rect(Rect2(x - 1, y - 1, r.size.x + 2, h + 2), INK)
		draw_rect(Rect2(x, y, r.size.x, h - 1), PAPER.darkened(0.08 * (k % 2)))
		draw_rect(Rect2(x, y + h - 3, r.size.x, 2), [CYAN, MAGENTA, YELLOW][k % 3])
	# CMYK printed top
	var top := Rect2(r.position.x, r.position.y - 6, r.size.x, 7)
	draw_rect(top.grow(1), INK)
	draw_rect(Rect2(top.position, Vector2(top.size.x / 3.0, top.size.y)), CYAN)
	draw_rect(Rect2(top.position + Vector2(top.size.x / 3.0, 0), Vector2(top.size.x / 3.0, top.size.y)), MAGENTA)
	draw_rect(Rect2(top.position + Vector2(top.size.x * 2.0 / 3.0, 0), Vector2(top.size.x / 3.0, top.size.y)), YELLOW)


func _spill(pts_in: Array) -> void:
	var pts := PackedVector2Array()
	for q in pts_in:
		pts.append(_p(q[0], q[1]))
	draw_colored_polygon(pts, Color(0.2, 0.75, 0.88, 0.85))
	draw_polyline(pts, Color(0.05, 0.25, 0.35), 2.0)
	draw_circle(pts[2] + Vector2(10, 10), 14.0, Color(1, 1, 1, 0.3))


func _roller(c: Vector2, l: float, r: float) -> void:
	var rect := Rect2(c - Vector2(l * 0.5, r), Vector2(l, r * 2.0))
	draw_rect(rect.grow(2), INK)
	draw_rect(rect, TEAL)
	for k in 3:
		draw_rect(Rect2(rect.position.x + l * (0.15 + k * 0.28), rect.position.y, l * 0.16, r * 2.0), [CYAN, MAGENTA, YELLOW][k])


func _scaffold() -> void:
	var deck := _r(1225, 570, 1500, 590)
	draw_rect(deck.grow(2), INK)
	draw_rect(deck, Color(0.55, 0.56, 0.6))
	for x in [1240, 1330, 1420, 1490]:
		draw_line(_p(x, 590), _p(x + 10, 700), INK, 3.0)
	for c in [[1260, 590, 1300, 690], [1330, 590, 1380, 670], [1400, 590, 1420, 720], [1450, 590, 1470, 650]]:
		var a := _p(c[0], c[1])
		var b := _p(c[2], c[3])
		draw_polyline(PackedVector2Array([a, (a + b) * 0.5 + Vector2(10, 6), b]), INK, 2.0)
	_sheets(_p(1300, 565), 4, 35)
