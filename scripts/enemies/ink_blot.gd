extends "res://scripts/enemies/enemy_base.gd"
## The Ink Blot (Shade's City): a hulking golem of wet ink with a swirl for a
## head and one glowing yellow eye. Sleeps until Vesper comes near (or hits
## it), then lumbers after him: a claw swipe up close, a ground slam that
## sends shockwaves both ways along the floor (jump them), and globs of ink
## that splash into slowing puddles. Light hardens the ink: lit, it takes
## double damage. When it falls it melts into a puddle and emits `defeated`.

signal defeated

enum State { SLEEP, WAKE, WALK, SWIPE_UP, SWIPE, SLAM_UP, SLAM, SPIT, REST, MELT }

const Shockwave = preload("res://scripts/enemies/ink_shockwave.gd")
const Glob = preload("res://scripts/enemies/ink_glob.gd")
const SWIRL := Color(0.3, 0.24, 0.42)
const SHEEN := Color(0.44, 0.38, 0.62)
const BODY := Color(0.06, 0.04, 0.09)
const SCRAP := Color(0.9, 0.84, 0.74)
const EYE := Color(1.0, 0.86, 0.32)
const RAGE_EYE := Color(1.0, 0.25, 0.2)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

@export var hp := 15
@export var walk_speed := 140.0
@export var wake_range := 420.0
@export var swipe_damage := 2.0
@export var slam_damage := 3.0
@export var touch_damage := 1.0
@export var art_scale := 0.78
## Starts asleep (a gatekeeper); false = awake and hunting at once.
@export var asleep := true
## Shown over its health bar (boss_bar.gd).
@export var display_name := "THE INK BLOT"
## Half ink bottles in the heart it always drops (6 = half of full health) when it melts (it flies to Vesper).
@export var drop_heal := 6.0

var state := State.SLEEP
var _timer := 0.0
var _cooldown := 0.8
var _claw: Area2D
var _arms := 0.0  # 0 rest .. 1 raised for a slam
var _swing := 0.0  # claw swipe
var _melt := 0.0
var _eye_open := 0.0
var _enraged := false
## Taking turns (cave_arena.gd, two Blots): while waiting it backs off to
## `wait_distance`, glows dim, doesn't attack and its touch doesn't hurt.
var waiting := false
var wait_distance := 360.0
## Attacks started since the last turn change (cave_arena.gd counts them).
var attacks_done := 0
var _dim := 0.0
var _slams_left := 0


func _ready() -> void:
	setup(Vector2(100, 150), hp)
	add_to_group("boss")
	knockback_speed = 40.0
	outline.scale = Vector2.ONE * art_scale
	_claw = Area2D.new()
	_claw.collision_layer = 0
	_claw.collision_mask = 0
	_claw.set_script(load("res://scripts/enemies/ink_claw.gd"))
	_claw.damage = swipe_damage
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(110, 90)
	cs.shape = r
	_claw.add_child(cs)
	add_child(_claw)
	if asleep:
		set_harmful(false)
	else:
		state = State.WALK
		_eye_open = 1.0


## Wake up (the gate arena calls this when Vesper walks in).
func wake() -> void:
	if state != State.SLEEP:
		return
	state = State.WAKE
	_timer = 1.0
	Sfx.play("boss_intro")
	pop("GRRAAAH!", Color(0.95, 0.85, 0.4), Vector2(0, -180), 40)
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.add_trauma(0.7)


func damage_default() -> float:
	return slam_damage if state == State.SLAM else touch_damage


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	if state == State.SLEEP:
		wake()
	super(damage * (2 if is_lit() else 1), hit_dir, from_pos)
	stun = 0.0  # a heavyweight: hits don't stagger it


