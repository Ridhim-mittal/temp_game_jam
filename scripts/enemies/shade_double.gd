extends "res://scripts/enemies/enemy_base.gd"
## Shade's last creation (the final fight, shade_finale.gd): the Writer's
## hand pours itself into the light and steps out as Vesper, the Vesper Shade
## meant to write. It wears Vesper's own body and sword (player_visual.gd,
## sword.tscn), inked black, a blood-red scarf and burning red eyes, and it
## fights with his moves:
##  - SLASH  a glint on the blade (the tell), then a lunging combo of
##           alternating cuts (3, then 4); from further off it rushes in first
##  - DASH   crouches, then a dash-thrust straight through Vesper leaving
##           afterimages, finished with a cut
##  - UPCUT  jumps up at Vesper with a rising cut when he's above it
##  - LEAP   jumps over him and plunges down, shockwaves rolling both ways
##  - WAVE   sweeps an ink wave along the street (two in the second half)
## It sidesteps Vesper's swings now and then. Below half health it rages:
## faster tells, longer combos, more dodges. Light (the Ember) doubles the
## damage it takes. Hits only stagger it while it's not attacking.
## `begin()` starts the fight (the director calls it after the emerge).

signal defeated

const Shockwave = preload("res://scripts/enemies/ink_shockwave.gd")
const VisualScript = preload("res://scripts/player/player_visual.gd")
const SwordScene = preload("res://scenes/player/sword.tscn")
const ClawScript = preload("res://scripts/enemies/ink_claw.gd")
const EYE := Color(1.0, 0.16, 0.2)
const AURA := Color(0.5, 0.02, 0.1)

enum State { INTRO, STALK, SLASH_WIND, SLASH, DASH_WIND, DASH, LEAP, PLUNGE, WAVE_WIND, BACKSTEP, RECOVER, DEFEATED }

@export var hp := 34
@export var display_name := "SHADE"
@export var walk_speed := 230.0
@export var slash_damage := 2.0
@export var dash_damage := 2.0
@export var wave_damage := 2.0
@export var touch_damage := 1.0
@export var dodge_chance := 0.3
## Its sword is longer than Vesper's (and it stands a little taller).
@export var blade_length := 58.0
@export var body_scale := 1.15

var state := State.INTRO
var _timer := 0.0
var _cooldown := 1.0
var _dodge_cd := 0.0
var _combo := 0
var _rage := false
var _iframes := 0.0
var _tell := 0.0  # 0..1 the blade glints before an attack
var _ghosts: Array = []  # dash afterimages {p, facing, age}
var _ghost_t := 0.0
var _waves_left := 0
var _crumble := 0.0
var _cut := 0  # which cut of the combo (they alternate overhead / rising)
var _upcut := false  # the SLASH is a jumping rising cut
var _rush := false  # it ran in before the combo  # 0..1 cracking apart when beaten (shade_finale.gd)

var _vis: CanvasGroup
var _art: Node2D
var _sword: Node2D
var _blade: Area2D
var _fx: Node2D


func _ready() -> void:
	setup(Vector2(26, 52), hp)
	add_to_group("boss")
	knockback_speed = 60.0
	outline.visible = false  # the base's painter isn't used: Vesper's own art is
	# Vesper's body, inked black
	_vis = CanvasGroup.new()
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	mat.set_shader_parameter("pop_color", Color(0.95, 0.12, 0.18))
	mat.set_shader_parameter("ink_width", 2.0)
	mat.set_shader_parameter("pop_width", 5.0)
	_vis.material = mat
	_vis.position = Vector2(0, 26)
	_vis.fit_margin = 14.0
	add_child(_vis)
	_art = Node2D.new()
	_art.name = "Art"
	_art.set_script(VisualScript)
	_art.cloak_color = Color(0.03, 0.02, 0.05)
	_art.cloak_rim = Color(0.42, 0.05, 0.1)
	_art.mask_color = Color(0.16, 0.13, 0.18)
	_art.scarf_color = Color(0.62, 0.03, 0.1)
	_art.hat_color = Color(0.03, 0.02, 0.05)
	_art.band_color = Color(0.85, 0.08, 0.14)
	_art.page_color = Color(0.3, 0.05, 0.08)
	_art.pencil_color = Color(0.25, 0.05, 0.08)
	_art.eye_color = EYE
	_vis.add_child(_art)
	_sword = SwordScene.instantiate()
	_sword.grip_color = Color(0.55, 0.03, 0.08)
	_sword.blade_length = blade_length
	_sword.arm_length = 12.0
	_sword.cloak_color = Color(0.03, 0.02, 0.05)
	_vis.add_child(_sword)
	# the blade's hitbox: on the enemy layer only mid-swing
	_blade = Area2D.new()
	_blade.set_script(ClawScript)
	_blade.collision_layer = 0
	_blade.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(100, 70)
	cs.shape = r
	_blade.add_child(cs)
	add_child(_blade)
	# aura, eye glow and afterimages
	_fx = Node2D.new()
	_fx.top_level = true
	_fx.z_index = -1
	_fx.draw.connect(_paint_fx)
	add_child(_fx)
	set_harmful(false)


