extends Node2D
## SHADE'S ERASER: the Writer's eraser, come down to rub Vesper out of the
## book (from the "Animated SCARY ERASER Boss" sheet). A tall block eraser:
## a worn pink rubber top with a chipped crown, a torn tan cardboard sleeve
## with a blue band down one side ("SHADE'S ERASER"), a skull of a face
## printed on the sleeve (angry white eyes, a nose hole, a gaping maw of
## jagged teeth), pink rubber underneath, and thin black scribbled arms with
## clawed hands. Simple, low-colour, thick outlines. It never keeps still: it
## vibrates at a high frame rate (`jitter`), and when it RUBS it tilts and
## scrubs from side to side throwing pink eraser shavings and grey dust.
## Drawn in code (InkBatch: one draw call); origin = the middle of its base.
##
## eraser_chase.gd drives it (where it is, `rubbing`, `lunge`); touching it
## costs half a bottle (a hurt area on the enemy layer, group "enemy").

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const InkBits = preload("res://scripts/effects/ink_bits.gd")
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
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

## Size of the block, px (Vesper is about 52 px tall).
@export var block := Vector2(210, 330)
## 0..1: scrubbing from side to side (the rub).
@export var rubbing := 0.0
## How hard it shakes all the time.
@export var jitter := 1.0
## Which way it's going (1 right, -1 left): it leans into it.
var heading := 1.0
## 0..1: the maw opening (a roar).
var roar := 0.0
## Lean forward into a lunge (0..1).
var lunge := 0.0

var _time := 0.0
var _batch := InkBatch.new()
var _rng := RandomNumberGenerator.new()
var _hurt: Area2D
var _crumbs := 0.0


func _ready() -> void:
	z_index = 5
	_hurt = Area2D.new()
	_hurt.collision_layer = 4  # the enemy layer: Vesper's hurtbox finds it
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	_hurt.add_to_group("enemy")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(block.x * 0.8, block.y * 0.9)
	cs.shape = r
	cs.position = Vector2(0, -block.y * 0.45)
	_hurt.add_child(cs)
	add_child(_hurt)


## Turns the hurt area on or off (off during cutscenes).
func set_harmful(on: bool) -> void:
	if on and not _hurt.is_in_group("enemy"):
		_hurt.add_to_group("enemy")
	elif not on and _hurt.is_in_group("enemy"):
		_hurt.remove_from_group("enemy")


func _process(delta: float) -> void:
	_time += delta
	# shavings and dust while it rubs
	if rubbing > 0.05:
		_crumbs += delta * (10.0 * rubbing)
		while _crumbs >= 1.0:
			_crumbs -= 1.0
			_shavings()
	queue_redraw()


func _shavings() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var at := global_position + Vector2(randf_range(-block.x * 0.5, block.x * 0.5), -6.0)
	var fx := InkBits.burst(tree, at, 3, 260.0, Vector2(-heading, -0.6), 0.0)
	if fx:
		fx.modulate = Color(1.6, 0.75, 0.8)  # pink rubber crumbs, not ink
	if randf() < 0.5:
		var dust := InkBits.burst(tree, at, 2, 120.0, Vector2(-heading, -0.3), 1.0)
		if dust:
			dust.modulate = Color(0.75, 0.75, 0.78, 0.7)


