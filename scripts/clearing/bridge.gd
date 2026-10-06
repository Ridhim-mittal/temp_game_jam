@tool
extends Node3D
## The hub's way in over the void, towards the camera (+Z): one of the
## comic's dead gutters (gutter_strip.gd), a dark, cracked, ragged walkway
## between two broken ink kerbs; what is left of a kerb closes the far end.
## (Was a stone walkway with parapets.)

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
## Unused since the bridge became an old gutter (kept for scenes that set it).
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
	Toon.merge_when_built(root)  # one mesh per material: far fewer draw calls
	GutterStrip.section(root, 0.0, length, width, 3)
	# the far end: what is left of the kerb across it, broken in three
	for k in 3:
		var w := (width + 0.36) / 3.0
		Toon.part(root, Toon.box(Vector3(w * (0.6 + 0.12 * k), GutterStrip.THICK + 0.1 + 0.05 * k, 0.18)), GutterStrip.INK,
			Vector3(-width * 0.5 - 0.18 + w * (k + 0.5), -GutterStrip.THICK * 0.5 + 0.08, length + 0.09),
			Vector3(0, 0, 4.0 * (k - 1)), {"outline": 0.0})
	if not Engine.is_editor_hint():
		var thick := GutterStrip.THICK
		Toon.collider(root, Toon.box_shape(Vector3(width, thick, length)), Vector3(0, -thick * 0.5, length * 0.5))
		for side in [-1, 1]:
			Toon.collider(root, Toon.box_shape(Vector3(0.4, 4.0, length)), Vector3(side * (width * 0.5 + 0.2), 2.0, length * 0.5))
		Toon.collider(root, Toon.box_shape(Vector3(width, 4.0, 0.5)), Vector3(0, 2.0, length + 0.25))
