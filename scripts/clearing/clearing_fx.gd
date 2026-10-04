extends RefCounted
## One-shot effects for the 2.5D clearing: the attack slash, comic hit
## text, ink splats and grass clippings. Each spawns into the current scene
## and frees itself.

const SLASH_SHADER = preload("res://shaders/clearing/slash_arc.gdshader")
const SPLAT_SHADER = preload("res://shaders/clearing/ink_splat.gdshader")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const ScreenAnchor = preload("res://scripts/clearing/screen_anchor.gd")
const INK := Color(0.06, 0.03, 0.13)


## Draws every effect once, hidden under the ground at `pos`, so their
## shaders compile while the level loads instead of hitching the game on
## the first swing or the first kill.
static func prewarm(tree: SceneTree, pos: Vector3) -> void:
	var hidden := pos - Vector3(0, 1.5, 0)
	slash(tree, hidden, Vector3.RIGHT, false, false)
	slash(tree, hidden, Vector3.RIGHT, true, true)
	splat(tree, hidden)
	burst(tree, hidden, Color(0.42, 0.62, 0.42), 4)


## Ink crescent swept on the ground around `pos`, facing `dir`.
static func slash(tree: SceneTree, pos: Vector3, dir: Vector3, mirror: bool, big: bool, rim := Color(1.0, 0.58, 0.14)) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	var size := 4.4 if big else 3.6
	q.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = SLASH_SHADER
	mat.set_shader_parameter("mirror", -1.0 if mirror else 1.0)
	mat.set_shader_parameter("arc_deg", 190.0 if big else 150.0)
	mat.set_shader_parameter("rim", rim)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.55, 0)
	mi.rotation.y = atan2(-dir.z, dir.x)
	var t := mi.create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.24 if big else 0.18)
	t.tween_callback(mi.queue_free)


## Comic sound-effect word ("THWACK!"): the platformer's own 2D pop text,
## drawn on the scene's UI layer and pinned over the 3D point.
static func pop_text(tree: SceneTree, pos: Vector3, text: String, color := Color(1.0, 0.82, 0.15), size := 34) -> void:
	var settings := tree.root.get_node_or_null("Settings")
	if settings and settings.get_value("hit_text") == "off":
		return
	var layer: Node = tree.current_scene.get_node_or_null("UI")
	if layer == null:
		layer = tree.current_scene
	var anchor := ScreenAnchor.new()
	anchor.world_position = pos
	var pop := ComicText.new()
	pop.text = text
	pop.color = color
	pop.font_size = size
	anchor.add_child(pop)
	layer.add_child(anchor)


## Ink blob on the ground that fades away after a few seconds.
static func splat(tree: SceneTree, pos: Vector3, size := 1.6) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = SPLAT_SHADER
	mat.set_shader_parameter("seed", randf() * 50.0)
	mat.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_position = Vector3(pos.x, pos.y + 0.02, pos.z)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * 0.3
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_interval(3.0)
	t.tween_method(func(v: float): mat.set_shader_parameter("alpha", v), 1.0, 0.0, 1.5)
	t.tween_callback(mi.queue_free)


## Burst of little flat bits (grass clippings, ink droplets).
static func burst(tree: SceneTree, pos: Vector3, color: Color, amount := 12, speed := 3.5) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _bit_mesh()
	p.color = color
	p.amount = amount
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.angle_max = 180.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## One particle mesh + material shared by every burst (colour comes from
## the particles). Kept alive for good: a StandardMaterial3D's shader is
## freed with the last material using it, and recompiling it on every
## burst hitched the game for ~200 ms.
static var _bits: QuadMesh


static func _bit_mesh() -> QuadMesh:
	if _bits == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		_bits = QuadMesh.new()
		_bits.size = Vector2(0.12, 0.12)
		_bits.material = mat
	return _bits