## The fight starts (after the emerge from the light).
func begin() -> void:
	state = State.STALK
	_cooldown = 0.8
	set_harmful(true)
	Sfx.play("boss_intro", 0.0, 0.85)


func damage_default() -> float:
	match state:
		State.DASH:
			return dash_damage
		State.PLUNGE:
			return slash_damage
	return touch_damage


func _blocks(_hit_dir: Vector2, _from_pos: Vector2) -> bool:
	if state == State.INTRO or state == State.DEFEATED:
		return true
	if _iframes > 0.0:
		pop("MISS", Color(0.9, 0.8, 1.0), Vector2(0, -60), 20)
		return true
	return false


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	var lit := is_lit()
	super(damage * (2 if lit else 1), hit_dir, from_pos)
	if lit and not dead:
		pop("BURNS!", Color(1.0, 0.92, 0.6), Vector2(0, -70), 22)
	# only staggered when it isn't mid-attack
	stun = 0.12 if state in [State.STALK, State.RECOVER] else 0.0
	_vis.modulate = Color(3, 3, 3)
	create_tween().tween_property(_vis, "modulate", Color.WHITE, 0.15)


func _tick(delta: float) -> void:
	if state == State.INTRO or state == State.DEFEATED:
		velocity.x = 0.0
		_fall(delta)
		move_and_slide()
		return
	if not _rage and health <= hp / 2:
		_rage = true
		dodge_chance = 0.45
		pop("YOU CAN'T BEAT ME. I WROTE YOU.", Color(1.0, 0.3, 0.3), Vector2(0, -90), 26)
		Sfx.play("boss_intro", 0.0, 1.25)
		var cam := get_tree().get_first_node_in_group("camera")
		if cam:
			cam.add_trauma(0.6)
	var k := 1.25 if _rage else 1.0
	delta *= k
	_timer -= delta
	_cooldown -= delta
	_dodge_cd -= delta
	_iframes -= delta
	var d := to_player()
	var dist := absf(d.x)
	_blade_on(state == State.SLASH or state == State.PLUNGE or state == State.DASH)
	match state:
		State.STALK:
			face_player()
			_tell = move_toward(_tell, 0.0, delta * 4.0)
			if _player == null:
				velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			elif _try_dodge(dist):
				pass
			elif d.y < -90.0 and dist < 170.0 and is_on_floor() and _cooldown < 0.2:
				_up_cut()
			elif _cooldown > 0.0:
				# circle at sword's length, never quite still
				var want := 0.0
				if dist > 170.0:
					want = facing * walk_speed
				elif dist < 90.0:
					want = -facing * walk_speed * 0.6
				velocity.x = move_toward(velocity.x, want, 1800.0 * delta)
			else:
				_choose(dist)
			_fall(delta)
		State.SLASH_WIND:
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, (700.0 if _rush else 2000.0) * delta)
			_tell = 1.0
			_fall(delta)
			if _timer <= 0.0:
				state = State.SLASH
				_timer = 0.2
				_rush = false
				velocity.x = facing * 480.0
				# the cuts alternate: overhead down through him, then a rising one
				_sword.swing(Vector2(facing, 0) if _cut % 2 == 0 else Vector2(0, -1))
				_cut += 1
				Sfx.play("sword_swing", 0.0, 0.8)
		State.SLASH:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			_tell = 0.0
			_fall(delta)
			if _timer <= 0.0 and _upcut:
				if is_on_floor() or velocity.y > 0.0:
					_upcut = false
					_recover(0.45)
			elif _timer <= 0.0:
				if _combo > 1:
					_combo -= 1
					state = State.SLASH_WIND
					_timer = 0.16
				else:
					_recover(0.55)
		State.DASH_WIND:
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_tell = 1.0
			_fall(delta)
			if _timer <= 0.0:
				state = State.DASH
				_timer = 0.32
				_iframes = 0.32
				_sword.thrust()  # the dash is a thrust: sword straight out in front
				Sfx.play("dash", 0.0, 0.8)
		State.DASH:
			velocity = Vector2(facing * 960.0, 0.0)
			_tell = 0.0
			_ghost_t -= delta
			if _ghost_t <= 0.0:
				_ghost_t = 0.03
				_ghosts.append({"p": global_position, "f": facing, "age": 0.0})
			if _timer <= 0.0 or hitting_wall():
				if _rage and randf() < 0.45 and not hitting_wall():
					facing = -facing  # straight back through him
					_timer = 0.32
					Sfx.play("dash", 0.0, 0.9)
				else:
					# finish the dash with a cut back at him
					velocity.x = facing * 200.0
					face_player()
					state = State.SLASH_WIND
					_timer = 0.12
					_combo = 1
		State.LEAP:
			_fall(delta)
			if velocity.y > 0.0 and _player and global_position.y < _player.global_position.y - 60.0:
				state = State.PLUNGE
				velocity = Vector2(0, 1250.0)
				_sword.swing(Vector2(0, 1))
				Sfx.play("sword_swing", 0.0, 0.7)
			elif is_on_floor() and velocity.y >= 0.0 and _timer <= 0.0:
				_recover(0.4)
		State.PLUNGE:
			velocity.x = 0.0
			velocity.y = 1250.0
			if is_on_floor():
				_impact()
				_recover(0.6)
		State.WAVE_WIND:
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_tell = 1.0
			_fall(delta)
			if _timer <= 0.0:
				_sword.swing(Vector2(facing, 0))
				_wave()
				_waves_left -= 1
				if _waves_left > 0:
					_timer = 0.35
				else:
					_recover(0.45)
		State.BACKSTEP:
			_fall(delta)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _timer <= 0.0:
				# counter: straight back in, or an ink wave
				if randf() < 0.5:
					state = State.DASH_WIND
					_timer = 0.25
				else:
					state = State.WAVE_WIND
					_timer = 0.25
					_waves_left = 1
		State.RECOVER:
			_tell = 0.0
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			_fall(delta)
			if _timer <= 0.0:
				state = State.STALK
				_cooldown = randf_range(0.15, 0.45) if _rage else randf_range(0.3, 0.7)
	move_and_slide()


