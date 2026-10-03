extends "res://scripts/enemies/enemy_base.gd"
## Crossed-Out: an abandoned draft of Vesper. A big red X shields its front,
## so side hits from the front bounce off. Get behind it (it turns slowly),
## pogo on its head, or get it into light, which burns the X away.
## It walks at the player and shoves when close.

enum State { WALK, WINDUP, SHOVE, RECOVER }

@export var hp := 3
@export var walk_speed := 70.0
@export var shove_speed := 340.0
## How long the player must stay behind it before it turns round.
@export var turn_delay := 0.55

var state := State.WALK
var _timer := 0.0
var _turn := 0.0
var _shield := 1.0  # 1 = X fully up, 0 = burnt away by light


func _ready() -> void:
	setup(Vector2(28, 56), hp)


func _tick(delta: float) -> void:
	_timer -= delta
	_fall(delta)
	_shield = move_toward(_shield, 0.0 if is_lit() else 1.0, delta * 3.0)
	var d := to_player()
	match state:
		State.WALK:
			if _player and signf(d.x) != facing and absf(d.x) > 6.0:
				_turn += delta
				if _turn >= turn_delay:
					facing = -facing
					_turn = 0.0
			else:
				_turn = 0.0
			var blocked := is_on_floor() and (hitting_wall() or at_ledge())
			var chasing := _player != null and absf(d.x) < 500.0 and signf(d.x) == facing
			velocity.x = move_toward(velocity.x, facing * walk_speed if chasing and not blocked else 0.0, 600.0 * delta)
			if chasing and absf(d.x) < 74.0 and absf(d.y) < 50.0:
				state = State.WINDUP
				_timer = 0.4
		State.WINDUP:
			velocity.x = move_toward(velocity.x, -facing * 40.0, 600.0 * delta)
			if _timer <= 0.0:
				state = State.SHOVE
				_timer = 0.22
		State.SHOVE:
			velocity.x = facing * shove_speed
			if is_on_floor() and at_ledge():
				velocity.x = 0.0
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = 0.7
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _timer <= 0.0:
				state = State.WALK
	move_and_slide()


func _blocks(hit_dir: Vector2, from_pos: Vector2) -> bool:
	if _shield < 0.5 or hit_dir.y > 0.0:
		return false  # no shield in light; pogo hits come from above
	if signf(from_pos.x - global_position.x) != facing:
		return false  # hit from behind
	pop("BLOCK!", Color(0.9, 0.25, 0.2), Vector2(facing * 20.0, -60), 22)
	return true


func paint(c: CanvasItem) -> void:
	var coat := Color(0.4, 0.4, 0.47)
	var face := Color(0.8, 0.8, 0.84)
	var step := sin(time * 6.0) * 3.0 if absf(velocity.x) > 10.0 else 0.0
	var lean := 0.0
	if state == State.WINDUP:
		lean = -0.25
	elif state == State.SHOVE:
		lean = 0.3
	for sx in [-4.0, 4.0]:
		c.draw_line(Vector2(sx, -14), Vector2(sx + step * signf(sx), 0), INK, 4.0)
	c.draw_set_transform(Vector2(0, -14), lean)
	c.draw_colored_polygon(pts([-11, -26, 11, -26, 15, 0, 8, 4, 2, -2, -4, 4, -9, -2, -15, 2]), coat)
	c.draw_colored_polygon(ell(Vector2(1, -36), 10, 10), face)
	for ex in [-2.0, 6.0]:  # crossed-out eyes
		c.draw_line(Vector2(ex - 2, -39), Vector2(ex + 2, -33), INK, 1.6)
		c.draw_line(Vector2(ex + 2, -39), Vector2(ex - 2, -33), INK, 1.6)
	c.draw_colored_polygon(ell(Vector2(1, -44), 21, 5), coat.darkened(0.3))  # hat brim
	c.draw_colored_polygon(pts([-10, -46, -8, -60, 9, -58, 11, -46]), coat.darkened(0.3))
	if _shield > 0.02:
		var red := Color(0.82, 0.12, 0.1, _shield)
		var a := Vector2(14, -52)
		var b := Vector2(40, 10)
		c.draw_line(a, b, red, 6.0, true)
		c.draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), red, 6.0, true)
	c.draw_set_transform(Vector2.ZERO)
