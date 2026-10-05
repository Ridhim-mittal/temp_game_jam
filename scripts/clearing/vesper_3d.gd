extends Node3D
## Vesper as a 2.5D character: a procedural model of primitive meshes with
## the clearing's cel shading and ink outline (toon.gd), matching the 2D
## design - dark tunic under a long cloak with a torn-page hem, a pale round
## head under spiky ink-black hair, big white eyes, a long red scarf and the
## nib-sword in his right hand.
##
## The origin is at the feet and the model faces local -Z. clearing_player.gd
## feeds the state vars below every frame (like player_visual.gd in 2D) and
## this script poses it: smooth turning towards `facing_dir`, idle bob, run
## lean and stride, jump squash and stretch, dash stretch, a swing for each
## combo hit (the finisher is an overhead strike), hurt flinch, heal glow,
## the erase whitening, the invulnerability blink and a death collapse.
## The scarf is a chain of segments with simple follow physics.

const Toon = preload("res://scripts/clearing/toon.gd")
const INK := Color(0.05, 0.03, 0.1)
const STEEL := Color(0.86, 0.88, 0.95)
const STEEL_DARK := Color(0.48, 0.5, 0.62)
const EMBER := Color(1.0, 0.62, 0.3)

## Turning speed towards `facing_dir` (higher = snappier).
@export var turn_speed := 16.0
## Run-cycle radians per unit travelled.
@export var stride := 2.6
@export var scarf_segments := 6
@export var scarf_segment_length := 0.13
## 0..1: how much the scarf trails behind when moving (vs. hanging down).
@export var scarf_drag := 0.55

@export_group("Colours")
@export var tunic_color := Color(0.1, 0.09, 0.13)
@export var cloak_color := Color(0.14, 0.11, 0.16)
@export var cloak_rim := Color(0.36, 0.3, 0.42)
@export var mask_color := Color(0.98, 0.96, 0.9)
@export var scarf_color := Color(0.92, 0.3, 0.2)
@export var page_color := Color(0.92, 0.89, 0.8)
@export var grip_color := Color(1.0, 0.58, 0.14)
## Length of the nib blade, in world units.
@export var blade_length := 0.62
## Thin cold rim light round his silhouette (toon.gdshader), so the dark
## cloak still reads in the Gutter's dark.
@export var rim_light := 0.45
## Overall size (1 = about 1.5 units tall).
@export var model_scale := 1.15

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
var erase := 0.0  # 0..1 Writer's light erasing him
var blink := false
var dead := false
var fuel := 1.0  # 0..1 Ember fuel
var show_sword := true

var _yaw := 0.0
var _phase := 0.0
var _time := 0.0
var _run := 0.0
var _swing_w := 0.0
var _last_swing := -1.0
var _swing_combo := 1
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
var _eyes: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _arm_r: Node3D
var _arm_l: Node3D
var _sword: Node3D
var _ember: MeshInstance3D
var _scarf: Array[MeshInstance3D] = []
var _scarf_pts: Array[Vector3] = []
var _scarf_prev: Array[Vector3] = []


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
		blade_length = 0.62 * float(look.blade_length) / 36.0
	if is_inside_tree():
		_build()


## Jumps the scarf to its rest pose (spawn, respawn, teleports).
func snap() -> void:
	_scarf_pts.clear()
	_scarf_prev.clear()


# ------------------------------------------------------------------ build

