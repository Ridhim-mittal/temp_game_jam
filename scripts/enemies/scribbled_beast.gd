extends "res://scripts/enemies/enemy_base.gd"
## The Scribbled Beast: the boss at the bottom of the Long Drop (from the
## "Scary Scribbles" sheet). A hulking thing of frantic, overlapping pen and
## pencil strokes with no solid outline: two heads with staring white eyes
## and jagged maws, a third eye in its chest ("the stare of the Margins"),
## long clawed arms, spindly legs. It lives in the dark of the gutter, and it
## got out carrying a SHIELD: a slab torn out of the gutter itself, black
## with the white panel lines still on it, that keeps the light off it.
## Everything is drawn in code and re-scribbled at 12 fps (the jitter);
## hits throw loose paper and ink splats (ink_bits.gd).
##
## The fight (beast_arena.gd runs the intro and the ending around it):
##  - The shield always faces the thing it fears most: a lit lantern near it
##    (lantern.gd), else Vesper's raised Ember, else Vesper. A hit from the
##    side the shield faces is blocked ("SCRITCH!"). So: LIGHT A LANTERN.
##    It swings its shield round to the light, and its other side is open.
##  - A lit lantern pins it for `snuff_delay` s: it stops where it is (a
##    charge included) and cowers behind the shield, no walking, no attacks.
##  - SNUFF: then it lobs an ink glob at the lantern (beast_glob.gd) to put it
##    out. Slash the glob out of the air and it has to throw again.
##  - Only its charge and its slam hurt to touch; walking or dashing through
##    it is safe. Its claw costs `claw_damage` (a bottle).
##  - CLAW: close up it rears back (eyes flare) and rakes the floor in front.
##  - RUSH: from afar it lowers the shield and charges, all the way across.
##    Jump it: it slams into the wall and is DAZED, shield down: hit it from
##    anywhere.
##  - Every `stagger_every` damage it STAGGERS for a moment, shield down.
##  - Below half health (phase two) it is faster, its eyes burn red, it LEAPS
##    and slams (beast_shockwave.gd: jump the waves) and drags Scribbles up
##    out of the gutter it came from (scenes/enemies/scribble.tscn, at most
##    `max_spawn`; beast_arena.gd crack_gutter()).
##  - Dashing through it (dash i-frames) gets you behind the shield before it
##    turns: the shield turns at `guard_turn` rad/s.
## At 0 health it doesn't fall over like the small monsters: DYING, light
## breaks out through cracks in the shield, the shield shatters and the
## beast unravels into strokes and paper; then `defeated` fires.

