extends "res://scripts/clearing/monster_3d.gd"
## Smudge (clearing version of scripts/enemies/smudge.gd): swims almost
## invisibly across the grass towards the player, surfaces, and lunges.
## While hidden it can't hurt or be hurt, unless a brazier's light shows
## it. It is exposed while it surfaces, lunges and recovers. Jump to dodge.

enum State { HIDDEN, SURFACE, LUNGE, RECOVER }  # same order as the 2D art

@export var swim_speed := 2.8
@export var lunge_range := 3.0
@export var lunge_speed := 8.0
@export var surface_time := 0.45
@export var lunge_time := 0.35
@export var recover_time := 1.1
@export var cooldown := 1.5

var state := State.HIDDEN
var _timer := 0.0
var _cooldown := 1.0
var _alpha := 0.15
var _lunge_dir := Vector3.RIGHT


func _ready() -> void:
	hp = 2
	sight = 10.0
	setup_monster("res://scenes/enemies/smudge.tscn", 224, 40, true)
	_set_exposed(false)


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	var exposed := state != State.HIDDEN or is_lit()
	_set_exposed(exposed)
	_alpha = move_toward(_alpha, 1.0 if exposed else 0.15, delta * 4.0)
	match state:
		State.HIDDEN:
			if sees_player():
				var d := to_player()
				face_dir(d)
				move_planar(d.normalized() * swim_speed, 12.0, delta)
				if d.length() < lunge_range and _cooldown <= 0.0:
					state = State.SURFACE
					_timer = surface_time
					_lunge_dir = d.normalized()
			else:
				_slow_to_stop(10.0, delta)
		State.SURFACE:
			_slow_to_stop(20.0, delta)
			if _player:
				_lunge_dir = to_player().normalized()
				face_dir(_lunge_dir)
			if _timer <= 0.0:
				state = State.LUNGE
				_timer = lunge_time
				velocity = _lunge_dir * lunge_speed + Vector3(0, 4.0, 0)
		State.LUNGE:
			if _timer <= 0.0 and is_on_floor():
				state = State.RECOVER
				_timer = recover_time
		State.RECOVER:
			_slow_to_stop(14.0, delta)
			if _timer <= 0.0:
				state = State.HIDDEN
				_cooldown = cooldown


## Hidden: no collision on the enemy layer, so attacks pass through it.
func _set_exposed(on: bool) -> void:
	collision_layer = 4 if on and not dead else 0


func is_harmful() -> bool:
	return super() and (state == State.LUNGE or state == State.SURFACE)


func _on_respawn() -> void:
	state = State.HIDDEN
	_set_exposed(false)


func _sync_puppet() -> void:
	puppet.figure.state = state
	puppet.figure._alpha = _alpha
	puppet.figure.velocity = Vector2(velocity.x, velocity.z) * 40.0
