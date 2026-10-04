extends CharacterBody2D
## Ink blob lobbed by an Inkwell. Hurts on contact, can be slashed out of
## the air, and leaves a slowing ink puddle where it lands on the floor.

const InkPuddle = preload("res://scripts/world/ink_puddle.gd")
const INK := Color(0.07, 0.06, 0.14)

var dead := false
var contact_damage := 14.0  # HP
var gravity := 1400.0
var _time := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemy")
	z_index = 5
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	cs.shape = circle
	add_child(cs)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	velocity.y += gravity * delta
	var motion := velocity * delta
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + motion + motion.normalized() * 9.0, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.normal.y < -0.7:
			_leave_puddle(hit.position)
		_pop()
		return
	if _time > 5.0:
		_pop()
		return
	position += motion
	queue_redraw()


func _leave_puddle(at: Vector2) -> void:
	var puddle := InkPuddle.new()
	puddle.size = Vector2(110, 14)
	puddle.position = at + Vector2(0, -7)
	puddle.z_index = 1
	get_tree().current_scene.add_child.call_deferred(puddle)


func take_hit(_damage: int, _hit_dir: Vector2, _from_pos: Vector2) -> void:
	_pop()


func on_hit_player() -> void:
	_pop()


func _pop() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(2.2, 0.6), 0.15)
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(queue_free)


func _draw() -> void:
	var back := -velocity.normalized()
	for i in 3:
		draw_circle(back * (10.0 + i * 7.0), 5.0 - i * 1.3, INK)
	draw_circle(Vector2.ZERO, 9.0 + sin(_time * 30.0) * 0.6, INK)
	draw_circle(Vector2(-3, -3), 2.5, Color(1, 1, 1, 0.7))
