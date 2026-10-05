extends Node3D
## The body of the Half-Drawn (half_drawn_3d.gd): a scribble the Writer
## started and never finished, drawn in 3D strokes (scribble_stroke.gdshader:
## camera-facing ribbons that "boil" like hand-drawn animation).
##  - a body of tangled scribble loops, a few of them inked, the rest pencil,
##    with hatching across its front
##  - a head that is still only construction lines: two guide circles, the
##    cross for the face, an inked brow and a jagged mouth, and two eyes
##  - its right arm sketched in full and ending in a nib-blade drawn in ink;
##    its left arm stops at the elbow in a dashed pencil guess
##  - a scribbled tail trailing to the floor instead of legs
## Out of the Ember's light it is a faint pale ghost (`reveal` 0); in it the
## strokes ink in (1). The monster sets `reveal`, `dir`, `speed`, `windup` /
## `strike` (0..1 progress, -1 = not) and `dead`; the model also answers the
## monster base's puppet calls (`facing`, look_at_point(), flash()).

const STROKE_SHADER = preload("res://shaders/clearing/scribble_stroke.gdshader")
const INK := Color(0.05, 0.04, 0.08)
const PENCIL := Color(0.42, 0.44, 0.5)
const EYE := Color(1.0, 0.96, 0.85)

@export var model_scale := 1.25
@export var turn_speed := 11.0
## Height its body hovers at; the tail trails down to the floor.
@export var hover := 0.1

# fed by half_drawn_3d.gd
var facing := 1  # set by the monster base; the model turns by `dir` instead
var dir := Vector3(0, 0, 1)
var speed := 0.0
var windup := -1.0
var strike := -1.0
var dead := false
## 0 = out of the Ember's light (a faint ghost) .. 1 = inked in.
var reveal := 0.0

var _yaw := 0.0
var _time := 0.0
var _flash := 0.0
var _shown := 0.0  # eases towards `reveal`
var _body: Node3D
var _arm: Node3D  # the blade arm, pivoting at the shoulder
var _stub: Node3D  # the unfinished arm
var _head: Node3D
var _tail: Node3D
var _mat: ShaderMaterial
var _eye_mat: StandardMaterial3D
var _pupil_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2207
	_time = randf() * 10.0
	_build()
	_yaw = atan2(-dir.x, -dir.z)


func look_at_point(_point: Vector3) -> void:
	pass  # it turns its whole body (dir) rather than its eyes


func flash() -> void:
	_flash = 1.0


# ----------------------------------------------------------------- build

func _build() -> void:
	var old := get_node_or_null("Generated")
	if old:
		old.free()
	var root := Node3D.new()
	root.name = "Generated"
	root.scale = Vector3.ONE * model_scale
	add_child(root)
	_mat = ShaderMaterial.new()
	_mat.shader = STROKE_SHADER
	_body = _pivot(root, Vector3(0, hover, 0))
	_part(_body, _body_strokes())
	_head = _pivot(_body, Vector3(0, 1.62, -0.02))
	_part(_head, _head_strokes())
	_build_eyes()
	_arm = _pivot(_body, Vector3(-0.36, 1.25, 0.0))
	_part(_arm, _blade_arm_strokes())
	_stub = _pivot(_body, Vector3(0.36, 1.25, 0.0))
	_part(_stub, _stub_strokes())
	_tail = _pivot(_body, Vector3(0, 0.55, 0.05))
	_part(_tail, _tail_strokes())


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Adds one stroke along `pts` (a ribbon the shader turns to the camera).
func _stroke(st: SurfaceTool, pts: PackedVector3Array, col: Color, w := 1.0) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var t := (b - a).normalized()
		for v in [[a, -1.0], [a, 1.0], [b, 1.0], [a, -1.0], [b, 1.0], [b, -1.0]]:
			st.set_color(Color(col.r, col.g, col.b, w))
			st.set_normal(t)
			st.set_uv(Vector2(v[1], 0.0))
			st.add_vertex(v[0])


func _jit(amount: float) -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * amount


## A wobbly loop: `n` points round `centre` in the plane of `basis`'s x / y,
## going round `turns` times (scribbles overlap themselves).
func _loop(centre: Vector3, basis: Basis, rx: float, ry: float, n: int, turns := 1.1, wob := 0.04) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var a0 := _rng.randf() * TAU
	for i in n + 1:
		var a := a0 + TAU * turns * i / n
		var r := 1.0 + _rng.randf_range(-wob, wob) * 3.0
		pts.append(centre + basis * Vector3(cos(a) * rx * r, sin(a) * ry * r, 0.0) + _jit(wob * 0.5))
	return pts


