extends Node3D
## The body of the Half-Drawn (half_drawn_3d.gd): the hooded ghost from the
## "half-forgotten ghostly model" sheet, as an ink drawing the Writer never
## finished.
##  - its left half is drawn in: a pale fill with comic hatching in the
##    shadows (ink_fill.gdshader) under inked outlines (scribble_stroke
##    .gdshader: camera-facing strokes that "boil" like hand-drawn
##    animation): a tattered robe, a pointed hood round a skull face with
##    glowing eyes, a sleeve and a nib-blade, a torn hole in the chest
##  - its right half is only dashed pencil construction lines, and that arm
##    stops in a stub where the Writer ran out of time
## Out of the Ember's light (`reveal` 0) almost nothing of it shows: two
## glowing eyes (that flare orange when it winds up a swing), a few motes of
## ink and pencil dust drifting off it, and now and then a short piece of one
## of its lines. In the light (1) it is drawn in. The monster sets `reveal`, `dir`, `speed`,
## `windup` / `strike` (0..1 progress, -1 = not) and `dead`; the model also
## answers the monster base's puppet calls (`facing`, look_at_point(),
## flash()).

const STROKE_SHADER = preload("res://shaders/clearing/scribble_stroke.gdshader")
const FILL_SHADER = preload("res://shaders/clearing/ink_fill.gdshader")
const INK := Color(0.05, 0.04, 0.08)
const PENCIL := Color(0.45, 0.48, 0.55)
const GHOST := Color(0.6, 0.84, 0.8)
const BONE := Color(0.93, 0.94, 0.9)
const EYE := Color(0.85, 1.0, 1.0)
const EYE_FLARE := Color(1.0, 0.55, 0.3)
const BLADE := Color(0.62, 0.66, 0.76)
## The robe's profile: (radius, height) from the hem up.
const ROBE := [Vector2(0.56, 0.0), Vector2(0.48, 0.35), Vector2(0.38, 0.75), Vector2(0.31, 1.05), Vector2(0.27, 1.28), Vector2(0.17, 1.42)]
const HOOD := [Vector2(0.24, -0.2), Vector2(0.28, 0.0), Vector2(0.26, 0.14), Vector2(0.19, 0.27), Vector2(0.08, 0.38), Vector2(0.0, 0.44)]
const SLEEVE := [Vector2(0.12, -0.62), Vector2(0.1, -0.4), Vector2(0.075, -0.15), Vector2(0.08, 0.0)]

@export var model_scale := 1.3
@export var turn_speed := 11.0
## Height it hovers at (the hem never quite touches the floor).
@export var hover := 0.16

# fed by half_drawn_3d.gd
var facing := 1  # set by the monster base; the model turns by `dir` instead
var dir := Vector3(0, 0, 1)
var speed := 0.0
var windup := -1.0
var strike := -1.0
var dead := false
## 0 = out of the Ember's light (only hints of it) .. 1 = drawn in.
var reveal := 0.0

var _yaw := 0.0
var _time := 0.0
var _flash := 0.0
var _shown := 0.0  # eases towards `reveal`
var _body: Node3D
var _arm: Node3D  # the blade arm, pivoting at the shoulder
var _stub: Node3D  # the unfinished arm
var _head: Node3D
var _stroke_mat: ShaderMaterial
var _fill_mats: Array[ShaderMaterial] = []
var _eye_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _glows: Array[MeshInstance3D] = []
var _motes: CPUParticles3D
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

