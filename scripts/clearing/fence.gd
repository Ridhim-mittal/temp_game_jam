@tool
extends Node3D
## An old wrought-iron fence, broken: spear-topped bars from this node's
## origin to `end` (local) on two rails, leaning every which way, some bent
## over, some missing, a rail snapped and sagging, rust creeping over it all.
## Blocks the player along its length. (Was sharpened stakes, then rulers;
## `wood` tints the iron a little.)

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
	Toon.merge_when_built(root)  # one mesh per material: far fewer draw calls
	var length := end.length()
	if length < 0.1:
		return
	var dir := end / length
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	var iron := Color(0.15, 0.14, 0.17).lerp(wood, 0.12)
	var rust := {"outline": 0.018, "moss": 0.3, "moss_color": Color(0.34, 0.22, 0.17)}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(end.x * 31.0 + end.z * 17.0) + int(position.x * 7.0)
	var count := int(length / (spacing * 0.6)) + 1
	for i in count:
		if rng.randf() < 0.15 and i > 0 and i < count - 1:
			continue  # a bar gone
		var p := dir * (i * length / maxf(count - 1, 1))
		var h := height * rng.randf_range(0.85, 1.1)
		var bar := Node3D.new()
		bar.position = p
		bar.rotation_degrees = Vector3(rng.randf_range(-7, 7), yaw, rng.randf_range(-6, 6))
		root.add_child(bar)
		if rng.randf() < 0.15:
			# bent over halfway up
			var low := h * rng.randf_range(0.4, 0.6)
			Toon.part(bar, Toon.box(Vector3(0.05, low, 0.05)), iron, Vector3(0, low * 0.5, 0), Vector3.ZERO, rust)
			var bent := Node3D.new()
			bent.position = Vector3(0, low, 0)
			bent.rotation_degrees = Vector3(rng.randf_range(-70, -40) * (1.0 if rng.randf() < 0.5 else -1.0), 0, rng.randf_range(-20, 20))
			bar.add_child(bent)
			Toon.part(bent, Toon.box(Vector3(0.05, h - low, 0.05)), iron, Vector3(0, (h - low) * 0.5, 0), Vector3.ZERO, rust)
			Toon.part(bent, Toon.prism(Vector3(0.13, 0.2, 0.05)), iron.darkened(0.2), Vector3(0, h - low + 0.1, 0), Vector3.ZERO, rust)
		else:
			Toon.part(bar, Toon.box(Vector3(0.05, h, 0.05)), iron, Vector3(0, h * 0.5, 0), Vector3.ZERO, rust)
			Toon.part(bar, Toon.prism(Vector3(0.13, 0.2, 0.05)), iron.darkened(0.2), Vector3(0, h + 0.1, 0), Vector3.ZERO, rust)
	# the rails: the top one snapped in the middle, each half sagging
	Toon.part(root, Toon.box(Vector3(length + 0.1, 0.06, 0.06)), iron, end * 0.5 + Vector3(0, height * 0.18, 0), Vector3(0, yaw, 1.0), rust)
	for k in 2:
		var half := end * (0.25 + 0.5 * k) + Vector3(0, height * 0.78 - 0.05, 0)
		Toon.part(root, Toon.box(Vector3(length * 0.48, 0.06, 0.06)), iron, half, Vector3(0, yaw, (4.0 if k == 0 else -4.0)), rust)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.box_shape(Vector3(length + 0.3, 2.0, 0.4)), end * 0.5 + Vector3(0, 1, 0), Vector3(0, yaw, 0))
