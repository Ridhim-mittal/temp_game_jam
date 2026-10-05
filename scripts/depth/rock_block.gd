@tool
extends StaticBody2D
## Plain solid terrain for the "depth" levels: a flat near-black rectangle
## with collision and no outline, so neighbouring blocks merge into one mass.
## The lit edges are separate depth_trim.gd nodes.

@export var size := Vector2(200, 200):
	set(value):
		size = value
		queue_redraw()
@export var color := Color(0.015, 0.02, 0.045):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	collision_layer = 1
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)


func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size).grow(0.5), color)
