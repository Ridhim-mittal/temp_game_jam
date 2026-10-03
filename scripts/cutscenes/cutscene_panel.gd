extends Control
## One comic panel: draws its art from a list of simple draw ops and types
## out its caption boxes. Created and driven by cutscene.gd.
## Positions in ops are 0..1 across the panel; sizes are relative to a
## 300 px tall panel so art scales with the panel.

const INK := Color(0.06, 0.05, 0.07)
const PAL := {
	"cream": Color(0.93, 0.88, 0.78),
	"gray": Color(0.74, 0.73, 0.71),
	"gray_dark": Color(0.55, 0.54, 0.53),
	"black": Color(0.04, 0.04, 0.06),
	"night": Color(0.09, 0.1, 0.17),
	"white": Color(0.98, 0.98, 0.96),
	"ink": Color(0.06, 0.05, 0.07),
	"red": Color(0.8, 0.27, 0.2),
	"blue": Color(0.25, 0.42, 0.7),
	"green": Color(0.35, 0.62, 0.4),
	"yellow": Color(1.0, 0.82, 0.15),
	"wood": Color(0.42, 0.28, 0.18),
	"wood_dark": Color(0.3, 0.19, 0.12),
	"shadow": Color(0.05, 0.05, 0.08, 0.8),
	"line": Color(0.88, 0.88, 0.92),
}

var spec := {}
var t := 0.0
var cps := 48.0
var _labels: Array = []
var _shown := 0.0
var _total := 0
var _font: Font


func setup(s: Dictionary, chars_per_second: float) -> void:
	spec = s
	cps = chars_per_second
	_font = ThemeDB.fallback_font
	var r: Array = s["rect"]
	position = Vector2(r[0], r[1])
	size = Vector2(r[2], r[3])
	pivot_offset = size * 0.5
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in s.get("captions", []):
		_add_caption(c)
	_apply_text()


func is_typing() -> bool:
	return _shown < float(_total)


func finish_typing() -> void:
	_shown = float(_total)
	_apply_text()


func _process(delta: float) -> void:
	t += delta
	if is_typing():
		_shown = minf(_shown + cps * delta, float(_total))
		_apply_text()
	queue_redraw()


# ---------------------------------------------------------------- captions

func _add_caption(c: Dictionary) -> void:
	var who: String = c.get("who", "writer")
	var sb := StyleBoxFlat.new()
	var fg := INK
	sb.bg_color = Color(1.0, 0.93, 0.6)
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_content_margin_all(10)
	match who:
		"vesper":
			sb.bg_color = Color(1, 1, 1)
			sb.set_corner_radius_all(18)
		"shade":
			sb.bg_color = Color(0.02, 0.02, 0.03)
			sb.border_color = Color(0.95, 0.95, 0.98)
			fg = Color(0.95, 0.95, 0.98)
		"margin":
			sb.bg_color = Color(0.13, 0.13, 0.17)
			sb.border_color = Color(0.75, 0.75, 0.8)
			fg = Color(0.92, 0.92, 0.95)
		"shaky":
			sb.bg_color = Color(0.97, 0.86, 0.8)
			fg = Color(0.5, 0.08, 0.08)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = c["text"]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(size.x * float(c.get("w", 0.6)) - 26.0, 0)
	label.add_theme_color_override("font_color", fg)
	label.add_theme_font_size_override("font_size", int(c.get("size", 20)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	box.position = Vector2(size.x * float(c.get("x", 0.03)), size.y * float(c.get("y", 0.05)))
	if who == "shaky":
		box.rotation = -0.03
	add_child(box)
	_labels.append(label)
	_total += label.text.length()


func _apply_text() -> void:
	var left := int(_shown)
	var all := not is_typing()
	for l in _labels:
		var n: int = l.text.length()
		l.visible_characters = -1 if all else clampi(left, 0, n)
		l.get_parent().modulate.a = 1.0 if (all or left > 0) else 0.0
		left -= n


# ------------------------------------------------------------------- art

func _draw() -> void:
	for op in spec.get("draw", []):
		draw_set_transform(Vector2.ZERO)
		_op(op)
	draw_set_transform(Vector2.ZERO)
	var border: Color = _col(spec.get("border", "ink"))
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), border, false, 6.0)


func _col(c) -> Color:
	if c is Color:
		return c
	return PAL.get(c, INK)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _u() -> float:
	return size.y / 300.0


