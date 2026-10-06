extends "res://scripts/enemies/enemy_base.gd"
## Smudge: swims almost invisibly along the ground, then surfaces and
## lunges. While hidden it cannot hurt or be hurt, unless light shows it.
## It is exposed while it surfaces, lunges and recovers.

enum State { HIDDEN, SURFACE, LUNGE, RECOVER }

@export var hp := 2
@export var swim_speed := 130.0
@export var lunge_speed := Vector2(460, -230)
@export var lunge_range := 170.0

var state := State.HIDDEN
var _timer := 0.0
var _cooldown := 1.0
var _alpha := 0.15


func _ready() -> void:
	setup(Vector2(44, 20), hp)
	collision_layer = 0
	set_harmful(false)


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	_fall(delta)
	var lit := is_lit()
	var d := to_player()
	match state:
		State.HIDDEN:
			face_player()
			var blocked := is_on_floor() and (hitting_wall() or at_ledge())
			var want := facing * swim_speed * (0.5 if lit else 1.0)
			if _player == null or blocked or absf(d.x) < 20.0 or absf(d.x) > 620.0:
				want = 0.0
			velocity.x = move_toward(velocity.x, want, 700.0 * delta)
			if _player and absf(d.x) < lunge_range and absf(d.y) < 80.0 and _cooldown <= 0.0 and is_on_floor():
				state = State.SURFACE
				_timer = 0.45
		State.SURFACE:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			face_player()
			if _timer <= 0.0:
				velocity = Vector2(facing * lunge_speed.x, lunge_speed.y)
				state = State.LUNGE
				_timer = 0.12
		State.LUNGE:
			if _timer <= 0.0 and is_on_floor():
				state = State.RECOVER
				_timer = 0.9
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _timer <= 0.0:
				state = State.HIDDEN
				_cooldown = 1.2
	var exposed := lit or state != State.HIDDEN
	collision_layer = 4 if exposed else 0
	set_harmful(state == State.LUNGE)
	_alpha = move_toward(_alpha, 0.9 if exposed else 0.14, delta * 5.0)
	move_and_slide()


func _on_hurt() -> void:
	state = State.RECOVER
	_timer = 0.5


func paint(c: CanvasItem) -> void:
	var body_col := Color(0.42, 0.42, 0.62, _alpha)
	var rise := 0.0
	if state == State.SURFACE:
		rise = 6.0 + sin(time * 40.0) * 1.5
	elif state == State.LUNGE:
		rise = 4.0
	for i in 5:  # smear trail
		c.draw_colored_polygon(ell(Vector2(-16.0 - i * 9.0, -6.0 + sin(time * 5.0 + i) * 1.5), 13.0 - i * 2.0, 6.0 - i * 0.9, 12),
			Color(0.6, 0.6, 0.8, _alpha * (0.3 - i * 0.05)))
	c.draw_colored_polygon(pts([-20, -2, -12, -14 - rise, 6, -18 - rise, 22, -12 - rise, 30, -5, 22, 0, -8, 0]), body_col)
	if _alpha > 0.4:
		c.draw_colored_polygon(pts([8, -13 - rise, 15, -15 - rise, 13, -9 - rise]), PALE)
		c.draw_colored_polygon(pts([19, -12 - rise, 25, -9 - rise, 20, -6 - rise]), PALE)
		c.draw_polyline(pts([8, -4, 12, -2, 16, -4, 20, -2, 24, -4]), PALE, 1.5)


func damage_default() -> float:
	return 2.0  # ambush lunge
