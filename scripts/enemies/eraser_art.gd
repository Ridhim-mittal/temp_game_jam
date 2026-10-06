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

## The block seen three-quarters on (as on the sheet): the front face carries
## the skull, the left side face is the blue band, the crown's top face shows.
## Front face x from FX0 to FX1; the side face reaches DEPTH further left and
## RISE higher (perspective).
const FX0 := -0.3 * W
const FX1 := 0.5 * W
const DEPTH := 0.2 * W
const RISE := 16.0


## Returns where the brand is lettered.
static func _front(xf: Transform2D, p: Dictionary) -> Transform2D:
	var rubbing := float(p.get("rubbing", 0.0))
	var lunge := float(p.get("lunge", 0.0))
	var windup := float(p.get("windup", 0.0))
	var tired := float(p.get("tired", 0.0))
	var heading := float(p.get("heading", 1.0))
	_j = float(p.get("jitter", 1.0)) * (1.0 + rubbing * 1.5 + windup * 1.2) * (1.0 - tired * 0.6)
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
	var back := Vector2(-DEPTH, -RISE)
	# ink spatters on the paper round its base (they stay put, it's its mess)
	_out.draw_set_transform_matrix(xf)
	for i in 5:
		var c := Vector2((_chip(i + 400) - 0.5) * W * 1.25, -2.0 - _chip(i + 410) * 6.0)
		_fill(_ellipse(c, 3.0 + _chip(i + 420) * 9.0, 2.0 + _chip(i + 430) * 4.0, 9), Color(INK, 0.75))
	_out.draw_set_transform_matrix(body)
	# the arm on the far side, behind the block
	_arm(-1.0, h, p)
	# bottom rubber: its left side face, then the front
	var by0 := -h * 0.23
	var bot_side := PackedVector2Array([Vector2(FX0 + 6, by0), Vector2(FX0 + 6, 0), Vector2(FX0 + 6, 0) + back, Vector2(FX0 + 6, by0) + back])
	_fill(bot_side, PINK_DARK)
	_hatch(bot_side[0], bot_side[3], bot_side[1], bot_side[2], 5, 2.0)
	_outline2(bot_side, 4.0)
	var bot := _box(Rect2(FX0 + 6, by0, FX1 - FX0 - 12, -by0))
	_fill(bot, PINK)
	_fill(_box(Rect2(FX1 - 46, by0, 40, -by0)), Color(PINK_DARK, 0.7))
	_outline2(bot, 5.0)
	# top rubber: a worn crown with two big bites taken out of its edge
	var ty := -h + RISE
	var cy1 := -h * 0.66
	var edge := PackedVector2Array()
	var crown := 9
	for i in crown + 1:
		var x := lerpf(FX0 + 4, FX1 - 4, float(i) / crown)
		var dip := 0.0
		if i > 0 and i < crown:
			dip = _chip(i) * 12.0 + (34.0 if i == 2 or i == 6 else 0.0)
		edge.append(Vector2(x + _rng.randf_range(-1, 1) * _j, ty + 6.0 + dip))
	# the crown's top face (lighter), seen from a little above
	var top_face := PackedVector2Array()
	for q in edge:
		top_face.append(q)
	for i in range(edge.size() - 1, -1, -1):
		top_face.append(edge[i] + back * Vector2(1.0, 1.0))
	_fill(top_face, PINK_LIGHT)
	_outline2(top_face, 4.0)
	# its left side face, in shadow and hatched
	var crown_side := PackedVector2Array([edge[0], Vector2(FX0 + 4, cy1), Vector2(FX0 + 4, cy1) + back, edge[0] + back])
	_fill(crown_side, PINK_DARK)
	_hatch(crown_side[3], crown_side[0], crown_side[2], crown_side[1], 5, 2.0)
	_outline2(crown_side, 4.0)
	# its front face
	var crown_front := edge.duplicate()
	crown_front.append(Vector2(FX1 - 4, cy1))
	crown_front.append(Vector2(FX0 + 4, cy1))
	_fill(crown_front, PINK)
	_fill(PackedVector2Array([Vector2(FX1 - 44, ty + 20), Vector2(FX1 - 4, ty + 14), Vector2(FX1 - 4, cy1), Vector2(FX1 - 44, cy1)]), Color(PINK_DARK, 0.75))
	_fill(PackedVector2Array([Vector2(FX0 + 22, ty + 30), Vector2(FX0 + 70, ty + 24), Vector2(FX0 + 64, ty + 44), Vector2(FX0 + 20, ty + 50)]), PINK_LIGHT)
	for i in 4:  # scuffs rubbed into the rubber
		var a := Vector2(FX0 + 30 + _chip(i + 140) * 110.0, ty + 40 + _chip(i + 150) * 34.0)
		_out.draw_line(a, a + Vector2(20, -5), _c(PINK_DARK), 2.5)
	_outline2(crown_front, 5.0)
	# the cardboard sleeve, torn along its top and bottom edges
	var sy0 := -h * 0.75
	var sy1 := -h * 0.2
	var tears := 10
	var s_top := PackedVector2Array()
	var s_bot := PackedVector2Array()
	for i in tears + 1:
		var x := lerpf(FX0, FX1, float(i) / tears)
		var tear := (_chip(i + 20) * 28.0 if i % 2 == 1 else _chip(i + 40) * 7.0)
		s_top.append(Vector2(x + _rng.randf_range(-1, 1) * _j, sy0 + tear))
		var rip := _chip(i + 160) * 13.0 + (20.0 if i == 7 else 0.0)
		s_bot.append(Vector2(x + _rng.randf_range(-1, 1) * _j, sy1 + rip))
	# the blue band wraps the left side face, torn with the rest
	var band := PackedVector2Array([s_top[0], s_bot[0], s_bot[0] + back, s_top[0] + back + Vector2(0, 10)])
	_fill(band, BLUE)
	_fill(PackedVector2Array([s_top[0] + Vector2(-8, 4), s_bot[0] + Vector2(-8, 0), s_bot[0], s_top[0]]), BLUE_DARK)
	_hatch(band[3], band[0], band[2], band[1], 3, 1.5)
	_outline2(band, 4.0)
	var sleeve := PackedVector2Array()
	for q in s_top:
		sleeve.append(q)
	for i in range(s_bot.size() - 1, -1, -1):
		sleeve.append(s_bot[i])
	_fill(sleeve, TAN)
	# the sleeve's right edge in shadow, hatched like the sheet
	var shade := PackedVector2Array([Vector2(FX1 - 40, sy0 + 18), Vector2(FX1, sy0 + 8), Vector2(FX1, sy1), Vector2(FX1 - 40, sy1 + 8)])
	_fill(shade, Color(TAN_DARK, 0.6))
	_hatch(shade[0], shade[1], shade[3], shade[2], 6, 2.0)
	_outline2(sleeve, 5.5)
	# the face, printed on the sleeve: a skull filling it
	_face(p)
	# the arm on the near side, in front
	_arm(1.0, h, p)
	# tired: the weak spot shows (a pulsing marker over the crown) and stars circle it
	if tired > 0.0:
		var bob := sin(_time * 6.0) * 6.0
		_out.draw_circle(Vector2(20, -h - 34 + bob), 15.0, _c(Color(INK, tired)))
		_out.draw_circle(Vector2(20, -h - 34 + bob), 11.0, _c(Color(DANGER, tired)))
		for k in 3:
			var a := _time * 3.0 + TAU * k / 3.0
			_star(Vector2(20 + cos(a) * W * 0.42, -h - 6 + sin(a) * 16.0), 9.0, tired)
	# the brand runs down the band
	return body * Transform2D(-PI * 0.5 + 0.06, s_bot[0] + Vector2(-DEPTH * 0.82, -16))


