@tool
extends Node3D
## The Spine's centrepiece: a forgotten shrine to Vesper, worn grey stone.
## Only the lower half of his statue still stands on the tiered plinth: the
## boots and the hem of his cloak, broken off at the chest in a jagged edge.
## The rest lies where it fell: his egg of a head and his hat on the ground
## by the steps, an arm and the snapped blade of his sword among the rubble.
## Everything is weathered stone, cracked and mossy; the offerings are old (a
## faded scarf over the steps, tipped ink pots, quills, yellowed pages, a few
## candles still guttering) and a dim ring of the Writer's marks is worn into
## the dirt round it (sigil_ring.gdshader). A small pool of light in the
## Gutter's darkness (group "glow").
## (The statue is only built in the game, not in the editor.)

const Toon = preload("res://scripts/clearing/toon.gd")
const RING_SHADER = preload("res://shaders/world25/sigil_ring.gdshader")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const PAGE := Color(0.82, 0.78, 0.66)
const WORN_RED := Color(0.48, 0.3, 0.28)
const CANDLE := Color(1.0, 0.7, 0.35)

@export var stone := Color(0.6, 0.6, 0.58):
	set(v):
		stone = v
		_rebuild()
## Radius of the ring round the shrine (0 = none).
@export var ring_radius := 4.4:
	set(v):
		ring_radius = v
		_rebuild()
@export var ring_color := Color(0.62, 0.56, 0.46):
	set(v):
		ring_color = v
		_rebuild()
## Size of the statue (about Vesper's 3D model at this scale).
@export var statue_scale := 1.9

