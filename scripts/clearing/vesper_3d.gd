extends Node3D
## Vesper as a 2.5D character, "the Traveler's Ghost": a procedural model of
## primitive meshes with the clearing's cel shading and ink outline
## (toon.gd). A tall white egg of a head with two black dash eyes under a
## wide black hat with a red band; a chunky red scarf with a trailing tail;
## a muted purple cloak, open at the front over a cream tunic, its hem
## dipping to points at the sides; grey legs in brown boots; a gold-hilted
## broadsword strapped diagonally across his back.
##
## The origin is at the feet and the model faces local -Z. clearing_player.gd
## feeds the state vars below every frame (like player_visual.gd in 2D) and
## this script poses it: smooth turning towards `facing_dir`, idle bob, run
## stride and cloak flare, jump squash and stretch, a dash lunge that
## streams the cloak and scarf back and leaves ghost afterimages, a swing
## for each combo hit (an arm comes out of the cloak with the sword; the
## finisher is an overhead strike; the sword goes back on his back a moment
## after the last swing), hurt flinch, heal glow, the erase whitening, the
## invulnerability blink and a death collapse. The scarf's tail is a chain
## of segments with simple follow physics.

const Toon = preload("res://scripts/clearing/toon.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const INK := Color(0.05, 0.03, 0.1)
const STEEL := Color(0.84, 0.86, 0.9)
const GOLD := Color(0.86, 0.64, 0.2)
const LEATHER := Color(0.45, 0.28, 0.16)
const EMBER := Color(1.0, 0.62, 0.3)
const GHOST := Color(0.66, 0.6, 1.0)

## Turning speed towards `facing_dir` (higher = snappier).
@export var turn_speed := 16.0
## Run-cycle radians per unit travelled.
@export var stride := 2.6
@export var scarf_segments := 5
@export var scarf_segment_length := 0.12
## 0..1: how much the scarf trails behind when moving (vs. hanging down).
@export var scarf_drag := 0.6
## Seconds the sword stays in hand after the last swing.
@export var sheathe_after := 1.1
## Seconds between ghost afterimages while dashing, and how long each lasts.
@export var afterimage_every := 0.03
@export var afterimage_life := 0.3

@export_group("Colours")
@export var tunic_color := Color(0.86, 0.81, 0.7)
@export var cloak_color := Color(0.44, 0.4, 0.53)
@export var cloak_rim := Color(0.3, 0.27, 0.36)
## The head (the old "mask" colour, so gear that tints it still works).
@export var mask_color := Color(0.95, 0.95, 0.93)
@export var scarf_color := Color(0.85, 0.22, 0.16)
@export var hat_color := Color(0.1, 0.09, 0.11)
@export var leg_color := Color(0.56, 0.53, 0.5)
@export var boot_color := Color(0.24, 0.14, 0.13)
@export var grip_color := Color(0.12, 0.08, 0.08)
## Length of the broadsword's blade, in world units.
@export var blade_length := 0.72
## Overall size (1 = about 1.5 units tall, hat included).
@export var model_scale := 1.3

# Driven by clearing_player.gd every frame.
var facing_dir := Vector3(0, 0, 1)
var speed := 0.0  # planar speed / max speed (0..1+)
var on_floor := true
var vertical := 0.0  # vertical velocity
var dashing := false
var squash := Vector2.ONE
## Swing progress 0..1 (-1 = not swinging) and which combo hit (1..3).
var swing := -1.0
var combo := 1
var hurt := 0.0  # 1 just hit, eases to 0
var heal := 0.0  # 0..1 heal channel
var inking := false  # holding the Ember up to ink a drawn bridge
var erase := 0.0  # 0..1 Writer's light erasing him
var blink := false
var dead := false
var fuel := 1.0  # 0..1 Ember fuel
var show_sword := true

var _yaw := 0.0
var _phase := 0.0
var _time := 0.0
var _run := 0.0
var _dash := 0.0  # 0..1 eased dash pose
var _was_dashing := false
var _ghost_t := 0.0
var _swing_w := 0.0
var _last_swing := -1.0
var _swing_combo := 1
var _drawn_t := 0.0  # > 0 while the sword is in hand
var _death := 0.0
var _blink_t := 2.0
var _eyes_open := 1.0
var _mats: Array[ShaderMaterial] = []
var _mat_glow: Array[float] = []  # each material's own emission
var _shown := {"whiten": -1.0, "tint": -1.0, "emission": -1.0}

var _body: Node3D
var _torso: Node3D
var _cloak: Node3D
var _head: Node3D
var _hat: Node3D
var _eyes: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _arm_r: Node3D
var _sword: Node3D
var _back_sword: Node3D
var _ember: MeshInstance3D
var _ink_w := 0.0  # eases towards `inking`
var _scarf: Array[MeshInstance3D] = []
var _scarf_pts: Array[Vector3] = []
var _scarf_prev: Array[Vector3] = []
var _ghost_meshes: Array = []  # [mesh, transform] of the afterimage silhouette


func _ready() -> void:
	_build()


## Rebuilds with gear colours (clearing_player.gd _apply_look()).
func apply_look(look: Dictionary) -> void:
	if look.has("scarf"):
		scarf_color = look.scarf
	if look.has("mask"):
		mask_color = look.mask
	if look.has("cloak"):
		cloak_color = look.cloak
	if look.has("cloak_rim"):
		cloak_rim = look.cloak_rim
	if look.has("grip"):
		grip_color = look.grip
	if look.has("blade_length"):
		# the 2D sword's length is in pixels (36 = standard)
		blade_length = 0.72 * float(look.blade_length) / 36.0
	if is_inside_tree():
		_build()


## Jumps the scarf to its rest pose (spawn, respawn, teleports).
func snap() -> void:
	_scarf_pts.clear()
	_scarf_prev.clear()


# ------------------------------------------------------------------ build

func _mat(color: Color, opts := {}) -> ShaderMaterial:
	var m: ShaderMaterial = Toon.material(color, opts).duplicate()
	_mats.append(m)
	_mat_glow.append(opts.get("emission", 0.0))
	return m


func _part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
	if not opts.has("from_center"):
		opts = opts.duplicate()
		opts["from_center"] = 1.0 if mesh is BoxMesh or mesh is PrismMesh else 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, opts)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_mats.clear()
	_mat_glow.clear()
	_eyes.clear()
	_legs.clear()
	_scarf.clear()
	_shown = {"whiten": -1.0, "tint": -1.0, "emission": -1.0}
	_body = _pivot(self, Vector3.ZERO)
	# legs: grey stockings into tall brown boots, pivoting at the hips
	for side in [-1, 1]:
		var leg := _pivot(_body, Vector3(side * 0.09, 0.38, 0))
		_part(leg, Toon.cylinder(0.038, 0.034, 0.2, 8), leg_color, Vector3(0, -0.1, 0), Vector3.ZERO, {"outline": 0.02})
		_part(leg, Toon.cylinder(0.068, 0.062, 0.21, 10), boot_color, Vector3(0, -0.275, 0), Vector3.ZERO, {"outline": 0.025})
		_part(leg, Toon.box(Vector3(0.12, 0.07, 0.2)), boot_color.darkened(0.15), Vector3(0, -0.345, -0.05), Vector3.ZERO, {"outline": 0.022})
		_legs.append(leg)
	_torso = _pivot(_body, Vector3(0, 0.38, 0))
	# the cream tunic, seen through the cloak's open front
	_part(_torso, Toon.cylinder(0.15, 0.26, 0.54, 14), tunic_color, Vector3(0, 0.25, 0), Vector3.ZERO, {"outline": 0.025})
	# the cloak: an open A-line shell with a pointed hem, lined darker inside
	_cloak = _pivot(_torso, Vector3(0, 0.5, 0.0))
	var shells := _cloak_meshes()
	var outer := MeshInstance3D.new()
	outer.mesh = shells[0]
	outer.material_override = _mat(cloak_color, {"outline": 0.03, "from_center": 0.0})
	_cloak.add_child(outer)
	var inner := MeshInstance3D.new()
	inner.mesh = shells[1]
	inner.material_override = _mat(cloak_rim, {"outline": 0.0})
	_cloak.add_child(inner)
	# a leather strap across the back, holding the sword
	var strap := _part(_torso, Toon.box(Vector3(0.06, 0.62, 0.025)), LEATHER, Vector3(0.0, 0.3, 0.255), Vector3(0.12, 0, 0.62), {"outline": 0.015})
	strap.scale = Vector3.ONE
	_back_sword = _pivot(_torso, Vector3(0.17, 0.5, 0.29))
	_back_sword.rotation = Vector3(-0.12, 0, -0.62)
	_build_sword(_back_sword)
	# the scarf: a chunky roll round the neck, its tail simulated below
	_part(_torso, Toon.cylinder(0.19, 0.21, 0.13, 14), scarf_color, Vector3(0, 0.5, 0), Vector3.ZERO, {"outline": 0.03, "emission": 0.15})
	var roll := _part(_torso, Toon.cylinder(0.215, 0.2, 0.07, 14), scarf_color.darkened(0.12), Vector3(0, 0.44, -0.01), Vector3(0.12, 0, 0), {"outline": 0.025})
	roll.scale = Vector3.ONE
	# the Ember: a small warm glow under the scarf, like a pendant
	_ember = _part(_torso, Toon.sphere(0.05, 8, 5), EMBER, Vector3(0, 0.36, -0.235), Vector3.ZERO, {"outline": 0.0, "emission": 3.0})
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# head: a tall white egg, two black dash eyes, the hat
	_head = _pivot(_torso, Vector3(0, 0.74, 0))
	# (a little glow of its own, so the face reads in the dark)
	var egg := _part(_head, Toon.sphere(0.27, 18, 10), mask_color, Vector3.ZERO, Vector3.ZERO, {"outline": 0.035, "emission": 0.3})
	egg.scale = Vector3(1.0, 1.2, 1.0)
	for side in [-1, 1]:
		var eye := _pivot(_head, Vector3(side * 0.08, 0.02, -0.256))
		var cap := CapsuleMesh.new()
		cap.radius = 0.024
		cap.height = 0.12
		cap.radial_segments = 8
		cap.rings = 2
		var e := _part(eye, cap, INK, Vector3.ZERO, Vector3.ZERO, {"outline": 0.0})
		e.scale = Vector3(1.0, 1.0, 0.6)
		_eyes.append(eye)
	_hat = _pivot(_head, Vector3(0, 0.27, 0.0))
	_hat.rotation = Vector3(0.12, 0, 0.04)
	_part(_hat, Toon.cylinder(0.43, 0.41, 0.035, 28), hat_color, Vector3.ZERO, Vector3.ZERO, {"outline": 0.03})
	_part(_hat, Toon.cylinder(0.24, 0.27, 0.32, 18), hat_color, Vector3(0, 0.17, 0), Vector3.ZERO, {"outline": 0.03})
	_part(_hat, Toon.cylinder(0.275, 0.28, 0.085, 18), scarf_color, Vector3(0, 0.065, 0), Vector3.ZERO, {"outline": 0.015})
	# a crease across the crown
	_part(_hat, Toon.box(Vector3(0.3, 0.02, 0.06)), hat_color.darkened(0.4), Vector3(0, 0.33, 0), Vector3.ZERO, {"outline": 0.0})
	# sword arm: hidden in the cloak until he swings
	_arm_r = _pivot(_torso, Vector3(0.21, 0.44, 0.0))
	_part(_arm_r, Toon.cylinder(0.06, 0.055, 0.3, 8), cloak_color, Vector3(0, -0.15, 0), Vector3.ZERO, {"outline": 0.022})
	_part(_arm_r, Toon.sphere(0.055, 8, 5), mask_color.darkened(0.08), Vector3(0, -0.32, 0), Vector3.ZERO, {"outline": 0.018})
	_sword = _pivot(_arm_r, Vector3(0, -0.32, 0))
	_build_sword(_sword)
	# scarf tail: world-space segments, simulated in _update_scarf()
	for i in scarf_segments:
		var w := lerpf(0.12, 0.09, float(i) / maxf(scarf_segments - 1, 1))
		var seg := _part(self, Toon.box(Vector3(w, scarf_segment_length * 1.15, 0.035)), scarf_color.darkened(0.06 * (i % 2)),
			Vector3.ZERO, Vector3.ZERO, {"outline": 0.018})
		seg.top_level = true
		_scarf.append(seg)
	_build_ghost_meshes()
	snap()