static func _face(p: Dictionary) -> void:
	var tired := float(p.get("tired", 0.0))
	var rage := clampf(float(p.get("rage", 0.0)) + float(p.get("windup", 0.0)) * 0.8, 0.0, 1.0)
	var roar := clampf(float(p.get("roar", 0.0)) + float(p.get("windup", 0.0)) * 0.6, 0.0, 1.0)
	var fx := (FX0 + FX1) * 0.5 + 4.0  # the middle of the front face
	var cy := -H * 0.56
	# deep hatched sockets, cheek hollows, then wild eyes under heavy brows
	for side: float in [-1.0, 1.0]:
		var ex := fx + side * 40.0
		var socket := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			socket.append(Vector2(ex, cy) + Vector2(cos(a) * 40.0, sin(a) * 32.0) + _wob(1.5))
		_fill(socket, Color(TAN_DARK, 0.95))
		_hatch(Vector2(ex - 34, cy - 20), Vector2(ex + 34, cy - 20), Vector2(ex - 30, cy + 26), Vector2(ex + 30, cy + 26), 6, 1.5)
		_fill(PackedVector2Array([Vector2(ex - side * 4.0, cy + 34), Vector2(ex + side * 36.0, cy + 26), Vector2(ex + side * 30.0, cy + 54), Vector2(ex + side * 6.0, cy + 46)]), Color(TAN_DARK, 0.65))
		if tired > 0.5:
			# dizzy: spirals for eyes, the brows gone slack
			var sp := PackedVector2Array()
			for i in 24:
				var t := i / 23.0
				var a := _time * 8.0 * side + t * TAU * 2.2
				sp.append(Vector2(ex, cy + 2) + Vector2(cos(a), sin(a) * 0.8) * (3.0 + 19.0 * t))
			_fill(_ellipse(Vector2(ex, cy + 2), 26.0, 20.0), BONE)
			_out.draw_polyline(sp, _c(INK), 3.5)
			_out.draw_line(Vector2(ex - 24, cy - 26), Vector2(ex + 24, cy - 28), _c(INK), 5.0)
			continue
		# the eye: a big almond cut off by a brow slanting down to the nose
		var eye := PackedVector2Array()
		for i in 11:
			var a := PI + PI * i / 10.0
			eye.append(Vector2(ex, cy + 4) + Vector2(cos(a) * 30.0, sin(a) * 24.0))
		var brow_in := Vector2(ex - side * 32.0, cy - 4.0 + rage * 4.0)
		var brow_out := Vector2(ex + side * 30.0, cy - 30.0)
		var cut := PackedVector2Array()
		for q in eye:
			var t := (q.x - brow_in.x) / (brow_out.x - brow_in.x)
			cut.append(Vector2(q.x, maxf(q.y, lerpf(brow_in.y, brow_out.y, clampf(t, 0.0, 1.0)))))
		cut.append(Vector2(ex + 26.0, cy + 14))
		cut.append(Vector2(ex - 26.0, cy + 14))
		if rage > 0.0:  # a red glow round a burning eye
			_out.draw_circle(Vector2(ex, cy + 4), 34.0, _c(Color(RED, 0.28 * rage)))
		_fill(cut, BONE.lerp(Color(1.0, 0.5, 0.4), rage * 0.7))
		_outline2(cut, 3.5)
		var pupil := Vector2(ex - side * 4.0, cy + 6) + Vector2(_rng.randf_range(-1, 1), 0)
		_out.draw_circle(pupil, 5.0 - rage * 1.2, _c(INK.lerp(RED, rage)))
		_out.draw_circle(pupil + Vector2(-1.5, -2.0), 1.6, _c(BONE))
		_out.draw_line(brow_in + Vector2(0, -3), brow_out + Vector2(0, -3), _c(INK), 8.0)
		_out.draw_line(brow_in + Vector2(side * 6, -9), brow_out + Vector2(-side * 4, -12), _c(INK), 3.0)
	# nose: two dark slits in a notch
	_fill(PackedVector2Array([Vector2(fx, cy + 26), Vector2(fx - 12, cy + 50), Vector2(fx, cy + 44), Vector2(fx + 12, cy + 50)]), INK)
	# the maw: wide, gaping, long jagged teeth top and bottom (sags open when tired)
	var open := 0.6 + 0.4 * roar + 0.08 * sin(_time * 9.0) + tired * 0.2
	var mw := FX1 - FX0 - 24.0 - tired * 16.0
	var mh := 64.0 + 46.0 * open
	var mc := Vector2(fx, cy + 60 + mh * 0.5)
	var maw := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		var r := Vector2(cos(a) * mw * 0.5, sin(a) * mh * 0.5)
		if sin(a) < 0.0:
			r.y *= 0.8  # the upper lip flatter, like a skull's
		maw.append(mc + r + _wob(1.5))
	_fill(maw, MAW)
	var n := 10
	for i in n:
		var x := mc.x - mw * 0.43 + mw * 0.86 * (i + 0.5) / n
		var e := sqrt(maxf(1.0 - pow((x - mc.x) / (mw * 0.5), 2.0), 0.0)) * mh * 0.5
		var tw := mw * 0.86 / n * 0.52
		var tl := mh * (0.42 + 0.22 * _chip(i + 60))
		var top := PackedVector2Array([Vector2(x - tw, mc.y - e * 0.8 + 2), Vector2(x + tw, mc.y - e * 0.8 + 2), Vector2(x + _rng.randf_range(-1, 1) + tw * 0.2, mc.y - e * 0.8 + tl)])
		_fill(top, BONE)
		_out.draw_polyline(PackedVector2Array([top[0], top[2], top[1]]), _c(INK), 1.8)
		var bl := mh * (0.32 + 0.2 * _chip(i + 80))
		var bot := PackedVector2Array([Vector2(x - tw, mc.y + e - 2), Vector2(x + tw, mc.y + e - 2), Vector2(x + _rng.randf_range(-1, 1) - tw * 0.2, mc.y + e - bl)])
		_fill(bot, BONE)
		_out.draw_polyline(PackedVector2Array([bot[0], bot[2], bot[1]]), _c(INK), 1.8)
	if tired > 0.5:  # panting, the tongue lolling out
		var tg := mc + Vector2(10, mh * 0.28)
		_fill(_ellipse(tg + Vector2(0, 12 + 4.0 * sin(_time * 7.0)), 18.0, 16.0), Color(0.86, 0.32, 0.4))
		_out.draw_line(tg + Vector2(0, 2), tg + Vector2(0, 22), _c(Color(0.55, 0.12, 0.2)), 2.0)
	_outline2(maw, 5.0)
	# cracks and creases in the cardboard round the face
	for i in 5:
		var a := Vector2(FX0 + 14 + _chip(i + 100) * (FX1 - FX0 - 28), cy - 70 + _chip(i + 110) * 150.0)
		_out.draw_polyline(PackedVector2Array([a, a + Vector2(12, 10), a + Vector2(6, 26)]), _c(Color(TAN_DARK, 0.95)), 2.2)


