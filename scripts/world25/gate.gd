@tool
extends Node3D
## Gate between the Gutter's rooms. Sealed with a
## glowing red X while monsters remain; when the room is cleared (room.gd
## calls open()) the X fades, and walking out through the gate ink-wipes to
## `target_scene`, arriving at the gate there whose gate_id is `target_gate`.
##
## The gate's local -Z points out of the room. Styles:
##   THRESHOLD  a carved stone step jutting out over the void at a room
##              edge, with lanterns (leave a gap in the island edge for it)
##   DOORWAY    an invisible trigger for walking into an archway (the cave)

const Toon = preload("res://scripts/clearing/toon.gd")
const MARKS_SHADER = preload("res://shaders/world25/gate_marks.gdshader")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")

enum Style { THRESHOLD, DOORWAY }

@export var gate_id := "north"
@export_file("*.tscn") var target_scene := ""
@export var target_gate := "south"
@export var style := Style.THRESHOLD:
	set(v):
		style = v
		_rebuild()
@export var width := 3.6:
	set(v):
		width = v
		_rebuild()
@export var stone := Color(0.42, 0.4, 0.44):
	set(v):
		stone = v
		_rebuild()
@export var lantern_color := Color(1.0, 0.25, 0.15):
	set(v):
		lantern_color = v
		_rebuild()
## Open from the start (no seal).
@export var always_open := false

var is_open := false

var _x_mat: ShaderMaterial
var _wall_shape: CollisionShape3D
var _used := false

const STEP_DEPTH := 2.4


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("gate")
	_rebuild()
	if always_open and not Engine.is_editor_hint():
		open(false)


## Where a player arriving through this gate appears (inside the room).
func arrival_point() -> Vector3:
	return global_transform * Vector3(0, 0.05, 2.0 if style == Style.THRESHOLD else 1.6)


func open(animate := true) -> void:
	if is_open:
		return
	is_open = true
	if _wall_shape:
		_wall_shape.set_deferred("disabled", true)
	if _x_mat == null:
		return
	if not animate:
		_x_mat.set_shader_parameter("seal", 0.0)
		return
	var t := create_tween()
	t.tween_method(func(v: float): _x_mat.set_shader_parameter("seal", v), 1.0, 0.0, 0.6)
	if target_scene != "":
		Fx.burst(get_tree(), global_transform * Vector3(0, 1.0, -0.4), lantern_color, 14, 3.0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var half := width * 0.5
	if style == Style.THRESHOLD:
		# carved step jutting out of the room, a darker lip at the outer end
		Toon.part(root, Toon.box(Vector3(width, 0.5, STEP_DEPTH)), stone, Vector3(0, -0.25, -STEP_DEPTH * 0.5),
			Vector3.ZERO, {"tile": 1.2, "moss": 0.15})
		Toon.part(root, Toon.box(Vector3(width + 0.3, 0.6, 0.35)), stone.darkened(0.25),
			Vector3(0, -0.28, -STEP_DEPTH + 0.1))
		_marks(root, 0, Vector2(width * 0.85, 0.6), Vector3(0, 0.012, -0.9), Vector3(-90, 0, 0), Color(0.86, 0.82, 0.76))
		for side in [-1, 1]:
			_lantern(root, Vector3(side * (half + 0.35), 0, -0.2))
	# the seal: a big red X standing in the gap
	_x_mat = _marks(root, 1, Vector2(width * 0.6, width * 0.6), Vector3(0, width * 0.3 + 0.2, -0.3 if style == Style.THRESHOLD else 0.2),
		Vector3.ZERO, Color(1.0, 0.16, 0.1))
	_x_mat.set_shader_parameter("billboard", 1.0)
	if is_open:
		_x_mat.set_shader_parameter("seal", 0.0)
	if Engine.is_editor_hint():
		return
	if style == Style.THRESHOLD:
		var floor_body := Toon.collider(root, Toon.box_shape(Vector3(width, 0.5, STEP_DEPTH)), Vector3(0, -0.25, -STEP_DEPTH * 0.5))
		floor_body.name = "Step"
		for side in [-1, 1]:
			Toon.collider(root, Toon.box_shape(Vector3(0.4, 3.0, STEP_DEPTH)), Vector3(side * (half + 0.2), 1.5, -STEP_DEPTH * 0.5))
	var wall := Toon.collider(root, Toon.box_shape(Vector3(width, 3.0, 0.4)), Vector3(0, 1.5, 0.1 if style == Style.THRESHOLD else 0.5))
	_wall_shape = wall.get_child(0)
	_wall_shape.disabled = is_open


func _marks(root: Node3D, mode: int, size: Vector2, pos: Vector3, rot: Vector3, color: Color) -> ShaderMaterial:
	var q := QuadMesh.new()
	q.size = size
	var mat := ShaderMaterial.new()
	mat.shader = MARKS_SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("color", color)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mat


func _lantern(root: Node3D, pos: Vector3) -> void:
	Toon.part(root, Toon.box(Vector3(0.3, 1.1, 0.3)), stone.darkened(0.15), pos + Vector3(0, 0.55, 0), Vector3.ZERO, {"moss": 0.3})
	Toon.part(root, Toon.cylinder(0.24, 0.14, 0.2, 8), Color(0.16, 0.13, 0.18), pos + Vector3(0, 1.2, 0))
	Toon.billboard(root, FLAME_SHADER, Vector2(0.6, 0.8), pos + Vector3(0, 1.6, 0),
		{"outer_color": lantern_color, "core_color": lantern_color.lightened(0.5)})
	if not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.light_color = lantern_color
		l.light_energy = 1.2
		l.omni_range = 3.5
		l.position = pos + Vector3(0, 1.6, 0)
		root.add_child(l)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_open or _used or target_scene == "":
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or ("dead" in player and player.dead):
		return
	var local := to_local(player.global_position)
	var through := -1.3 if style == Style.THRESHOLD else -0.2
	if absf(local.x) < width * 0.5 + 0.2 and local.z < through and local.z > -STEP_DEPTH - 1.0:
		_used = true
		var world := get_node_or_null("/root/World25")
		if world:
			world.go(target_scene, target_gate)
