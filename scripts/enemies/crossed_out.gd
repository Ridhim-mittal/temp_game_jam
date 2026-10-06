extends "res://scripts/enemies/enemy_base.gd"
## Crossed-Out: an abandoned draft, gone feral in the gutter. A big X of nailed
## planks shields its front,
## so side hits from the front bounce off. Get behind it (it turns slowly),
## pogo on its head, or get it into light, which burns the X away.
## It walks at the player and shoves when close.

enum State { WALK, WINDUP, SHOVE, RECOVER }

const InkBatch = preload("res://scripts/depth/ink_batch.gd")

@export var hp := 3
@export var walk_speed := 70.0
@export var shove_speed := 340.0
## How long the player must stay behind it before it turns round.
@export var turn_delay := 0.55

var state := State.WALK
var _timer := 0.0
var _turn := 0.0
var _shield := 1.0  # 1 = X fully up, 0 = burnt away by light


func _ready() -> void:
	setup(Vector2(28, 56), hp)


func _tick(delta: float) -> void:
	_timer -= delta
	_fall(delta)
	_shield = move_toward(_shield, 0.0 if is_lit() else 1.0, delta * 3.0)
	var d := to_player()
	match state:
		State.WALK:
			if _player and signf(d.x) != facing and absf(d.x) > 6.0:
				_turn += delta
				if _turn >= turn_delay:
					facing = -facing
					_turn = 0.0
			else:
				_turn = 0.0
			var blocked := is_on_floor() and (hitting_wall() or at_ledge())
			var chasing := _player != null and absf(d.x) < 500.0 and signf(d.x) == facing
			velocity.x = move_toward(velocity.x, facing * walk_speed if chasing and not blocked else 0.0, 600.0 * delta)
			if chasing and absf(d.x) < 74.0 and absf(d.y) < 50.0:
				state = State.WINDUP
				_timer = 0.4
		State.WINDUP:
			velocity.x = move_toward(velocity.x, -facing * 40.0, 600.0 * delta)
			if _timer <= 0.0:
				state = State.SHOVE
				_timer = 0.22
		State.SHOVE:
			velocity.x = facing * shove_speed
			if is_on_floor() and at_ledge():
				velocity.x = 0.0
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = 0.7
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _timer <= 0.0:
				state = State.WALK
	move_and_slide()


func _blocks(hit_dir: Vector2, from_pos: Vector2) -> bool:
	if _shield < 0.5 or hit_dir.y > 0.0:
		return false  # no shield in light; pogo hits come from above
	if signf(from_pos.x - global_position.x) != facing:
		return false  # hit from behind
	pop("BLOCK!", Color(0.9, 0.25, 0.2), Vector2(facing * 20.0, -60), 22)
	return true


# ------------------------------------------------------------------ the art
# A hunched, ragged ghoul in a long tattered brown coat and a crumpled top hat,
# crossed-out white X eyes and a grin of jagged teeth, its black clawed hands
# gripping the shield: a giant X of two splintered planks, nailed and stapled,
# stained with red ink. Light chars the planks black, edges glowing, until
# they crumble. All strokes boil at 12 fps (one InkBatch draw call).

const COAT := Color(0.31, 0.23, 0.17)
const COAT_DARK := Color(0.16, 0.11, 0.09)
const COAT_LIGHT := Color(0.47, 0.36, 0.26)
const HAT := Color(0.34, 0.27, 0.21)
const WOOD := Color(0.56, 0.37, 0.22)
const WOOD_DARK := Color(0.33, 0.19, 0.11)
const WOOD_LIGHT := Color(0.75, 0.55, 0.36)
const IRON := Color(0.56, 0.56, 0.6)
const RED_INK := Color(0.6, 0.07, 0.05)
const BONE := Color(0.96, 0.94, 0.87)
const MAW := Color(0.2, 0.02, 0.03)
const EMBER := Color(1.0, 0.52, 0.12)
## The head is drawn this much bigger than the body (the face has to read).
const HEAD_SCALE := 1.3
## Tatter lengths along the coat's hem, back to front.
const TATTERS := [6.0, 2.0, 7.0, 4.0, 8.0, 3.0, 6.0, 1.0, 5.0, 3.0]

