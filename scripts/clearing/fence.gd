@tool
extends Node3D
## A row of the Writer's wooden rulers stood on end, from this node's origin
## to `end` (local), with two more laid across them as rails; every ruler is
## marked with ink ticks (one merged mesh). Blocks the player along its
## length. (Was sharpened stakes; `wood` is the rulers' wood.)

const Toon = preload("res://scripts/clearing/toon.gd")

@export var end := Vector3(6, 0, 0):
	set(v):
		end = v
		_rebuild()
@export var spacing := 0.6:
	set(v):
		spacing = v
		_rebuild()
@export var height := 1.3:
	set(v):
		height = v
		_rebuild()
@export var wood := Color(0.62, 0.5, 0.34):
	set(v):
		wood = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var length := end.length()
	if length < 0.1:
		return
	var dir := end / length
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	var count := int(length / spacing) + 1
	var ticks := SurfaceTool.new()
	ticks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tick := BoxMesh.new()
	tick.size = Vector3(1, 1, 1)
	for i in count:
		var p := dir * (i * length / maxf(count - 1, 1))
		var h := height * (0.85 + 0.3 * absf(sin(i * 2.7)))
		var tilt := Vector3(5.0 * sin(i * 1.9), yaw, 6.0 * sin(i * 3.3))
		var ruler := Node3D.new()
		ruler.position = p
		ruler.rotation_degrees = tilt
		root.add_child(ruler)
		Toon.part(ruler, Toon.box(Vector3(0.22, h, 0.05)), wood.darkened(0.06 * (i % 2)), Vector3(0, h * 0.5, 0), Vector3.ZERO,
			{"outline": 0.025})
		# ticks up one edge of both faces, a long one every fifth
		var k := 0
		var y := 0.12
		while y < h - 0.04:
			var w := 0.11 if k % 5 == 0 else 0.055
			for face in [-1.0, 1.0]:
				ticks.append_from(tick, 0, ruler.transform * Transform3D(Basis.from_scale(Vector3(w, 0.014, 0.01)),
					Vector3(-0.11 + w * 0.5, y, face * 0.026)))
			y += 0.08
			k += 1
	for y in [height * 0.35, height * 0.7]:
		var rail := Node3D.new()
		rail.position = end * 0.5 + Vector3(0, y, 0) + Vector3(dir.z, 0, -dir.x) * -0.08
		rail.rotation_degrees = Vector3(0, yaw, 2.0 * sin(y * 9.0))
		root.add_child(rail)
		var rail_len := length + 0.3
		Toon.part(rail, Toon.box(Vector3(rail_len, 0.16, 0.045)), wood.lightened(0.06), Vector3.ZERO, Vector3.ZERO, {"outline": 0.02})
		var x := -rail_len * 0.5 + 0.1
		var k := 0
		while x < rail_len * 0.5 - 0.05:
			var tall := 0.07 if k % 5 == 0 else 0.035
			for face in [-1.0, 1.0]:
				ticks.append_from(tick, 0, rail.transform * Transform3D(Basis.from_scale(Vector3(0.012, tall, 0.01)),
					Vector3(x, 0.08 - tall * 0.5, face * 0.024)))
			x += 0.1
			k += 1
	var mi := MeshInstance3D.new()
	mi.mesh = ticks.commit()
	mi.material_override = Toon.material(Color(0.08, 0.06, 0.1), {"outline": 0.0})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.box_shape(Vector3(length + 0.3, 2.0, 0.4)), end * 0.5 + Vector3(0, 1, 0), Vector3(0, yaw, 0))
