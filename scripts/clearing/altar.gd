@tool
extends Node3D
## The Spine's centrepiece: a shrine to Vesper. A statue of him (the 3D
## Vesper, vesper_3d.gd, frozen pale as plaster) stands on a tiered stone
## plinth, sword raised overhead, the Ember's glow on the blade, a gilt
## "VESPER" plaque at his feet. Offerings crowd the tiers: a red scarf like
## his draped over the edge, ink pots, quills, stacks of comic pages and
## cream candles with golden flames. Round it a ring of the Writer's marks is
## burnt into the dirt (sigil_ring.gdshader), glowing Ember gold. It lights
## its own pool in the Gutter's darkness (group "glow").
## (The statue is only built in the game, not in the editor.)

const Toon = preload("res://scripts/clearing/toon.gd")
const RING_SHADER = preload("res://shaders/world25/sigil_ring.gdshader")
const VesperModel = preload("res://scripts/clearing/vesper_3d.gd")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const GOLD := Color(1.0, 0.8, 0.32)
const EMBER := Color(1.0, 0.62, 0.22)
const PAGE := Color(0.95, 0.92, 0.84)

@export var stone := Color(0.72, 0.68, 0.62):
	set(v):
		stone = v
		_rebuild()
## Radius of the ring round the shrine (0 = none).
@export var ring_radius := 4.4:
	set(v):
		ring_radius = v
		_rebuild()
@export var ring_color := Color(1.0, 0.62, 0.22):
	set(v):
		ring_color = v
		_rebuild()
## Size of the statue (vesper_3d.gd model_scale).
@export var statue_scale := 1.9

## The pool it carves in the darkness (darkness.gd).
var glow_radius := 4.4

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
		rm.set_shader_parameter("glow", 1.3)
		var ring := MeshInstance3D.new()
		ring.mesh = q
		ring.material_override = rm
		ring.position.y = 0.025
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	var opts := {"moss": 0.25}
	var tiers := [[2.3, 0.3], [1.75, 0.38], [1.25, 0.5]]  # radius, height
	var y := 0.0
	for i in tiers.size():
		var r: float = tiers[i][0]
		var h: float = tiers[i][1]
		Toon.part(root, Toon.cylinder(r, r + 0.05, h, 20), stone.darkened(0.06 * i), Vector3(0, y + h * 0.5, 0),
			Vector3.ZERO, opts)
		# a gilt band round the lip
		Toon.part(root, Toon.cylinder(r + 0.02, r + 0.02, 0.05, 20), GOLD.darkened(0.15), Vector3(0, y + h - 0.03, 0),
			Vector3.ZERO, {"outline": 0.0, "emission": 0.15})
		y += h
		if i < 2:
			# offerings on the step: candles all round the front, and between
			# them ink pots, quills and stacks of pages
			var next_r: float = tiers[i + 1][0]
			var cr := (r + next_r) * 0.5 + 0.08
			var n := 9 - i * 3
			for k in n:
				var a := lerpf(-1.25, 1.25, float(k) / maxf(n - 1, 1)) + rng.randf_range(-0.06, 0.06)
				var at := Vector3(sin(a) * cr, y, cos(a) * cr)
				match k % 3:
					0:
						Toon.candle(root, at, rng.randf_range(0.2, 0.4), GOLD, Color(0.95, 0.9, 0.78))
					1:
						_ink_pot(root, at, rng.randf() * 360.0)
					_:
						if i == 0:
							_pages(root, at, rng)
						else:
							_quill(root, at, rad_to_deg(a))
	# the pedestal and its plaque
	var ped := Vector3(1.0, 0.45, 1.0)
	Toon.part(root, Toon.box(ped), stone.lightened(0.06), Vector3(0, y + ped.y * 0.5, 0), Vector3.ZERO, opts)
	Toon.part(root, Toon.box(Vector3(1.1, 0.08, 1.1)), GOLD.darkened(0.2), Vector3(0, y + ped.y, 0), Vector3.ZERO, {"outline": 0.02})
	var plaque := Label3D.new()
	plaque.text = "VESPER"
	plaque.font = TITLE_FONT
	plaque.font_size = 64
	plaque.pixel_size = 0.006
	plaque.modulate = GOLD
	plaque.outline_size = 14
	plaque.outline_modulate = Toon.INK
	plaque.position = Vector3(0, y + ped.y * 0.5, ped.z * 0.5 + 0.01)
	root.add_child(plaque)
	# his red scarf, draped over the top tier's edge
	for k in 4:
		var a := 0.55 + k * 0.12
		Toon.part(root, Toon.box(Vector3(0.22, 0.06, 0.34 + k * 0.06)), Color(0.85, 0.22, 0.16),
			Vector3(sin(a) * 1.15, y - 0.02 - k * 0.07, cos(a) * 1.15), Vector3(-25.0 - k * 12.0, rad_to_deg(a), 0), {"outline": 0.02})
	var top := y + ped.y + 0.04
	if Engine.is_editor_hint():
		return
	_build_statue(root, top)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.72, 0.4)
	_light.light_energy = 1.4
	_light.omni_range = 6.0
	_light.position = Vector3(0, 1.6, 1.8)
	root.add_child(_light)
	Toon.collider(root, Toon.cylinder_shape(2.0, 3.0), Vector3(0, 1.5, 0))