signal defeated
signal hp_changed(current: int, maximum: int)

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const InkBits = preload("res://scripts/effects/ink_bits.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const Glob = preload("res://scripts/enemies/beast_glob.gd")
const Shockwave = preload("res://scripts/enemies/beast_shockwave.gd")
const SCRIBBLE_SCENE := "res://scenes/enemies/scribble.tscn"
const GREY := Color(0.2, 0.19, 0.25)
const PENCIL := Color(0.42, 0.42, 0.5)
const RIM := Color(0.86, 0.92, 1.0)
const EYE := Color(0.98, 0.97, 0.92)
const RED := Color(1.0, 0.2, 0.12)
const LIGHT := Color(1.0, 0.92, 0.6)
const VOID := Color(0.006, 0.006, 0.014)

enum State { DORMANT, INTRO, IDLE, CLAW_WINDUP, CLAW, RUSH_WINDUP, RUSH, DAZED, SNUFF, LEAP_WINDUP, LEAP, LAND, SUMMON, STAGGER, DYING, DEAD }

@export var hp := 16
@export var walk_speed := 95.0
@export var rush_speed := 640.0
## Radians a second the shield turns towards what it fears.
@export var guard_turn := 3.0
@export var claw_range := 240.0
## Seconds a lit lantern pins it (cowering, no walking or attacks) before it
## lobs an ink glob to put the light out.
@export var snuff_delay := 1.6
## What its claw costs (half ink bottles).
@export var claw_damage := 2.0
@export var stagger_every := 4
@export var max_spawn := 3
## The gutter's tear in the floor (world x) it climbs out of and drags
## Scribbles up through (beast_arena.gd sets it).
@export var gap_x := 0.0
## Shown over its health bar.
var display_name := "THE SCRIBBLED BEAST"

var state := State.DORMANT
var max_hp := 16
var phase_two := false
## World angle the shield faces (from its chest).
var guard := PI
## Intro / outro pose, set by beast_arena.gd: shield lifted over the head
## (0..1), how far each eye is open, the roar.
var shield_lift := 0.0
var eyes_open := [1.0, 1.0, 1.0]
var roar := 0.0
## 0..1: light pouring through the cracking shield, then the unravelling.
var cracks := 0.0
var unravel := 0.0
## Light hitting the shield (0..1): draws the light splashing off it.
var light_on_shield := 0.0
## Intro: the claw hand gripping the lip of the tear (0..1) at `grip_point`
## (world space), as it hauls itself up.
var grip := 0.0
## The lanterns it watches (beast_arena.gd sets them); empty = every lantern.
var arena_lanterns: Array = []
var grip_point := Vector2.ZERO

var _timer := 0.0
var _cd := 2.0
var _walk := 0.0
var _seed := 0
var _lamp_time := 0.0
var _snuff_lamp: Node2D
var _thrown := false
var _struck := false
var _since_hit := 0
var _summon_cd := 4.0
var _leap_cd := 0.0
var _shield_gone := false
var _batch := InkBatch.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	setup(Vector2(110, 210), hp)
	add_to_group("boss")  # the SFX pack's boss_hit on every hit (enemy_base.gd)
	max_hp = hp
	knockback_speed = 30.0
	_seed = randi() % 10000
	outline.fit_margin = 140.0  # the shield and the claws reach far out
	var mat := outline.material as ShaderMaterial
	mat.set_shader_parameter("pop_color", RIM)
	mat.set_shader_parameter("ink_width", 1.5)
	mat.set_shader_parameter("pop_width", 3.0)
	z_index = 2
	if state == State.DORMANT:
		_set_body(false)


## Shows / hides it as a solid, harmful body (dormant in the floor, dying).
func _set_body(on: bool) -> void:
	set_deferred("collision_layer", 4 if on else 0)
	set_harmful(on)


## beast_arena.gd: the intro is over, fight.
func begin_fight() -> void:
	state = State.IDLE
	_cd = 1.2
	shield_lift = 0.0
	eyes_open = [1.0, 1.0, 1.0]
	roar = 0.0
	_set_body(true)
	_update_harm()
	hp_changed.emit(health, max_hp)


## Touching it only hurts while it charges or slams down.
func _update_harm() -> void:
	set_harmful(state in [State.RUSH, State.LEAP])


## Only its charge and its slam hurt to touch (half a bottle); brushing past
## it, or dashing through it, is safe (_update_harm()).
func damage_default() -> float:
	return 1.0


func _physics_process(delta: float) -> void:
	if state in [State.DORMANT, State.INTRO]:
		time += delta
		art.scale.x = facing
		return  # beast_arena.gd moves it
	super(delta)


# ------------------------------------------------------------------ brain

func _tick(delta: float) -> void:
	if state == State.DYING:
		_tick_dying(delta)
		return
	if state == State.DEAD:
		return
	_timer -= delta
	_cd -= delta
	_summon_cd -= delta
	_leap_cd -= delta
	_fall(delta)
	var lamp := _lit_lantern()
	_lamp_time = _lamp_time + delta if lamp else 0.0
	_update_guard(delta, lamp)
	var d := to_player()
	var speed_k := 1.25 if phase_two else 1.0
	match state:
		State.IDLE:
			if lamp:
				# a lit lantern pins it for a moment, cowering behind the shield
				# (no walking, no attacks); then it lobs ink to put the light out
				velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
				if _lamp_time >= snuff_delay / speed_k and is_on_floor():
					_start_snuff(lamp)
			elif _player:
				face_player()
				var want := 0.0
				if absf(d.x) > 170.0 and not hitting_wall():
					want = facing * walk_speed * speed_k
				velocity.x = move_toward(velocity.x, want, 600.0 * delta)
				_walk += absf(velocity.x) * delta * 0.045
				if _cd <= 0.0 and is_on_floor():
					_pick_attack(d)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		State.CLAW_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _timer > 0.2:
				face_player()
			if _timer <= 0.0:
				state = State.CLAW
				_timer = 0.3
				_struck = false
				velocity.x = facing * 260.0
				SfxSynth.play(get_tree(), "whoosh", -4.0, 0.8)
		State.CLAW:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if not _struck and _timer < 0.18:
				_struck = true
				_claw_hit()
			if _timer <= 0.0:
				_recover(0.9)
		State.RUSH_WINDUP:
			velocity.x = move_toward(velocity.x, -facing * 40.0, 600.0 * delta)
			if lamp:
				_recover(0.4)  # the light stops it before it starts
			if fmod(time, 0.12) < delta:
				InkBits.burst(get_tree(), global_position + Vector2(-facing * 30, body_size.y * 0.5), 2, 160.0, Vector2(-facing, -0.4), 0.0)
			if _timer <= 0.0:
				state = State.RUSH
				_timer = 2.6
				pop("GRRAAH!", RED, Vector2(0, -170), 30)
				SfxSynth.play(get_tree(), "roar", -8.0, 1.35)
		State.RUSH:
			velocity.x = facing * rush_speed * speed_k
			guard = 0.0 if facing > 0 else PI
			# it doesn't stop for Vesper: jump it and it slams into the wall
			if hitting_wall():
				_dazed()
			elif lamp:
				velocity.x *= 0.2  # a lantern lit mid-charge stops it dead
				pop("HSSSS!", PALE, Vector2(0, -190), 26)
				_recover(0.4)
			elif _timer <= 0.0:
				velocity.x *= 0.3
				_recover(0.7)
		State.DAZED, State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _timer <= 0.0:
				_recover(0.6)
		State.SNUFF:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if not is_instance_valid(_snuff_lamp) or not _snuff_lamp.lit:
				_recover(0.4)  # the light went out by itself
			elif not _thrown and _timer <= 0.35:
				_thrown = true
				Glob.throw(get_tree(), _hand_world(), _snuff_lamp)
				SfxSynth.play(get_tree(), "whoosh", -6.0, 1.2)
			if _timer <= 0.0:
				_recover(0.5)
		State.LEAP_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _timer <= 0.0:
				state = State.LEAP
				var tx := clampf(d.x, -520.0, 520.0)
				velocity = Vector2(tx / 0.85, -1050.0)
				SfxSynth.play(get_tree(), "roar", -10.0, 1.6)
		State.LEAP:
			if is_on_floor() and velocity.y >= 0.0:
				_land()
		State.LAND:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			if _timer <= 0.0:
				_recover(0.5)
		State.SUMMON:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if not _struck and _timer <= 0.7:
				_struck = true
				_summon()
			if _timer <= 0.0:
				_recover(0.6)
	_update_harm()
	move_and_slide()


func _pick_attack(d: Vector2) -> void:
	var far := absf(d.x)
	if phase_two and _summon_cd <= 0.0 and _spawn_count() < max_spawn:
		state = State.SUMMON
		_timer = 1.4
		_struck = false
		pop("SKRRITCH", PALE, Vector2(0, -190), 26)
	elif phase_two and _leap_cd <= 0.0 and far > 220.0 and randf() < 0.55:
		state = State.LEAP_WINDUP
		_timer = 0.55
		_leap_cd = 3.5
	elif far < claw_range and absf(d.y) < 180.0:
		state = State.CLAW_WINDUP
		_timer = 0.42 if phase_two else 0.55
	elif far > 330.0:
		state = State.RUSH_WINDUP
		_timer = 0.55 if phase_two else 0.7
		SfxSynth.play(get_tree(), "scritch", -6.0, 0.6)
	else:
		_cd = 0.3


func _recover(cooldown: float) -> void:
	state = State.IDLE
	_cd = cooldown * (0.75 if phase_two else 1.0)


func _start_snuff(lamp: Node2D) -> void:
	state = State.SNUFF
	_snuff_lamp = lamp
	_timer = 0.8 if not phase_two else 0.6
	_thrown = false
	var dx: float = lamp.lamp_position().x - global_position.x
	facing = 1 if dx > 0.0 else -1
	pop("HSSSS!", PALE, Vector2(0, -190), 26)


func _dazed() -> void:
	velocity.x = -facing * 160.0
	state = State.DAZED
	_timer = 2.3
	pop("THUNK!", DANGER, Vector2(facing * 40, -120), 34)
	SfxSynth.play(get_tree(), "thud", 0.0)
	InkBits.burst(get_tree(), global_position + Vector2(facing * 55, -20), 24, 420.0, Vector2(-facing, -0.5), 0.5)
	_cam_shake(0.7)


func _land() -> void:
	state = State.LAND
	_timer = 0.7
	velocity.x = 0.0
	SfxSynth.play(get_tree(), "thud", 2.0, 0.8)
	_cam_shake(0.8)
	var feet := global_position + Vector2(0, body_size.y * 0.5)
	InkBits.burst(get_tree(), feet, 30, 480.0, Vector2.UP, 0.3)
	for dir: float in [-1.0, 1.0]:
		var w: CharacterBody2D = Shockwave.new()
		w.dir = dir
		get_tree().current_scene.add_child(w)
		w.global_position = feet + Vector2(dir * 50.0, 0)


## Calls Scribbles out of the gutter it came from: beast_arena.gd cracks the
## gap between the columns open for a moment and they fly out of it.
func _summon() -> void:
	_summon_cd = 11.0
	var at := Vector2(gap_x if gap_x != 0.0 else global_position.x, global_position.y + body_size.y * 0.5 - 260.0)
	var arena := get_tree().get_first_node_in_group("beast_arena")
	if arena:
		arena.crack_gutter(1.6)
	SfxSynth.play(get_tree(), "rip", -2.0)
	InkBits.burst(get_tree(), at, 26, 380.0, Vector2.ZERO, 0.4)
	var scene := load(SCRIBBLE_SCENE) as PackedScene
	for i in mini(2, max_spawn - _spawn_count()):
		var s: Node2D = scene.instantiate()
		s.add_to_group("beast_spawn")
		get_tree().current_scene.add_child(s)
		s.global_position = at + Vector2((i - 0.5) * 60.0, -i * 60.0)


func _spawn_count() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("beast_spawn"):
		if not s.dead:
			n += 1
	return n


## The claw rakes the floor in front: a box from its chest to `claw_range`.
func _claw_hit() -> void:
	_cam_shake(0.35)
	var feet := global_position + Vector2(0, body_size.y * 0.5)
	InkBits.burst(get_tree(), feet + Vector2(facing * 150, -10), 14, 300.0, Vector2(facing, -0.5), 0.2)
	if _player == null or not _player.has_method("take_damage"):
		return
	var rel := _player.global_position - global_position
	if rel.x * facing > -30.0 and absf(rel.x) < claw_range + 30.0 and rel.y > -170.0 and rel.y < 130.0:
		_player.take_damage(claw_damage, global_position)


# ------------------------------------------------------------------ the shield

## The nearest lit lantern it can see (lantern.gd, group "lantern").
func _lit_lantern() -> Node2D:
	var best: Node2D = null
	var best_d := 1500.0
	for l in (arena_lanterns if not arena_lanterns.is_empty() else get_tree().get_nodes_in_group("lantern")):
		if not is_instance_valid(l) or not l.lit:
			continue
		var dd: float = l.lamp_position().distance_to(global_position)
		if dd < best_d:
			best_d = dd
			best = l
	return best


## Turns the shield towards what it fears: a lit lantern, else the raised
## Ember, else Vesper.
func _update_guard(delta: float, lamp: Node2D) -> void:
	var chest := _chest_world()
	var target := chest + Vector2(facing * 100.0, 0.0)
	var lit := false
	if lamp:
		target = lamp.lamp_position()
		lit = true
	elif _player:
		target = _player.global_position + Vector2(0, -10)
		var ember = _player.get("ember")
		if ember and ember.raised and _player.global_position.distance_to(chest) < ember.radius + 160.0:
			lit = true
	var want := (target - chest).angle()
	# never down into the floor
	var v := Vector2.from_angle(want)
	if v.y > 0.45:
		v.y = 0.45
		want = v.angle()
	var turn := guard_turn * (1.35 if phase_two else 1.0)
	guard = rotate_toward(guard, want, turn * delta)
	light_on_shield = move_toward(light_on_shield, 1.0 if lit else 0.0, delta * 4.0)


func _shield_up() -> bool:
	return not _shield_gone and state not in [State.DAZED, State.STAGGER, State.DYING, State.DEAD, State.DORMANT, State.INTRO]


func _blocks(_hit_dir: Vector2, from_pos: Vector2) -> bool:
	if state in [State.DORMANT, State.INTRO, State.DYING, State.DEAD]:
		return true
	if not _shield_up():
		return false
	if not _covers(from_pos):
		return false
	pop(["SCRITCH!", "CLANG!", "SKREE!"].pick_random(), RIM, Vector2(0, -150), 24)
	SfxSynth.play(get_tree(), "clang", -8.0, randf_range(0.85, 1.1))
	InkBits.burst(get_tree(), _shield_world(), 6, 260.0, (from_pos - _shield_world()), 0.0)
	var arena := get_tree().get_first_node_in_group("beast_arena")
	if arena:
		arena.on_blocked()
	return true


## Does the shield cover a hit from `from_pos`? It covers a side, plainly:
## facing up it covers what's above its chest; facing left or right it covers
## everything on that side (so standing inside it, or right behind it, works
## the same every time).
func _covers(from_pos: Vector2) -> bool:
	var g := Vector2.from_angle(guard)
	var rel := from_pos - _chest_world()
	if g.y < -0.75:
		return rel.y < -30.0
	return rel.x * g.x > 0.0


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	var before := health
	super(damage, hit_dir, from_pos)
	if health == before:
		return
	stun = 0.04  # a boss: hits don't stop it in its tracks
	hp_changed.emit(maxi(health, 0), max_hp)
	SfxSynth.play(get_tree(), "splut", -6.0, randf_range(0.8, 1.2))
	InkBits.burst(get_tree(), _chest_world(), 16, 380.0, (_chest_world() - from_pos), 0.4)


func _on_hurt() -> void:
	_since_hit += 1
	if not phase_two and health <= max_hp / 2:
		phase_two = true
		pop("RRAAAGH!", RED, Vector2(0, -200), 40)
		SfxSynth.play(get_tree(), "roar", -2.0, 1.1)
		_cam_shake(0.8)
		state = State.STAGGER
		_timer = 1.2
		_summon_cd = 1.5
		_since_hit = 0
	elif _since_hit >= stagger_every and state not in [State.DAZED, State.STAGGER]:
		_since_hit = 0
		state = State.STAGGER
		_timer = 1.1
		pop("!!", DANGER, Vector2(0, -190), 30)


## No tumbling away like the small monsters: it dies slowly (DYING).
func _die(_kx: float) -> void:
	state = State.DYING
	_timer = 0.0
	velocity = Vector2.ZERO
	_set_body(false)
	for s in get_tree().get_nodes_in_group("beast_spawn"):
		if not s.dead and s.has_method("take_hit"):
			s.take_hit(99, Vector2.UP, s.global_position + Vector2(0, 20))
	SfxSynth.play(get_tree(), "screech", 0.0)


func _tick_dying(delta: float) -> void:
	_timer += delta
	velocity.x = 0.0
	_fall(delta)
	move_and_slide()
	cracks = clampf(_timer / 1.8, 0.0, 1.0)
	if _timer > 0.4 and fmod(_timer, 0.18) < delta:
		InkBits.burst(get_tree(), _chest_world() + Vector2(randf_range(-40, 40), randf_range(-60, 40)), 4, 200.0, Vector2.ZERO, 0.3)
	if _timer >= 1.9 and not _shield_gone:
		_shield_gone = true
		SfxSynth.play(get_tree(), "shatter", 0.0)
		InkBits.burst(get_tree(), _shield_world(), 60, 620.0, Vector2.ZERO, 0.7)
		InkBits.burst(get_tree(), _chest_world(), 80, 560.0, Vector2.UP, 0.4)
		_cam_shake(1.0)
	if _timer >= 1.9:
		unravel = clampf((_timer - 1.9) / 1.4, 0.0, 1.0)
	if _timer >= 3.4 and state != State.DEAD:
		state = State.DEAD
		dead = true
		visible = false
		defeated.emit()


func _cam_shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)


