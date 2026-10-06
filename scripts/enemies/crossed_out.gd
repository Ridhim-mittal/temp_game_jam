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
# A slim, stooped ghoul in a tattered brown coat and a battered top hat,
# white X eyes (red on a windup) over a grin of jagged teeth, a black clawed
# hand gripping its shield: an X of two splintered, nailed planks with a
# red-ink stain. Light chars the planks, edges glowing, until they crumble.
# About Vesper's height; the strokes boil at 12 fps (one InkBatch call).

const COAT := Color(0.32, 0.24, 0.18)
const COAT_DARK := Color(0.18, 0.13, 0.1)
const HAT := Color(0.3, 0.24, 0.19)
const WOOD := Color(0.58, 0.39, 0.23)
const WOOD_DARK := Color(0.35, 0.21, 0.12)
const IRON := Color(0.6, 0.6, 0.64)
const RED_INK := Color(0.62, 0.08, 0.06)
const BONE := Color(0.96, 0.94, 0.87)
const MAW := Color(0.2, 0.02, 0.03)
const EMBER := Color(1.0, 0.52, 0.12)
## Tatter lengths along the coat's hem, back to front.
const TATTERS := [4.0, 1.5, 5.0, 2.0, 4.5, 1.0]

var _batch := InkBatch.new()
var _rng := RandomNumberGenerator.new()


func paint(c: CanvasItem) -> void:
	var b := _batch
	_rng.seed = int(time * 12.0)  # the strokes boil
	var walking := absf(velocity.x) > 10.0
	var step := sin(time * 7.0) if walking else 0.0
	var lean := 0.05
	var push := 0.0
	var gape := 0.2 + 0.1 * sin(time * 1.7)
	match state:
		State.WINDUP:
			lean = -0.18
			push = -5.0
			gape = 0.7
		State.SHOVE:
			lean = 0.22
			push = 10.0
			gape = 1.0
		State.RECOVER:
			lean = 0.1
			push = 2.0
			gape = 0.4
	var bob := sin(time * 2.3) * 0.8 + absf(step) * 1.0
	for i in 2:  # thin legs under the coat
		var fx := -5.0 + 9.0 * i + step * (3.5 if i == 0 else -3.5)
		var lift := maxf(0.0, step * (1.0 if i == 0 else -1.0)) * 2.0
		b.draw_line(Vector2(fx, -10), Vector2(fx, -lift), INK, 2.6)
		b.draw_line(Vector2(fx - 1.5, -lift), Vector2(fx + 4.0, -lift), INK, 2.2)
	b.draw_set_transform(Vector2.ZERO, lean)
	_coat(b, bob)
	_head(b, Vector2(4, -45 + bob), gape)
	if _shield > 0.02:
		var x0 := Vector2(17.0 + push, -25.0 + bob * 0.5)
		_plank(b, x0, -0.42, 1)
		_plank(b, x0, 0.42, 2)
		_nail(b, x0, 1.0, 1.9)  # the spike through the crossing
	_arm(b, push, bob)
	b.draw_set_transform(Vector2.ZERO)
	b.flush(c)


func _j(v: Vector2, amount := 0.5) -> Vector2:
	return v + Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


func _coat(b: InkBatch, bob: float) -> void:
	var top := -41.0 + bob
	var hem := -8.0
	var poly := PackedVector2Array([_j(Vector2(8, top)), _j(Vector2(-3, top - 3)), _j(Vector2(-10, top + 4)),
		_j(Vector2(-13, top + 18)), _j(Vector2(-16, hem))])
	var n := TATTERS.size()
	for i in n:  # a ragged hem, swaying
		var x := lerpf(-16.0, 12.0, (i + 0.5) / n)
		poly.append(_j(Vector2(x - 2.0, hem - 1.5)))
		poly.append(_j(Vector2(x + sin(time * 3.1 + i * 1.7) * 1.2, hem + TATTERS[i])))
	poly.append_array(PackedVector2Array([_j(Vector2(12, hem)), _j(Vector2(11, top + 14))]))
	b.draw_colored_polygon(poly, COAT)
	# the back in shadow, one fold line, a torn hole
	b.draw_colored_polygon(PackedVector2Array([_j(Vector2(-3, top - 2)), _j(Vector2(-10, top + 4)),
		_j(Vector2(-13, top + 18)), _j(Vector2(-16, hem)), _j(Vector2(-8, hem + 1)), _j(Vector2(-5, top + 14))]), COAT_DARK)
	b.draw_line(_j(Vector2(3, top + 8)), _j(Vector2(2, hem + 2)), COAT_DARK, 1.2)
	b.draw_colored_polygon(pts([-2, -20, 0, -22, 1.5, -19, -0.5, -17]), INK)


