extends Node3D
## The Half-Drawn's body (half_drawn_3d.gd), after the "half-forgotten
## ghostly model" sheet: a tall hooded ghost the Writer began and never
## finished. Its left half is inked and cel-shaded (pale ghostly teal,
## tattered robe, a bony face with glowing eyes, a nib-blade in its hand);
## its right half is raw pencil wireframe (half_drawn.gdshader) and its right
## arm ends in a stub, where the Writer ran out of time. A torn patch of
## nothing shows through its chest.
##
## The monster feeds it every frame: `dir` (where it faces on the ground),
## `speed` (0..1), `windup` / `strike` (0..1 progress, -1 = not), `dead`.
## It also answers the monster base's puppet calls: `facing`,
## look_at_point() and flash().

const Toon = preload("res://scripts/clearing/toon.gd")
const SKETCH_SHADER = preload("res://shaders/clearing/half_drawn.gdshader")

const GHOST := Color(0.58, 0.8, 0.78)
const GHOST_DARK := Color(0.3, 0.46, 0.5)
const BONE := Color(0.88, 0.92, 0.88)
const SOCKET := Color(0.04, 0.05, 0.08)
const EYE := Color(0.82, 1.0, 1.0)
const HOLE := Color(0.02, 0.02, 0.05)
const BLADE := Color(0.64, 0.68, 0.76)
const SHAFT := Color(0.14, 0.1, 0.12)

@export var model_scale := 1.3
@export var turn_speed := 9.0
## Height the ghost hovers at (the hem never quite touches the floor).
@export var hover := 0.16

# fed by half_drawn_3d.gd
var facing := 1  # set by the monster base; the model turns by `dir` instead
var dir := Vector3(0, 0, 1)
var speed := 0.0
var windup := -1.0
var strike := -1.0
var dead := false

var _yaw := 0.0
var _time := 0.0
var _flash := 0.0
var _body: Node3D
var _arm: Node3D  # the sword arm, pivoting at the shoulder
var _stub: Node3D  # the unfinished arm
var _head: Node3D
var _solid_mats: Array[ShaderMaterial] = []
var _sketch_mats: Array[ShaderMaterial] = []
var _eye_mat: ShaderMaterial
var _blade_mat: ShaderMaterial
var _light: OmniLight3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4123
	_time = randf() * 10.0
	_build()
	_yaw = atan2(-dir.x, -dir.z)


func look_at_point(_point: Vector3) -> void:
	pass  # it turns its whole body (dir) rather than its eyes


func flash() -> void:
	_flash = 1.0


# ----------------------------------------------------------------- build

func _mat(color: Color, opts := {}) -> ShaderMaterial:
	var m: ShaderMaterial = Toon.material(color, opts).duplicate()
	_solid_mats.append(m)
	return m


