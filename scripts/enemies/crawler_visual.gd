extends Node2D
## Procedural crawler art ("Ink Beetle"): glossy shell, animated legs,
## tracking eye, ink spines along the back that rise when it is angry and
## sweep back when it runs, and mandibles that open before it spits.
## Faces +X; parent flips via scale.x.
## All the public vars below are driven every frame by crawler.gd.

const INK := Color(0.06, 0.05, 0.06)
const OnScreen = preload("res://scripts/core/on_screen.gd")
const HAIR := Color(0.03, 0.03, 0.04)

@export var shell_color := Color(0.75, 0.27, 0.2)

var walk_phase := 0.0
var trail := 0.0       # 0..1   hair streaming backwards (speed)
var lift := 0.0        # -1..1  positive = falling, hair blown upward
var bristle := 0.0     # 0..1   hair stands on end (angry)
var aggro := false     # angry brow
var mouth_open := 0.0  # 0..1   spit wind-up
var look := Vector2(1, 0)  # local look direction for the pupil
var alert := 0.0       # >0 shows "!" above the head

var _time := 0.0
var _blink := 0.0
var _blink_timer := 2.0
var _strand_len: Array[float] = []
const STRANDS := 12


func _ready() -> void:
	_time = randf() * 10.0
	for i in STRANDS:
		_strand_len.append(randf_range(6.0, 10.0))


func _process(delta: float) -> void:
	_time += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(1.5, 4.0)
	_blink = maxf(_blink - delta, 0.0)
	alert = maxf(alert - delta, 0.0)
	if OnScreen.near(self, 200.0):
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 0.5), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.15))  # ground shadow
	draw_set_transform(Vector2.ZERO)
	_draw_legs()
	_draw_hair()
	_draw_body()
	_draw_face()
	_draw_fringe()
	if alert > 0.0:
		_draw_alert()


func _draw_legs() -> void:
	for i in 3:
		var base := Vector2(-12.0 + i * 12.0, -6.0)
		var ph := walk_phase + i * 2.1
		var foot := Vector2(base.x + sin(ph) * 5.0, -maxf(0.0, cos(ph)) * 4.0)
		var knee := (base + foot) * 0.5 + Vector2(4.0, -2.0)
		draw_polyline(PackedVector2Array([base, knee, foot]), INK, 3.0)


func _draw_body() -> void:
	# belly
	draw_rect(Rect2(-20, -9, 40, 7), shell_color.darkened(0.45))
	# shell dome
	var shell := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		shell.append(Vector2(cos(a) * 22.0, -6.0 + sin(a) * 22.0))
	draw_colored_polygon(shell, shell_color)
	# shell bands + spots + highlight
	draw_arc(Vector2(0, -6), 15.0, PI + 0.25, TAU - 0.25, 14, shell_color.darkened(0.25), 2.0)
	draw_circle(Vector2(-10, -14), 2.5, shell_color.darkened(0.35))
	draw_circle(Vector2(-3, -21), 2.0, shell_color.darkened(0.35))
	draw_arc(Vector2(0, -6), 18.0, PI + 0.45, PI + 1.2, 8, shell_color.lightened(0.4), 3.0)
	# ink outline
	var outline := shell.duplicate()
	outline.append(Vector2(20, -2))
	outline.append(Vector2(-20, -2))
	outline.append(shell[0])
	draw_polyline(outline, INK, 2.5)


func _draw_face() -> void:
	var eye := Vector2(11, -15)
	var open := 1.0 if _blink <= 0.0 else 0.15
	draw_set_transform(eye, 0.0, Vector2(1.0, 1.2 * open))
	draw_circle(Vector2.ZERO, 5.5, Color(0.97, 0.95, 0.9))
	draw_arc(Vector2.ZERO, 5.5, 0, TAU, 16, INK, 1.5)
	draw_set_transform(Vector2.ZERO)
	if open > 0.5:
		draw_circle(eye + look.limit_length(1.0) * 2.5, 2.6, INK)
	if aggro:
		draw_line(Vector2(4, -24), Vector2(16, -19), INK, 3.0)  # angry brow
	if mouth_open > 0.05:
		draw_circle(Vector2(19, -8), 1.5 + mouth_open * 4.0, INK)
		draw_circle(Vector2(19, -8), mouth_open * 2.0, Color(0.5, 0.05, 0.05))


func _draw_hair() -> void:
	# Ink spines along the shell (drawn behind it, so only the tips show).
	for i in STRANDS / 2:
		var t := float(i) / (STRANDS / 2 - 1)
		var theta := lerpf(-1.25, 0.35, t)  # angle from straight up
		var root := Vector2(sin(theta) * 19.0, -6.0 - cos(theta) * 19.0)
		var length := _strand_len[i] * (1.1 + 1.3 * bristle) + 4.0
		var ang := theta - trail * 0.45 - lift * 0.25 + sin(_time * 9.0 + i) * 0.05 * (1.0 + bristle)
		var dir := Vector2(sin(ang), -cos(ang))
		var side := dir.orthogonal() * 4.5
		draw_colored_polygon(PackedVector2Array([root - side, root + dir * length, root + side]), HAIR)


func _draw_fringe() -> void:
	# Mandibles: open wide while winding up a spit, twitch when angry.
	var gape := 0.25 + mouth_open * 0.9 + (0.12 * sin(_time * 14.0) if aggro else 0.0)
	for s in [-1.0, 1.0]:
		var base := Vector2(19, -7 + s * 2.0)
		var ang: float = s * gape
		var mid := base + Vector2(cos(ang), sin(ang)) * 7.0
		var tip := mid + Vector2(cos(ang - s * 0.9), sin(ang - s * 0.9)) * 6.0
		draw_polyline(PackedVector2Array([base, mid, tip]), INK, 3.0)
	# glossy highlight on the shell
	draw_arc(Vector2(0, -6), 13.0, PI + 0.55, PI + 1.05, 6, Color(1, 1, 1, 0.45), 2.5)


func _draw_alert() -> void:
	var font := ThemeDB.fallback_font
	var pos := Vector2(-5, -46 - (0.6 - alert) * 10.0)
	draw_string_outline(font, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, INK)
	draw_string(font, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.82, 0.15))
