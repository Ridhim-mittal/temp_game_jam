extends RefCounted
## The 2.5D effects of the weapons' specials (clearing_player.gd; catalog.gd
## "special"), the twins of scripts/effects/weapon_fx.gd:
##   ring()        - a ring of ink running out on the ground (INK SLAM, the
##                   drill's burst; shock_ring.gdshader)
##   rainbow()     - a wide arc of rainbow bands (BLINDING SWEEP,
##                   prism_sweep.gdshader)
##   QuillDart     - one flying quill of the QUILL VOLLEY (pierces)
##   OrbitLantern  - the Lantern Flail's lantern while it whirls (a real light)

const Toon = preload("res://scripts/clearing/toon.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const RING_SHADER = preload("res://shaders/clearing/shock_ring.gdshader")
const PRISM_SHADER = preload("res://shaders/clearing/prism_sweep.gdshader")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")


## A ring of ink racing out along the ground from `pos` to `radius`, a
## bright core with a coloured rim (shock_ring.gdshader), then fading.
static func ring(tree: SceneTree, pos: Vector3, radius: float, rim: Color, time := 0.35) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter("rim", rim)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	var t := mi.create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, time)
	t.tween_callback(mi.queue_free)


## The Prism Saber's sweep: rainbow bands fanning out in front, `radius`
## across, then fading.
static func rainbow(tree: SceneTree, pos: Vector3, dir: Vector3, radius := 3.2) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = PRISM_SHADER
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.5, 0)
	mi.rotation.y = atan2(-dir.z, dir.x)
	var t := mi.create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.5)
	t.tween_callback(mi.queue_free)


## One quill of the volley: flies along `direction` at `speed`, hits every
## monster it passes once, stops at walls and after `max_range`.
class QuillDart extends Node3D:
	var direction := Vector3.RIGHT
	var speed := 14.0
	var max_range := 9.0
	var damage := 1
	var color := Color(0.55, 0.85, 1.0)
	var _travelled := 0.0
	var _hit: Array = []

	func _ready() -> void:
		var root := Node3D.new()
		add_child(root)
		Toon.part(root, Toon.cylinder(0.012, 0.012, 0.6, 6), Color(0.95, 0.93, 0.86), Vector3.ZERO, Vector3(0, 0, 90), {"outline": 0.008})
		Toon.part(root, Toon.box(Vector3(0.42, 0.012, 0.11)), color.lerp(Color.WHITE, 0.55), Vector3(-0.08, 0, 0), Vector3.ZERO,
			{"outline": 0.01, "emission": 0.3})
		Toon.part(root, Toon.prism(Vector3(0.06, 0.12, 0.012)), Color(0.88, 0.9, 0.96), Vector3(0.35, 0, 0), Vector3(0, 0, -90),
			{"outline": 0.008, "emission": 0.2})
		rotation.y = atan2(-direction.z, direction.x)

	func _physics_process(delta: float) -> void:
		var step := direction * speed * delta
		var space := get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
		if not space.intersect_ray(ray).is_empty():
			queue_free()
			return
		global_position += step
		_travelled += step.length()
		var shape := SphereShape3D.new()
		shape.radius = 0.5
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), global_position)
		params.collision_mask = 4
		for r in space.intersect_shape(params, 8):
			var t: Object = r.collider
			if t == null or t in _hit or not t.has_method("take_hit") or ("dead" in t and t.dead):
				continue
			_hit.append(t)
			if t.take_hit(damage, direction, false) != false:
				Fx.pop_text(get_tree(), t.global_position + Vector3(0, 1.3, 0), "THWIP!", Color(0.6, 0.9, 1.0), 26)
		if _travelled >= max_range:
			queue_free()


## The whirling lantern: a little lit lantern with a warm glow, on a chain
## back to `anchor` (Vesper's hand, set every frame by the player).
class OrbitLantern extends Node3D:
	var glow_range := 4.0
	var anchor := Vector3.ZERO
	var _links: Array[Node3D] = []

	func _process(_delta: float) -> void:
		for k in _links.size():
			_links[k].global_position = anchor.lerp(global_position, float(k + 1) / (_links.size() + 1))

	func _ready() -> void:
		var frame := Color(0.22, 0.2, 0.24)
		Toon.part(self, Toon.box(Vector3(0.3, 0.05, 0.3)), frame, Vector3(0, 0.2, 0), Vector3.ZERO, {"outline": 0.015})
		Toon.part(self, Toon.box(Vector3(0.3, 0.05, 0.3)), frame, Vector3(0, -0.2, 0), Vector3.ZERO, {"outline": 0.015})
		for k in 4:
			var a := k * PI * 0.5 + PI * 0.25
			Toon.part(self, Toon.box(Vector3(0.035, 0.38, 0.035)), frame, Vector3(cos(a), 0, sin(a)) * 0.14, Vector3.ZERO, {"outline": 0.008})
		Toon.part(self, Toon.sphere(0.12, 10, 6), Color(1.0, 0.82, 0.42), Vector3.ZERO, Vector3.ZERO, {"outline": 0.0, "emission": 2.0})
		# a glow you can see from above, and the chain
		Toon.billboard(self, FLAME_SHADER, Vector2(1.0, 1.1), Vector3(0, 0.1, 0),
			{"outer_color": Color(1.0, 0.7, 0.3), "core_color": Color(1.0, 0.97, 0.8), "brightness": 2.0})
		for k in 6:
			var link := Node3D.new()
			add_child(link)
			link.top_level = true
			Toon.part(link, Toon.sphere(0.045, 6, 4), Color(0.55, 0.55, 0.6), Vector3.ZERO, Vector3.ZERO, {"outline": 0.01})
			_links.append(link)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.78, 0.42)
		light.light_energy = 2.2
		light.omni_range = glow_range
		add_child(light)
