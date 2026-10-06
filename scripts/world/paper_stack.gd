@tool
extends StaticBody2D
## A bale of comic pages to climb on in Shade's City: stacked sheets with
## printer's colour edges and a CMYK-printed top, solid all round.
## Origin = bottom-left (on the street).

const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.93, 0.9, 0.81)
const CYAN := Color(0.12, 0.78, 0.92)
const MAGENTA := Color(0.96, 0.24, 0.62)
const YELLOW := Color(1.0, 0.86, 0.22)

@export var size := Vector2(120, 80):
	set(value):
		size = value
		queue_redraw()
		_update_shape()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	_update_shape()


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var r := RectangleShape2D.new()
	r.size = size
	_shape.shape = r
	_shape.position = Vector2(size.x * 0.5, -size.y * 0.5)


func _draw() -> void:
	var r := Rect2(Vector2(0, -size.y), size)
	draw_rect(r.grow(3), INK)
	var h := 7.0
	var y := r.end.y - h
	var k := 0
	while y >= r.position.y + 8.0:
		var x := sin(k * 1.7) * 3.0
		draw_rect(Rect2(x, y, size.x, h - 1), PAPER.darkened(0.07 * (k % 2)))
		draw_rect(Rect2(x, y + h - 3, size.x, 2), [CYAN, MAGENTA, YELLOW][k % 3])
		y -= h
		k += 1
	var top := Rect2(r.position, Vector2(size.x, 9))
	draw_rect(top.grow(1), INK)
	for i in 3:
		draw_rect(Rect2(top.position + Vector2(size.x * i / 3.0, 0), Vector2(size.x / 3.0, 9)), [CYAN, MAGENTA, YELLOW][i])
	draw_rect(Rect2(r.position, Vector2(size.x, 3)), Color(1.0, 0.97, 0.88))
