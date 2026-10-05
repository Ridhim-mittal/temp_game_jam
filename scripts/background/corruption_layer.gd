extends Node2D
## Shade deleting the city, painted over the skyline: redaction bars, red
## graffiti that drips, ink bleeding off rooftops, glitch slices, pinned error
## notes and sagging cables. Generated per slot along x (seeded, endless).
## Put inside a ComicParallax at the near skyline's scroll_scale; coordinates
## are screen space at the reference camera (see comic_parallax.gd).

const INK := Color(0.02, 0.02, 0.03)
const RED := Color(0.72, 0.05, 0.1)
const NOTE := Color(0.96, 0.93, 0.82)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const CHEWY = preload("res://assets/fonts/Chewy-Regular.ttf")
const WORDS := ["DELETE", "CORRUPTED", "SCRAPPED_BUILDING_04", "CORRUPTED DATA", "SCRAPPER BUILDING_04",
	"ERROR", "SAFE ZONE?", "NOT FOUND", "DELETE"]
const NOTES := ["ERROR: CHARACTER\nNOT FOUND", "ERROR: FILE\nNOT FOUND", "PAGE 3\nMISSING", "DO NOT\nDRAW HIM",
	"SCRAPPED\nNOT FOUND"]

@export var seed := 11
@export var slot_width := 380.0
## Band of the screen the marks sit in (building faces).
@export var y_range := Vector2(150, 560)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var view := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var first := floori(view.position.x / slot_width) - 1
	var last := floori(view.end.x / slot_width) + 1
	for i in range(first, last + 1):
		_slot(i)


func _slot(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(i, seed))
	var x0 := i * slot_width
	for k in rng.randi_range(3, 5):  # redaction bars
		draw_rect(Rect2(x0 + rng.randf_range(0, slot_width - 60), rng.randf_range(y_range.x, y_range.y),
			rng.randf_range(50, 150), rng.randf_range(10, 22)), INK)
	for k in rng.randi_range(1, 3):  # ink bleeding off a roof
		var x := x0 + rng.randf_range(0, slot_width)
		var y := rng.randf_range(y_range.x, y_range.x + 120)
		var l := rng.randf_range(80, 220) * (0.85 + 0.15 * sin(_time * 0.7 + x))
		draw_rect(Rect2(x, y, 4, l), RED)
		draw_circle(Vector2(x + 2, y + l), 3.5, RED)
	if rng.randf() < 0.8:
		_graffiti(Vector2(x0 + rng.randf_range(10, slot_width * 0.5), rng.randf_range(y_range.x + 40, y_range.y - 40)),
			WORDS[rng.randi() % WORDS.size()], rng.randi_range(22, 50), rng.randf_range(-0.12, 0.08))
	if rng.randf() < 0.5:
		var g := Rect2(x0 + rng.randf_range(0, slot_width - 120), rng.randf_range(y_range.x, y_range.y), rng.randf_range(90, 180), rng.randf_range(7, 12))
		var jit := sin(_time * 23.0 + i) * 6.0
		draw_rect(Rect2(g.position + Vector2(jit + 4, 0), g.size), Color(0.1, 0.8, 0.95, 0.55))
		draw_rect(Rect2(g.position + Vector2(jit - 4, 0), g.size), Color(0.95, 0.2, 0.6, 0.55))
		draw_rect(Rect2(g.position + Vector2(jit, 0), g.size), Color(0.16, 0.1, 0.26, 0.92))
	if rng.randf() < 0.35:
		_note(Vector2(x0 + rng.randf_range(0, slot_width - 130), rng.randf_range(y_range.y - 160, y_range.y - 40)),
			NOTES[rng.randi() % NOTES.size()], rng.randf_range(-0.1, 0.1))
	if rng.randf() < 0.45:  # a cable sagging to the next slot
		var a := Vector2(x0 + rng.randf_range(0, 80), rng.randf_range(y_range.x + 60, y_range.x + 160))
		var b := Vector2(x0 + slot_width + rng.randf_range(0, 80), rng.randf_range(y_range.x + 60, y_range.x + 160))
		var pts := PackedVector2Array()
		for k in 13:
			var t := k / 12.0
			pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 40.0))
		draw_polyline(pts, INK, 3.0)


func _graffiti(p: Vector2, text: String, size: int, rot: float) -> void:
	draw_set_transform(p, rot)
	draw_string_outline(FONT, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.1, 0.0, 0.02, 0.6))
	draw_string(FONT, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, RED)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	for k in int(w / 14.0):
		var x := 6.0 + k * 14.0 + sin(k * 3.7) * 4.0
		var l := 8.0 + absf(sin(k * 2.3)) * size * 0.6
		draw_line(Vector2(x, 2), Vector2(x, 2 + l), RED, 2.0)
		draw_circle(Vector2(x, 3 + l), 2.0, RED)
	draw_set_transform(Vector2.ZERO)


func _note(p: Vector2, text: String, rot: float) -> void:
	draw_set_transform(p, rot)
	draw_rect(Rect2(-3, -3, 128, 52), Color(0, 0, 0, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(122, -6), Vector2(122, 30), Vector2(110, 46),
		Vector2(90, 38), Vector2(70, 46), Vector2(-6, 46)]), NOTE)
	var lines := text.split("\n")
	for k in lines.size():
		draw_string(CHEWY, Vector2(2, 14 + k * 18), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, RED)
	draw_set_transform(Vector2.ZERO)
