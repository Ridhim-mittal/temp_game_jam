extends ColorRect
## The Gutter's darkness: a full-screen layer (darkness.gdshader) that sinks
## everything into near-black except pools of light. room.gd puts it under
## the comic overlay and the HUD. Every frame it gathers the lights and
## projects them to the screen:
##   - Vesper's Ember (its glow radius grows and shrinks with his fuel)
##   - lit braziers / lanterns (group "lantern", `lit`, `light_radius`)
##   - open gates (group "gate"), the Haunting Lamp's circle ("haunt_lamp")
##     and searchlights ("searchlight": `spot`, `spot_radius`)
##   - anything in group "glow" with a `glow_radius` property or meta
##     (candles, the altar, the background's skull heaps), so props can
##     carve their own pools

const SHADER = preload("res://shaders/world25/darkness.gdshader")
const MAX_HOLES := 32

## 0 = off .. 1 = black outside the light.
@export var darkness := 0.78
@export var tint := Color(0.02, 0.015, 0.035)
## The pool round Vesper is this much bigger than his Ember's glow.
@export var ember_scale := 1.5

var _mat: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var holes: Array[Vector4] = []
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player") as Node3D
	if player and "smooth_position" in player:
		var r: float = player.glow_radius() * ember_scale if player.has_method("glow_radius") else 4.0
		_add(holes, cam, player.smooth_position, r, 1.0)
	for l in tree.get_nodes_in_group("lantern"):
		if l is Node3D and l.is_visible_in_tree() and l.get("lit"):
			_add(holes, cam, l.global_position, l.light_radius * 1.35, 0.95)
	for g in tree.get_nodes_in_group("gate"):
		if g is Node3D and g.is_open:
			_add(holes, cam, g.global_transform * Vector3(0, 0, -0.8), 3.2, 0.85)
	for s in tree.get_nodes_in_group("searchlight"):
		if s is Node3D and "spot" in s:
			var at: Vector3 = s.get("_prev_spot").lerp(s.spot, Engine.get_physics_interpolation_fraction()) if "_prev_spot" in s else s.spot
			_add(holes, cam, at, s.spot_radius * 1.7, 1.0)
	for n in tree.get_nodes_in_group("glow"):
		if n is Node3D and n.is_visible_in_tree():
			var gr: float = n.get_meta("glow_radius", 0.0)
			if gr <= 0.0 and "glow_radius" in n:
				gr = n.glow_radius
			if gr > 0.0:
				_add(holes, cam, n.global_position, gr, 0.8)
	var packed := PackedVector4Array()
	for h in holes:
		packed.append(h)
	_mat.set_shader_parameter("holes", packed)
	_mat.set_shader_parameter("count", holes.size())
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("darkness", darkness)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("squash", clampf(sin(-cam.global_rotation.x), 0.2, 1.0))


## Projects a ground circle (world centre, world radius) to a screen hole.
func _add(holes: Array[Vector4], cam: Camera3D, at: Vector3, radius: float, strength: float) -> void:
	if holes.size() >= MAX_HOLES or cam.is_position_behind(at):
		return
	var c := cam.unproject_position(at)
	var edge := cam.unproject_position(at + cam.global_basis.x * radius)
	var r := c.distance_to(edge)
	# skip pools that are entirely off screen
	if c.x < -r or c.y < -r or c.x > size.x + r or c.y > size.y + r:
		return
	holes.append(Vector4(c.x, c.y, r, strength))
