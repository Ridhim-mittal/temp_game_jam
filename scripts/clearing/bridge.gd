@tool
extends Node3D
## The hub's way in over the void, towards the camera (+Z): a gutter of the
## comic (gutter_strip.gd), a walkway of cream paper between two thick ink
## panel borders with the printed panels lying either side; an ink border
## closes the far end. (Was a stone walkway with parapets.)

const Toon = preload("res://scripts/clearing/toon.gd")
const GutterStrip = preload("res://scripts/world25/gutter_strip.gd")

@export var length := 9.0:
	set(v):
		length = v
		_rebuild()
@export var width := 4.4:
	set(v):
		width = v
		_rebuild()
## Unused since the bridge became a gutter (kept for scenes that set it).
@export var stone := Color(0.6, 0.57, 0.6):
	set(v):
		stone = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	GutterStrip.section(root, 0.0, length, width, 3)
	# the far end: the panel border runs across it
	Toon.part(root, Toon.box(Vector3(width + 0.36, GutterStrip.THICK + 0.16, 0.18)), GutterStrip.INK,
		Vector3(0, -GutterStrip.THICK * 0.5 + 0.08, length + 0.09), Vector3.ZERO, {"outline": 0.0})
	if not Engine.is_editor_hint():
		var thick := GutterStrip.THICK
		Toon.collider(root, Toon.box_shape(Vector3(width, thick, length)), Vector3(0, -thick * 0.5, length * 0.5))
		for side in [-1, 1]:
			Toon.collider(root, Toon.box_shape(Vector3(0.4, 4.0, length)), Vector3(side * (width * 0.5 + 0.2), 2.0, length * 0.5))
		Toon.collider(root, Toon.box_shape(Vector3(width, 4.0, 0.5)), Vector3(0, 2.0, length + 0.25))