## A long, thin, scribbled arm out of the block's side, hanging down, ending
## in a hand of five long hooked fingers (the sheet's spidery claws).
static func _arm(side: float, h: float, p: Dictionary) -> void:
	var lunge := float(p.get("lunge", 0.0))
	var rubbing := float(p.get("rubbing", 0.0))
	var windup := float(p.get("windup", 0.0))
	var tired := float(p.get("tired", 0.0))
	var sx := FX1 - 6.0 if side > 0.0 else FX0 - DEPTH * 0.6
	var shoulder := Vector2(sx, -h * 0.5)
	var sway := sin(_time * 3.0 + side * 1.3)
	var grab := lunge + rubbing * 0.5
	var elbow := shoulder + Vector2(side * (62.0 + 10.0 * sway), 22.0 - 30.0 * grab - 96.0 * windup + 34.0 * tired)
	var hand := elbow + Vector2(side * (26.0 + 46.0 * grab - 18.0 * windup), 78.0 - 70.0 * grab - 120.0 * windup + 40.0 * tired + 8.0 * sin(_time * 7.0 + side))
	var wrist := hand - (hand - elbow).normalized() * 12.0
	for k in 3:  # scribbled: a few overlapping strokes, the elbow a sharp knob
		var o := _wob(2.5)
		_out.draw_polyline(PackedVector2Array([shoulder + o, elbow + o * 1.5, wrist + o]), _c(INK), 7.5 - k * 2.0)
	_out.draw_circle(elbow, 5.0, _c(INK))
	_out.draw_circle(hand, 7.0, _c(INK))
	var down := (hand - elbow).normalized()
	_claws(hand, down.rotated(-side * (0.5 + windup * 0.6)), side, 1.0 - tired * 0.4, 5)


