extends "res://scripts/clearing/unfinished_model.gd"
## Quire, the shopkeeper of the Spine (shop_stall.gd), as what he is: a
## character the Writer never finished, and a ghost of one. He is drawn the
## way the Half-Drawn is (unfinished_model.gd, whose strokes, fills and
## helpers this uses): his left half inked in over a pale hatched fill, his
## right half only dashed pencil guides.
##  - one slim shape, the ghost everybody knows: a domed head running down
##    into narrow shoulders and a long body that thins to a wisp and curls
##    away at the bottom (no legs: they were never drawn)
##  - two big eyes on their own pivot (`head`: the stall turns it so they
##    follow Vesper), one drawn and glowing, the other a pencil ring, and a
##    small round mouth
##  - the arm that writes (aim_arm(): the stall points it at his quill each
##    frame) and, on the unfinished side, a stub that stops short
##  - a soft glow round him, motes of ink and pencil dust drifting off him
## `shown` (0..1) is how drawn-in he is: the stall lets him fade, his lines
## coming and going, while he is alone, and inks him in when Vesper comes
## near. Now and then he skips, like a drawing with frames missing.
## Faces +Z. Sizes are in his own units; the stall scales him.

const SKIN := Color(0.8, 0.94, 0.93)
const AURA := Color(0.45, 0.95, 0.9)
## His shape, (radius, height) from the tip of the wisp up over the head.
const BODY := [Vector2(0.015, 0.0), Vector2(0.06, 0.2), Vector2(0.11, 0.45), Vector2(0.15, 0.75), Vector2(0.165, 1.0), Vector2(0.15, 1.14),
	Vector2(0.185, 1.3), Vector2(0.165, 1.44), Vector2(0.1, 1.54), Vector2(0.0, 1.58)]
## Where his eyes are (the middle of his head).
const FACE := 1.33

## 0 = barely there (pieces of his lines flicker in and out) .. 1 = drawn in.
var shown := 1.0
## Turned by the stall to look at Vesper.
var head: Node3D

var _skip := 0.0   # until he next skips a frame or two
var _aura_mat: StandardMaterial3D
var _flats: Array = []  # his fills: [material, colour, how opaque when drawn in]


func _ready() -> void:
	_rng.seed = 907
	_time = randf() * 10.0
	hover = 0.05
	_build()


func _build() -> void:
	var old := get_node_or_null("Generated")
	if old:
		old.free()
	var root := Node3D.new()
	root.name = "Generated"
	add_child(root)
	_stroke_mat = ShaderMaterial.new()
	_stroke_mat.shader = STROKE_SHADER
	_stroke_mat.set_shader_parameter("seed", 41.0)
	_stroke_mat.set_shader_parameter("width", 0.02)
	_stroke_mat.set_shader_parameter("boil", 0.006)
	_stroke_mat.set_shader_parameter("ghost_alpha", 0.16)
	_stroke_mat.render_priority = 1  # lines over the fills
	_body = _pivot(root, Vector3(0, hover, 0))
	_aura()
	# one shape, head to wisp: the left half drawn in, the right half only guessed at
	var left := _curl(_grid(BODY, PI, TAU, 12))
	var right := _curl(_grid(BODY, 0.0, PI, 12))
	_flat(_body, _surface(left), SKIN, 0.88)
	_flat(_body, _surface(right), SKIN, 0.12)
	var st := _strokes()
	_ink_outline(st, left, [6, 12], [])  # his outline, and the line down his middle where the ink stops
	_pencil_guides(st, right, [6], [3, 6])
	_part(_body, st.commit(), _stroke_mat)
	# his face, on a pivot: the eyes follow Vesper round the head
	head = _pivot(_body, Vector3(0, FACE, 0))
	_head = head
	var hs := _strokes()
	_stroke(hs, _circle(Vector3(0.075, 0.03, 0.175), 0.05, 10), PENCIL, 0.9)  # the eye that isn't
	_stroke(hs, _circle(Vector3(0.0, -0.1, 0.18), 0.028, 8), INK, 1.2)  # a small round mouth
	_part(head, hs.commit(), _stroke_mat)
	_build_eye()
	# the arm that writes: drawn a unit long (aim_arm() stretches it to his hand)
	_arm = _pivot(_body, Vector3.ZERO)
	var arm := _strokes()
	for x: float in [-0.028, 0.028]:
		_stroke(arm, _line(Vector3(x, 0, 0), Vector3(x * 0.7, 1, 0), 3, 0.0), INK, 1.1)
	_stroke(arm, _circle(Vector3(0, 1, 0), 0.035, 8), INK, 1.1)
	_part(_arm, arm.commit(), _stroke_mat)
	# the other: a dashed pencil guess, cut off
	_stub = _pivot(_body, Vector3(0.15, 1.02, 0.04))
	var ss := _strokes()
	for x: float in [-0.03, 0.03]:
		_dashed(ss, Vector3(x, 0, 0), Vector3(x * 0.9, -0.26, 0), 4, PENCIL, 0.8)
	_stroke(ss, _circle(Vector3(0, -0.26, 0), 0.03, 8, Vector3.RIGHT), PENCIL, 0.7)
	_part(_stub, ss.commit(), _stroke_mat)
	_build_motes()
	_motes.amount = 10
	_motes.emission_sphere_radius = 0.3
	_motes.position = Vector3(0, 1.0, 0)