## The cloak as two shells (outside, and the darker lining inside): a cone
## from the shoulders flaring out, open at the front (the gap widens
## towards the hem), the hem dipping into points at the sides, with soft
## folds. Faces -Z; the top ring sits at the node's origin.
func _cloak_meshes() -> Array:
	var cols := 30
	var rows := 7
	var grid := []
	for i in rows + 1:
		var t := float(i) / rows
		var row := []
		var gap := lerpf(0.16, 0.72, t)
		for j in cols + 1:
			var u := float(j) / cols
			var a := lerpf(gap, TAU - gap, u)  # 0 = straight ahead (-Z)
			var side := pow(absf(sin(a)), 3.0)
			var length := 0.56 + 0.13 * side + 0.03 * maxf(-cos(a), 0.0)
			var r := lerpf(0.18, 0.46, pow(t, 0.85)) * (1.0 + 0.045 * sin(a * 7.0) * t)
			row.append(Vector3(sin(a) * r, -length * t, -cos(a) * r))
		grid.append(row)
	var shells := []
	for inside in [false, true]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in rows:
			for j in cols:
				var a: Vector3 = grid[i][j]
				var b: Vector3 = grid[i][j + 1]
				var c: Vector3 = grid[i + 1][j + 1]
				var d: Vector3 = grid[i + 1][j]
				_quad(st, a, b, c, d, inside)
		shells.append(st.commit())
	return shells