func _line(a: Vector3, b: Vector3, n := 6, wob := 0.02) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		pts.append(a.lerp(b, float(i) / n) + (_jit(wob) if i > 0 and i < n else Vector3.ZERO))
	return pts


func _commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


## The tangled body: scribble loops wound round an egg, some inked, with
## hatching across the front and an inked outline on one side only.
func _body_strokes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(0, 0.98, 0)
	for k in 11:
		var b := Basis.from_euler(Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6)))
		var loop := _loop(c, b, 0.4, 0.5, 26, _rng.randf_range(1.0, 1.6), 0.05)
		for i in loop.size():
			var p := loop[i] - c
			loop[i] = c + Vector3(p.x, p.y * 1.12, p.z * 0.85)  # an egg, taller than wide
		_stroke(st, loop, INK if k % 3 == 0 else PENCIL, 1.3 if k % 3 == 0 else 0.8)
	# hatching across the belly
	for i in 7:
		var y := 0.62 + i * 0.07
		_stroke(st, _line(Vector3(-0.3 + i * 0.02, y, -0.36), Vector3(0.05 + i * 0.03, y + 0.22, -0.4), 3, 0.01), PENCIL, 0.6)
	# half an outline, inked in; the other half never got there
	var outline := PackedVector3Array()
	for i in 17:
		var a := lerpf(PI * 0.5, PI * 1.55, float(i) / 16)
		outline.append(c + Vector3(cos(a) * 0.46, sin(a) * 0.6, -0.08) + _jit(0.015))
	_stroke(st, outline, INK, 1.8)
	return _commit(st)


## The head: guide circles and the face cross, a brow and a jagged mouth.
func _head_strokes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stroke(st, _loop(Vector3.ZERO, Basis(), 0.27, 0.27, 24, 1.05, 0.02), PENCIL, 0.9)
	_stroke(st, _loop(Vector3.ZERO, Basis(Vector3.UP, PI * 0.5), 0.27, 0.27, 24, 1.05, 0.02), PENCIL, 0.6)
	_stroke(st, _line(Vector3(0, 0.28, -0.24), Vector3(0, -0.3, -0.25), 6, 0.01), PENCIL, 0.6)
	_stroke(st, _line(Vector3(-0.27, 0.02, -0.18), Vector3(0.27, 0.02, -0.18), 6, 0.01), PENCIL, 0.6)
	# an inked brow over the top, angry
	var brow := PackedVector3Array()
	for i in 11:
		var a := lerpf(PI * 0.15, PI * 0.85, float(i) / 10)
		brow.append(Vector3(cos(a) * 0.29, sin(a) * 0.29 - 0.02 - absf(cos(a)) * 0.04, -0.12))
	_stroke(st, brow, INK, 1.6)
	# a jagged mouth
	var mouth := PackedVector3Array()
	for i in 9:
		mouth.append(Vector3(-0.15 + i * 0.0375, -0.12 - (0.04 if i % 2 == 0 else 0.0), -0.25))
	_stroke(st, mouth, INK, 1.1)
	return _commit(st)


func _build_eyes() -> void:
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_eye_mat.albedo_color = EYE
	_pupil_mat = _eye_mat.duplicate()
	_pupil_mat.albedo_color = INK
	var eye := SphereMesh.new()
	eye.radius = 0.062
	eye.height = 0.124
	var pupil := SphereMesh.new()
	pupil.radius = 0.028
	pupil.height = 0.056
	for side in [-1, 1]:
		var e := MeshInstance3D.new()
		e.mesh = eye
		e.material_override = _eye_mat
		e.position = Vector3(side * 0.1, 0.04, -0.23)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(e)
		var p := MeshInstance3D.new()
		p.mesh = pupil
		p.material_override = _pupil_mat
		p.position = Vector3(side * 0.1, 0.03, -0.285)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(p)