func _sketch_mat(rings := 7.0, meridians := 12.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKETCH_SHADER
	m.set_shader_parameter("rings", rings)
	m.set_shader_parameter("meridians", meridians)
	_sketch_mats.append(m)
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	var root := Toon.fresh_root(self)
	root.scale = Vector3.ONE * model_scale
	_body = _pivot(root, Vector3(0, hover, 0))
	# the robe: a flared shell with a torn hem; the left half inked, the
	# right half left as pencil wireframe
	var robe := [Vector2(0.56, 0.0), Vector2(0.48, 0.35), Vector2(0.38, 0.75), Vector2(0.31, 1.05), Vector2(0.27, 1.28), Vector2(0.17, 1.42)]
	_part(_body, _shell(robe, PI, TAU, 14, 0.32), _mat(GHOST, {"emission": 0.35}))
	# its lining, seen through the pencil half (else the ink outline shows)
	_rng.seed = 4123
	_part(_body, _shell(robe, PI, TAU, 14, 0.32, true), _mat(GHOST_DARK, {"emission": 0.2, "outline": 0.0}))
	_rng.seed = 4124
	_part(_body, _shell(robe, 0.0, PI, 14, 0.32), _sketch_mat())
	# a rope belt and a scarf wrapped at the neck (inked side only)
	_part(_body, _shell([Vector2(0.335, 0.9), Vector2(0.33, 0.97)], PI - 0.15, TAU + 0.15, 10), _mat(GHOST_DARK, {"outline": 0.02}))
	_part(_body, _shell([Vector2(0.2, 1.36), Vector2(0.22, 1.44), Vector2(0.17, 1.52)], PI, TAU, 10), _mat(GHOST.lightened(0.15), {"outline": 0.025}))
	# the torn hole in its chest: nothing shows through
	_part(_body, _hole_mesh(), _mat(HOLE, {"outline": 0.0}), Vector3(-0.06, 1.12, -0.315), Vector3(0.12, 0.0, 0.0))
	# head: a bony face in a pointed hood
	_head = _pivot(_body, Vector3(0, 1.6, 0))
	_part(_head, Toon.sphere(0.15, 12, 8), _mat(BONE, {"emission": 0.25, "outline": 0.03}), Vector3(0, 0.02, -0.03), Vector3.ZERO, Vector3(1.0, 1.25, 1.0))
	for side in [-1, 1]:
		_part(_head, Toon.sphere(0.052, 8, 5), _mat(SOCKET, {"outline": 0.0}), Vector3(side * 0.062, 0.05, -0.145), Vector3.ZERO, Vector3(1.0, 1.2, 1.0))
	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = Toon.TOON_SHADER
	_eye_mat.set_shader_parameter("albedo", EYE)
	_eye_mat.set_shader_parameter("emission_strength", 2.5)
	for side in [-1, 1]:
		_part(_head, Toon.sphere(0.026, 8, 5), _eye_mat, Vector3(side * 0.062, 0.05, -0.185))
	_part(_head, Toon.box(Vector3(0.02, 0.05, 0.02)), _mat(SOCKET, {"outline": 0.0}), Vector3(0, -0.02, -0.175))
	for k in 5:  # a row of teeth
		_part(_head, Toon.box(Vector3(0.016, 0.03, 0.02)), _mat(SOCKET, {"outline": 0.0}), Vector3(-0.05 + k * 0.025, -0.1, -0.15))
	# the unfinished half of the face: a pencil mesh laid over it
	_part(_head, _shell([Vector2(0.0, -0.17), Vector2(0.12, -0.12), Vector2(0.16, 0.0), Vector2(0.14, 0.12), Vector2(0.0, 0.2)], PI * 0.5, PI * 1.05, 6), _sketch_mat(14.0, 10.0), Vector3(0, 0.02, -0.03))
	var hood := [Vector2(0.24, -0.2), Vector2(0.28, 0.0), Vector2(0.26, 0.14), Vector2(0.19, 0.27), Vector2(0.08, 0.38), Vector2(0.0, 0.44)]
	_part(_head, _shell(hood, PI + 0.85, TAU, 10), _mat(GHOST, {"emission": 0.3}), Vector3(0, 0, 0.03))
	_part(_head, _shell(hood, PI + 0.85, TAU, 10, 0.0, true), _mat(GHOST_DARK.darkened(0.5), {"outline": 0.0}), Vector3(0, 0, 0.03))
	_part(_head, _shell(hood, 0.0, PI - 0.85, 10), _sketch_mat(12.0, 10.0), Vector3(0, 0, 0.03))
	# the sword arm (inked side): sleeve, bony hand and the nib-blade
	_arm = _pivot(_body, Vector3(-0.3, 1.36, 0))
	var sleeve := [Vector2(0.12, -0.62), Vector2(0.1, -0.4), Vector2(0.075, -0.15), Vector2(0.08, 0.0)]
	_part(_arm, _shell(sleeve, 0.0, TAU, 10, 0.12), _mat(GHOST, {"emission": 0.3}))
	_part(_arm, Toon.sphere(0.06, 8, 5), _mat(BONE, {"emission": 0.2, "outline": 0.02}), Vector3(0, -0.66, 0))
	_build_blade(_pivot(_arm, Vector3(0, -0.68, 0)))
	# the stub arm (pencil side): it stops short, a cut end showing
	_stub = _pivot(_body, Vector3(0.3, 1.36, 0))
	_part(_stub, _shell([Vector2(0.085, -0.36), Vector2(0.08, -0.15), Vector2(0.08, 0.0)], 0.0, TAU, 10), _sketch_mat(16.0, 10.0))
	_part(_stub, Toon.cylinder(0.085, 0.085, 0.02, 10), _mat(GHOST_DARK, {"outline": 0.02}), Vector3(0, -0.36, 0))
	_part(_stub, Toon.cylinder(0.04, 0.04, 0.025, 8), _mat(HOLE, {"outline": 0.0}), Vector3(0, -0.365, 0))
	# a faint cold light, so it reads as a ghost in the dark
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.95, 0.95)
	_light.light_energy = 0.5
	_light.omni_range = 2.4
	_light.position = Vector3(0, 1.3, -0.3)
	_body.add_child(_light)


## The nib-blade: a quill-shaft grip, a little crossguard and a long blade
## shaped like a split pen nib, held along -Y.
func _build_blade(hand: Node3D) -> void:
	_part(hand, Toon.cylinder(0.025, 0.03, 0.34, 6), _mat(SHAFT, {"outline": 0.015}), Vector3(0, 0.0, 0))
	_part(hand, Toon.box(Vector3(0.2, 0.035, 0.06)), _mat(BLADE.darkened(0.35), {"outline": 0.015}), Vector3(0, -0.17, 0))
	_blade_mat = _mat(BLADE, {"outline": 0.02})
	_part(hand, Toon.cylinder(0.0, 0.075, 0.95, 4), _blade_mat, Vector3(0, -0.66, 0), Vector3(PI, 0, 0), Vector3(1.0, 1.0, 0.28))
	# the nib's slit and breather hole, in ink
	_part(hand, Toon.box(Vector3(0.008, 0.5, 0.03)), _mat(SOCKET, {"outline": 0.0}), Vector3(0, -0.8, 0))
	_part(hand, Toon.cylinder(0.018, 0.018, 0.03, 8), _mat(SOCKET, {"outline": 0.0}), Vector3(0, -0.52, 0), Vector3(PI * 0.5, 0, 0))


