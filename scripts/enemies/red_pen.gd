extends "res://scripts/enemies/enemy_base.gd"
## The Red Pen: the Writer's editor, a giant red fountain pen with a green
## eyeshade, one squinting eye, a gold nib and a little window of red ink.
## Art for the 2.5D boss (scripts/clearing/red_pen_3d.gd drives it through
## MonsterPuppet); in a 2D level it just floats and glares.
## Origin = its lowest point (the nib tip when it points down).

enum State { HOVER, AIM, STAB, STUCK, STRIKE, WRITE, DAZZLED }  # same order as red_pen_3d.gd

const RED := Color(0.86, 0.13, 0.15)
const RED_DARK := Color(0.55, 0.05, 0.1)
const RED_LIGHT := Color(1.0, 0.45, 0.42)
const GOLD := Color(0.98, 0.76, 0.28)
const GOLD_DARK := Color(0.72, 0.46, 0.12)
const SILVER := Color(0.82, 0.84, 0.9)
const VISOR := Color(0.25, 0.68, 0.32)
const VISOR_DARK := Color(0.12, 0.42, 0.2)
const IRIS := Color(0.62, 0.46, 0.14)
const LEN := 130.0  # nib tip to cap end
const WID := 34.0

@export var hp := 18

var state := State.HOVER
## Lean of the pen (radians, 0 = nib straight down), set by the 3D boss.
var tilt := 0.6
## 0..1: how angry (phase 2 reddens the eye and shakes the body).
var rage := 0.0
## Fraction of red ink left in the window.
var ink := 1.0


func _ready() -> void:
	add_to_group("boss")
	setup(Vector2(60, 140), hp)
	set_harmful(false)


func _tick(_delta: float) -> void:
	velocity = Vector2.ZERO  # in a 2D level it just hangs there
	face_player()


func paint(c: CanvasItem) -> void:
	var t := tilt
	if state == State.DAZZLED:
		t = 1.45
	# rotate about the middle, keeping the lowest point on the origin
	var h := LEN * 0.5 * absf(cos(t)) + WID * 0.5 * absf(sin(t))
	var mid := Vector2(0, -h)
	var shake := Vector2(sin(time * 41.0), cos(time * 37.0)) * 1.5 * rage
	c.draw_set_transform(mid + shake, t, Vector2.ONE)
	# local frame: +Y towards the nib, nib tip at (0, LEN/2), cap end at (0, -LEN/2)
	var tip := LEN * 0.5
	_draw_nib(c, tip)
	_draw_body(c, tip)
	_draw_eye(c, tip, t)
	_draw_visor(c, tip)
	c.draw_set_transform(Vector2.ZERO)
	_draw_drip(c, mid, t)


func _draw_nib(c: CanvasItem, tip: float) -> void:
	var nib := PackedVector2Array([Vector2(0, tip), Vector2(-12, tip - 22), Vector2(-11, tip - 30), Vector2(11, tip - 30), Vector2(12, tip - 22)])
	for poly in Geometry2D.offset_polygon(nib, 2.5, Geometry2D.JOIN_ROUND):
		c.draw_colored_polygon(poly, INK)
	c.draw_colored_polygon(nib, GOLD)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, tip), Vector2(-12, tip - 22), Vector2(-11, tip - 30), Vector2(-3, tip - 30)]), GOLD_DARK)
	# scrollwork, slit and breather hole
	c.draw_arc(Vector2(-4, tip - 22), 3.5, -1.0, 2.2, 6, GOLD_DARK, 1.2)
	c.draw_arc(Vector2(4, tip - 22), 3.5, 0.9, 4.1, 6, GOLD_DARK, 1.2)
	c.draw_line(Vector2(0, tip - 1), Vector2(0, tip - 16), INK, 1.5)
	c.draw_circle(Vector2(0, tip - 17), 2.2, INK)
	# wet red ink on the very tip
	c.draw_circle(Vector2(0, tip - 1.5), 2.2, RED)