## Adds quad a-b-c-d facing outwards from the cloak's axis (or inwards).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: bool) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		var centre := (p0 + p1 + p2) / 3.0
		var out := Vector3(centre.x, 0.0, centre.z).normalized() + Vector3(0, 0.25, 0)
		if inside:
			out = -out
		if (p2 - p0).cross(p1 - p0).dot(out) < 0.0:
			var tmp := p1
			p1 = p2
			p2 = tmp
		for p in [p0, p1, p2]:
			var n := Vector3(p.x, 0.0, p.z).normalized() + Vector3(0, 0.25, 0)
			st.set_normal((-n if inside else n).normalized())
			st.add_vertex(p)


## A broadsword: black grip, gold pommel and crossguard, a long straight
## steel blade with a fuller and a point. Held at the origin, blade along -Y.
func _build_sword(root: Node3D) -> void:
	_part(root, Toon.cylinder(0.027, 0.027, 0.2, 8), grip_color, Vector3(0, 0.02, 0), Vector3.ZERO, {"outline": 0.016})
	_part(root, Toon.sphere(0.045, 8, 5), GOLD, Vector3(0, 0.14, 0), Vector3.ZERO, {"outline": 0.016})
	_part(root, Toon.box(Vector3(0.3, 0.045, 0.06)), GOLD, Vector3(0, -0.1, 0), Vector3.ZERO, {"outline": 0.018})
	var top := -0.13
	_part(root, Toon.box(Vector3(0.09, blade_length, 0.022)), STEEL, Vector3(0, top - blade_length * 0.5, 0), Vector3.ZERO,
		{"outline": 0.018, "emission": 0.12})
	_part(root, Toon.box(Vector3(0.018, blade_length * 0.8, 0.026)), STEEL.darkened(0.3), Vector3(0, top - blade_length * 0.45, 0),
		Vector3.ZERO, {"outline": 0.0})
	var tip := _part(root, Toon.prism(Vector3(0.09, 0.12, 0.022)), STEEL, Vector3(0, top - blade_length - 0.06, 0), Vector3(0, 0, PI),
		{"outline": 0.018, "emission": 0.12})
	tip.scale = Vector3.ONE