var _batch := InkBatch.new()
var _rng := RandomNumberGenerator.new()


func paint(c: CanvasItem) -> void:
	var b := _batch
	_rng.seed = int(time * 12.0)  # the strokes boil
	var walking := absf(velocity.x) > 10.0
	var step := sin(time * 6.0) if walking else 0.0
	var lean := 0.04
	var push := 0.0
	var gape := 0.25 + 0.1 * sin(time * 1.7)
	match state:
		State.WINDUP:
			lean = -0.2
			push = -7.0
			gape = 0.75
		State.SHOVE:
			lean = 0.24
			push = 15.0
			gape = 1.0
		State.RECOVER:
			lean = 0.12
			push = 3.0
			gape = 0.45
	var bob := sin(time * 2.3) * 1.2 + absf(step) * 1.5
	# ink pooled under it, and the feet
	b.draw_colored_polygon(ell(Vector2(4, 0.5), 27, 3.2), INK)
	for i in 2:
		var sx := -9.0 + 16.0 * i
		var fx := sx + step * (5.0 if i == 0 else -5.0)
		_foot(b, Vector2(fx, 0.0), maxf(0.0, step * (1.0 if i == 0 else -1.0)) * 3.0)
	b.draw_set_transform(Vector2.ZERO, lean)
	_coat(b, bob)
	_back_arm(b, push, bob)
	# the head, hunched forward, drawn big in its own frame
	b.draw_set_transform_matrix(Transform2D(lean, Vector2.ZERO) * Transform2D(0.0, Vector2.ONE * HEAD_SCALE, 0.0, Vector2(7, -60 + bob)))
	_head(b, Vector2.ZERO, gape)
	b.draw_set_transform(Vector2.ZERO, lean)
	if _shield > 0.02:
		var x0 := Vector2(32.0 + push, -36.0 + bob * 0.5)
		_plank(b, x0, -0.4, 1)
		_plank(b, x0, 0.4, 2)
		_nail(b, x0, 0.9, true)  # the big spike through the crossing
	_front_arm(b, push, bob)
	b.draw_set_transform(Vector2.ZERO)
	b.flush(c)


func _j(v: Vector2, amount := 0.7) -> Vector2:
	return v + Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


func _foot(b: InkBatch, at: Vector2, lift: float) -> void:
	var p := at - Vector2(0, lift)
	b.draw_line(p + Vector2(-1, -12), p + Vector2(0, -2), INK, 4.0)
	b.draw_colored_polygon(pts([p.x - 4, p.y - 3, p.x + 6, p.y - 3, p.x + 9, p.y, p.x - 4, p.y]), INK)
	for k in 3:  # claws
		var t := p + Vector2(4 + k * 2.5, 0)
		b.draw_line(t, t + Vector2(3, 0.5), INK, 1.4)


