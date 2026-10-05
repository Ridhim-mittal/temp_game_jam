@tool
extends Node3D
## Dead fir silhouette: a tall black trunk with bare, drooping branches
## stacked in tiers, needles long gone. Used in rings round the Gutter's
## rooms and rising out of the fog below the cliffs, where it reads as a
## black shape against the lighter fog banks.

const Toon = preload("res://scripts/clearing/toon.gd")

@export var height := 6.0:
	set(v):
		height = v
		_rebuild()
@export var radius := 1.6:
	set(v):
		radius = v
		_rebuild()
@export var color := Color(0.06, 0.06, 0.08):
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
	var rng := RandomNumberGenerator.new()
	rng.seed = int(height * 31.0 + radius * 7.0 + position.x * 13.0)
	# trunk tapering to a snapped-off spike
	Toon.part(root, Toon.cylinder(radius * 0.03, radius * 0.16, height, 7), color, Vector3(0, height * 0.5, 0),
		Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), {"bark": 0.8, "line": color.lightened(0.08), "outline": 0.05})
	# bare branches: whorls that droop, shorter towards the top
	var whorls := tiers * 3
	for i in whorls:
		var t := (i + 1.0) / (whorls + 1.0)
		var y := height * lerpf(0.25, 0.95, t)
		var reach := radius * lerpf(1.0, 0.25, t) * rng.randf_range(0.7, 1.05)
		var n := 3 + rng.randi() % 2
		for k in n:
			var yaw := TAU * k / n + rng.randf() * 0.9 + i * 0.7
			var droop := rng.randf_range(-18.0, 8.0)
			var arm := Node3D.new()
			arm.position = Vector3(0, y, 0)
			arm.rotation_degrees = Vector3(0, rad_to_deg(yaw), 90.0 - droop)
			root.add_child(arm)
			# a branch lying along the arm's local +Y, thinning to a point
			Toon.part(arm, Toon.cylinder(0.0, radius * 0.045, reach, 5), color, Vector3(0, reach * 0.5, 0), Vector3.ZERO, {"outline": 0.03})
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius * 0.25, 3.0), Vector3(0, 1.5, 0))
