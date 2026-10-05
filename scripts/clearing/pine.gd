@tool
extends Node3D
## One of the Writer's old quills, giant, stuck nib-first in the ground (or
## rising out of the void below the cliffs): a dark feather (`color`) on a
## pale shaft, its vane split in `tiers` places, ink pooled where the nib
## went in. Stands in rings round the rooms where pines used to (the name
## and exports are kept so the rooms and their generator still work).

const Toon = preload("res://scripts/clearing/toon.gd")
const SHAFT := Color(0.8, 0.77, 0.68)
const STEEL := Color(0.24, 0.24, 0.28)
const INK := Color(0.05, 0.04, 0.08)

@export var height := 6.0:
	set(v):
		height = v
		_rebuild()
@export var radius := 1.6:
	set(v):
		radius = v
		_rebuild()
@export var color := Color(0.1, 0.11, 0.17):
	set(v):
		color = v
		_rebuild()
@export var tiers := 3:
	set(v):
		tiers = v
		_rebuild()
@export var solid := true


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var seed := absi(hash(Vector2i(roundi(position.x * 10.0), roundi(position.z * 10.0))))
	Toon.part(root, Toon.cylinder(radius * 0.5, radius * 0.55, 0.02, 14), INK, Vector3(0, 0.01, 0), Vector3.ZERO, {"outline": 0.0})
	# leaning a little its own way, the vane turned mostly to the camera
	var quill := Node3D.new()
	quill.rotation_degrees = Vector3(4.0 * sin(seed * 0.7), float(seed % 70) - 35.0, 5.0 * cos(seed * 1.3))
	root.add_child(quill)
	var shaft := SHAFT.lerp(color, 0.35)
	var nib_h := height * 0.09
	# the nib, buried to its shoulders, and the bare shaft above it
	Toon.part(quill, Toon.cylinder(radius * 0.09, radius * 0.02, nib_h, 8), STEEL, Vector3(0, nib_h * 0.3, 0), Vector3.ZERO,
		{"outline": 0.02})
	Toon.part(quill, Toon.cylinder(radius * 0.035, radius * 0.08, height - nib_h * 0.8, 8), shaft,
		Vector3(0, nib_h * 0.8 + (height - nib_h * 0.8) * 0.5, 0), Vector3.ZERO, {"outline": 0.025})
	# the vane: a broad side and a narrow one, thin, from a third of the way up
	var y0 := height * 0.3
	var vane_h := height - y0
	var mid := y0 + vane_h * 0.52
	var broad := Toon.part(quill, Toon.sphere(1.0, 14, 8), color, Vector3(radius * 0.28, mid, 0), Vector3(0, 0, -4), {"outline": 0.05})
	broad.scale = Vector3(radius * 0.62, vane_h * 0.5, radius * 0.035)
	var narrow := Toon.part(quill, Toon.sphere(1.0, 14, 8), color.darkened(0.15), Vector3(-radius * 0.16, mid + vane_h * 0.04, 0),
		Vector3(0, 0, 3), {"outline": 0.05})
	narrow.scale = Vector3(radius * 0.36, vane_h * 0.46, radius * 0.03)
	# splits in the vane: pale gaps slanting up from the edge to the shaft
	for i in tiers:
		var t := (i + 0.6) / (tiers + 0.4)
		var side := 1.0 if i % 2 == 0 else -1.0
		var reach := radius * (0.5 if side > 0 else 0.3)
		var y := y0 + vane_h * lerpf(0.18, 0.78, t)
		Toon.part(quill, Toon.box(Vector3(reach, 0.035 * radius + 0.02, radius * 0.09)), shaft.darkened(0.25),
			Vector3(side * reach * 0.55, y, 0), Vector3(0, 0, side * 35.0), {"outline": 0.0})
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius * 0.3, 3.0), Vector3(0, 1.5, 0))
