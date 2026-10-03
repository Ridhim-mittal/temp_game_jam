@tool
extends Node2D
## Aerial-perspective veil between the backdrop and the playfield: a flat,
## light wash that lowers the backdrop's contrast so the dark, outlined
## characters in front always read first (the Hollow Knight value rule:
## the playfield owns the strongest darks and lights).

const ComicView = preload("res://scripts/background/comic_view.gd")

@export var color := Color(0.8, 0.9, 0.98, 0.2):
	set(value):
		color = value
		queue_redraw()

var _last_xf := Transform2D()


func _process(_delta: float) -> void:
	var xf := get_global_transform_with_canvas()
	if xf != _last_xf:
		_last_xf = xf
		queue_redraw()


func _draw() -> void:
	draw_rect(ComicView.local_view(self).rect.grow(8.0), color)