## Simple silhouette meshes (cloak, head, hat) shared by the dash
## afterimages.
func _build_ghost_meshes() -> void:
	_ghost_meshes.clear()
	var cone := Toon.cylinder(0.19, 0.44, 0.62, 12)
	_ghost_meshes.append([cone, Transform3D(Basis(), Vector3(0, 0.57, 0))])
	var head := Toon.sphere(0.27, 12, 6)
	_ghost_meshes.append([head, Transform3D(Basis.from_scale(Vector3(1, 1.2, 1)), Vector3(0, 1.12, 0))])
	_ghost_meshes.append([Toon.cylinder(0.42, 0.42, 0.035, 18), Transform3D(Basis(), Vector3(0, 1.39, 0))])
	_ghost_meshes.append([Toon.cylinder(0.24, 0.27, 0.32, 12), Transform3D(Basis(), Vector3(0, 1.56, 0))])


# ---------------------------------------------------------------- animate

func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_turn(delta)
	_run = move_toward(_run, clampf(speed, 0.0, 1.0) if on_floor and not dashing else 0.0, delta * 8.0)
	_dash = move_toward(_dash, 1.0 if dashing else 0.0, delta * (14.0 if dashing else 5.0))
	if on_floor and not dashing:
		_phase += speed * delta * stride * 5.5
	_update_dash_fx(delta)
	_pose_body(delta)
	_pose_limbs(delta)
	_pose_face(delta)
	_update_scarf(delta)
	_update_materials()


