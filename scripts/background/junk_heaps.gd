extends Node2D
## Rubble banked along the street of Shade's city: mounds of scrapped pages,
## broken slabs, filing cabinets, fallen rollers, wires and CMYK paper bales,
## now and then a blood-red printing press half buried in it. Generated per
## slot (seeded, endless). Put in a ComicParallax just behind the playfield;
## coordinates are screen space at the reference camera, `base` = the street.

const INK := Color(0.05, 0.03, 0.1)
const MOUND := Color(0.4, 0.44, 0.52)
const SLAB := Color(0.55, 0.6, 0.66)
const PAPER := Color(0.9, 0.87, 0.78)
const METAL := Color(0.36, 0.42, 0.48)
const RED := Color(0.62, 0.03, 0.08)
const CYAN := Color(0.1, 0.78, 0.92)
const MAGENTA := Color(0.96, 0.22, 0.62)
const YELLOW := Color(1.0, 0.86, 0.2)

@export var seed := 5
@export var slot_width := 440.0
@export var base := 612.0
## Chance a slot has a heap / a press.
@export var heap_chance := 0.75
@export var press_chance := 0.3

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var view := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	for i in range(floori(view.position.x / slot_width) - 1, floori(view.end.x / slot_width) + 2):
		_slot(i)


func _slot(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(i, seed))
	if rng.randf() > heap_chance:
		return
	var cx := i * slot_width + rng.randf_range(80, slot_width - 80)
	var w := rng.randf_range(220, 380)
	var h := rng.randf_range(90, 190)
	var pts := PackedVector2Array([Vector2(cx - w * 0.5, base)])
	for k in 7:
		var t := (k + 1) / 8.0
		pts.append(Vector2(cx - w * 0.5 + w * t, base - h * sin(t * PI) * rng.randf_range(0.75, 1.1)))
	pts.append(Vector2(cx + w * 0.5, base))
	var outer := PackedVector2Array()
	for p in pts:
		outer.append(p + (p - Vector2(cx, base + 30)).normalized() * 4.0)
	draw_colored_polygon(outer, INK)
	draw_colored_polygon(pts, MOUND)
	# broken slabs and pages packed into it
	for k in 34:
		var x := cx + rng.randf_range(-w * 0.45, w * 0.45)
		var top := base - h * sin((x - (cx - w * 0.5)) / w * PI) * 0.9
		var y := rng.randf_range(top + 6.0, base - 6.0)
		var s := rng.randf_range(10.0, 26.0)
		draw_set_transform(Vector2(x, y), rng.randf_range(-0.8, 0.8))
		draw_rect(Rect2(-s * 0.5 - 1, -s * 0.35 - 1, s + 2, s * 0.7 + 2), INK)
		var r := rng.randf()
		var col := PAPER.darkened(rng.randf_range(0.0, 0.35)) if r < 0.55 else SLAB.darkened(rng.randf_range(0.0, 0.3))
		if r > 0.97:
			col = RED
		draw_rect(Rect2(-s * 0.5, -s * 0.35, s, s * 0.7), col)
		draw_set_transform(Vector2.ZERO)
	var pick := rng.randf()
	if pick < press_chance:
		_press(Vector2(cx + rng.randf_range(-40, 40), base - h * 0.75), rng.randf_range(0.45, 0.6), float(i))
	elif pick < 0.6:
		_cabinet(Vector2(cx - w * 0.25, base - h * 0.4), rng.randf_range(-0.2, 0.2))
	else:
		_roller(Vector2(cx + w * 0.15, base - h * 0.5), rng.randf_range(-0.4, 0.4))
	_bale(Vector2(cx + w * 0.42, base), rng.randi_range(4, 8))
	var wire := Vector2(cx - w * 0.1, base - h * 0.8)
	draw_polyline(PackedVector2Array([wire, wire + Vector2(40, 50), wire + Vector2(30, 100)]), INK, 3.0)


func _cabinet(p: Vector2, rot: float) -> void:
	draw_set_transform(p, rot)
	draw_rect(Rect2(-26, -50, 52, 100).grow(3), INK)
	draw_rect(Rect2(-26, -50, 52, 100), METAL)
	for k in 3:
		draw_rect(Rect2(-20, -44 + k * 31, 40, 26), METAL.darkened(0.25))
		draw_rect(Rect2(-7, -34 + k * 31, 14, 4), INK)
	draw_rect(Rect2(-18, -12, 36, 10), PAPER)
	draw_set_transform(Vector2.ZERO)


func _roller(p: Vector2, rot: float) -> void:
	draw_set_transform(p, rot)
	draw_rect(Rect2(-70, -16, 140, 32).grow(3), INK)
	draw_rect(Rect2(-70, -16, 140, 32), METAL)
	for k in 3:
		draw_rect(Rect2(-44 + k * 30, -16, 18, 32), [CYAN, MAGENTA, YELLOW][k])
	draw_set_transform(Vector2.ZERO)


func _bale(p: Vector2, n: int) -> void:
	for k in n:
		var y := p.y - 6.0 - k * 6.0
		var x := p.x + sin(k * 1.9) * 4.0
		draw_rect(Rect2(x - 31, y - 1, 62, 7), INK)
		draw_rect(Rect2(x - 30, y, 60, 5), PAPER if k % 3 != 2 else [CYAN, MAGENTA, YELLOW][k % 3])


## A printing press half buried in the heap, red ink running out of it.
func _press(p: Vector2, s: float, phase: float) -> void:
	draw_set_transform(p, 0.0, Vector2.ONE * s)
	var iron := Color(0.24, 0.2, 0.32)
	draw_rect(Rect2(-110, -230, 220, 110).grow(4), INK)
	draw_rect(Rect2(-110, -230, 220, 110), iron)
	draw_rect(Rect2(-8, -300, 16, 72).grow(3), INK)
	draw_rect(Rect2(-8, -300, 16, 72), iron.lightened(0.2))
	_gear(Vector2(0, -306), 30.0, _time * 0.6 + phase)
	_gear(Vector2(118, -176), 42.0, -_time * 0.9 + phase)
	for k in 2:
		var r := Rect2(-96, -116 + k * 34.0 - 14.0, 192, 28)
		draw_rect(r.grow(3), INK)
		draw_rect(r, iron.lightened(0.15) if k == 0 else RED)
	for s2 in [[-70, -200, 9], [60, -170, 12], [-30, -150, 7]]:
		draw_circle(Vector2(s2[0], s2[1]), s2[2], RED)
	for d in [[-80, -90, 90], [40, -90, 110], [76, -128, 150]]:
		var l: float = d[2] * (0.6 + 0.4 * fmod(_time * 0.5 + d[0] * 0.013, 1.0))
		draw_rect(Rect2(d[0] - 2.5, d[1], 5, l), RED)
		draw_circle(Vector2(d[0], d[1] + l), 4.5, RED)
	draw_set_transform(Vector2.ZERO)


func _gear(c: Vector2, r: float, a: float) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		pts.append(c + Vector2.from_angle(a + TAU * k / 24.0) * (r if k % 2 == 0 else r * 0.82))
	draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.88)
	draw_colored_polygon(inner, Color(0.24, 0.2, 0.32))
	for k in 4:
		draw_line(c, c + Vector2.from_angle(a + k * PI * 0.5) * r * 0.7, INK, 4.0)
	draw_circle(c, r * 0.22, INK)
	draw_circle(c, r * 0.12, RED)
