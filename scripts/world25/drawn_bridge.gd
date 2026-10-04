@tool
extends Node3D
## A drawn bridge (light rule 1): a walkway of planks, each solid and in
## colour only while some light reaches it (the Ember's glow, a Flash's
## afterglow, a lit lantern, a brazier, the searchlight). Unlit planks are
## pale dashed ghosts you fall through. A plank flickers for `warn_time`
## before vanishing, and never re-solidifies inside the player.
## The bridge runs from this node along local -Z for `length`; its side
## rails are always solid, so you only fall through missing planks.

const Toon = preload("res://scripts/clearing/toon.gd")
const Light = preload("res://scripts/world25/light.gd")
const GHOST_SHADER = preload("res://shaders/world25/drawn_ghost.gdshader")

@export var length := 8.0:
	set(v):
		length = v
		_rebuild()
@export var width := 3.0:
	set(v):
		width = v
		_rebuild()
@export var plank := 1.0:
	set(v):
		plank = v
		_rebuild()
@export var wood := Color(0.62, 0.42, 0.3):
	set(v):
		wood = v
		_rebuild()
## Seconds a plank flickers after losing light before it vanishes.
@export var warn_time := 0.3
## Show every plank solid in the editor (to place the bridge).
@export var preview_solid := false:
	set(v):
		preview_solid = v
		_rebuild()

enum { SOLID, WARN, GHOST }

var _planks: Array = []  # [{body, shape, solid_mesh, ghost_mesh, state, timer, center}]
var _player: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	_planks.clear()
	var n := maxi(int(round(length / plank)), 1)
	var step := length / n
	var size := Vector3(width, 0.3, step * 0.94)
	var ghost_mat := ShaderMaterial.new()
	ghost_mat.shader = GHOST_SHADER
	ghost_mat.set_shader_parameter("half_size", size * 0.5)
	for i in n:
		var center := Vector3(0, -0.15, -(i + 0.5) * step)
		var solid := Toon.part(root, Toon.box(size), wood.darkened(0.08 * (i % 2)), center, Vector3(0, 0, (i % 3 - 1) * 1.5),
			{"tile": 0.5, "line": wood.darkened(0.5)})
		var ghost := MeshInstance3D.new()
		ghost.mesh = Toon.box(size)
		ghost.material_override = ghost_mat
		ghost.position = center
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ghost)
		var body: StaticBody3D = null
		var shape: CollisionShape3D = null
		if not Engine.is_editor_hint():
			body = Toon.collider(root, Toon.box_shape(Vector3(width, 0.3, step)), center)
			body.add_to_group("drawn")
			shape = body.get_child(0)
		var show_solid := preview_solid and Engine.is_editor_hint()
		solid.visible = show_solid
		ghost.visible = not show_solid
		if shape:
			shape.disabled = true
		_planks.append({"shape": shape, "solid": solid, "ghost": ghost, "state": GHOST, "timer": 0.0,
			"center": center, "half": Vector3(width * 0.5, 0.6, step * 0.5)})
	# rope rails on both sides: posts and a sagging rope, always solid
	for side in [-1, 1]:
		var x: float = side * (width * 0.5 + 0.12)
		for k in n + 1:
			Toon.part(root, Toon.box(Vector3(0.14, 0.9, 0.14)), wood.darkened(0.3), Vector3(x, 0.3, -k * step), Vector3.ZERO)
		Toon.part(root, Toon.box(Vector3(0.06, 0.06, length)), Color(0.85, 0.78, 0.6), Vector3(x, 0.62, -length * 0.5), Vector3.ZERO,
			{"outline": 0.02})
		if not Engine.is_editor_hint():
			Toon.collider(root, Toon.box_shape(Vector3(0.3, 3.0, length)), Vector3(x, 1.5, -length * 0.5))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_player = get_tree().get_first_node_in_group("player")
	for p in _planks:
		var lit := Light.is_lit(get_tree(), to_global(p.center))
		match p.state:
			GHOST:
				if lit and not _player_inside(p):
					_set_state(p, SOLID)
			SOLID:
				if not lit:
					_set_state(p, WARN)
					p.timer = warn_time
			WARN:
				if lit:
					_set_state(p, SOLID)
				else:
					p.timer -= delta
					# flicker between solid and ghost as a warning
					var on := fmod(p.timer, 0.08) < 0.04
					p.solid.visible = on
					p.ghost.visible = not on
					if p.timer <= 0.0:
						_set_state(p, GHOST)


func _set_state(p: Dictionary, state: int) -> void:
	p.state = state
	var solid := state != GHOST
	p.solid.visible = solid
	p.ghost.visible = not solid
	p.shape.set_deferred("disabled", not solid)


## Safe re-solidify: never close a plank around the player's feet.
func _player_inside(p: Dictionary) -> bool:
	if _player == null:
		return false
	var local: Vector3 = to_local(_player.global_position) - p.center
	return absf(local.x) < p.half.x and absf(local.z) < p.half.z and local.y < 0.0 and local.y > -p.half.y * 3.0


## Number of planks solid right now (tests and puzzles).
func solid_count() -> int:
	var c := 0
	for p in _planks:
		if p.state != GHOST:
			c += 1
	return c
