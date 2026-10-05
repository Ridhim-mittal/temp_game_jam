@tool
extends Node3D
## Dark pine silhouette: stacked cones on a short trunk. Used in rings
## around the clearing and rising out of the void below the cliffs.

const Toon = preload("res://scripts/clearing/toon.gd")

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
	var trunk_h := height * 0.18
	Toon.part(root, Toon.cylinder(radius * 0.12, radius * 0.16, trunk_h, 8), Color(0.16, 0.11, 0.12),
		Vector3(0, trunk_h * 0.5, 0))
	var cone_h := (height - trunk_h) / tiers * 1.55
	for i in tiers:
		var t := float(i) / tiers
		var r := radius * lerpf(1.0, 0.45, t)
		var y := trunk_h + (height - trunk_h - cone_h) * t + cone_h * 0.5
		# each tier a little darker towards the top, slightly twisted
		Toon.part(root, Toon.cylinder(0.0, r, cone_h, 9), color.darkened(t * 0.2), Vector3(0, y, 0),
			Vector3(0, i * 23.0, 0), {"outline": 0.06})
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius * 0.3, 3.0), Vector3(0, 1.5, 0))
