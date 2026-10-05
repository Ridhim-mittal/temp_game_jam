extends Node2D
## One parallax layer of depth_backdrop.gd. The layer's own space is the
## world scaled by `scroll`, cut into cells; each cell's scenery is generated
## from its coordinates, so only the cells around the camera are ever drawn
## and the layer is redrawn only when that set of cells changes. All cells
## use the style of the zone the camera is in (a far layer shows the same
## scenery across thousands of px of level, so it cannot follow zone borders;
## put the borders in narrow shafts and the switch goes unnoticed).

const Style = preload("res://scripts/depth/depth_style.gd")
const CELL := Vector2(440, 380)

var backdrop: Node2D
## 0 = fixed to the screen (infinitely far), 1 = moves with the level.
var scroll := 0.3
## 0 = pale and foggy, 1 = as dark as the playfield.
var depth_k := 0.5
## 0 far, 1 mid, 2 near: picks which scenery the layer draws.
var kind := 0

var _cells := Rect2i()


func follow(camera_center: Vector2) -> void:
	position = camera_center * (1.0 - scroll)
	var centre := camera_center * scroll
	var half := get_viewport_rect().size * 0.5
	var first := Vector2i(((centre - half) / CELL).floor()) - Vector2i.ONE
	var last := Vector2i(((centre + half) / CELL).floor()) + Vector2i.ONE
	var cells := Rect2i(first, last - first + Vector2i.ONE)
	if cells != _cells:
		_cells = cells
		queue_redraw()


## The camera moved into another zone: redraw in its style and fade back in.
func retheme() -> void:
	queue_redraw()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	for cy in range(_cells.position.y, _cells.end.y):
		for cx in range(_cells.position.x, _cells.end.x):
			rng.seed = hash(Vector3i(cx, cy, kind + backdrop.current_theme * 10))
			var origin := Vector2(cx, cy) * CELL
			var theme: int = backdrop.current_theme
			draw_rect(Rect2(origin, CELL), Color(Style.PALETTES[theme].fog, 0.07))  # fog between layers
			match theme:
				Style.CAVERN:
					_cavern(origin, rng, cx)
				Style.ARCHIVE:
					_archive(origin, rng, cx, cy)
				Style.WORKS:
					_works(origin, rng, cx)


func _col(theme: int, jitter := 0.0) -> Color:
	return Style.depth(theme, clampf(depth_k + jitter, 0.0, 1.0))


func _glow(p: Vector2, r: float, col: Color, a := 0.5) -> void:
	draw_texture_rect(backdrop.glow_texture, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, a))


func _orb(p: Vector2, r: float, theme: int) -> void:
	var glow: Color = Style.PALETTES[theme].glow
	_glow(p, r * 8.0, glow, 0.55)
	draw_circle(p, r, Color(glow, 0.6))
	draw_circle(p, r * 0.6, Color(1, 1, 1, 0.9))


# ------------------------------------------------------------------ cavern

