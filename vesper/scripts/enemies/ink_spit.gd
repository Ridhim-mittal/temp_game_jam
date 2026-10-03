extends CharacterBody2D
## Ink glob spat by crawlers. Flies straight at standing head height:
## duck under it, or slash it out of the air (you can pogo off it too).

const INK := Color(0.05, 0.04, 0.06)

var dead := false
var contact_damage := 1
var lifetime := 3.0
var _time := 0.0


func _ready() -> void:
	collision_layer = 4  # enemy layer: player hurtbox + slashes detect it
	collision_mask = 0
	add_to_group("enemy")
	z_index = 5
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	cs.shape = circle
	add_child(cs)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	if _time > lifetime:
		_pop()
		return
	var motion := velocity * delta
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + motion + motion.normalized() * 7.0, 1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		_pop()
		return
	position += motion
	queue_redraw()


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
	var back := -signf(velocity.x) if velocity.x != 0.0 else -1.0
	for i in 3:
		draw_circle(Vector2(back * (11.0 + i * 7.0), sin(_time * 20.0 + i) * 2.0), 4.0 - i, INK)
	draw_circle(Vector2.ZERO, 7.0 + sin(_time * 30.0) * 0.6, INK)
	draw_circle(Vector2(-2, -2.5), 2.0, Color(1, 1, 1, 0.7))