# ------------------------------------------------------------------ geometry

## Feet in world space (the body's origin is its centre).
func _feet() -> Vector2:
	return global_position + Vector2(0, body_size.y * 0.5)


func _chest_world() -> Vector2:
	return _feet() + Vector2(facing * 20.0, -165.0)


func _shield_world() -> Vector2:
	return _chest_world() + Vector2(0, -10) + Vector2.from_angle(guard) * 82.0


func _hand_world() -> Vector2:
	return _feet() + Vector2(-facing * 40.0, -280.0)


# ------------------------------------------------------------------ drawing

func paint(c: CanvasItem) -> void:
	if state == State.DEAD:
		return
	var f := int(time * 12.0)  # 12 fps: the pose and every stroke jump together
	var t := f / 12.0
	_rng.seed = _seed + f * 7919
	var jit := 1.6 if phase_two else 1.0
	if state == State.DYING:
		jit = 2.4
	var k := _anim_k()
	# --- pose
	var crouch := 0.0
	match state:
		State.CLAW_WINDUP, State.RUSH_WINDUP, State.LEAP_WINDUP:
			crouch = 0.6 + 0.4 * k
		State.LAND:
			crouch = 1.0 - k * 0.6
		State.DAZED, State.STAGGER:
			crouch = 0.5
		State.SNUFF:
			crouch = 0.2
		State.IDLE:
			if light_on_shield > 0.5 and absf(velocity.x) < 5.0:
				crouch = 0.35  # cowering behind the shield
	var moving := clampf(absf(velocity.x) / walk_speed, 0.0, 1.0) if state in [State.IDLE, State.RUSH] else 0.0
	var bob := sin(_walk * 2.0) * 4.0 * moving + sin(t * 2.2) * 2.0
	var lean := 0.32 + crouch * 0.25 + (0.25 if state == State.RUSH else 0.0)
	if state in [State.DAZED, State.STAGGER]:
		lean = -0.1 + sin(t * 9.0) * 0.12
	var hip := Vector2(0, -100 + crouch * 26.0 + bob)
	var chest := hip + Vector2(sin(lean), -cos(lean)) * 80.0
	var head_a := chest + Vector2(-12, -60) + Vector2(sin(t * 3.0), cos(t * 2.6)) * 2.0
	var head_b := chest + Vector2(32, -48) + Vector2(cos(t * 2.4), sin(t * 3.4)) * 2.0
	if roar > 0.0:
		head_a += Vector2(-6, -10) * roar
		head_b += Vector2(10, -6) * roar
	var lg := Vector2.from_angle(guard)
	lg.x *= facing  # shield direction in the art's space (it faces +X)
	var shield_hand := chest + Vector2(14, -6) + lg * 64.0
	if shield_lift > 0.0:
		shield_hand = shield_hand.lerp(chest + Vector2(10, -150), shield_lift)
		lg = lg.lerp(Vector2(0.15, -1).normalized(), shield_lift).normalized()
	var shield_down := state in [State.DAZED, State.STAGGER]
	if state == State.DYING:
		# it clings to the shield to the end, held up before it as the light breaks through
		shield_hand = chest + Vector2(40, -10) + Vector2(sin(t * 30.0), cos(t * 27.0)) * 3.0
		lg = Vector2(1, -0.25).normalized()
	var claw_hand := _claw_hand_pos(chest, t, k)
	# --- draw, back to front
	var back := _shield_behind(lg) and not shield_down
	_leg(hip, -1.0, t, moving, crouch, jit)
	if back:
		_shield(shield_hand, lg, t, jit)
	_arm(chest + Vector2(-20, 6), claw_hand, -1.0, jit)
	_claws(claw_hand, (claw_hand - chest).normalized(), 44.0, jit, 5)
	_body(hip, chest, lean, jit)
	_head(head_a, 36.0, 31.0, -0.15, jit, 0, t)
	_head(head_b, 27.0, 32.0, 0.35, jit, 1, t)
	_chest_eye(chest + Vector2(10, 14), jit, t)
	_leg(hip, 1.0, t, moving, crouch, jit)
	if shield_down:
		_shield_dropped(hip, t, jit)
	_arm(chest + Vector2(16, -6), shield_hand if not shield_down else hip + Vector2(70, 60), 1.0, jit)
	if not back and not shield_down:
		_shield(shield_hand, lg, t, jit)
	if state == State.SNUFF and not _thrown:
		_glob_in_hand(claw_hand, jit)
	if state == State.DYING:
		_death_light(chest, t)
	_batch.flush(c)


