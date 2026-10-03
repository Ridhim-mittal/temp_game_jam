@tool
extends Node2D
## Infinite rolling hill silhouette with an ink outline and halftone shading
## that thickens toward the bottom. Use with the comic_halftone material.

const ComicView = preload("res://scripts/background/comic_view.gd")

@export var seed := 5
@export var base_y := 420.0
@export var amplitude := 60.0
@export var wavelength := 600.0
@export var color := Color(0.95, 0.62, 0.6)
@export var ink := Color(0.3, 0.16, 0.4)
@export var outline_width := 2.0
@export_range(0.0, 1.0) var haze := 0.35
@export var haze_color := Color(0.62, 0.9, 0.93)
## Halftone strength (crest, foot).
@export var shade := Vector2(0.1, 0.9)
@export var step := 12.0

var _last_xf := Transform2D()


func _process(_delta: float) -> void:
	var xf := get_global_transform_with_canvas()
	if Engine.is_editor_hint() or xf != _last_xf:
		_last_xf = xf
		queue_redraw()


func height_at(x: float) -> float:
	var p := float(seed) * 1.618
	var t := x / maxf(wavelength, 1.0) * TAU
	var h := sin(t + p) * 0.55 + sin(t * 2.3 + p * 3.1) * 0.3 + sin(t * 5.7 + p * 7.3) * 0.15
	# flatten the valleys a little so the crests read as separate hills
	return base_y - amplitude * (maxf(h, -0.6) + 0.6)


func _draw() -> void:
	var rect: Rect2 = ComicView.local_view(self).rect
	var bottom := maxf(rect.end.y, base_y) + 8.0
	var crest_c := ComicView.halftone(_hz(color), shade.x)
	var foot_c := ComicView.halftone(_hz(color), shade.y)
	var x := floorf(rect.position.x / step) * step - step
	var crest := PackedVector2Array()
	while x <= rect.end.x + step:
		var y := height_at(x)
		var y2 := height_at(x + step)
		draw_primitive(
			PackedVector2Array([Vector2(x, y), Vector2(x + step, y2), Vector2(x + step, bottom), Vector2(x, bottom)]),
			PackedColorArray([crest_c, crest_c, foot_c, foot_c]), PackedVector2Array())
		crest.append(Vector2(x, y))
		x += step
	if crest.size() > 1:
		draw_polyline(crest, _hz(ink), outline_width)


func _hz(c: Color) -> Color:
	var h := c.lerp(haze_color, haze)
	h.a = 1.0
	return h