func _tick(delta: float) -> void:
	if not _enraged and health <= hp / 2 and state != State.SLEEP:
		_enraged = true
		pop("RAAARGH!!", Color(1.0, 0.3, 0.25), Vector2(0, -190), 44)
		Sfx.play("boss_intro", 0.0, 1.2)
	var rage := 1.3 if _enraged else 1.0
	delta *= rage  # everything it does speeds up
	_timer -= delta
	_cooldown -= delta
	_fall(delta)
	var d := to_player()
	_claw_active(state == State.SWIPE)
	match state:
		State.SLEEP:
			velocity.x = 0.0
			if _player and absf(d.x) < wake_range and absf(d.y) < 200.0 and not asleep:
				wake()
		State.WAKE:
			_eye_open = move_toward(_eye_open, 1.0, delta * 2.5)
			face_player()
			if _timer <= 0.0:
				state = State.WALK
				set_harmful(true)
		State.WALK:
			face_player()
			var dist := absf(d.x)
			var want := facing * walk_speed if dist > 110.0 else 0.0
			if waiting:
				# its turn is over: hang back and watch, swaying
				want = -facing * walk_speed * 0.8 if dist < wait_distance - 40.0 else 0.0
				if dist > wait_distance + 120.0:
					want = facing * walk_speed * 0.6
			velocity.x = move_toward(velocity.x, want, 500.0 * delta)
			if _player and _cooldown <= 0.0 and is_on_floor() and not waiting:
				if dist < 160.0:
					state = State.SWIPE_UP
					_timer = 0.5
				elif dist < 330.0:
					state = State.SLAM_UP
					_timer = 0.75
					_slams_left = 1 if _enraged else 0
				elif randf() < 0.2:
					state = State.SPIT
					_timer = 0.9
				else:
					_cooldown = 0.8  # keep closing in, think again soon
				if state != State.WALK:
					velocity.x = 0.0
					attacks_done += 1
		State.SWIPE_UP:
			_swing = minf(_swing + delta / 0.5, 1.0) * 0.6
			if _timer <= 0.0:
				state = State.SWIPE
				_timer = 0.22
				velocity.x = facing * 220.0
				pop("SWISH!", Color(0.95, 0.95, 1.0), Vector2(facing * 70.0, -120), 24)
		State.SWIPE:
			_swing = 1.0
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _timer <= 0.0:
				_rest(0.7)
		State.SLAM_UP:
			_arms = minf(_arms + delta / 0.75, 1.0)
			velocity.x = 0.0
			if _timer <= 0.0:
				state = State.SLAM
				_timer = 0.35
				_slam()
		State.SLAM:
			_arms = move_toward(_arms, 0.0, delta * 8.0)
			if _timer <= 0.0:
				if _slams_left > 0:
					_slams_left -= 1  # enraged: up again for a second slam
					state = State.SLAM_UP
					_timer = 0.45
				else:
					_rest(0.6)
		State.SPIT:
			velocity.x = 0.0
			_arms = sin(clampf(1.0 - _timer / 0.9, 0.0, 1.0) * PI) * 0.5
			if _timer <= 0.3 and _timer + delta > 0.3:
				_spit()
			if _timer <= 0.0:
				_rest(0.8)
		State.REST:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_swing = move_toward(_swing, 0.0, delta * 4.0)
			_arms = move_toward(_arms, 0.0, delta * 4.0)
			if _timer <= 0.0:
				state = State.WALK
		State.MELT:
			velocity.x = 0.0
			_melt = minf(_melt + delta / 1.4, 1.0)
	# waiting dims it and makes its touch harmless; its turn brings both back
	if waiting or _dim > 0.0:
		_dim = move_toward(_dim, 1.0 if waiting else 0.0, delta * 3.0)
		modulate = Color.WHITE.lerp(Color(0.5, 0.48, 0.62), _dim)
	if not dead and state != State.SLEEP and state != State.WAKE and state != State.MELT:
		set_harmful(not waiting)
	move_and_slide()


## Its turn in the two-Blot fight (cave_arena.gd).
func take_turn() -> void:
	waiting = false
	attacks_done = 0
	_cooldown = minf(_cooldown, 0.4)
	pop("MY TURN!", Color(1.0, 0.85, 0.3), Vector2(0, -170), 28)


func _rest(t: float) -> void:
	state = State.REST
	_timer = t
	_cooldown = randf_range(0.3, 0.7) if _enraged else randf_range(0.45, 0.9)


