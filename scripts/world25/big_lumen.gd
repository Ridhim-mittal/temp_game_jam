@tool
extends Node3D
## The big Lumen in the Margins (the 2D levels' big_coin.gd): the same gold
## coin as lumen.gd, five times the size, standing up and turning slowly
## over the floor, worth 15 at once. Its own glow: a pale aura and a ring of
## turning rays behind it (additive billboards), and it lights a pool in the
## Gutter's darkness (group "glow", darkness.gd). Placed off the usual path.
## Walk into it: "x15", and it stays gone for the run (GameState.collected).
## Origin = the floor under it.

const Lumen = preload("res://scripts/world25/lumen.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const AURA := Color(0.62, 0.95, 1.0)
const RAYS := Color(1.0, 0.85, 0.45)

@export var value := 15
## Pool of light it keeps in the darkness (darkness.gd reads it).
@export var glow_radius := 2.2

var _coin: Node3D
var _aura: MeshInstance3D
var _rays: MeshInstance3D
var _time := 0.0
var _taken := false


func _ready() -> void:
	for c in get_children():
		if c.name == "Generated":
			c.free()
	var gen := Node3D.new()
	gen.name = "Generated"
	add_child(gen)
	_coin = Node3D.new()
	_coin.position = Vector3(0, 1.1, 0)
	gen.add_child(_coin)
	Lumen.build_coin(_coin, 0.5)
	_rays = _billboard(gen, 3.4, _ray_texture(), RAYS, 0.8)
	_aura = _billboard(gen, 3.0, _aura_texture(), AURA, 0.75)
	_time = position.x
	if Engine.is_editor_hint():
		return
	var state := get_node_or_null("/root/GameState")
	if state and state.collected.has(state.id_of(self)):
		queue_free()
		return
	add_to_group("glow")


func _billboard(parent: Node3D, size: float, tex: Texture2D, col: Color, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.albedo_texture = tex
	m.albedo_color = Color(col, alpha)
	m.render_priority = 1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = _coin.position
	parent.add_child(mi)
	return mi


static func _aura_texture() -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	tex.gradient = g
	return tex


## Ten soft rays round a clear middle, drawn once into an image.
static func _ray_texture() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var r := d.length()
			var a := pow(maxf(cos(atan2(d.y, d.x) * 5.0), 0.0), 6.0) * clampf((r - 0.25) * 4.0, 0.0, 1.0) * clampf((1.0 - r) * 2.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if _coin == null:
		return
	_time += delta
	var bob := sin(_time * 2.2) * 0.08
	_coin.position.y = 1.1 + bob
	_coin.rotation.y += delta * (9.0 if _taken else 1.6)
	_aura.position.y = _coin.position.y
	_rays.position.y = _coin.position.y
	var pulse := 0.9 + 0.1 * sin(_time * 3.1)
	_aura.scale = Vector3.ONE * pulse
	_rays.scale = Vector3.ONE * (0.92 + 0.12 * sin(_time * 2.0))
	if Engine.is_editor_hint() or _taken:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and not player.get("dead"):
		var to := player.global_position + Vector3(0, 0.6, 0) - (global_position + _coin.position)
		if to.length() < 1.0:
			_collect()


func _collect() -> void:
	_taken = true
	remove_from_group("glow")
	var state := get_node_or_null("/root/GameState")
	if state:
		state.collected[state.id_of(self)] = true
	var profile := get_node_or_null("/root/Profile")
	if profile:
		profile.add_lumens(value)
	Fx.pop_text(get_tree(), global_position + Vector3(0, 2.0, 0), "x%d" % value, Color(1.0, 0.85, 0.3), 44)
	var t := create_tween().set_parallel()
	t.tween_property(_coin, "position:y", 1.8, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector3.ONE * 1.4, 0.3)
	t.chain().tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
	t.chain().tween_callback(queue_free)