## 0..1 through the current timed state.
func _anim_k() -> float:
	match state:
		State.CLAW_WINDUP:
			return 1.0 - clampf(_timer / (0.42 if phase_two else 0.55), 0.0, 1.0)
		State.CLAW:
			return 1.0 - clampf(_timer / 0.3, 0.0, 1.0)
		State.RUSH_WINDUP:
			return 1.0 - clampf(_timer / (0.55 if phase_two else 0.7), 0.0, 1.0)
		State.LEAP_WINDUP:
			return 1.0 - clampf(_timer / 0.55, 0.0, 1.0)
		State.LAND:
			return 1.0 - clampf(_timer / 0.7, 0.0, 1.0)
		State.SNUFF:
			return 1.0 - clampf(_timer / (1.0 if not phase_two else 0.75), 0.0, 1.0)
		State.SUMMON:
			return 1.0 - clampf(_timer / 1.4, 0.0, 1.0)
	return 0.0


func _claw_hand_pos(chest: Vector2, t: float, k: float) -> Vector2:
	var shoulder := chest + Vector2(-20, 6)
	match state:
		State.CLAW_WINDUP:
			return shoulder.lerp(shoulder + Vector2(-70, -120), _ease(k))
		State.CLAW:
			var a := lerpf(-2.0, 0.85, _ease(k))
			return shoulder + Vector2.from_angle(a) * 165.0 + Vector2(30, 0)
		State.SNUFF:
			return shoulder + Vector2(-60, -110) + Vector2(sin(t * 20.0), 0) * 3.0 * k
		State.LEAP, State.LEAP_WINDUP:
			return shoulder + Vector2(-40, -100)
		State.SUMMON:
			return shoulder.lerp(Vector2(70, 10), _ease(minf(k * 2.0, 1.0)))
		State.DAZED, State.STAGGER, State.DYING:
			return shoulder + Vector2(-20, 120)
	# idle: hanging long, down to the knees, swaying
	var idle := shoulder + Vector2(-26 + sin(t * 2.0) * 10.0, 116 + cos(t * 1.7) * 6.0)
	if grip > 0.0:
		var g := grip_point - _feet()
		g.x *= facing
		return idle.lerp(g, grip)
	return idle


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _shield_behind(lg: Vector2) -> bool:
	return lg.x < -0.2