func _draw_body(c: CanvasItem, tip: float) -> void:
	var top := -LEN * 0.5
	var grip := tip - 30.0
	var w := WID * 0.5
	var body := PackedVector2Array()
	# capsule from the grip up to a round cap end
	body.append(Vector2(w - 3, grip))
	for i in 9:
		var a := TAU * 0.5 * i / 8.0
		body.append(Vector2(cos(a) * w, top + w - sin(a) * w))
	body.append(Vector2(-w + 3, grip))
	for poly in Geometry2D.offset_polygon(body, 3.0, Geometry2D.JOIN_ROUND):
		c.draw_colored_polygon(poly, INK)
	c.draw_colored_polygon(body, RED)
	# shading: dark side, glossy highlight
	c.draw_rect(Rect2(w * 0.35, top + 8, w * 0.55, grip - top - 10), RED_DARK)
	c.draw_rect(Rect2(-w * 0.62, top + 10, 4, grip - top - 18), RED_LIGHT)
	# grip section and rings
	c.draw_rect(Rect2(-w + 3, grip - 8, WID - 6, 8), RED_DARK)
	for y in [grip - 9.0, top + 62.0]:
		c.draw_rect(Rect2(-w - 1, y - 2.5, WID + 2, 5), SILVER)
		c.draw_line(Vector2(-w - 1, y + 2.5), Vector2(w + 1, y + 2.5), INK, 1.2)
	# the ink window: red ink sloshing behind glass
	var win := Rect2(-w + 6, grip - 34, WID - 12, 22)
	c.draw_rect(win.grow(1.5), INK)
	c.draw_rect(win, Color(0.95, 0.92, 0.9))
	var depth := win.size.y * clampf(ink, 0.0, 1.0)
	if depth > 4.0:
		var level := win.end.y - depth
		var slosh := minf(1.6, depth * 0.3)
		var wave := PackedVector2Array()
		for i in 7:
			var x := win.position.x + win.size.x * i / 6.0
			wave.append(Vector2(x, clampf(level + sin(time * 4.0 + i * 1.1) * slosh, win.position.y, win.end.y - 2.0)))
		wave.append(win.end)
		wave.append(Vector2(win.position.x, win.end.y))
		c.draw_colored_polygon(wave, RED)
	elif depth > 0.5:
		c.draw_rect(Rect2(win.position.x, win.end.y - depth, win.size.x, depth), RED)
	c.draw_line(win.position + Vector2(3, 3), win.position + Vector2(3, win.size.y - 3), Color(1, 1, 1, 0.7), 2.0)
	# gold clip along the far side
	var clip := PackedVector2Array([Vector2(w - 2, top + 14), Vector2(w + 7, top + 16), Vector2(w + 8, top + 56), Vector2(w + 4, top + 62), Vector2(w + 1, top + 56), Vector2(w + 1, top + 18)])
	for poly in Geometry2D.offset_polygon(clip, 2.0, Geometry2D.JOIN_ROUND):
		c.draw_colored_polygon(poly, INK)
	c.draw_colored_polygon(clip, GOLD)
	c.draw_circle(Vector2(w + 4, top + 59), 2.5, GOLD_DARK)