func _mat(color: Color, opts := {}) -> ShaderMaterial:
	var m: ShaderMaterial = Toon.material(color, opts).duplicate()
	m.set_shader_parameter("rim_strength", rim_light)
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
	# legs, pivoting at the hips
	for side in [-1, 1]:
		var leg := _pivot(_body, Vector3(side * 0.1, 0.42, 0))
		_part(leg, Toon.cylinder(0.065, 0.055, 0.34, 8), INK.lightened(0.08), Vector3(0, -0.17, 0), Vector3.ZERO, {"outline": 0.025})
		_part(leg, Toon.box(Vector3(0.14, 0.1, 0.24)), INK, Vector3(0, -0.36, -0.04), Vector3.ZERO, {"outline": 0.025})
		_legs.append(leg)
	# torso: the tunic, with the cloak hanging from the shoulders over it
	_torso = _pivot(_body, Vector3(0, 0.42, 0))
	_part(_torso, Toon.cylinder(0.19, 0.25, 0.46, 12), tunic_color, Vector3(0, 0.22, 0), Vector3.ZERO, {"outline": 0.03})
	_cloak = _pivot(_torso, Vector3(0, 0.44, 0.03))
	var coat := _part(_cloak, Toon.cylinder(0.21, 0.36, 0.62, 14), cloak_color, Vector3(0, -0.31, 0.02), Vector3.ZERO, {"outline": 0.035})
	coat.scale = Vector3(1.0, 1.0, 0.92)
	# torn-page lining showing along the hem, and a pale rim down the front edge
	var hem := _part(_cloak, Toon.cylinder(0.365, 0.385, 0.06, 14), page_color, Vector3(0, -0.6, 0.02), Vector3.ZERO, {"outline": 0.02})
	hem.scale = Vector3(1.0, 1.0, 0.92)
	for side in [-1, 1]:
		_part(_cloak, Toon.box(Vector3(0.035, 0.56, 0.035)), cloak_rim, Vector3(side * 0.09, -0.3, -0.27), Vector3(0.22, 0, side * 0.18), {"outline": 0.0})
	# scarf wrapped round the neck
	_part(_torso, Toon.cylinder(0.2, 0.22, 0.13, 12), scarf_color, Vector3(0, 0.47, 0), Vector3.ZERO, {"outline": 0.03})
	# head: pale round face, ink hair, big white eyes
	_head = _pivot(_torso, Vector3(0, 0.72, 0))
	_part(_head, Toon.sphere(0.3, 16, 8), mask_color, Vector3.ZERO, Vector3.ZERO, {"outline": 0.035})
	var cap := _part(_head, Toon.sphere(0.305, 14, 7), INK, Vector3(0, 0.085, 0.085), Vector3.ZERO, {"outline": 0.03})
	cap.scale = Vector3(1.03, 0.94, 1.0)
	_hair(_head)
	for side in [-1, 1]:
		var eye := _pivot(_head, Vector3(side * 0.115, -0.02, -0.258))
		var white := _part(eye, Toon.sphere(0.1, 12, 6), Color(1, 1, 1), Vector3.ZERO, Vector3.ZERO, {"outline": 0.024, "emission": 0.3})
		white.scale = Vector3(0.78, 1.35, 0.42)
		var pupil := _part(eye, Toon.sphere(0.034, 8, 4), INK, Vector3(side * -0.012, -0.018, -0.036), Vector3.ZERO, {"outline": 0.0})
		pupil.scale = Vector3(1.0, 1.3, 0.4)
		_eyes.append(eye)
	# arms: right holds the nib-sword, left carries the Ember
	_arm_r = _arm(Vector3(0.25, 0.4, 0))
	_arm_l = _arm(Vector3(-0.25, 0.4, 0))
	_sword = _pivot(_arm_r, Vector3(0, -0.33, 0))
	_build_sword(_sword)
	_ember = _part(_arm_l, Toon.sphere(0.06, 8, 5), EMBER, Vector3(0, -0.36, -0.06), Vector3.ZERO, {"outline": 0.0, "emission": 3.0})
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# scarf tail: world-space segments, simulated in _update_scarf()
	for i in scarf_segments:
		var w := lerpf(0.11, 0.07, float(i) / maxf(scarf_segments - 1, 1))
		var seg := _part(self, Toon.box(Vector3(w, scarf_segment_length * 1.15, 0.03)), scarf_color.darkened(0.08 * (i % 2)),
			Vector3.ZERO, Vector3.ZERO, {"outline": 0.018})
		seg.top_level = true
		_scarf.append(seg)
	snap()


## Spiky hair: ink cones fanned over the top and back of the head, with a
## few forward over the brow.
func _hair(head: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spikes := []
	for i in 9:
		var az := lerpf(-2.5, 2.5, i / 8.0) + rng.randf_range(-0.15, 0.15)  # 0 = straight back (+Z)
		spikes.append([az, rng.randf_range(0.2, 0.75), rng.randf_range(0.2, 0.3)])
	for k in 3:
		spikes.append([PI + (k - 1) * 0.45, 0.95, 0.17])  # fringe over the brow
	spikes.append([0.0, 1.35, 0.26])  # crown
	for s in spikes:
		var az: float = s[0]
		var el: float = s[1]
		var d := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)).normalized()
		var mi := _part(head, Toon.cylinder(0.0, 0.085, s[2], 6), INK, Vector3(0, 0.05, 0.05) + d * (0.24 + s[2] * 0.5), Vector3.ZERO, {"outline": 0.022})
		mi.basis = Basis(Quaternion(Vector3.UP, d))


