@tool
extends Node3D
## Giant dead tree trunk rising out of the dark, with roots, framing the
## scene at the edges of a room.

const Toon = preload("res://scripts/clearing/toon.gd")

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
	var opts := {"bark": 1.0, "line": color.darkened(0.55), "outline": 0.07}
	Toon.part(root, Toon.cylinder(radius * 0.85, radius, height, 14), color, Vector3(0, height * 0.5, 0), Vector3.ZERO, opts)
	for i in roots:
		var a := TAU * i / roots + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		var root_mesh := Toon.cylinder(radius * 0.18, radius * 0.4, radius * 2.2, 8)
		var r := Toon.part(root, root_mesh, color, d * radius * 1.05 + Vector3(0, radius * 0.45, 0), Vector3.ZERO, opts)
		# lean the root outwards and down, into the ground
		r.basis = Basis.looking_at(d + Vector3(0, -0.9, 0), Vector3.UP)
		r.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius, height), Vector3(0, height * 0.5, 0))
