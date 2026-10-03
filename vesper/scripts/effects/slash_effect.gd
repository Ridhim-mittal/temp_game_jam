extends Node2D
## Ink crescent drawn for a nail slash. Points along +X; rotate to aim.

var radius := 40.0
var color := Color(0.08, 0.08, 0.1)


func _ready() -> void:
	z_index = 10
	scale = Vector2(0.7, 0.7)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.16).set_delay(0.05)
	t.chain().tween_callback(queue_free)


func _draw() -> void:
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var a := lerpf(-1.2, 1.2, float(i) / steps)
		pts.append(Vector2(-radius * 0.5, 0) + Vector2(cos(a), sin(a)) * radius)
	for i in range(steps, -1, -1):
		var a := lerpf(-1.1, 1.1, float(i) / steps)
		pts.append(Vector2(-radius * 0.65, 0) + Vector2(cos(a), sin(a)) * radius * 0.8)
	draw_colored_polygon(pts, color)