## Vesper in stone: the game's own model, posed with his sword raised
## overhead and frozen, whitened like plaster, the Ember glowing on the blade.
func _build_statue(root: Node3D, top: float) -> void:
	var statue := VesperModel.new()
	statue.name = "Statue"
	statue.model_scale = statue_scale
	statue.position = Vector3(0, top, 0)
	root.add_child(statue)
	statue.facing_dir = Vector3(0, 0, 1)  # looking out over the Spine
	statue.on_floor = true
	statue.show_sword = true
	statue.combo = 3
	statue.swing = 0.0  # the overhead finisher at its height: sword raised
	statue.erase = 0.22  # paler, like painted plaster, with a soft glow
	for i in 40:
		statue._process(1.0 / 30.0)
	statue.set_process(false)
	var glow := OmniLight3D.new()
	glow.light_color = EMBER
	glow.light_energy = 1.6
	glow.omni_range = 3.5
	glow.position = Vector3(0, top + 3.6, 0.3)
	root.add_child(glow)
	var flame := Toon.billboard(root, Toon.FLAME_SHADER, Vector2(0.55, 0.75), Vector3(0, top + 3.7, 0.35),
		{"outer_color": EMBER, "core_color": Color(1.0, 0.95, 0.7), "brightness": 2.4})
	flame.name = "Ember"


func _ink_pot(root: Node3D, at: Vector3, yaw: float) -> void:
	Toon.part(root, Toon.cylinder(0.11, 0.14, 0.18, 10), Color(0.1, 0.1, 0.16), at + Vector3(0, 0.09, 0), Vector3(0, yaw, 0), {"outline": 0.015})
	Toon.part(root, Toon.cylinder(0.06, 0.06, 0.06, 8), Color(0.55, 0.38, 0.25), at + Vector3(0, 0.21, 0), Vector3.ZERO, {"outline": 0.01})


func _quill(root: Node3D, at: Vector3, yaw: float) -> void:
	var tilt := Vector3(-35, yaw + 20.0, 15)
	Toon.part(root, Toon.cylinder(0.008, 0.012, 0.55, 5), Color(0.9, 0.86, 0.75), at + Vector3(0, 0.22, 0), tilt, {"outline": 0.008})
	Toon.part(root, Toon.box(Vector3(0.1, 0.32, 0.015)), PAGE, at + Vector3(0, 0.36, -0.08), tilt, {"outline": 0.012})


## A little stack of comic pages, each with an inked panel border.
func _pages(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var yaw := rng.randf_range(-25, 25)
		Toon.part(root, Toon.box(Vector3(0.36, 0.02, 0.48)), PAGE.darkened(0.05 * k), at + Vector3(0, 0.012 + k * 0.022, 0), Vector3(0, yaw, 0), {"outline": 0.01})
	Toon.part(root, Toon.box(Vector3(0.26, 0.004, 0.18)), Toon.INK, at + Vector3(0, 0.072, -0.08), Vector3.ZERO, {"outline": 0.0})
	Toon.part(root, Toon.box(Vector3(0.26, 0.004, 0.14)), Color(0.3, 0.75, 0.85), at + Vector3(0, 0.072, 0.1), Vector3.ZERO, {"outline": 0.0})


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	_light.light_energy = 1.4 * (0.9 + 0.07 * sin(_time * 9.0) + 0.05 * sin(_time * 17.0 + 1.0))
