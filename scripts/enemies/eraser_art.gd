extends RefCounted
## SHADE'S ERASER, drawn in code from the team's "Animated SCARY ERASER Boss"
## sheet. Every Eraser in the game draws through here, so they all look the
## same: the Long Drop's chase (shade_eraser.gd), the 2D mini-boss in Shade's
## waves (eraser.gd), the Rubbing Room boss in the Gutter (eraser_3d.gd, the
## 2D art on a billboard), the opening book's panel and the fall into the
## Margins.
##
## A tall block eraser: a worn pink rubber top with a chipped crown, a torn tan
## cardboard sleeve with a blue band down one side lettered "SHADE'S ERASER",
## a skull of a face printed on the sleeve (angry white eyes under heavy brows,
## a nose hole, a gaping maw of jagged teeth), pink rubber underneath, thin
## black scribbled arms ending in hooked claws. Low colour, thick ink outlines,
## and it never keeps still: it re-jitters 24 times a second.
##
##   EraserArt.draw(self, Transform2D(0, Vector2.ONE * 0.3, 0, feet), {"time": t, "rubbing": 1.0})
##
## Drawn in sheet units (the block is W x H = 210 x 330, origin = the middle of
## its base, up = -y); `xf` places and scales it. Shapes go out as one draw call
## (InkBatch), then the brand is lettered on top. It leaves `ci`'s transform at
## identity. Pose keys (all optional, 0..1 unless noted):
##   time      seconds (drives the jitter, the scrub and the breathing)
##   rubbing   scrubbing side to side, tilted
##   roar      the maw wide open
##   lunge     leaning into a charge          windup  leaning back, arms up, eyes lit
##   tired     sagging, dizzy spiral eyes, tongue out, a weak-spot marker
##   rage      the eyes burn red              heading 1 / -1: the way it leans
##   jitter    how hard it shakes (default 1) side    true: the side / attack view
##   brand     false: no lettering            alpha   0..1
##   trail     how far the side view's streaks and dust reach back (default 1)
##   seed      int, so two Erasers don't shake in step

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.08)
const PINK := Color(0.88, 0.38, 0.44)
const PINK_DARK := Color(0.62, 0.2, 0.3)
const PINK_LIGHT := Color(0.97, 0.6, 0.62)
const TAN := Color(0.83, 0.69, 0.5)
const TAN_DARK := Color(0.56, 0.42, 0.29)
const BLUE := Color(0.27, 0.42, 0.74)
const BLUE_DARK := Color(0.16, 0.26, 0.5)
const BONE := Color(0.97, 0.95, 0.9)
const MAW := Color(0.12, 0.04, 0.06)
const RED := Color(1.0, 0.22, 0.16)
const DANGER := Color(1.0, 0.86, 0.2)
const DUST := Color(0.72, 0.72, 0.76)
const W := 210.0
const H := 330.0

static var _batch := InkBatch.new()
static var _out: InkBatch  # where shapes go: _batch, or the caller's (draw_into())
static var _rng := RandomNumberGenerator.new()
static var _tint := Callable()
static var _alpha := 1.0
static var _time := 0.0
static var _j := 1.0


