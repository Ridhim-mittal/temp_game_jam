extends Node2D
## The author's light: a cone from the moon (night_sky.gd) down onto the street,
## fixed to the screen, drawn over the skyline but under the playfield
## (give it a z_index between the two). `street_y` is in screen px.

@export var street_y := 612.0
@export var moon := Vector2(0.5, 0.08)
@export var color := Color(1.0, 0.97, 0.8)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position = cam.get_screen_center_position() - get_viewport_rect().size * 0.5
	queue_redraw()


func _draw() -> void:
	var s := get_viewport_rect().size
	var m := moon * s
	var flicker := 0.9 + 0.1 * sin(_time * 1.7)
	draw_colored_polygon(PackedVector2Array([m + Vector2(-30, 0), m + Vector2(30, 0), Vector2(m.x + 180, street_y),
		Vector2(m.x - 180, street_y)]), Color(color, 0.12 * flicker))
	draw_colored_polygon(PackedVector2Array([m + Vector2(-15, 0), m + Vector2(15, 0), Vector2(m.x + 80, street_y),
		Vector2(m.x - 80, street_y)]), Color(color, 0.12 * flicker))
	# pool of light on the street
	for k in 4:
		var pts := PackedVector2Array()
		var rx := 220.0 - k * 45.0
		for j in 24:
			var a := TAU * j / 24.0
			pts.append(Vector2(m.x + cos(a) * rx, street_y + sin(a) * rx * 0.12))
		draw_colored_polygon(pts, Color(color, 0.06 + k * 0.04))
