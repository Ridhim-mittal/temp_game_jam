extends "res://scripts/enemies/enemy_base.gd"
## Crumple: a balled-up page. Rolls at the player and is armoured while it
## is a ball. Two ways to open it up:
##  - light unfolds it flat (vulnerable for `unfold_time` seconds)
##  - it dazes itself when it rolls into a wall or reaches a ledge

enum State { IDLE, WINDUP, ROLL, DAZED, UNFOLDED }

@export var hp := 3
@export var sight := 420.0
@export var roll_speed := 300.0
@export var unfold_time := 3.0
@export var daze_time := 1.4

var state := State.IDLE
var _timer := 0.0
var _cooldown := 0.0
var _angle := 0.0


func _ready() -> void:
	setup(Vector2(42, 42), hp)


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	_fall(delta)
	if state != State.UNFOLDED and is_lit():
		state = State.UNFOLDED
		_timer = unfold_time
		velocity.x = 0.0
		pop("FWOOMP!", PALE)
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			var d := to_player()
			if _player and absf(d.x) < sight and absf(d.y) < 90.0 and _cooldown <= 0.0:
				face_player()
				state = State.WINDUP
				_timer = 0.5
		State.WINDUP:
			_angle -= facing * delta * 14.0  # spins in place like a revving wheel
			if _timer <= 0.0:
				state = State.ROLL
				_timer = 2.2
		State.ROLL:
			velocity.x = facing * roll_speed
			_angle += facing * delta * roll_speed / 21.0
			if is_on_floor() and (hitting_wall() or at_ledge()):
				velocity = Vector2(-facing * 140.0, -260.0)
				state = State.DAZED
				_timer = daze_time
				pop("CRUNCH!", PALE)
			elif _timer <= 0.0:
				state = State.IDLE
				_cooldown = 0.8
		State.DAZED, State.UNFOLDED:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _timer <= 0.0:
				state = State.IDLE
				_cooldown = 0.6
				_angle = 0.0
	set_harmful(state == State.ROLL or state == State.WINDUP or state == State.IDLE)
	move_and_slide()


func _blocks(_hit_dir: Vector2, _from_pos: Vector2) -> bool:
	if state == State.DAZED or state == State.UNFOLDED:
		return false
	pop("TINK!", Color(0.8, 0.8, 0.85), Vector2(0, -44), 22)
	return true


func paint(c: CanvasItem) -> void:
	var paper := Color(0.92, 0.89, 0.8)
	var crease := Color(0.5, 0.46, 0.4)
	if state == State.UNFOLDED or state == State.DAZED:
		# flattened page lying open, dizzy
		var w := 34.0 if state == State.UNFOLDED else 26.0
		var page := pts([-w, -16, -w * 0.4, -20, w * 0.3, -15, w, -19, w + 2, 0, -w - 2, 0])
		c.draw_colored_polygon(page, paper)
		c.draw_line(Vector2(-w * 0.4, -20), Vector2(-w * 0.3, 0), crease, 1.3)
		c.draw_line(Vector2(w * 0.3, -15), Vector2(w * 0.4, 0), crease, 1.3)
		for sx in [-8.0, 8.0]:
			c.draw_arc(Vector2(sx, -9), 3.5, time * 9.0, time * 9.0 + 4.5, 8, INK, 1.6)
		return
	c.draw_set_transform(Vector2(0, -21), _angle)
	var ball := pts([-20, -12, -8, -21, 9, -20, 21, -9, 22, 6, 14, 18, -4, 21, -18, 15, -23, 2])
	c.draw_colored_polygon(ball, paper)
	for l in [[-20, -12], [21, -9], [14, 18], [-18, 15], [-8, -21], [22, 6]]:
		c.draw_line(Vector2(l[0], l[1]), Vector2(1, 0), crease, 1.3)
	c.draw_set_transform(Vector2(0, -21), 0.0)
	if state != State.ROLL:
		c.draw_colored_polygon(pts([-10, -6, 15, -8, 16, 3, -9, 5]), INK)
		c.draw_circle(Vector2(-1, -1), 3.0, DANGER)
		c.draw_circle(Vector2(9, -2), 3.0, DANGER)
	else:
		for k in 3:
			var y := -12.0 + k * 12.0
			c.draw_line(Vector2(-30, y), Vector2(-44, y), INK, 2.0)
	c.draw_set_transform(Vector2.ZERO)