static func draw(ci: CanvasItem, xf: Transform2D, p := {}, tint := Callable()) -> void:
	_out = _batch
	_tint = tint
	_alpha = float(p.get("alpha", 1.0))
	_time = float(p.get("time", 0.0))
	_rng.seed = int(_time * 24.0) * 7 + 13 + int(p.get("seed", 0)) * 101
	var text_xf: Transform2D
	if p.get("side", false):
		text_xf = _side(xf, p)
	else:
		text_xf = _front(xf, p)
	_batch.draw_set_transform_matrix(Transform2D.IDENTITY)
	_batch.flush(ci)
	# the brand, lettered down the band (text can't go through the batch); too
	# small to read, it's left out
	if p.get("brand", true) and xf.get_scale().y * H > 130.0:
		ci.draw_set_transform_matrix(text_xf)
		var bone := _c(BONE)
		if p.get("side", false):
			ci.draw_string(FONT, Vector2(0, 0), "SHADE'S", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, bone)
		else:
			ci.draw_string(FONT, Vector2(0, 8), "SHADE'S", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, bone)
			ci.draw_string(FONT, Vector2(0, 30), "ERASER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, bone)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The shapes only (no lettering), into the caller's own InkBatch, on top of
## its current transform: for a small Eraser inside a bigger batched picture
## (the fall into the Margins). `tint` maps every colour (greying, fading).
static func draw_into(batch: InkBatch, xf: Transform2D, p := {}, tint := Callable()) -> void:
	var base: Transform2D = batch._xf
	_out = batch
	_tint = tint
	_alpha = float(p.get("alpha", 1.0))
	_time = float(p.get("time", 0.0))
	_rng.seed = int(_time * 24.0) * 7 + 13 + int(p.get("seed", 0)) * 101
	if p.get("side", false):
		_side(base * xf, p)
	else:
		_front(base * xf, p)
	batch.draw_set_transform_matrix(base)
	_out = _batch


# --------------------------------------------------------------- front view

## Returns where the brand is lettered.
static func _front(xf: Transform2D, p: Dictionary) -> Transform2D:
	var rubbing := float(p.get("rubbing", 0.0))
	var lunge := float(p.get("lunge", 0.0))
	var windup := float(p.get("windup", 0.0))
	var tired := float(p.get("tired", 0.0))
	var heading := float(p.get("heading", 1.0))
	_j = float(p.get("jitter", 1.0)) * (1.0 + rubbing * 1.5 + windup * 1.2) * (1.0 - tired * 0.6)
	var w := W
	var h := H
	# the rub: a fast scrub side to side with a tilt; a lunge leans it in, a windup back
	var scrub := sin(_time * 22.0) * rubbing
	var tilt := scrub * 0.22 + heading * (lunge * 0.35 - windup * 0.2) + tired * 0.08 * sin(_time * 2.0)
	var shift := Vector2(scrub * 26.0, -absf(scrub) * 6.0)
	var shake := Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5)) * _j
	# crouched on a windup, slumped when tired, breathing otherwise
	var breathe := 0.012 * sin(_time * 3.0)
	var sy := 1.0 - windup * 0.08 - tired * (0.1 + 0.03 * sin(_time * 7.0)) + breathe
	var sx := 1.0 + windup * 0.05 + tired * 0.06 - breathe * 0.5
	var body := xf * Transform2D(tilt, Vector2(sx, sy), 0.0, shift + shake)
	_out.draw_set_transform_matrix(body)
	# arms behind the block, reaching
	for side: float in [-1.0, 1.0]:
		_arm(side, w, h, p)
	# bottom rubber
	var bot := _box(Rect2(-w * 0.42, -h * 0.24, w * 0.84, h * 0.24))
	_fill(bot, PINK)
	_fill(_box(Rect2(w * 0.18, -h * 0.24, w * 0.24, h * 0.24)), PINK_DARK)
	_outline(bot, 5.0)
	# top rubber: a worn crown with a chipped top edge
	var top := PackedVector2Array()
	var ty := -h
	var crown := 8
	top.append(Vector2(-w * 0.44, -h * 0.66))
	for i in crown + 1:
		var x := -w * 0.44 + w * 0.88 * i / crown
		var dip := (_chip(i) * 14.0 if i > 0 and i < crown else 0.0)
		top.append(Vector2(x + _rng.randf_range(-1, 1) * _j, ty + 10.0 + dip + absf(x) * 0.06))
	top.append(Vector2(w * 0.44, -h * 0.66))
	_fill(top, PINK)
	# its shaded right face and a pale worn patch
	_fill(PackedVector2Array([Vector2(w * 0.2, ty + 16), Vector2(w * 0.44, ty + 22), Vector2(w * 0.44, -h * 0.66), Vector2(w * 0.2, -h * 0.66)]), PINK_DARK)
	_fill(PackedVector2Array([Vector2(-w * 0.3, ty + 22), Vector2(-w * 0.08, ty + 18), Vector2(-w * 0.12, ty + 36), Vector2(-w * 0.32, ty + 40)]), PINK_LIGHT)
	# scuffs rubbed into the rubber
	for i in 3:
		var a := Vector2(-w * 0.3 + _chip(i + 140) * w * 0.5, ty + 44 + _chip(i + 150) * 30.0)
		_out.draw_line(a, a + Vector2(18, -4), _c(PINK_DARK), 2.0)
	_outline(top, 5.0)
	# the cardboard sleeve, torn along its top edge
	var sleeve := PackedVector2Array()
	var sy0 := -h * 0.74
	var sy1 := -h * 0.2
	sleeve.append(Vector2(-w * 0.5, sy1))
	var tears := 10
	for i in tears + 1:
		var x := -w * 0.5 + w * i / tears
		var tear := (_chip(i + 20) * 26.0 if i % 2 == 1 else _chip(i + 40) * 6.0)
		sleeve.append(Vector2(x + _rng.randf_range(-1, 1) * _j, sy0 + tear))
	sleeve.append(Vector2(w * 0.5, sy1))
	# the bottom edge torn too, with a flap hanging at the right
	for i in range(tears, -1, -1):
		var x := -w * 0.5 + w * i / tears
		var rip := _chip(i + 160) * 12.0 + (16.0 if i == 7 else 0.0)
		sleeve.append(Vector2(x + _rng.randf_range(-1, 1) * _j, sy1 + rip))
	_fill(sleeve, TAN)
	# shading on the sleeve's right
	_fill(PackedVector2Array([Vector2(w * 0.3, sy0 + 20), Vector2(w * 0.5, sy0 + 10), Vector2(w * 0.5, sy1), Vector2(w * 0.3, sy1 + 10)]), Color(TAN_DARK, 0.55))
	# the blue band down the left with the brand on it
	var band := PackedVector2Array([Vector2(-w * 0.5, sy0 + 8), Vector2(-w * 0.26, sy0 + 26), Vector2(-w * 0.24, sy1 - 6), Vector2(-w * 0.5, sy1)])
	_fill(band, BLUE)
	_fill(PackedVector2Array([Vector2(-w * 0.31, sy0 + 22), Vector2(-w * 0.26, sy0 + 26), Vector2(-w * 0.24, sy1 - 6), Vector2(-w * 0.3, sy1 - 4)]), BLUE_DARK)
	_outline(band, 3.0)
	_outline(sleeve, 5.0)
	# the face, printed on the sleeve: a skull
	_face(w, h, p)
	# tired: the weak spot shows (a pulsing marker over the crown) and stars circle it
	if tired > 0.0:
		var bob := sin(_time * 6.0) * 6.0
		_out.draw_circle(Vector2(0, ty - 34 + bob), 15.0, _c(Color(INK, tired)))
		_out.draw_circle(Vector2(0, ty - 34 + bob), 11.0, _c(Color(DANGER, tired)))
		for k in 3:
			var a := _time * 3.0 + TAU * k / 3.0
			_star(Vector2(cos(a) * w * 0.42, ty - 8 + sin(a) * 16.0), 9.0, tired)
	return body * Transform2D(-PI * 0.5, Vector2(-w * 0.36, sy1 - 14))