func _claw_active(on: bool) -> void:
	_claw.position = Vector2(facing * 70.0, -10.0)
	if on and not _claw.is_in_group("enemy"):
		_claw.collision_layer = 4
		_claw.add_to_group("enemy")
	elif not on and _claw.is_in_group("enemy"):
		_claw.collision_layer = 0
		_claw.remove_from_group("enemy")


func _slam() -> void:
	Sfx.play("fall_land", 4.0, 0.6)
	pop("KRAKOOM!", Color(1.0, 0.86, 0.2), Vector2(0, -170), 40)
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.add_trauma(0.6)
	var floor_y := global_position.y + body_size.y * 0.5
	for dir in [-1.0, 1.0]:
		var w := Shockwave.new()
		w.direction = dir
		w.damage = slam_damage
		w.position = Vector2(global_position.x + dir * 60.0, floor_y)
		get_tree().current_scene.add_child(w)


func _spit() -> void:
	for k in (5 if _enraged else 3):
		var g := Glob.new()
		g.position = global_position + Vector2(facing * 30.0, -110.0)
		var reach := 180.0 + k * (100.0 if _enraged else 130.0)
		g.velocity = Vector2(facing * reach * 0.95, -520.0 + k * 40.0)
		get_tree().current_scene.add_child(g)


func _die(_kx: float) -> void:
	dead = true
	state = State.MELT
	set_harmful(false)
	_claw_active(false)
	set_deferred("collision_layer", 0)
	pop("BLORRP...", Color(0.7, 0.62, 0.9), Vector2(0, -150), 34)
	Sfx.play("ink_splat", 4.0, 0.7)
	defeated.emit()
	var heart_script = load("res://scripts/world/health_heart.gd")  # untyped: calls its static player_full()
	if not heart_script.player_full(get_tree()):  # full ink: no heart to fly in and sit on him
		var heart := Area2D.new()
		heart.set_script(heart_script)
		heart.amount = drop_heal
		heart.seek = true
		heart.position = global_position + Vector2(0, -90)
		get_parent().add_child(heart)
	await get_tree().create_timer(1.6).timeout
	create_tween().tween_property(self, "modulate:a", 0.0, 0.8).finished.connect(queue_free)


func _physics_process(delta: float) -> void:
	if dead and state == State.MELT:
		time += delta
		_melt = minf(_melt + delta / 1.4, 1.0)
		# sag into a spreading puddle (the art is pinned at its feet)
		outline.scale = Vector2(art_scale * (1.0 + _melt * 0.9), art_scale * maxf(1.0 - _melt, 0.06))
		return
	super(delta)


# ------------------------------------------------------------------ art

