extends Area2D
## A glob of ink lobbed by the Ink Blot: arcs under gravity, hurts on
## contact, and splats into a slowing ink puddle (ink_puddle.gd) on the floor.

const INK := Color(0.06, 0.04, 0.09)
const Puddle = preload("res://scripts/enemies/ink_puddle.gd")

var velocity := Vector2.ZERO
var damage := 8.0
var dead := false
var _time := 0.0


func get_damage() -> float:
	return damage


func on_hit_player() -> void:
	queue_free()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemy")
	z_index = 5
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	cs.shape = c
	add_child(cs)


func _physics_process(delta: float) -> void:
	_time += delta
	velocity.y += 1500.0 * delta
	var motion := velocity * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion + motion.normalized() * 10.0, 1 | 16)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		Sfx.play("ink_splat", -6.0, 1.2)
		if hit.normal.y < -0.5:
			var p := Puddle.new()
			p.position = hit.position
			get_tree().current_scene.add_child(p)
		queue_free()
		return
	position += motion
	if _time > 4.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var stretch := clampf(velocity.length() / 900.0, 0.0, 0.6)
	draw_set_transform(Vector2.ZERO, velocity.angle(), Vector2(1.0 + stretch, 1.0 - stretch * 0.4))
	draw_circle(Vector2.ZERO, 11.0, INK)
	draw_circle(Vector2(-3, -3), 3.0, Color(0.44, 0.38, 0.62))
	draw_set_transform(Vector2.ZERO)
