@tool
extends Node3D
## Small decorative clusters, picked with `kind`:
##   MUSHROOMS  pale caps on cream stems
##   BUSH       a heap of round leaves (red autumn leaves by default)
##   ROCKS      faceted mossy stones
## Placed at random inside `radius` around this node, from `seed`.

const Toon = preload("res://scripts/clearing/toon.gd")

enum Kind { MUSHROOMS, BUSH, ROCKS }

@export var kind := Kind.MUSHROOMS:
	set(v):
		kind = v
		_rebuild()
@export var count := 5:
	set(v):
		count = v
		_rebuild()
@export var radius := 0.8:
	set(v):
		radius = v
		_rebuild()
@export var size := 1.0:
	set(v):
		size = v
		_rebuild()
@export var color := Color(0.82, 0.62, 0.42):
	set(v):
		color = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
@export var solid := false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * radius * sqrt(rng.randf())
		var s := size * rng.randf_range(0.6, 1.15)
		match kind:
			Kind.MUSHROOMS:
				var stem_h := 0.45 * s
				Toon.part(root, Toon.cylinder(0.07 * s, 0.1 * s, stem_h, 8), Color(0.93, 0.9, 0.8),
					p + Vector3(0, stem_h * 0.5, 0), Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), {"outline": 0.03})
				Toon.part(root, Toon.sphere(0.24 * s, 10, 4, true), color.darkened(rng.randf() * 0.15),
					p + Vector3(0, stem_h - 0.02, 0), Vector3.ZERO, {"outline": 0.035})
			Kind.BUSH:
				var r := 0.42 * s
				var leaf := Toon.part(root, Toon.sphere(r, 9, 5), color.darkened(rng.randf() * 0.3),
					p + Vector3(0, r * 0.7, 0), Vector3(0, rng.randf() * 360.0, 0), {"outline": 0.04})
				leaf.scale = Vector3(1.0, 0.8, 1.0)
			Kind.ROCKS:
				var rock := Toon.part(root, Toon.sphere(0.45 * s, 6, 3), color.darkened(rng.randf() * 0.15),
					p + Vector3(0, 0.15 * s, 0), Vector3(rng.randf() * 30.0, rng.randf() * 360.0, 0), {"moss": 0.4, "outline": 0.04})
				rock.scale = Vector3(1.2, 0.7, 1.0)
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius * 0.8 + 0.3 * size, 2.0), Vector3(0, 1, 0))