func _cavern(o: Vector2, rng: RandomNumberGenerator, cx: int) -> void:
	var t := Style.CAVERN
	match kind:
		0:  # huge looping pen-stroke roots and fine hanging threads
			var pts := PackedVector2Array()
			var x0 := o.x + CELL.x * 0.5
			for k in 13:
				var y := o.y + CELL.y * k / 12.0
				pts.append(Vector2(x0 + sin(y * 0.006 + cx * 1.7) * 150.0, y))
			draw_polyline(pts, _col(t), rng.randf_range(40.0, 72.0), true)
			for i in 7:
				var x := o.x + rng.randf() * CELL.x
				var y0 := o.y + rng.randf() * CELL.y
				draw_line(Vector2(x, y0), Vector2(x + rng.randf_range(-6, 6), y0 + rng.randf_range(80, 300)), _col(t, 0.08),
					rng.randf_range(1.0, 3.0))
		1:  # mounds of glossy ink droplets, a lantern bulb on a thread
			var c := o + Vector2(rng.randf(), rng.randf()) * CELL
			for i in 7:
				var p := c + Vector2(rng.randf_range(-130, 130), rng.randf_range(-70, 70))
				var r := rng.randf_range(16.0, 46.0)
				var col := _col(t, rng.randf_range(-0.1, 0.05))
				draw_colored_polygon(Style.ell(p, r, r * 0.86, 16), col)
				draw_arc(p, r * 0.72, PI + 0.4, PI + 1.5, 6, col.lightened(0.35), 3.0)
			if rng.randf() < 0.55:
				var lp := o + Vector2(rng.randf(), rng.randf_range(0.2, 0.9)) * CELL
				draw_line(lp + Vector2(0, -rng.randf_range(80, 200)), lp, _col(t, 0.15), 1.5)
				_orb(lp, 11.0, t)
				draw_arc(lp, 13.0, 0, TAU, 16, _col(t, 0.2), 2.0)
		2:  # floating shelves of rock trailing drips, the odd pale bubble
			var c2 := o + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)) * CELL
			var w := rng.randf_range(90.0, 190.0)
			var col2 := _col(t)
			draw_colored_polygon(Style.ell(c2, w, 22.0, 18), col2)
			for i in int(w / 14.0):
				var x2 := c2.x + rng.randf_range(-w * 0.85, w * 0.85)
				var l := 14.0 + pow(rng.randf(), 2.0) * 140.0
				draw_colored_polygon(PackedVector2Array([Vector2(x2 - 7, c2.y + 8), Vector2(x2 + 7, c2.y + 8), Vector2(x2, c2.y + l)]), col2)
				var h := rng.randf_range(10.0, 44.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x2 - 3, c2.y - 14), Vector2(x2 + rng.randf_range(-9, 9), c2.y - 14 - h),
					Vector2(x2 + 3, c2.y - 14)]), col2)
			if rng.randf() < 0.3:
				var bp := o + Vector2(rng.randf(), rng.randf()) * CELL
				var br := rng.randf_range(16.0, 36.0)
				_glow(bp, br * 3.0, Style.PALETTES[t].glow, 0.4)
				draw_colored_polygon(Style.ell(bp, br, br * 0.9, 18), Color(0.7, 0.93, 0.9))
				draw_colored_polygon(Style.ell(bp + Vector2(3, 4), br * 0.78, br * 0.68, 16), Color(0.45, 0.78, 0.8))
				draw_arc(bp, br * 0.7, PI + 0.5, PI + 1.3, 6, Color(1, 1, 1, 0.8), 3.0)
				draw_arc(bp, br, 0, TAU, 20, Style.PALETTES[t].dark, 2.5)


# ----------------------------------------------------------------- archive