func _op(op: Array) -> void:
	var W := size.x
	var H := size.y
	var u := _u()
	match op[0]:
		"bg":
			draw_rect(Rect2(Vector2.ZERO, size), _col(op[1]))
		"rect":  # x y w h color
			draw_rect(Rect2(_p(op[1], op[2]), _p(op[3], op[4])), _col(op[5]))
		"poly":  # color [x y x y ...]
			var pts := PackedVector2Array()
			var a: Array = op[2]
			for i in range(0, a.size(), 2):
				pts.append(_p(a[i], a[i + 1]))
			draw_colored_polygon(pts, _col(op[1]))
		"line":  # x0 y0 x1 y1 color width
			draw_line(_p(op[1], op[2]), _p(op[3], op[4]), _col(op[5]), float(op[6]) * u, true)
		"circle":  # x y r color
			draw_circle(_p(op[1], op[2]), float(op[3]) * u, _col(op[4]))
		"ground":  # y fill line
			draw_rect(Rect2(0, op[1] * H, W, H), _col(op[2]))
			draw_line(Vector2(0, op[1] * H), Vector2(W, op[1] * H), _col(op[3]), 3.0 * u)
		"block":  # x y w h color mode
			_block(Rect2(_p(op[1], op[2]), _p(op[3], op[4])), _col(op[5]), op[6])
		"beam":  # x0 y0 x1 y1 halfwidth kind
			_beam(_p(op[1], op[2]), _p(op[3], op[4]), float(op[5]) * W, op[6])
		"lamp":  # x y angle
			_lamp(_p(op[1], op[2]), float(op[3]), u)
		"glow":  # x y r color
			var gc: Color = _col(op[4])
			for i in 7:
				draw_circle(_p(op[1], op[2]), float(op[3]) * u * (1.0 - i / 7.0) * (1.0 + 0.04 * sin(t * 5.0)), Color(gc, 0.09))
		"vesper":  # x y scale pose flip
			_vesper(_p(op[1], op[2]), float(op[3]) * u, op[4], float(op[5]))
		"shade":  # x y scale [reach_x reach_y]
			if op.size() > 5:
				_shade_arm(_p(op[1], op[2]) + Vector2(0, -42.0 * float(op[3]) * u), _p(op[4], op[5]), float(op[3]) * u)
			_shade(_p(op[1], op[2]), float(op[3]) * u)
		"eyes":  # x y w h count seed
			_eyes(Rect2(_p(op[1], op[2]), _p(op[3], op[4])), int(op[5]), int(op[6]), u)
		"scribble":  # x y scale seed color
			_scribble(_p(op[1], op[2]), float(op[3]) * u, int(op[4]), _col(op[5]))
		"text":  # x y size string color rotation outline
			_text(_p(op[1], op[2]), int(float(op[3]) * u), op[4], _col(op[5]), float(op[6]), _col(op[7]))
		"cross":  # x y size
			var c := _p(op[1], op[2])
			var s: float = float(op[3]) * u
			var red := Color(0.78, 0.1, 0.1)
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), red, 7.0 * u, true)
			draw_line(c + Vector2(s, -s), c + Vector2(-s, s * 0.9), red, 7.0 * u, true)
		"paper":  # x y scale rotation
			_paper(_p(op[1], op[2]), float(op[3]) * u, float(op[4]))
		"desklamp":  # x y scale
			_desklamp(_p(op[1], op[2]), float(op[3]) * u)
		"hand":  # x y scale
			_hand(_p(op[1], op[2]), float(op[3]) * u)
		"photo":  # x y scale rotation
			_photo(_p(op[1], op[2]), float(op[3]) * u, float(op[4]))
		"pencil":  # x y length rotation
			_pencil(_p(op[1], op[2]), float(op[3]) * u, float(op[4]))


func _outline(pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, color, width, true)


func _block(r: Rect2, color: Color, mode: String) -> void:
	if mode == "ghost":
		var g := Color(0.35, 0.35, 0.38, 0.8)
		var a := r.position
		var b := r.position + Vector2(r.size.x, 0)
		var c := r.end
		var d := r.position + Vector2(0, r.size.y)
		for seg in [[a, b], [b, c], [c, d], [d, a]]:
			draw_dashed_line(seg[0], seg[1], g, 2.0, 8.0)
		return
	draw_rect(r, color)
	draw_rect(r, INK, false, 3.0)


func _beam(a: Vector2, b: Vector2, hw: float, kind: String) -> void:
	var perp := (b - a).normalized().orthogonal()
	var flick := 0.03 * sin(t * 9.0)
	var col := Color(1.0, 0.9, 0.45, 0.42 + flick)
	if kind == "burn":
		col = Color(1.0, 0.42, 0.25, 0.5 + flick * 3.0)
	elif kind == "cold":
		col = Color(0.9, 0.95, 1.0, 0.3 + flick)
	draw_colored_polygon(PackedVector2Array([a - perp * 5.0, a + perp * 5.0, b + perp * hw, b - perp * hw]), col)
	draw_colored_polygon(PackedVector2Array([a - perp * 3.0, a + perp * 3.0, b + perp * hw * 0.55, b - perp * hw * 0.55]), Color(col, col.a * 0.5))


