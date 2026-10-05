@tool
extends Node3D
## Small clusters of the Writer's desk clutter, picked with `kind` (the
## names are the old ones, kept so scenes and the room generator still work):
##   MUSHROOMS  rusty push pins stuck in the floor (`color` tints the heads)
##   BUSH       a wad of crumpled, yellowed drafts, red-pen marked
##   ROCKS      broken, grimy stones (in `color`)
## Placed at random inside `radius` around this node, from `seed`.

const Toon = preload("res://scripts/clearing/toon.gd")
const PAPER := Color(0.82, 0.79, 0.7)
const STEEL := Color(0.7, 0.72, 0.78)
const RED_PEN := Color(0.78, 0.14, 0.14)

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
				var pin := Node3D.new()
				pin.position = p
				pin.rotation_degrees = Vector3(rng.randf_range(-18, 18), rng.randf() * 360.0, rng.randf_range(-18, 18))
				root.add_child(pin)
				var head := color.lerp(Color(0.3, 0.26, 0.24), 0.7).darkened(rng.randf() * 0.2)
				Toon.part(pin, Toon.cylinder(0.018 * s, 0.006 * s, 0.12 * s, 6), STEEL.darkened(0.45), Vector3(0, 0.04 * s, 0), Vector3.ZERO,
					{"outline": 0.01})
				Toon.part(pin, Toon.cylinder(0.06 * s, 0.08 * s, 0.2 * s, 10), head, Vector3(0, 0.2 * s, 0), Vector3.ZERO, {"outline": 0.025})
				Toon.part(pin, Toon.cylinder(0.2 * s, 0.2 * s, 0.07 * s, 14), head.lightened(0.1), Vector3(0, 0.33 * s, 0), Vector3.ZERO,
					{"outline": 0.03})
			Kind.BUSH:
				var r := 0.3 * s
				var ball := Toon.part(root, Toon.sphere(r, 5, 3), PAPER.lerp(color, 0.15).darkened(rng.randf() * 0.2),
					p + Vector3(0, r * 0.75, 0), Vector3(rng.randf() * 360.0, rng.randf() * 360.0, rng.randf() * 360.0), {"outline": 0.035})
				ball.scale = Vector3(1.0, rng.randf_range(0.8, 1.0), rng.randf_range(0.85, 1.1))
				if rng.randf() < 0.5:  # a red-pen stroke caught in the creases
					Toon.part(root, Toon.box(Vector3(r * 1.2, 0.03, 0.04)), RED_PEN, p + Vector3(0, r * 1.45, 0),
						Vector3(rng.randf_range(-20, 20), rng.randf() * 360.0, 0), {"outline": 0.0})
			Kind.ROCKS:
				var rock := Toon.part(root, Toon.sphere(0.45 * s, 6, 3), color.darkened(0.15 + rng.randf() * 0.15),
					p + Vector3(0, 0.15 * s, 0), Vector3(rng.randf() * 30.0, rng.randf() * 360.0, 0),
					{"moss": 0.35, "moss_color": Color(0.17, 0.15, 0.15), "outline": 0.04})
				rock.scale = Vector3(1.2, 0.7, 1.0)
				# a chip broken off it
				Toon.part(root, Toon.box(Vector3(0.18, 0.12, 0.15) * s), color.darkened(0.3), p + Vector3(0.45, 0.05, 0.2) * s,
					Vector3(rng.randf() * 40.0, rng.randf() * 90.0, 0), {"outline": 0.02})
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius * 0.8 + 0.3 * size, 2.0), Vector3(0, 1, 0))
