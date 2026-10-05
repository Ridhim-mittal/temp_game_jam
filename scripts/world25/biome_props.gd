@tool
extends Node3D
## Props for the 2.5D biomes, picked with `kind`. Each builds from simple
## cel-shaded shapes (toon.gd) like the clearing's props, so they share its
## inked look. `size` scales the prop, `seed` varies it, `color` tints it
## (Color(0, 0, 0, 0) = the prop's own colours), `count`/`radius` are used by
## clusters. Set `solid` to block the player.
##
## Darkwood:  TOMBSTONE, STUMP
## Shrine:    PILLAR (broken), RITUAL_CIRCLE (red correction marks),
##            SHADE_STATUE
## Shallows:  INK_POOL
## Wastes:    CRYSTAL, PAPER_MOUND, PINS, PENCIL_TOTEM, INK_POT
##
## Retired (no longer placed anywhere, kept so the enum's integers stay put;
## never remove or reorder Kind values, scenes store them as numbers):
## CANOPY, GARDEN_PLOT, BARN, SCARECROW, CORAL, TUBE_PLANT, NEST.

const Toon = preload("res://scripts/clearing/toon.gd")
const EYES_SHADER = preload("res://shaders/clearing/glow_eyes.gdshader")
const CIRCLE_SHADER = preload("res://shaders/world25/ritual_circle.gdshader")
const SPLAT_SHADER = preload("res://shaders/clearing/ink_splat.gdshader")

enum Kind {
	CANOPY, TOMBSTONE, STUMP, GARDEN_PLOT, BARN, SCARECROW,
	PILLAR, RITUAL_CIRCLE, SHADE_STATUE,
	CORAL, TUBE_PLANT, INK_POOL,
	CRYSTAL, PAPER_MOUND, PINS, NEST, PENCIL_TOTEM, INK_POT,
}

@export var kind := Kind.TOMBSTONE:
	set(v):
		kind = v
		_rebuild()
@export var size := 1.0:
	set(v):
		size = v
		_rebuild()
@export var color := Color(0, 0, 0, 0):
	set(v):
		color = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
@export var count := 5:
	set(v):
		count = v
		_rebuild()
@export var radius := 1.2:
	set(v):
		radius = v
		_rebuild()
@export var solid := false:
	set(v):
		solid = v
		_rebuild()

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rebuild()


func _col(default: Color) -> Color:
	return default if color.a == 0.0 else color


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	_rng.seed = seed
	var s := size
	match kind:
		Kind.CANOPY: _canopy(root, s)
		Kind.TOMBSTONE: _tombstone(root, s)
		Kind.STUMP: _stump(root, s)
		Kind.GARDEN_PLOT: _garden_plot(root, s)
		Kind.BARN: _barn(root, s)
		Kind.SCARECROW: _scarecrow(root, s)
		Kind.PILLAR: _pillar(root, s)
		Kind.RITUAL_CIRCLE: _ritual_circle(root, s)
		Kind.SHADE_STATUE: _shade_statue(root, s)
		Kind.CORAL: _coral(root, s)
		Kind.TUBE_PLANT: _tube_plant(root, s)
		Kind.INK_POOL: _ink_pool(root, s)
		Kind.CRYSTAL: _crystal(root, s)
		Kind.PAPER_MOUND: _paper_mound(root, s)
		Kind.PINS: _pins(root, s)
		Kind.NEST: _nest(root, s)
		Kind.PENCIL_TOTEM: _pencil_totem(root, s)
		Kind.INK_POT: _ink_pot(root, s)


func _collide(root: Node3D, shape: Shape3D, pos: Vector3) -> void:
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, shape, pos)


func _rand_in_disc(r: float) -> Vector3:
	var a := _rng.randf() * TAU
	return Vector3(cos(a), 0, sin(a)) * r * sqrt(_rng.randf())


# ---------------------------------------------------------------- darkwood

