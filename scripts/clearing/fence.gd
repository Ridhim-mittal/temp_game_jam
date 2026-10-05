@tool
extends Node3D
## Wrought-iron railings with spear tips and two rails, from this node's
## origin to `end` (local), a heavier gate post at each end. Some bars lean
## or are missing. Blocks the player along its length.

const Toon = preload("res://scripts/clearing/toon.gd")

@export var end := Vector3(6, 0, 0):
	set(v):
		end = v
		_rebuild()
@export var spacing := 0.32:
	set(v):
		spacing = v
		_rebuild()
@export var height := 1.5:
	set(v):
		height = v
		_rebuild()
## The iron's colour (the name is left over from the wooden fence).
@export var wood := Color(0.09, 0.09, 0.11):
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
		if i > 0 and i < count - 1 and absf(sin(i * 7.31)) > 0.93:
			continue  # a bar gone missing
		var p := dir * (i * length / maxf(count - 1, 1))
		var post := i == 0 or i == count - 1
		var h := height * (1.25 if post else 1.0)
		var bar := Node3D.new()
		bar.position = p
		bar.rotation_degrees = Vector3(4.0 * sin(i * 1.9), yaw, 5.0 * sin(i * 3.3) * (0.0 if post else 1.0))
		root.add_child(bar)
		if post:
			Toon.part(bar, Toon.box(Vector3(0.2, h, 0.2)), wood, Vector3(0, h * 0.5, 0))
			Toon.part(bar, Toon.sphere(0.16, 8, 5), wood, Vector3(0, h + 0.1, 0), Vector3.ZERO, {"outline": 0.03})
		else:
			Toon.part(bar, Toon.cylinder(0.025, 0.03, h, 6), wood, Vector3(0, h * 0.5, 0), Vector3.ZERO, {"outline": 0.025})
			Toon.part(bar, Toon.prism(Vector3(0.12, 0.2, 0.05)), wood, Vector3(0, h + 0.08, 0), Vector3.ZERO, {"outline": 0.025})
	for y in [height * 0.18, height * 0.82]:
		Toon.part(root, Toon.box(Vector3(length, 0.05, 0.05)), wood, end * 0.5 + Vector3(0, y, 0), Vector3(0, yaw, 0), {"outline": 0.025})
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.box_shape(Vector3(length + 0.3, 2.0, 0.4)), end * 0.5 + Vector3(0, 1, 0), Vector3(0, yaw, 0))
