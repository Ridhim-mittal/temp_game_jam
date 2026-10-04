extends Node3D
## Ink Wave (Blade skill): a crescent of ink flung forward by the combo
## finisher, skimming the ground. It cuts every monster it passes once and
## splashes against anything solid. The 2.5D cousin of the platformer's
## charged ink wave (scripts/effects/ink_wave.gd).

const SLASH_SHADER = preload("res://shaders/clearing/slash_arc.gdshader")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")

var direction := Vector3.RIGHT
var speed := 11.0
var max_range := 6.5
var damage := 2
var rim := Color(1.0, 0.58, 0.14)

var _travelled := 0.0
var _hit: Array = []
var _mat: ShaderMaterial


func _ready() -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(2.6, 2.6)
	_mat = ShaderMaterial.new()
	_mat.shader = SLASH_SHADER
	_mat.set_shader_parameter("progress", 0.5)
	_mat.set_shader_parameter("arc_deg", 120.0)
	_mat.set_shader_parameter("rim", rim)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat
	mi.position = Vector3(0, 0.6, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	rotation.y = atan2(-direction.z, direction.x)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var from := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + direction * (step + 0.3), 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		_burst()
		return
	global_position += direction * step
	_travelled += step
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.5, 0))
	params.collision_mask = 4
	for r in get_world_3d().direct_space_state.intersect_shape(params, 8):
		var t: Object = r.collider
		if t and t.has_method("take_hit") and not t in _hit and not ("dead" in t and t.dead):
			_hit.append(t)
			if t.take_hit(damage, direction, false) != false:
				Fx.pop_text(get_tree(), t.global_position + Vector3(0, 1.3, 0), "SPLASH!", rim, 30)
	_mat.set_shader_parameter("progress", 0.5 + 0.4 * _travelled / max_range)
	if _travelled >= max_range:
		_burst()


func _burst() -> void:
	set_physics_process(false)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.6, 0), Color(0.08, 0.05, 0.12), 12, 3.0)
	queue_free()
