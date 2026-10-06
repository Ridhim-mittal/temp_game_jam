extends CharacterBody2D
## The Scribbled Beast's slam (scribbled_beast.gd, phase two): a wave of
## jagged ink spikes that runs along the floor away from where it landed.
## Jump over it. Stops at a wall or after `life` seconds.

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const INK := Color(0.04, 0.03, 0.07)
const RIM := Color(0.8, 0.88, 1.0)

var dead := false
var contact_damage := 2.0  # a whole ink bottle
var dir := 1.0
var speed := 560.0
var life := 1.5

var _time := 0.0
var _batch := InkBatch.new()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemy")
	z_index = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(46, 40)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	var step := dir * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -16), global_position + Vector2(step + dir * 26.0, -16), 1)
	if _time > life or not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		_end()
		return
	position.x += step
	queue_redraw()


func on_hit_player() -> void:
	pass  # it rolls on


func _end() -> void:
	dead = true
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0) * 13 + 3
	var fade := clampf((life - _time) / 0.3, 0.0, 1.0)
	# a crest of spikes, tallest at the front, trailing back into a smear
	for i in 9:
		var x := -dir * i * 9.0
		var h := (52.0 - i * 5.0) * rng.randf_range(0.7, 1.1)
		var w := 9.0
		var tip := Vector2(x + dir * rng.randf_range(2, 8), -h)
		var tri := PackedVector2Array([Vector2(x - w, 0), tip, Vector2(x + w, 0)])
		_batch.draw_colored_polygon(tri, Color(INK, fade))
		_batch.draw_polyline(PackedVector2Array([Vector2(x - w, 0), tip, Vector2(x + w, 0)]), Color(RIM, 0.55 * fade), 1.4)
	for i in 4:
		var y := -rng.randf_range(4, 30)
		_batch.draw_line(Vector2(-dir * 20, y), Vector2(-dir * rng.randf_range(60, 110), y + rng.randf_range(-4, 4)), Color(INK, 0.6 * fade), 1.6)
	_batch.flush(self)