func _coat(b: InkBatch, bob: float) -> void:
	var top := -60.0 + bob
	var hem := -10.0
	# the silhouette: hunched shoulders forward, widening down to a tattered hem
	var outline := PackedVector2Array([
		_j(Vector2(12, top - 2)), _j(Vector2(2, top - 6)), _j(Vector2(-10, top - 2)),
		_j(Vector2(-19, top + 10)), _j(Vector2(-24, top + 28)), _j(Vector2(-29, -20)), _j(Vector2(-33, hem))])
	var n := TATTERS.size()
	for i in n:  # hem, back to front: notch, tip, notch...
		var x := lerpf(-33.0, 24.0, (i + 0.5) / n)
		var sway := sin(time * 3.1 + i * 1.7) * 1.6
		outline.append(_j(Vector2(x - 2.5, hem - 2.0)))
		outline.append(_j(Vector2(x + sway, hem + TATTERS[i])))
	outline.append_array(PackedVector2Array([
		_j(Vector2(24, hem)), _j(Vector2(21, -30)), _j(Vector2(19, top + 14)), _j(Vector2(17, top + 4))]))
	b.draw_colored_polygon(outline, COAT)
	# the back half in shadow, a ragged shawl over the shoulders
	b.draw_colored_polygon(PackedVector2Array([
		_j(Vector2(-10, top - 1)), _j(Vector2(-19, top + 10)), _j(Vector2(-24, top + 28)),
		_j(Vector2(-29, -20)), _j(Vector2(-32, hem)), _j(Vector2(-16, hem + 2)), _j(Vector2(-12, -30)),
		_j(Vector2(-6, top + 14))]), COAT_DARK)
	var shawl := PackedVector2Array([_j(Vector2(14, top - 3)), _j(Vector2(2, top - 8)), _j(Vector2(-12, top - 3)),
		_j(Vector2(-21, top + 12))])
	for k in 7:  # its torn lower edge
		var x := lerpf(-21.0, 18.0, (k + 1) / 7.0)
		shawl.append(_j(Vector2(x, top + 13.0 + (5.0 if k % 2 == 0 else -1.0) + sin(time * 2.0 + k) * 1.0)))
	b.draw_colored_polygon(shawl, COAT_LIGHT.darkened(0.15))
	for k in 4:  # rags hanging off the shawl, swaying
		var x := lerpf(-17.0, 12.0, k / 3.0)
		var y0 := top + 14.0
		var sway := sin(time * 2.6 + k * 2.1) * 1.8
		var ln := 9.0 + (k * 7) % 5
		b.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.2, y0), Vector2(x + 2.2, y0),
			_j(Vector2(x + 1.0 + sway, y0 + ln)), _j(Vector2(x - 0.5 + sway * 1.2, y0 + ln + 2.5))]), COAT_LIGHT.darkened(0.3))
	# folds, hatching, highlights, holes, stitches
	for f: Array in [[-4, top + 16, -10, hem + 2], [6, top + 14, 4, hem + 4], [-16, top + 20, -22, hem + 3], [14, top + 16, 16, hem]]:
		b.draw_line(_j(Vector2(f[0], f[1])), _j(Vector2(f[2], f[3])), COAT_DARK, 1.6)
	for k in 7:  # hatching down the shadowed back, inside the silhouette
		var y := top + 18.0 + k * 5.0
		var x := -15.0 - (y - top) * 0.2
		b.draw_line(_j(Vector2(x, y), 0.4), _j(Vector2(x + 6.0, y - 3.0), 0.4), INK, 0.9)
	b.draw_line(_j(Vector2(19, top + 16)), _j(Vector2(22, hem - 4)), COAT_LIGHT, 1.4)
	b.draw_line(_j(Vector2(4, top - 6)), _j(Vector2(12, top - 3)), COAT_LIGHT, 1.2)
	b.draw_colored_polygon(pts([-6, -26, -3, -29, 0, -25, -3, -22]), INK)
	b.draw_colored_polygon(pts([8, -18, 11, -20, 12, -15, 9, -14]), INK)
	for k in 4:  # a crude stitched seam
		var y := -40.0 + k * 5.0
		b.draw_line(Vector2(-1, y), Vector2(3, y + 1.5), BONE.darkened(0.45), 1.0)
	# ink dripping off the hem
	for d: Array in [[-20.0, 0.0], [2.0, 1.3], [17.0, 2.6]]:
		var drop: float = fmod(time * 0.9 + float(d[1]), 1.0)
		var dx: float = d[0]
		b.draw_line(Vector2(dx, hem + 2.0), Vector2(dx, hem + 2.0 + drop * 9.0), INK, 1.5)
		b.draw_circle(Vector2(dx, hem + 3.0 + drop * 9.0), 1.4, INK)


