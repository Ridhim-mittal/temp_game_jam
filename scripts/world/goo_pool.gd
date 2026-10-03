@tool
extends Area2D
## Sticky comic glue puddle: doesn't hurt, but while the player stands in it
## they run slower and jump lower (dash still works, as the escape).
## Lime green with an ink outline so it never reads as a hazard (yellow =
## damage, green = slow). Place it with its bottom edge on the ground.

const ComicText = preload("res://scripts/effects/comic_text.gd")
const INK := Color(0.05, 0.03, 0.1)

@export var size := Vector2(200, 16):
	set(value):
		size = value
		queue_redraw()
@export_range(0.1, 1.0) var speed_mult := 0.45
@export_range(0.1, 1.0) var jump_mult := 0.65
@export var goo_color := Color(0.58, 0.95, 0.28)
@export var goo_dark := Color(0.22, 0.6, 0.18)

var _time := 0.0
var _bubbles: Array = []
var _bubble_timer := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_slowed"):
		body.set_slowed(self, speed_mult, jump_mult)
		_splash_text(body.global_position + Vector2(0, -40))


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_slowed"):
		body.set_slowed(self, 1.0, 1.0)


func _splash_text(pos: Vector2) -> void:
	var pop := ComicText.new()
	pop.text = ["SPLORCH!", "GLOOP!", "SQUELCH!"].pick_random()
	pop.color = goo_color
	pop.font_size = 24
	pop.position = pos
	get_tree().current_scene.add_child(pop)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = randf_range(0.25, 0.7)
		_bubbles.append({"x": randf_range(-0.45, 0.45) * size.x, "age": 0.0, "r": randf_range(3.0, 6.0)})
	for b in _bubbles:
		b.age += delta
	_bubbles = _bubbles.filter(func(b): return b.age < 1.0)
	queue_redraw()


func _surface_y(x: float) -> float:
	var half := size * 0.5
	var edge := clampf(1.0 - absf(x) / half.x, 0.0, 1.0)
	# rounded puddle edges + slow wobbling surface
	return half.y - size.y * sqrt(edge) + sin(x * 0.08 + _time * 2.5) * 1.5 * edge


func _draw() -> void:
	var half := size * 0.5
	var surface := PackedVector2Array()
	var steps := maxi(int(size.x / 8.0), 4)
	for i in steps + 1:
		var x := -half.x + size.x * i / steps
		surface.append(Vector2(x, _surface_y(x)))
	var body := surface.duplicate()
	body.append(Vector2(half.x, half.y))
	body.append(Vector2(-half.x, half.y))
	for poly in Geometry2D.offset_polygon(body, 3.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(body, goo_dark)
	# lighter top layer = depth; glossy highlight streaks
	var top := surface.duplicate()
	for i in range(steps, -1, -1):
		top.append(Vector2(surface[i].x, minf(surface[i].y + size.y * 0.35, half.y)))
	draw_colored_polygon(top, goo_color)
	for k in 2:
		var hx := -half.x * 0.5 + k * half.x * 0.7
		draw_line(Vector2(hx, _surface_y(hx) + 3), Vector2(hx + 18, _surface_y(hx + 18) + 3), Color(1, 1, 1, 0.8), 2.0)
	# ink base just below the ground line: covers the wader's outline
	draw_rect(Rect2(-half.x, half.y - 1.0, size.x, 10.0), INK)
	# drips over the front edge
	for k in int(size.x / 50.0):
		var dx := -half.x + 25.0 + k * 50.0
		var drip := 3.0 + 2.0 * sin(_time * 1.7 + k * 2.0)
		draw_circle(Vector2(dx, half.y + drip * 0.5), 2.5, goo_dark)
	# bubbles rise, swell and pop into a ring
	for b in _bubbles:
		var p := Vector2(b.x, _surface_y(b.x) + 2.0)
		if b.age < 0.8:
			var r: float = b.r * (b.age / 0.8)
			draw_circle(p - Vector2(0, r * 0.6), r + 1.5, INK)
			draw_circle(p - Vector2(0, r * 0.6), r, goo_color.lightened(0.25))
			draw_circle(p - Vector2(r * 0.3, r * 1.0), r * 0.25, Color.WHITE)
		else:
			var t: float = (b.age - 0.8) / 0.2
			draw_arc(p - Vector2(0, b.r), b.r * (1.0 + t), 0, TAU, 12, Color(INK, 1.0 - t), 2.0)