func _j(p: Vector2, a: float) -> Vector2:
	return p + Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))


## Unravelling: everything flies apart from the chest and thins out.
func _u(p: Vector2) -> Vector2:
	if unravel <= 0.0:
		return p
	var out := (p - Vector2(10, -170))
	return p + out.normalized() * unravel * unravel * (120.0 + out.length() * 1.5) + Vector2(0, -60.0 * unravel)


func _ink(a := 1.0) -> Color:
	return Color(INK, a * (1.0 - unravel))


## A limb or any path: a thick ink core plus three or four frantic strokes
## over it, each a little off.
func _strokes(path: Array, width: float, jit: float) -> void:
	var core := PackedVector2Array()
	for p in path:
		core.append(_u(_j(p, 1.5 * jit)))
	_batch.draw_polyline(core, _ink(), width)
	for s in 4:
		var line := PackedVector2Array()
		var off := _rng.randf_range(-width, width) * 0.7
		for i in path.size():
			var p: Vector2 = path[i]
			var n := Vector2.ZERO
			if i < path.size() - 1:
				n = (path[i + 1] - p).normalized().orthogonal()
			elif i > 0:
				n = (p - path[i - 1]).normalized().orthogonal()
			line.append(_u(_j(p + n * off, 3.0 * jit)))
		# overshoot past the ends, as a hasty pen does
		if line.size() > 1:
			line[0] = line[0] + (line[0] - line[1]).normalized() * _rng.randf_range(2, 10)
		var col := _ink(0.9) if s < 3 else Color(PENCIL, 0.6 * (1.0 - unravel))
		_batch.draw_polyline(line, col, _rng.randf_range(1.2, 2.6))