func _turn(delta: float) -> void:
	var f := Vector3(facing_dir.x, 0.0, facing_dir.z)
	if f.length() > 0.01 and not dead:
		var target := atan2(-f.x, -f.z)
		var rate := turn_speed * (2.0 if swing >= 0.0 or dashing else 1.0)
		_yaw = lerp_angle(_yaw, target, 1.0 - exp(-rate * delta))
	transform.basis = Basis(Vector3.UP, _yaw).scaled(Vector3.ONE * model_scale)


## The dash: a puff of dust as he launches, then pale ghosts of his
## silhouette left behind along the path, fading out.
func _update_dash_fx(delta: float) -> void:
	if dashing and not _was_dashing and is_inside_tree():
		Fx.burst(get_tree(), global_position + Vector3(0, 0.15, 0), Color(0.78, 0.74, 0.66), 10, 3.2)
		_ghost_t = 0.0
	_was_dashing = dashing
	if not dashing:
		return
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = afterimage_every
		_spawn_afterimage()


func _spawn_afterimage() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return
	var ghost := Node3D.new()
	ghost.top_level = true
	scene.add_child(ghost)
	ghost.global_transform = _body.global_transform
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(GHOST, 0.55)
	for g in _ghost_meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = g[0]
		mi.transform = g[1]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(mi)
	var t := ghost.create_tween()
	t.set_parallel(true)
	t.tween_property(mat, "albedo_color:a", 0.0, afterimage_life)
	t.tween_property(ghost, "scale", ghost.scale * Vector3(0.9, 0.95, 0.9), afterimage_life)
	t.chain().tween_callback(ghost.queue_free)


func _pose_body(delta: float) -> void:
	_death = move_toward(_death, 1.0 if dead else 0.0, delta * (1.6 if dead else 6.0))
	var bob := -absf(sin(_phase)) * 0.045 * _run + sin(_time * 2.4) * 0.012 * (1.0 - _run)
	var lean := -0.16 * _run
	if not on_floor and not dashing:
		lean = clampf(-vertical * 0.02, -0.15, 0.15) - 0.1 * clampf(speed, 0.0, 1.0)
	lean = lerpf(lean, -0.6, _dash)  # the dash: a hard forward lunge
	lean += 0.45 * hurt  # flinch back
	if _swing_w > 0.0 and _swing_combo == 3:
		lean -= 0.3 * _swing_w * clampf(_swing_t() * 1.5, 0.0, 1.0)  # leans into the overhead strike
	# squash and stretch; the dash stretches him along his facing
	var sq := squash
	var stretch := 1.0 + 0.35 * _dash
	# death: topple backwards, then melt into the ink splat
	var fall := clampf(_death * 1.6, 0.0, 1.0)
	var melt := clampf(_death * 1.6 - 0.6, 0.0, 1.0)
	lean = lerpf(lean, 1.45, fall)
	_body.position = Vector3(0.0, bob - melt * 0.25 - 0.06 * _dash, 0.0)
	_body.rotation = Vector3(lean, 0.0, 0.0)
	_body.scale = Vector3(sq.x * (1.0 - 0.12 * _dash), sq.y * (1.0 - 0.12 * _dash), sq.x * stretch) * (1.0 - melt * 0.95)
	visible = melt < 0.99
	# the cloak flares out behind a run and streams back in a dash
	var flare := -0.22 * _run - sin(_time * 14.0) * 0.04 * _run + clampf(vertical * 0.03, -0.3, 0.2) * (0.0 if on_floor else 1.0)
	_cloak.rotation.x = lerpf(flare, -0.85, _dash)
	var open := 1.0 + 0.12 * _run + 0.18 * _dash
	_cloak.scale = Vector3(open, 1.0 - 0.1 * _dash, open)