## The blade arm: a sketched arm, a scribbled fist and a long nib-blade
## drawn in ink, hanging along -Y from the shoulder.
func _blade_arm_strokes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stroke(st, _line(Vector3(-0.06, 0, 0), Vector3(-0.05, -0.58, 0), 6, 0.025), PENCIL, 0.9)
	_stroke(st, _line(Vector3(0.06, 0, 0), Vector3(0.05, -0.58, 0), 6, 0.025), INK, 1.1)
	_stroke(st, _loop(Vector3(0, -0.64, 0), Basis(), 0.09, 0.08, 14, 1.8, 0.04), INK, 1.2)
	# the nib-blade: outline, slit, breather hole, a little shading
	var tip := Vector3(0, -1.55, 0)
	var left := Vector3(-0.11, -0.95, 0)
	var right := Vector3(0.11, -0.95, 0)
	var top_l := Vector3(-0.07, -0.72, 0)
	var top_r := Vector3(0.07, -0.72, 0)
	var nib := PackedVector3Array([top_l, left, tip, right, top_r, top_l])
	_stroke(st, nib, INK, 1.5)
	_stroke(st, _line(tip, Vector3(0, -0.98, 0), 4, 0.004), INK, 0.8)
	_stroke(st, _loop(Vector3(0, -0.92, 0), Basis(), 0.03, 0.03, 10, 1.0, 0.0), INK, 0.8)
	for i in 4:
		var y := -1.05 - i * 0.1
		var half := 0.1 * (1.0 - (absf(y) - 0.95) / 0.6)
		_stroke(st, _line(Vector3(-half, y, 0), Vector3(-half * 0.2, y - 0.05, 0), 2, 0.0), PENCIL, 0.5)
	return _commit(st)


## The unfinished arm: an upper arm, then only a dashed pencil guess.
func _stub_strokes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stroke(st, _line(Vector3(-0.05, 0, 0), Vector3(-0.04, -0.32, 0), 4, 0.02), INK, 1.0)
	_stroke(st, _line(Vector3(0.05, 0, 0), Vector3(0.04, -0.32, 0), 4, 0.02), PENCIL, 0.8)
	for i in 4:
		var y0 := -0.4 - i * 0.12
		_stroke(st, _line(Vector3(0, y0, 0), Vector3(0, y0 - 0.06, 0), 1, 0.0), PENCIL, 0.6)
	return _commit(st)


## A scribbled tail trailing to the floor instead of legs.
func _tail_strokes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var pts := PackedVector3Array()
		var off := (k - 1) * 0.12
		for i in 13:
			var t := float(i) / 12
			pts.append(Vector3(off * (1.0 - t) + sin(t * 9.0 + k) * 0.12 * t, -t * 0.55, t * 0.35 + cos(t * 7.0 + k) * 0.05))
		_stroke(st, pts, PENCIL if k != 1 else INK, lerpf(1.0, 0.6, float(k) / 2))
	return _commit(st)


# --------------------------------------------------------------- animate

func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_shown = move_toward(_shown, clampf(reveal, 0.0, 1.0), delta * 5.0)
	var f := Vector3(dir.x, 0.0, dir.z)
	if f.length() > 0.01 and not dead:
		_yaw = lerp_angle(_yaw, atan2(-f.x, -f.z), 1.0 - exp(-turn_speed * delta))
	rotation.y = _yaw
	_body.position.y = hover + sin(_time * 2.6) * 0.05
	var lean := 0.15 * clampf(speed, 0.0, 1.0)
	var arm_x := 0.3 + 0.1 * sin(_time * 2.0)
	var arm_z := -0.3
	var eye := 1.0
	if windup >= 0.0:
		# the blade goes up high behind its head, eyes flaring: the tell
		var t := clampf(windup, 0.0, 1.0)
		lean -= 0.2 * t
		arm_x = lerpf(arm_x, -2.7, smoothstep(0.0, 0.6, t))
		arm_z = lerpf(arm_z, -0.45, t)
		eye = 1.0 + 1.5 * t
	elif strike >= 0.0:
		var t := clampf(strike, 0.0, 1.0)
		lean += 0.3 * (1.0 - t)
		arm_x = lerpf(-2.7, 1.2, 1.0 - pow(1.0 - t, 3.0))
		arm_z = -0.45
		eye = 2.5
	_body.rotation.x = lerp_angle(_body.rotation.x, -lean, 1.0 - exp(-12.0 * delta))
	_arm.rotation.x = arm_x
	_arm.rotation.z = arm_z
	_stub.rotation.z = 0.7 + 0.15 * sin(_time * 1.7)
	_head.rotation.z = 0.1 * sin(_time * 1.3)
	_tail.rotation.x = 0.25 * sin(_time * 2.2)
	_tail.rotation.z = 0.2 * sin(_time * 1.6 + 1.0)
	_mat.set_shader_parameter("reveal", _shown)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("fade", 0.0 if dead else 1.0)
	# its eyes show even as a ghost, faintly: the one thing you can catch
	var eye_a := lerpf(0.3, 1.0, _shown) * minf(eye, 1.0)
	_eye_mat.albedo_color = Color(EYE.r, EYE.g, EYE.b, eye_a).lerp(Color(1.0, 0.55, 0.3, eye_a), clampf(eye - 1.0, 0.0, 1.0))
	_pupil_mat.albedo_color = Color(INK, eye_a * _shown)