## The pool it carves in the darkness (darkness.gd).
var glow_radius := 3.4

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
	Toon.merge_when_built(root)  # one mesh per material (only its light flickers)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	if ring_radius > 0.0:
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(ring_radius * 2.0, ring_radius * 2.0)
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", ring_color)
		rm.set_shader_parameter("glow", 0.45)
		var ring := MeshInstance3D.new()
		ring.mesh = q
		ring.material_override = rm
		ring.position.y = 0.025
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	var opts := {"moss": 0.3}
	var tiers := [[2.3, 0.3], [1.75, 0.38], [1.25, 0.5]]  # radius, height
	var y := 0.0
	for i in tiers.size():
		var r: float = tiers[i][0]
		var h: float = tiers[i][1]
		var tier := Toon.part(root, Toon.cylinder(r, r + 0.05, h, 14), stone.darkened(0.05 * i), Vector3(0, y + h * 0.5, 0),
			Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)), opts)
		tier.scale = Vector3.ONE
		# a worn band round the lip, and chips knocked out of the edge
		Toon.part(root, Toon.cylinder(r + 0.02, r + 0.02, 0.05, 14), stone.darkened(0.2), Vector3(0, y + h - 0.03, 0), Vector3.ZERO,
			{"outline": 0.0})
		for k in 2:
			var a := rng.randf() * TAU
			Toon.part(root, Toon.box(Vector3(0.3, h * 0.6, 0.3)), stone.darkened(0.35), Vector3(sin(a) * r, y + h * 0.7, cos(a) * r),
				Vector3(0, rad_to_deg(a) + 45.0, 0), {"outline": 0.0})
		# cracks running across the step
		Toon.part(root, Toon.box(Vector3(0.03, 0.012, r * 0.9)), Color(0.15, 0.15, 0.16), Vector3(r * 0.3, y + h + 0.004, r * 0.25),
			Vector3(0, rng.randf_range(-40, 40), 0), {"outline": 0.0})
		y += h
		if i < 2:
			# old offerings on the step: a few candles still burning, tipped
			# ink pots, quills and yellowed pages
			var next_r: float = tiers[i + 1][0]
			var cr := (r + next_r) * 0.5 + 0.08
			var n := 7 - i * 2
			for k in n:
				var a := lerpf(-1.2, 1.2, float(k) / maxf(n - 1, 1)) + rng.randf_range(-0.08, 0.08)
				var at := Vector3(sin(a) * cr, y, cos(a) * cr)
				match k % 3:
					0:
						Toon.candle(root, at, rng.randf_range(0.08, 0.2), CANDLE, Color(0.78, 0.76, 0.7))
					1:
						_ink_pot(root, at, rng.randf() * 360.0, k % 2 == 1)
					_:
						if i == 0:
							_pages(root, at, rng)
						else:
							_quill(root, at, rad_to_deg(a))
	# the pedestal, its plaque worn down
	var ped := Vector3(1.0, 0.45, 1.0)
	Toon.part(root, Toon.box(ped), stone.lightened(0.04), Vector3(0, y + ped.y * 0.5, 0), Vector3(0, 4, 0), opts)
	Toon.part(root, Toon.box(Vector3(1.1, 0.08, 1.1)), stone.darkened(0.12), Vector3(0, y + ped.y, 0), Vector3(0, 4, 0), {"outline": 0.02})
	var plaque := Label3D.new()
	plaque.text = "VESPER"
	plaque.font = TITLE_FONT
	plaque.font_size = 64
	plaque.pixel_size = 0.006
	plaque.modulate = stone.darkened(0.55)
	plaque.outline_size = 6
	plaque.outline_modulate = stone.lightened(0.25)
	plaque.position = Vector3(0, y + ped.y * 0.5, ped.z * 0.5 + 0.06)
	plaque.rotation_degrees = Vector3(0, 4, 0)
	root.add_child(plaque)
	Toon.part(root, Toon.box(Vector3(0.025, 0.3, 0.02)), Color(0.15, 0.15, 0.16), plaque.position + Vector3(0.12, 0.0, 0.01),
		Vector3(0, 0, 24), {"outline": 0.0})
	# his scarf, faded to a dusty red, draped over the edge
	for k in 3:
		var a := 0.55 + k * 0.13
		Toon.part(root, Toon.box(Vector3(0.22, 0.05, 0.34 + k * 0.06)), WORN_RED.darkened(0.08 * k),
			Vector3(sin(a) * 1.15, y - 0.02 - k * 0.07, cos(a) * 1.15), Vector3(-25.0 - k * 12.0, rad_to_deg(a), 0), {"outline": 0.02})
	var top := y + ped.y + 0.04
	if Engine.is_editor_hint():
		return
	_build_statue(root, top, rng)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.76, 0.5)
	_light.light_energy = 0.8
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.6, 1.8)
	root.add_child(_light)
	Toon.collider(root, Toon.cylinder_shape(2.0, 3.0), Vector3(0, 1.5, 0))


