extends Node2D
const OnScreen = preload("res://scripts/core/on_screen.gd")
## Draw surface for a monster. It sits inside the outline CanvasGroup and
## simply asks its owner script to paint on it every frame.

var painter: Node


func _process(_delta: float) -> void:
	if OnScreen.near(self, 200.0):
		queue_redraw()


func _draw() -> void:
	if painter:
		painter.paint(self)
