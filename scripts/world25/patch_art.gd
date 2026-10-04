extends Node2D
## Patch, drawn in code: a scruffy dog cut out of paper, with torn edges, a
## floppy ear, a wagging tail and a too-big grin. Origin at the feet, faces
## +X. Idles by itself (wag, breathe, blink, the odd happy hop).

const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.95, 0.92, 0.84)
const SHADE := Color(0.82, 0.78, 0.7)
const PATCH := Color(0.62, 0.44, 0.3)

var _time := 0.0
var _blink := 0.0
var _blink_t := 2.0
var _hop := 0.0
var _hop_t := 3.0


func _process(delta: float) -> void:
	_time += delta
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.12
		_blink_t = randf_range(2.0, 4.0)
	_blink = maxf(_blink - delta, 0.0)
	_hop_t -= delta
	if _hop_t <= 0.0:
		_hop = 1.0
		_hop_t = randf_range(3.0, 6.0)
	_hop = maxf(_hop - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var lift := -sin(_hop * PI) * 6.0 + sin(_time * 2.5) * 0.6
	var wag := sin(_time * 14.0) * 0.5
	# legs
	for x in [-9.0, -4.0, 6.0, 11.0]:
		draw_line(Vector2(x, -8 + lift), Vector2(x + 0.5, 0), INK, 3.0)
	# tail
	var t0 := Vector2(-13, -16 + lift)
	var t1 := t0 + Vector2(-7, -9).rotated(wag)
	draw_line(t0, t1, PAPER, 5.0)
	draw_circle(t1, 2.5, PAPER)
	# body: a torn paper oval with a brown patch
	var body := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var r := Vector2(15.0, 8.5) * (1.0 + 0.08 * sin(i * 2.7))
		body.append(Vector2(0, -15 + lift) + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(body, PAPER)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -21 + lift), Vector2(2, -22 + lift), Vector2(1, -15 + lift), Vector2(-7, -14 + lift)]), PATCH)
	# head
	var h := Vector2(15, -26 + lift)
	var head := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		head.append(h + Vector2(cos(a) * 9.5, sin(a) * 8.5) * (1.0 + 0.06 * sin(i * 3.1)))
	draw_colored_polygon(head, PAPER)
	# snout and nose
	draw_colored_polygon(PackedVector2Array([h + Vector2(5, -1), h + Vector2(13, 1), h + Vector2(12, 6), h + Vector2(4, 5)]), SHADE)
	draw_circle(h + Vector2(13, 1.5), 2.6, INK)
	# grin
	draw_arc(h + Vector2(8, 3), 4.0, 0.2, 2.6, 8, INK, 1.6)
	# floppy ear (with the patch colour) and the perky one
	draw_colored_polygon(PackedVector2Array([h + Vector2(-5, -6), h + Vector2(1, -8), h + Vector2(-1, 6 + wag * 2.0), h + Vector2(-7, 3)]), PATCH)
	draw_colored_polygon(PackedVector2Array([h + Vector2(2, -7), h + Vector2(5, -16), h + Vector2(8, -6)]), PAPER)
	# eye
	if _blink > 0.0:
		draw_line(h + Vector2(4, -2), h + Vector2(8, -2), INK, 1.6)
	else:
		draw_circle(h + Vector2(6, -2), 2.4, INK)
		draw_circle(h + Vector2(6.8, -2.8), 0.8, PAPER)
	# a scrap of tape holding the head on
	draw_line(h + Vector2(-9, 4), h + Vector2(-3, 9), Color(0.95, 0.85, 0.5, 0.8), 3.0)
