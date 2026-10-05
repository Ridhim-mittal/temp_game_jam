extends RefCounted
## Shared helpers for the 2.5D clearing props: cel-shaded materials with an
## ink outline pass, and shortcuts for adding mesh parts and colliders.
## Props are @tool scripts that build their parts under a "Generated" child,
## which is never saved into the scene, so they are cheap to tweak in the
## editor: change an export and the prop rebuilds.

const TOON_SHADER = preload("res://shaders/clearing/toon.gdshader")
const OUTLINE_SHADER = preload("res://shaders/clearing/toon_outline.gdshader")
const INK := Color(0.06, 0.04, 0.09)
const STONE := Color(0.64, 0.6, 0.58)
const MOSS := Color(0.36, 0.6, 0.42)

static var _materials := {}


## A cel-shaded material. opts: outline (width, 0 = none), from_center,
## moss, tile, bark, line, emission (keys map to toon.gdshader uniforms).
static func material(color: Color, opts := {}) -> ShaderMaterial:
	var key := "%s|%s" % [color, opts]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("moss_amount", opts.get("moss", 0.0))
	m.set_shader_parameter("moss_color", opts.get("moss_color", MOSS))
	m.set_shader_parameter("tile_size", opts.get("tile", 0.0))
	m.set_shader_parameter("bark", opts.get("bark", 0.0))
	m.set_shader_parameter("line_color", opts.get("line", INK))
	m.set_shader_parameter("emission_strength", opts.get("emission", 0.0))
	var width: float = opts.get("outline", 0.045)
	if width > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("width", width)
		o.set_shader_parameter("from_center", opts.get("from_center", 0.0))
		m.next_pass = o
	_materials[key] = m
	return m


## Frees the previous build and returns an empty "Generated" node.
static func fresh_root(owner_node: Node3D) -> Node3D:
	var old := owner_node.get_node_or_null("Generated")
	if old:
		owner_node.remove_child(old)
		old.free()
	var root := Node3D.new()
	root.name = "Generated"
	owner_node.add_child(root)
	return root


## Adds a mesh part. Boxes get the corner-safe outline by default.
static func part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, opts := {}) -> MeshInstance3D:
	if not opts.has("from_center"):
		opts = opts.duplicate()
		opts["from_center"] = 1.0 if mesh is BoxMesh or mesh is PrismMesh else 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, opts)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top_r: float, bottom_r: float, height: float, segments := 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func sphere(radius: float, segments := 12, rings := 6, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * (1.0 if hemisphere else 2.0)
	m.radial_segments = segments
	m.rings = rings
	m.is_hemisphere = hemisphere
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


## Camera-facing quad with a custom shader (flames, eyes).
static func billboard(parent: Node3D, shader: Shader, size: Vector2, pos: Vector3, params := {}) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Static collider on the world layer (layer 1).
static func collider(parent: Node3D, shape: Shape3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


static func box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func cylinder_shape(radius: float, height: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return s


# --------------------------------------------------------- bones and wax

const BONE := Color(0.8, 0.76, 0.66)
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")


## A small skull, `s` units across, facing local +Z: domed cranium, jaw,
## dark eye sockets and nose, a line of teeth. Returns its holder node.
static func skull(parent: Node3D, pos: Vector3, s := 0.3, yaw_deg := 0.0, tilt := Vector3.ZERO, tint := BONE) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = Vector3(tilt.x, yaw_deg, tilt.z)
	parent.add_child(n)
	var o := {"outline": 0.016}
	var head := part(n, sphere(0.5 * s, 10, 6), tint, Vector3(0, 0.52 * s, 0), Vector3.ZERO, o)
	head.scale = Vector3(1.0, 0.92, 1.1)
	part(n, box(Vector3(0.6, 0.28, 0.4) * s), tint.darkened(0.08), Vector3(0, 0.16 * s, 0.14 * s), Vector3.ZERO, o)
	var none := {"outline": 0.0}
	for side in [-1, 1]:
		var eye := part(n, sphere(0.15 * s, 8, 4), INK, Vector3(side * 0.19 * s, 0.5 * s, 0.43 * s), Vector3.ZERO, none)
		eye.scale = Vector3(1.0, 1.15, 0.6)
	part(n, prism(Vector3(0.12, 0.13, 0.06) * s), INK, Vector3(0, 0.33 * s, 0.53 * s), Vector3(0, 0, 180), none)
	part(n, box(Vector3(0.42, 0.03, 0.02) * s), INK, Vector3(0, 0.19 * s, 0.35 * s), Vector3.ZERO, none)
	return n


## A crossed pair of bones lying flat, about `s` long.
static func bones(parent: Node3D, pos: Vector3, s := 0.5, yaw_deg := 0.0) -> void:
	for k in 2:
		var b := Node3D.new()
		b.position = pos + Vector3(0, 0.04 * s + k * 0.03 * s, 0)
		b.rotation_degrees = Vector3(0, yaw_deg + (k * 2 - 1) * 35.0, 90)
		parent.add_child(b)
		part(b, cylinder(0.05 * s, 0.05 * s, s, 6), BONE.darkened(0.05 * k), Vector3.ZERO, Vector3.ZERO, {"outline": 0.014})
		for end in [-1, 1]:
			part(b, sphere(0.08 * s, 6, 4), BONE, Vector3(0, end * s * 0.5, 0), Vector3.ZERO, {"outline": 0.014})


## A wax candle, `h` tall, with a little flame on top.
static func candle(parent: Node3D, pos: Vector3, h := 0.3, flame := Color(1.0, 0.42, 0.2), wax := Color(0.78, 0.2, 0.18)) -> void:
	part(parent, cylinder(0.05, 0.06, h, 8), wax, pos + Vector3(0, h * 0.5, 0), Vector3.ZERO, {"outline": 0.014})
	part(parent, sphere(0.04, 6, 4), wax.lightened(0.1), pos + Vector3(0.05, h * 0.7, 0.02), Vector3.ZERO, {"outline": 0.0})
	billboard(parent, FLAME_SHADER, Vector2(0.15, 0.24), pos + Vector3(0, h + 0.1, 0),
		{"outer_color": flame, "core_color": flame.lightened(0.6), "brightness": 2.2})
