@tool
extends StaticBody2D
## Wooden scaffold plank: jump up through it from below, land on top.
## Warm wood so it reads apart from solid (ink-violet) terrain.

const INK := Color(0.05, 0.03, 0.1)

@export var size := Vector2(160, 16):
	set(value):
		size = value
		queue_redraw()
@export var wood := Color(0.82, 0.5, 0.26)
## Draw diagonal braces under the plank.
@export var braces := true


func _ready() -> void:
	collision_layer = 1
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.one_way_collision = true
	add_child(cs)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if braces:
		for sx in [-1.0, 1.0]:
			var top := Vector2(sx * size.x * 0.3, r.end.y)
			var foot := Vector2(sx * size.x * 0.12, r.end.y + 34.0)
			draw_line(top, foot, INK, 7.0)
			draw_line(top, foot, wood.darkened(0.35), 4.0)
	draw_rect(r.grow(2.5), INK)
	draw_rect(r, wood)
	draw_rect(Rect2(r.position, Vector2(size.x, 4)), wood.lightened(0.25))
	var x := r.position.x + 30.0
	while x < r.end.x - 10.0:  # plank seams + nails
		draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), wood.darkened(0.4), 1.5)
		draw_circle(Vector2(x - 6, r.position.y + size.y * 0.5), 1.4, INK)
		x += 34.0