func _lamp(p: Vector2, angle: float, u: float) -> void:
	draw_set_transform(p, angle, Vector2(u, u))
	var shade := PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(22, 22), Vector2(-22, 22)])
	draw_colored_polygon(shade, Color(0.3, 0.32, 0.36))
	_outline(shade, INK, 2.5)
	draw_circle(Vector2(0, 24), 7.0, Color(1.0, 0.93, 0.6))
	draw_set_transform(Vector2.ZERO)


func _vesper(p: Vector2, sc: float, pose: String, flip: float) -> void:
	# Matches scripts/player/player_visual.gd: dark cloak, pale mask, ember scarf.
	var cloak_c := Color(0.1, 0.09, 0.2)
	var rim_c := Color(0.3, 0.33, 0.62)
	var mask_c := Color(0.98, 0.96, 0.9)
	var scarf_c := Color(1.0, 0.58, 0.14)
	var line_c := INK
	var fill := true
	var rot := 0.0
	var at := p
	match pose:
		"down":
			rot = flip * PI * 0.5
			at += Vector2(0, -14.0 * sc)
		"crawl":
			rot = flip * (1.1 + 0.05 * sin(t * 11.0))
			at += Vector2(sin(t * 11.0) * 1.5 * sc, -10.0 * sc)
		"torn":
			cloak_c = Color(0.16, 0.16, 0.3)
			scarf_c = Color(0.8, 0.42, 0.12)
			line_c = PAL["line"]
		"ghost":
			fill = false
			line_c = Color(0.8, 0.8, 0.86, 0.75)
		"run":
			rot = flip * 0.25
			line_c = PAL["line"]
	draw_set_transform(at, rot, Vector2(flip * sc, sc))
	var h := Vector2(0, -15)
	var cloak := PackedVector2Array([h + Vector2(-10, -20), h + Vector2(10, -20), h + Vector2(13, 0),
		h + Vector2(6, 3), h + Vector2(0, 0), h + Vector2(-7, 3), h + Vector2(-14, 0)])
	if pose == "torn" or pose == "ghost":
		cloak = PackedVector2Array([h + Vector2(-10, -20), h + Vector2(10, -20), h + Vector2(13, 0),
			h + Vector2(8, -6), h + Vector2(4, 3), h + Vector2(0, -5), h + Vector2(-5, 3),
			h + Vector2(-9, -4), h + Vector2(-14, 1)])
	var mask := _round_rect(Rect2(-11, -61, 23, 23), 7.0)
	var leg_c := INK if line_c == INK else line_c
	for sx in [-3.0, 3.0]:
		draw_line(Vector2(sx, -15), Vector2(sx, 0), leg_c, 4.0, true)
		draw_circle(Vector2(sx + 1.5, 0), 3.0, leg_c)
	if fill:
		var tail := PackedVector2Array([h + Vector2(-6, -21)])
		for i in range(1, 6):
			tail.append(h + Vector2(-6.0 - i * 4.0, -21.0 + sin(t * 8.0 - i * 0.9) * i * 0.5 + i * 1.3))
		for i in tail.size() - 1:
			draw_line(tail[i], tail[i + 1], scarf_c, lerpf(6.0, 2.5, i / 4.0), true)
		draw_colored_polygon(cloak, cloak_c)
		draw_colored_polygon(PackedVector2Array([h + Vector2(6, -20), h + Vector2(10, -20),
			h + Vector2(13, 0), h + Vector2(8, 1.5)]), rim_c)
	_outline(cloak, line_c, 2.0)
	if fill:
		draw_colored_polygon(_round_rect(Rect2(-11, -39, 22, 6), 3.0), scarf_c)
		draw_colored_polygon(mask, mask_c)
		var eye := PackedVector2Array()
		for i in 12:
			eye.append(Vector2(5.5 + cos(TAU * i / 12.0) * 3.0, -50.0 + sin(TAU * i / 12.0) * 5.5))
		draw_colored_polygon(eye, INK)
	else:
		draw_line(Vector2(2.5, -54), Vector2(8.5, -46), line_c, 1.5)
		draw_line(Vector2(8.5, -54), Vector2(2.5, -46), line_c, 1.5)
	_outline(mask, line_c, 2.0)
	if pose == "torn":
		draw_circle(Vector2(-5, -27), 3.5, INK)
		draw_circle(Vector2(5, -20), 2.5, INK)
		draw_circle(Vector2(-6, -54), 2.5, INK)
	if pose == "wave":
		var hand := Vector2(27, -58.0 + sin(t * 8.0) * 5.0)
		draw_line(Vector2(10, -30), hand, INK, 3.0, true)
		draw_circle(hand, 3.5, mask_c)
		draw_arc(hand, 3.5, 0, TAU, 12, INK, 1.5)
	draw_set_transform(Vector2.ZERO)


