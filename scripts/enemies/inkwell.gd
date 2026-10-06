extends "res://scripts/enemies/enemy_base.gd"
## Inkwell: a living ink bottle. It never moves; it lobs ink blobs in an arc
## at the player. A blob that lands leaves a puddle that slows you for a few
## seconds. Blobs can be slashed out of the air, and the bottle is pogo-able.

const InkBlob = preload("res://scripts/enemies/ink_blob.gd")

@export var hp := 4
@export var sight := 620.0
@export var fire_interval := 2.4
## Seconds a blob takes to reach where the player was standing.
@export var flight_time := 0.9
@export var blob_gravity := 1400.0

var _cooldown := 1.2
var _aim := 0.0  # >0 while winding up a shot


func _ready() -> void:
	setup(Vector2(44, 48), hp)
	knockback_speed = 0.0


func _tick(delta: float) -> void:
	_cooldown -= delta
	_fall(delta)
	velocity.x = 0.0
	var d := to_player()
	if _player:
		face_player()
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_fire()
	elif _player and d.length() < sight and _cooldown <= 0.0:
		_aim = 0.4
		_cooldown = fire_interval
	move_and_slide()


func _fire() -> void:
	if _player == null:
		return
	var blob := InkBlob.new()
	var from := global_position + Vector2(0, -34)
	var d := _player.global_position - from
	blob.position = from
	blob.gravity = blob_gravity
	blob.velocity = Vector2(d.x / flight_time, (d.y - 0.5 * blob_gravity * flight_time * flight_time) / flight_time)
	get_tree().current_scene.add_child(blob)
	pop("BLORP!", Color(0.5, 0.5, 0.8), Vector2(0, -70), 20)


func paint(c: CanvasItem) -> void:
	var glass := Color(0.55, 0.7, 0.85)
	var ink := Color(0.07, 0.06, 0.14)
	var puff := 1.0 + (0.12 * sin(time * 40.0) if _aim > 0.0 else 0.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(puff, 2.0 - puff))
	c.draw_colored_polygon(pts([-20, -34, 20, -34, 24, 0, -24, 0]), glass)
	var slosh := sin(time * 3.0) * 2.0
	c.draw_colored_polygon(pts([-21, -24 + slosh, 21, -24 - slosh, 24, 0, -24, 0]), ink)
	c.draw_colored_polygon(pts([-11, -46, 11, -46, 11, -34, -11, -34]), glass)
	c.draw_colored_polygon(pts([-14, -50, 14, -50, 14, -45, -14, -45]), Color(0.3, 0.3, 0.38))
	c.draw_line(Vector2(-15, -30), Vector2(-18, -6), glass.lightened(0.5), 2.5)
	var look := to_player().normalized() * Vector2(facing, 1) if _player else Vector2.UP
	draw_eye(c, Vector2(-8, -13), 5.0, look)
	draw_eye(c, Vector2(8, -13), 5.0, look)
	if _aim > 0.0:
		c.draw_circle(Vector2(0, -52), 6.0 * (1.0 - _aim / 0.4) + 2.0, ink)
	c.draw_set_transform(Vector2.ZERO)


func damage_default() -> float:
	return 1.0  # touching the bottle: half an ink bottle (its blobs too)
