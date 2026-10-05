extends Control
## Night sky over Shade's city (put in a CanvasLayer at the back): deep blue
## into violet, twinkling stars, van Gogh swirls, a constellation and the
## moon the author's light pours from (see moon_beam.gd).

@export var top := Color(0.05, 0.06, 0.18)
@export var horizon := Color(0.24, 0.16, 0.38)
## Where the moon sits, as a fraction of the screen.
@export var moon := Vector2(0.5, 0.08)

var _time := 0.0
var _stars: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 150:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.75), rng.randf_range(0.8, 1.9)])


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	for i in 40:
		var t := i / 39.0
		draw_rect(Rect2(0, t * s.y, s.x, s.y / 39.0 + 1.0), top.lerp(horizon, t))
	for i in _stars.size():
		var st: Array = _stars[i]
		draw_circle(st[0] * s, st[1], Color(1, 1, 1, 0.45 + 0.35 * sin(_time * 2.0 + i)))
	for sp in [[0.07, 0.08, 9], [0.78, 0.05, 11], [0.93, 0.2, 8], [0.33, 0.15, 7], [0.6, 0.04, 6], [0.86, 0.42, 7]]:
		_sparkle(Vector2(sp[0], sp[1]) * s, sp[2])
	for sw in [[0.67, 0.1, 34.0], [0.79, 0.21, 22.0], [0.24, 0.08, 26.0]]:
		for k in 3:
			draw_arc(Vector2(sw[0], sw[1]) * s, sw[2] - k * 8.0, _time * 0.3 + k, _time * 0.3 + k + 4.4, 24,
				Color(0.85, 0.9, 1.0, 0.55 - k * 0.12), 2.0)
	var con := [Vector2(0.84, 0.3), Vector2(0.89, 0.35), Vector2(0.93, 0.32), Vector2(0.95, 0.39), Vector2(0.91, 0.42)]
	for i in con.size() - 1:
		draw_line(con[i] * s, con[i + 1] * s, Color(0.8, 0.85, 1.0, 0.5), 1.5)
	for p in con:
		draw_circle(p * s, 3.0, Color(1, 1, 1, 0.9))
	var m := moon * s
	for k in 5:
		draw_circle(m, 90.0 - k * 14.0, Color(1.0, 0.97, 0.85, 0.06 + k * 0.03))
	draw_circle(m, 34.0, Color(1.0, 0.98, 0.9))
	draw_circle(m + Vector2(-10, -6), 7.0, Color(0.9, 0.88, 0.8))


func _sparkle(p: Vector2, r: float) -> void:
	var c := Color(1, 1, 1, 0.95)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.25, 0), p + Vector2(0, r),
		p + Vector2(-r * 0.25, 0)]), c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r, 0), p + Vector2(0, r * 0.25), p + Vector2(r, 0),
		p + Vector2(0, -r * 0.25)]), c)
