extends RefCounted
## Shared helpers for the 2.5D clearing props: cel-shaded materials with an
## ink outline pass, and shortcuts for adding mesh parts and colliders.
## Props are @tool scripts that build their parts under a "Generated" child,
## which is never saved into the scene, so they are cheap to tweak in the
## editor: change an export and the prop rebuilds.

const TOON_SHADER = preload("res://shaders/clearing/toon.gdshader")
const OUTLINE_SHADER = preload("res://shaders/clearing/toon_outline.gdshader")
const INK := Color(0.06, 0.04, 0.09)
## Ruined stone and the grey-green lichen on it: the Gutter is dark and cold.
const STONE := Color(0.34, 0.35, 0.37)
const MOSS := Color(0.17, 0.22, 0.21)

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
