extends CharacterBody2D
## Crawler: hairy ink bug with a small state machine.
##  PATROL  -> walks, turns at walls/ledges, pauses to look around (IDLE)
##  ALERT   -> spots the player: hops, "!" and bristling hair
##  CHASE   -> runs at the player but never walks off ledges
##  WINDUP  -> crouches and shakes, then LEAPs at the player
##  RECOVER -> brief vulnerable pause after landing / spitting
##  SPIT    -> rears up and spits ink at head height (duck under it!)
##  STUNNED -> knocked back by a nail hit, interrupts any attack

const InkSpit = preload("res://scripts/enemies/ink_spit.gd")

enum State { PATROL, IDLE, ALERT, CHASE, WINDUP, LEAP, RECOVER, SPIT, STUNNED }

@export_group("Stats")
@export var max_health := 4
@export var contact_damage := 1.0  # half ink bottles
@export var gravity := 2000.0

@export_group("Movement")
@export var patrol_speed := 60.0
@export var chase_speed := 155.0
@export var accel := 900.0
@export_enum("Left:-1", "Right:1") var start_direction := -1

@export_group("Senses")
@export var sight_range := 380.0
@export var sight_height := 140.0
@export var lose_range := 620.0

@export_group("Leap")
@export var leap_range := 170.0
@export var leap_velocity := Vector2(340, -520)
@export var leap_windup := 0.38
@export var leap_cooldown := 1.4
@export var recover_time := 0.45

@export_group("Spit")
@export var can_spit := true
@export var spit_min_range := 220.0
@export var spit_max_range := 460.0
@export var spit_windup := 0.5
@export var spit_cooldown := 2.6
@export var spit_speed := 380.0

@export_group("Hit")
@export var knockback_speed := 320.0
@export var stun_time := 0.28

var health := 0
var dead := false
var state := State.PATROL

var _dir := -1
var _state_timer := 0.0
var _leap_cd := 0.0
var _spit_cd := 0.0
var _walk_timer := 0.0
var _lost_sight_timer := 0.0
var _squash := Vector2.ONE
var _player: Node2D

@onready var visual = $Outline/Visual
@onready var body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = max_health
	_dir = start_direction
	add_to_group("enemy")
	_walk_timer = randf_range(2.0, 4.0)
	_spit_cd = randf_range(0.5, 1.5)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.dead:
		_player = null
	_state_timer -= delta
	_leap_cd -= delta
	_spit_cd -= delta
	velocity.y = minf(velocity.y + gravity * delta, 900.0)

	match state:
		State.PATROL: _patrol(delta)
		State.IDLE: _idle(delta)
		State.ALERT: _alert(delta)
		State.CHASE: _chase(delta)
		State.WINDUP: _windup(delta)
		State.LEAP: _leap(delta)
		State.RECOVER: _recover(delta)
		State.SPIT: _spit(delta)
		State.STUNNED: _stunned(delta)

	move_and_slide()
	_update_visual(delta)


# ------------------------------------------------------------------ states

func _enter(new_state: State, duration := 0.0) -> void:
	state = new_state
	_state_timer = duration


func _patrol(delta: float) -> void:
	if is_on_floor() and (_hitting_wall() or _at_ledge()):
		_dir = -_dir
	_approach_speed(_dir * patrol_speed, delta)
	_walk_timer -= delta
	if _walk_timer <= 0.0:
		_enter(State.IDLE, randf_range(0.8, 1.8))
	if _can_see_player():
		_enter_alert()


func _idle(delta: float) -> void:
	_approach_speed(0.0, delta)
	if _can_see_player():
		_enter_alert()
	elif _state_timer <= 0.0:
		if randf() < 0.5:
			_dir = -_dir
		_walk_timer = randf_range(2.0, 4.0)
		_enter(State.PATROL)


func _enter_alert() -> void:
	_face_player()
	if is_on_floor():
		velocity.y = -240.0
	visual.alert = 0.6
	_enter(State.ALERT, 0.45)


func _alert(delta: float) -> void:
	_approach_speed(0.0, delta * 3.0)
	if _state_timer <= 0.0:
		_lost_sight_timer = 0.0
		_enter(State.CHASE)


func _chase(delta: float) -> void:
	if _player == null:
		_enter(State.PATROL)
		return
	var d := _player.global_position - global_position
	if absf(d.x) > 8.0:
		_dir = 1 if d.x > 0.0 else -1
	var blocked := is_on_floor() and (_hitting_wall() or _at_ledge())
	var target := 0.0 if blocked or absf(d.x) < 10.0 else _dir * chase_speed
	_approach_speed(target, delta)

	if is_on_floor():
		if absf(d.x) < leap_range and absf(d.y) < 120.0 and _leap_cd <= 0.0:
			_enter(State.WINDUP, leap_windup)
			return
		if can_spit and _spit_cd <= 0.0 and absf(d.x) > spit_min_range \
				and absf(d.x) < spit_max_range and absf(d.y) < 60.0 and _has_los():
			_enter(State.SPIT, spit_windup)
			return

	if d.length() > lose_range or not _has_los():
		_lost_sight_timer += delta
		if _lost_sight_timer > 2.0:
			_walk_timer = randf_range(2.0, 4.0)
			_enter(State.PATROL)
	else:
		_lost_sight_timer = 0.0


func _windup(delta: float) -> void:
	_approach_speed(0.0, delta * 4.0)
	_face_player()
	if _state_timer <= 0.0:
		var dx := absf(_player.global_position.x - global_position.x) if _player else leap_range
		var air_time := 2.0 * absf(leap_velocity.y) / gravity
		velocity = Vector2(_dir * clampf(dx / air_time, 120.0, leap_velocity.x), leap_velocity.y)
		_squash = Vector2(0.7, 1.35)
		_leap_cd = leap_cooldown
		_enter(State.LEAP, 0.1)