## Retired. Foliage hanging from a canopy above: leafy lumps with dangling
## vines and dark hollows where red eyes watch.
## Place it at the room edge; it floats at height `size * 5`.
func _canopy(root: Node3D, s: float) -> void:
	var leaf := _col(Color(0.36, 0.52, 0.3))
	var top := s * 5.0
	# a dark trunk rising out of the void below holds the crown up
	var trunk_h := top + 9.0
	Toon.part(root, Toon.cylinder(0.45 * s, 0.7 * s, trunk_h, 10), Color(0.2, 0.14, 0.16), Vector3(0, top - trunk_h * 0.5 - 0.3, -0.4 * s),
		Vector3.ZERO, {"bark": 1.0, "line": Color(0.1, 0.07, 0.09), "outline": 0.06})
	for i in 5:
		var p := Vector3(_rng.randf_range(-1.6, 1.6), top + _rng.randf_range(-0.5, 0.8), _rng.randf_range(-0.6, 0.6)) * Vector3(s, 1, s)
		var r := s * _rng.randf_range(0.9, 1.4)
		var blob := Toon.part(root, Toon.sphere(r, 10, 6), leaf.darkened(_rng.randf() * 0.25), p, Vector3(0, _rng.randf() * 360.0, 0),
			{"outline": 0.07, "moss": 0.35, "moss_color": leaf.lightened(0.25)})
		blob.scale = Vector3(1.0, 0.8, 1.0)
	# dangling vines
	for i in 7:
		var x := _rng.randf_range(-2.2, 2.2) * s
		var h := _rng.randf_range(1.2, 2.6) * s
		Toon.part(root, Toon.cylinder(0.04 * s, 0.05 * s, h, 5), leaf.darkened(0.45),
			Vector3(x, top - s * 0.8 - h * 0.5, _rng.randf_range(0.2, 0.8) * s), Vector3.ZERO, {"outline": 0.025})
	# a dark hollow with eyes, facing the camera (+Z)
	for k in 2:
		var hp := Vector3((k - 0.5) * 1.8 * s, top - s * 0.1, s * 1.0)
		var hollow := Toon.part(root, Toon.box(Vector3(0.9 * s, 0.9 * s, 0.12)), Color(0.04, 0.03, 0.05), hp, Vector3(0, 0, 45),
			{"outline": 0.05})
		hollow.scale = Vector3(1.0, 1.25, 1.0)
		Toon.billboard(root, EYES_SHADER, Vector2(0.9, 0.45) * s, hp + Vector3(0, 0, 0.12), {"color": Color(1.0, 0.15, 0.1)})


func _tombstone(root: Node3D, s: float) -> void:
	var st := _col(Color(0.55, 0.54, 0.56))
	var tilt := Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-20, 20), _rng.randf_range(-8, 8))
	var holder := Node3D.new()
	holder.rotation_degrees = tilt
	root.add_child(holder)
	Toon.part(holder, Toon.box(Vector3(0.8, 1.0, 0.25) * s), st, Vector3(0, 0.5 * s, 0), Vector3.ZERO, {"moss": 0.4})
	var cap := Toon.part(holder, Toon.cylinder(0.4 * s, 0.4 * s, 0.25 * s, 14), st, Vector3(0, 1.0 * s, 0), Vector3(90, 0, 0), {"moss": 0.4})
	cap.scale = Vector3(1, 1, 1)
	# a red X: this one was crossed out
	for a in [35.0, -35.0]:
		Toon.part(holder, Toon.box(Vector3(0.08, 0.7, 0.03) * s), Color(0.8, 0.12, 0.1), Vector3(0, 0.62 * s, 0.14 * s),
			Vector3(0, 0, a), {"outline": 0.0})
	_collide(root, Toon.box_shape(Vector3(0.9, 1.4, 0.4) * s), Vector3(0, 0.7 * s, 0))


func _stump(root: Node3D, s: float) -> void:
	var wood := _col(Color(0.36, 0.26, 0.24))
	Toon.part(root, Toon.cylinder(0.5 * s, 0.6 * s, 0.6 * s, 10), wood, Vector3(0, 0.3 * s, 0), Vector3.ZERO,
		{"bark": 1.0, "line": wood.darkened(0.5)})
	Toon.part(root, Toon.cylinder(0.42 * s, 0.42 * s, 0.03, 10), Color(0.78, 0.66, 0.5), Vector3(0, 0.61 * s, 0), Vector3.ZERO,
		{"outline": 0.0})
	_collide(root, Toon.cylinder_shape(0.55 * s, 1.0), Vector3(0, 0.5, 0))


