extends RefCounted
## The Gutter's lights: the Writer's own architect desk lamps, giant down
## here (the Margins are the edge of his desk). A round white base, a
## wooden arm in two jointed sections (pairs of slats with brass bolts), a
## white dome shade tipped down over the base, a white cable looping down
## the arm, and when it's on a warm bulb glowing in the shade and a soft
## cone of light falling to the floor.
## Unhooked: the Gutter's lights went back to braziers (brazier.gd) and the
## gates' stone-post lanterns; kept in case a desk ever wants one.
##
##   var lamp := DeskLamp.build(root, Vector3.ZERO, 1.0, 0.0, warm, core)
##   lamp.on (Node3D: bulb glow + beam; show when lit), lamp.light (OmniLight3D)

const Toon = preload("res://scripts/clearing/toon.gd")
const WHITE := Color(0.92, 0.91, 0.88)
const WOOD := Color(0.8, 0.6, 0.38)
const BRASS := Color(0.78, 0.64, 0.36)
const INSIDE_OFF := Color(0.36, 0.35, 0.38)


## Builds a lamp under `root` at `at`, `s` times the size of a person-tall
## lamp (about 2 units), its shade facing local +Z turned by `yaw_deg`.
## Returns {"on": Node3D (the bulb and beam, shown while lit), "light":
## OmniLight3D (null in the editor or without `with_light`), "head":
## Vector3 (the shade, in root's space)}.
static func build(root: Node3D, at: Vector3, s: float, yaw_deg: float, color: Color, core: Color, with_light := true) -> Dictionary:
	var lamp := Node3D.new()
	lamp.position = at
	lamp.rotation_degrees.y = yaw_deg
	lamp.scale = Vector3.ONE * s
	root.add_child(lamp)
	# the base: a round white weight with a wooden block for the pivot
	Toon.part(lamp, Toon.cylinder(0.4, 0.43, 0.12, 22), WHITE, Vector3(0, 0.06, 0), Vector3.ZERO, {"outline": 0.025})
	Toon.part(lamp, Toon.box(Vector3(0.16, 0.2, 0.16)), WOOD, Vector3(0, 0.22, 0.02), Vector3.ZERO, {"outline": 0.015})
	var p0 := Vector3(0, 0.3, 0.02)  # base pivot
	var p1 := Vector3(0, 1.15, -0.32)  # elbow, leaning back
	var p2 := Vector3(0, 1.82, 0.12)  # head pivot, reaching forward
	for side in [-1.0, 1.0]:
		_rod(lamp, p0 + Vector3(side * 0.05, 0, 0), p1 + Vector3(side * 0.05, 0, 0), 0.05, WOOD)
		_rod(lamp, p1 + Vector3(side * 0.05, 0, 0), p2 + Vector3(side * 0.05, 0, 0), 0.045, WOOD)
	for p in [p0, p1, p2]:
		Toon.part(lamp, Toon.cylinder(0.03, 0.03, 0.18, 8), BRASS, p, Vector3(0, 0, 90), {"outline": 0.008})
	# the shade: a white dome tipped down over the base
	var dir := Vector3(0, -1.0, 0.28).normalized()
	var shade := Node3D.new()
	shade.position = p2 + Vector3(0, -0.02, 0.18)
	shade.basis = Basis(Quaternion(Vector3.DOWN, dir))
	lamp.add_child(shade)
	_rod(lamp, p2, shade.position, 0.05, WHITE)
	var dome := Toon.part(shade, Toon.sphere(0.32, 18, 9, true), WHITE, Vector3.ZERO, Vector3.ZERO, {"outline": 0.025})
	dome.scale = Vector3(1, 0.85, 1)
	Toon.part(shade, Toon.cylinder(0.07, 0.09, 0.1, 10), WHITE, Vector3(0, 0.3, 0), Vector3.ZERO, {"outline": 0.015})
	# inside the shade: grey when off, the bulb's glow when on
	Toon.part(shade, Toon.cylinder(0.3, 0.3, 0.012, 18), INSIDE_OFF, Vector3(0, -0.005, 0), Vector3.ZERO, {"outline": 0.0})
	var on := Node3D.new()
	shade.add_child(on)
	Toon.part(on, Toon.cylinder(0.3, 0.3, 0.014, 18), core.lerp(Color.WHITE, 0.5), Vector3(0, -0.012, 0), Vector3.ZERO,
		{"outline": 0.0, "emission": 1.6})
	var bulb := Toon.part(on, Toon.sphere(0.1, 10, 6), core.lerp(Color.WHITE, 0.6), Vector3(0, -0.04, 0), Vector3.ZERO,
		{"outline": 0.0, "emission": 2.2})
	bulb.scale = Vector3(1, 0.7, 1)
	var reach := (shade.position.y - 0.05) / -dir.y
	var beam := MeshInstance3D.new()
	beam.mesh = Toon.cylinder(0.28, 0.28 + reach * 0.45, reach, 18)
	beam.material_override = _beam_material(color.lerp(core, 0.6))
	beam.position = Vector3(0, -reach * 0.5, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	on.add_child(beam)
	# the white cable, looping down the back of the arm to the base
	var cable := [p2 + Vector3(0.12, 0.05, -0.05), p1 + Vector3(0.13, 0.05, -0.08), p1 + Vector3(0.14, -0.3, -0.05),
		p0 + Vector3(0.14, 0.15, -0.12), Vector3(0.2, 0.13, -0.3)]
	for i in cable.size() - 1:
		_rod(lamp, cable[i], cable[i + 1], 0.022, WHITE.darkened(0.08))
	var light: OmniLight3D = null
	if with_light and not Engine.is_editor_hint():
		light = OmniLight3D.new()
		light.light_color = color.lerp(core, 0.5)
		light.omni_range = 6.0
		light.omni_attenuation = 0.8
		light.position = shade.position + dir * 0.35
		lamp.add_child(light)
	return {"on": on, "light": light, "head": lamp.transform * shade.position}


## A straight rod (a box) from `a` to `b`.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, thick: float, color: Color) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var n := Node3D.new()
	n.position = (a + b) * 0.5
	n.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	parent.add_child(n)
	Toon.part(n, Toon.box(Vector3(thick, d.length(), thick * 0.8)), color, Vector3.ZERO, Vector3.ZERO, {"outline": 0.01})


## The beam: a soft additive cone, faint, brighter near the shade.
static func _beam_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color, 0.09)
	return m