static func _face(w: float, h: float, p: Dictionary) -> void:
	var tired := float(p.get("tired", 0.0))
	var rage := clampf(float(p.get("rage", 0.0)) + float(p.get("windup", 0.0)) * 0.8, 0.0, 1.0)
	var roar := clampf(float(p.get("roar", 0.0)) + float(p.get("windup", 0.0)) * 0.6, 0.0, 1.0)
	var cy := -h * 0.47
	# deep sockets, then angry eyes under heavy brows
	for side: float in [-1.0, 1.0]:
		var ex := side * w * 0.17 + w * 0.03
		var socket := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			socket.append(Vector2(ex, cy - 32) + Vector2(cos(a) * 36.0, sin(a) * 29.0) + _wob(1.5))
		_fill(socket, Color(TAN_DARK, 0.9))
		# the skull's cheek hollow under the eye
		_fill(PackedVector2Array([Vector2(ex - side * 6.0, cy - 2), Vector2(ex + side * 30.0, cy - 8), Vector2(ex + side * 24.0, cy + 18), Vector2(ex + side * 4.0, cy + 10)]), Color(TAN_DARK, 0.6))
		if tired > 0.5:
			# dizzy: spirals for eyes, the brows gone slack
			var sp := PackedVector2Array()
			for i in 22:
				var t := i / 21.0
				var a := _time * 8.0 * side + t * TAU * 2.2
				sp.append(Vector2(ex, cy - 32) + Vector2(cos(a), sin(a) * 0.8) * (3.0 + 15.0 * t))
			_fill(_ellipse(Vector2(ex, cy - 32), 20.0, 16.0), BONE)
			_out.draw_polyline(sp, _c(INK), 3.0)
			_out.draw_line(Vector2(ex - 18, cy - 54), Vector2(ex + 18, cy - 56), _c(INK), 4.0)
			continue
		# the eye: an almond cut off by a brow slanting down to the nose
		var eye := PackedVector2Array()
		for i in 9:
			var a := PI + PI * i / 8.0
			eye.append(Vector2(ex, cy - 30) + Vector2(cos(a) * 26.0, sin(a) * 19.0))
		eye.append(Vector2(ex + 26.0, cy - 30))
		var brow_in := Vector2(ex - side * 27.0, cy - 30 - 4.0 + rage * 4.0)
		var brow_out := Vector2(ex + side * 27.0, cy - 30 - 27.0)
		var cut := PackedVector2Array()
		for q in eye:
			var t := (q.x - brow_in.x) / (brow_out.x - brow_in.x)
			var limit := lerpf(brow_in.y, brow_out.y, clampf(t, 0.0, 1.0))
			cut.append(Vector2(q.x, maxf(q.y, limit)))
		cut.append(Vector2(ex + 22.0, cy - 19))
		cut.append(Vector2(ex - 22.0, cy - 19))
		if rage > 0.0:  # a red glow round a burning eye
			_out.draw_circle(Vector2(ex, cy - 28), 30.0, _c(Color(RED, 0.25 * rage)))
		_fill(cut, BONE.lerp(Color(1.0, 0.5, 0.4), rage * 0.7))
		_outline(cut, 3.0)
		var pupil := Vector2(ex - side * 3.0, cy - 26) + Vector2(_rng.randf_range(-1, 1), 0)
		_out.draw_circle(pupil, 5.5 - rage * 1.5, _c(INK.lerp(RED, rage)))
		_out.draw_circle(pupil + Vector2(-1.5, -2.0), 1.6, _c(BONE))
		_out.draw_line(brow_in + Vector2(0, -2), brow_out + Vector2(0, -2), _c(INK), 7.0)
	# nose hole
	_fill(PackedVector2Array([Vector2(w * 0.03, cy - 10), Vector2(w * 0.03 - 9, cy + 6), Vector2(w * 0.03 + 9, cy + 6)]), INK)
	# the maw: wide, gaping, jagged teeth top and bottom (sags open when tired)
	var open := 0.55 + 0.45 * roar + 0.08 * sin(_time * 9.0) + tired * 0.2
	var mw := w * (0.7 - tired * 0.1)
	var mh := 54.0 + 44.0 * open
	var mc := Vector2(w * 0.03, cy + 30 + mh * 0.5)
	var maw := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		maw.append(mc + Vector2(cos(a) * mw * 0.5, sin(a) * mh * 0.5) + _wob(1.5))
	_fill(maw, MAW)
	var n := 9
	for i in n:
		var x := mc.x - mw * 0.42 + mw * 0.84 * (i + 0.5) / n
		var edge := sqrt(maxf(1.0 - pow((x - mc.x) / (mw * 0.5), 2.0), 0.0)) * mh * 0.5
		var tw := mw * 0.84 / n * 0.5
		var tl := mh * (0.4 + 0.2 * _chip(i + 60))
		var top := PackedVector2Array([Vector2(x - tw, mc.y - edge + 2), Vector2(x + tw, mc.y - edge + 2), Vector2(x + _rng.randf_range(-1, 1), mc.y - edge + tl)])
		_fill(top, BONE)
		_out.draw_polyline(PackedVector2Array([top[0], top[2], top[1]]), _c(INK), 1.5)
		var bl := mh * (0.3 + 0.18 * _chip(i + 80))
		var bot := PackedVector2Array([Vector2(x - tw, mc.y + edge - 2), Vector2(x + tw, mc.y + edge - 2), Vector2(x + _rng.randf_range(-1, 1), mc.y + edge - bl)])
		_fill(bot, BONE)
		_out.draw_polyline(PackedVector2Array([bot[0], bot[2], bot[1]]), _c(INK), 1.5)
	if tired > 0.5:  # panting, the tongue lolling out
		var tg := mc + Vector2(10, mh * 0.3)
		_fill(_ellipse(tg + Vector2(0, 10 + 4.0 * sin(_time * 7.0)), 16.0, 14.0), Color(0.86, 0.32, 0.4))
		_out.draw_line(tg + Vector2(0, 2), tg + Vector2(0, 18), _c(Color(0.55, 0.12, 0.2)), 2.0)
	_outline(maw, 4.0)
	# cracks and creases in the cardboard round the face
	for i in 4:
		var a := Vector2(_chip(i + 100) * w * 0.8 - w * 0.4, cy - 60 + _chip(i + 110) * 90.0)
		_out.draw_polyline(PackedVector2Array([a, a + Vector2(12, 10), a + Vector2(6, 24)]), _c(Color(TAN_DARK, 0.9)), 2.0)