func _head(b: InkBatch, h: Vector2, gape: float) -> void:
	var windup := state == State.WINDUP or state == State.SHOVE
	# the face: a shadow under the hat
	b.draw_colored_polygon(PackedVector2Array([_j(h + Vector2(-9, -7)), _j(h + Vector2(9, -8)),
		_j(h + Vector2(11, 4)), _j(h + Vector2(5, 12)), _j(h + Vector2(-5, 12)), _j(h + Vector2(-10, 3))]), INK)
	# the grin: a wide maw of jagged teeth, opening on the attack
	var open := 3.0 + gape * 5.0
	var m := h + Vector2(1, 4)
	var maw := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		maw.append(m + Vector2(lerpf(-8.0, 9.0, t), -sin(t * PI) * 1.5))
	for k in 9:
		var t := 1.0 - k / 8.0
		maw.append(m + Vector2(lerpf(-8.0, 9.0, t), sin(t * PI) * open))
	b.draw_colored_polygon(maw, MAW)
	for k in 8:  # upper and lower fangs
		var x := lerpf(-7.0, 8.0, (k + 0.5) / 8.0)
		var t := (x + 8.0) / 17.0
		var up := m + Vector2(x, -sin(t * PI) * 1.5)
		var low := m + Vector2(x, sin(t * PI) * open)
		var tl := 2.2 + (k % 3) * 0.9
		b.draw_colored_polygon(PackedVector2Array([up + Vector2(-1.1, 0), up + Vector2(1.1, 0), up + Vector2(0, tl)]), BONE)
		b.draw_colored_polygon(PackedVector2Array([low + Vector2(-1.0, 0), low + Vector2(1.0, 0), low + Vector2(0.3, -tl * 0.9)]), BONE)
	# crossed-out eyes: white, burning red when it winds up
	var eye := Color(1.0, 0.35, 0.25) if windup else BONE
	for ex: float in [-3.5, 4.5]:
		var e := h + Vector2(ex, -2.5)
		b.draw_circle(e, 3.6, Color(eye.r, eye.g, eye.b, 0.22))
		b.draw_line(e + Vector2(-2.4, -2.4), e + Vector2(2.4, 2.4), eye, 1.9)
		b.draw_line(e + Vector2(2.4, -2.4), e + Vector2(-2.4, 2.4), eye, 1.9)
	# the battered top hat, tipped back, its crown crumpled and dented
	var brim := h + Vector2(-1, -8)
	var tilt := -0.14
	var crown := PackedVector2Array([_j(brim + Vector2(-9, 0)), _j(brim + Vector2(-11, -12)),
		_j(brim + Vector2(-9, -20)), _j(brim + Vector2(-3, -18)), _j(brim + Vector2(2, -22)),
		_j(brim + Vector2(9, -19)), _j(brim + Vector2(8, -9)), _j(brim + Vector2(10, 0))])
	b.draw_colored_polygon(_rot(crown, brim, tilt), HAT)
	b.draw_colored_polygon(_rot(pts([brim.x - 10, brim.y - 1, brim.x + 10, brim.y - 1, brim.x + 9.5, brim.y - 5,
		brim.x - 10.5, brim.y - 5]), brim, tilt), HAT.darkened(0.45))  # band
	b.draw_line(_rot1(brim + Vector2(-2, -18), brim, tilt), _rot1(brim + Vector2(0, -8), brim, tilt), HAT.darkened(0.35), 1.2)
	b.draw_colored_polygon(_rot(pts([brim.x + 3, brim.y - 15, brim.x + 7, brim.y - 16, brim.x + 7, brim.y - 11,
		brim.x + 3, brim.y - 11]), brim, tilt), HAT.lightened(0.15))  # a patch
	var brim_pts := PackedVector2Array()
	for k in 14:  # a wide floppy brim with a torn notch
		var a := TAU * k / 14.0
		var r := Vector2(17.0, 3.8) * (0.7 if k == 3 else 1.0)
		brim_pts.append(_j(brim + Vector2(cos(a) * r.x, sin(a) * r.y + (1.5 if cos(a) > 0.6 else 0.0)), 0.4))
	b.draw_colored_polygon(_rot(brim_pts, brim, tilt), HAT.darkened(0.2))


