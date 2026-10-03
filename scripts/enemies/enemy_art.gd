extends Node2D
## Draw surface for a monster. It sits inside the outline CanvasGroup and
## simply asks its owner script to paint on it every frame.

var painter: Node


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if painter:
		painter.paint(self)
