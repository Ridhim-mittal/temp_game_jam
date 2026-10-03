extends Node2D
## Charged attack projectile: a big ink crescent with an ember edge that
## flies forward, pierces enemies (each one is hit once) and splatters on
## walls. Spawned by player.gd when a fully charged attack is released.

const ComicText = preload("res://scripts/effects/comic_text.gd")
const HIT_WORDS := ["KA-SHOOM!", "SPLAT!", "KRAK!"]
const INK := Color(0.05, 0.03, 0.1)
const MASK_WORLD := 1
const MASK_ENEMY := 4

var direction := 1.0
var speed := 1100.0
var max_range := 520.0
var damage := 2
var edge_color := Color(1.0, 0.58, 0.14)
var hit_size := Vector2(56, 44)

var _travelled := 0.0
var _hit: Array = []
var _dying := false


func _ready() -> void:
	z_index = 10
	scale = Vector2(direction, 1.0)


func _physics_process(delta: float) -> void:
	if _dying:
		return
	var step := speed * delta
	position.x += direction * step
	_travelled += step
	_check_hits()
	if _travelled >= max_range or _touching_wall():
		_burst()
	queue_redraw()


func _query(size: Vector2, mask: int) -> Array:
	var shape := RectangleShape2D.new()
	shape.size = size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = mask
	return get_world_2d().direct_space_state.intersect_shape(params, 16)


func _check_hits() -> void:
	for result in _query(hit_size, MASK_ENEMY):
		var target: Object = result.collider
		if target == null or target in _hit or not target.has_method("take_hit"):
			continue
		if "dead" in target and target.dead:
			continue
		_hit.append(target)
		target.take_hit(damage, Vector2(direction, 0), global_position - Vector2(direction * 40.0, 0))
		var pop := ComicText.new()
		pop.text = HIT_WORDS.pick_random()
		pop.color = edge_color
		pop.position = target.global_position + Vector2(0, -44)
		get_tree().current_scene.add_child(pop)
		var cam := get_tree().get_first_node_in_group("camera")
		if cam:
			cam.add_trauma(0.4)


func _touching_wall() -> bool:
	# small core only, so skimming along the floor doesn't stop the wave
	return not _query(Vector2(14, 14), MASK_WORLD).is_empty()


func _burst() -> void:
	_dying = true
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(direction * 1.4, 1.4), 0.12)
	t.tween_property(self, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(queue_free)


func _draw() -> void:
	var fade := clampf(1.0 - _travelled / max_range, 0.25, 1.0)
	var r := 34.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var a := lerpf(-1.25, 1.25, i / 16.0)
		outer.append(Vector2(cos(a), sin(a)) * r)
		inner.append(Vector2(cos(a) * 0.55 - 0.35, sin(a) * 0.85) * r)
	inner.reverse()
	var crescent := outer + inner
	# ember rim, then ink body slightly inside it
	for poly in Geometry2D.offset_polygon(crescent, 4.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, Color(edge_color, fade))
	draw_colored_polygon(crescent, Color(INK, fade))
	# speed lines trailing behind
	for k in 3:
		var y := (k - 1) * 16.0
		var len := 50.0 + 25.0 * (1 - absf(k - 1))
		draw_line(Vector2(-12, y), Vector2(-12 - len, y), Color(edge_color, 0.7 * fade), 3.0)
	# ink droplets flicked off the back
	for k in 4:
		var p := Vector2(-20 - k * 14, sin(_travelled * 0.05 + k * 1.7) * 18.0)
		draw_circle(p, 3.0 - k * 0.5, Color(INK, fade))