func _round_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - radius, radius), r.end - Vector2(radius, radius),
		r.position + Vector2(radius, r.size.y - radius), r.position + Vector2(radius, radius)]
	for c in 4:
		for i in 5:
			var a := -PI * 0.5 + (c + i / 4.0) * PI * 0.5
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * radius)
	return pts


func _shade(p: Vector2, sc: float) -> void:
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	var dark := Color(0.02, 0.02, 0.03)
	var rim := Color(0.85, 0.85, 0.92, 0.55)
	for i in 5:
		var x := -24.0 + i * 12.0
		var pts := PackedVector2Array()
		for s in 6:
			pts.append(Vector2(x + sin(t * 3.0 + i * 1.9 + s * 0.9) * 5.0, -18.0 + s * 5.0))
		draw_polyline(pts, rim, 7.5, true)
		draw_polyline(pts, dark, 6.0, true)
	var body := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var r := 34.0 + sin(t * 2.5 + i * 1.3) * 3.5 + sin(i * 2.7) * 3.0
		body.append(Vector2(cos(a) * r * 0.8, -46.0 + sin(a) * r))
	draw_colored_polygon(body, dark)
	_outline(body, rim, 1.5)
	for sx in [-1.0, 1.0]:
		var e := PackedVector2Array([Vector2(sx * 5, -54), Vector2(sx * 17, -60), Vector2(sx * 15, -50)])
		draw_colored_polygon(e, Color(0.97, 0.97, 1.0))
	draw_set_transform(Vector2.ZERO)


func _shade_arm(from: Vector2, to: Vector2, sc: float) -> void:
	var pts := PackedVector2Array()
	var perp := (to - from).normalized().orthogonal()
	for i in 13:
		var k := i / 12.0
		pts.append(from.lerp(to, k) + perp * sin(k * PI * 2.0 + t * 3.0) * 7.0 * sc * (1.0 - k))
	draw_polyline(pts, Color(0.85, 0.85, 0.92, 0.55), 9.5 * sc, true)
	draw_polyline(pts, Color(0.02, 0.02, 0.03), 7.0 * sc, true)
	for a in [-0.6, 0.0, 0.6]:
		var d := (to - from).normalized().rotated(a) * 11.0 * sc
		draw_line(to, to + d, Color(0.85, 0.85, 0.92, 0.55), 4.5 * sc, true)
		draw_line(to, to + d, Color(0.02, 0.02, 0.03), 3.0 * sc, true)


func _eyes(r: Rect2, count: int, rng_seed: int, u: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in count:
		var c := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var s := rng.randf_range(0.7, 1.3) * u
		var phase := rng.randf() * 4.0
		if fmod(t + phase, 4.0) < 0.14:
			continue
		draw_circle(c + Vector2(-5.0 * s, 0), 2.8 * s, Color(0.97, 0.97, 1.0))
		draw_circle(c + Vector2(5.0 * s, 0), 2.8 * s, Color(0.97, 0.97, 1.0))


func _scribble(p: Vector2, sc: float, rng_seed: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var pts := PackedVector2Array()
	for i in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, 24.0)
		pts.append(p + Vector2(cos(a) * r, sin(a) * r * 0.8 + sin(t * 6.0 + i) * 1.2) * sc)
	draw_polyline(pts, color, 2.2 * sc, true)
	for sx in [-1.0, 1.0]:
		draw_circle(p + Vector2(sx * 7.0, -3.0) * sc, 4.5 * sc, Color(0.97, 0.97, 1.0))
		draw_circle(p + Vector2(sx * 7.0 + 1.0, -3.0) * sc, 2.0 * sc, INK)


func _text(p: Vector2, fs: int, s: String, color: Color, rot: float, outline: Color) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	var sz := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(-sz.x * 0.5, sz.y * 0.3)
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(fs / 4, 4), outline)
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	draw_set_transform(Vector2.ZERO)


