extends "res://scripts/clearing/monster_3d.gd"
## The Half-Drawn: hooded ghosts the Writer started and never finished
## (unfinished_model.gd: half inked, half dashed pencil, a nib-blade for a
## hand). They are barely on the page: out of the Ember's light only hints
## of one show (its eyes, a few motes, a flicker of line), and a sword goes
## straight through it ("NOT DRAWN YET"). Hold right click: inside the
## raised Ember's light it inks in, solid enough to cut
## (clearing_player.gd ember_reveals(); the Lantern Flail's whirl counts
## too). The Prism Saber's blade is light itself: it cuts one unseen, and
## the cut shows it for a moment. Vesper shows a "HOLD RIGHT CLICK" prompt
## when one is near and unseen (group "needs_ember").
## They drift after Vesper and cut at him:
##  - WINDUP: the blade snaps up behind the head, the eyes flare; it tracks
##    him, then locks for the last moment
##  - STRIKE: a quick lunge and a slash across an arc in front (`reach`,
##    `arc`); only the blade hurts, touching it doesn't
##  - RECOVER: a short pause, the time to hit back
## Hitting one mid-windup staggers it out of the swing. `hp` 5 (half_drawn.tscn).

const Model = preload("res://scripts/clearing/unfinished_model.gd")
const GHOST_RIM := Color(0.6, 1.0, 0.95)

enum State { DRIFT, WINDUP, STRIKE, RECOVER }

@export var drift_speed := 3.2
## Starts a swing when Vesper is this close.
@export var strike_range := 2.0
## How far the slash reaches, and how many degrees either side of its aim.
@export var reach := 2.2
@export var arc := 70.0
@export var windup_time := 0.38
@export var strike_time := 0.14
@export var recover_time := 0.5
## Seconds between swings.
@export var cooldown := 0.45
@export var blade_damage := 1

var state := State.DRIFT
var model: Node3D
## True while the raised Ember's light is on it: visible and hittable.
var revealed := false

var _timer := 0.0
var _cd := 0.0
var _dir := Vector3(0, 0, 1)
var _struck := false
var _lit := 0.0  # seconds a Prism Saber cut keeps it drawn in


func _ready() -> void:
	sight = 8.5
	knockback = 5.5
	contact_damage = 0
	lumens = 4  # hard to see, quick to swing
	model = Model.new()
	model.name = "Model"
	add_child(model)
	setup_monster_model(model)
	_cd = randf_range(0.3, 1.2)
	add_to_group("needs_ember")


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	revealed = not dead and p != null and p.has_method("ember_reveals") and p.ember_reveals(global_position + Vector3(0, 1.0, 0))
	_lit = maxf(_lit - delta, 0.0)
	super(delta)


func _tick(delta: float) -> void:
	_timer -= delta
	_cd -= delta
	var d := to_player()
	match state:
		State.DRIFT:
			if sees_player():
				_turn_to(d, delta, 8.0)
				if d.length() > strike_range * 0.8:
					move_planar(d.normalized() * drift_speed, 6.0, delta)
				else:
					_slow_to_stop(10.0, delta)
				if d.length() < strike_range and _cd <= 0.0:
					state = State.WINDUP
					_timer = windup_time
			else:
				# drifting about where it was drawn
				var home := _home - global_position
				home.y = 0.0
				var wander := Vector3(sin(time * 0.4), 0.0, cos(time * 0.31)) * 0.6
				move_planar((home * 0.5 + wander).limit_length(0.8), 3.0, delta)
				if Vector2(velocity.x, velocity.z).length() > 0.2:
					_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
		State.WINDUP:
			_slow_to_stop(14.0, delta)
			if _timer > windup_time * 0.3 and d.length() > 0.05:
				_turn_to(d, delta, 10.0)  # tracks him, then locks for the last third
			if _timer <= 0.0:
				state = State.STRIKE
				_timer = strike_time
				_struck = false
				velocity.x = _dir.x * 4.5
				velocity.z = _dir.z * 4.5
		State.STRIKE:
			_slow_to_stop(16.0, delta)
			if not _struck and _timer <= strike_time * 0.6:
				_struck = true
				_slash()
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = recover_time
		State.RECOVER:
			_slow_to_stop(10.0, delta)
			if _timer <= 0.0:
				state = State.DRIFT
				_cd = cooldown


func _turn_to(d: Vector3, delta: float, rate: float) -> void:
	if d.length() < 0.05:
		return
	_dir = _dir.slerp(d.normalized(), 1.0 - exp(-rate * delta)).normalized()
	face_dir(_dir)


## The blade comes down across an arc in front: Vesper is hit if he's within
## `reach` and `arc` of its aim (and not jumping clear over it).
func _slash() -> void:
	Fx.slash(get_tree(), global_position, _dir, randf() < 0.5, false, GHOST_RIM)
	if _player == null:
		return
	var to := _player.global_position - global_position
	if absf(to.y) > 1.4:
		return
	to.y = 0.0
	var dist := to.length()
	var inside := dist < 0.8 or (dist < reach and (to / dist).dot(_dir) >= cos(deg_to_rad(arc)))
	if inside and _player.has_method("take_damage"):
		_player.take_damage(blade_damage, global_position)


## Only the blade hurts: brushing past it is safe.
func is_harmful() -> bool:
	return false


## Out of the Ember's light there is nothing there to cut (but the Prism
## Saber's light cuts it anyway).
func _blocks(_dir: Vector3, _aerial: bool) -> bool:
	if revealed:
		return false
	if _player and _player.has_method("light_blade") and _player.light_blade():
		_lit = 0.8
		return false
	pop("NOT DRAWN YET", Color(0.78, 0.9, 1.0), 2.2, 22)
	return true


## A hit mid-windup staggers it out of the swing.
func _on_hurt() -> void:
	if state == State.WINDUP:
		state = State.RECOVER
		_timer = 0.5
		pop("!", PALE, 2.4, 30)


func _die() -> void:
	remove_from_group("needs_ember")
	pop("UNWRITTEN", Color(0.95, 0.93, 0.86), 2.4, 26)
	Fx.burst(get_tree(), global_position + Vector3(0, 1.0, 0), Color(0.42, 0.44, 0.5), 16, 3.2)
	super()


func _on_respawn() -> void:
	state = State.DRIFT
	add_to_group("needs_ember")


func _sync_puppet() -> void:
	model.dir = _dir
	model.speed = Vector2(velocity.x, velocity.z).length() / maxf(drift_speed, 0.1)
	model.windup = 1.0 - _timer / windup_time if state == State.WINDUP else -1.0
	model.strike = 1.0 - _timer / strike_time if state == State.STRIKE else -1.0
	model.dead = dead
	model.reveal = 1.0 if revealed or _lit > 0.0 else 0.0
