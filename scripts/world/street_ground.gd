@tool
extends StaticBody2D
## The street of Shade's corrupted city: a dark curb-stone slab with a pale lip
## so the line Vesper walks on reads at a glance against the busy skyline,
## joints every few metres and a halftone fade into the dark below.
## Origin = top-left corner of the walkable top.

@export var size := Vector2(4000, 400):
	set(value):
		size = value
		queue_redraw()
		_update_shape()
@export var face := Color(0.28, 0.27, 0.34)
@export var body := Color(0.16, 0.15, 0.21)
@export var lip := Color(0.5, 0.48, 0.58)
@export var joint_every := 200.0

const INK := Color(0.04, 0.03, 0.08)

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
	_shape.position = size * 0.5


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r.grow(3), INK)
	draw_rect(r, body)
	# kerb face: a lighter band under the lip, shading down into the body
	for i in 6:
		draw_rect(Rect2(0, 6 + i * 6.0, size.x, 6), face.lerp(body, i / 6.0))
	draw_rect(Rect2(0, 0, size.x, 4), lip)
	draw_rect(Rect2(0, 4, size.x, 2), INK)
	draw_rect(Rect2(0, 42, size.x, 3), Color(INK, 0.7))
	# joints between the slabs
	var x := joint_every * 0.5
	while x < size.x:
		draw_line(Vector2(x, 6), Vector2(x, 42), INK, 3.0)
		draw_line(Vector2(x + 3, 6), Vector2(x + 3, 42), Color(lip, 0.25), 1.0)
		x += joint_every
	# halftone dots fading into the dark
	var y := 60.0
	while y < minf(size.y, 200.0):
		var k := 1.0 - (y - 60.0) / 140.0
		var dx := 14.0
		var xx := fmod(y, 28.0) * 0.5
		while xx < size.x:
			draw_circle(Vector2(xx, y), 3.0 * k, Color(face, 0.55))
			xx += dx
		y += 12.0
