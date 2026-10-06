extends "res://scripts/enemies/enemy_base.gd"
## Scribble: a small flying tangle. Hovers around its spawn point, then
## shakes and dive-bombs the player. Weak (2 hits) but comes in swarms.
## Light scatters it: it shrieks and flees the lit area.

enum State { HOVER, AIM, DIVE, RISE, FLEE }

@export var hp := 2
@export var sight := 340.0
@export var dive_speed := 430.0
@export var dive_cooldown := 1.6

var state := State.HOVER
var _home := Vector2.ZERO
var _timer := 0.0
var _cooldown := 0.0
var _dir := Vector2.ZERO
var _seed := 0


func _ready() -> void:
	setup(Vector2(30, 26), hp)
	_home = global_position
	_cooldown = randf_range(0.3, 1.5)
	_seed = randi() % 1000


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	var light := light_at(global_position)
	if light and state != State.FLEE:
		_dir = (global_position - light.global_position).normalized()
		if _dir == Vector2.ZERO:
			_dir = Vector2.UP
		state = State.FLEE
		_timer = 1.2
		pop("SKREE!", PALE, Vector2(0, -30), 20)
	match state:
		State.HOVER:
			var target := _home + Vector2(sin(time * 1.3) * 40.0, sin(time * 2.1) * 14.0)
			velocity = (target - global_position) * 3.0
			var d := to_player()
			if _player and d.length() < sight and _cooldown <= 0.0:
				face_player()
				state = State.AIM
				_timer = 0.45
		State.AIM:
			velocity *= 0.85
			face_player()
			if _timer <= 0.0:
				_dir = to_player().normalized() if _player else Vector2.DOWN
				state = State.DIVE
				_timer = 0.75
		State.DIVE:
			velocity = _dir * dive_speed
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				state = State.RISE
				_cooldown = dive_cooldown
		State.RISE:
			var back := _home - global_position
			velocity = velocity.move_toward(back.limit_length(1.0) * 220.0, 900.0 * delta)
			if back.length() < 24.0:
				state = State.HOVER
		State.FLEE:
			velocity = _dir * 300.0
			if _timer <= 0.0:
				_home = global_position
				state = State.HOVER
				_cooldown = 1.0
	move_and_slide()


func _fall(_delta: float) -> void:
	pass  # it flies


func _on_hurt() -> void:
	state = State.RISE
	_cooldown = dive_cooldown


func paint(c: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(time * 9.0)  # re-scribbles itself a few times a second
	var mid := Vector2(0, -13)
	var shake := Vector2(randf_range(-2, 2), randf_range(-2, 2)) if state == State.AIM else Vector2.ZERO
	var flap := sin(time * 26.0)
	for sx in [-1.0, 1.0]:
		var wing := PackedVector2Array()
		for i in 9:
			wing.append(mid + shake + Vector2(sx * (8.0 + rng.randf() * 16.0), -6.0 - rng.randf() * 12.0 + flap * 5.0))
		c.draw_polyline(wing, INK, 1.6, true)
	var tangle := PackedVector2Array()
	for i in 34:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 14.0)
		tangle.append(mid + shake + Vector2(cos(a) * r, sin(a) * r))
	c.draw_polyline(tangle, INK, 2.4, true)
	c.draw_circle(mid + shake, 7.0, INK)
	var look := (to_player().normalized() if _player else Vector2.RIGHT) * Vector2(facing, 1)
	draw_eye(c, mid + shake + Vector2(-4, -1), 3.6, look)
	draw_eye(c, mid + shake + Vector2(5, -1), 3.6, look)


func damage_default() -> float:
	return 1.0  # weak, but they come in swarms