## A mass of scribble: a dark jittered core, scribbled through with greys
## (the pen's back-and-forth), wrapped in heavy overshooting loops and bristling
## with hatching strokes, so its edge is all strokes (no solid outline).
func _blob(center: Vector2, rx: float, ry: float, rot: float, jit: float, density := 1.0) -> void:
	var fill := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		var r := _rng.randf_range(0.72, 0.88)
		fill.append(_u(center + Vector2(cos(a) * rx * r, sin(a) * ry * r).rotated(rot)))
	_batch.draw_colored_polygon(fill, _ink())
	# heavy loops: they build the body's edge out of strokes
	for s in int(12 * density):
		var loop := PackedVector2Array()
		var a0 := _rng.randf() * TAU
		var span := _rng.randf_range(1.6, 4.2)
		var rr := _rng.randf_range(0.75, 1.12)
		for i in 11:
			var a := a0 + span * i / 10.0
			var r := rr * _rng.randf_range(0.9, 1.1)
			loop.append(_u(center + Vector2(cos(a) * rx * r, sin(a) * ry * r).rotated(rot) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)) * jit))
		_batch.draw_polyline(loop, _ink(0.95), _rng.randf_range(2.0, 4.2))
	# scratchy back-and-forth inside, in greys that show on the black
	for s in int(16 * density):
		var line := PackedVector2Array()
		var a0 := _rng.randf() * TAU
		var p := center + Vector2(cos(a0) * rx * 0.5, sin(a0) * ry * 0.5).rotated(rot)
		var d := Vector2.from_angle(_rng.randf() * TAU)
		for i in 7:
			d = (-d).rotated(_rng.randf_range(-0.5, 0.5))  # zig-zag
			p += d * rx * _rng.randf_range(0.25, 0.6)
			p = center + ((p - center).rotated(-rot) * Vector2(1.0 / rx, 1.0 / ry)).limit_length(0.85).rotated(rot) * Vector2(rx, ry)
			line.append(_u(p))
		var col := Color(GREY, 0.95) if s % 4 else Color(PENCIL, 0.55)
		_batch.draw_polyline(line, Color(col, col.a * (1.0 - unravel)), _rng.randf_range(0.9, 1.8))
	# hatching bristling off the edge, like fur scratched in
	for s in int(26 * density):
		var a := _rng.randf() * TAU
		var edge := center + Vector2(cos(a) * rx * 0.95, sin(a) * ry * 0.95).rotated(rot)
		var out := (edge - center).normalized().rotated(_rng.randf_range(-0.6, 0.6))
		var ln := _rng.randf_range(6.0, 18.0)
		_batch.draw_line(_u(edge - out * 6.0), _u(edge + out * ln), _ink(0.9), _rng.randf_range(1.0, 2.2))


## Wisps flicking off the body: thin strokes that curl away.
func _wisps(center: Vector2, rx: float, ry: float, count: int, length: float, jit: float, up := -1.0) -> void:
	for s in count:
		var a := _rng.randf_range(PI * 0.9, PI * 2.1) if up < 0.0 else _rng.randf() * TAU
		var p := center + Vector2(cos(a) * rx, sin(a) * ry)
		var dir := Vector2.from_angle(a + _rng.randf_range(-0.5, 0.5))
		var line := PackedVector2Array([_u(p)])
		var curl := _rng.randf_range(-0.5, 0.5)
		for i in 4:
			dir = dir.rotated(curl)
			p += dir * length * _rng.randf_range(0.2, 0.35) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)) * jit
			line.append(_u(p))
		_batch.draw_polyline(line, _ink(0.85), _rng.randf_range(0.9, 1.8))


func _body(hip: Vector2, chest: Vector2, lean: float, jit: float) -> void:
	var mid := (hip + chest) * 0.5
	_blob(mid + Vector2(0, -4), 46.0, 66.0, lean, jit, 1.4)
	_blob(chest + Vector2(-4, -6), 54.0, 34.0, lean * 0.5, jit, 1.0)  # the hunched shoulders
	_wisps(chest + Vector2(-20, -10), 50.0, 30.0, 22, 56.0, jit)
	_wisps(mid, 44.0, 64.0, 8, 30.0, jit, 1.0)
	# ribs of hatching across the belly, ink running off it
	for i in 5:
		var y := mid.y + 10.0 + i * 9.0
		_batch.draw_line(_u(_j(Vector2(mid.x - 26, y), 2.0)), _u(_j(Vector2(mid.x + 24, y - 8), 2.0)), Color(GREY, 0.8 * (1.0 - unravel)), 1.4)
	if _rng.randf() < 0.5:
		var drip := hip + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(0, 10))
		_batch.draw_line(_u(drip), _u(drip + Vector2(0, _rng.randf_range(10, 26))), _ink(0.9), 2.0)


func _head(at: Vector2, rx: float, ry: float, rot: float, jit: float, which: int, t: float) -> void:
	_blob(at, rx, ry, rot, jit, 0.9)
	_wisps(at + Vector2(0, -6), rx, ry, 10, 40.0, jit)
	var open: float = eyes_open[which]
	var look := (to_player().normalized() if _player else Vector2.RIGHT) * Vector2(facing, 1)
	var mouth_open := 0.35 + 0.25 * sin(t * 4.0 + which * 2.0)
	if state in [State.CLAW_WINDUP, State.RUSH_WINDUP, State.LEAP_WINDUP, State.SNUFF]:
		mouth_open = 0.85
	mouth_open = maxf(mouth_open, roar)
	if which == 0:
		_eye(at + Vector2(-8, -6), 12.0 * jitter_scale(), open, look, jit)
		_eye(at + Vector2(16, -9), 9.0, open, look, jit)
		_maw(at + Vector2(6, 16), 50.0, 12.0 + mouth_open * 30.0, -0.1, jit)
	else:
		_eye(at + Vector2(2, -12), 10.0, open, look, jit)
		_eye(at + Vector2(18, -7), 8.0, open, look, jit)
		_maw(at + Vector2(12, 16), 30.0, 14.0 + mouth_open * 36.0, 0.25, jit)