func _draw() -> void:
	# high frame rate jitter: re-seeded 24 times a second
	var f := int(_time * 24.0)
	_rng.seed = f * 7 + 13
	var j := jitter * (1.0 + rubbing * 1.5)
	var w := block.x
	var h := block.y
	# the rub: a fast scrub side to side with a tilt; a lunge leans it in
	var scrub := sin(_time * 22.0) * rubbing
	var tilt := scrub * 0.22 + heading * lunge * 0.35
	var shift := Vector2(scrub * 26.0, -absf(scrub) * 6.0)
	var shake := Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5)) * j
	var xf := Transform2D(tilt, shift + shake)
	_batch.draw_set_transform_matrix(xf)
	# arms behind the block, reaching
	for side: float in [-1.0, 1.0]:
		_arm(side, w, h, j)
	# bottom rubber
	var bot := _box(Rect2(-w * 0.42, -h * 0.24, w * 0.84, h * 0.24), 6.0, j)
	_batch.draw_colored_polygon(bot, PINK)
	_batch.draw_colored_polygon(_box(Rect2(w * 0.18, -h * 0.24, w * 0.24, h * 0.24), 4.0, j), PINK_DARK)
	_outline(bot, 5.0)
	# top rubber: a worn crown with a chipped top edge
	var top := PackedVector2Array()
	var ty := -h
	var crown := 8
	top.append(Vector2(-w * 0.44, -h * 0.66))
	for i in crown + 1:
		var x := -w * 0.44 + w * 0.88 * i / crown
		var dip := (_chip(i) * 14.0 if i > 0 and i < crown else 0.0)
		top.append(Vector2(x + _rng.randf_range(-1, 1) * j, ty + 10.0 + dip + absf(x) * 0.06))
	top.append(Vector2(w * 0.44, -h * 0.66))
	_batch.draw_colored_polygon(top, PINK)
	# its shaded right face and a pale worn patch
	_batch.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, ty + 16), Vector2(w * 0.44, ty + 22), Vector2(w * 0.44, -h * 0.66), Vector2(w * 0.2, -h * 0.66)]), PINK_DARK)
	_batch.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.3, ty + 22), Vector2(-w * 0.08, ty + 18), Vector2(-w * 0.12, ty + 36), Vector2(-w * 0.32, ty + 40)]), PINK_LIGHT)
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
		sleeve.append(Vector2(x + _rng.randf_range(-1, 1) * j, sy0 + tear))
	sleeve.append(Vector2(w * 0.5, sy1))
	# a torn flap at the bottom right
	sleeve.append(Vector2(w * 0.3, sy1 + 14))
	sleeve.append(Vector2(w * 0.18, sy1 + 4))
	_batch.draw_colored_polygon(sleeve, TAN)
	# shading on the sleeve's right
	_batch.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, sy0 + 20), Vector2(w * 0.5, sy0 + 10), Vector2(w * 0.5, sy1), Vector2(w * 0.3, sy1 + 10)]), Color(TAN_DARK, 0.55))
	# the blue band down the left with the brand on it
	var band := PackedVector2Array([Vector2(-w * 0.5, sy0 + 8), Vector2(-w * 0.26, sy0 + 26), Vector2(-w * 0.24, sy1 - 6), Vector2(-w * 0.5, sy1)])
	_batch.draw_colored_polygon(band, BLUE)
	_batch.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.31, sy0 + 22), Vector2(-w * 0.26, sy0 + 26), Vector2(-w * 0.24, sy1 - 6), Vector2(-w * 0.3, sy1 - 4)]), BLUE_DARK)
	_outline(band, 3.0)
	_outline(sleeve, 5.0)
	# the face, printed on the sleeve: a skull
	_face(w, h, j)
	_batch.draw_set_transform_matrix(Transform2D.IDENTITY)
	_batch.flush(self)
	# the brand, written down the band (text can't go through the batch)
	draw_set_transform_matrix(xf * Transform2D(-PI * 0.5, Vector2(-w * 0.36, sy1 - 14)))
	draw_string(FONT, Vector2(0, 8), "SHADE'S", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BONE)
	draw_string(FONT, Vector2(0, 30), "ERASER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, BONE)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A fixed "random" chip size per index (the shape doesn't boil, only the jitter).
func _chip(i: int) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)


