@tool
extends Node3D
## Props for the 2.5D biomes, picked with `kind`. Each builds from simple
## cel-shaded shapes (toon.gd) like the clearing's props, so they share its
## inked look. `size` scales the prop, `seed` varies it, `color` tints it
## (Color(0, 0, 0, 0) = the prop's own colours), `count`/`radius` are used by
## clusters. Set `solid` to block the player.
##
## Everything in the Gutter is what the Writer threw away or left lying at the
## edge of his desk (the kinds keep their old names; scenes store numbers):
## Darkwood:  TOMBSTONE (discarded drafts: a cracked, dried ink blob, a
##            snapped pen nib stuck in the ground, crumpled paper and
##            crossed-out scraps), STUMP (a worn-down pencil stub)
## Shrine:    PILLAR (a leaning stack of old books), RITUAL_CIRCLE (a
##            glowing circle of the Writer's marks round a pen nib),
##            SHADE_STATUE
## Anywhere:  SKULL_PILE (a heap of `count` crumpled pages and snapped
##            pencils), CANDLES (`count` candles), RUNE_STONE (a giant pen
##            nib standing in the ground, one of the Writer's marks glowing
##            in its breather hole)
## Shallows:  INK_POOL
## Wastes:    CRYSTAL, PAPER_MOUND, PINS, PENCIL_TOTEM, INK_POT
##
## Retired (no longer placed anywhere, kept so the enum's integers stay put;
## never remove or reorder Kind values, scenes store them as numbers):
## CANOPY, GARDEN_PLOT, BARN, SCARECROW, CORAL, TUBE_PLANT, NEST.

const Toon = preload("res://scripts/clearing/toon.gd")
const EYES_SHADER = preload("res://shaders/clearing/glow_eyes.gdshader")
const RING_SHADER = preload("res://shaders/world25/sigil_ring.gdshader")
const MARK_SHADER = preload("res://shaders/world25/sigil_mark.gdshader")
const CORRECTION := Color(0.85, 0.14, 0.12)
const SIGIL_GLOW := Color(1.0, 0.26, 0.16)
const SPLAT_SHADER = preload("res://shaders/clearing/ink_splat.gdshader")
const INK := Color(0.08, 0.06, 0.12)
const PAPER := Color(0.82, 0.79, 0.7)
const STEEL := Color(0.7, 0.72, 0.78)
## Muted paints for pencils and book covers (the Gutter is dark).
const PAINTS := [Color(0.78, 0.6, 0.2), Color(0.55, 0.16, 0.14), Color(0.18, 0.3, 0.45), Color(0.22, 0.36, 0.24),
	Color(0.4, 0.26, 0.42), Color(0.5, 0.36, 0.22)]