## A tilled garden bed: dark soil with a sprout or a ripe ink-pumpkin.
func _garden_plot(root: Node3D, s: float) -> void:
	var soil := _col(Color(0.36, 0.18, 0.18))
	Toon.part(root, Toon.box(Vector3(1.2, 0.14, 1.2) * s), soil, Vector3(0, 0.07 * s, 0), Vector3(0, 45, 0),
		{"tile": 0.32 * s, "line": soil.darkened(0.45), "outline": 0.035})
	var r := _rng.randf()
	if r < 0.35:
		var pumpkin := Toon.part(root, Toon.sphere(0.32 * s, 10, 6), Color(0.95, 0.45, 0.15), Vector3(0, 0.36 * s, 0))
		pumpkin.scale = Vector3(1.2, 0.85, 1.2)
		Toon.part(root, Toon.cylinder(0.04 * s, 0.05 * s, 0.18 * s, 5), Color(0.3, 0.45, 0.2), Vector3(0, 0.66 * s, 0))
	elif r < 0.75:
		for k in 3:
			Toon.part(root, Toon.prism(Vector3(0.12, 0.35, 0.06) * s), Color(0.4, 0.68, 0.36),
				Vector3((k - 1) * 0.16 * s, 0.3 * s, 0), Vector3(0, k * 60.0, (k - 1) * 18.0), {"outline": 0.02})


func _barn(root: Node3D, s: float) -> void:
	var red := _col(Color(0.78, 0.18, 0.15))
	Toon.part(root, Toon.box(Vector3(2.6, 1.7, 2.2) * s), red, Vector3(0, 0.85 * s, 0), Vector3.ZERO,
		{"tile": 0.45 * s, "line": red.darkened(0.45)})
	var roof := Toon.part(root, Toon.prism(Vector3(3.0, 1.3, 2.5) * s), Color(0.3, 0.16, 0.16), Vector3(0, 2.35 * s, 0))
	roof.scale = Vector3(1, 1, 1)
	# white door with a cross brace (the Writer drew the X in)
	var door_z := 1.11 * s
	Toon.part(root, Toon.box(Vector3(1.1, 1.3, 0.05) * s), Color(0.95, 0.92, 0.85), Vector3(0, 0.65 * s, door_z))
	for a in [40.0, -40.0]:
		Toon.part(root, Toon.box(Vector3(0.1, 1.55, 0.04) * s), red.darkened(0.2), Vector3(0, 0.65 * s, door_z + 0.04), Vector3(0, 0, a),
			{"outline": 0.0})
	_collide(root, Toon.box_shape(Vector3(2.7, 2.6, 2.3) * s), Vector3(0, 1.3 * s, 0))


## A draft of Vesper nailed up as a scarecrow, crossed out in red.
func _scarecrow(root: Node3D, s: float) -> void:
	var wood := Color(0.42, 0.3, 0.25)
	Toon.part(root, Toon.box(Vector3(0.14, 2.2, 0.14) * s), wood, Vector3(0, 1.1 * s, 0))
	Toon.part(root, Toon.box(Vector3(1.6, 0.12, 0.12) * s), wood, Vector3(0, 1.6 * s, 0), Vector3(0, 0, 4))
	var paper := Color(0.92, 0.9, 0.84)
	Toon.part(root, Toon.box(Vector3(0.75, 0.8, 0.12) * s), paper, Vector3(0, 1.35 * s, 0.1 * s), Vector3(0, 0, -3))
	Toon.part(root, Toon.sphere(0.32 * s, 9, 5), paper, Vector3(0, 2.15 * s, 0.05 * s))
	Toon.part(root, Toon.cylinder(0.28 * s, 0.42 * s, 0.32 * s, 10), Color(0.12, 0.1, 0.13), Vector3(0, 2.45 * s, 0.05 * s))
	for a in [38.0, -38.0]:
		Toon.part(root, Toon.box(Vector3(0.09, 1.2, 0.03) * s), Color(0.85, 0.12, 0.1), Vector3(0, 1.55 * s, 0.18 * s), Vector3(0, 0, a),
			{"outline": 0.0})
	_collide(root, Toon.cylinder_shape(0.25 * s, 2.0), Vector3(0, 1.0, 0))


# ------------------------------------------------------------------ shrine