## What's left of Vesper in stone: the lower half standing on the pedestal,
## broken off at the chest; his head, hat, an arm and the blade lie below.
func _build_statue(root: Node3D, top: float, rng: RandomNumberGenerator) -> void:
	var s := statue_scale
	var opts := {"moss": 0.35}
	var statue := Node3D.new()
	statue.name = "Statue"
	statue.position = Vector3(0, top, 0)
	statue.rotation_degrees = Vector3(0, 8, 0)
	root.add_child(statue)
	# boots and legs
	for side in [-1.0, 1.0]:
		Toon.part(statue, Toon.cylinder(0.07 * s, 0.075 * s, 0.3 * s, 10), stone.darkened(0.06), Vector3(side * 0.1 * s, 0.17 * s, 0), Vector3.ZERO, opts)
		Toon.part(statue, Toon.box(Vector3(0.14, 0.09, 0.22) * s), stone.darkened(0.12), Vector3(side * 0.1 * s, 0.045 * s, 0.03 * s), Vector3.ZERO, opts)
	# the cloak: an A-line skirt, its hem cut in points, up to the chest
	var hem := 0.26 * s
	var waist := 0.62 * s
	Toon.part(statue, Toon.cylinder(0.3 * s, 0.45 * s, waist - hem, 14), stone, Vector3(0, (waist + hem) * 0.5, 0), Vector3.ZERO, opts)
	for k in 9:
		var a := TAU * k / 9.0
		Toon.part(statue, Toon.prism(Vector3(0.16 * s, 0.1 * s, 0.05 * s)), stone, Vector3(sin(a) * 0.44 * s, hem - 0.04 * s, cos(a) * 0.44 * s),
			Vector3(180, rad_to_deg(a), 0), {"outline": 0.02})
	# the chest, broken off on a slant: its left side and shoulder still
	# stand, the right side is gone
	var chest := Node3D.new()
	chest.position = Vector3(0, waist, 0)
	statue.add_child(chest)
	Toon.part(chest, Toon.cylinder(0.27 * s, 0.3 * s, 0.12 * s, 14), stone, Vector3(0, 0.06 * s, 0), Vector3.ZERO, opts)
	var shoulder := Toon.part(chest, Toon.box(Vector3(0.24, 0.36, 0.42) * s), stone, Vector3(-0.15 * s, 0.26 * s, 0), Vector3(0, 0, 8), opts)
	shoulder.scale = Vector3.ONE
	Toon.part(chest, Toon.sphere(0.12 * s, 10, 6), stone, Vector3(-0.24 * s, 0.38 * s, 0), Vector3.ZERO, opts)
	# the scarf's roll, half of it, and its tail hanging down the back
	Toon.part(chest, Toon.box(Vector3(0.2, 0.1, 0.36) * s), stone.darkened(0.1), Vector3(-0.08 * s, 0.44 * s, 0), Vector3(0, 0, -20), opts)
	Toon.part(chest, Toon.box(Vector3(0.1, 0.4, 0.04) * s), stone.darkened(0.1), Vector3(-0.1 * s, 0.2 * s, -0.24 * s), Vector3(8, 0, 5), opts)
	# his left arm, snapped at the elbow
	Toon.part(chest, Toon.cylinder(0.06 * s, 0.065 * s, 0.26 * s, 8), stone.darkened(0.04), Vector3(-0.31 * s, 0.22 * s, 0.03 * s), Vector3(0, 0, -10), opts)
	Toon.part(chest, Toon.cylinder(0.065 * s, 0.065 * s, 0.02 * s, 8), stone.lightened(0.22), Vector3(-0.33 * s, 0.09 * s, 0.03 * s), Vector3(0, 0, -10),
		{"outline": 0.0})
	# the break: paler, fresher stone on a slant, shards standing up from it
	var fresh := stone.lightened(0.22)
	Toon.part(chest, Toon.box(Vector3(0.52, 0.03, 0.5) * s), fresh, Vector3(0.06 * s, 0.17 * s, 0), Vector3(0, 0, 28), {"outline": 0.0})
	for k in 6:
		var x := lerpf(-0.04, 0.24, float(k) / 5.0) * s
		var h := rng.randf_range(0.05, 0.14) * s
		Toon.part(chest, Toon.prism(Vector3(0.09 * s, h, 0.07 * s)), fresh.darkened(0.12 * (k % 2)),
			Vector3(x, 0.2 * s - (x / s) * 0.5 * s + h * 0.4, rng.randf_range(-0.15, 0.15) * s),
			Vector3(rng.randf_range(-15, 15), rng.randf() * 90.0, rng.randf_range(-15, 15)), {"outline": 0.015})
	# the stump of the strap that held his sword
	Toon.part(statue, Toon.box(Vector3(0.05 * s, 0.3 * s, 0.03 * s)), stone.darkened(0.25), Vector3(0.12 * s, waist - 0.05 * s, -0.28 * s),
		Vector3(0, 0, -35), {"outline": 0.0})
	# cracks down the cloak, on a slant
	for k in 3:
		var a := rng.randf_range(0.6, 2.2) * (1.0 if k % 2 == 0 else -1.0)
		Toon.part(statue, Toon.box(Vector3(0.015 * s, rng.randf_range(0.15, 0.3) * s, 0.01 * s)), Color(0.15, 0.15, 0.16),
			Vector3(sin(a) * 0.38 * s, 0.42 * s, cos(a) * 0.38 * s), Vector3(-10, rad_to_deg(a), rng.randf_range(25, 45)), {"outline": 0.0})
	# what fell: on the ground by the steps, in front
	var fallen := Node3D.new()
	fallen.name = "Fallen"
	root.add_child(fallen)
	_fallen_head(fallen, Vector3(2.35, 0, 1.55), s)
	_fallen_hat(fallen, Vector3(2.95, 0, 0.55), s)
	# the chest piece, on its side
	Toon.part(fallen, Toon.cylinder(0.2 * s, 0.31 * s, 0.32 * s, 12), stone, Vector3(-2.45, 0.29 * s, 1.35), Vector3(84, 30, 0), opts)
	Toon.part(fallen, Toon.cylinder(0.2 * s, 0.21 * s, 0.1 * s, 12), stone.darkened(0.08), Vector3(-2.3, 0.29 * s, 1.55), Vector3(84, 30, 0), opts)
	# an arm, and the snapped blade of his sword
	Toon.part(fallen, Toon.cylinder(0.06 * s, 0.055 * s, 0.32 * s, 8), stone.darkened(0.04), Vector3(1.45, 0.69 + 0.06 * s, 1.55), Vector3(90, -40, 0), opts)
	Toon.part(fallen, Toon.box(Vector3(0.09 * s, 0.45 * s, 0.025 * s)), stone.lightened(0.1), Vector3(-1.5, 0.69 + 0.03, 1.4), Vector3(88, 70, 0), opts)
	Toon.part(fallen, Toon.box(Vector3(0.3 * s, 0.05 * s, 0.06 * s)), stone.darkened(0.1), Vector3(-1.25, 0.69 + 0.06, 1.6), Vector3(0, 20, 90), opts)
	# rubble
	for k in 12:
		var a := rng.randf_range(-1.4, 1.4)
		var r := rng.randf_range(2.35, 3.1)
		var sz := rng.randf_range(0.12, 0.3)
		Toon.part(fallen, Toon.box(Vector3(sz, sz * 0.7, sz)), stone.darkened(rng.randf_range(0.0, 0.2)), Vector3(sin(a) * r, sz * 0.3, cos(a) * r),
			Vector3(rng.randf_range(-30, 30), rng.randf() * 360.0, rng.randf_range(-30, 30)), {"moss": 0.3})
	Toon.collider(fallen, Toon.cylinder_shape(0.55, 0.9), Vector3(2.35, 0.45, 1.55))


