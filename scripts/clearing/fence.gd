@tool
extends Node3D
## Row of sharpened wooden stakes with two crossbars, from this node's
## origin to `end` (local). Blocks the player along its length.

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
@export var wood := Color(0.4, 0.3, 0.27):
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
	for i in count:
		var p := dir * (i * length / maxf(count - 1, 1))
		var h := height * (0.8 + 0.35 * absf(sin(i * 2.7)))
		var tilt := Vector3(6.0 * sin(i * 1.9), yaw, 7.0 * sin(i * 3.3))
		var stake := Node3D.new()
		stake.position = p
		stake.rotation_degrees = tilt
		root.add_child(stake)
		Toon.part(stake, Toon.box(Vector3(0.16, h, 0.16)), wood.darkened(0.08 * (i % 2)), Vector3(0, h * 0.5, 0))
		Toon.part(stake, Toon.prism(Vector3(0.16, 0.32, 0.16)), wood.lightened(0.1), Vector3(0, h + 0.16, 0))
	for y in [height * 0.35, height * 0.7]:
		Toon.part(root, Toon.box(Vector3(length + 0.3, 0.1, 0.08)), wood.darkened(0.15),
			end * 0.5 + Vector3(0, y, 0.1), Vector3(0, yaw, 2.0 * sin(y * 9.0)))
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.box_shape(Vector3(length + 0.3, 2.0, 0.4)), end * 0.5 + Vector3(0, 1, 0), Vector3(0, yaw, 0))
