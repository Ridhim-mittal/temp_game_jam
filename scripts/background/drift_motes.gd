@tool
extends Node2D
## Floating comic "dust": inked dots and little 4-point sparkles drifting
## through the air between the skyline and the playfield (the Hollow Knight
## floating-particle depth cue). Wraps around the view, so it never runs out.

const ComicView = preload("res://scripts/background/comic_view.gd")

@export var seed := 11
@export var count := 60
## Size of the repeating tile the motes wrap in (should exceed the screen).
@export var tile := Vector2(1600, 1000)
@export var drift := Vector2(-10.0, -16.0)
@export var size_range := Vector2(1.5, 4.0)
@export var color := Color(1.0, 0.97, 0.78)
@export var ink := Color(0.1, 0.06, 0.25, 0.8)
@export_range(0.0, 1.0) var sparkle_chance := 0.25

var _motes: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		_motes.append({
			"p": Vector2(rng.randf() * tile.x, rng.randf() * tile.y),
			"v": drift * rng.randf_range(0.5, 1.5),
			"s": rng.randf_range(size_range.x, size_range.y),
			"ph": rng.randf() * TAU,
			"spark": rng.randf() < sparkle_chance,
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = ComicView.local_view(self).rect
	var origin := rect.get_center() - tile * 0.5
	for m in _motes:
		var p: Vector2 = m.p + m.v * _time + Vector2(sin(_time * 0.7 + m.ph), cos(_time * 0.5 + m.ph)) * 12.0
		p = origin + (p - origin).posmodv(tile)
		var twinkle := 0.6 + 0.4 * sin(_time * 2.0 + m.ph * 3.0)
		var s: float = m.s * twinkle
		if m.spark:
			var r := s * 2.6
			var q := s * 0.6
			var star := PackedVector2Array([
				p + Vector2(0, -r), p + Vector2(q, -q), p + Vector2(r, 0), p + Vector2(q, q),
				p + Vector2(0, r), p + Vector2(-q, q), p + Vector2(-r, 0), p + Vector2(-q, -q)])
			draw_colored_polygon(star, Color(color, twinkle))
		else:
			draw_circle(p, s + 1.2, Color(ink, ink.a * twinkle))
			draw_circle(p, s, Color(color, twinkle))