## His head: a stone egg rolled onto its side, the dash eyes worn shallow.
func _fallen_head(parent: Node3D, at: Vector3, s: float) -> void:
	var head := Node3D.new()
	head.position = at + Vector3(0, 0.22 * s, 0)
	head.rotation_degrees = Vector3(-25, 15, 78)
	parent.add_child(head)
	var egg := Toon.part(head, Toon.sphere(0.27 * s, 14, 8), stone.lightened(0.08), Vector3.ZERO, Vector3.ZERO, {"moss": 0.12})
	egg.scale = Vector3(1, 1.2, 1)
	for side in [-1.0, 1.0]:
		var eye := Toon.part(head, Toon.box(Vector3(0.05, 0.14, 0.03) * s), stone.darkened(0.45), Vector3(side * 0.1 * s, 0.03 * s, 0.24 * s),
			Vector3.ZERO, {"outline": 0.0})
		eye.scale = Vector3.ONE
	# the neck's broken edge
	Toon.part(head, Toon.cylinder(0.12 * s, 0.14 * s, 0.05 * s, 10), stone.lightened(0.22), Vector3(0, -0.31 * s, 0), Vector3.ZERO, {"outline": 0.015})
	Toon.part(head, Toon.box(Vector3(0.012, 0.2, 0.01) * s), Color(0.15, 0.15, 0.16), Vector3(0.12 * s, 0.1 * s, 0.2 * s), Vector3(0, 30, 25), {"outline": 0.0})


