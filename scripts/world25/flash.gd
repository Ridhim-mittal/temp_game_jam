extends Node3D
## The Ember's Flash (design doc 6.7): a burst of light around Vesper.
##  - for `burst_time` it is the Writer's kind of light: monsters inside
##    `radius` react (on_flash: stun, unfold, surface, flee)
##  - then it lingers as an afterglow for `glow_time`, still making drawn
##    things real out to `radius` (so a flash reveals a far bridge)
##  - it makes noise: searchlights come to look (group "searchlight")
## Lives in the light_3d group so light queries see it.

const RING_SHADER = preload("res://shaders/world25/flash_ring.gdshader")

var radius := 7.0
var burst_time := 0.45
var glow_time := 2.2
## true during the burst (monsters react), false in the afterglow
var monster_light := true

var _age := 0.0
var _light: OmniLight3D
var _ring_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("light_3d")
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.5)
	_light.light_energy = 6.0
	_light.omni_range = radius + 2.0
	_light.position.y = 1.5
	add_child(_light)
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.0, radius * 2.0)
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	var ring := MeshInstance3D.new()
	ring.mesh = q
	ring.material_override = _ring_mat
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	for m in get_tree().get_nodes_in_group("enemy"):
		if m is Node3D and m.has_method("on_flash") and _flat_dist(m.global_position) < radius:
			m.on_flash(global_position)
	get_tree().call_group("searchlight", "hear", global_position)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.25)


func _process(delta: float) -> void:
	_age += delta
	monster_light = _age < burst_time
	_ring_mat.set_shader_parameter("progress", clampf(_age / 0.5, 0.0, 1.0))
	_light.light_energy = lerpf(6.0, 0.6, clampf(_age / 0.4, 0.0, 1.0)) * clampf((burst_time + glow_time - _age) / 0.6, 0.0, 1.0)
	if _age > burst_time + glow_time:
		queue_free()


func lights(point: Vector3) -> bool:
	return _flat_dist(point) < radius * clampf(_age / 0.15, 0.2, 1.0)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
