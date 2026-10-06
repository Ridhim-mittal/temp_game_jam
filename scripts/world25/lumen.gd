extends Node3D
## A Margins coin dropped by a beaten monster (monster_3d.gd and scribble.gd
## _die()): the same gold Lumen as the 2D levels' coins (coin.gd: a gold
## disc, a darker ring and the embossed V), only small. They spill out in a tight little cluster, bounce,
## settle and spin, each twinkling now and then (a small additive glint,
## bright enough to show through the Gutter's darkness, darkness.gd). Within
## `magnet` of Vesper (or after `home_after` seconds, wherever he is) they
## fly to him. Each adds `value` to the shop's purse (Profile.lumens); the
## HUD's counter (clearing_hud.gd) shows it. Spawn them with Lumen.spill().

const Toon = preload("res://scripts/clearing/toon.gd")
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.78, 0.46, 0.1)
const GOLD_LIGHT := Color(1.0, 0.95, 0.65)
## Most coins one monster spills (the rest go into their values).
const MAX_COINS := 14

var value := 1
var velocity := Vector3.ZERO
## Vesper this close: the coin flies to him.
var magnet := 3.0
## After this long it flies to him from anywhere.
var home_after := 6.0

var _ground := 0.0
var _age := 0.0
var _coin: Node3D
var _glint: MeshInstance3D
var _phase := 0.0

## One glint material for every coin (made once: a radial white fade, added).
static var _glint_mat: StandardMaterial3D


## Spill `total` coins' worth round `at`, as up to MAX_COINS small coins in
## a tight cluster.
static func spill(tree: SceneTree, at: Vector3, total: int) -> void:
	if total <= 0:
		return
	var script: Script = load("res://scripts/world25/lumen.gd")
	var coins := clampi(total, 1, MAX_COINS)
	for i in coins:
		var c: Node3D = script.new()
		c.value = total / coins + (1 if i < total % coins else 0)
		var a := randf() * TAU
		c.velocity = Vector3(cos(a), 0, sin(a)) * randf_range(0.4, 1.3) + Vector3(0, randf_range(3.0, 4.5), 0)
		tree.current_scene.add_child(c)
		c.global_position = at + Vector3(randf_range(-0.15, 0.15), 0.6, randf_range(-0.15, 0.15))
		c._ground = at.y
		c._age = -randf() * 0.15  # not all in the same instant


func _ready() -> void:
	add_to_group("margin_coin")
	_coin = Node3D.new()
	add_child(_coin)
	build_coin(_coin, 0.1 + 0.015 * minf(value - 1, 4))
	_coin.rotation.y = randf() * TAU
	_glint = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	_glint.mesh = q
	_glint.material_override = _glint_material()
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.position = Vector3(0, 0.02, 0)
	add_child(_glint)
	_phase = randf() * TAU


## The Lumen's model under `parent`, facing +z (as coin.gd draws it): a gold
## disc with a ring and the embossed V on both faces. big_lumen.gd uses it too.
static func build_coin(parent: Node3D, size: float) -> void:
	Toon.part(parent, Toon.cylinder(size, size, size * 0.35, 18), GOLD, Vector3.ZERO, Vector3(90, 0, 0),
		{"outline": size * 0.18, "emission": 0.35})
	Toon.part(parent, Toon.cylinder(size * 0.72, size * 0.72, size * 0.38, 16), GOLD_DARK, Vector3.ZERO, Vector3(90, 0, 0),
		{"outline": 0.0, "emission": 0.25})
	Toon.part(parent, Toon.cylinder(size * 0.6, size * 0.6, size * 0.4, 16), GOLD, Vector3.ZERO, Vector3(90, 0, 0),
		{"outline": 0.0, "emission": 0.35})
	for sx in [-1.0, 1.0]:  # the V's two strokes
		Toon.part(parent, Toon.box(Vector3(size * 0.16, size * 0.82, size * 0.46)), GOLD_LIGHT,
			Vector3(sx * size * 0.15, 0, 0), Vector3(0, 0, -sx * 22.0), {"outline": 0.0, "emission": 0.6})


static func _glint_material() -> StandardMaterial3D:
	if _glint_mat == null:
		var tex := GradientTexture2D.new()
		tex.width = 32
		tex.height = 32
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.15, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 0.9, 1), Color(1.0, 0.9, 0.6, 0.8), Color(0.9, 0.7, 0.3, 0.15), Color(1, 1, 1, 0)])
		tex.gradient = g
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glint_mat.albedo_texture = tex
		_glint_mat.render_priority = 2
	return _glint_mat


func _physics_process(delta: float) -> void:
	_age += delta
	_coin.rotation.y += delta * 5.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and _age > 0.5 and not player.dead:
		var to := player.global_position + Vector3(0, 0.6, 0) - global_position
		if to.length() < 0.6:
			_collect()
			return
		if to.length() < magnet or _age > home_after:
			velocity = velocity.lerp(to.normalized() * 13.0, 1.0 - exp(-9.0 * delta))
			global_position += velocity * delta
			return
	velocity.y -= 18.0 * delta
	global_position += velocity * delta
	if global_position.y < _ground + 0.15:
		global_position.y = _ground + 0.15
		velocity = Vector3(velocity.x * 0.4, absf(velocity.y) * 0.25, velocity.z * 0.4)
		if velocity.length() < 0.4:
			velocity = Vector3.ZERO
	_coin.position.y = sin(_age * 3.0) * 0.04
	_twinkle()


## A soft glow that flares into a glint every second or so.
func _twinkle() -> void:
	var t := fposmod(_age * 0.9 + _phase, TAU)
	var flare := pow(maxf(sin(t), 0.0), 12.0)
	_glint.position.y = _coin.position.y + 0.02
	_glint.scale = Vector3.ONE * (0.55 + 0.9 * flare)


func _collect() -> void:
	var profile := get_node_or_null("/root/Profile")
	if profile:
		profile.add_lumens(value)
	queue_free()