func _build() -> void:
	var old := get_node_or_null("Generated")
	if old:
		old.free()
	var root := Node3D.new()
	root.name = "Generated"
	root.scale = Vector3.ONE * model_scale
	add_child(root)
	_stroke_mat = ShaderMaterial.new()
	_stroke_mat.shader = STROKE_SHADER
	_stroke_mat.set_shader_parameter("seed", randf() * 100.0)
	_stroke_mat.render_priority = 1  # lines over the fills
	_body = _pivot(root, Vector3(0, hover, 0))
	# the robe: the left half drawn in, the right half only guessed at
	var robe_l := _grid(ROBE, PI, TAU, 14, 0.32)
	var robe_r := _grid(ROBE, 0.0, PI, 14, 0.32)
	_fill(_body, _surface(robe_l), GHOST, 0.85)
	_fill(_body, _surface(robe_r), GHOST, 0.1)
	var st := _strokes()
	_ink_outline(st, robe_l, [0, 4, 7, 10, 14], [0, 3])
	_stroke(st, _ring_pts(Vector2(0.33, 0.93), PI - 0.1, TAU + 0.1, 10), INK, 1.1)  # a rope belt
	_stroke(st, _ring_pts(Vector2(0.21, 1.44), PI, TAU, 8), INK, 1.2)  # the scarf at the neck
	_pencil_guides(st, robe_r, [3, 7, 11], [0, 2, 4])
	_chest_hole(st)
	_part(_body, st.commit(), _stroke_mat)
	# head: a skull in a pointed hood
	_head = _pivot(_body, Vector3(0, 1.6, 0))
	_fill(_head, _surface(_grid([Vector2(0.0, -0.19), Vector2(0.13, -0.14), Vector2(0.16, 0.0), Vector2(0.14, 0.13), Vector2(0.0, 0.2)], 0.0, TAU, 12)), BONE, 0.95)
	var hood_l := _grid(HOOD, PI + 0.85, TAU, 10)
	var hood_r := _grid(HOOD, 0.0, PI - 0.85, 10)
	_fill(_head, _surface(hood_l), GHOST, 0.85)
	_fill(_head, _surface(hood_r), GHOST, 0.1)
	var hs := _strokes()
	_ink_outline(hs, hood_l, [0, 5, 10], [0])
	_pencil_guides(hs, hood_r, [3, 7], [1, 3])
	# the face: socket rims, the nose, a row of teeth, the jaw
	for side in [-1, 1]:
		_stroke(hs, _circle(Vector3(side * 0.062, 0.05, -0.15), 0.05, 10), INK, 1.0)
	_stroke(hs, _line(Vector3(0, 0.0, -0.165), Vector3(0, -0.04, -0.17), 2, 0.0), INK, 0.9)
	_stroke(hs, _line(Vector3(-0.07, -0.1, -0.14), Vector3(0.07, -0.1, -0.14), 6, 0.004), INK, 0.8)
	for k in 5:
		var x := -0.05 + k * 0.025
		_stroke(hs, _line(Vector3(x, -0.08, -0.145), Vector3(x, -0.12, -0.145), 1, 0.0), INK, 0.6)
	_stroke(hs, _ring_pts(Vector2(0.15, 0.0), PI * 0.55, PI * 1.45, 10), INK, 1.2)  # the cheek line
	_part(_head, hs.commit(), _stroke_mat)
	_build_eyes()
	# the blade arm (drawn side)
	_arm = _pivot(_body, Vector3(-0.3, 1.36, 0))
	var sleeve := _grid(SLEEVE, 0.0, TAU, 10, 0.12)
	_fill(_arm, _surface(sleeve), GHOST, 0.85)
	var as_ := _strokes()
	_ink_outline(as_, sleeve, [0, 5], [0])
	_blade(as_)
	_part(_arm, as_.commit(), _stroke_mat)
	_fill(_arm, _blade_mesh(), BLADE, 0.9)
	# the stub arm: a dashed pencil guess, cut off
	_stub = _pivot(_body, Vector3(0.3, 1.36, 0))
	var ss := _strokes()
	for x in [-0.07, 0.07]:
		_dashed(ss, Vector3(x, 0, 0), Vector3(x * 0.9, -0.38, 0), 5, PENCIL, 0.8)
	_stroke(ss, _circle(Vector3(0, -0.38, 0), 0.07, 8, Vector3.RIGHT), PENCIL, 0.7)
	_part(_stub, ss.commit(), _stroke_mat)
	_build_motes()


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _fill(parent: Node3D, mesh: Mesh, color: Color, alpha: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = FILL_SHADER
	m.set_shader_parameter("fill", color)
	m.set_shader_parameter("fill_alpha", alpha)
	_fill_mats.append(m)
	_part(parent, mesh, m)


func _strokes() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A surface of revolution as rows of points: `profile` [Vector2(radius, y)]
## bottom to top, swept from a0 to a1 (x = sin, z = cos: PI faces -Z).
## `jag` tears the bottom row.
func _grid(profile: Array, a0: float, a1: float, segs: int, jag := 0.0) -> Array:
	var rows := []
	for j in profile.size():
		var pr: Vector2 = profile[j]
		var row := PackedVector3Array()
		for i in segs + 1:
			var a := lerpf(a0, a1, float(i) / segs)
			var y := pr.y
			if j == 0 and jag > 0.0:
				y -= jag * (_rng.randf() * 0.55 + (0.45 if i % 2 == 0 else 0.0))
			row.append(Vector3(sin(a) * pr.x, y, cos(a) * pr.x))
		rows.append(row)
	return rows


## The fill: quads between the grid's rows, normals pointing away from Y.
func _surface(rows: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows.size() - 1:
		var lo: PackedVector3Array = rows[j]
		var hi: PackedVector3Array = rows[j + 1]
		for i in lo.size() - 1:
			for p in [lo[i], lo[i + 1], hi[i + 1], lo[i], hi[i + 1], hi[i]]:
				var n := Vector3(p.x, 0.25, p.z).normalized()
				st.set_normal(n)
				st.add_vertex(p)
	return st.commit()


## Inked lines over a grid: the columns listed (meridians down the form) and
## the rows listed (the hem, rims), slightly overshooting like a quick pen.
func _ink_outline(st: SurfaceTool, rows: Array, cols: Array, ring_rows: Array) -> void:
	var segs: int = (rows[0] as PackedVector3Array).size() - 1
	for c in cols:
		var col := PackedVector3Array()
		for j in rows.size():
			col.append((rows[j] as PackedVector3Array)[mini(c, segs)] * 1.01)
		_stroke(st, col, INK, 1.4 if c == 0 or c == segs else 1.0)
	for r in ring_rows:
		var row: PackedVector3Array = rows[r]
		var pts := PackedVector3Array()
		for p in row:
			pts.append(p * 1.01)
		_stroke(st, pts, INK, 1.4 if r == 0 else 1.0)


## Construction lines over the unfinished half: dashed pencil.
func _pencil_guides(st: SurfaceTool, rows: Array, cols: Array, ring_rows: Array) -> void:
	for c in cols:
		for j in rows.size() - 1:
			if j % 2 == 0:
				_stroke(st, _line((rows[j] as PackedVector3Array)[c], (rows[j + 1] as PackedVector3Array)[c], 2, 0.006), PENCIL, 0.7)
	for r in ring_rows:
		var row: PackedVector3Array = rows[r]
		for i in range(0, row.size() - 1, 2):
			_stroke(st, _line(row[i], row[i + 1], 2, 0.006), PENCIL, 0.7)


## The torn hole in its chest: a jagged inked edge with nothing inside.
func _chest_hole(st: SurfaceTool) -> void:
	var c := Vector3(-0.06, 1.12, -0.31)
	var pts := PackedVector3Array()
	var shape := [Vector2(-0.1, 0.14), Vector2(0.05, 0.16), Vector2(0.13, 0.03), Vector2(0.09, -0.13),
		Vector2(-0.04, -0.16), Vector2(-0.13, -0.05), Vector2(-0.1, 0.14)]
	for v in shape:
		pts.append(c + Vector3(v.x, v.y, 0.0))
	_stroke(st, pts, INK, 1.5)
	for k in 4:  # dark scratches across the hole
		var y := c.y + 0.09 - k * 0.06
		_stroke(st, _line(Vector3(c.x - 0.08, y, c.z), Vector3(c.x + 0.08, y - 0.05, c.z), 2, 0.004), INK, 1.6)


## The nib-blade's ink: outline, slit and breather hole, along -Y.
func _blade(st: SurfaceTool) -> void:
	var tip := Vector3(0, -1.6, 0)
	var nib := PackedVector3Array([Vector3(-0.06, -0.7, 0), Vector3(-0.1, -0.95, 0), tip, Vector3(0.1, -0.95, 0),
		Vector3(0.06, -0.7, 0), Vector3(-0.06, -0.7, 0)])
	_stroke(st, nib, INK, 1.3)
	_stroke(st, _line(tip, Vector3(0, -0.98, 0), 3, 0.0), INK, 0.7)
	_stroke(st, _circle(Vector3(0, -0.92, 0), 0.025, 8), INK, 0.7)
	_stroke(st, _line(Vector3(-0.1, -0.68, 0), Vector3(0.1, -0.68, 0), 2, 0.0), INK, 1.2)  # the guard
	_stroke(st, _line(Vector3(0, -0.66, 0), Vector3(0, -0.3, 0), 3, 0.004), INK, 1.0)  # the grip


func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.06, -0.7, 0), Vector3(-0.1, -0.95, 0), Vector3(0, -1.6, 0), Vector3(0.1, -0.95, 0), Vector3(0.06, -0.7, 0)]
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(p)
	return st.commit()


