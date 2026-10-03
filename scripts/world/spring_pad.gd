@tool
extends Area2D
## Comic spring: land on it (or walk onto it) and get launched up.

const INK := Color(0.05, 0.03, 0.1)
const ComicText = preload("res://scripts/effects/comic_text.gd")

@export var launch_speed := 1250.0
@export var cap_color := Color(0.95, 0.25, 0.2)

var _squash := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 16)
	cs.shape = rect
	cs.position = Vector2(0, -16)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or not body.is_in_group("player"):
		return
	var p := body as CharacterBody2D
	if p.velocity.y < -50.0:
		return  # rising through it, not landing
	p.velocity.y = -launch_speed
	if "is_jumping" in p:
		p.is_jumping = false  # releasing jump must not cut the launch short
	if "can_dash" in p:
		p.can_dash = true
	_squash = 1.0
	var pop := ComicText.new()
	pop.text = "BOING!"
	pop.color = cap_color.lightened(0.3)
	pop.position = global_position + Vector2(0, -50)
	get_tree().current_scene.add_child(pop)


func _process(delta: float) -> void:
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	# origin = ground contact point
	var h := 22.0 - 10.0 * _squash + sin(_squash * 20.0) * 4.0 * _squash
	draw_rect(Rect2(-24, -6, 48, 6), INK)
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(Vector2(-14.0 if i % 2 == 0 else 14.0, -6.0 - h * i / 6.0))
	draw_polyline(pts, INK, 6.0)
	draw_polyline(pts, Color(0.75, 0.78, 0.85), 3.0)
	var cap := Rect2(-26, -6 - h - 10, 52, 12)
	draw_rect(cap.grow(2.5), INK)
	draw_rect(cap, cap_color)
	draw_rect(Rect2(cap.position, Vector2(cap.size.x, 3)), cap_color.lightened(0.35))
