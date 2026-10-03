@tool
extends Node2D
## One depth layer of the Ink Cavern, generated per slot so it never ends.
## Put it inside a ComicParallax; `style` picks what it draws:
##   COILS      far: giant twisting columns of ribbed segments (pale, misty)
##   ARCHES     mid: gothic ribbed arches with swaying tendrils
##   SHELLS     near: ammonite-spiral shells and roots along floor and roof
##   SACS       amber glowing egg sacs (the only warm colour)
##   FOREGROUND black trunks, grass blades and vines in front of the player
## Cave depth rule (inverse of the sunny city): far = pale mist, near = black.
## Coordinates are screen space at the reference camera (floor at y ~446).

const ComicView = preload("res://scripts/background/comic_view.gd")
const INK := Color(0.02, 0.02, 0.03)

enum Style { COILS, ARCHES, SHELLS, SACS, FOREGROUND }

@export var style := Style.COILS
@export var seed := 1
@export var slot_width := 500.0
## Base tone of the shapes (greys; mist is mixed in by `haze`).
@export var tone := Color(0.3, 0.3, 0.33)
@export var mist := Color(0.6, 0.6, 0.64)
@export_range(0.0, 1.0) var haze := 0.0
@export var outline_width := 2.0
## Floor line of this layer (screen y at the reference camera).
@export var floor_y := 450.0
@export_range(0.0, 1.0) var empty_chance := 0.15

var _time := 0.0
var _last_xf := Transform2D()


func _process(delta: float) -> void:
	_time += delta
	var animated := style == Style.ARCHES or style == Style.SACS or style == Style.FOREGROUND
	var xf := get_global_transform_with_canvas()
	if animated or Engine.is_editor_hint() or xf != _last_xf:
		_last_xf = xf
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = ComicView.local_view(self).rect
	var i0 := floori(rect.position.x / slot_width) - 1
	var i1 := mini(ceili(rect.end.x / slot_width) + 1, i0 + 80)
	for i in range(i0, i1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(seed, i, 7727))
		if rng.randf() < empty_chance:
			continue
		var x := (i + rng.randf_range(0.2, 0.8)) * slot_width
		match style:
			Style.COILS: _draw_coil_column(x, rng, rect)
			Style.ARCHES: _draw_arch(x, rng)
			Style.SHELLS: _draw_shells(x, rng)
			Style.SACS: _draw_sac(x, rng)
			Style.FOREGROUND: _draw_foreground(x, rng)


func _c(shade := 0.0) -> Color:
	var c := tone.lightened(shade) if shade > 0.0 else tone.darkened(-shade)
	c = c.lerp(mist, haze)
	c.a = 1.0
	return c


func _ink() -> Color:
	var c := INK.lerp(mist, haze * 0.8)
	c.a = 1.0
	return c


# ---------------------------------------------------------------- coils

func _draw_coil_column(x: float, rng: RandomNumberGenerator, rect: Rect2) -> void:
	# a ribbed organic column: overlapping rounded segments whose width
	# swells and pinches along a slow twist, each shaded like a cylinder
	var w := rng.randf_range(130.0, 220.0)
	var twist := rng.randf_range(30.0, 80.0)
	var freq := rng.randf_range(0.003, 0.007)
	var ph := rng.randf() * TAU
	var bulge_ph := rng.randf() * TAU
	var y := floor_y + 140.0
	var top := minf(rect.position.y - 80.0, floor_y - 900.0)
	var k := 0
	while y > top and k < 48:
		var h := rng.randf_range(48.0, 66.0)
		var cx := x + sin(y * freq + ph) * twist
		var sw := w * (0.78 + 0.28 * sin(k * 0.55 + bulge_ph)) * lerpf(1.25, 1.0, clampf(float(k) / 4.0, 0.0, 1.0))
		_draw_segment(Vector2(cx, y - h * 0.5), Vector2(sw, h))
		y -= h * 0.6
		k += 1
	if rng.randf() < 0.5:
		var cx := x + sin(y * freq + ph) * twist
		_draw_spiral(Vector2(cx, y), w * 0.55, _c(0.04), _ink())


