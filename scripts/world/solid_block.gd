@tool
extends StaticBody2D
## Solid rectangle of terrain. Set `size` in the inspector; the collision
## shape is generated at runtime and the block draws itself (also in-editor).
## Later this is where "light makes the world real" toggling will plug in.

@export var size := Vector2(128, 32):
	set(value):
		size = value
		queue_redraw()
@export var color := Color(0.12, 0.09, 0.17):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, color)
	draw_rect(r, Color(0.05, 0.05, 0.05), false, 3.0)