func _back_arm(b: InkBatch, push: float, bob: float) -> void:
	var sh := Vector2(-4, -56 + bob)
	var el := Vector2(10, -44 + bob)
	var hand := Vector2(27 + push, -54 + bob * 0.5)
	b.draw_line(sh, el, COAT_DARK, 7.0)
	b.draw_line(el, hand, INK, 3.5)
	_hand(b, hand, -0.4)


func _front_arm(b: InkBatch, push: float, bob: float) -> void:
	var sh := Vector2(16, -50 + bob)
	var el := Vector2(22, -38 + bob)
	var hand := Vector2(36 + push, -24 + bob * 0.5)
	b.draw_line(sh, el, COAT, 8.0)  # the sleeve, ragged at the cuff
	for k in 3:
		b.draw_line(el + Vector2(-3 + k * 3, 0), _j(el + Vector2(-4 + k * 3, 6 + k % 2 * 2)), COAT, 2.0)
	b.draw_line(el, hand, INK, 3.5)
	_hand(b, hand, 0.3)


## Long black fingers hooked over the plank, claws out.
func _hand(b: InkBatch, at: Vector2, rot: float) -> void:
	b.draw_circle(at, 3.6, INK)
	for k in 4:
		var a := rot - 0.9 + k * 0.55
		var mid := at + Vector2.from_angle(a) * 5.0
		var tip := mid + Vector2.from_angle(a + 0.9) * 4.5
		b.draw_line(at, mid, INK, 2.0)
		b.draw_line(mid, tip, INK, 1.6)
		b.draw_line(tip, tip + Vector2.from_angle(a + 1.6) * 2.2, BONE.darkened(0.3), 1.0)