func _archive(o: Vector2, rng: RandomNumberGenerator, cx: int, cy: int) -> void:
	var t := Style.ARCHIVE
	var pal: Dictionary = Style.PALETTES[t]
	match kind:
		0:  # rose windows and round-headed arches with tracery, vault ribs between
			var col := _col(t)
			var c := o + CELL * 0.5
			if posmod(cx + cy * 2, 3) == 0:
				draw_colored_polygon(Style.ell(c, 150, 150, 32), Color(pal.fog, 0.2))
				draw_arc(c, 150, 0, TAU, 40, col, 8.0)
				draw_arc(c, 54, 0, TAU, 24, col, 4.5)
				for k in 10:
					var d := Vector2.from_angle(TAU * k / 10.0)
					draw_line(c + d * 54, c + d * 148, col, 3.5)
					draw_arc(c + d * 102, 30, 0, TAU, 14, col, 3.0)
			else:
				var arch := PackedVector2Array([Vector2(c.x - 78, o.y + CELL.y)])
				arch.append_array(Style.arc_pts(Vector2(c.x, o.y + 150), 78, 110, PI, TAU, 14))
				arch.append(Vector2(c.x + 78, o.y + CELL.y))
				draw_colored_polygon(arch, Color(pal.fog, 0.13))
				draw_polyline(arch, col, 6.0)
				draw_arc(Vector2(c.x, o.y + 150), 30, 0, TAU, 14, col, 3.0)
				draw_arc(Vector2(c.x - 30, o.y + 210), 22, 0, TAU, 12, col, 3.0)
				draw_arc(Vector2(c.x + 30, o.y + 210), 22, 0, TAU, 12, col, 3.0)
				draw_line(Vector2(c.x, o.y + 232), Vector2(c.x, o.y + CELL.y), col, 3.0)
			draw_arc(Vector2(o.x, o.y), 250, 0.15, 1.25, 14, _col(t, 0.08), 5.0)
			draw_arc(Vector2(o.x + CELL.x, o.y), 250, PI - 1.25, PI - 0.15, 14, _col(t, 0.08), 5.0)
		1:  # round columns, bow-fronted shelves of books, lights on sagging chains
			var col2 := _col(t, -0.06)
			draw_rect(Rect2(o.x - 20, o.y, 40, CELL.y), col2)
			draw_line(Vector2(o.x - 11, o.y), Vector2(o.x - 11, o.y + CELL.y), col2.lightened(0.14), 2.0)
			draw_colored_polygon(Style.arc_pts(Vector2(o.x, o.y + 4), 36, 16, 0, PI, 10), col2.darkened(0.12))
			draw_colored_polygon(Style.ell(Vector2(o.x, o.y + 4), 30, 6, 12), col2.lightened(0.08))
			var y := o.y + rng.randf_range(150.0, 300.0)
			var x0 := o.x + 50.0
			var x1 := o.x + CELL.x - 50.0
			var mid := (x0 + x1) * 0.5
			var x := x0 + 14.0
			while x < x1 - 24.0:
				var bw := rng.randf_range(10.0, 20.0)
				var bh := rng.randf_range(40.0, 86.0)
				var u := (x - x0) / (x1 - x0)
				var base := Vector2(x, y - sin(u * PI) * 18.0)
				var bc := _col(t, rng.randf_range(-0.06, 0.12))
				if rng.randf() < 0.14:
					bc = bc.lerp(Color(0.62, 0.3, 0.36), 0.45)
				var roll := rng.randf()
				if roll < 0.14:  # leaning
					draw_set_transform(base + Vector2(bw, 0), -0.32)
					_book(bw, bh, bc)
					draw_set_transform(Vector2.ZERO)
					x += bw + 16.0
				elif roll < 0.24:  # a flat stack with a scroll on top
					for k in 3:
						draw_colored_polygon(Style.ell(base + Vector2(18, -6 - k * 11), 20 - k * 2, 6, 10), bc.lightened(k * 0.06))
					Style.spiral(self, base + Vector2(18, -44), 8.0, 2.0, bc.lightened(0.35), 2.0)
					x += 40.0
				elif roll < 0.32:
					x += bw
				else:
					draw_set_transform(base, rng.randf_range(-0.03, 0.03))
					_book(bw, bh, bc)
					draw_set_transform(Vector2.ZERO)
					x += bw + 1.5
			var shelf := Style.arc_pts(Vector2(mid, y), (x1 - x0) * 0.5, 20, PI, TAU, 14)
			shelf.append(Vector2(x1, y + 14))
			shelf.append(Vector2(x0, y + 14))
			draw_colored_polygon(shelf, _col(t, 0.12))
			draw_colored_polygon(Style.arc_pts(Vector2(mid, y + 14), (x1 - x0) * 0.5, 46, 0, PI, 14), _col(t, 0.22))
			var a := Vector2(o.x, o.y + 40)
			var b := Vector2(o.x + CELL.x, o.y + 40)
			var chain := PackedVector2Array()
			for k in 13:
				chain.append(a.lerp(b, k / 12.0) + Vector2(0, sin(k / 12.0 * PI) * 44.0))
			draw_polyline(chain, _col(t, 0.05), 1.5, true)
			for k in [3, 6, 9]:
				var lp: Vector2 = chain[k] + Vector2(0, 14)
				_glow(lp, 46.0, pal.glow, 0.5)
				draw_colored_polygon(Style.ell(lp, 5, 8, 10), Color(0.86, 0.93, 1.0, 0.9))
		2:  # swagged drapes, a hanging lamp, a spiral stair or a leaning ladder
			var col3 := _col(t)
			var roll2 := rng.randf()
			if roll2 < 0.4:
				var dr := PackedVector2Array()
				for k in 17:
					dr.append(Vector2(o.x + CELL.x * k / 16.0, o.y + 30 + sin(k / 16.0 * PI) * 90.0))
				dr.append(Vector2(o.x + CELL.x, o.y))
				dr.append(Vector2(o.x, o.y))
				draw_colored_polygon(dr, col3.lerp(Color(0.4, 0.16, 0.3), 0.35))
			elif roll2 < 0.65:
				var p := o + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.3, 0.7)) * CELL
				draw_line(Vector2(p.x, o.y), p + Vector2(0, -40), col3, 3.0)
				draw_colored_polygon(Style.arc_pts(p, 38, 46, PI, TAU, 14), col3)
				draw_colored_polygon(Style.ell(p, 38, 5, 14), Color(pal.accent, 0.9))
				_glow(p + Vector2(0, 30), 190.0, pal.accent, 0.4)
			elif roll2 < 0.82:
				var px := o.x + rng.randf_range(0.3, 0.7) * CELL.x
				draw_line(Vector2(px, o.y), Vector2(px, o.y + CELL.y), col3, 5.0)
				for k in 17:
					var yy := o.y + k * CELL.y / 17.0
					var reach := cos(k * 0.75) * 60.0
					if absf(reach) < 8.0:
						continue  # step seen edge-on: nothing to fill
					var tip := Vector2(px + reach, yy + sin(k * 0.75) * 6.0)
					draw_colored_polygon(PackedVector2Array([Vector2(px, yy - 3), tip + Vector2(0, -4), tip + Vector2(0, 5), Vector2(px, yy + 6)]),
						col3.lightened(0.06 * sin(k * 0.75)))
			else:
				var lx := o.x + rng.randf_range(0.2, 0.7) * CELL.x
				draw_line(Vector2(lx, o.y + CELL.y), Vector2(lx + 70, o.y), col3, 3.0)
				draw_line(Vector2(lx + 26, o.y + CELL.y), Vector2(lx + 96, o.y), col3, 3.0)
				for k in 14:
					var f := k / 14.0
					draw_line(Vector2(lx + 70 * f, o.y + CELL.y * (1.0 - f)), Vector2(lx + 26 + 70 * f, o.y + CELL.y * (1.0 - f)), col3, 2.5)


