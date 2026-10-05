extends "res://scripts/enemies/enemy_base.gd"
## Ink bat (the Ink Cave): a blot of ink with torn paper wings and two yellow
## eyes. Hangs upside down asleep until Vesper comes near, then flutters round
## him in a wavy orbit; now and then it pulls back, flares its wings (the tell)
## and swoops through where he stands. Light (the Ember) scatters it.
## Flies: no gravity, passes over the floor.

enum State { ROOST, WAKE, ORBIT, WINDUP, SWOOP, CLIMB, SCATTER }

@export var hp := 2
@export var wake_range := 360.0
@export var fly_speed := 230.0
@export var swoop_speed := 560.0
@export var swoop_damage := 12.0
@export var orbit_radius := 150.0
@export var art_scale := 0.75

const WING := Color(0.18, 0.13, 0.26)
const PAPER := Color(0.88, 0.84, 0.76)
const EYE := Color(1.0, 0.86, 0.3)
## Right wing at rest, from the shoulder: top edge out to the tip, scalloped back.
const WING_SHAPE := [Vector2(0, -4), Vector2(18, -6), Vector2(38, -12), Vector2(32, 6), Vector2(22, 2),
	Vector2(12, 10), Vector2(0, 8)]

var state := State.ROOST
var _timer := 0.0
var _phase := 0.0
var _swoop_dir := Vector2.ZERO
var _flare := 0.0


func _ready() -> void:
	setup(Vector2(40, 30), hp)
	collision_mask = 0  # flies through everything
	outline.scale = Vector2.ONE * art_scale
	outline.position = Vector2(0, 14)
	gravity = 0.0
	knockback_speed = 180.0
	set_harmful(false)
	_phase = randf() * TAU


func damage_default() -> float:
	return swoop_damage


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	if state == State.ROOST:
		_wake()
	super(damage, hit_dir, from_pos)
	velocity.y = -160.0  # knocked up and away
	state = State.CLIMB
	_timer = 0.4


func _wake() -> void:
	if state != State.ROOST:
		return
	state = State.WAKE
	_timer = 0.5 + randf() * 0.3
	set_harmful(true)
	pop("SKREE!", Color(1.0, 0.86, 0.3), Vector2(0, -30), 22)
	Sfx.play("ink_enemy_hit", -10.0, 1.8)
	# the rest of the roost wakes with it
	for b in get_tree().get_nodes_in_group("enemy"):
		if b != self and b.has_method("_wake") and "state" in b and b.global_position.distance_to(global_position) < 260.0:
			b.call_deferred("_wake")


func _tick(delta: float) -> void:
	_timer -= delta
	_phase += delta
	var d := to_player()
	var target := Vector2.ZERO
	if _player:
		target = _player.global_position + Vector2(0, -20)
	match state:
		State.ROOST:
			velocity = Vector2.ZERO
			if _player and absf(d.x) < wake_range and absf(d.y) < 520.0:
				_wake()
			return
		State.WAKE:
			velocity = Vector2(0, 120.0)  # drops off the ceiling
			if _timer <= 0.0:
				state = State.ORBIT
				_timer = randf_range(1.2, 2.2)
		State.ORBIT:
			if _player == null:
				velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			else:
				var spot := target + Vector2(cos(_phase * 1.6) * orbit_radius, -90.0 + sin(_phase * 3.1) * 40.0)
				velocity = velocity.move_toward((spot - global_position).limit_length(fly_speed), 900.0 * delta)
				face_player()
				if is_lit():
					_scatter()
				elif _timer <= 0.0:
					state = State.WINDUP
					_timer = 0.45
		State.WINDUP:
			face_player()
			velocity = velocity.move_toward(Vector2(0, -60.0), 900.0 * delta)
			_flare = minf(_flare + delta / 0.45, 1.0)
			if _timer <= 0.0:
				state = State.SWOOP
				_timer = 0.55
				_swoop_dir = (target - global_position).normalized()
				_flare = 0.0
		State.SWOOP:
			velocity = _swoop_dir * swoop_speed
			# pull out of the dive at Vesper's feet: skims him, never digs into the floor
			if _timer <= 0.0 or (_player and global_position.y > _player.global_position.y + 20.0):
				velocity.y = minf(velocity.y, -40.0)  # a sharp pull-up
				state = State.CLIMB
				_timer = 0.6
		State.CLIMB:
			velocity = velocity.move_toward(Vector2(-facing * 60.0, -fly_speed), 1100.0 * delta)
			if _timer <= 0.0:
				state = State.ORBIT
				_timer = randf_range(1.4, 2.4)
		State.SCATTER:
			velocity = velocity.move_toward((global_position - target).normalized() * fly_speed * 1.3, 1200.0 * delta)
			if _timer <= 0.0 and not is_lit():
				state = State.ORBIT
				_timer = 1.5
	if state != State.WINDUP:
		_flare = move_toward(_flare, 0.0, delta * 4.0)
	if _near_ground() and velocity.y > 0.0:
		velocity.y = -40.0  # skim the floor, never sink into it
	move_and_slide()