## The bottom of him curls away to one side, like smoke.
func _curl(rows: Array) -> Array:
	for j in rows.size():
		var row: PackedVector3Array = rows[j]
		for i in row.size():
			var low := clampf(1.0 - row[i].y / 0.6, 0.0, 1.0)
			row[i] += Vector3(0.16 * low * low, 0, -0.05 * low)
		rows[j] = row
	return rows


## A flat, pale, see-through fill (not the Half-Drawn's hatched one, which
## shades anything seen from above: he is small on screen and it buried him).
func _flat(parent: Node3D, mesh: Mesh, color: Color, alpha: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color, alpha)
	_flats.append([m, color, alpha])
	_part(parent, mesh, m)


## The pale light he gives off: a ghost's, soft, always turned to the camera.
func _aura() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 48
	tex.height = 48
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
	tex.gradient = g
	_aura_mat = StandardMaterial3D.new()
	_aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_aura_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_aura_mat.albedo_texture = tex
	_aura_mat.albedo_color = AURA
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 2.4)
	_part(_body, quad, _aura_mat).position = Vector3(0, 0.85, -0.1)


## His one drawn eye: a bright point and the soft glow round it.
func _build_eye() -> void:
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_eye_mat.albedo_color = EYE
	_eye_mat.render_priority = 2
	var eye := SphereMesh.new()
	eye.radius = 0.045
	eye.height = 0.11
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
	var at := Vector3(-0.075, 0.03, 0.18)
	_part(head, eye, _eye_mat).position = at
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var glow := _part(head, quad, _glow_mat)
	glow.position = at + Vector3(0, 0, 0.02)
	_glows.append(glow)


## Points his writing arm from `shoulder` to `hand` (both in his own space).
func aim_arm(shoulder: Vector3, hand: Vector3) -> void:
	var along := hand - shoulder
	var up := along.normalized()
	var side := up.cross(Vector3.BACK).normalized()
	_arm.transform = Transform3D(Basis(side, along, side.cross(up)), shoulder - Vector3(0, _body.position.y, 0))


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_body.position.y = hover + sin(_time * 1.7) * 0.03
	_stub.rotation.z = 0.5 + 0.12 * sin(_time * 1.3 + 1.0)
	_stub.rotation.x = 0.2 * sin(_time * 1.1)
	# he skips: for a frame or two most of him is not there
	_skip -= delta
	if _skip < -0.12:
		_skip = randf_range(2.5, 7.0)
	_shown = move_toward(_shown, clampf(shown, 0.0, 1.0) * (0.35 if _skip < 0.0 else 1.0), delta * (30.0 if _skip < 0.0 else 3.0))
	_stroke_mat.set_shader_parameter("reveal", _shown)
	for f: Array in _flats:
		f[0].albedo_color = Color(f[1], f[2] * _shown)
	var pulse := 0.85 + 0.15 * sin(_time * 3.0)
	_eye_mat.albedo_color = Color(EYE, pulse)
	_glow_mat.albedo_color = Color(EYE, 0.6 * pulse)
	_aura_mat.albedo_color = Color(AURA, (0.35 + 0.12 * sin(_time * 1.3)) * _shown)
