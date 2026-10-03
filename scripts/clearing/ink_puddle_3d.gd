extends Node3D
## Sticky ink puddle left by an Inkwell blob: slows the player (run and
## jump) while they stand in it, then dries up after `life` seconds.
## Same idea as the platformer's scripts/world/ink_puddle.gd.

const SPLAT_SHADER = preload("res://shaders/clearing/ink_splat.gdshader")

@export var radius := 0.9
@export var life := 4.0
@export var speed_mult := 0.5
@export var jump_mult := 0.6

var _mat: ShaderMaterial
var _age := 0.0
var _slowing: Node3D


func _ready() -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.4, radius * 2.4)
	_mat = ShaderMaterial.new()
	_mat.shader = SPLAT_SHADER
	_mat.set_shader_parameter("seed", randf() * 50.0)
	_mat.set_shader_parameter("ink", Color(0.12, 0.08, 0.22))
	_mat.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat
	mi.position.y = 0.025
	mi.rotation.y = randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	scale = Vector3.ONE * 0.3
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_age += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var inside := false
	if player and _age < life:
		var d := player.global_position - global_position
		inside = Vector2(d.x, d.z).length() < radius and absf(d.y) < 0.4
	if inside and _slowing == null and player.has_method("set_slowed"):
		player.set_slowed(self, speed_mult, jump_mult)
		_slowing = player
	elif not inside and _slowing:
		_slowing.set_slowed(self, 1.0, 1.0)
		_slowing = null
	if _age > life:
		_mat.set_shader_parameter("alpha", clampf(1.0 - (_age - life) / 0.6, 0.0, 1.0))
		if _age > life + 0.6:
			queue_free()


func _exit_tree() -> void:
	if _slowing and is_instance_valid(_slowing):
		_slowing.set_slowed(self, 1.0, 1.0)