## True when the ground Vesper stands on is right under the bat (it flies through rock).
func _near_ground() -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 36), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	# ledges above Vesper's feet don't count: the bat dives past them to reach him
	return not hit.is_empty() and (_player == null or hit.position.y > _player.global_position.y - 10.0)


func _scatter() -> void:
	state = State.SCATTER
	_timer = 0.8
	pop("EEK!", Color(0.95, 0.95, 1.0), Vector2(0, -30), 18)


func paint(c: CanvasItem) -> void:
	var hanging := state == State.ROOST
	var flap := sin(time * (6.0 if hanging else 22.0)) * (0.15 if hanging else 1.0)
	if state == State.SWOOP:
		flap = -0.6  # wings swept back in the dive
	var spread := 1.0 + 0.6 * _flare
	var body := Vector2(0, -20)
	if hanging:
		c.draw_set_transform(Vector2(0, -36), PI)  # upside down from the ceiling
		flap = 0.0
		spread = 0.45
	for side in [-1.0, 1.0]:
		# one wing shape, stretched by `spread` and swung round the shoulder by `flap`
		var shoulder := body + Vector2(side * 6.0, -2.0)
		var xf := Transform2D(-side * flap * 0.7, Vector2(side * spread, 1.0), 0.0, shoulder)
		var wing := PackedVector2Array()
		for q in WING_SHAPE:
			wing.append(xf * q)
		c.draw_colored_polygon(wing, WING)
		c.draw_line(xf * WING_SHAPE[0], xf * WING_SHAPE[2], INK, 2.0)
		c.draw_line(xf * WING_SHAPE[1], xf * WING_SHAPE[5], INK, 1.5)
		var mid := xf * WING_SHAPE[1]
		c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-side * 3.0, 2.0), mid + Vector2(side * 4.0, 1.0),
			mid + Vector2(0, 7.0)]), PAPER)  # a torn paper patch
	c.draw_colored_polygon(ell(body, 12.0, 14.0, 14), INK)
	c.draw_colored_polygon(pts([-9, -30, -6, -42, -1, -32]), INK)  # ears
	c.draw_colored_polygon(pts([9, -30, 6, -42, 1, -32]), INK)
	var open := 0.15 if hanging else 1.0
	for ex in [-4.5, 4.5]:
		c.draw_circle(body + Vector2(ex, -4.0), 3.2 * (1.0 if open > 0.5 else 0.4), EYE if open > 0.5 else INK.lightened(0.3))
	if state == State.WINDUP or state == State.SWOOP:
		c.draw_colored_polygon(pts([-4, 2, 4, 2, 0, 9]), PALE)  # fangs out
	c.draw_set_transform(Vector2.ZERO)