## A surface of revolution round Y. `profile`: [Vector2(radius, y)] from
## bottom to top; it sweeps from angle a0 to a1 (x = sin, z = cos, so PI
## faces -Z). `jag` tears the bottom edge; `inside` faces it inwards.
func _shell(profile: Array, a0: float, a1: float, segs: int, jag := 0.0, inside := false) -> ArrayMesh:
	var rings := []
	for j in profile.size():
		var pr: Vector2 = profile[j]
		var ring := []
		for i in segs + 1:
			var a := lerpf(a0, a1, float(i) / segs)
			var y := pr.y
			if j == 0 and jag > 0.0:
				y -= jag * (_rng.randf() * 0.55 + (0.45 if i % 2 == 0 else 0.0))
			ring.append(Vector3(sin(a) * pr.x, y, cos(a) * pr.x))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in profile.size() - 1:
		for i in segs:
			_quad(st, rings[j][i], rings[j][i + 1], rings[j + 1][i + 1], rings[j + 1][i], inside)
	return st.commit()


## Adds quad a-b-c-d facing away from the Y axis (or towards it).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: bool) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		var centre := (p0 + p1 + p2) / 3.0
		var out := Vector3(centre.x, 0.0, centre.z).normalized()
		if inside:
			out = -out
		if (p2 - p0).cross(p1 - p0).dot(out) < 0.0:
			var tmp := p1
			p1 = p2
			p2 = tmp
		for p in [p0, p1, p2]:
			var n := Vector3(p.x, 0.0, p.z).normalized()
			st.set_normal(-n if inside else n)
			st.add_vertex(p)


## The torn patch in its chest: a jagged flat polygon facing -Z.
func _hole_mesh() -> ArrayMesh:
	var pts := [Vector2(-0.1, 0.14), Vector2(0.05, 0.16), Vector2(0.13, 0.03), Vector2(0.09, -0.13),
		Vector2(-0.04, -0.16), Vector2(-0.13, -0.05)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		for v in [Vector3.ZERO, Vector3(q.x, q.y, 0.0), Vector3(p.x, p.y, 0.0)]:
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(v)
	return st.commit()


# --------------------------------------------------------------- animate

func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	var f := Vector3(dir.x, 0.0, dir.z)
	if f.length() > 0.01 and not dead:
		_yaw = lerp_angle(_yaw, atan2(-f.x, -f.z), 1.0 - exp(-turn_speed * delta))
	rotation.y = _yaw
	# drifting: a slow bob and sway, leaning into its movement
	_body.position.y = hover + sin(_time * 2.1) * 0.06
	var lean := 0.12 * clampf(speed, 0.0, 1.0)
	var arm_x := 0.35 + 0.08 * sin(_time * 1.7)
	var arm_z := -0.25
	var eyes := 2.5
	var glint := 0.0
	if windup >= 0.0:
		# raising the blade high behind its head: a slow, readable tell
		var t := clampf(windup, 0.0, 1.0)
		lean -= 0.15 * t
		arm_x = lerpf(arm_x, -2.6, smoothstep(0.0, 0.7, t))
		arm_z = lerpf(arm_z, -0.4, t)
		eyes = 2.5 + 4.0 * t
		glint = 1.5 * t
	elif strike >= 0.0:
		var t := clampf(strike, 0.0, 1.0)
		lean += 0.25 * (1.0 - t)
		arm_x = lerpf(-2.6, 1.1, 1.0 - pow(1.0 - t, 3.0))
		arm_z = -0.4
		eyes = 6.5
		glint = 1.0 - t
	_body.rotation.x = lerp_angle(_body.rotation.x, -lean, 1.0 - exp(-10.0 * delta))
	_arm.rotation.x = arm_x
	_arm.rotation.z = arm_z
	_stub.rotation.z = 0.9 + 0.1 * sin(_time * 1.3 + 1.0)
	_stub.rotation.x = 0.2 * sin(_time * 1.1)
	_head.rotation.z = 0.08 * sin(_time * 0.9)
	_eye_mat.set_shader_parameter("emission_strength", eyes)
	_blade_mat.set_shader_parameter("emission_strength", glint)
	for m in _solid_mats:
		m.set_shader_parameter("whiten", _flash * 0.85)
	for m in _sketch_mats:
		m.set_shader_parameter("flash", _flash)
	_light.light_energy = 0.5 + 0.6 * maxf(windup, 0.0)
