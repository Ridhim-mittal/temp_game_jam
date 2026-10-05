@tool
extends Node3D
## Mossy stone archway built from individual blocks, with a door inside:
## a black cave mouth, or a painted wooden door with an emblem. The arch
## faces +Z (towards the camera).

const Toon = preload("res://scripts/clearing/toon.gd")
const EMBLEM_SHADER = preload("res://shaders/clearing/emblem.gdshader")

enum Door { CAVE, RED, PURPLE }

const DOOR_COLORS := {
	Door.CAVE: Color(0.02, 0.015, 0.03),
	Door.RED: Color(0.72, 0.15, 0.14),
	Door.PURPLE: Color(0.44, 0.2, 0.64),
}

@export var door := Door.CAVE:
	set(v):
		door = v
		_rebuild()
@export var width := 3.2:
	set(v):
		width = v
		_rebuild()
@export var pillar_height := 2.4:
	set(v):
		pillar_height = v
		_rebuild()
@export var stone := Color(0.3, 0.3, 0.33):
	set(v):
		stone = v
		_rebuild()
@export var block := 0.7:
	set(v):
		block = v
		_rebuild()
## Leave the opening walkable (pair it with a DOORWAY gate); otherwise the
## whole arch is solid.
@export var walk_through := false:
	set(v):
		walk_through = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var opts := {"moss": 0.55}
	var half := width * 0.5
	# pillars: stacked blocks, a little uneven
	for side in [-1, 1]:
		var y := 0.0
		var k := 0
		while y < pillar_height - 0.01:
			var h := minf(0.5 + 0.15 * absf(sin(k * 1.7 + side)), pillar_height - y)
			var jitter := 0.05 * sin(k * 3.1 + side * 2.0)
			Toon.part(root, Toon.box(Vector3(block, h, block)), stone.darkened(0.06 * (k % 2)),
				Vector3(side * half + jitter, y + h * 0.5, 0), Vector3(0, jitter * 60.0, 0), opts)
			y += h
			k += 1
	# pointed arch: two arcs of tilted blocks meeting under a keystone
	var segs := 4
	for side in [-1, 1]:
		for i in segs:
			var p0 := _arch_point(float(i) / segs, side, half)
			var p1 := _arch_point(float(i + 1) / segs, side, half)
			var mid := (p0 + p1) * 0.5
			var ang := rad_to_deg(atan2(p1.y - p0.y, p1.x - p0.x))
			Toon.part(root, Toon.box(Vector3(p0.distance_to(p1) + 0.08, block * 0.9, block)),
				stone.darkened(0.05 * (i % 2)), Vector3(mid.x, pillar_height + mid.y, 0), Vector3(0, 0, ang), opts)
	var apex := _arch_point(1.0, 1, half).y
	Toon.part(root, Toon.box(Vector3(block * 0.75, block * 1.15, block * 1.1)), stone.lightened(0.06),
		Vector3(0, pillar_height + apex + block * 0.1, 0), Vector3.ZERO, opts)

	# the opening, filled with the door (or the cave's darkness)
	var inner := half - block * 0.5
	var color: Color = DOOR_COLORS[door]
	var fill := MeshInstance3D.new()
	fill.mesh = _opening_mesh(inner)
	fill.position = Vector3(0, 0, -0.1)
	fill.material_override = Toon.material(color, {"outline": 0.0})
	root.add_child(fill)
	if door == Door.CAVE:
		Toon.part(root, Toon.box(Vector3(inner * 2.0, 0.02, 1.0)), DOOR_COLORS[Door.CAVE],
			Vector3(0, 0.012, 0.25), Vector3.ZERO, {"outline": 0.0})
	else:
		var door_h := pillar_height + _arch_point(1.0, 1, inner).y
		for i in range(1, 4):
			var x := -inner + inner * 2.0 * i / 4.0
			var h := pillar_height + _arch_point(1.0 - absf(x) / inner, 1, inner).y * 0.9
			Toon.part(root, Toon.box(Vector3(0.05, h, 0.03)), color.darkened(0.45),
				Vector3(x, h * 0.5, -0.07), Vector3.ZERO, {"outline": 0.0})
		var q := QuadMesh.new()
		q.size = Vector2(1.15, 1.15)
		var em := MeshInstance3D.new()
		em.mesh = q
		var m := ShaderMaterial.new()
		m.shader = EMBLEM_SHADER
		m.set_shader_parameter("mode", 1 if door == Door.RED else 2)
		em.material_override = m
		em.position = Vector3(0, door_h * 0.55, -0.04)
		root.add_child(em)
	if not Engine.is_editor_hint():
		var total := pillar_height + apex
		if walk_through:
			for side in [-1, 1]:
				Toon.collider(root, Toon.box_shape(Vector3(block, total, block)), Vector3(side * half, total * 0.5, 0))
		else:
			Toon.collider(root, Toon.box_shape(Vector3(width + block, total, block)), Vector3(0, total * 0.5, 0))


## Point on one half of a gothic arch over an opening of half-width `half`:
## t = 0 at the pillar top, t = 1 at the apex. Each half is an arc of a
## circle centred on the opposite side, which gives the pointed top.
static func _arch_point(t: float, side: int, half: float) -> Vector2:
	var c := half * 0.5
	var r := half + c
	var a := t * acos(c / r)
	return Vector2(-side * c + side * r * cos(a), r * sin(a))


## Flat panel in the shape of the opening (pillars up to the arch), facing +Z.
func _opening_mesh(inner: float) -> ArrayMesh:
	var pts := PackedVector2Array([Vector2(-inner, 0), Vector2(inner, 0)])
	for i in 9:
		var p := _arch_point(float(i) / 8.0, 1, inner)
		pts.append(Vector2(p.x, pillar_height + p.y))
	for i in range(7, -1, -1):
		var p := _arch_point(float(i) / 8.0, -1, inner)
		pts.append(Vector2(p.x, pillar_height + p.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		var a := Vector3(pts[idx[i]].x, pts[idx[i]].y, 0)
		var b := Vector3(pts[idx[i + 1]].x, pts[idx[i + 1]].y, 0)
		var c := Vector3(pts[idx[i + 2]].x, pts[idx[i + 2]].y, 0)
		if (c - a).cross(b - a).dot(Vector3.BACK) < 0.0:
			var tmp := b
			b = c
			c = tmp
		for v in [a, b, c]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	return st.commit()
