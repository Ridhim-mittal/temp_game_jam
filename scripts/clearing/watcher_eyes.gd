@tool
extends Node3D
## Glowing eyes watching from the darkness below the cliffs.

const Toon = preload("res://scripts/clearing/toon.gd")
const EYES_SHADER = preload("res://shaders/clearing/glow_eyes.gdshader")

@export var color := Color(1.0, 0.12, 0.08):
	set(v):
		color = v
		_rebuild()
@export var size := 1.0:
	set(v):
		size = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	Toon.billboard(root, EYES_SHADER, Vector2(1.6, 0.8) * size, Vector3.ZERO, {"color": color})
