@tool
extends Node3D
## Scatters grass tufts (one MultiMesh, so hundreds cost one draw call)
## across `area`, only on the island and away from the `keep_clear` circles
## (x, z, radius) such as paths, the altar and doorways.

const TUFT_SHADER = preload("res://shaders/clearing/grass_tuft.gdshader")

@export var island_path: NodePath:
	set(v):
		island_path = v
		_rebuild()
## x, z, width, depth of the scatter rectangle (world space).
@export var area := Rect2(-10, -10, 20, 20):
	set(v):
		area = v
		_rebuild()
@export var count := 300:
	set(v):
		count = v
		_rebuild()
@export var size_range := Vector2(0.6, 1.0):
	set(v):
		size_range = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
@export var keep_clear := PackedVector3Array():
	set(v):
		keep_clear = v
		_rebuild()
@export var base_color := Color(0.18, 0.33, 0.27):
	set(v):
		base_color = v
		_rebuild()
@export var tip_color := Color(0.5, 0.68, 0.45):
	set(v):
		tip_color = v
		_rebuild()
@export var blades := 5:
	set(v):
		blades = v
		_rebuild()
## Take the tuft colours from a biome (scripts/world25/biome.gd) instead
## of base_color / tip_color, multiplied by `biome_tint` (darker reeds).
@export var biome: Resource:
	set(v):
		biome = v
		_rebuild()
@export var biome_tint := Color.WHITE:
	set(v):
		biome_tint = v
		_rebuild()
## Blend into biome_b's tufts past the line blend_from -> blend_to (x, z),
## matching the island's biome seam.
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
## Seconds before cut grass grows back.
@export var regrow_time := 12.0

var _mm: MultiMesh
var _transforms: Array[Transform3D] = []
var _cut_until := {}  # instance index -> time (s) it grows back


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("grass")
	_rebuild()


## Cuts every tuft within `radius` of `center` (world space, ground plane).
## Returns how many were cut. Called by the player's attack.
func cut(center: Vector3, radius: float) -> int:
	if _mm == null:
		return 0
	var local := center - global_position
	var now := Time.get_ticks_msec() / 1000.0
	var cut_count := 0
	for i in _transforms.size():
		if _cut_until.has(i):
			continue
		var o := _transforms[i].origin
		if Vector2(o.x - local.x, o.z - local.z).length() < radius:
			_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), o))
			_cut_until[i] = now + regrow_time
			cut_count += 1
	if cut_count > 0:
		set_process(true)
	return cut_count


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _cut_until.is_empty():
		set_process(false)
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in _cut_until.keys():
		if now >= _cut_until[i]:
			_mm.set_instance_transform(i, _transforms[i])
			_cut_until.erase(i)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root: Node3D = preload("res://scripts/clearing/toon.gd").fresh_root(self)
	var island := get_node_or_null(island_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries := 0
	while transforms.size() < count and tries < count * 20:
		tries += 1
		var p := Vector2(area.position.x + rng.randf() * area.size.x, area.position.y + rng.randf() * area.size.y)
		if island and island.has_method("contains") and not island.contains(p):
			continue
		var blocked := false
		for c in keep_clear:
			if p.distance_to(Vector2(c.x, c.y)) < c.z:
				blocked = true
				break
		if blocked:
			continue
		var s := rng.randf_range(size_range.x, size_range.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s))
		transforms.append(Transform3D(basis, Vector3(p.x - global_position.x, 0.0, p.y - global_position.z)))
		var shade := rng.randf_range(0.82, 1.12)
		colors.append(Color(shade, shade * rng.randf_range(0.95, 1.05), shade))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft_mesh()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	_mm = mm
	_transforms = transforms
	_cut_until.clear()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = TUFT_SHADER
	mat.set_shader_parameter("base_color", biome.tuft_base * biome_tint if biome else base_color)
	mat.set_shader_parameter("tip_color", biome.tuft_tip * biome_tint if biome else tip_color)
	if biome_b:
		mat.set_shader_parameter("use_blend", 1.0)
		mat.set_shader_parameter("blend_from", blend_from)
		mat.set_shader_parameter("blend_to", blend_to)
		mat.set_shader_parameter("base_b", biome_b.tuft_base * biome_tint)
		mat.set_shader_parameter("tip_b", biome_b.tuft_tip * biome_tint)
	mat.set_shader_parameter("blades", blades)
	mmi.material_override = mat
	root.add_child(mmi)


## Two crossed 1 x 1 quads standing on the ground, UV y = 0 at the top.
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var dir := Vector3(1, 0, 0).rotated(Vector3.UP, k * PI * 0.5 + 0.4)
		var a := -dir * 0.5
		var b := dir * 0.5
		var verts := [a, b, b + Vector3.UP, a + Vector3.UP]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_uv(uvs[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(verts[i])
	return st.commit()
