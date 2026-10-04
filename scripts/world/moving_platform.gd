@tool
extends AnimatableBody2D
## Steel girder that slides back and forth along `travel` and carries
## whatever stands on it (AnimatableBody2D + sync_to_physics).
## Motion is a smooth ping-pong (eased at both ends).

const INK := Color(0.05, 0.03, 0.1)
const HAZARD := Color(1.0, 0.86, 0.2)

@export var size := Vector2(140, 20):
	set(value):
		size = value
		queue_redraw()
## Offset from the start position to the far end.
@export var travel := Vector2(300, 0):
	set(value):
		travel = value
		queue_redraw()
## Seconds for a full there-and-back trip.
@export var period := 4.0
## 0..1 where in the trip it starts.
@export_range(0.0, 1.0) var phase := 0.0
@export var steel := Color(0.48, 0.55, 0.75)

var _origin := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	collision_layer = 1
	sync_to_physics = true
	_origin = position
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var t := 0.5 - 0.5 * cos(TAU * (_time / maxf(period, 0.1) + phase))  # 0..1..0
	position = _origin + travel * t


func _draw() -> void:
	if Engine.is_editor_hint():
		# show the path in the editor
		draw_dashed_line(Vector2.ZERO, travel, Color(HAZARD, 0.7), 2.0, 10.0)
		draw_rect(Rect2(travel - size * 0.5, size), Color(HAZARD, 0.25), false, 2.0)
	var r := Rect2(-size * 0.5, size)
	draw_rect(r.grow(2.5), INK)
	draw_rect(r, steel)
	draw_rect(Rect2(r.position, Vector2(size.x, 4)), steel.lightened(0.3))
	draw_rect(Rect2(r.position + Vector2(0, size.y - 5), Vector2(size.x, 5)), steel.darkened(0.3))
	# hazard-striped end caps + rivets
	for end in [r.position.x, r.end.x - 16.0]:
		draw_rect(Rect2(end, r.position.y, 16, size.y), INK)
		for k in 3:
			draw_colored_polygon(PackedVector2Array([Vector2(end + k * 6, r.end.y), Vector2(end + k * 6 + 3, r.position.y),
				Vector2(end + k * 6 + 6, r.position.y), Vector2(end + k * 6 + 3, r.end.y)]), HAZARD)
	var x := r.position.x + 28.0
	while x < r.end.x - 24.0:
		draw_circle(Vector2(x, 0), 2.0, steel.darkened(0.45))
		x += 22.0