func _pillar(root: Node3D, s: float) -> void:
	var st := _col(Color(0.62, 0.6, 0.58))
	var h := 0.0
	var segs := 2 + _rng.randi() % 3
	for i in segs:
		var sh := _rng.randf_range(0.6, 0.9) * s
		var part := Toon.part(root, Toon.cylinder(0.42 * s, 0.46 * s, sh, 10), st.darkened(0.05 * (i % 2)),
			Vector3(_rng.randf_range(-0.04, 0.04), h + sh * 0.5, 0), Vector3(_rng.randf_range(-4, 4), _rng.randf() * 90.0, 0),
			{"moss": 0.45, "tile": 0.0})
		part.scale = Vector3.ONE
		h += sh
	Toon.part(root, Toon.box(Vector3(1.1, 0.3, 1.1) * s), st.darkened(0.12), Vector3(0, 0.15 * s, 0), Vector3.ZERO, {"moss": 0.3})
	# a broken chunk lying beside it
	if _rng.randf() < 0.6:
		var chunk := Toon.part(root, Toon.cylinder(0.4 * s, 0.44 * s, 0.6 * s, 10), st, Vector3(0.9 * s, 0.3 * s, 0.4 * s),
			Vector3(90, _rng.randf() * 180.0, 0), {"moss": 0.4})
		chunk.scale = Vector3.ONE
	_collide(root, Toon.cylinder_shape(0.5 * s, h + 0.5), Vector3(0, (h + 0.5) * 0.5, 0))


func _ritual_circle(root: Node3D, s: float) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_SHADER
	mat.set_shader_parameter("color", _col(Color(0.95, 0.18, 0.14)))
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## The Shade, carved in black stone: a tall shape of ink with white slit eyes.
func _shade_statue(root: Node3D, s: float) -> void:
	var ink := Color(0.07, 0.06, 0.1)
	Toon.part(root, Toon.box(Vector3(2.0, 0.5, 2.0) * s), Color(0.4, 0.38, 0.42), Vector3(0, 0.25 * s, 0), Vector3.ZERO, {"moss": 0.4})
	var body := Toon.part(root, Toon.cylinder(0.25 * s, 0.85 * s, 3.4 * s, 9), ink, Vector3(0, 2.2 * s, 0), Vector3.ZERO, {"outline": 0.06})
	body.scale = Vector3(1.0, 1.0, 0.75)
	Toon.part(root, Toon.sphere(0.55 * s, 10, 6), ink, Vector3(0, 4.1 * s, 0), Vector3.ZERO, {"outline": 0.06})
	for side in [-1, 1]:
		Toon.part(root, Toon.box(Vector3(0.3, 0.07, 0.05) * s), Color(1, 1, 1), Vector3(side * 0.2 * s, 4.15 * s, 0.5 * s),
			Vector3(0, 0, side * -12.0), {"outline": 0.0, "emission": 1.5})
	# ink dripping off the plinth
	for i in 6:
		var x := (_rng.randf() - 0.5) * 1.8 * s
		var len := _rng.randf_range(0.2, 0.45) * s
		Toon.part(root, Toon.box(Vector3(0.08, len, 0.04)), ink, Vector3(x, 0.5 * s - len * 0.5, 1.01 * s), Vector3.ZERO, {"outline": 0.0})
	_collide(root, Toon.box_shape(Vector3(2.0, 4.5, 2.0) * s), Vector3(0, 2.25 * s, 0))


# ---------------------------------------------------------------- shallows

## Retired. Shell coral: a heap of round shells with dark mouths, in
## sea-glass greens and blues.
func _coral(root: Node3D, s: float) -> void:
	var base := _col(Color(0.36, 0.7, 0.62))
	for i in count:
		var p := _rand_in_disc(radius * s) + Vector3(0, 0, 0)
		var r := s * _rng.randf_range(0.35, 0.7)
		var tint := base.lerp(Color(0.3, 0.5, 0.8), _rng.randf() * 0.6)
		var shell := Toon.part(root, Toon.sphere(r, 10, 6), tint, p + Vector3(0, r * 0.8 + _rng.randf() * r, 0),
			Vector3(_rng.randf_range(-30, 30), _rng.randf() * 360.0, 0), {"outline": 0.04})
		shell.scale = Vector3(1.0, 0.85, 1.0)
		# the shell's mouth, a dark disc turned towards the camera
		var mouth := Toon.part(root, Toon.cylinder(r * 0.5, r * 0.5, 0.04, 12), Color(0.05, 0.1, 0.14),
			p + Vector3(0, r * 0.8 + _rng.randf() * 0.2, r * 0.82), Vector3(70, 0, _rng.randf_range(-20, 20)), {"outline": 0.0})
		mouth.scale = Vector3.ONE
	_collide(root, Toon.cylinder_shape(radius * s * 0.8, 2.0), Vector3(0, 1.0, 0))