func jitter_scale() -> float:
	return 1.0 + 0.08 * _rng.randf()


## A wide, staring white eye with a pin of a pupil and a scribbled socket.
func _eye(at: Vector2, r: float, open: float, look: Vector2, jit: float) -> void:
	if open <= 0.02 or unravel > 0.6:
		return
	var a := 1.0 - unravel
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		pts.append(_u(at + Vector2(cos(ang) * r, sin(ang) * r * open) + Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8)) * jit))
	_batch.draw_colored_polygon(pts, Color(EYE, a))
	var socket := pts.duplicate()
	socket.append(pts[0])
	_batch.draw_polyline(socket, _ink(), 2.0)
	var pupil := at + look.limit_length(1.0) * r * 0.35
	var red := phase_two or state in [State.CLAW_WINDUP, State.RUSH_WINDUP, State.LEAP_WINDUP]
	if red:
		_batch.draw_circle(_u(pupil), r * 0.42, Color(RED, a))
	_batch.draw_circle(_u(pupil), r * (0.2 if not red else 0.24) * clampf(open * 1.4, 0.3, 1.0), _ink())


## A jagged maw: a dark hole with ragged white teeth top and bottom.
func _maw(at: Vector2, w: float, h: float, rot: float, jit: float) -> void:
	var hole := PackedVector2Array()
	for i in 14:
		var ang := TAU * i / 14.0
		hole.append(_u(at + Vector2(cos(ang) * w * 0.5, sin(ang) * h * 0.5).rotated(rot) + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * jit))
	_batch.draw_colored_polygon(hole, Color(VOID, 1.0 - unravel))
	var n := int(w / 5.0)
	for i in n:
		var x := -w * 0.45 + w * 0.9 * (i + 0.5) / n
		var tw := w * 0.9 / n * 0.5
		var depth := 1.0 - absf(x) / (w * 0.5)
		var top := sqrt(maxf(depth, 0.0)) * h * 0.5
		var tooth := h * _rng.randf_range(0.3, 0.55)
		var col := Color(EYE, 1.0 - unravel)
		_batch.draw_colored_polygon(PackedVector2Array([_u(at + Vector2(x - tw, -top).rotated(rot)), _u(at + Vector2(x + tw, -top).rotated(rot)),
			_u(at + Vector2(x + _rng.randf_range(-1.5, 1.5), -top + tooth).rotated(rot))]), col)
		_batch.draw_colored_polygon(PackedVector2Array([_u(at + Vector2(x - tw, top).rotated(rot)), _u(at + Vector2(x + tw, top).rotated(rot)),
			_u(at + Vector2(x + _rng.randf_range(-1.5, 1.5), top - tooth * 0.8).rotated(rot))]), col)


## The third eye in its chest: the stare of the Margins, ringed by scribble.
func _chest_eye(at: Vector2, jit: float, t: float) -> void:
	for i in 3:
		var loop := PackedVector2Array()
		var r := 19.0 + i * 5.0
		for j in 13:
			var a := TAU * j / 12.0 + i
			loop.append(_u(at + Vector2(cos(a) * r, sin(a) * r * 0.9) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)) * jit))
		_batch.draw_polyline(loop, Color(GREY if i > 0 else INK, 1.0 - unravel), 1.6)
	var look := (to_player().normalized() if _player else Vector2.RIGHT) * Vector2(facing, 1)
	_eye(at, 15.0 + sin(t * 3.0), eyes_open[2], look, jit)


func _leg(hip: Vector2, side: float, t: float, moving: float, crouch: float, jit: float) -> void:
	var ph := _walk + (0.0 if side > 0.0 else PI)
	var hip_l := hip + Vector2(side * 14.0, 4.0)
	var foot := Vector2(side * 32.0 + sin(ph) * 28.0 * moving, -maxf(0.0, -cos(ph)) * 18.0 * moving)
	if state == State.LEAP:
		foot = hip_l + Vector2(side * 20.0, 60.0)
	var knee := (hip_l + foot) * 0.5 + Vector2(22.0, -8.0 + crouch * 10.0)
	var heel := foot + Vector2(-16.0, -20.0)
	_strokes([hip_l, knee, heel, foot], 9.0, jit)
	_claws(foot + Vector2(6, -2), Vector2(1, 0.25), 16.0, jit, 3)


func _arm(shoulder: Vector2, hand: Vector2, side: float, jit: float) -> void:
	var mid := (shoulder + hand) * 0.5
	var bend := (hand - shoulder).orthogonal().normalized() * (28.0 * side)
	if bend.x < 0.0:
		bend = -bend  # elbows jut out the back
	var elbow := mid - bend
	_strokes([shoulder, (shoulder + elbow) * 0.5, elbow, (elbow + hand) * 0.5, hand], 7.0, jit)


## Long hooked talons, scratched in.
func _claws(at: Vector2, dir: Vector2, length: float, jit: float, count := 4) -> void:
	for i in count:
		var spread := (i - (count - 1) * 0.5) * 0.38
		var d := dir.rotated(spread)
		var p := at
		var line := PackedVector2Array([_u(p)])
		for s in 4:
			d = d.rotated(0.28)  # hooking round
			p += d * length * 0.3
			line.append(_u(_j(p, 1.0 * jit)))
		_batch.draw_polyline(line, _ink(), 2.6)
		_batch.draw_polyline(line, Color(PENCIL, 0.5 * (1.0 - unravel)), 1.0)