func _choose(dist: float) -> void:
	var r := randf()
	if dist < 170.0:
		if r < 0.6:
			_slash()
		elif r < 0.8:
			_leap()
		else:
			_backstep()
	elif dist < 420.0:
		if r < 0.3:
			_dash()
		elif r < 0.6:
			_rush_slash()
		elif r < 0.78:
			_leap()
		else:
			_wave_wind()
	else:
		if r < 0.5:
			_dash()
		else:
			_wave_wind()


func _slash() -> void:
	state = State.SLASH_WIND
	_timer = 0.22 if _rage else 0.3
	_combo = 4 if _rage else 3
	_cut = 0
	pop("!", EYE, Vector2(0, -70), 30)


## From further off: runs in at him and goes straight into the combo.
func _rush_slash() -> void:
	_slash()
	_rush = true
	_timer = 0.34
	velocity.x = facing * 620.0
	Sfx.play("dash", -4.0, 1.2)


## He's above it: it leaps up at him with a rising cut.
func _up_cut() -> void:
	state = State.SLASH
	_upcut = true
	_timer = 0.3
	velocity = Vector2(facing * 120.0, -760.0)
	_sword.swing(Vector2(0, -1))
	Sfx.play("sword_swing", 0.0, 0.9)


func _dash() -> void:
	state = State.DASH_WIND
	_timer = 0.32 if _rage else 0.45


func _leap() -> void:
	state = State.LEAP
	_timer = 0.3
	var dx := to_player().x
	velocity = Vector2(clampf(dx / 0.7, -620.0, 620.0), -900.0)
	Sfx.play("jump", 0.0, 0.8)


func _wave_wind() -> void:
	state = State.WAVE_WIND
	_timer = 0.4
	_waves_left = 2 if _rage else 1


func _backstep() -> void:
	state = State.BACKSTEP
	_timer = 0.35
	_iframes = 0.3
	velocity = Vector2(-facing * 520.0, -220.0)
	Sfx.play("dash", -2.0, 1.1)
	_ghosts.append({"p": global_position, "f": facing, "age": 0.0})


func _try_dodge(dist: float) -> bool:
	if _dodge_cd > 0.0 or dist > 120.0 or not is_on_floor():
		return false
	var sw = _player.get("sword")
	if sw == null or not sw.has_method("is_swinging") or not sw.is_swinging():
		return false
	_dodge_cd = 1.6
	if randf() >= dodge_chance:
		return false
	pop("TOO SLOW.", Color(0.95, 0.4, 0.45), Vector2(0, -70), 20)
	_backstep()
	return true


func _recover(t: float) -> void:
	state = State.RECOVER
	_upcut = false
	_timer = t * (0.65 if _rage else 0.85)


func _impact() -> void:
	Sfx.play("fall_land", 4.0, 0.7)
	pop("SKRASH!", EYE, Vector2(0, -60), 30)
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.add_trauma(0.5)
	var floor_y := global_position.y + body_size.y * 0.5
	for dir in [-1.0, 1.0]:
		var w := Shockwave.new()
		w.direction = dir
		w.damage = wave_damage
		w.range_px = 520.0
		w.position = Vector2(global_position.x + dir * 30.0, floor_y)
		get_tree().current_scene.add_child(w)