## One splintered plank of the X: grain, a knot, nails, bent staples, red ink.
func _plank(b: InkBatch, center: Vector2, angle: float, seed_n: int) -> void:
	var burn := 1.0 - _shield
	var a := clampf(_shield * 2.0, 0.0, 1.0)
	var wood := WOOD.lerp(INK, burn * 0.9)
	var half_len := 43.0
	var half_w := 6.5
	var along := Vector2.from_angle(angle - PI * 0.5)  # up the plank
	var across := Vector2(-along.y, along.x)
	var r := RandomNumberGenerator.new()
	r.seed = seed_n * 977
	var poly := PackedVector2Array()
	for k in 5:  # top end, splintered
		var t := lerpf(-1.0, 1.0, k / 4.0)
		poly.append(_j(center + along * (half_len + (r.randf_range(0, 6) if k % 2 else 0.0)) + across * t * half_w, 0.4))
	for k in 5:  # bottom end, splintered
		var t := lerpf(1.0, -1.0, k / 4.0)
		poly.append(_j(center - along * (half_len + (r.randf_range(0, 7) if k % 2 == 0 else 1.0)) + across * t * half_w, 0.4))
	b.draw_colored_polygon(poly, Color(wood, a))
	# grain lines and a knot
	for g: float in [-0.55, -0.1, 0.4]:
		var off: Vector2 = across * half_w * g
		var wob := r.randf_range(-1.0, 1.0)
		b.draw_polyline(PackedVector2Array([center + off - along * half_len * 0.95,
			center + off + across * wob - along * half_len * 0.3, center + off - across * wob + along * half_len * 0.3,
			center + off + along * half_len * 0.95]), Color(WOOD_DARK.lerp(INK, burn), a), 1.0)
	var knot := center + along * r.randf_range(-30, -18) + across * 1.5
	b.draw_colored_polygon(_ellipse_on(knot, along, 3.2, 1.8), Color(WOOD_DARK.lerp(INK, burn), a))
	b.draw_line(center + across * half_w * 0.85 - along * half_len, center + across * half_w * 0.85 + along * half_len,
		Color(WOOD_LIGHT.lerp(INK, burn), a * 0.9), 1.1)
	# barbs of splinter along the edges
	for k in 4:
		var t := r.randf_range(-0.85, 0.85)
		var side := 1.0 if k % 2 else -1.0
		var p := center + along * half_len * t + across * half_w * side
		b.draw_colored_polygon(PackedVector2Array([p, p + along * 4.0, p + across * side * 3.0 + along * 1.0]), Color(wood, a))
	# red ink stains with drips
	if burn < 0.7:
		for k in 2:
			var p := center + along * r.randf_range(-35, 30) + across * r.randf_range(-3, 3)
			var blob := PackedVector2Array()
			for q in 7:
				blob.append(p + Vector2.from_angle(TAU * q / 7.0) * r.randf_range(1.5, 3.8))
			b.draw_colored_polygon(blob, Color(RED_INK, a * (1.0 - burn)))
			b.draw_line(p, p + Vector2(0, r.randf_range(4, 9)), Color(RED_INK, a * (1.0 - burn)), 1.2)
	# nails and bent staples
	for k in 3:
		_nail(b, center + along * lerpf(-36.0, 36.0, k / 2.0) + across * r.randf_range(-2.5, 2.5), a, false)
	for k in 2:
		var p := center + along * r.randf_range(-28, 28) + across * half_w * (1.0 if k else -1.0)
		var o := across * (1.0 if k else -1.0)
		b.draw_polyline(PackedVector2Array([p - along * 2.5 - o * 1.5, p - along * 2.5 + o * 2.0,
			p + along * 2.5 + o * 2.5, p + along * 3.5 - o * 0.5]), Color(IRON, a), 1.2)
	# light chars it: glowing edges, sparks
	if burn > 0.05 and _shield > 0.02:
		var glow := Color(EMBER, a * minf(burn * 2.0, 1.0))
		for k in 2:
			var side := across * half_w * (1.0 if k else -1.0)
			b.draw_line(center + side - along * half_len, center + side + along * half_len, glow, 1.4)
		for k in 3:
			var sp := center + along * _rng.randf_range(-half_len, half_len) + across * _rng.randf_range(-half_w, half_w)
			b.draw_circle(sp, 1.2, Color(1.0, 0.85, 0.4, a))


func _nail(b: InkBatch, at: Vector2, a: float, big: bool) -> void:
	var rad := 2.6 if big else 1.5
	b.draw_circle(at, rad, Color(IRON.darkened(0.25), a))
	b.draw_circle(at + Vector2(-0.5, -0.5), rad * 0.5, Color(IRON.lightened(0.3), a))
	if big:  # its point comes out the side, bent
		b.draw_polyline(PackedVector2Array([at + Vector2(2, 1), at + Vector2(8, 3), at + Vector2(10, 7)]), Color(IRON, a), 1.5)


func _ellipse_on(c0: Vector2, along: Vector2, ra: float, rb: float) -> PackedVector2Array:
	var across := Vector2(-along.y, along.x)
	var out := PackedVector2Array()
	for q in 10:
		var t := TAU * q / 10.0
		out.append(c0 + along * cos(t) * ra + across * sin(t) * rb)
	return out


func _rot(poly: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(_rot1(p, pivot, angle))
	return out


func _rot1(p: Vector2, pivot: Vector2, angle: float) -> Vector2:
	return pivot + (p - pivot).rotated(angle)


func damage_default() -> float:
	return 2.0  # shove