func paint(c: CanvasItem) -> void:
	var breathe := sin(time * (2.2 if state != State.SLEEP else 1.0)) * 3.0
	var hunch := 14.0 * (1.0 - _eye_open)  # slumped while asleep
	for sx in [-1.0, 1.0]:
		_blob(c, Vector2(sx * 30.0, -26.0), Vector2(24, 30))
		_blob(c, Vector2(sx * 36.0, -6.0), Vector2(26, 9))
	_blob(c, Vector2(0, -96 + breathe * 0.5 + hunch), Vector2(60, 64 + breathe))
	for sx in [-1.0, 1.0]:
		_blob(c, Vector2(sx * 54.0, -122.0 + breathe * 0.3 + hunch), Vector2(28, 25))
	for sx in [-1.0, 1.0]:
		var sh := Vector2(sx * 60.0, -118.0 + hunch)
		var hand := Vector2(sx * 84.0, -40.0 + sin(time * 1.4 + sx) * 3.0)
		# slam: both arms up overhead; swipe: the front arm sweeps forward
		hand = hand.lerp(Vector2(sx * 40.0, -230.0), _arms)
		if sx > 0.0 and _swing > 0.0:
			hand = hand.lerp(Vector2(150.0, -70.0), _swing)
		var elbow := (sh + hand) * 0.5 + Vector2(sx * 16.0, 0)
		c.draw_polyline(PackedVector2Array([sh, elbow, hand]), BODY, 26.0)
		c.draw_circle(elbow, 13.0, BODY)
		_blob(c, hand, Vector2(20, 17))
		for f in 4:
			var base := hand + Vector2(sx * (-14.0 + f * 9.0), 8.0)
			var tip := base + Vector2(sx * (8.0 - f * 4.0), 32.0 - absf(f - 1.5) * 5.0)
			var bend := (base + tip) * 0.5 + Vector2(-sx * 5.0, 0)
			c.draw_colored_polygon(PackedVector2Array([base - Vector2(5, 0), bend - Vector2(2.5, 0), tip,
				bend + Vector2(2.5, 0), base + Vector2(5, 0)]), BODY)
			c.draw_line(bend, tip, SHEEN, 1.5)
		c.draw_arc(sh + Vector2(-sx * 4.0, -6.0), 18.0, -PI * 0.9, -PI * 0.45, 8, SHEEN, 3.0)
	var head := Vector2(4, -158 + breathe + hunch * 1.5)
	_blob(c, head, Vector2(40, 38))
	for k in 3:
		c.draw_arc(head + Vector2(2, 0), 14.0 + k * 9.0, time * 0.8 + k * 1.9, time * 0.8 + k * 1.9 + 3.6, 20, SWIRL, 4.0)
	var eye_col := RAGE_EYE if _enraged else EYE
	if _eye_open > 0.05:
		var eye := head + Vector2(4, 0)
		c.draw_circle(eye, 26.0 * _eye_open, Color(eye_col, 0.16))
		c.draw_circle(eye, 19.0 * _eye_open, Color(eye_col, 0.3))
		c.draw_set_transform(eye, 0.0, Vector2(1.0, _eye_open))
		c.draw_circle(Vector2.ZERO, 14.0, BODY)
		c.draw_circle(Vector2.ZERO, 12.0, eye_col)
		c.draw_circle(Vector2.ZERO, 7.0, eye_col.lightened(0.4))
		c.draw_set_transform(eye + Vector2(1, 0), 0.0, Vector2(0.32, _eye_open))
		c.draw_circle(Vector2.ZERO, 10.0, BODY)
		c.draw_set_transform(Vector2.ZERO)
	else:
		c.draw_line(head + Vector2(-8, 0), head + Vector2(16, 2), EYE.darkened(0.4), 3.0)  # shut
		for k in 3:  # z z z
			var t := fmod(time * 0.5 + k * 0.33, 1.0)
			var p := head + Vector2(30.0 + t * 30.0, -30.0 - t * 50.0)
			c.draw_string(FONT, p, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 + t * 10), Color(0.8, 0.8, 1.0, 1.0 - t))
	c.draw_arc(Vector2(-6, -100 + hunch), 50.0, -PI * 0.9, -PI * 0.65, 10, SHEEN, 3.5)
	for s in [[-34, -104, 0.3], [28, -72, -0.4], [48, -134, 0.7], [-60, -128, -0.2], [-18, -48, 0.5]]:
		c.draw_set_transform(Vector2(s[0], s[1] + hunch), s[2])
		c.draw_rect(Rect2(-6, -5, 12, 10), SCRAP)
		c.draw_set_transform(Vector2.ZERO)
	for k in 4:
		var src: Vector2 = [Vector2(-86, -16), Vector2(88, -16), Vector2(-20, -40), Vector2(24, -36)][k]
		var t := fmod(time * 0.9 + k * 0.37, 1.0)
		var p: Vector2 = src + Vector2(0, t * 40.0)
		c.draw_circle(p, 4.0 * (1.0 - t * 0.5), BODY)
	c.draw_set_transform(Vector2.ZERO)


func _blob(c: CanvasItem, at: Vector2, r: Vector2) -> void:
	var p := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var wob := 1.0 + 0.06 * sin(a * 3.0 + time * 2.0 + at.x * 0.1)
		p.append(at + Vector2(cos(a) * r.x, sin(a) * r.y) * wob)
	c.draw_colored_polygon(p, BODY)