func _draw_eye(c: CanvasItem, _tip: float, t: float) -> void:
	var top := -LEN * 0.5
	var e := Vector2(-2, top + 40)
	# the eye stays upright-ish in the world: undo most of the body's lean
	var look := to_player().rotated(-t).normalized() if _player else Vector2(1, 0)
	var open := 0.45  # squinting, cunning
	match state:
		State.AIM, State.STRIKE, State.WRITE:
			open = 1.0
		State.STAB:
			open = 0.8
		State.STUCK:
			open = 0.25 + 0.15 * sin(time * 9.0)
		State.DAZZLED:
			open = 0.0
	var rx := 11.0
	var ry := 9.0
	if open <= 0.01:
		# shut tight, with lashes and "dazzle" tears
		c.draw_arc(e, rx, 0.2, PI - 0.2, 10, INK, 3.0)
		for k in 3:
			var a := 0.6 + k * 0.95
			c.draw_line(e + Vector2.from_angle(a) * rx, e + Vector2.from_angle(a) * (rx + 5), INK, 2.0)
		return
	var sclera := ell(e, rx + 2.5, ry + 2.5, 18)
	c.draw_colored_polygon(sclera, INK)
	c.draw_colored_polygon(ell(e, rx, ry, 18), PALE.lerp(Color(1.0, 0.7, 0.7), rage * 0.6))
	if rage > 0.2:  # bloodshot
		for k in 3:
			var a := PI * (0.8 + k * 0.2)
			c.draw_line(e + Vector2.from_angle(a) * rx, e + Vector2.from_angle(a) * rx * 0.55, Color(0.9, 0.2, 0.2, rage), 1.0)
	var p := e + look * Vector2(4.5, 3.0)
	c.draw_circle(p, 6.0, IRIS)
	for k in 8:  # iris detail
		var a := TAU * k / 8.0
		c.draw_line(p + Vector2.from_angle(a) * 2.6, p + Vector2.from_angle(a) * 5.6, IRIS.darkened(0.35), 1.0)
	c.draw_circle(p, 2.6, INK)
	c.draw_circle(p + Vector2(-1.5, -1.8), 1.2, Color.WHITE)
	# heavy red lid comes down over the top: the squint
	var lid := ry * 2.0 * (1.0 - open)
	if lid > 0.5:
		c.draw_rect(Rect2(e.x - rx - 3, e.y - ry - 3, rx * 2 + 6, lid + 3), RED)
		c.draw_line(Vector2(e.x - rx - 2, e.y - ry + lid), Vector2(e.x + rx + 2, e.y - ry + lid - 1), INK, 3.0)
	# angry brow under the visor
	c.draw_line(Vector2(e.x - rx - 3, e.y - ry - 5), Vector2(e.x + rx + 3, e.y - ry - 1 + 3.0 * rage), INK, 3.5)


func _draw_visor(c: CanvasItem, _tip: float) -> void:
	var top := -LEN * 0.5
	var w := WID * 0.5
	var y := top + 20.0
	# headband round the barrel, brim jutting out over the eye
	c.draw_rect(Rect2(-w - 2, y - 4, WID + 4, 9).grow(2.0), INK)
	c.draw_rect(Rect2(-w - 2, y - 4, WID + 4, 9), VISOR)
	var brim := PackedVector2Array([Vector2(-w - 2, y + 4), Vector2(-w - 26, y + 15), Vector2(-w - 20, y + 20), Vector2(-w + 6, y + 9)])
	for poly in Geometry2D.offset_polygon(brim, 2.5, Geometry2D.JOIN_ROUND):
		c.draw_colored_polygon(poly, INK)
	c.draw_colored_polygon(brim, VISOR)
	c.draw_line(Vector2(-w - 4, y + 7), Vector2(-w - 21, y + 15), VISOR_DARK, 2.5)
	c.draw_rect(Rect2(-w - 2, y - 4, WID + 4, 3), VISOR.lightened(0.3))


func _draw_drip(c: CanvasItem, mid: Vector2, t: float) -> void:
	if state == State.DAZZLED:
		return
	var tip := mid + Vector2(0, LEN * 0.5).rotated(t)
	var k := fmod(time * 0.7, 1.0)
	if k < 0.6:  # a drop swells on the nib...
		c.draw_circle(tip + Vector2(0, 3.0 * k / 0.6), 1.5 + 2.5 * k / 0.6, RED)
	else:  # ...and falls
		var f := (k - 0.6) / 0.4
		c.draw_circle(tip + Vector2(0, 4.0 + 40.0 * f * f), 3.5 * (1.0 - f * 0.5), Color(RED, 1.0 - f))