## Long hooked claws fanning out of a hand along `d`.
static func _claws(hand: Vector2, d0: Vector2, side: float, spread: float, count := 4) -> void:
	for i in count:
		var d := d0.rotated((i - (count - 1) * 0.5) * 0.4 * side * spread)
		var q := hand
		var line := PackedVector2Array([q])
		for s in 4:
			d = d.rotated(0.32 * side)
			q += d * (16.0 - s * 2.0)
			line.append(q + _wob(1.0))
		_out.draw_polyline(line, _c(INK), 4.0 - 0.0)


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
	_hatch(Vector2(x0 + L * 0.2, T * 0.2), Vector2(front - 6, T * 0.2), Vector2(x0 + L * 0.2, T * 0.48), Vector2(front - 6, T * 0.48), 9, 2.0)
	var band := PackedVector2Array([Vector2(x0, -T * 0.5), Vector2(x0 + L * 0.2, -T * 0.5), Vector2(x0 + L * 0.17, T * 0.5), Vector2(x0, T * 0.5)])
	_fill(band, BLUE)
	_fill(PackedVector2Array([Vector2(x0 + L * 0.15, -T * 0.5), Vector2(x0 + L * 0.2, -T * 0.5), Vector2(x0 + L * 0.17, T * 0.5), Vector2(x0 + L * 0.13, T * 0.5)]), BLUE_DARK)
	_outline2(band, 3.5)
	_outline2(sleeve, 5.5)
	# the pink rubber nose, chipped, a pale scuff where it rubs
	var nose := PackedVector2Array([Vector2(front, -T * 0.5)])
	for i in 7:
		var y := -T * 0.5 + T * i / 6.0
		var dip := (_chip(i + 300) * 16.0 if i > 0 and i < 6 else 10.0)
		nose.append(Vector2(x1 - dip + _rng.randf_range(-1, 1) * _j, y))
	nose.append(Vector2(front, T * 0.5))
	_fill(nose, PINK)
	_fill(PackedVector2Array([Vector2(front, T * 0.2), Vector2(x1 - 10, T * 0.2), Vector2(x1 - 10, T * 0.5), Vector2(front, T * 0.5)]), PINK_DARK)
	_hatch(Vector2(front + 4, T * 0.22), Vector2(x1 - 14, T * 0.22), Vector2(front + 4, T * 0.48), Vector2(x1 - 14, T * 0.48), 5, 2.0)
	_fill(PackedVector2Array([Vector2(front + 14, -T * 0.4), Vector2(x1 - 30, -T * 0.42), Vector2(x1 - 34, -T * 0.25), Vector2(front + 18, -T * 0.22)]), PINK_LIGHT)
	_outline2(nose, 5.5)
	# the face on the sleeve's leading end: one eye under a brow, the maw with teeth
	var ec := Vector2(front - 54, -T * 0.2)
	if rage > 0.0:
		_out.draw_circle(ec, 30.0, _c(Color(RED, 0.25 * rage)))
	_fill(_ellipse(ec + Vector2(0, -2), 34.0, 24.0), Color(TAN_DARK, 0.9))
	var eye := PackedVector2Array()
	for i in 10:
		var a := PI + PI * i / 9.0
		eye.append(ec + Vector2(cos(a) * 26.0, sin(a) * 16.0))
	eye.append(ec + Vector2(18, 8))
	eye.append(ec + Vector2(-18, 8))
	_fill(eye, BONE.lerp(Color(1.0, 0.5, 0.4), rage * 0.7))
	_outline2(eye, 3.5)
	_out.draw_circle(ec + Vector2(8, 0), 4.5, _c(INK.lerp(RED, rage)))
	_out.draw_line(ec + Vector2(-30, -24), ec + Vector2(28, -6), _c(INK), 8.0)
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
	_outline2(maw, 4.5)
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


## A thick ink outline and a thin second pass a little off it: a pen line, not a vector edge.
static func _outline2(pts: PackedVector2Array, width: float) -> void:
	_outline(pts, width)
	var loop := PackedVector2Array()
	var o := _wob(2.5) + Vector2(1.5, -1.0)
	for q in pts:
		loop.append(q + o)
	loop.append(pts[0] + o)
	_out.draw_polyline(loop, _c(Color(INK, 0.7)), maxf(width * 0.3, 1.2))


## Pen hatching across a quad: lines from the edge a0-a1 to the edge b0-b1.
static func _hatch(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, n: int, width: float) -> void:
	for i in n:
		var t := (i + 0.5) / n
		_out.draw_line(a0.lerp(a1, t), b0.lerp(b1, clampf(t - 0.2, 0.0, 1.0)), _c(Color(INK, 0.55)), width)


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