func _head(b: InkBatch, h: Vector2, gape: float) -> void:
	# a shadowed face
	b.draw_colored_polygon(PackedVector2Array([_j(h + Vector2(-6, -5)), _j(h + Vector2(7, -5)),
		_j(h + Vector2(8, 3)), _j(h + Vector2(3, 8)), _j(h + Vector2(-4, 8)), _j(h + Vector2(-7, 2))]), INK)
	# the grin
	var open := 1.8 + gape * 3.2
	var m := h + Vector2(0.5, 3.0)
	var maw := PackedVector2Array()
	for k in 7:
		var t := k / 6.0
		maw.append(m + Vector2(lerpf(-5.5, 6.5, t), -sin(t * PI) * 0.8))
	for k in 7:
		var t := 1.0 - k / 6.0
		maw.append(m + Vector2(lerpf(-5.5, 6.5, t), sin(t * PI) * open))
	b.draw_colored_polygon(maw, MAW)
	for k in 6:
		var t := (k + 0.5) / 6.0
		var x := lerpf(-5.5, 6.5, t)
		var up := m + Vector2(x, -sin(t * PI) * 0.8)
		var low := m + Vector2(x, sin(t * PI) * open)
		b.draw_colored_polygon(PackedVector2Array([up + Vector2(-0.9, 0), up + Vector2(0.9, 0), up + Vector2(0, 1.8)]), BONE)
		b.draw_colored_polygon(PackedVector2Array([low + Vector2(-0.8, 0), low + Vector2(0.8, 0), low + Vector2(0, -1.5)]), BONE)
	# X eyes
	var eye := Color(1.0, 0.35, 0.25) if state == State.WINDUP or state == State.SHOVE else BONE
	for ex: float in [-2.5, 3.5]:
		var e := h + Vector2(ex, -2.0)
		b.draw_line(e + Vector2(-1.7, -1.7), e + Vector2(1.7, 1.7), eye, 1.5)
		b.draw_line(e + Vector2(1.7, -1.7), e + Vector2(-1.7, 1.7), eye, 1.5)
	# the battered top hat, tipped back, a dent in the crown
	var brim := h + Vector2(0, -5)
	var tilt := -0.12
	b.draw_colored_polygon(_rot(PackedVector2Array([_j(brim + Vector2(-6, 0)), _j(brim + Vector2(-7, -9)),
		_j(brim + Vector2(-5, -14)), _j(brim + Vector2(0, -12.5)), _j(brim + Vector2(5, -14)),
		_j(brim + Vector2(6, 0))]), brim, tilt), HAT)
	b.draw_colored_polygon(_rot(PackedVector2Array([brim + Vector2(-6.5, -0.5), brim + Vector2(6.5, -0.5),
		brim + Vector2(6.3, -3), brim + Vector2(-6.8, -3)]), brim, tilt), HAT.darkened(0.45))
	b.draw_colored_polygon(_rot(ell(brim, 11.0, 2.4, 12), brim, tilt), HAT.darkened(0.15))


## The arm: a ragged sleeve, a black clawed hand hooked over the planks.
func _arm(b: InkBatch, push: float, bob: float) -> void:
	var sh := Vector2(6, -34 + bob)
	var el := Vector2(12, -24 + bob)
	var hand := Vector2(19 + push, -20 + bob * 0.5)
	b.draw_line(sh, el, COAT, 5.0)
	b.draw_line(el, hand, INK, 2.4)
	b.draw_circle(hand, 2.4, INK)
	for k in 3:  # claws
		var a := -0.6 + k * 0.6
		var mid := hand + Vector2.from_angle(a) * 3.5
		b.draw_line(hand, mid, INK, 1.5)
		b.draw_line(mid, mid + Vector2.from_angle(a + 1.0) * 3.0, INK, 1.2)


## One splintered plank of the X: grain, two nails, a red-ink stain.
func _plank(b: InkBatch, center: Vector2, angle: float, seed_n: int) -> void:
	var burn := 1.0 - _shield
	var a := clampf(_shield * 2.0, 0.0, 1.0)
	var wood := WOOD.lerp(INK, burn * 0.9)
	var half_len := 24.0
	var half_w := 3.7
	var along := Vector2.from_angle(angle - PI * 0.5)
	var across := Vector2(-along.y, along.x)
	var r := RandomNumberGenerator.new()
	r.seed = seed_n * 977
	var poly := PackedVector2Array()
	for k in 3:  # splintered ends
		var t := lerpf(-1.0, 1.0, k / 2.0)
		poly.append(_j(center + along * (half_len + (r.randf_range(2, 5) if k == 1 else 0.0)) + across * t * half_w, 0.3))
	for k in 3:
		var t := lerpf(1.0, -1.0, k / 2.0)
		poly.append(_j(center - along * (half_len + (r.randf_range(2, 5) if k != 1 else 0.0)) + across * t * half_w, 0.3))
	b.draw_colored_polygon(poly, Color(wood, a))
	var grain := Color(WOOD_DARK.lerp(INK, burn), a)
	b.draw_line(center - along * half_len * 0.9 - across * 1.3, center + along * half_len * 0.9 - across * 1.3, grain, 0.9)
	b.draw_line(center - along * half_len * 0.7 + across * 1.6, center + along * half_len * 0.6 + across * 1.6, grain, 0.9)
	if burn < 0.7 and seed_n == 1:
		var p := center + along * 12.0
		b.draw_colored_polygon(ell(p, 2.4, 2.0, 8), Color(RED_INK, a * (1.0 - burn)))
		b.draw_line(p, p + Vector2(0, 5), Color(RED_INK, a * (1.0 - burn)), 1.0)
	for k in 2:
		_nail(b, center + along * (18.0 if k else -18.0), a, 1.0)
	if burn > 0.05:  # light chars it: glowing edges
		var glow := Color(EMBER, a * minf(burn * 2.0, 1.0))
		for k in 2:
			var side := across * half_w * (1.0 if k else -1.0)
			b.draw_line(center + side - along * half_len, center + side + along * half_len, glow, 1.1)


func _nail(b: InkBatch, at: Vector2, a: float, rad: float) -> void:
	b.draw_circle(at, rad, Color(IRON.darkened(0.25), a))
	b.draw_circle(at + Vector2(-0.3, -0.3), rad * 0.5, Color(IRON.lightened(0.3), a))


func _rot(poly: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(pivot + (p - pivot).rotated(angle))
	return out


func damage_default() -> float:
	return 2.0  # shove