func _box(r: Rect2, _corner: float, j: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c: Vector2 in corners:
		pts.append(c + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * j * 0.8)
	return pts


func _outline(pts: PackedVector2Array, width: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	_batch.draw_polyline(loop, INK, width)


func _face(w: float, h: float, j: float) -> void:
	var cy := -h * 0.47
	# deep sockets, then angry eyes under heavy brows
	for side: float in [-1.0, 1.0]:
		var ex := side * w * 0.17 + w * 0.03
		var socket := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			socket.append(Vector2(ex, cy - 34) + Vector2(cos(a) * 30.0, sin(a) * 24.0) + Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5)) * j)
		_batch.draw_colored_polygon(socket, Color(TAN_DARK, 0.9))
		# the eye: an almond cut off by a brow slanting down to the nose
		var eye := PackedVector2Array()
		for i in 9:
			var a := PI + PI * i / 8.0
			eye.append(Vector2(ex, cy - 30) + Vector2(cos(a) * 21.0, sin(a) * 15.0))
		eye.append(Vector2(ex + 21.0, cy - 30))
		var brow_in := Vector2(ex - side * 22.0, cy - 30 - 4.0)
		var brow_out := Vector2(ex + side * 22.0, cy - 30 - 22.0)
		var cut := PackedVector2Array()
		for p in eye:
			var t := (p.x - brow_in.x) / (brow_out.x - brow_in.x)
			var limit := lerpf(brow_in.y, brow_out.y, clampf(t, 0.0, 1.0))
			cut.append(Vector2(p.x, maxf(p.y, limit)))
		cut.append(Vector2(ex + 18.0, cy - 22))
		cut.append(Vector2(ex - 18.0, cy - 22))
		_batch.draw_colored_polygon(cut, BONE)
		_outline(cut, 3.0)
		_batch.draw_circle(Vector2(ex - side * 3.0, cy - 26) + Vector2(_rng.randf_range(-1, 1), 0), 4.5, INK)
		_batch.draw_line(brow_in + Vector2(0, -2), brow_out + Vector2(0, -2), INK, 5.0)
	# nose hole
	_batch.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.03, cy - 10), Vector2(w * 0.03 - 9, cy + 6), Vector2(w * 0.03 + 9, cy + 6)]), INK)
	# the maw: wide, gaping, jagged teeth top and bottom
	var open := 0.55 + 0.45 * roar + 0.08 * sin(_time * 9.0)
	var mw := w * 0.62
	var mh := 46.0 + 40.0 * open
	var mc := Vector2(w * 0.03, cy + 30 + mh * 0.5)
	var maw := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		maw.append(mc + Vector2(cos(a) * mw * 0.5, sin(a) * mh * 0.5) + Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5)) * j)
	_batch.draw_colored_polygon(maw, MAW)
	var n := 9
	for i in n:
		var x := mc.x - mw * 0.42 + mw * 0.84 * (i + 0.5) / n
		var edge := sqrt(maxf(1.0 - pow((x - mc.x) / (mw * 0.5), 2.0), 0.0)) * mh * 0.5
		var tw := mw * 0.84 / n * 0.5
		var tl := mh * (0.34 + 0.18 * _chip(i + 60))
		var top := PackedVector2Array([Vector2(x - tw, mc.y - edge + 2), Vector2(x + tw, mc.y - edge + 2), Vector2(x + _rng.randf_range(-1, 1), mc.y - edge + tl)])
		_batch.draw_colored_polygon(top, BONE)
		_batch.draw_polyline(PackedVector2Array([top[0], top[2], top[1]]), INK, 1.5)
		var bl := mh * (0.26 + 0.16 * _chip(i + 80))
		var bot := PackedVector2Array([Vector2(x - tw, mc.y + edge - 2), Vector2(x + tw, mc.y + edge - 2), Vector2(x + _rng.randf_range(-1, 1), mc.y + edge - bl)])
		_batch.draw_colored_polygon(bot, BONE)
		_batch.draw_polyline(PackedVector2Array([bot[0], bot[2], bot[1]]), INK, 1.5)
	_outline(maw, 4.0)
	# cracks and creases in the cardboard round the face
	for i in 4:
		var a := Vector2(_chip(i + 100) * w * 0.8 - w * 0.4, cy - 60 + _chip(i + 110) * 90.0)
		_batch.draw_polyline(PackedVector2Array([a, a + Vector2(12, 10), a + Vector2(6, 24)]), Color(TAN_DARK, 0.9), 2.0)


## A thin scribbled arm out of the sleeve's side, ending in a clawed hand.
func _arm(side: float, w: float, h: float, j: float) -> void:
	var shoulder := Vector2(side * w * 0.46, -h * 0.5)
	var reach := 0.5 + 0.5 * sin(_time * 3.0 + side)
	var grab := lunge + rubbing * 0.5
	var elbow := shoulder + Vector2(side * (46.0 + 10.0 * reach), 30.0 - 20.0 * grab)
	var hand := elbow + Vector2(side * (24.0 + 30.0 * grab), 46.0 - 50.0 * grab + 6.0 * sin(_time * 7.0 + side))
	for k in 3:  # scribbled: a few overlapping strokes
		var o := Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)) * j
		_batch.draw_polyline(PackedVector2Array([shoulder + o, elbow + o * 1.5, hand + o]), INK, 3.5 - k)
	# the claws
	for i in 4:
		var d := Vector2(side, 0.4).normalized().rotated((i - 1.5) * 0.45 * side)
		var p := hand
		var line := PackedVector2Array([p])
		for s in 3:
			d = d.rotated(0.35 * side)
			p += d * 11.0
			line.append(p + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * j)
		_batch.draw_polyline(line, INK, 2.6)
