extends "res://scripts/enemies/red_pen.gd"
## A diving fountain pen (Shade draws them in the final fight): the Red Pen's
## art, small and mean. It hovers above Vesper, shakes as it takes aim (the
## tell), then dives nib-first along that line and sticks in the street for a
## moment: the time to hit it. Light makes it pull out and back off early.

@export var dive_speed := 820.0
@export var hover_height := 230.0
@export var aim_time := 0.5
@export var stuck_time := 1.1
@export var dive_damage := 2.0
@export var touch_damage := 1.0

var _timer := 1.0
var _dir := Vector2.DOWN


func _ready() -> void:
	setup(Vector2(34, 60), hp)
	gravity = 0.0
	knockback_speed = 120.0
	outline.scale = Vector2.ONE * 0.55
	set_harmful(true)
	tilt = 0.0


func damage_default() -> float:
	return dive_damage if state == State.STAB else touch_damage


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	super(damage, hit_dir, from_pos)
	if state == State.STAB:
		stun = 0.0  # a dive doesn't stop for a scratch


func _tick(delta: float) -> void:
	_timer -= delta
	if _player == null:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return
	var target := _player.global_position + Vector2(0, -10)
	match state:
		State.HOVER:
			# drift to a spot above and to one side of Vesper, nib towards him
			var spot := target + Vector2(sin(time * 1.3) * 140.0, -hover_height)
			velocity = velocity.move_toward((spot - global_position).limit_length(260.0), 900.0 * delta)
			_point_at(target, delta)
			if _timer <= 0.0:
				state = State.AIM
				_timer = aim_time
				rage = 1.0
		State.AIM:
			velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			_point_at(target, delta)
			if _timer <= 0.0:
				state = State.STAB
				_dir = (target - global_position).normalized()
				_timer = 1.2
				rage = 0.0
				Sfx.play("dash", -4.0, 1.3)
		State.STAB:
			velocity = _dir * dive_speed
			move_and_slide()
			if is_on_floor() or is_on_wall() or _timer <= 0.0:
				state = State.STUCK
				_timer = stuck_time
				velocity = Vector2.ZERO
				pop("THUNK!", Color(1.0, 0.86, 0.4), Vector2(0, -40), 22)
				Sfx.play("fall_land", -6.0, 1.6)
			return
		State.STUCK:
			velocity = Vector2.ZERO
			if _timer <= 0.0 or is_lit():
				state = State.HOVER
				_timer = randf_range(1.2, 2.0)
				velocity = Vector2(0, -320.0)
	move_and_slide()


func _point_at(target: Vector2, delta: float) -> void:
	var v := target - global_position
	var want := atan2(-v.x, v.y)  # nib (local +Y) towards the target
	tilt = lerp_angle(tilt, want, 1.0 - exp(-8.0 * delta))
	if state == State.AIM:
		tilt += sin(time * 60.0) * 0.04
