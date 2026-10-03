@tool
extends Node2D
## Stand-in for the lamp until the real light mechanic exists: a fixed pool
## of light. Anything in the group "light" with a lights(point) method counts
## as light for the monsters (see enemy_base.gd), so the real lamp and ember
## only need to join that group and implement the same method.

@export var radius := 150.0:
	set(value):
		radius = value
		queue_redraw()
@export var color := Color(1.0, 0.9, 0.45, 0.28):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	add_to_group("light")
	z_index = -1


func lights(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.6, Color(color, color.a * 0.6))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, 0.8), 2.0)