func _paper(p: Vector2, sc: float, rot: float) -> void:
	draw_set_transform(p, rot, Vector2(sc, sc))
	var pts := PackedVector2Array([Vector2(-30, -38), Vector2(-4, -42), Vector2(28, -36), Vector2(33, -8),
		Vector2(29, 36), Vector2(2, 40), Vector2(-31, 37), Vector2(-34, 4)])
	draw_colored_polygon(pts, Color(0.9, 0.87, 0.8))
	_outline(pts, INK, 2.0)
	var crease := Color(0.45, 0.42, 0.38)
	draw_line(Vector2(-30, -38), Vector2(8, 2), crease, 1.5)
	draw_line(Vector2(8, 2), Vector2(29, 36), crease, 1.5)
	draw_line(Vector2(33, -8), Vector2(8, 2), crease, 1.5)
	draw_line(Vector2(8, 2), Vector2(-31, 37), crease, 1.5)
	draw_rect(Rect2(-22, -28, 20, 16), INK, false, 1.5)
	draw_rect(Rect2(4, -28, 18, 16), INK, false, 1.5)
	draw_rect(Rect2(-22, -6, 44, 30), INK, false, 1.5)
	draw_set_transform(Vector2.ZERO)


func _desklamp(p: Vector2, sc: float) -> void:
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	var metal := Color(0.32, 0.34, 0.4)
	draw_rect(Rect2(-22, -6, 44, 6), metal)
	draw_polyline(PackedVector2Array([Vector2(0, -6), Vector2(-26, -70), Vector2(20, -122)]), INK, 7.0, true)
	draw_polyline(PackedVector2Array([Vector2(0, -6), Vector2(-26, -70), Vector2(20, -122)]), metal, 4.0, true)
	var head := PackedVector2Array([Vector2(14, -132), Vector2(30, -120), Vector2(58, -106), Vector2(30, -84)])
	draw_colored_polygon(head, metal)
	_outline(head, INK, 2.0)
	draw_circle(Vector2(45, -94), 7.0, Color(1.0, 0.95, 0.7))
	draw_set_transform(Vector2.ZERO)


func _hand(p: Vector2, sc: float) -> void:
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	var skin := Color(0.85, 0.66, 0.52)
	var sleeve := PackedVector2Array([Vector2(60, -70), Vector2(140, -130), Vector2(170, -90), Vector2(84, -38)])
	draw_colored_polygon(sleeve, Color(0.3, 0.33, 0.4))
	_outline(sleeve, INK, 2.0)
	var palm := PackedVector2Array([Vector2(22, -40), Vector2(48, -66), Vector2(72, -62), Vector2(86, -40),
		Vector2(66, -18), Vector2(36, -14)])
	draw_colored_polygon(palm, skin)
	_outline(palm, INK, 2.0)
	var tip := Vector2(0, 0) + Vector2(sin(t * 7.0) * 1.5, 0)
	draw_line(tip, Vector2(58, -62), INK, 7.0, true)
	draw_line(tip + Vector2(6, -6), Vector2(58, -62), Color(0.9, 0.75, 0.2), 4.0, true)
	draw_set_transform(Vector2.ZERO)


func _photo(p: Vector2, sc: float, rot: float) -> void:
	draw_set_transform(p, rot, Vector2(sc, sc))
	draw_rect(Rect2(-34, -44, 68, 88), Color(0.97, 0.96, 0.92))
	draw_rect(Rect2(-34, -44, 68, 88), INK, false, 2.0)
	draw_rect(Rect2(-27, -37, 54, 62), Color(0.72, 0.6, 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(-15, 25), Vector2(-12, -2), Vector2(12, -2), Vector2(15, 25)]), Color(0.35, 0.27, 0.2))
	draw_circle(Vector2(0, -14), 11.0, Color(0.35, 0.27, 0.2))
	draw_circle(Vector2(0, -44), 4.0, Color(0.8, 0.15, 0.15))
	draw_set_transform(Vector2.ZERO)


func _pencil(p: Vector2, length: float, rot: float) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	var h := length * 0.07
	draw_rect(Rect2(0, -h, length, h * 2.0), Color(0.95, 0.75, 0.2))
	draw_rect(Rect2(0, -h, length, h * 2.0), INK, false, 2.0)
	draw_rect(Rect2(-length * 0.1, -h, length * 0.1, h * 2.0), Color(0.9, 0.5, 0.55))
	var tip := PackedVector2Array([Vector2(length, -h), Vector2(length * 1.14, 0), Vector2(length, h)])
	draw_colored_polygon(tip, Color(0.9, 0.8, 0.65))
	_outline(tip, INK, 2.0)
	draw_set_transform(Vector2.ZERO)
