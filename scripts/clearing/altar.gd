@tool
extends Node3D
## The Spine's centrepiece: a tiered stone shrine topped by a horned stele
## with a red eye that bleeds ink down the steps, standing in a ritual
## circle burnt into the dirt (sigil_ring.gdshader: rings, a great pen nib
## and a band of the Writer's marks, glowing and turning). Red candles burn on the tiers
## and old skulls are heaped round its foot. It lights its own pool in the
## Gutter's darkness (group "glow").

const Toon = preload("res://scripts/clearing/toon.gd")
const EMBLEM_SHADER = preload("res://shaders/clearing/emblem.gdshader")
const RING_SHADER = preload("res://shaders/world25/sigil_ring.gdshader")

@export var stone := Color(0.72, 0.68, 0.62):
	set(v):
		stone = v
		_rebuild()
@export var eye_color := Color(0.75, 0.1, 0.12):
	set(v):
		eye_color = v
		_rebuild()
## Radius of the ritual circle round the shrine (0 = none).
@export var ring_radius := 4.4:
	set(v):
		ring_radius = v
		_rebuild()
@export var ring_color := Color(1.0, 0.22, 0.14):
	set(v):
		ring_color = v
		_rebuild()

## The pool it carves in the darkness (darkness.gd).
var glow_radius := 4.2

var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("glow")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	if ring_radius > 0.0:
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(ring_radius * 2.0, ring_radius * 2.0)
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", ring_color)
		var ring := MeshInstance3D.new()
		ring.mesh = q
		ring.material_override = rm
		ring.position.y = 0.025
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	var opts := {"moss": 0.45}
	var tiers := [[2.3, 0.3], [1.75, 0.38], [1.25, 0.5]]  # radius, height
	var y := 0.0
	for i in tiers.size():
		var r: float = tiers[i][0]
		var h: float = tiers[i][1]
		Toon.part(root, Toon.cylinder(r, r + 0.05, h, 20), stone.darkened(0.06 * i), Vector3(0, y + h * 0.5, 0),
			Vector3.ZERO, opts)
		# ink running over the lip of the tier
		var drng := RandomNumberGenerator.new()
		drng.seed = 7 + i
		var drips := 10 + i * 2
		for k in drips:
			var a := TAU * k / drips + drng.randf() * 0.2
			if sin(a) < -0.3:
				continue  # only the visible side
			var len := h * drng.randf_range(0.45, 1.0)
			var d := Vector3(sin(a), 0, cos(a))
			Toon.part(root, Toon.box(Vector3(0.09, len, 0.05)), Toon.INK,
				d * (r + 0.03) + Vector3(0, y + h - len * 0.5, 0), Vector3(0, rad_to_deg(a), 0), {"outline": 0.0})
		y += h
		# red candles round the front of each lower tier
		if i < 2:
			var next_r: float = tiers[i + 1][0]
			var n := 7 - i * 2
			for k in n:
				var a := lerpf(-1.1, 1.1, float(k) / maxf(n - 1, 1)) + rng.randf_range(-0.08, 0.08)
				var cr := (r + next_r) * 0.5 + 0.08
				Toon.candle(root, Vector3(sin(a) * cr, y, cos(a) * cr), rng.randf_range(0.18, 0.38))
	# stele with two horns
	var stele := Vector3(1.6, 2.3, 0.75)
	Toon.part(root, Toon.box(stele), stone.lightened(0.04), Vector3(0, y + stele.y * 0.5, 0), Vector3.ZERO, opts)
	for side in [-1, 1]:
		Toon.part(root, Toon.prism(Vector3(0.7, 1.3, 0.72)), stone.lightened(0.04),
			Vector3(side * 0.5, y + stele.y + 0.55, 0), Vector3(0, 0, -side * 14.0), opts)
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.35, 1.9)
	var eye := MeshInstance3D.new()
	eye.mesh = q2
	var m := ShaderMaterial.new()
	m.shader = EMBLEM_SHADER
	m.set_shader_parameter("mode", 0)
	m.set_shader_parameter("color", eye_color)
	m.set_shader_parameter("glow", 0.6)
	eye.material_override = m
	eye.position = Vector3(0, y + stele.y * 0.52, stele.z * 0.5 + 0.01)
	root.add_child(eye)
	# skulls heaped round the foot of the shrine, mostly on the near side
	for k in 9:
		var a := lerpf(-1.6, 1.6, rng.randf()) if k < 7 else rng.randf_range(2.0, 4.2)
		var sr := 2.45 + rng.randf_range(0.0, 0.5)
		Toon.skull(root, Vector3(sin(a) * sr, 0.0, cos(a) * sr), rng.randf_range(0.26, 0.4), rad_to_deg(a) + rng.randf_range(-35, 35),
			Vector3(rng.randf_range(-15, 10), 0, rng.randf_range(-15, 15)))
	for k in 3:
		var a := rng.randf_range(-1.4, 1.4)
		Toon.bones(root, Vector3(sin(a) * 3.1, 0.0, cos(a) * 3.1), rng.randf_range(0.5, 0.75), rng.randf() * 180.0)
	if Engine.is_editor_hint():
		return
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.42, 0.28)
	_light.light_energy = 1.3
	_light.omni_range = 5.5
	_light.position = Vector3(0, 1.4, 1.6)
	root.add_child(_light)
	Toon.collider(root, Toon.cylinder_shape(2.0, 3.0), Vector3(0, 1.5, 0))


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	_light.light_energy = 1.3 * (0.9 + 0.07 * sin(_time * 9.0) + 0.05 * sin(_time * 17.0 + 1.0))