func _leap(_delta: float) -> void:
	if is_on_wall():
		velocity.x = 0.0
	if _state_timer <= 0.0 and is_on_floor():
		velocity.x = 0.0
		_squash = Vector2(1.35, 0.7)
		_enter(State.RECOVER, recover_time)


func _recover(delta: float) -> void:
	_approach_speed(0.0, delta * 4.0)
	if _state_timer <= 0.0:
		_enter(State.CHASE)


func _spit(delta: float) -> void:
	_approach_speed(0.0, delta * 4.0)
	_face_player()
	visual.mouth_open = clampf(1.0 - _state_timer / spit_windup, 0.0, 1.0)
	if _state_timer <= 0.0:
		_fire_spit()
		_spit_cd = spit_cooldown
		_enter(State.RECOVER, 0.35)


func _stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	if _state_timer <= 0.0:
		_lost_sight_timer = 0.0
		_enter(State.CHASE if _player else State.PATROL)


# ----------------------------------------------------------------- helpers

func _approach_speed(target: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _face_player() -> void:
	if _player:
		var dx := _player.global_position.x - global_position.x
		if absf(dx) > 4.0:
			_dir = 1 if dx > 0.0 else -1


func _can_see_player() -> bool:
	if _player == null:
		return false
	var d := _player.global_position - global_position
	if absf(d.x) > sight_range or absf(d.y) > sight_height:
		return false
	var in_front := signf(d.x) == _dir or absf(d.x) < 110.0
	return in_front and _has_los()


func _has_los() -> bool:
	if _player == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -10), _player.global_position, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _hitting_wall() -> bool:
	return is_on_wall() and get_wall_normal().x * _dir < 0.0


func _at_ledge() -> bool:
	var size: Vector2 = body_shape.shape.size
	var from := global_position + Vector2(_dir * (size.x * 0.5 + 4.0), 0.0)
	var to := from + Vector2(0.0, size.y * 0.5 + 16.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fire_spit() -> void:
	var spit := InkSpit.new()
	# Head height of a standing player; a ducking player is below this line.
	spit.position = global_position + Vector2(_dir * 22.0, -26.0)
	spit.velocity = Vector2(_dir * spit_speed, 0.0)
	get_tree().current_scene.add_child(spit)
	velocity.x = -_dir * 80.0
	_squash = Vector2(1.3, 0.8)
	visual.mouth_open = 0.0


# ------------------------------------------------------------------ damage

## Stunned for at least `seconds` (the weapons' specials: player.gd).
func stun_for(seconds: float) -> void:
	if dead:
		return
	if state == State.STUNNED:
		_state_timer = maxf(_state_timer, seconds)
	else:
		_enter(State.STUNNED, seconds)


## How long it stays stunned (0 = not), as enemy_base.gd's `stun` reads.
func stunned_for() -> float:
	return maxf(_state_timer, 0.0) if state == State.STUNNED else 0.0


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	if dead:
		return
	health -= damage
	Sfx.play("boss_hit" if is_in_group("boss") else "ink_enemy_hit", -3.0)
	_flash()
	var kx := signf(global_position.x - from_pos.x)
	if kx == 0.0:
		kx = 1.0
	var strength := 0.5 if hit_dir.y > 0.0 else 1.0  # pogo hits barely push
	velocity.x = kx * knockback_speed * strength
	velocity.y = -120.0 if hit_dir.y <= 0.0 else 0.0
	_squash = Vector2(0.8, 1.2)
	visual.mouth_open = 0.0
	_enter(State.STUNNED, stun_time)
	if health <= 0:
		_die(kx)


func _flash() -> void:
	visual.modulate = Color(4, 4, 4)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.15)


func _die(kx: float) -> void:
	Sfx.play("ink_splat")
	dead = true
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	visual.bristle = 1.0
	var t := create_tween().set_parallel()
	t.tween_property(self, "rotation", kx * 2.5, 0.4)
	t.tween_property(self, "position", position + Vector2(kx * 60.0, -50.0), 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(queue_free)


# ------------------------------------------------------------------ visual

func _update_visual(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	var sq := _squash
	var shake := 0.0
	if state == State.WINDUP:
		sq = Vector2(1.25, 0.72)
		shake = randf_range(-1.5, 1.5)
	elif state == State.SPIT:
		sq = Vector2(0.9, 1.0 + 0.15 * visual.mouth_open)
	visual.scale = Vector2(_dir * sq.x, sq.y)
	visual.position.x = shake

	if is_on_floor():
		visual.walk_phase += absf(velocity.x) * delta * 0.12
		visual.lift = move_toward(visual.lift, 0.0, delta * 4.0)
	else:
		visual.lift = clampf(velocity.y / 600.0, -1.0, 1.0)
	visual.trail = clampf(absf(velocity.x) / chase_speed, 0.0, 1.0)

	var bristle_target := 0.0
	match state:
		State.ALERT, State.WINDUP, State.SPIT, State.LEAP, State.STUNNED:
			bristle_target = 1.0
		State.CHASE, State.RECOVER:
			bristle_target = 0.45
	visual.bristle = move_toward(visual.bristle, bristle_target, delta * 5.0)
	visual.aggro = state != State.PATROL and state != State.IDLE
	if state != State.SPIT:
		visual.mouth_open = move_toward(visual.mouth_open, 0.0, delta * 5.0)

	if _player and visual.aggro:
		var to_p: Vector2 = (_player.global_position - global_position).normalized()
		visual.look = Vector2(to_p.x * _dir, to_p.y)
	else:
		visual.look = Vector2(0.8, 0.1 * sin(Time.get_ticks_msec() * 0.002))