## A thin scribbled arm out of the sleeve's side, ending in a clawed hand.
static func _arm(side: float, w: float, h: float, p: Dictionary) -> void:
	var lunge := float(p.get("lunge", 0.0))
	var rubbing := float(p.get("rubbing", 0.0))
	var windup := float(p.get("windup", 0.0))
	var tired := float(p.get("tired", 0.0))
	var shoulder := Vector2(side * w * 0.46, -h * 0.5)
	var reach := 0.5 + 0.5 * sin(_time * 3.0 + side)
	var grab := lunge + rubbing * 0.5
	var elbow := shoulder + Vector2(side * (46.0 + 10.0 * reach), 30.0 - 20.0 * grab - 70.0 * windup + 30.0 * tired)
	var hand := elbow + Vector2(side * (24.0 + 30.0 * grab - 10.0 * windup), 46.0 - 50.0 * grab - 90.0 * windup + 40.0 * tired + 6.0 * sin(_time * 7.0 + side))
	for k in 3:  # scribbled: a few overlapping strokes
		var o := _wob(2.5)
		_out.draw_polyline(PackedVector2Array([shoulder + o, elbow + o * 1.5, hand + o]), _c(INK), 7.0 - k * 2.0)
	_out.draw_circle(hand, 6.0, _c(INK))  # the knuckles
	_claws(hand, Vector2(side, 0.4 - windup * 1.2 + tired * 0.8).normalized(), side, 1.0 - tired * 0.5)