## His hat, knocked off: the brim tilted on the ground, a chip out of it.
func _fallen_hat(parent: Node3D, at: Vector3, s: float) -> void:
	var hat := Node3D.new()
	hat.position = at + Vector3(0, 0.1 * s, 0)
	hat.rotation_degrees = Vector3(-18, 25, 10)
	parent.add_child(hat)
	Toon.part(hat, Toon.cylinder(0.43 * s, 0.41 * s, 0.035 * s, 20), stone.darkened(0.15), Vector3.ZERO, Vector3.ZERO, {"moss": 0.3})
	Toon.part(hat, Toon.cylinder(0.24 * s, 0.27 * s, 0.32 * s, 14), stone.darkened(0.15), Vector3(0, 0.17 * s, 0), Vector3.ZERO, {"moss": 0.3})
	Toon.part(hat, Toon.cylinder(0.275 * s, 0.28 * s, 0.085 * s, 14), stone.darkened(0.3), Vector3(0, 0.065 * s, 0), Vector3.ZERO, {"outline": 0.015})
	Toon.part(hat, Toon.box(Vector3(0.22, 0.05, 0.14) * s), stone.lightened(0.2), Vector3(0.36 * s, 0.0, 0.12 * s), Vector3(0, 30, 0), {"outline": 0.0})


func _ink_pot(root: Node3D, at: Vector3, yaw: float, tipped := false) -> void:
	if tipped:
		# on its side, a dried stain where the ink ran out
		Toon.part(root, Toon.cylinder(0.11, 0.14, 0.18, 10), Color(0.16, 0.16, 0.2), at + Vector3(0, 0.12, 0), Vector3(90, yaw, 0), {"outline": 0.015})
		Toon.part(root, Toon.cylinder(0.2, 0.2, 0.01, 12), Color(0.08, 0.08, 0.12), at + Vector3(0.12, 0.005, 0.05), Vector3.ZERO, {"outline": 0.0})
		return
	Toon.part(root, Toon.cylinder(0.11, 0.14, 0.18, 10), Color(0.16, 0.16, 0.2), at + Vector3(0, 0.09, 0), Vector3(0, yaw, 0), {"outline": 0.015})
	Toon.part(root, Toon.cylinder(0.06, 0.06, 0.06, 8), Color(0.45, 0.36, 0.28), at + Vector3(0, 0.21, 0), Vector3.ZERO, {"outline": 0.01})


func _quill(root: Node3D, at: Vector3, yaw: float) -> void:
	var tilt := Vector3(-35, yaw + 20.0, 15)
	Toon.part(root, Toon.cylinder(0.008, 0.012, 0.55, 5), Color(0.9, 0.86, 0.75), at + Vector3(0, 0.22, 0), tilt, {"outline": 0.008})
	Toon.part(root, Toon.box(Vector3(0.1, 0.32, 0.015)), PAGE, at + Vector3(0, 0.36, -0.08), tilt, {"outline": 0.012})


## A little stack of old comic pages, yellowed, each with a faded panel.
func _pages(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var yaw := rng.randf_range(-25, 25)
		Toon.part(root, Toon.box(Vector3(0.36, 0.02, 0.48)), PAGE.darkened(0.05 * k), at + Vector3(0, 0.012 + k * 0.022, 0), Vector3(0, yaw, 0), {"outline": 0.01})
	Toon.part(root, Toon.box(Vector3(0.26, 0.004, 0.18)), Toon.INK, at + Vector3(0, 0.072, -0.08), Vector3.ZERO, {"outline": 0.0})
	Toon.part(root, Toon.box(Vector3(0.26, 0.004, 0.14)), Color(0.45, 0.55, 0.58), at + Vector3(0, 0.072, 0.1), Vector3.ZERO, {"outline": 0.0})


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	_light.light_energy = 0.8 * (0.85 + 0.1 * sin(_time * 9.0) + 0.06 * sin(_time * 17.0 + 1.0))
