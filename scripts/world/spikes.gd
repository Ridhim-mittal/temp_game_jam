@tool
extends StaticBody2D
const OnScreen = preload("res://scripts/core/on_screen.gd")
## Spike hazard. Player passes through it (hazard layer), takes damage and is
## put back on the last safe ground (player.gd, never in a loop). Can be pogo'd with a down-slash.

@export var size := Vector2(128, 24):
	set(value):
		size = value
		queue_redraw()
## Same danger colour as the crawlers' outline: yellow = this hurts.
@export var danger_color := Color(1.0, 0.86, 0.2)
@export var steel_light := Color(0.86, 0.88, 0.95)
@export var steel_dark := Color(0.42, 0.44, 0.58)

const INK := Color(0.05, 0.03, 0.1)
const PLATE_H := 7.0

var _time := 0.0


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


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if OnScreen.near(self, size.x):
		queue_redraw()  # travelling glint


func _draw() -> void:
	var half := size * 0.5
	var count := maxi(int(size.x / 20.0), 1)
	var w := size.x / count
	var base_y := half.y - PLATE_H
	# Whole-strip silhouette, used for the danger + ink outlines.
	var outline := PackedVector2Array([Vector2(-half.x, half.y)])
	for i in count:
		var x0 := -half.x + i * w
		outline.append(Vector2(x0, base_y))
		outline.append(Vector2(x0 + w * 0.5, -half.y))
	outline.append(Vector2(half.x, base_y))
	outline.append(Vector2(half.x, half.y))
	for poly in Geometry2D.offset_polygon(outline, 5.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, danger_color)
	for poly in Geometry2D.offset_polygon(outline, 2.0, Geometry2D.JOIN_MITER):
		draw_colored_polygon(poly, INK)

	# Teeth: lit left face + shaded right face reads as a 3D pyramid.
	var glint_x := fposmod(_time * 260.0, size.x + 600.0) - half.x - 300.0
	for i in count:
		var x0 := -half.x + i * w
		var tip := Vector2(x0 + w * 0.5, -half.y)
		var mid := Vector2(x0 + w * 0.5, base_y)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, base_y), tip, mid]), steel_light)
		draw_colored_polygon(PackedVector2Array([mid, tip, Vector2(x0 + w, base_y)]), steel_dark)
		draw_line(tip, mid, INK, 1.0)
		var glint := clampf(1.0 - absf(tip.x - glint_x) / 40.0, 0.0, 1.0)
		if glint > 0.0:
			draw_circle(tip + Vector2(-1, 3), 2.5 * glint, Color(1, 1, 1, glint))

	# Base plate with hazard stripes and rivets.
	var plate := Rect2(-half.x, base_y, size.x, PLATE_H)
	draw_rect(plate, INK)
	var x := -half.x + 2.0
	while x < half.x - 2.0:
		var x1 := minf(x + 6.0, half.x - 2.0)
		var stripe := PackedVector2Array([Vector2(x, plate.end.y - 1.5), Vector2(x + 3.0, base_y + 1.5),
			Vector2(minf(x + 9.0, half.x - 2.0), base_y + 1.5), Vector2(x1, plate.end.y - 1.5)])
		draw_colored_polygon(stripe, danger_color)
		x += 12.0
	for i in count:
		draw_circle(Vector2(-half.x + (i + 0.5) * w, base_y + PLATE_H * 0.5), 1.2, steel_light)