## Purple tube fingers fanning up out of the water.
func _tube_plant(root: Node3D, s: float) -> void:
	var c := _col(Color(0.55, 0.42, 0.9))
	for i in count:
		var ang := (float(i) / maxf(count - 1, 1) - 0.5) * 70.0 + _rng.randf_range(-8, 8)
		var h := _rng.randf_range(1.4, 2.6) * s
		var cap := CapsuleMesh.new()
		cap.radius = 0.16 * s
		cap.height = h
		cap.radial_segments = 8
		cap.rings = 2
		var holder := Node3D.new()
		holder.rotation_degrees = Vector3(_rng.randf_range(-15, 5), _rng.randf() * 40.0 - 20.0, ang)
		root.add_child(holder)
		Toon.part(holder, cap, c.darkened(_rng.randf() * 0.3), Vector3(0, h * 0.5, 0), Vector3.ZERO, {"outline": 0.035})


func _ink_pool(root: Node3D, s: float) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.4, radius * 2.4)
	var mat := ShaderMaterial.new()
	mat.shader = SPLAT_SHADER
	mat.set_shader_parameter("seed", float(seed) * 7.3)
	mat.set_shader_parameter("ink", _col(Color(0.05, 0.08, 0.2)))
	mat.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ------------------------------------------------------------------ wastes

## Shards of folded paper standing up like crystals.
func _crystal(root: Node3D, s: float) -> void:
	var c := _col(Color(0.82, 0.72, 0.95))
	for i in count:
		var h := _rng.randf_range(0.9, 2.2) * s
		var p := _rand_in_disc(radius * s * 0.6)
		var holder := Node3D.new()
		holder.position = p
		holder.rotation_degrees = Vector3(_rng.randf_range(-25, 25), _rng.randf() * 360.0, _rng.randf_range(-25, 25))
		root.add_child(holder)
		Toon.part(holder, Toon.cylinder(0.0, 0.3 * s * h, h, 4), c.lerp(Color(1, 1, 1), _rng.randf() * 0.4), Vector3(0, h * 0.5, 0),
			Vector3.ZERO, {"outline": 0.035, "emission": 0.25})
	_collide(root, Toon.cylinder_shape(radius * s * 0.6, 2.0), Vector3(0, 1.0, 0))


## A heap of crumpled pages (Silk Cradle's cocoon mounds, in paper).
func _paper_mound(root: Node3D, s: float) -> void:
	var c := _col(Color(0.86, 0.76, 0.7))
	for i in count:
		var p := _rand_in_disc(radius * s * 0.7)
		var r := _rng.randf_range(0.45, 0.85) * s
		var ball := Toon.part(root, Toon.sphere(r, 7, 4), c.darkened(_rng.randf() * 0.3), p + Vector3(0, r * 0.6, 0),
			Vector3(_rng.randf() * 60.0, _rng.randf() * 360.0, _rng.randf() * 60.0), {"outline": 0.04, "bark": 0.8, "line": c.darkened(0.55)})
		ball.scale = Vector3(1.0, 0.75, 1.0)
	_collide(root, Toon.cylinder_shape(radius * s * 0.7, 1.5), Vector3(0, 0.75, 0))


## Giant pins stuck in the ground like spikes.
func _pins(root: Node3D, s: float) -> void:
	var heads := [Color(0.9, 0.2, 0.25), Color(0.95, 0.85, 0.3), Color(0.3, 0.5, 0.9)]
	for i in count:
		var p := _rand_in_disc(radius * s)
		var h := _rng.randf_range(1.0, 2.0) * s
		var holder := Node3D.new()
		holder.position = p
		holder.rotation_degrees = Vector3(_rng.randf_range(-22, 22), 0, _rng.randf_range(-22, 22))
		root.add_child(holder)
		Toon.part(holder, Toon.cylinder(0.035 * s, 0.05 * s, h, 6), Color(0.78, 0.8, 0.86), Vector3(0, h * 0.5, 0), Vector3.ZERO,
			{"outline": 0.025})
		Toon.part(holder, Toon.sphere(0.16 * s, 8, 5), heads[_rng.randi() % heads.size()], Vector3(0, h, 0), Vector3.ZERO, {"outline": 0.03})