func _book(w: float, h: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, -h + 3), Vector2(w * 0.5, -h), Vector2(w, -h + 3), Vector2(w, 0)]), col)
	draw_line(Vector2(2, -h * 0.78), Vector2(w - 2, -h * 0.78), col.lightened(0.3), 1.5)


# ------------------------------------------------------------------- works

func _works(o: Vector2, rng: RandomNumberGenerator, cx: int) -> void:
	var t := Style.WORKS
	var pal: Dictionary = Style.PALETTES[t]
	var angles := [0.0, PI * 0.5, 0.5, -0.5, 1.0]
	match kind:
		0:  # a pale lattice of pencils and rulers
			for i in 5:
				var c := o + Vector2(rng.randf(), rng.randf()) * CELL
				var a: float = angles[rng.randi() % 5] + rng.randf_range(-0.06, 0.06)
				var d := Vector2.from_angle(a) * rng.randf_range(160.0, 420.0) * 0.5
				var col := _col(t, rng.randf_range(-0.05, 0.1))
				draw_line(c - d, c + d, col, rng.randf_range(10.0, 20.0))
				draw_line(c - d, c + d, col.lightened(0.18), 2.0)
		1:  # heavier beams lashed with twine, glass orbs hanging between them
			for i in 2:
				var c2 := o + Vector2(rng.randf(), rng.randf()) * CELL
				var a2: float = angles[rng.randi() % 4]
				var dir := Vector2.from_angle(a2)
				var l := rng.randf_range(300.0, 600.0)
				var col2 := _col(t)
				draw_line(c2 - dir * l * 0.5, c2 + dir * l * 0.5, col2, 22.0)
				draw_line(c2 - dir * l * 0.5 + dir.orthogonal() * 8, c2 + dir * l * 0.5 + dir.orthogonal() * 8, col2.lightened(0.2), 2.0)
				for k in [-0.3, 0.25]:
					draw_line(c2 + dir * l * k - dir.orthogonal() * 13, c2 + dir * l * k + dir.orthogonal() * 13, _col(t, -0.2), 5.0)
			if rng.randf() < 0.6:
				var op := o + Vector2(rng.randf(), rng.randf()) * CELL
				draw_line(op + Vector2(0, -70), op, _col(t), 1.5)
				_orb(op, 12.0, t)
		2:  # the great ink pipes, ink pots and clusters of glowing nibs
			if posmod(cx, 3) == 0:
				var col3 := _col(t, -0.2)
				draw_rect(Rect2(o.x + 120, o.y, 170, CELL.y), col3)
				draw_rect(Rect2(o.x + 120, o.y, 50, CELL.y), Color(pal.fog, 0.12))
				for k in 4:
					var ry := o.y + 20 + k * CELL.y / 4.0
					draw_rect(Rect2(o.x + 112, ry, 186, 12), Color(0.36, 0.25, 0.3))
					draw_line(Vector2(o.x + 112, ry + 1), Vector2(o.x + 298, ry + 1), Color(0.6, 0.45, 0.5), 1.5)
			elif rng.randf() < 0.5:
				var p := o + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.3, 0.8)) * CELL
				var plank := _col(t)
				draw_rect(Rect2(p.x - 90, p.y, 180, 14), plank)
				draw_colored_polygon(Style.ell(p + Vector2(-50, -24), 20, 25, 14), plank)
				_glow(p + Vector2(30, -22), 100.0, pal.accent, 0.55)
				for k in 7:
					var a3 := -PI * 0.5 + (k - 3) * 0.33
					var l2 := 24.0 + (k % 3) * 11.0
					var d2 := Vector2.from_angle(a3)
					var q := p + Vector2(30, 0)
					var nib := PackedVector2Array([q - d2.orthogonal() * 5, q + d2 * l2 * 0.6 - d2.orthogonal() * 6, q + d2 * l2,
						q + d2 * l2 * 0.6 + d2.orthogonal() * 6, q + d2.orthogonal() * 5])
					draw_colored_polygon(nib, Color(0.95, 0.82, 0.98))
					draw_polyline(nib, pal.dark, 1.5)
