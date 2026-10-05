extends Control
## Screen-space top layer of depth_backdrop.gd: black silhouettes fringing
## the top and bottom of the screen (they slide a little faster than the
## level, which is what sells them as "in front of the camera"), drifting
## motes of light, and a vignette. Sits under the HUD.

const Style = preload("res://scripts/depth/depth_style.gd")
const BLACK := Color(0.0, 0.0, 0.01)
const SPACING := 46.0

var backdrop: Node2D
var camera_center := Vector2.ZERO
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var theme: int = backdrop.theme_at(camera_center.y)
	var pal: Dictionary = backdrop.palette_at(camera_center.y)
	var rng := RandomNumberGenerator.new()
	# motes: fixed pattern that drifts and wraps
	for i in 22:
		rng.seed = 900 + i
		var base := Vector2(rng.randf() * s.x, rng.randf() * s.y)
		var drift := Vector2(sin(_time * 0.3 + i) * 30.0 - camera_center.x * 0.08, -_time * rng.randf_range(4.0, 12.0) - camera_center.y * 0.08)
		var p := Vector2(fposmod(base.x + drift.x, s.x), fposmod(base.y + drift.y, s.y))
		var r := rng.randf_range(1.0, 2.4)
		var a := 0.55 + 0.45 * sin(_time * 1.3 + i * 2.1)
		draw_texture_rect(backdrop.glow_texture, Rect2(p - Vector2(r, r) * 7.0, Vector2(r, r) * 14.0), false, Color(pal.accent, 0.5 * a))
		draw_circle(p, r, Color(1, 1, 0.92, 0.9 * a))
	# fringe: one silhouette per slot, slots slide with the camera
	var shift := camera_center.x * 1.3
	var first := int(floor(shift / SPACING)) - 1
	for i in range(first, first + int(s.x / SPACING) + 3):
		rng.seed = hash(Vector2i(i, theme))
		var x := i * SPACING - shift + rng.randf_range(-12.0, 12.0)
		match theme:
			Style.CAVERN:
				var l := 14.0 + pow(rng.randf(), 2.6) * 110.0
				var hw := rng.randf_range(6.0, 16.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - hw, -2), Vector2(x + hw, -2), Vector2(x + rng.randf_range(-3, 3), l)]), BLACK)
				var h := rng.randf_range(10.0, 46.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x + 14, s.y + 2), Vector2(x + 18 + rng.randf_range(-10, 10), s.y - h),
					Vector2(x + 22, s.y + 2)]), BLACK)
			Style.ARCHIVE:
				if posmod(i, 5) == 0:
					var span := SPACING * 4.2
					var sag := rng.randf_range(30.0, 70.0)
					var pts := PackedVector2Array()
					for k in 13:
						pts.append(Vector2(x + span * k / 12.0, sin(k / 12.0 * PI) * sag - 4.0))
					draw_polyline(pts, BLACK, 3.0, true)
			Style.WORKS:
				if posmod(i, 9) == 0:
					draw_line(Vector2(x, -10), Vector2(x + rng.randf_range(-60, 60), 54), BLACK, 12.0)
	# vignette
	var edge := Color(0, 0, 0, 0.62)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, 130), Vector2(0, 130)]), PackedColorArray([edge, edge, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y - 130), Vector2(s.x, s.y - 130), Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([clear, clear, edge, edge]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, s.y), Vector2(0, s.y)]), PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(s.x - 200, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - 200, s.y)]),
		PackedColorArray([clear, edge, edge, clear]))
