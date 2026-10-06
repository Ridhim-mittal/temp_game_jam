extends "res://scripts/clearing/monster_3d.gd"
## Crossed-Out (clearing version of scripts/enemies/crossed_out.gd): an
## abandoned draft of Vesper with a big red X shielding its front. It turns
## slowly, walks at the player and shoves when close. Hits on its front
## bounce off ("CLANG!") unless you:
##  - get behind it (dash round it: it turns slowly)
##  - attack from above (jump, then attack: you bounce off its head)
##  - lure it into a brazier's light, which burns the X away

enum State { WALK, WINDUP, SHOVE, RECOVER }  # same order as the 2D art

@export var walk_speed := 1.7
@export var turn_speed := 1.6  # radians per second
@export var shove_range := 1.8
@export var shove_speed := 8.0
@export var windup_time := 0.5
@export var shove_time := 0.25
@export var recover_time := 0.7

var state := State.WALK
var _timer := 0.0
## Ground direction it faces (its shielded front).
var _front := Vector3.LEFT
var _shield := 1.0


func _ready() -> void:
	lumens = 3
	hp = 3
	sight = 10.0
	knockback = 4.0
	setup_monster("res://scenes/enemies/crossed_out.tscn", 256, 40)


func _tick(delta: float) -> void:
	_timer -= delta
	if is_lit():
		_shield = maxf(_shield - delta * 0.6, 0.0)
	match state:
		State.WALK:
			if sees_player():
				_turn_towards(to_player(), delta)
				move_planar(_front * walk_speed, 10.0, delta)
				if to_player().length() < shove_range and _front.dot(to_player().normalized()) > 0.7:
					state = State.WINDUP
					_timer = windup_time
			else:
				_slow_to_stop(10.0, delta)
		State.WINDUP:
			_slow_to_stop(20.0, delta)
			if _timer <= 0.0:
				state = State.SHOVE
				_timer = shove_time
		State.SHOVE:
			move_planar(_front * shove_speed, 60.0, delta)
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = recover_time
		State.RECOVER:
			_slow_to_stop(16.0, delta)
			if _timer <= 0.0:
				state = State.WALK
	face_dir(_front)


func on_flash(from: Vector3) -> void:
	super(from)
	_shield = maxf(_shield - 0.7, 0.0)
	pop("SIZZLE!", Color(1.0, 0.95, 0.7), 2.0, 22)


func _turn_towards(d: Vector3, delta: float) -> void:
	if d.length() < 0.01:
		return
	var a := atan2(_front.z, _front.x)
	var b := atan2(d.z, d.x)
	a = move_toward(a, a + angle_difference(a, b), turn_speed * delta)
	_front = Vector3(cos(a), 0.0, sin(a))


## Front hits bounce off the X, unless they come from above or it's burnt.
func _blocks(dir: Vector3, aerial: bool) -> bool:
	if aerial or _shield < 0.5:
		return false
	if dir.dot(_front) < -0.2:
		pop("CLANG!", PALE, 1.9, 26)
		return true
	return false


func is_harmful() -> bool:
	return super() and state != State.RECOVER


func _on_respawn() -> void:
	state = State.WALK
	_shield = 1.0


func _sync_puppet() -> void:
	puppet.figure.state = state
	puppet.figure._shield = _shield
	puppet.figure.velocity = Vector2(velocity.x, velocity.z) * 40.0