## Four hooked claws fanning out of a hand along `d`.
static func _claws(hand: Vector2, d0: Vector2, side: float, spread: float) -> void:
	for i in 4:
		var d := d0.rotated((i - 1.5) * 0.45 * side * spread)
		var q := hand
		var line := PackedVector2Array([q])
		for s in 3:
			d = d.rotated(0.35 * side)
			q += d * 15.0
			line.append(q + _wob(1.0))
		_out.draw_polyline(line, _c(INK), 4.0)


# ---------------------------------------------------------------- side view

## The side / attack view from the sheet: the block flung on its side, crown
## first, maw and one eye on the leading end, claws reaching ahead, speed
## streaks and a dust cloud behind, shavings flying. Faces `heading`.
static func _side(xf: Transform2D, p: Dictionary) -> Transform2D:
	var heading := float(p.get("heading", 1.0))
	var rage := float(p.get("rage", 0.0))
	_j = float(p.get("jitter", 1.0)) * 1.6
	var shake := Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)) * _j
	var flip := Transform2D(0.0, Vector2(heading, 1.0), 0.0, Vector2.ZERO)
	# lying along x: length 330, thickness 170, tipped nose-down
	var body := xf * flip * Transform2D(-0.42, Vector2.ONE, 0.0, Vector2(0, -150) + shake)
	var L := H
	var T := W * 0.8
	var x0 := -L * 0.5
	var x1 := L * 0.5
	# speed streaks and a dust cloud behind (drawn unrotated, along the ground)
	var trail := float(p.get("trail", 1.0))
	_out.draw_set_transform_matrix(xf * flip)
	for k in 5:
		var y := -40.0 - k * 46.0 + _rng.randf_range(-4, 4)
		var len := (120.0 + _chip(k + 7) * 120.0) * trail
		_out.draw_line(Vector2(-L * 0.55 - len, y), Vector2(-L * 0.55 - 20.0, y + 8.0), _c(Color(INK, 0.55)), 6.0 - k * 0.6)
	for k in 6:
		var c := Vector2(-L * 0.5 - (40.0 + k * 46.0) * trail, -26.0 - _chip(k + 30) * 40.0)
		var r := 34.0 + _chip(k + 50) * 26.0 - k * 3.0
		_fill(_ellipse(c + _wob(3.0), r, r * 0.7), Color(DUST, 0.7 - k * 0.09))
	# shavings flicked up off the nose
	for k in 8:
		var a := Vector2(L * 0.35 + _chip(k + 70) * 60.0, -20.0 - _chip(k + 90) * 70.0) + _wob(8.0)
		_fill(PackedVector2Array([a, a + Vector2(9, -3), a + Vector2(4, 6)]), PINK if k % 2 == 0 else Color(DUST, 0.9))
	_out.draw_set_transform_matrix(body)
	# the trailing arm (behind the block), the claws dragging
	var sh2 := Vector2(-L * 0.05, T * 0.5)
	var el2 := sh2 + Vector2(-40, 60) + _wob(3.0)
	var hd2 := el2 + Vector2(-50, 30)
	for k in 2:
		_out.draw_polyline(PackedVector2Array([sh2, el2 + _wob(2.0), hd2]), _c(INK), 6.0 - k * 2.0)
	_claws(hd2, Vector2(-1, 0.3).normalized(), -1.0, 0.8)
	# the sleeve: tan, torn at its front edge, the blue band at the back end
	var sleeve := PackedVector2Array([Vector2(x0, -T * 0.5), Vector2(x0, T * 0.5)])
	var front := x1 - L * 0.34
	for i in 7:
		var y := T * 0.5 - T * i / 6.0
		var tear := (_chip(i + 200) * 26.0 if i % 2 == 1 else _chip(i + 210) * 6.0)
		sleeve.append(Vector2(front + tear + _rng.randf_range(-1, 1) * _j, y))
	_fill(sleeve, TAN)
	_fill(PackedVector2Array([Vector2(x0, T * 0.18), Vector2(front, T * 0.18), Vector2(front, T * 0.5), Vector2(x0, T * 0.5)]), Color(TAN_DARK, 0.5))
	var band := PackedVector2Array([Vector2(x0, -T * 0.5), Vector2(x0 + L * 0.2, -T * 0.5), Vector2(x0 + L * 0.17, T * 0.5), Vector2(x0, T * 0.5)])
	_fill(band, BLUE)
	_fill(PackedVector2Array([Vector2(x0 + L * 0.15, -T * 0.5), Vector2(x0 + L * 0.2, -T * 0.5), Vector2(x0 + L * 0.17, T * 0.5), Vector2(x0 + L * 0.13, T * 0.5)]), BLUE_DARK)
	_outline(band, 3.0)
	_outline(sleeve, 5.0)
	# the pink rubber nose, chipped, a pale scuff where it rubs
	var nose := PackedVector2Array([Vector2(front, -T * 0.5)])
	for i in 7:
		var y := -T * 0.5 + T * i / 6.0
		var dip := (_chip(i + 300) * 16.0 if i > 0 and i < 6 else 10.0)
		nose.append(Vector2(x1 - dip + _rng.randf_range(-1, 1) * _j, y))
	nose.append(Vector2(front, T * 0.5))
	_fill(nose, PINK)
	_fill(PackedVector2Array([Vector2(front, T * 0.2), Vector2(x1 - 10, T * 0.2), Vector2(x1 - 10, T * 0.5), Vector2(front, T * 0.5)]), PINK_DARK)
	_fill(PackedVector2Array([Vector2(front + 14, -T * 0.4), Vector2(x1 - 30, -T * 0.42), Vector2(x1 - 34, -T * 0.25), Vector2(front + 18, -T * 0.22)]), PINK_LIGHT)
	_outline(nose, 5.0)
	# the face on the sleeve's leading end: one eye under a brow, the maw with teeth
	var ec := Vector2(front - 54, -T * 0.2)
	if rage > 0.0:
		_out.draw_circle(ec, 30.0, _c(Color(RED, 0.25 * rage)))
	var eye := PackedVector2Array()
	for i in 10:
		var a := PI + PI * i / 9.0
		eye.append(ec + Vector2(cos(a) * 22.0, sin(a) * 13.0))
	eye.append(ec + Vector2(18, 8))
	eye.append(ec + Vector2(-18, 8))
	_fill(eye, BONE.lerp(Color(1.0, 0.5, 0.4), rage * 0.7))
	_outline(eye, 3.0)
	_out.draw_circle(ec + Vector2(8, 0), 4.5, _c(INK.lerp(RED, rage)))
	_out.draw_line(ec + Vector2(-26, -22), ec + Vector2(24, -6), _c(INK), 6.0)
	var mc := Vector2(front - 40, T * 0.18)
	var mw := 92.0
	var mh := 60.0 + 10.0 * sin(_time * 14.0)
	var maw := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		maw.append(mc + Vector2(cos(a) * mw * 0.5, sin(a) * mh * 0.5) + _wob(1.5))
	_fill(maw, MAW)
	for i in 6:
		var x := mc.x - mw * 0.4 + mw * 0.8 * (i + 0.5) / 6.0
		var edge := sqrt(maxf(1.0 - pow((x - mc.x) / (mw * 0.5), 2.0), 0.0)) * mh * 0.5
		_fill(PackedVector2Array([Vector2(x - 7, mc.y - edge + 2), Vector2(x + 7, mc.y - edge + 2), Vector2(x, mc.y - edge + mh * 0.42)]), BONE)
		_fill(PackedVector2Array([Vector2(x - 7, mc.y + edge - 2), Vector2(x + 7, mc.y + edge - 2), Vector2(x, mc.y + edge - mh * 0.34)]), BONE)
	_outline(maw, 4.0)
	# the leading arm, reaching ahead under the nose, claws open
	var sh := Vector2(front - 10, T * 0.5)
	var el := sh + Vector2(46, 50) + _wob(3.0)
	var hd := el + Vector2(70, -6 + 8.0 * sin(_time * 12.0))
	for k in 3:
		_out.draw_polyline(PackedVector2Array([sh + _wob(2.0), el + _wob(2.0), hd]), _c(INK), 7.0 - k * 2.0)
	_out.draw_circle(hd, 6.0, _c(INK))
	_claws(hd, Vector2(1, 0.2).normalized(), 1.0, 1.0)
	# the brand along the sleeve's side, always reading left to right
	var from := body * Vector2(x0 + L * 0.21, T * 0.16)
	var to := body * Vector2(front - 92.0, T * 0.16)
	if to.x < from.x:
		var swap := from
		from = to
		to = swap
	var ax := (to - from).normalized() * xf.get_scale().y
	return Transform2D(ax, -ax.orthogonal(), from)


# ----------------------------------------------------------------- helpers

static func _c(col: Color) -> Color:
	var out: Color = _tint.call(col) if _tint.is_valid() else col
	out.a *= _alpha
	return out


static func _fill(poly: PackedVector2Array, col: Color) -> void:
	_out.draw_colored_polygon(poly, _c(col))


static func _outline(pts: PackedVector2Array, width: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	_out.draw_polyline(loop, _c(INK), width)


## A fixed "random" size per index (the shape doesn't boil, only the jitter).
static func _chip(i: int) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)


static func _wob(amount: float) -> Vector2:
	return Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount)) * _j


static func _box(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		pts.append(c + _wob(0.8))
	return pts


static func _ellipse(c: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _star(c: Vector2, r: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * (r if i % 2 == 0 else r * 0.45))
	_out.draw_colored_polygon(pts, _c(Color(DANGER, a)))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_out.draw_polyline(loop, _c(Color(INK, a)), 2.0)
