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
## Crumpled paper and torn scraps piled along the closed edges (one merged
## mesh; was broken stone): 0 = none, 1 = the usual amount.
@export var rubble := 1.0:
	set(v):
		rubble = v
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
	preload("res://scripts/clearing/toon.gd").merge_when_built(root)  # one mesh per material: far fewer draw calls
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
	if rubble > 0.0:
		_build_rubble(root)
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
	mat.set_shader_parameter("blend_from", blend_from)
	mat.set_shader_parameter("blend_to", blend_to)
	if "runes" in a:
		mat.set_shader_parameter("rune_density", a.runes)
		mat.set_shader_parameter("rune_color", a.rune_color)


## The Writer's rejects along every closed edge: crumpled balls of paper
## and torn scraps lying flat, some hanging over the drop, kept clear of the
## open edges (stairs, bridges, gates). Paper, dimmed and tinted towards the
## biome's light colour.
func _build_rubble(root: Node3D) -> void:
	var Toon = preload("res://scripts/clearing/toon.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = polygon.size() * 97 + int(absf(polygon[0].x) * 13.0)
	var ball := _crumpled_ball()
	var scrap := BoxMesh.new()
	scrap.size = Vector3(1.0, 0.04, 0.75)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := polygon.size()
	var placed := 0
	for i in n:
		if i in open_edges:
			continue
		var a := polygon[i]
		var b := polygon[(i + 1) % n]
		var inward := -_outward(a, b)
		var along := (b - a).normalized()
		var steps := int(a.distance_to(b) / 1.3 * rubble)
		for k in steps:
			if rng.randf() < 0.2:
				continue
			var p2 := a.lerp(b, (k + rng.randf()) / maxf(steps, 1))
			if _near_open_edge(p2, 2.2):
				continue
			# a little pile: two to four balls of paper, the biggest nearest
			# the drop, now and then a torn sheet lying flat among them
			for j in 2 + rng.randi() % 3:
				var size := rng.randf_range(0.25, 0.55) * (1.0 - j * 0.15)
				var q := p2 + along * rng.randf_range(-0.5, 0.5)
				var p := Vector3(q.x, 0.0, q.y) + inward * (rng.randf_range(-0.15, 0.35) + j * 0.3)
				if rng.randf() < 0.25:
					var flat := Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
					st.append_from(scrap, 0, Transform3D(flat.scaled(Vector3.ONE * size * 1.8), p + Vector3(0, 0.02, 0)))
				else:
					var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
					basis = basis.scaled(Vector3(size * rng.randf_range(0.9, 1.25), size * rng.randf_range(0.75, 1.0), size))
					st.append_from(ball, 0, Transform3D(basis, p + Vector3(0, size * 0.35, 0)))
				placed += 1
	if placed == 0:
		return
	var a_biome: Resource = biome if biome else DEFAULT_BIOME
	var color: Color = Color(0.84, 0.81, 0.72).lerp(a_biome.light.linear_to_srgb(), 0.2).darkened(0.12)
	var mi := MeshInstance3D.new()
	mi.name = "Rubble"
	mi.mesh = st.commit()
	mi.material_override = Toon.material(color, {"outline": 0.035, "from_center": 0.0})
	root.add_child(mi)


## A ball of crumpled paper, half a unit across: a sphere with its points
## pushed in and out, every face flat so the creases catch the light.
static func _crumpled_ball() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		# the same push for the same point, so the seams stay closed
		var h := absi(hash(Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0)))) % 1000 / 1000.0
		verts[i] = v * lerpf(0.72, 1.12, h)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(verts[i])
	st.generate_normals()
	return st.commit()


func _near_open_edge(p: Vector2, dist: float) -> bool:
	for i in open_edges:
		if i < 0 or i >= polygon.size():
			continue
		var q := Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % polygon.size()])
		if q.distance_to(p) < dist:
			return true
	return false


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
