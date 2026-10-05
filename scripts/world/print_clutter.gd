@tool
extends Node2D
## Printing junk lying on the street of Shade's city (no collision): bales of
## CMYK-edged comic pages, fallen rollers, spilled ink puddles and loose
## sheets, placed along `length` from a seed. Origin = street top, left end.

const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.93, 0.9, 0.81)
const STEEL := Color(0.4, 0.44, 0.52)
const CYAN := Color(0.1, 0.78, 0.92)
const MAGENTA := Color(0.96, 0.22, 0.62)
const YELLOW := Color(1.0, 0.86, 0.2)

@export var length := 4000.0:
	set(value):
		length = value
		queue_redraw()
@export var seed := 3:
	set(value):
		seed = value
		queue_redraw()
## Average gap between pieces of junk.
@export var spacing := 340.0


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := rng.randf_range(80, spacing)
	while x < length:
		match rng.randi() % 4:
			0: _bale(Vector2(x, 0), rng.randi_range(5, 10), rng)
			1: _roller(Vector2(x, -22), rng.randf_range(90, 140))
			2: _puddle(Vector2(x, 2), rng.randf_range(50, 110), [CYAN, MAGENTA, YELLOW][rng.randi() % 3])
			3: _sheets(Vector2(x, -2), rng)
		x += spacing * rng.randf_range(0.6, 1.4)


func _bale(p: Vector2, n: int, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(60, 90)
	for k in n:
		var y := p.y - 7.0 - k * 7.0
		var x := p.x + sin(k * 1.9 + p.x) * 4.0
		draw_rect(Rect2(x - w * 0.5 - 1, y - 1, w + 2, 8), INK)
		var band: Color = [CYAN, MAGENTA, YELLOW][k % 3]
		draw_rect(Rect2(x - w * 0.5, y, w, 6), PAPER)
		draw_rect(Rect2(x - w * 0.5, y + 4, w, 2), band)


func _roller(c: Vector2, l: float) -> void:
	var r := 22.0
	var rect := Rect2(c - Vector2(l * 0.5, r), Vector2(l, r * 2.0))
	draw_rect(rect.grow(3), INK)
	draw_rect(rect, STEEL)
	draw_rect(Rect2(rect.position + Vector2(0, r * 0.3), Vector2(l, r * 0.35)), STEEL.lightened(0.35))
	var bands := [CYAN, MAGENTA, YELLOW]
	for i in 3:
		draw_rect(Rect2(rect.position.x + l * (0.2 + i * 0.22), rect.position.y, l * 0.12, r * 2.0), bands[i])
	for sx in [-1.0, 1.0]:
		draw_set_transform(c + Vector2(sx * l * 0.5, 0), 0.0, Vector2(0.35, 1.0))
		draw_circle(Vector2.ZERO, r + 3.0, INK)
		draw_circle(Vector2.ZERO, r, STEEL.darkened(0.2))
		draw_circle(Vector2.ZERO, r * 0.3, INK)
		draw_set_transform(Vector2.ZERO)


func _puddle(c: Vector2, r: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, 0.14))
	draw_circle(Vector2.ZERO, r + 4.0, INK)
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.45))
	draw_set_transform(Vector2.ZERO)


func _sheets(p: Vector2, rng: RandomNumberGenerator) -> void:
	for k in 4:
		draw_set_transform(p + Vector2(k * 22.0 - 30.0, 0), rng.randf_range(-0.6, 0.6), Vector2(1.0, 0.45))
		draw_rect(Rect2(-14, -10, 28, 20), INK)
		draw_rect(Rect2(-13, -9, 26, 18), PAPER)
		for l in 3:
			draw_line(Vector2(-10, -4 + l * 5), Vector2(10, -4 + l * 5), Color(0.5, 0.55, 0.7), 1.0)
		draw_set_transform(Vector2.ZERO)
