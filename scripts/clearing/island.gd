@tool
extends Node3D
## The clearing's ground: a flat plateau cut from `polygon` (x, z) with a
## dark cliff dropping into the void. Edges get invisible walls so the
## player can't walk off, except the edges listed in `open_edges` (where
## stairs or a bridge connect). Edge i runs from point i to point i + 1.

const GROUND_SHADER = preload("res://shaders/clearing/ground.gdshader")

@export var polygon := PackedVector2Array():
	set(v):
		polygon = v
		_rebuild()
@export var depth := 7.0:
	set(v):
		depth = v
		_rebuild()
@export var open_edges := PackedInt32Array():
	set(v):
		open_edges = v
		_rebuild()
@export var wall_height := 3.0
## Sandy patches: x, z centre and radius.
@export var sand_zones := PackedVector3Array():
	set(v):
		sand_zones = v
		_rebuild()
## Where the ink stains gather: x, z centre and radius.
@export var stain_zone := Vector3.ZERO:
	set(v):
		stain_zone = v
		_rebuild()
## Ground look (scripts/world25/biome.gd); empty = the clearing's colours.
@export var biome: Resource:
	set(v):
		biome = v
		_rebuild()
@export_group("Blend into another biome")
## Biome B takes over past the wavy line between blend_from and blend_to
## (x, z). Leave empty for a single-biome island.
@export var biome_b: Resource:
	set(v):
		biome_b = v
		_rebuild()
@export var blend_from := Vector2(0, 0):
	set(v):
		blend_from = v
		_rebuild()
@export var blend_to := Vector2(10, 0):
	set(v):
		blend_to = v
		_rebuild()


func _ready() -> void:
	_rebuild()


## True if (x, z) is on the plateau (used by grass_field.gd).
func contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p - Vector2(global_position.x, global_position.z), polygon)


func _rebuild() -> void:
	if not is_inside_tree() or polygon.size() < 3:
		return
	var root: Node3D = preload("res://scripts/clearing/toon.gd").fresh_root(self)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	var zones: Array[Vector3] = []
	for i in 4:
		zones.append(sand_zones[i] if i < sand_zones.size() else Vector3.ZERO)
	mat.set_shader_parameter("sand_zones", zones)
	mat.set_shader_parameter("stain_zone", stain_zone)
	_apply_biomes(mat)
	mi.material_override = mat
	root.add_child(mi)
	_build_colliders(root)


const DEFAULT_BIOME = preload("res://data/biomes/darkwood.tres")


func _apply_biomes(mat: ShaderMaterial) -> void:
	var a: Resource = biome if biome else DEFAULT_BIOME
	var b: Resource = biome_b if biome_b else a
	mat.set_shader_parameter("pal_a", PackedColorArray(a.ground_palette()))
	mat.set_shader_parameter("pal_b", PackedColorArray(b.ground_palette()))
	mat.set_shader_parameter("mode_a", a.ground)
	mat.set_shader_parameter("mode_b", b.ground)
	mat.set_shader_parameter("use_blend", 1.0 if biome_b else 0.0)
	mat.set_shader_parameter("void_color", a.background)
	mat.set_shader_parameter("blend_from", blend_from)
	mat.set_shader_parameter("blend_to", blend_to)


func _signed_area() -> float:
	var a := 0.0
	for i in polygon.size():
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Outward horizontal normal of edge a -> b.
func _outward(a: Vector2, b: Vector2) -> Vector3:
	var d := (b - a).normalized()
	var n := Vector2(d.y, -d.x) if _signed_area() > 0.0 else Vector2(-d.y, d.x)
	return Vector3(n.x, 0.0, n.y)


## Adds a triangle facing `n` (fixes the winding so it is front-facing).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, idx.size(), 3):
		var a := polygon[idx[i]]
		var b := polygon[idx[i + 1]]
		var c := polygon[idx[i + 2]]
		_tri(st, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(c.x, 0, c.y), Vector3.UP)
	# cliff walls; the bottom edge is ragged and leans in a little
	var n := polygon.size()
	for i in n:
		var a := polygon[i]
		var b := polygon[(i + 1) % n]
		var out := _outward(a, b)
		var a_top := Vector3(a.x, 0, a.y)
		var b_top := Vector3(b.x, 0, b.y)
		var a_bot := a_top - out * 0.8 + Vector3(0, -depth * (0.85 + 0.15 * sin(i * 2.3)), 0)
		var b_bot := b_top - out * 0.8 + Vector3(0, -depth * (0.85 + 0.15 * sin((i + 1) * 2.3)), 0)
		var face_n := (out * depth + Vector3(0, 0.8, 0)).normalized()
		_tri(st, a_top, b_top, b_bot, face_n)
		_tri(st, a_top, b_bot, a_bot, face_n)
	return st.commit()


func _build_colliders(root: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	var Toon = preload("res://scripts/clearing/toon.gd")
	# floor: one trimesh for the whole top face
	var faces := PackedVector3Array()
	var idx := Geometry2D.triangulate_polygon(polygon)
	for i in idx:
		faces.append(Vector3(polygon[i].x, 0, polygon[i].y))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	Toon.collider(root, shape)
	# invisible walls along the closed edges
	for i in polygon.size():
		if i in open_edges:
			continue
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var out := _outward(a, b)
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) + 0.6
		var pos := Vector3(mid.x, wall_height * 0.5, mid.y) + out * 0.25
		var angle := rad_to_deg(atan2(-(b - a).y, (b - a).x))
		Toon.collider(root, Toon.box_shape(Vector3(length, wall_height, 0.5)), pos, Vector3(0, angle, 0))
