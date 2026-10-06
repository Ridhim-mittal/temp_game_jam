@tool
extends Node2D
## Foreground silhouettes that pass IN FRONT of the player (Hollow Knight's
## strongest depth cue): railings and rubble (street lamps with glowing heads
## and light cones only with `lamps` on: they reach up into the playfield and
## hid signs like the panel door's). Sparse, dark and only along the bottom of the screen
## so they frame the action without hiding it. Put inside a ComicParallax
## with scroll_scale > 1 and a z_index above the playfield.

const ComicView = preload("res://scripts/background/comic_view.gd")

@export var seed := 3
@export var slot_width := 560.0
## Ground line of the foreground plane (just below the bottom of the screen).
@export var street_y := 760.0
@export var lamp_top_y := 140.0
@export var color := Color(0.06, 0.03, 0.13)
@export var rim_color := Color(0.6, 0.4, 0.95)
@export var lamp_color := Color(1.0, 0.9, 0.55)
@export_range(0.0, 1.0) var empty_chance := 0.3
## Tall street lamps in the foreground. Off: their slots get a railing instead.
@export var lamps := false

var _last_xf := Transform2D()
var _time := 0.0
var _visible_lamp := false


func _process(delta: float) -> void:
	_time += delta
	var xf := get_global_transform_with_canvas()
	# lamps flicker gently, so redraw while any are on screen
	if Engine.is_editor_hint() or xf != _last_xf or _visible_lamp:
		_last_xf = xf
		queue_redraw()


func _draw() -> void:
	_visible_lamp = false
	var rect: Rect2 = ComicView.local_view(self).rect
	if rect.end.y < lamp_top_y:
		return
	var i0 := floori(rect.position.x / slot_width) - 1
	var i1 := ceili(rect.end.x / slot_width) + 1
	for i in range(i0, i1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(seed, i, 104729))
		if rng.randf() < empty_chance:
			continue
		var x := (i + rng.randf_range(0.2, 0.8)) * slot_width
		match rng.randi() % 3:
			0:
				if lamps:
					_draw_lamp(x, rng)
					_visible_lamp = true
				else:
					_draw_railing(x, rng)
			1:
				_draw_railing(x, rng)
				_draw_rubble(x + rng.randf_range(80.0, 160.0), rng)
			2:
				_draw_rubble(x, rng)


func _draw_lamp(x: float, rng: RandomNumberGenerator) -> void:
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var top := lamp_top_y + rng.randf_range(0.0, 80.0)
	var arm_end := Vector2(x + dir * 70.0, top + 18.0)
	var head := arm_end + Vector2(0, 22)
	var flicker := 0.85 + 0.15 * sin(_time * 9.0 + x) * sin(_time * 3.1 + x * 0.3)

	# light cone + glow rings (flat comic bands, not a smooth gradient)
	var cone := PackedVector2Array([head + Vector2(-14, 6), head + Vector2(14, 6),
		Vector2(head.x + 150, street_y), Vector2(head.x - 150, street_y)])
	draw_colored_polygon(cone, Color(lamp_color, 0.09 * flicker))
	for k in 3:
		draw_circle(head, 30.0 + k * 24.0, Color(lamp_color, (0.2 - k * 0.055) * flicker))

	# pole with a flared base and curved arm
	draw_rect(Rect2(x - 7, top, 14, street_y - top + 40), color)
	draw_rect(Rect2(x + 4, top, 3, street_y - top + 40), rim_color.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 20, street_y + 40), Vector2(x - 10, street_y - 60),
		Vector2(x + 10, street_y - 60), Vector2(x + 20, street_y + 40)]), color)
	var arm := PackedVector2Array()
	for s in 9:
		var t := s / 8.0
		arm.append(Vector2(x + dir * 70.0 * t, top + 18.0 - sin(t * PI) * 26.0))
	draw_polyline(arm, color, 8.0)
	# lamp shade + bulb
	draw_colored_polygon(PackedVector2Array([arm_end + Vector2(-6, -2), arm_end + Vector2(6, -2),
		head + Vector2(16, 4), head + Vector2(-16, 4)]), color)
	draw_circle(head + Vector2(0, 5), 7.0, Color(lamp_color, flicker))


func _draw_railing(x: float, rng: RandomNumberGenerator) -> void:
	var length := rng.randf_range(160.0, 300.0)
	var top := street_y - 80.0
	for p in int(length / 32.0) + 1:
		draw_rect(Rect2(x + p * 32.0 - 3, top, 6, 120), color)
	draw_rect(Rect2(x - 6, top - 4, length + 12, 9), color)
	draw_line(Vector2(x - 6, top - 4), Vector2(x + length + 6, top - 4), rim_color, 2.0)
	draw_rect(Rect2(x - 6, top + 34, length + 12, 6), color)


func _draw_rubble(x: float, rng: RandomNumberGenerator) -> void:
	var width := rng.randf_range(140.0, 260.0)
	var pts := PackedVector2Array([Vector2(x - width * 0.5, street_y + 40)])
	var n := 7
	for k in n + 1:
		var t := float(k) / n
		var bump := sin(t * PI) * rng.randf_range(40.0, 75.0)
		pts.append(Vector2(x - width * 0.5 + width * t, street_y - bump))
	pts.append(Vector2(x + width * 0.5, street_y + 40))
	draw_colored_polygon(pts, color)
	draw_polyline(pts.slice(1, pts.size() - 1), rim_color.darkened(0.2), 2.0)