func _arm(shoulder: Vector3) -> Node3D:
	var arm := _pivot(_torso, shoulder)
	_part(arm, Toon.cylinder(0.055, 0.05, 0.3, 8), cloak_color, Vector3(0, -0.15, 0), Vector3.ZERO, {"outline": 0.025})
	_part(arm, Toon.sphere(0.065, 8, 5), mask_color.darkened(0.08), Vector3(0, -0.32, 0), Vector3.ZERO, {"outline": 0.02})
	return arm


## A steel blade shaped like a fountain-pen nib (slit, breather hole,
## ink-dipped tip) on a grip wrapped in scarf cloth. Points along local -Y.
func _build_sword(root: Node3D) -> void:
	_part(root, Toon.cylinder(0.032, 0.032, 0.16, 8), grip_color, Vector3(0, 0.03, 0), Vector3.ZERO, {"outline": 0.018})
	_part(root, Toon.box(Vector3(0.2, 0.045, 0.07)), STEEL_DARK, Vector3(0, -0.06, 0), Vector3.ZERO, {"outline": 0.02})
	var nib := _part(root, Toon.cylinder(0.0, 0.085, blade_length, 4), STEEL, Vector3(0, -0.08 - blade_length * 0.5, 0),
		Vector3(PI, 0, 0), {"outline": 0.022, "emission": 0.15})
	nib.scale = Vector3(1.0, 1.0, 0.4)
	_part(root, Toon.box(Vector3(0.012, blade_length * 0.5, 0.05)), INK, Vector3(0, -0.08 - blade_length * 0.62, 0), Vector3.ZERO, {"outline": 0.0})
	_part(root, Toon.sphere(0.022, 6, 4), INK, Vector3(0, -0.08 - blade_length * 0.34, 0), Vector3.ZERO, {"outline": 0.0})
	var tip := _part(root, Toon.cylinder(0.0, 0.028, blade_length * 0.16, 4), INK, Vector3(0, -0.08 - blade_length * 0.93, 0),
		Vector3(PI, 0, 0), {"outline": 0.0})
	tip.scale = Vector3(1.0, 1.0, 0.4)


# ---------------------------------------------------------------- animate

func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_turn(delta)
	_run = move_toward(_run, clampf(speed, 0.0, 1.0) if on_floor and not dashing else 0.0, delta * 8.0)
	if on_floor and not dashing:
		_phase += speed * delta * stride * 5.5
	_pose_body(delta)
	_pose_limbs(delta)
	_pose_face(delta)
	_update_scarf(delta)
	_update_materials()


func _turn(delta: float) -> void:
	var f := Vector3(facing_dir.x, 0.0, facing_dir.z)
	if f.length() > 0.01 and not dead:
		var target := atan2(-f.x, -f.z)
		var rate := turn_speed * (2.0 if swing >= 0.0 else 1.0)
		_yaw = lerp_angle(_yaw, target, 1.0 - exp(-rate * delta))
	transform.basis = Basis(Vector3.UP, _yaw).scaled(Vector3.ONE * model_scale)


func _pose_body(delta: float) -> void:
	_death = move_toward(_death, 1.0 if dead else 0.0, delta * (1.6 if dead else 6.0))
	var bob := -absf(sin(_phase)) * 0.05 * _run + sin(_time * 2.4) * 0.012 * (1.0 - _run)
	var lean := -0.2 * _run
	if dashing:
		lean = -0.5
	elif not on_floor:
		lean = clampf(-vertical * 0.02, -0.15, 0.15) - 0.1 * clampf(speed, 0.0, 1.0)
	lean += 0.45 * hurt  # flinch back
	if _swing_w > 0.0 and _swing_combo == 3:
		lean -= 0.3 * _swing_w * clampf(_swing_t() * 1.5, 0.0, 1.0)  # leans into the overhead strike
	var sq := squash
	if dashing:
		sq = Vector2(sq.x * 0.9, sq.y * 0.92)
	# death: topple backwards, then melt into the ink splat
	var fall := clampf(_death * 1.6, 0.0, 1.0)
	var melt := clampf(_death * 1.6 - 0.6, 0.0, 1.0)
	lean = lerpf(lean, 1.45, fall)
	_body.position = Vector3(0.0, bob - melt * 0.25, 0.0)
	_body.rotation = Vector3(lean, 0.0, 0.0)
	_body.scale = Vector3(sq.x, sq.y, sq.x * (1.25 if dashing else 1.0)) * (1.0 - melt * 0.95)
	visible = melt < 0.99
	_cloak.rotation.x = -0.25 * _run - (0.45 if dashing else 0.0) + clampf(vertical * 0.03, -0.3, 0.2) * (0.0 if on_floor else 1.0) \
		- sin(_time * 14.0) * 0.04 * _run


