extends "res://scripts/clearing/monster_3d.gd"
## The Eraser mini-boss (clearing version of scripts/enemies/eraser.gd).
## A rubber block: every hit bounces off ("BOING!") except while it is
## TIRED. It plods after the player, leans back, then charges in a straight
## line. If the charge misses or slams into something, it is left TIRED,
## panting, with its weak spot showing: that's your window.

enum State { WALK, WINDUP, LUNGE, TIRED, RUB }  # same order as the 2D art

@export var walk_speed := 1.4
@export var charge_range := 6.5
@export var lunge_speed := 10.0
@export var lunge_time := 0.9
@export var windup_time := 0.6
@export var tired_time := 1.9
@export var cooldown := 1.2

var state := State.WALK
var _timer := 0.0
var _cooldown := 1.5
var _lunge_dir := Vector3.RIGHT


func _ready() -> void:
	hp = maxi(hp, 10)  # a scene can make it tougher (the arena does)
	sight = 11.0
	knockback = 2.0
	contact_damage = 2
	respawn_time = 15.0
	setup_monster("res://scenes/enemies/eraser.tscn", 288, 40)


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	match state:
		State.WALK:
			if sees_player():
				var d := to_player()
				face_dir(d)
				move_planar(d.normalized() * walk_speed, 8.0, delta)
				if d.length() < charge_range and _cooldown <= 0.0:
					state = State.WINDUP
					_timer = windup_time
					_lunge_dir = d.normalized()
			else:
				_slow_to_stop(8.0, delta)
		State.WINDUP:
			_slow_to_stop(20.0, delta)
			if _player:
				_lunge_dir = to_player().normalized()
				face_dir(_lunge_dir)
			if _timer <= 0.0:
				state = State.LUNGE
				_timer = lunge_time
				pop("RRRUB!", Color(0.93, 0.55, 0.6), 2.4, 30)
		State.LUNGE:
			move_planar(_lunge_dir * lunge_speed, 50.0, delta)
			var slammed := is_on_wall() and get_slide_collision_count() > 0
			if _timer <= 0.0 or slammed:
				if slammed:
					pop("THUD!", PALE, 2.4)
					_shake(0.4)
				state = State.TIRED
				_timer = tired_time
		State.TIRED:
			_slow_to_stop(12.0, delta)
			if _timer <= 0.0:
				state = State.WALK
				_cooldown = cooldown


func on_flash(_from: Vector3) -> void:
	if dead:
		return
	stun = maxf(stun, 0.6)  # the boss shrugs most of it off
	puppet.flash()


func _blocks(dir: Vector3, _aerial: bool) -> bool:
	if state == State.TIRED:
		return false
	pop("BOING!", Color(0.93, 0.55, 0.6), 2.4, 28)
	puppet.flash()
	if _player and _player.has_method("bounce_back"):
		_player.bounce_back(-dir)
	return true


func is_harmful() -> bool:
	return super() and state != State.TIRED


func _shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)


func _on_respawn() -> void:
	state = State.WALK
	_cooldown = 2.0


func _sync_puppet() -> void:
	puppet.figure.state = state
	puppet.figure.velocity = Vector2(velocity.x, velocity.z) * 40.0
