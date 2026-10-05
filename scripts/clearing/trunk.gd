@tool
extends Node3D
## A giant pencil rising out of the dark, sharpened end up, framing the
## scene at the edges of a room: a hexagonal body in dark paint (`color`),
## gold bands near the top (`roots` / 2 of them), a ring of pale sharpened
## wood and a graphite point. (Was a dead tree trunk; the name and exports
## are kept so the rooms and their generator still work.)

const Toon = preload("res://scripts/clearing/toon.gd")
const WOOD := Color(0.72, 0.56, 0.4)
const GRAPHITE := Color(0.2, 0.2, 0.23)
const GOLD := Color(0.72, 0.6, 0.34)

@export var height := 16.0:
	set(v):
		height = v
		_rebuild()
@export var radius := 1.3:
	set(v):
		radius = v
		_rebuild()
@export var color := Color(0.22, 0.15, 0.17):
	set(v):
		color = v
		_rebuild()
@export var roots := 4:
	set(v):
		roots = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var cone_h := radius * 2.2
	var tip_h := radius * 0.8
	var body_h := maxf(height - cone_h - tip_h, radius)
	Toon.part(root, Toon.cylinder(radius, radius, body_h, 6), color, Vector3(0, body_h * 0.5, 0), Vector3.ZERO,
		{"line": color.darkened(0.55), "outline": 0.07})
	for i in clampi(roots / 2, 0, 3):
		Toon.part(root, Toon.cylinder(radius * 1.02, radius * 1.02, radius * 0.1, 6), GOLD,
			Vector3(0, body_h - radius * (0.9 + i * 0.3), 0), Vector3.ZERO, {"outline": 0.0})
	Toon.part(root, Toon.cylinder(radius * 0.3, radius, cone_h, 6), WOOD.lerp(color, 0.25), Vector3(0, body_h + cone_h * 0.5, 0),
		Vector3.ZERO, {"outline": 0.06})
	Toon.part(root, Toon.cylinder(0.0, radius * 0.3, tip_h, 12), GRAPHITE, Vector3(0, body_h + cone_h + tip_h * 0.5, 0),
		Vector3.ZERO, {"outline": 0.04})
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius, height), Vector3(0, height * 0.5, 0))