func _wave() -> void:
	var w := Shockwave.new()
	w.direction = facing
	w.damage = wave_damage
	w.speed = 560.0
	w.range_px = 900.0
	w.position = Vector2(global_position.x + facing * 40.0, global_position.y + body_size.y * 0.5)
	get_tree().current_scene.add_child(w)
	Sfx.play("sword_swing", 2.0, 0.6)


func _blade_on(on: bool) -> void:
	_blade.damage = slash_damage
	if state == State.PLUNGE:
		_blade.position = Vector2(0, 30)
	elif _upcut:
		_blade.position = Vector2(facing * 24.0, -50.0)
	else:
		_blade.position = Vector2(facing * 52.0, -6.0)
	if on and not _blade.is_in_group("enemy"):
		_blade.collision_layer = 4
		_blade.add_to_group("enemy")
	elif not on and _blade.is_in_group("enemy"):
		_blade.collision_layer = 0
		_blade.remove_from_group("enemy")


func _die(_kx: float) -> void:
	dead = true
	state = State.DEFEATED
	set_harmful(false)
	_blade_on(false)
	set_deferred("collision_layer", 0)
	Sfx.play("boss_hit", 4.0, 0.6)
	defeated.emit()


## Cracking apart with light (0..1), driven by shade_finale.gd's ending.
func crumble(amount: float) -> void:
	_crumble = amount
	_fx.z_index = 2  # the cracks shine over the body


func _process(delta: float) -> void:
	# Vesper's art is fed like player.gd does it
	if state == State.DEFEATED:
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, 900.0)
			move_and_slide()
	_vis.scale = Vector2(facing, 1.0) * body_scale
	_art.velocity = velocity
	_art.facing = facing
	_art.on_floor = is_on_floor()
	_art.dashing = state == State.DASH or state == State.BACKSTEP
	_art.max_speed = 300.0
	_art.crouch = 0.6 if state == State.DASH_WIND else 0.0
	_art.crouching = state == State.DASH_WIND
	_art.land = 1.0 if state == State.DEFEATED else 0.0
	_sword.charge = _tell
	_sword.charge_ready = _tell >= 1.0
	for g in _ghosts:
		g.age += delta
	_ghosts = _ghosts.filter(func(g): return g.age < 0.35)
	_fx.queue_redraw()


func _paint_fx() -> void:
	var t := time
	var feet := global_position + Vector2(0, 26)
	# afterimages: dark red silhouettes of him, fading
	for g in _ghosts:
		var a: float = 0.55 * (1.0 - g.age / 0.35)
		var p: Vector2 = g.p + Vector2(0, 26)
		var f: float = g.f
		_fx.draw_colored_polygon(ell(p + Vector2(0, -16), 13, 18, 12), Color(AURA, a))
		_fx.draw_colored_polygon(ell(p + Vector2(f * 2, -34), 11, 10, 10), Color(AURA, a))
		_fx.draw_colored_polygon(ell(p + Vector2(f * 2, -42), 21, 5, 10), Color(AURA, a))
	if state == State.INTRO and modulate.a <= 0.0:
		return
	# an aura of black ink licking up around him, red at the edges
	var rage := 1.4 if _rage else 1.0
	for k in 7:
		var x := -22.0 + k * 7.3
		var h := (34.0 + 22.0 * absf(sin(t * 5.0 + k * 1.7))) * rage
		var base := feet + Vector2(x, 0)
		var lick := PackedVector2Array([base + Vector2(-7, 0), base + Vector2(sin(t * 6.0 + k) * 6.0, -h), base + Vector2(7, 0)])
		_fx.draw_colored_polygon(lick, Color(AURA, 0.35 * (1.0 - _crumble)))
	_fx.draw_colored_polygon(ell(feet, 34, 7, 16), Color(0.0, 0.0, 0.0, 0.45))
	# burning eyes: a glow round the head
	var head := global_position + Vector2(facing * 4.0, -8.0)
	_fx.draw_circle(head, 16.0 + 3.0 * sin(t * 8.0), Color(EYE, 0.16))
	# cracks of light when it's beaten
	if _crumble > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in int(10 * _crumble) + 1:
			var p := global_position + Vector2(rng.randf_range(-12, 12), rng.randf_range(-20, 24))
			var q := p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
			_fx.draw_line(p, q, Color(1.0, 0.95, 0.75, _crumble), 3.0)
		_fx.draw_circle(global_position, 30.0 + 60.0 * _crumble, Color(1.0, 0.95, 0.8, 0.25 * _crumble))
