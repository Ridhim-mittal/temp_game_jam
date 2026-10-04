extends "res://scripts/clearing/monster_3d.gd"
## Crumple (clearing version of scripts/enemies/crumple.gd): a balled-up
## page that winds up and rolls at the player. Armoured while it is a ball
## ("CLANG!"). It opens up when:
##  - it rolls into something solid, or runs out of steam: dazed for a bit
##  - it ends up in a brazier's light: unfolds flat for `unfold_time`
## Jump over the roll, or dash aside and let it hit a wall.

enum State { IDLE, WINDUP, ROLL, DAZED, UNFOLDED }  # same order as the 2D art

@export var roll_speed := 8.5
@export var roll_time := 1.6
@export var windup_time := 0.5
@export var daze_time := 1.6
@export var unfold_time := 3.0
@export var cooldown := 1.0

var state := State.IDLE
var _timer := 0.0
var _cooldown := 0.5
var _roll_dir := Vector3.RIGHT
var _angle := 0.0


func _ready() -> void:
	hp = 3
	sight = 8.5
	setup_monster("res://scenes/enemies/crumple.tscn", 224, 40)


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	if is_lit() and state != State.UNFOLDED:
		state = State.UNFOLDED
		_timer = unfold_time
		pop("FWUMP!", PALE)
	match state:
		State.IDLE:
			_slow_to_stop(20.0, delta)
			if sees_player() and _cooldown <= 0.0:
				_roll_dir = to_player().normalized()
				face_dir(_roll_dir)
				state = State.WINDUP
				_timer = windup_time
		State.WINDUP:
			_slow_to_stop(20.0, delta)
			if _player:
				_roll_dir = to_player().normalized()
				face_dir(_roll_dir)
			if _timer <= 0.0:
				state = State.ROLL
				_timer = roll_time
		State.ROLL:
			move_planar(_roll_dir * roll_speed, 40.0, delta)
			_angle += roll_speed * delta * 3.0 * facing
			if _timer <= 0.0 or (get_slide_collision_count() > 0 and is_on_wall()):
				if is_on_wall():
					pop("BONK!", PALE)
					velocity.x = -_roll_dir.x * 3.0
					velocity.z = -_roll_dir.z * 3.0
				state = State.DAZED
				_timer = daze_time
		State.DAZED, State.UNFOLDED:
			_slow_to_stop(14.0, delta)
			if _timer <= 0.0:
				state = State.IDLE
				_cooldown = cooldown


func on_flash(_from: Vector3) -> void:
	if dead:
		return
	state = State.UNFOLDED
	_timer = unfold_time
	pop("FWUMP!", PALE)


func _blocks(_dir: Vector3, _aerial: bool) -> bool:
	if state == State.DAZED or state == State.UNFOLDED:
		return false
	pop("CLANG!", PALE, 1.4, 26)
	puppet.flash()
	return true


func is_harmful() -> bool:
	return super() and state == State.ROLL


func _on_respawn() -> void:
	state = State.IDLE
	_cooldown = 1.0


func _sync_puppet() -> void:
	puppet.figure.state = state
	puppet.figure._angle = _angle
	puppet.figure.velocity = Vector2(velocity.x, velocity.z) * 40.0