func _draw_segment(c: Vector2, s: Vector2) -> void:
	var pts := PackedVector2Array()
	for j in 24:
		var a := TAU * j / 24.0
		pts.append(c + Vector2(cos(a) * s.x * 0.5, sin(a) * s.y * 0.5))
	draw_colored_polygon(pts, _c())
	# shadowed underside (cylinder volume)
	var shade := PackedVector2Array()
	for j in 13:
		var a := PI * j / 12.0
		shade.append(c + Vector2(cos(a) * s.x * 0.5, sin(a) * s.y * 0.5))
	for j in range(12, -1, -1):
		var a := PI * j / 12.0
		shade.append(c + Vector2(cos(a) * s.x * 0.42, sin(a) * s.y * 0.12))
	draw_colored_polygon(shade, _c(-0.35))
	pts.append(pts[0])
	draw_polyline(pts, _ink(), outline_width)
	# rib + rim light
	draw_arc(c - Vector2(0, s.y * 0.05), s.x * 0.34, PI * 1.12, PI * 1.88, 10, _c(-0.2), outline_width * 0.8)
	draw_arc(c - Vector2(s.x * 0.1, s.y * 0.14), s.x * 0.26, PI * 1.2, PI * 1.55, 8, _c(0.22), 1.5)


func _draw_spiral(c: Vector2, r: float, fill: Color, line: Color) -> void:
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 32, line, outline_width)
	var pts := PackedVector2Array()
	for j in 60:
		var t := j / 59.0
		var a := t * TAU * 2.6
		pts.append(c + Vector2.from_angle(a) * r * (1.0 - t * 0.92))
	draw_polyline(pts, line, outline_width * 0.9, true)


# --------------------------------------------------------------- arches

func _draw_arch(x: float, rng: RandomNumberGenerator) -> void:
	var half := rng.randf_range(70.0, 120.0)
	var top_y := floor_y - rng.randf_range(380.0, 560.0)
	var apex := Vector2(x, top_y)
	for side in [-1.0, 1.0]:
		var foot := Vector2(x + side * half, floor_y + 60.0)
		var ctrl := Vector2(x + side * half * 1.25, top_y + (floor_y - top_y) * 0.35)
		_draw_rib(foot, ctrl, apex, 22.0, 7.0)
		# inner rib
		_draw_rib(foot + Vector2(-side * 16, 0), ctrl + Vector2(-side * 18, 10), apex + Vector2(0, 26), 8.0, 3.0)
	# ribbed capital where the ribs meet
	draw_circle(apex + Vector2(0, 8), 12.0, _c(0.08))
	draw_arc(apex + Vector2(0, 8), 12.0, 0, TAU, 16, _ink(), outline_width)
	# tendrils dangling from the arch, swaying
	for k in rng.randi_range(2, 4):
		var root := apex + Vector2(rng.randf_range(-half * 0.6, half * 0.6), rng.randf_range(20.0, 80.0))
		var length := rng.randf_range(90.0, 230.0)
		var ph := rng.randf() * TAU
		var pts := PackedVector2Array()
		for j in 12:
			var t := j / 11.0
			var sway := sin(_time * 0.8 + ph + t * 2.5) * 14.0 * t
			pts.append(root + Vector2(sway + sin(t * 6.0 + ph) * 6.0, t * length))
		draw_polyline(pts, _ink(), 4.0, true)
		draw_polyline(pts, _c(-0.05), 2.0, true)