func _swing_t() -> float:
	# fast start, gentle settle (an ease-out cubic)
	var t := clampf(_last_swing, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _pose_limbs(delta: float) -> void:
	# legs: stride when running, tuck in the air, kick back in a dash
	for k in 2:
		var x := sin(_phase + k * PI) * 0.75 * _run
		if dashing:
			x = 0.6 + k * 0.25
		elif not on_floor:
			x = -0.6 if k == 0 else 0.25
		_legs[k].rotation.x = lerp_angle(_legs[k].rotation.x, x, 1.0 - exp(-20.0 * delta))
	# swing tracking: a new swing starts when the progress jumps back
	if swing >= 0.0:
		_swing_combo = combo
		_last_swing = swing
		_swing_w = 1.0
	else:
		_swing_w = move_toward(_swing_w, 0.0, delta * 5.0)
		if _swing_w <= 0.0:
			_last_swing = -1.0
	# right arm + sword: rest / run pose blended with the swing pose
	var rest_arm := Vector3(0.35 - 0.85 * _run, 0.0, 0.25)
	var rest_sword := Vector3(0.75 + 0.4 * _run, 0.0, 0.0)
	if heal > 0.0:
		rest_arm = rest_arm.lerp(Vector3(0.9, -0.5, 0.2), heal)
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
	_sword.visible = show_sword
	_torso.rotation.y = twist
	# left arm swings against the stride and holds the Ember out a little
	var l := Vector3(0.25 - sin(_phase) * 0.7 * _run, 0.0, -0.22)
	if dashing:
		l = Vector3(-0.9, 0.0, -0.3)
	if heal > 0.0:
		l = l.lerp(Vector3(1.0, 0.5, -0.2), heal)
	_arm_l.rotation = l
	var e := 0.55 + 0.45 * fuel
	_ember.scale = Vector3.ONE * e * (1.0 + 0.12 * sin(_time * 9.0) + heal * 0.6)


func _pose_face(delta: float) -> void:
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 4.5)
		_eyes_open = 0.1
	_eyes_open = move_toward(_eyes_open, 1.0, delta * 7.0)
	var squint := 0.55 if hurt > 0.3 or dead else 1.0
	for eye in _eyes:
		eye.scale = Vector3(1.0, _eyes_open * squint, 1.0)
	_head.rotation = Vector3(-0.15 * hurt + 0.06 * _run, 0.0, 0.0)


## Each point trails the one before it at a fixed length (Verlet), with
## gravity, a little flutter, and drag that streams it out behind a run.
func _update_scarf(delta: float) -> void:
	if _scarf.is_empty():
		return
	var anchor := _torso.global_transform * Vector3(0, 0.44, 0.19)
	var back := global_transform.basis.z.normalized()
	var side := global_transform.basis.x.normalized()
	var seg_len := scarf_segment_length * model_scale
	var n := _scarf.size()
	if _scarf_pts.size() != n + 1:
		_scarf_pts.clear()
		_scarf_prev.clear()
		for i in n + 1:
			var p := anchor + back * seg_len * i * 0.6 + Vector3(0, -seg_len * i * 0.8, 0)
			_scarf_pts.append(p)
			_scarf_prev.append(p)
	var dt := minf(delta, 1.0 / 30.0)
	var drag := scarf_drag * clampf(speed + (1.0 if dashing else 0.0), 0.0, 1.5)
	_scarf_pts[0] = anchor
	var floor_y := global_position.y + 0.04
	for i in range(1, n + 1):
		var p := _scarf_pts[i]
		var v := (p - _scarf_prev[i]) * 0.9
		_scarf_prev[i] = p
		var flutter := sin(_time * 11.0 - i * 0.9) * (0.4 + drag) * 0.8
		var accel := Vector3(0, -6.0 * (1.0 - 0.6 * drag), 0) + back * (2.0 + drag * 6.0) \
			+ side * flutter
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