## Pale cocoons with glowing blue bulbs on stalks.
func _nest(root: Node3D, s: float) -> void:
	var c := _col(Color(0.9, 0.86, 0.9))
	for i in count:
		var p := _rand_in_disc(radius * s * 0.6)
		var r := _rng.randf_range(0.35, 0.6) * s
		var egg := Toon.part(root, Toon.sphere(r, 10, 6), c.darkened(_rng.randf() * 0.15), p + Vector3(0, r * 0.9, 0),
			Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30)), {"outline": 0.035})
		egg.scale = Vector3(0.8, 1.25, 0.8)
	for i in 3:
		var p := _rand_in_disc(radius * s)
		var h := _rng.randf_range(0.8, 1.8) * s
		Toon.part(root, Toon.cylinder(0.04 * s, 0.06 * s, h, 5), Color(0.2, 0.3, 0.45), p + Vector3(0, h * 0.5, 0), Vector3.ZERO,
			{"outline": 0.02})
		Toon.part(root, Toon.sphere(0.18 * s, 8, 5), Color(0.45, 0.85, 1.0), p + Vector3(0, h, 0), Vector3.ZERO,
			{"outline": 0.025, "emission": 1.2})
	_collide(root, Toon.cylinder_shape(radius * s * 0.6, 1.5), Vector3(0, 0.75, 0))


## A pencil stub standing like a totem, eraser on top.
func _pencil_totem(root: Node3D, s: float) -> void:
	var body := _col(Color(0.98, 0.78, 0.22))
	var h := 2.2 * s
	Toon.part(root, Toon.cylinder(0.3 * s, 0.3 * s, h, 6), body, Vector3(0, h * 0.5 + 0.55 * s, 0), Vector3.ZERO,
		{"bark": 0.6, "line": body.darkened(0.35)})
	# sharpened end buried point-down, wood and graphite showing
	Toon.part(root, Toon.cylinder(0.3 * s, 0.05 * s, 0.55 * s, 6), Color(0.93, 0.78, 0.6), Vector3(0, 0.28 * s, 0))
	Toon.part(root, Toon.cylinder(0.33 * s, 0.33 * s, 0.22 * s, 10), Color(0.72, 0.72, 0.76), Vector3(0, h + 0.66 * s, 0))
	Toon.part(root, Toon.cylinder(0.3 * s, 0.32 * s, 0.4 * s, 10), Color(0.95, 0.55, 0.62), Vector3(0, h + 0.97 * s, 0))
	_collide(root, Toon.cylinder_shape(0.35 * s, h + 1.0), Vector3(0, (h + 1.0) * 0.5, 0))


func _ink_pot(root: Node3D, s: float) -> void:
	var glass := _col(Color(0.82, 0.42, 0.38))
	for i in count:
		var p := _rand_in_disc(radius * s * 0.7)
		var k := _rng.randf_range(0.6, 1.1) * s
		Toon.part(root, Toon.cylinder(0.3 * k, 0.42 * k, 0.75 * k, 10), glass.darkened(_rng.randf() * 0.25), p + Vector3(0, 0.37 * k, 0),
			Vector3.ZERO, {"bark": 0.5, "line": glass.darkened(0.5)})
		Toon.part(root, Toon.cylinder(0.2 * k, 0.26 * k, 0.18 * k, 10), glass.darkened(0.2), p + Vector3(0, 0.84 * k, 0))
		Toon.part(root, Toon.cylinder(0.17 * k, 0.17 * k, 0.03, 10), Color(0.05, 0.03, 0.08), p + Vector3(0, 0.94 * k, 0),
			Vector3.ZERO, {"outline": 0.0})
	_collide(root, Toon.cylinder_shape(radius * s * 0.6, 1.2), Vector3(0, 0.6, 0))