func _swing_t() -> float:
	# fast start, gentle settle (an ease-out cubic)
	var t := clampf(_last_swing, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _pose_limbs(delta: float) -> void:
	# legs: stride when running, tuck in the air, a lunge in a dash
	for k in 2:
		var x := sin(_phase + k * PI) * 0.7 * _run
		if not on_floor and not dashing:
			x = -0.55 if k == 0 else 0.25
		x = lerpf(x, -0.75 if k == 0 else 0.95, _dash)
		_legs[k].rotation.x = lerp_angle(_legs[k].rotation.x, x, 1.0 - exp(-22.0 * delta))
	# swing tracking: a new swing starts when the progress jumps back
	if swing >= 0.0:
		_swing_combo = combo
		_last_swing = swing
		_swing_w = 1.0
		_drawn_t = sheathe_after
	else:
		_swing_w = move_toward(_swing_w, 0.0, delta * 5.0)
		if _swing_w <= 0.0:
			_last_swing = -1.0
		_drawn_t = maxf(_drawn_t - delta, 0.0)
	# the sword is in hand while swinging and a moment after; otherwise on his back
	var drawn := _drawn_t > 0.0 and show_sword
	_arm_r.visible = drawn
	_back_sword.visible = show_sword and not drawn
	var rest_arm := Vector3(0.45 - 0.6 * _run, 0.0, 0.3)
	var rest_sword := Vector3(0.9 + 0.3 * _run, 0.0, 0.0)
	var arm := rest_arm
	var sword := rest_sword
	var twist := 0.0
	if _swing_w > 0.0:
		var t := _swing_t()
		var sa := Vector3.ZERO
		var ss := Vector3(0.15, 0.0, 0.0)
		match _swing_combo:
			# hits 1 and 2 sweep the same way as the ink slash (clearing_fx.gd):
			# 1 from his left across to his right, 2 back again
			1:
				sa = Vector3(1.45, lerpf(1.25, -1.5, t), 0.0)
				twist = lerpf(0.45, -0.5, t)
			2:
				sa = Vector3(1.2, lerpf(-1.5, 1.25, t), 0.0)
				twist = lerpf(-0.45, 0.5, t)
			_:
				sa = Vector3(lerpf(3.4, 0.55, t), -0.15, 0.0)
				ss = Vector3(lerpf(0.0, 0.35, t), 0.0, 0.0)
		arm = rest_arm.lerp(sa, _swing_w)
		sword = rest_sword.lerp(ss, _swing_w)
		twist *= _swing_w
	_arm_r.rotation = arm
	_sword.rotation = sword
	_torso.rotation.y = twist
	var e := 0.55 + 0.45 * fuel
	_ink_w = move_toward(_ink_w, 1.0 if inking else 0.0, delta * 6.0)
	_ember.scale = Vector3.ONE * e * (1.0 + 0.12 * sin(_time * 9.0) + heal * 0.8 + _ink_w * (1.4 + 0.3 * sin(_time * 14.0)))


func _pose_face(delta: float) -> void:
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 4.5)
		_eyes_open = 0.1
	_eyes_open = move_toward(_eyes_open, 1.0, delta * 7.0)
	var squint := 0.4 if hurt > 0.3 or dead else 1.0
	for eye in _eyes:
		eye.scale = Vector3(1.0, _eyes_open * squint, 1.0)
	_head.rotation = Vector3(-0.15 * hurt + 0.05 * _run, 0.0, 0.0)
	# the hat lifts a little on a jump and is pressed back in a dash
	var lift := clampf(vertical * 0.004, -0.02, 0.03) if not on_floor else 0.0
	# (tipped back a little, so the face shows from the high camera)
	_hat.position = Vector3(0.0, 0.27 + lift, 0.02 + 0.03 * _dash)
	_hat.rotation = Vector3(0.12 + 0.3 * _dash - 0.06 * _run, 0.0, 0.04 + sin(_phase) * 0.03 * _run)


