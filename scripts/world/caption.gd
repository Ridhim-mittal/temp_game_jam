@tool
extends Node2D
## A yellow narrator caption box pinned in the level (comic tutorial text).
## Lines are separated by "\n"; the box sizes itself to them.

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)

@export_multiline var text := "CAPTION":
	set(value):
		text = value
		queue_redraw()
@export var font_size := 30:
	set(value):
		font_size = value
		queue_redraw()
@export var tilt := -0.03:
	set(value):
		tilt = value
		queue_redraw()
@export var paper := Color(1.0, 0.9, 0.45)


var _pad := false  # drawn for a controller (InputSetup.using_pad)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not ("CLICK" in text):
		return
	var ins := get_node_or_null("/root/InputSetup")
	if ins and ins.using_pad != _pad:
		_pad = ins.using_pad
		queue_redraw()  # its mouse buttons become the pad's


func _draw() -> void:
	var ins := get_node_or_null("/root/InputSetup") if not Engine.is_editor_hint() else null
	var shown: String = ins.words(text) if ins else text
	var lines := shown.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var lh := font_size * 1.15
	var box := Rect2(-w * 0.5 - 14, -lh * lines.size() * 0.5 - 10, w + 28, lh * lines.size() + 14)
	draw_set_transform(Vector2.ZERO, tilt)
	draw_rect(Rect2(box.position + Vector2(5, 6), box.size), Color(INK, 0.35))
	draw_rect(box.grow(3.0), INK)
	draw_rect(box, paper)
	for i in lines.size():
		var lw := FONT.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(FONT, Vector2(-lw * 0.5, box.position.y + 6 + lh * (i + 0.8)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	draw_set_transform(Vector2.ZERO)
