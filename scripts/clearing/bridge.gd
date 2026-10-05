@tool
extends Node3D
## Stone walkway leading towards the camera (+Z) over the void, with mossy
## parapet walls and a little rubble. The far end is blocked.

const Toon = preload("res://scripts/clearing/toon.gd")

@export var length := 9.0:
	set(v):
		length = v
		_rebuild()
@export var width := 4.4:
	set(v):
		width = v
		_rebuild()
@export var stone := Color(0.29, 0.29, 0.32):
	set(v):
		stone = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var thick := 1.6
	Toon.part(root, Toon.box(Vector3(width, thick, length)), stone, Vector3(0, -thick * 0.5, length * 0.5),
		Vector3.ZERO, {"tile": 0.9, "moss": 0.12})
	# parapets: chunky blocks, the odd one missing its cap
	var blocks := int(length / 1.5)
	for side in [-1, 1]:
		for i in blocks:
			var h := 1.0 + 0.25 * absf(sin(i * 2.1 + side))
			var z := (i + 0.5) * length / blocks
			Toon.part(root, Toon.box(Vector3(0.8, h + thick, length / blocks)), stone.darkened(0.06 * (i % 2)),
				Vector3(side * (width * 0.5 + 0.4), (h - thick) * 0.5, z), Vector3.ZERO, {"moss": 0.6, "tile": 0.6})
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 3:
		var side := -1 if i % 2 == 0 else 1
		var rock := Toon.part(root, Toon.sphere(0.32, 6, 3), stone.darkened(0.1),
			Vector3(side * (width * 0.5 - 0.45), 0.12, rng.randf_range(1.0, length - 1.0)),
			Vector3(rng.randf() * 40.0, rng.randf() * 360.0, 0), {"moss": 0.4})
		rock.scale = Vector3(1.3, 0.75, 1.0)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.box_shape(Vector3(width, thick, length)), Vector3(0, -thick * 0.5, length * 0.5))
		for side in [-1, 1]:
			Toon.collider(root, Toon.box_shape(Vector3(0.8, 4.0, length)), Vector3(side * (width * 0.5 + 0.4), 2.0, length * 0.5))
		Toon.collider(root, Toon.box_shape(Vector3(width, 4.0, 0.5)), Vector3(0, 2.0, length + 0.25))
