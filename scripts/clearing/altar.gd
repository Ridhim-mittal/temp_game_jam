@tool
extends Node3D
## The clearing's centrepiece: a tiered stone shrine topped by a horned
## stele with a red eye that bleeds ink down the steps (Cult of the Lamb's
## statue, told in The Gutter's ink).

const Toon = preload("res://scripts/clearing/toon.gd")
const EMBLEM_SHADER = preload("res://shaders/clearing/emblem.gdshader")

@export var stone := Color(0.72, 0.68, 0.62):
	set(v):
		stone = v
		_rebuild()
@export var eye_color := Color(0.75, 0.1, 0.12):
	set(v):
		eye_color = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var opts := {"moss": 0.45}
	var tiers := [[2.3, 0.3], [1.75, 0.38], [1.25, 0.5]]  # radius, height
	var y := 0.0
	for i in tiers.size():
		var r: float = tiers[i][0]
		var h: float = tiers[i][1]
		Toon.part(root, Toon.cylinder(r, r + 0.05, h, 20), stone.darkened(0.06 * i), Vector3(0, y + h * 0.5, 0),
			Vector3.ZERO, opts)
		# ink running over the lip of the tier
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + i
		var drips := 10 + i * 2
		for k in drips:
			var a := TAU * k / drips + rng.randf() * 0.2
			if sin(a) < -0.3:
				continue  # only the visible side
			var len := h * rng.randf_range(0.45, 1.0)
			var d := Vector3(sin(a), 0, cos(a))
			Toon.part(root, Toon.box(Vector3(0.09, len, 0.05)), Toon.INK,
				d * (r + 0.03) + Vector3(0, y + h - len * 0.5, 0), Vector3(0, rad_to_deg(a), 0), {"outline": 0.0})
		y += h
	# stele with two horns
	var stele := Vector3(1.6, 2.3, 0.75)
	Toon.part(root, Toon.box(stele), stone.lightened(0.04), Vector3(0, y + stele.y * 0.5, 0), Vector3.ZERO, opts)
	for side in [-1, 1]:
		Toon.part(root, Toon.prism(Vector3(0.7, 1.3, 0.72)), stone.lightened(0.04),
			Vector3(side * 0.5, y + stele.y + 0.55, 0), Vector3(0, 0, -side * 14.0), opts)
	var q := QuadMesh.new()
	q.size = Vector2(1.35, 1.9)
	var eye := MeshInstance3D.new()
	eye.mesh = q
	var m := ShaderMaterial.new()
	m.shader = EMBLEM_SHADER
	m.set_shader_parameter("mode", 0)
	m.set_shader_parameter("color", eye_color)
	m.set_shader_parameter("glow", 0.35)
	eye.material_override = m
	eye.position = Vector3(0, y + stele.y * 0.52, stele.z * 0.5 + 0.01)
	root.add_child(eye)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(2.0, 3.0), Vector3(0, 1.5, 0))