## The shield: a strip torn out of the gutter, the black between two panels,
## with the panels' white border lines still printed down both long edges and
## both ends torn ragged; crossed out, twice. `lg` is the way its face points.
func _shield(hand: Vector2, lg: Vector2, t: float, jit: float) -> void:
	if _shield_gone:
		return
	var center := hand + lg * 16.0
	var along := lg.orthogonal()
	var half_len := 96.0
	var half_th := 24.0
	_rng.seed = _seed * 3 + int(t * 12.0)
	var P := func(u: float, v: float) -> Vector2:
		# u along the strip (-1..1), v across it (-1 back .. 1 face, which bulges)
		return center + along * (u * half_len) + lg * (v * half_th + 6.0 * (1.0 - u * u) * maxf(v, 0.0))
	var pts := PackedVector2Array()
	for i in 9:  # face edge, end to end
		pts.append(P.call(-0.92 + 1.84 * i / 8.0, 1.0) + lg * _rng.randf_range(-1.5, 1.5))
	for i in 7:  # one torn end
		pts.append(P.call(0.92 + _rng.randf_range(0.0, 0.1) * (1 + i % 2), 1.0 - 2.0 * i / 6.0))
	for i in 9:  # back edge
		pts.append(P.call(0.92 - 1.84 * i / 8.0, -1.0) + lg * _rng.randf_range(-1.5, 1.5))
	for i in 7:  # the other torn end
		pts.append(P.call(-0.92 - _rng.randf_range(0.0, 0.1) * (1 + i % 2), -1.0 + 2.0 * i / 6.0))
	_batch.draw_colored_polygon(pts, VOID)
	# the panels' border lines down both long edges, broken where it tore
	for v: float in [0.62, -0.62]:
		var line := PackedVector2Array()
		for i in 12:
			line.append(_j(P.call(-0.84 + 1.68 * i / 11.0, v), 0.8 * jit))
		_batch.draw_polyline(line.slice(0, 7), Color(RIM, 0.95), 2.4)
		_batch.draw_polyline(line.slice(8, 12), Color(RIM, 0.95), 2.4)
	# crossed out, twice, and scratched
	for sx: float in [-1.0, 1.0]:
		_batch.draw_line(_j(P.call(-0.5, sx * 0.4), 2.0), _j(P.call(0.5, -sx * 0.4), 2.0), Color(GREY, 0.95), 3.0)
	for i in 5:
		var u := _rng.randf_range(-0.7, 0.7)
		_batch.draw_line(P.call(u, 0.3), P.call(u + _rng.randf_range(-0.12, 0.12), -0.3), Color(GREY, 0.6), 1.2)
	var edge := pts.duplicate()
	edge.append(pts[0])
	_batch.draw_polyline(edge, Color(RIM, 0.3), 1.2)
	# the light it keeps off: bright streaks splashing off its face
	if light_on_shield > 0.05:
		for i in 8:
			var su := _rng.randf_range(-0.9, 0.9)
			var from: Vector2 = P.call(su, 1.15)
			var spray := (lg * 0.6 + along * signf(su) * _rng.randf_range(0.5, 1.2)).normalized()
			var ln := _rng.randf_range(20, 64) * light_on_shield
			_batch.draw_line(from, from + spray * ln, Color(LIGHT, 0.8 * light_on_shield), _rng.randf_range(1.5, 3.0))
	# cracks with light breaking through (dying)
	if cracks > 0.0:
		for i in 7:
			var p: Vector2 = P.call(_rng.randf_range(-0.75, 0.75), _rng.randf_range(-0.5, 0.8))
			var line := PackedVector2Array([p])
			var d := (lg + along * _rng.randf_range(-1, 1)).normalized()
			for s in 4:
				d = d.rotated(_rng.randf_range(-0.8, 0.8))
				p += d * 16.0 * cracks
				line.append(p)
			_batch.draw_polyline(line, Color(LIGHT, cracks), 2.0 + cracks * 2.5)


## Dazed or staggered: the shield hangs low, face down to the floor.
func _shield_dropped(hip: Vector2, t: float, jit: float) -> void:
	_shield(hip + Vector2(66, 64), Vector2(0.25, -1).normalized(), t, jit)


func _glob_in_hand(hand: Vector2, jit: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0
		pts.append(hand + Vector2(cos(a), sin(a)) * _rng.randf_range(10, 15) + Vector2(0, -10))
	_batch.draw_colored_polygon(pts, INK)
	_batch.draw_line(hand + Vector2(-4, 0), hand + Vector2(-6, 14 + _rng.randf() * 6), INK, 2.0)


## Dying: the light it hid from bursts out of it in golden rays.
func _death_light(chest: Vector2, t: float) -> void:
	var strength := cracks * (1.0 - unravel)
	if strength <= 0.0:
		return
	var from := chest + Vector2(10, 14)
	for k in 3:
		_batch.draw_circle(from, (30.0 + k * 26.0) * strength, Color(LIGHT, 0.12 * strength))
	for i in 14:
		var a := TAU * i / 14.0 + t * 0.5 + _rng.randf_range(-0.05, 0.05)
		var ln := (140.0 + _rng.randf() * 160.0) * strength
		var spread := 0.07 + 0.05 * _rng.randf()
		_batch.draw_colored_polygon(PackedVector2Array([from + Vector2.from_angle(a - spread) * 12.0, from + Vector2.from_angle(a) * ln,
			from + Vector2.from_angle(a + spread) * 12.0]), Color(LIGHT, 0.6 * strength))
		_batch.draw_line(from, from + Vector2.from_angle(a) * ln * 0.7, Color(1, 1, 1, 0.75 * strength), 2.0)