func _draw_rib(a: Vector2, ctrl: Vector2, b: Vector2, w0: float, w1: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 18
	for j in n + 1:
		var t := float(j) / n
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		var p2 := a.lerp(ctrl, t + 0.01).lerp(ctrl.lerp(b, t + 0.01), t + 0.01)
		var dir := (p2 - p).normalized()
		var nrm := Vector2(-dir.y, dir.x) * lerpf(w0, w1, t) * 0.5
		left.append(p + nrm)
		right.append(p - nrm)
	right.reverse()
	var poly := left + right
	draw_colored_polygon(poly, _c())
	poly.append(poly[0])
	draw_polyline(poly, _ink(), outline_width)
	# segment rings along the rib (the ribbed look)
	for j in range(2, n, 3):
		draw_line(left[j], right[n - j], _c(-0.2), 1.5)


# --------------------------------------------------------------- shells

func _draw_shells(x: float, rng: RandomNumberGenerator) -> void:
	# a cluster on the floor and sometimes one hanging from the roof
	for k in rng.randi_range(2, 4):
		var r := rng.randf_range(26.0, 62.0)
		var c := Vector2(x + rng.randf_range(-90.0, 90.0), floor_y - r * 0.55 + rng.randf_range(-10.0, 14.0))
		_draw_spiral(c, r, _c(rng.randf_range(-0.05, 0.08)), _ink())
	if rng.randf() < 0.6:
		# root/trunk rising out of the cluster
		var pts := PackedVector2Array()
		var ph := rng.randf() * TAU
		for j in 10:
			var t := j / 9.0
			pts.append(Vector2(x + sin(t * 3.0 + ph) * 26.0, floor_y + 30.0 - t * rng.randf_range(260.0, 420.0)))
		draw_polyline(pts, _ink(), 18.0, true)
		draw_polyline(pts, _c(-0.08), 11.0, true)
	if rng.randf() < 0.45:
		var r := rng.randf_range(30.0, 50.0)
		_draw_spiral(Vector2(x + rng.randf_range(-60, 60), floor_y - rng.randf_range(560.0, 700.0)), r, _c(), _ink())


# ----------------------------------------------------------------- sacs

func _draw_sac(x: float, rng: RandomNumberGenerator) -> void:
	var amber := Color(1.0, 0.72, 0.38)
	var hanging := rng.randf() < 0.4
	var r := rng.randf_range(26.0, 44.0)
	var c := Vector2(x, floor_y - r * 1.05) if not hanging else Vector2(x, floor_y - rng.randf_range(300.0, 420.0))
	var pulse := 0.8 + 0.2 * sin(_time * 1.6 + x * 0.01)
	for k in 4:  # glow halo in flat comic bands
		draw_circle(c, r * (1.6 + k * 0.7) * pulse, Color(amber, 0.07 - k * 0.014))
	if hanging:
		draw_line(c - Vector2(0, r), c - Vector2(0, r + 260.0), INK, 4.0)
	var body := PackedVector2Array()
	for j in 24:
		var a := TAU * j / 24.0
		body.append(c + Vector2(cos(a) * r * 0.82, sin(a) * r * (1.0 + 0.12 * sin(a))))
	draw_colored_polygon(body, amber.darkened(0.15))
	draw_circle(c + Vector2(-r * 0.15, -r * 0.2), r * 0.5, amber.lightened(0.25))
	draw_circle(c + Vector2(r * 0.2, r * 0.25), r * 0.14, amber.darkened(0.35))  # spots
	draw_circle(c + Vector2(-r * 0.35, r * 0.35), r * 0.1, amber.darkened(0.35))
	body.append(body[0])
	draw_polyline(body, INK, 2.5)


# ----------------------------------------------------------- foreground

func _draw_foreground(x: float, rng: RandomNumberGenerator) -> void:
	var black := INK
	match rng.randi() % 3:
		0:  # twisted trunk from below the floor up out of view
			var ph := rng.randf() * TAU
			var lean := rng.randf_range(-120.0, 120.0)
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for j in 16:
				var t := j / 15.0
				var cx := x + sin(t * 4.0 + ph) * 30.0 + lean * t
				var w := lerpf(46.0, 24.0, t)
				var y := floor_y + 120.0 - t * 1100.0
				left.append(Vector2(cx - w, y))
				right.append(Vector2(cx + w, y))
			right.reverse()
			draw_colored_polygon(left + right, black)
		1:  # spiky grass tuft along the bottom, swaying
			for k in rng.randi_range(6, 11):
				var bx := x + rng.randf_range(-110.0, 110.0)
				var h := rng.randf_range(60.0, 170.0)
				var sway := sin(_time * 1.2 + bx * 0.05) * 8.0
				draw_colored_polygon(PackedVector2Array([Vector2(bx - 6, floor_y + 60), Vector2(bx + sway, floor_y + 60 - h),
					Vector2(bx + 6, floor_y + 60)]), black)
		_:  # vines hanging from the roof
			for k in rng.randi_range(2, 4):
				var vx := x + rng.randf_range(-80.0, 80.0)
				var length := rng.randf_range(160.0, 360.0)
				var ph := rng.randf() * TAU
				var pts := PackedVector2Array()
				for j in 12:
					var t := j / 11.0
					pts.append(Vector2(vx + sin(_time * 0.7 + ph + t * 2.0) * 16.0 * t, floor_y - 700.0 + t * length))
				draw_polyline(pts, black, lerpf(10.0, 5.0, 0.5), true)
