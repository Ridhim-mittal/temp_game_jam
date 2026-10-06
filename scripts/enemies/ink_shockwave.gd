extends Area2D
## Ground shockwave from the Ink Blot's slam: a crest of ink rolling along
## the floor in `direction`. Jump over it. Fades out after `range_px` or at a
## wall. Origin = on the floor.

const INK := Color(0.06, 0.04, 0.09)
const SHEEN := Color(0.44, 0.38, 0.62)

var direction := 1.0
var damage := 3.0
var speed := 430.0
var range_px := 700.0
var dead := false
var _travelled := 0.0
var _life := 1.0


func get_damage() -> float:
	return damage


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemy")
	z_index = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 34)
	cs.shape = r
	cs.position = Vector2(0, -17)
	add_child(cs)


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -12), global_position + Vector2(step + direction * 20.0, -12), 1)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		_travelled = range_px
	position.x += step
	_travelled += absf(step)
	if _travelled >= range_px:
		_life -= delta * 5.0
		if is_in_group("enemy"):
			remove_from_group("enemy")
		if _life <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var a := _life
	var h := 34.0 * (1.0 - 0.4 * _travelled / range_px)
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var x := lerpf(-34.0, 26.0, t) * direction
		var y := -h * sin(t * PI) * (1.0 + 0.15 * sin(t * 12.0 + _travelled * 0.05))
		pts.append(Vector2(x, y))
	draw_colored_polygon(pts, Color(INK, a))
	draw_polyline(pts, Color(SHEEN, a), 2.0)
	for k in 3:
		var p := Vector2(direction * (10.0 - k * 14.0), -h - 8.0 - k * 6.0)
		draw_circle(p, 4.0 - k, Color(INK, a))