enum Kind {
	CANOPY, TOMBSTONE, STUMP, GARDEN_PLOT, BARN, SCARECROW,
	PILLAR, RITUAL_CIRCLE, SHADE_STATUE,
	CORAL, TUBE_PLANT, INK_POOL,
	CRYSTAL, PAPER_MOUND, PINS, NEST, PENCIL_TOTEM, INK_POT,
	# new kinds always go at the end
	SKULL_PILE, CANDLES, RUNE_STONE,
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
## The pool it carves in the Gutter's darkness (darkness.gd), for kinds that
## give light (candles); 0 = none.
var glow_radius := 0.0


func _ready() -> void:
	_rebuild()


func _col(default: Color) -> Color:
	return default if color.a == 0.0 else color


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	_rng.seed = seed
	glow_radius = 0.0
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
		Kind.SKULL_PILE: _skull_pile(root, s)
		Kind.CANDLES: _candles(root, s)
		Kind.RUNE_STONE: _rune_stone(root, s)
	if glow_radius > 0.0 and not Engine.is_editor_hint():
		add_to_group("glow")
	elif is_in_group("glow"):
		remove_from_group("glow")


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


## A grave: a leaning headstone on a low mound of dug earth. Most were
## crossed out in red (cut characters); the rest bear a carved sigil that
## glows faintly. Skulls and bones lie round it, and now and then a candle.
## The Writer's discarded drafts, where the graves used to be: a dried ink
## blob, cracked, with shards broken off it; a pen nib snapped in two, half
## of it stuck point-first in the ground; crumpled balls of paper and torn
## scraps with crossed-out scribbles.
func _tombstone(root: Node3D, s: float) -> void:
	var ink := _col(INK)
	var turn := Node3D.new()
	turn.rotation_degrees.y = _rng.randf_range(-30, 30)
	root.add_child(turn)
	# the dried blob, glossy and cracked
	var blob := Toon.part(turn, Toon.sphere(0.6 * s, 12, 6, true), ink, Vector3(0, 0, 0), Vector3.ZERO, {"outline": 0.03, "emission": 0.04})
	blob.scale = Vector3(1.0, 0.5, 0.8)
	Toon.part(turn, Toon.box(Vector3(0.22, 0.02, 0.06) * s), Color(0.7, 0.72, 0.8), Vector3(-0.15 * s, 0.29 * s, -0.1 * s),
		Vector3(0, 30, 0), {"outline": 0.0, "emission": 0.6})
	for k in 3:
		var a := _rng.randf_range(-0.6, 0.6) + k * 2.1
		Toon.part(turn, Toon.box(Vector3(0.02, 0.025, 0.4) * s), Color(0.32, 0.3, 0.36), Vector3(cos(a) * 0.2 * s, 0.27 * s, sin(a) * 0.2 * s),
			Vector3(0, rad_to_deg(-a), 0), {"outline": 0.0})
	for k in 3:
		var a := _rng.randf() * TAU
		var shard := Toon.part(turn, Toon.prism(Vector3(0.2, 0.16, 0.12) * s), ink, Vector3(cos(a) * 0.75 * s, 0.05 * s, sin(a) * 0.65 * s),
			Vector3(_rng.randf_range(-40, 40), _rng.randf() * 180.0, _rng.randf_range(60, 110)), {"outline": 0.02})
		shard.scale = Vector3.ONE
	# the snapped nib: one half stuck in the ground, the tip lying by it
	var nib := Node3D.new()
	nib.position = Vector3(0.55 * s, 0.32 * s, 0.25 * s)
	nib.rotation_degrees = Vector3(_rng.randf_range(-20, -10), _rng.randf_range(-40, 40), 160.0 + _rng.randf_range(-15, 15))
	turn.add_child(nib)
	Toon.part(nib, Toon.prism(Vector3(0.34, 0.75, 0.05) * s), STEEL, Vector3.ZERO, Vector3.ZERO, {"outline": 0.02, "emission": 0.1})
	Toon.part(nib, Toon.box(Vector3(0.025, 0.5, 0.06) * s), INK, Vector3(0, 0.08 * s, 0), Vector3.ZERO, {"outline": 0.0})
	Toon.part(nib, Toon.cylinder(0.04 * s, 0.04 * s, 0.07 * s, 8), INK, Vector3(0, -0.15 * s, 0), Vector3(90, 0, 0), {"outline": 0.0})
	var tip := Toon.part(turn, Toon.prism(Vector3(0.2, 0.35, 0.04) * s), STEEL, Vector3(-0.7 * s, 0.03 * s, 0.45 * s),
		Vector3(90, _rng.randf() * 180.0, 0), {"outline": 0.015, "emission": 0.1})
	tip.scale = Vector3.ONE
	# crumpled pages and torn scraps, crossed out in red pen
	for k in 2 + _rng.randi() % 2:
		_crumple(turn, Vector3(_rng.randf_range(-0.9, 0.9) * s, 0.0, _rng.randf_range(0.4, 0.9) * s), _rng.randf_range(0.16, 0.26) * s)
	for k in 1 + _rng.randi() % 2:
		_scrap(turn, Vector3(_rng.randf_range(-0.8, 0.8) * s, 0.01, _rng.randf_range(-0.7, 0.8) * s), s, true)
	_collide(root, Toon.box_shape(Vector3(1.3, 1.0, 1.0) * s), Vector3(0, 0.4 * s, 0))


## A crumpled ball of paper: a lumpy low-poly ball, squashed a little.
func _crumple(parent: Node3D, at: Vector3, r: float) -> void:
	var ball := Toon.part(parent, Toon.sphere(r, 6, 4), PAPER.darkened(_rng.randf() * 0.15), at + Vector3(0, r * 0.75, 0),
		Vector3(_rng.randf() * 360.0, _rng.randf() * 360.0, _rng.randf() * 360.0), {"outline": 0.018})
	ball.scale = Vector3(_rng.randf_range(0.85, 1.15), _rng.randf_range(0.75, 1.0), _rng.randf_range(0.85, 1.15))


## A torn scrap of paper lying flat, a few scribbled lines on it; `crossed`
## adds the red pen's X.
func _scrap(parent: Node3D, at: Vector3, s: float, crossed: bool) -> void:
	var scrap := Node3D.new()
	scrap.position = at
	scrap.rotation_degrees = Vector3(_rng.randf_range(-4, 4), _rng.randf() * 360.0, _rng.randf_range(-4, 4))
	parent.add_child(scrap)
	var w := _rng.randf_range(0.4, 0.6) * s
	var d := _rng.randf_range(0.3, 0.45) * s
	Toon.part(scrap, Toon.box(Vector3(w, 0.012, d)), PAPER.lightened(0.05), Vector3(0, 0.006, 0), Vector3.ZERO, {"outline": 0.012})
	for k in 3:
		Toon.part(scrap, Toon.box(Vector3(w * _rng.randf_range(0.4, 0.75), 0.004, 0.012)), INK, Vector3(-w * 0.08, 0.014, -d * 0.3 + k * d * 0.25),
			Vector3.ZERO, {"outline": 0.0})
	if crossed:
		for a in [35.0, -35.0]:
			Toon.part(scrap, Toon.box(Vector3(w * 0.9, 0.006, 0.03)), CORRECTION, Vector3(0, 0.018, 0), Vector3(0, a, 0), {"outline": 0.0})


## A glowing carved mark (sigil_mark.gdshader: one of the Writer's marks,
## writers_marks.gdshaderinc) on a quad facing local +Z.
func _sigil_quad(parent: Node3D, pos: Vector3, w: float, rot := Vector3.ZERO, glow := 1.6) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(w, w)
	var m := ShaderMaterial.new()
	m.shader = MARK_SHADER
	m.set_shader_parameter("sigil", _rng.randi() % 10)  # one of the Writer's marks
	m.set_shader_parameter("seed", float(seed) + _rng.randf() * 10.0)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("color", _col(SIGIL_GLOW) if kind != Kind.TOMBSTONE else SIGIL_GLOW)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A worn-down pencil stub stuck upright in the ground, sharpened.
func _stump(root: Node3D, s: float) -> void:
	var paint: Color = _col(PAINTS[_rng.randi() % PAINTS.size()])
	var h := _rng.randf_range(0.5, 0.8) * s
	var holder := Node3D.new()
	holder.rotation_degrees = Vector3(_rng.randf_range(-8, 8), _rng.randf() * 60.0, _rng.randf_range(-8, 8))
	root.add_child(holder)
	Toon.part(holder, Toon.cylinder(0.42 * s, 0.42 * s, h, 6), paint, Vector3(0, h * 0.5, 0), Vector3.ZERO, {"outline": 0.03})
	Toon.part(holder, Toon.cylinder(0.12 * s, 0.4 * s, 0.4 * s, 6), Color(0.85, 0.68, 0.48), Vector3(0, h + 0.2 * s, 0), Vector3.ZERO,
		{"outline": 0.02})
	Toon.part(holder, Toon.cylinder(0.0, 0.12 * s, 0.14 * s, 6), Color(0.18, 0.18, 0.2), Vector3(0, h + 0.47 * s, 0), Vector3.ZERO,
		{"outline": 0.015})
	# shavings curled round its foot
	for k in 3:
		var a := _rng.randf() * TAU
		var curl := Toon.part(root, Toon.cylinder(0.12 * s, 0.03 * s, 0.05 * s, 8), Color(0.85, 0.68, 0.48), Vector3(cos(a), 0.03, sin(a)) * 0.6 * s,
			Vector3(_rng.randf_range(-30, 30), _rng.randf() * 180.0, 0), {"outline": 0.01})
		curl.scale = Vector3.ONE
	_collide(root, Toon.cylinder_shape(0.45 * s, 1.0), Vector3(0, 0.5, 0))


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

## A leaning stack of old books, one fallen open beside it.
func _pillar(root: Node3D, s: float) -> void:
	var h := 0.0
	var books := 5 + _rng.randi() % 4
	var lean := 0.0
	for i in books:
		var bh := _rng.randf_range(0.22, 0.36) * s
		var size := Vector3(_rng.randf_range(0.9, 1.15), bh, _rng.randf_range(0.7, 0.85)) * Vector3(s, 1, s)
		lean += _rng.randf_range(-0.03, 0.04) * s
		_book(root, Vector3(lean, h + bh * 0.5, _rng.randf_range(-0.05, 0.05) * s), size, _rng.randf_range(-12, 12))
		h += bh
	if _rng.randf() < 0.7:
		_open_book(root, Vector3(0.95 * s, 0.0, 0.5 * s), s)
	_collide(root, Toon.box_shape(Vector3(1.1, h + 0.5, 0.9) * Vector3(s, 1, s)), Vector3(0, (h + 0.5) * 0.5, 0))


## A closed book: cover, a cream block of page edges, the spine.
func _book(parent: Node3D, at: Vector3, size: Vector3, yaw: float) -> void:
	var b := Node3D.new()
	b.position = at
	b.rotation_degrees.y = yaw
	parent.add_child(b)
	var cover: Color = _col(PAINTS[_rng.randi() % PAINTS.size()]).darkened(0.15)
	var t := maxf(size.y * 0.12, 0.025)
	for y in [-1.0, 1.0]:
		Toon.part(b, Toon.box(Vector3(size.x, t, size.z)), cover, Vector3(0, y * (size.y - t) * 0.5, 0), Vector3.ZERO, {"outline": 0.02})
	Toon.part(b, Toon.box(Vector3(size.x - 0.06, size.y - t * 2.0, size.z - 0.05)), PAPER, Vector3(0.02, 0, 0), Vector3.ZERO, {"outline": 0.015})
	Toon.part(b, Toon.box(Vector3(0.07, size.y, size.z)), cover, Vector3(-size.x * 0.5 + 0.035, 0, 0), Vector3.ZERO, {"outline": 0.02})


## A book lying open on the ground, pages up, a few lines of writing.
func _open_book(parent: Node3D, at: Vector3, s: float) -> void:
	var b := Node3D.new()
	b.position = at
	b.rotation_degrees.y = _rng.randf() * 360.0
	parent.add_child(b)
	var cover: Color = PAINTS[_rng.randi() % PAINTS.size()]
	for side in [-1.0, 1.0]:
		Toon.part(b, Toon.box(Vector3(0.5, 0.03, 0.7) * s), cover.darkened(0.2), Vector3(side * 0.26 * s, 0.015, 0), Vector3(0, 0, side * 6.0),
			{"outline": 0.015})
		Toon.part(b, Toon.box(Vector3(0.46, 0.05, 0.66) * s), PAPER, Vector3(side * 0.25 * s, 0.05 * s, 0), Vector3(0, 0, side * 6.0),
			{"outline": 0.012})
		for k in 4:
			Toon.part(b, Toon.box(Vector3(0.32, 0.004, 0.015) * s), INK, Vector3(side * 0.25 * s, 0.077 * s + side * 0.0, -0.2 * s + k * 0.12 * s),
				Vector3(0, 0, side * 6.0), {"outline": 0.0})


func _ritual_circle(root: Node3D, s: float) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter("color", _col(SIGIL_GLOW))
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

## Torn-out pages stuck upright in the ground like shards (they were
## crystals): ruled sheets, a jagged torn edge on top, a faint glow so they
## catch the eye in the dark, tinted by the biome.
func _crystal(root: Node3D, s: float) -> void:
	var c := _col(Color(0.82, 0.72, 0.95)).lerp(PAPER, 0.45)
	for i in count:
		var h := _rng.randf_range(0.9, 2.0) * s
		var w := h * _rng.randf_range(0.45, 0.7)
		var p := _rand_in_disc(radius * s * 0.6)
		var holder := Node3D.new()
		holder.position = p + Vector3(0, -0.15 * s, 0)  # sunk into the ground
		holder.rotation_degrees = Vector3(_rng.randf_range(-22, 22), _rng.randf() * 360.0, _rng.randf_range(-22, 22))
		root.add_child(holder)
		var sheet := c.lerp(Color(1, 1, 1), _rng.randf() * 0.25)
		var ruled := {"outline": 0.03, "emission": 0.2, "pages": 0.16 * s, "line": sheet.darkened(0.4)}
		Toon.part(holder, Toon.box(Vector3(w, h, 0.04)), sheet, Vector3(0, h * 0.5, 0), Vector3.ZERO, ruled)
		# the torn top: two jagged teeth
		Toon.part(holder, Toon.prism(Vector3(w * 0.55, h * 0.28, 0.04)), sheet, Vector3(-w * 0.22, h + h * 0.13, 0), Vector3(0, 0, 8),
			{"outline": 0.03, "emission": 0.2})
		Toon.part(holder, Toon.prism(Vector3(w * 0.5, h * 0.18, 0.04)), sheet, Vector3(w * 0.25, h + h * 0.08, 0), Vector3(0, 0, -6),
			{"outline": 0.03, "emission": 0.2})
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


# --------------------------------------------------------------- the dead

## Skulls heaped into a mound, a couple of bones rolled away. `count` is how
## many skulls, `radius` how wide; big ones make the background's heaps.
## A heap of crumpled pages (`count` of them) with snapped pencils and a
## scrap or two: the Writer's wastepaper spilling over.
func _skull_pile(root: Node3D, s: float) -> void:
	var n := maxi(count, 3)
	var big := radius * s
	for k in n:
		# denser and higher towards the middle: a mound, not a ring
		var d := pow(_rng.randf(), 0.8) * big
		var a := _rng.randf() * TAU
		var y := (1.0 - (d / big) * (d / big)) * big * 0.5
		_crumple(root, Vector3(cos(a) * d, y, sin(a) * d), _rng.randf_range(0.22, 0.34) * s)
	for k in 2:
		_snapped_pencil(root, _rand_in_disc(big * 1.1), s)
	_scrap(root, _rand_in_disc(big * 1.2) + Vector3(0, 0.01, 0), s, _rng.randf() < 0.5)
	_collide(root, Toon.cylinder_shape(big * 0.6, 1.2), Vector3(0, 0.6, 0))


## Half a pencil, snapped, lying on the ground.
func _snapped_pencil(parent: Node3D, at: Vector3, s: float) -> void:
	var p := Node3D.new()
	p.position = at + Vector3(0, 0.07 * s, 0)
	p.rotation_degrees = Vector3(0, _rng.randf() * 360.0, 90)
	parent.add_child(p)
	var paint: Color = PAINTS[_rng.randi() % PAINTS.size()]
	var len := _rng.randf_range(0.5, 0.8) * s
	Toon.part(p, Toon.cylinder(0.07 * s, 0.07 * s, len, 6), paint, Vector3(0, 0, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(p, Toon.cylinder(0.0, 0.07 * s, 0.16 * s, 6), Color(0.85, 0.68, 0.48), Vector3(0, len * 0.5 + 0.08 * s, 0), Vector3.ZERO,
		{"outline": 0.01})
	# the splintered end
	Toon.part(p, Toon.prism(Vector3(0.12, 0.1, 0.12) * s), Color(0.85, 0.68, 0.48), Vector3(0, -len * 0.5 - 0.04 * s, 0), Vector3(180, 0, 0),
		{"outline": 0.01})


## Cream candles of every height melted onto a puddle of wax.
func _candles(root: Node3D, s: float) -> void:
	var wax := _col(Color(0.82, 0.78, 0.68))
	var puddle := Toon.part(root, Toon.cylinder(radius * s * 0.8, radius * s * 0.9, 0.04, 14), wax.darkened(0.35), Vector3(0, 0.02, 0),
		Vector3.ZERO, {"outline": 0.0})
	puddle.scale = Vector3(1.0, 1.0, 0.8)
	for k in maxi(count, 1):
		var p := _rand_in_disc(radius * s * 0.75)
		Toon.candle(root, p, _rng.randf_range(0.14, 0.5) * s, Color(1.0, 0.42, 0.2), wax.lerp(Color(0.9, 0.85, 0.75), _rng.randf() * 0.3))
	glow_radius = 1.4 + radius * s * 0.6
	if not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.45, 0.25)
		l.light_energy = 0.9
		l.omni_range = glow_radius + 1.0
		l.position = Vector3(0, 0.6, 0)
		root.add_child(l)


## A giant pen nib stood point-first in the ground like a standing stone,
## leaning, one of the Writer's marks glowing in its breather hole, a pool
## of dried ink round its foot.
func _rune_stone(root: Node3D, s: float) -> void:
	var steel := _col(STEEL)
	var holder := Node3D.new()
	holder.rotation_degrees = Vector3(_rng.randf_range(-7, 7), _rng.randf_range(-20, 20), _rng.randf_range(-7, 7))
	root.add_child(holder)
	var h := _rng.randf_range(1.8, 2.4) * s
	# the nib, upside down: shoulders up top, the split point in the ground
	Toon.part(holder, Toon.prism(Vector3(1.1 * s, h, 0.14 * s)), steel, Vector3(0, h * 0.5, 0), Vector3(180, 0, 0),
		{"outline": 0.03, "emission": 0.08})
	Toon.part(holder, Toon.box(Vector3(1.12, 0.3, 0.16) * s), steel.darkened(0.25), Vector3(0, h + 0.1 * s, 0), Vector3.ZERO, {"outline": 0.025})
	Toon.part(holder, Toon.box(Vector3(0.05 * s, h * 0.55, 0.16 * s)), INK, Vector3(0, h * 0.27, 0.0), Vector3.ZERO, {"outline": 0.0})
	Toon.part(holder, Toon.cylinder(0.17 * s, 0.17 * s, 0.17 * s, 14), INK, Vector3(0, h * 0.62, 0), Vector3(90, 0, 0), {"outline": 0.0})
	_sigil_quad(holder, Vector3(0, h * 0.62, 0.09 * s), 0.36 * s, Vector3.ZERO, 2.0)
	var pool := Toon.part(root, Toon.cylinder(0.75 * s, 0.8 * s, 0.03, 16), INK, Vector3(0, 0.015, 0), Vector3.ZERO, {"outline": 0.0})
	pool.scale = Vector3(1.0, 1.0, 0.7)
	_collide(root, Toon.box_shape(Vector3(1.0, 2.0, 0.4) * s), Vector3(0, 1.0, 0))