## Adds one stroke along `pts` (a ribbon the stroke shader turns to face the
## camera). COLOR: ink or pencil, alpha = width scale.
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


func _dashed(st: SurfaceTool, a: Vector3, b: Vector3, dashes: int, col: Color, w: float) -> void:
	for k in dashes:
		var t0 := float(k) / dashes
		var t1 := t0 + 0.55 / dashes
		_stroke(st, _line(a.lerp(b, t0), a.lerp(b, t1), 1, 0.0), col, w)


func _line(a: Vector3, b: Vector3, n := 4, wob := 0.01) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var j := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * wob
		pts.append(a.lerp(b, float(i) / n) + (j if i > 0 and i < n else Vector3.ZERO))
	return pts


func _circle(c: Vector3, r: float, n: int, normal := Vector3.BACK) -> PackedVector3Array:
	var basis := Basis.looking_at(-normal, Vector3.UP) if absf(normal.dot(Vector3.UP)) < 0.99 else Basis()
	var pts := PackedVector3Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + basis * Vector3(cos(a) * r, sin(a) * r, 0.0))
	return pts


func _ring_pts(pr: Vector2, a0: float, a1: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(Vector3(sin(a) * pr.x, pr.y, cos(a) * pr.x))
	return pts


func _build_eyes() -> void:
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_eye_mat.albedo_color = EYE
	_eye_mat.render_priority = 2
	var eye := SphereMesh.new()
	eye.radius = 0.03
	eye.height = 0.06
	# a soft glow round each: what you see of it in the dark
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.16, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	tex.gradient = g
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.albedo_texture = tex
	_glow_mat.render_priority = 3
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	for side in [-1, 1]:
		var at := Vector3(side * 0.062, 0.05, -0.17)
		var e := MeshInstance3D.new()
		e.mesh = eye
		e.material_override = _eye_mat
		e.position = at
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(e)
		var glow := MeshInstance3D.new()
		glow.mesh = quad
		glow.material_override = _glow_mat
		glow.position = at + Vector3(0, 0, -0.02)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(glow)
		_glows.append(glow)


## A few motes of ink and pencil dust drifting off it: what you catch of it
## out of the light.
func _build_motes() -> void:
	_motes = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	_motes.mesh = q
	_motes.amount = 14
	_motes.lifetime = 1.8
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 0.5
	_motes.position = Vector3(0, 0.9, 0)
	_motes.direction = Vector3(0, 1, 0)
	_motes.spread = 60.0
	_motes.gravity = Vector3(0, 0.3, 0)
	_motes.initial_velocity_min = 0.1
	_motes.initial_velocity_max = 0.45
	_motes.scale_amount_min = 0.7
	_motes.scale_amount_max = 1.6
	# flecks of ink and pale pencil dust, each fading in and out
	var tint := Gradient.new()
	tint.offsets = PackedFloat32Array([0.0, 0.35, 0.36, 1.0])
	tint.colors = PackedColorArray([Color(0.08, 0.07, 0.12), Color(0.08, 0.07, 0.12), Color(0.8, 0.95, 0.95), EYE])
	_motes.color_initial_ramp = tint
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.2, 0.7, 1])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	_motes.color_ramp = g
	_body.add_child(_motes)


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
	_body.position.y = hover + sin(_time * 2.1) * 0.06
	var lean := 0.12 * clampf(speed, 0.0, 1.0)
	var arm_x := 0.35 + 0.08 * sin(_time * 1.7)
	var arm_z := -0.25
	var eye := 1.0
	if windup >= 0.0:
		# the blade snaps up high behind its head, eyes flaring: the tell
		var t := clampf(windup, 0.0, 1.0)
		lean -= 0.18 * t
		arm_x = lerpf(arm_x, -2.6, smoothstep(0.0, 0.6, t))
		arm_z = lerpf(arm_z, -0.4, t)
		eye = 1.0 + 1.5 * t
	elif strike >= 0.0:
		var t := clampf(strike, 0.0, 1.0)
		lean += 0.25 * (1.0 - t)
		arm_x = lerpf(-2.6, 1.1, 1.0 - pow(1.0 - t, 3.0))
		arm_z = -0.4
		eye = 2.5
	_body.rotation.x = lerp_angle(_body.rotation.x, -lean, 1.0 - exp(-10.0 * delta))
	_arm.rotation.x = arm_x
	_arm.rotation.z = arm_z
	_stub.rotation.z = 0.9 + 0.1 * sin(_time * 1.3 + 1.0)
	_stub.rotation.x = 0.2 * sin(_time * 1.1)
	_head.rotation.z = 0.08 * sin(_time * 0.9)
	var fade := 0.0 if dead else 1.0
	_stroke_mat.set_shader_parameter("reveal", _shown)
	_stroke_mat.set_shader_parameter("flash", _flash)
	_stroke_mat.set_shader_parameter("fade", fade)
	for m in _fill_mats:
		m.set_shader_parameter("reveal", _shown)
		m.set_shader_parameter("flash", _flash)
		m.set_shader_parameter("fade", fade)
	# out of the light its eyes are the one clear hint; they flare on a windup
	# (hidden while it looks away from the camera)
	var cam := get_viewport().get_camera_3d()
	var front := 1.0
	if cam:
		var to_cam := cam.global_position - _head.global_position
		to_cam.y = 0.0
		front = smoothstep(-0.35, 0.1, (-_head.global_basis.z).normalized().dot(to_cam.normalized()))
	var flare := clampf(eye - 1.0, 0.0, 1.0)
	var col := EYE.lerp(EYE_FLARE, flare)
	_eye_mat.albedo_color = Color(col, fade * maxf(front, flare))
	_glow_mat.albedo_color = Color(col, fade * maxf(front, flare) * lerpf(0.7, 0.45, _shown))
	for gl in _glows:
		gl.scale = Vector3.ONE * (1.0 + 0.9 * flare + 0.08 * sin(_time * 5.0))
	_motes.emitting = not dead