## Each point trails the one before it at a fixed length (Verlet), with
## gravity, a little flutter, and drag that streams it out behind a run.
## The tail starts at the front left of the scarf, hanging over the cloak.
func _update_scarf(delta: float) -> void:
	if _scarf.is_empty():
		return
	var anchor := _torso.global_transform * Vector3(-0.1, 0.46, -0.17)
	var back := global_transform.basis.z.normalized()
	var side := global_transform.basis.x.normalized()
	var seg_len := scarf_segment_length * model_scale
	var n := _scarf.size()
	if _scarf_pts.size() != n + 1:
		_scarf_pts.clear()
		_scarf_prev.clear()
		for i in n + 1:
			var p := anchor - back * seg_len * i * 0.3 + Vector3(0, -seg_len * i * 0.9, 0)
			_scarf_pts.append(p)
			_scarf_prev.append(p)
	var dt := minf(delta, 1.0 / 30.0)
	var drag := scarf_drag * clampf(speed + (1.5 if dashing else 0.0), 0.0, 2.0)
	_scarf_pts[0] = anchor
	var floor_y := global_position.y + 0.04
	for i in range(1, n + 1):
		var p := _scarf_pts[i]
		var v := (p - _scarf_prev[i]) * 0.9
		_scarf_prev[i] = p
		var flutter := sin(_time * 11.0 - i * 0.9) * (0.3 + drag) * 0.8
		# at rest it hangs forward over the cloak; moving, it streams behind
		var accel := Vector3(0, -6.0 * (1.0 - 0.5 * clampf(drag, 0.0, 1.0)), 0) + back * (drag * 7.0 - 1.6) + side * flutter
		_scarf_pts[i] = p + v + accel * dt * dt
	for _iter in 2:
		for i in range(1, n + 1):
			var d := _scarf_pts[i] - _scarf_pts[i - 1]
			var len := d.length()
			if len > 0.0001:
				_scarf_pts[i] = _scarf_pts[i - 1] + d / len * seg_len
			_scarf_pts[i].y = maxf(_scarf_pts[i].y, floor_y)
	for i in n:
		var a := _scarf_pts[i]
		var b := _scarf_pts[i + 1]
		var dir := b - a
		if dir.length() < 0.0001:
			continue
		dir = dir.normalized()
		var basis := Basis(Quaternion(Vector3.DOWN, dir)) if dir.dot(Vector3.DOWN) > -0.999 else Basis(Vector3.RIGHT, PI)
		var s := (_body.scale.x if not dead else _body.scale.y) * model_scale
		_scarf[i].global_transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * clampf(s, 0.05, 1.5)), (a + b) * 0.5)


func _update_materials() -> void:
	var w := clampf(erase, 0.0, 1.0) * 0.85
	var tint := 0.42 if blink else 1.0
	var glow := heal * (0.35 + 0.25 * sin(_time * 18.0))
	if absf(w - _shown.whiten) > 0.001:
		_shown.whiten = w
		for m in _mats:
			m.set_shader_parameter("whiten", w)
	if absf(tint - _shown.tint) > 0.001:
		_shown.tint = tint
		for m in _mats:
			m.set_shader_parameter("tint", Color(tint, tint, tint * 1.05))
	if absf(glow - _shown.emission) > 0.001:
		_shown.emission = glow
		for i in _mats.size():
			_mats[i].set_shader_parameter("emission_strength", _mat_glow[i] + glow)
