@tool
extends Node3D
## Giant dead tree trunk rising out of the dark, with roots, framing the
## scene at the edges of a room; a few branches snapped off short, the top
## broken.

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
	Toon.merge_when_built(root)  # one mesh per material: far fewer draw calls
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
	# branches snapped off short, and the broken top
	for i in 3:
		var a := TAU * i / 3.0 + 1.1
		var stub := Node3D.new()
		stub.position = Vector3(cos(a), 0, sin(a)) * radius * 0.8 + Vector3(0, height * (0.55 + 0.13 * i), 0)
		stub.basis = Basis(Quaternion(Vector3.UP, Vector3(cos(a), 0.8, sin(a)).normalized()))
		root.add_child(stub)
		Toon.part(stub, Toon.cylinder(radius * 0.18, radius * 0.32, radius * 1.6, 7), color, Vector3.ZERO, Vector3.ZERO, opts)
	for k in 3:
		var a := TAU * k / 3.0
		Toon.part(root, Toon.prism(Vector3(radius * 0.7, radius * 0.9, radius * 0.4)), color.darkened(0.1),
			Vector3(cos(a), 0, sin(a)) * radius * 0.45 + Vector3(0, height + radius * 0.35, 0), Vector3(0, rad_to_deg(-a), 8.0 * (k - 1)), opts)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius, height), Vector3(0, height * 0.5, 0))
