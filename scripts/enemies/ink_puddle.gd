extends Area2D
## A splat of the Ink Blot's ink on the floor: doesn't hurt, but Vesper runs
## and jumps slower while standing in it. Dries up after `lifetime`.
## Origin = on the floor, centre of the puddle.

const INK := Color(0.06, 0.04, 0.09)
const SHEEN := Color(0.44, 0.38, 0.62)

@export var width := 120.0
@export var lifetime := 5.0
@export_range(0.1, 1.0) var speed_mult := 0.5
@export_range(0.1, 1.0) var jump_mult := 0.7

var _age := 0.0
var _inside: Array = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	z_index = -1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 14)
	cs.shape = r
	cs.position = Vector2(0, -7)
	add_child(cs)
	body_entered.connect(_grab)
	body_exited.connect(_release)


func _grab(b: Node) -> void:
	if b.has_method("set_slowed"):
		b.set_slowed(self, speed_mult, jump_mult)
		_inside.append(b)


func _release(b: Node) -> void:
	if b.has_method("set_slowed"):
		b.set_slowed(self, 1.0, 1.0)
	_inside.erase(b)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		for b in _inside.duplicate():
			_release(b)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := clampf((lifetime - _age) / 0.8, 0.0, 1.0)
	var grow := minf(_age / 0.2, 1.0)
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(Vector2(cos(t) * width * 0.5 * grow * (1.0 + 0.08 * sin(i * 2.7)), sin(t) * 7.0 - 2.0))
	draw_colored_polygon(pts, Color(INK, a))
	draw_arc(Vector2(-width * 0.15, -4), width * 0.12, PI * 1.1, PI * 1.6, 6, Color(SHEEN, a), 2.0)
