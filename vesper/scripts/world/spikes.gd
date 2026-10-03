@tool
extends StaticBody2D
## Spike hazard. Player passes through it (hazard layer), takes damage and is
## returned to the last safe ground. Can be pogo'd with a down-slash.

@export var size := Vector2(128, 24):
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("pogo")
	collision_layer = 8
	collision_mask = 0
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)


func _draw() -> void:
	var half := size * 0.5
	var count := maxi(int(size.x / 20.0), 1)
	var w := size.x / count
	for i in count:
		var x0 := -half.x + i * w
		var tri := PackedVector2Array([
			Vector2(x0, half.y), Vector2(x0 + w * 0.5, -half.y), Vector2(x0 + w, half.y)])
		draw_colored_polygon(tri, Color(0.3, 0.3, 0.34))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color(0.05, 0.05, 0.05), 2.0)
