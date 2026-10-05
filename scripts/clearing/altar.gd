@tool
extends Node3D
## The Spine's centrepiece: the Broken Nib. The Writer's own pen nib, snapped
## off and driven point-first into a cracked stone plinth, tied down with
## black binding thread like the stitches in a book's spine, with ink still
## seeping out of the split and pooling round the base. (It replaced a red-eyed
## stele that looked too much like somebody else's game.)

const Toon = preload("res://scripts/clearing/toon.gd")
const SPLAT_SHADER = preload("res://shaders/clearing/ink_splat.gdshader")

@export var stone := Color(0.3, 0.31, 0.34):
	set(v):
		stone = v
		_rebuild()
@export var metal := Color(0.36, 0.38, 0.44):
	set(v):
		metal = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	# ink pooled round the plinth
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(6.4, 6.4)
	var pool := ShaderMaterial.new()
	pool.shader = SPLAT_SHADER
	pool.set_shader_parameter("seed", 11.0)
	pool.set_shader_parameter("ink", Color(0.03, 0.03, 0.05))
	pool.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = pool
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# cracked octagonal plinth, two tiers, the top one split and shifted
	Toon.part(root, Toon.cylinder(2.1, 2.2, 0.4, 8), stone.darkened(0.1), Vector3(0, 0.2, 0), Vector3(0, 22.5, 0), {"tile": 0.0})
	for k in 2:
		var half := Node3D.new()
		half.position = Vector3((k - 0.5) * 0.12, 0.4, (k - 0.5) * 0.06)
		half.rotation_degrees = Vector3(0, 22.5 + k * 180.0, (k - 0.5) * 3.0)
		root.add_child(half)
		var block := Toon.part(half, Toon.cylinder(1.45, 1.5, 0.55, 8), stone, Vector3(0, 0.27, 0))
		block.scale = Vector3(1.0, 1.0, 0.5)
		block.position.z = 0.36
	# the nib: a flat blade, point down, sunk into the split
	var nib := Node3D.new()
	nib.position = Vector3(0, 0.6, 0)
	nib.rotation_degrees = Vector3(-8, 14, 9)
	root.add_child(nib)
	var h := 3.6
	# a four-sided cone flattened into a ridged blade, flipped point-down
	var blade := Toon.part(nib, Toon.cylinder(0.0, 0.95, h, 4), metal, Vector3(0, h * 0.5, 0), Vector3.ZERO, {"outline": 0.06})
	blade.basis = Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(1.0, 1.0, 0.3))
	# the slit down the middle, the breather hole, and ink leaking out of it
	Toon.part(nib, Toon.box(Vector3(0.07, h * 0.62, 0.36)), Toon.INK, Vector3(0, h * 0.36, 0), Vector3.ZERO, {"outline": 0.0})
	var hole := Toon.part(nib, Toon.cylinder(0.17, 0.17, 0.38, 12), Toon.INK, Vector3(0, h * 0.68, 0), Vector3(90, 0, 0), {"outline": 0.0})
	hole.scale = Vector3.ONE
	# snapped-off shoulders: jagged teeth along the broken top edge
	for i in 5:
		var x := -0.75 + i * 0.375
		var tooth_h := rng.randf_range(0.25, 0.6)
		Toon.part(nib, Toon.prism(Vector3(0.36, tooth_h, 0.26)), metal.darkened(0.1), Vector3(x, h + tooth_h * 0.5 - 0.05, 0),
			Vector3(0, 0, rng.randf_range(-12, 12)), {"outline": 0.04})
	# black binding thread, stitched from the nib down to iron stakes
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var stake := Vector3(cos(a) * 2.9, 0.0, sin(a) * 2.9)
		Toon.part(root, Toon.cylinder(0.05, 0.08, 0.7, 6), Color(0.12, 0.12, 0.14), stake + Vector3(0, 0.3, 0), Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), {"outline": 0.025})
		var top := nib.transform * Vector3(cos(a) * 0.35, h * 0.72, sin(a) * 0.12)
		var from := stake + Vector3(0, 0.55, 0)
		var d := top - from
		var cord := Toon.part(root, Toon.cylinder(0.025, 0.025, d.length(), 5), Toon.INK, (top + from) * 0.5, Vector3.ZERO, {"outline": 0.0})
		cord.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
		# a cross-stitch where the thread crosses the plinth's edge
		Toon.part(root, Toon.box(Vector3(0.3, 0.04, 0.05)), Toon.INK, stake * 0.62 + Vector3(0, 0.95, 0), Vector3(0, -rad_to_deg(a), 45), {"outline": 0.0})
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(2.0, 3.0), Vector3(0, 1.5, 0))
