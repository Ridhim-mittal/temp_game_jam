extends CharacterBody3D
## Scribble: the first thing in the Gutter that wants Vesper gone. A
## vibrating swarm of scratchy pen and pencil loops with angry white eyes
## and a mouth full of teeth (scribble.gdshader: it never stops boiling and
## jittering). From the "IDLE / VIBRATING SWARM" and "ATTACK ACTION (The
## Claw)" sketch sheet. How it fights:
##  - LURK: skitters about where it was drawn, grinning
##  - SHRIEK: it spots Vesper, its jaws snap open ("SKRITCH!")
##  - STALK: it circles him just out of sword reach, in jerky bursts,
##    changing direction now and then
##  - WINDUP: it stops dead, its eyes burn red, it bristles and a red pencil
##    scratch races along the floor where the claw will land (the tell:
##    dash sideways, or out of the line)
##  - CLAW: a sudden shape-shifting reach, `claw_reach` long; only the claw
##    hurts, brushing past the swarm is safe
##  - TANGLED: the arm reels back in slowly and it can't move: the time to
##    hit it
## It hates the light (the design doc: Scribbles flee it). It never steps
## into a monster light (a lit lantern's pool, the raised Ember, the
## Writer's lamp) and backs out of one; its claw still reaches in from the
## edge. Raise the Ember on one that is winding up and it curls up, stunned
## (`light_stun`): a parry. A swarm takes turns: at most `max_attackers` of
## them wind up at once (group "scribble_claw"). Hits knock it back and it
## frays apart into an ink splat. Outside story rooms it scribbles itself
## back into existence a few seconds later.

const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const Lumen = preload("res://scripts/world25/lumen.gd")
const Light = preload("res://scripts/world25/light.gd")
const CLAW_SHADER = preload("res://shaders/clearing/scribble_claw.gdshader")
const AIM_SHADER = preload("res://shaders/clearing/scribble_aim.gdshader")
const RAGE := Color(1.0, 0.3, 0.2)
const ATTACKING := "scribble_claw"

enum State { LURK, CHASE, STUNNED, DEAD, WINDUP, CLAW, SHRIEK, TANGLED }

@export var max_health := 3
@export var wander_speed := 1.4
@export var chase_speed := 3.4
@export var wander_radius := 3.0
@export var sight_range := 7.0
## The distance it circles Vesper at (just outside a sword swing).
@export var keep_distance := 2.6
## Winds up a claw when Vesper is this close.
@export var claw_range := 3.0
## How far the claw reaches from the swarm (the talons go a little further).
@export var claw_reach := 3.0
@export var windup_time := 0.55
@export var claw_out_time := 0.08
@export var claw_hold_time := 0.14
## The arm reels back in this slowly; it can't move meanwhile.
@export var tangle_time := 0.75
@export var claw_cooldown := 1.3
@export var claw_damage := 1  # half ink bottles: small, half a bottle
## Kept for the player's contact check (is_harmful() is always false: only
## the claw hurts).
@export var contact_damage := 1
## At most this many Scribbles wind up or claw at once.
@export var max_attackers := 2
## Seconds it stays curled up when light catches its windup.
@export var light_stun := 1.2
## Coins it drops when beaten (lumen.gd).
@export var lumens := 1
@export var knockback := 9.0
@export var stun_time := 0.3
@export var respawn_time := 5.0
@export var gravity := 30.0

var health := 0
var dead := false
var state := State.LURK

## Seconds before any Scribble may start the next claw (they take turns).
static var _next_claw_ms := 0
static var _shriek_wav: AudioStreamWAV
const SfxSynthBaked = preload("res://scripts/effects/sfx_synth.gd")
static var _swipe_wav: AudioStreamWAV

var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _timer := 0.0
var _time := 0.0
var _squash := Vector3.ONE
var _flash := 0.0
var _player: Node3D
var _claw_cd := 1.0
var _claw_dir := Vector3(1, 0, 0)
var _claw_len := 0.0
var _clawed := false
var _orbit := 1.0
var _orbit_timer := 0.0
var _in_light := false
var _mouth := 0.2
var _rage := 0.0
var _chomp := 0.0
var _floors: Array[Node] = []
var _claw: MeshInstance3D
var _claw_mat: ShaderMaterial
var _aim: MeshInstance3D
var _aim_mat: ShaderMaterial

@onready var visual: MeshInstance3D = $Visual
@onready var _mat: ShaderMaterial = visual.material_override.duplicate()


const DIVER_SCENE := "res://scenes/clearing/monsters/scribble_diver.tscn"


func _ready() -> void:
	# Settings can swap every Scribble for the platformer's flying dive-bomber
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.scribble_style == "diver" and not Engine.is_editor_hint():
		_become_diver.call_deferred()
	add_to_group("enemy")
	visual.material_override = _mat
	var s := randf() * 100.0
	_mat.set_shader_parameter("seed", s)
	_home = global_position
	_time = randf() * 10.0
	_orbit = 1.0 if randf() < 0.5 else -1.0
	if settings and settings.get_value("difficulty") == "hard":
		max_health += 1
		claw_damage += 1
	health = max_health
	_build_claw(s)
	_pick_wander_target()
	_find_floors.call_deferred()


func _build_claw(s: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.5, 0.0, 0.0)
	_claw_mat = ShaderMaterial.new()
	_claw_mat.shader = CLAW_SHADER
	_claw_mat.set_shader_parameter("seed", s)
	_claw = MeshInstance3D.new()
	_claw.name = "Claw"
	_claw.mesh = quad
	_claw.material_override = _claw_mat
	_claw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_claw.extra_cull_margin = claw_reach + 2.5  # the shader moves the quad's corners
	_claw.position = Vector3(0, 0.8, 0)
	_claw.visible = false
	add_child(_claw)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 0.45)
	plane.center_offset = Vector3(0.5, 0.0, 0.0)
	_aim_mat = ShaderMaterial.new()
	_aim_mat.shader = AIM_SHADER
	_aim_mat.set_shader_parameter("seed", s)
	_aim = MeshInstance3D.new()
	_aim.name = "Tell"
	_aim.mesh = plane
	_aim.material_override = _aim_mat
	_aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim.position = Vector3(0, 0.04, 0)
	_aim.visible = false
	add_child(_aim)


## The islands it stands on, so it never circles off an edge.
func _find_floors() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for n in scene.find_children("*", "Node3D", true, false):
		if n.has_method("contains"):
			_floors.append(n)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if global_position.y < _home.y - 8.0:
		_die()  # fell into the void
		return
	_player = get_tree().get_first_node_in_group("player")
	if _player and "dead" in _player and _player.dead:
		_player = null
	_timer -= delta
	_claw_cd -= delta
	_orbit_timer -= delta
	var was_lit := _in_light
	_in_light = Light.is_lit(get_tree(), global_position + Vector3(0, 0.5, 0), true)
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var to := _player.global_position - global_position if _player else Vector3.ZERO
	to.y = 0.0
	if _in_light and not was_lit:
		_flinch()
	match state:
		State.LURK:
			var w := _wander_target - global_position
			w.y = 0.0
			if w.length() < 0.3 or _timer <= 0.0:
				_pick_wander_target()
			planar = planar.move_toward(w.normalized() * wander_speed * _skitter(), 14.0 * delta)
			if _sees_player():
				state = State.SHRIEK
				_timer = 0.45
				_squash = Vector3(0.75, 1.35, 0.75)
				Fx.pop_text(get_tree(), global_position + Vector3(0, 1.6, 0), "SKRITCH!", RAGE, 30)
				_play(_shriek(), -4.0, randf_range(0.9, 1.15))
		State.SHRIEK:
			planar = planar.move_toward(Vector3.ZERO, 30.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE
		State.CHASE:
			if _player == null or to.length() > sight_range * 1.6:
				state = State.LURK
			else:
				planar = planar.move_toward(_stalk(to) * _skitter(), 22.0 * delta)
				if to.length() < claw_range and _claw_cd <= 0.0 and not _in_light and _may_claw():
					_start_windup(to)
		State.WINDUP:
			planar = planar.move_toward(Vector3.ZERO, 30.0 * delta)
			# tracks him, then locks for the last third
			if _timer > windup_time * 0.35 and to.length() > 0.05:
				_claw_dir = _claw_dir.slerp(to.normalized(), 1.0 - exp(-12.0 * delta)).normalized()
			_aim_at(_claw_dir)
			_aim_mat.set_shader_parameter("amount", clampf(1.0 - _timer / windup_time, 0.0, 1.0) * 1.15)
			if _timer <= 0.0:
				state = State.CLAW
				_timer = claw_out_time + claw_hold_time
				_clawed = false
				_aim.visible = false
				_claw.visible = true
				_squash = Vector3(1.3, 0.8, 1.3)
				_play(_swipe(), -3.0, randf_range(0.9, 1.1))
		State.CLAW:
			planar = Vector3.ZERO
			var t := 1.0 - _timer / (claw_out_time + claw_hold_time)
			var out := clampf(t * (claw_out_time + claw_hold_time) / claw_out_time, 0.0, 1.0)
			_claw_len = claw_reach * (1.0 - pow(1.0 - out, 3.0))
			if not _clawed and out > 0.6:
				_claw_hits()
			if _timer <= 0.0:
				state = State.TANGLED
				_timer = tangle_time
				_end_turn()
		State.TANGLED:
			planar = planar.move_toward(Vector3.ZERO, 30.0 * delta)
			_claw_len = claw_reach * clampf(_timer / tangle_time, 0.0, 1.0)
			if _timer <= 0.0:
				_claw.visible = false
				_claw_len = 0.0
				state = State.CHASE if _player else State.LURK
				_claw_cd = claw_cooldown * randf_range(0.8, 1.25)
		State.STUNNED:
			planar = planar.move_toward(Vector3.ZERO, 28.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE if _player else State.LURK
	# it never steps into the light: it backs out of it instead
	if _in_light and state in [State.LURK, State.CHASE, State.SHRIEK]:
		var src := Light.light_at(get_tree(), global_position + Vector3(0, 0.5, 0), true) as Node3D
		if src:
			var away := global_position - src.global_position
			away.y = 0.0
			if away.length() < 0.05:
				away = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
			planar = planar.move_toward(away.normalized() * chase_speed, 40.0 * delta)
	planar = _keep_on_floor(planar)
	velocity.x = planar.x
	velocity.z = planar.z
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## Circles Vesper at `keep_distance`: in, out, and round him.
func _stalk(to: Vector3) -> Vector3:
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	var n := to / dist
	if _orbit_timer <= 0.0:
		_orbit_timer = randf_range(1.2, 2.8)
		if randf() < 0.45:
			_orbit = -_orbit
	var radial := n * clampf((dist - keep_distance) * 1.6, -1.0, 1.0)
	var circle := Vector3(-n.z, 0.0, n.x) * _orbit * (0.85 if dist < keep_distance + 1.5 else 0.25)
	var v := radial + circle
	# would the next step be inside a monster light? don't
	var next := global_position + v.normalized() * 0.9 + Vector3(0, 0.5, 0)
	if Light.is_lit(get_tree(), next, true):
		_orbit = -_orbit
		v = radial * 0.5 - circle
		if Light.is_lit(get_tree(), global_position + v.normalized() * 0.9 + Vector3(0, 0.5, 0), true):
			v = Vector3.ZERO
	return v.limit_length(1.0) * chase_speed


## Jerky, insect-like bursts: quick dashes and dead stops.
func _skitter() -> float:
	var ph := fmod(_time * 2.3, 1.0)
	return 1.45 if ph < 0.55 else 0.2


## Keeps it from walking off an island edge (it turns round instead).
func _keep_on_floor(planar: Vector3) -> Vector3:
	if _floors.is_empty() or planar.length() < 0.1 or not is_on_floor():
		return planar
	var ahead := global_position + planar.normalized() * 0.8
	for f in _floors:
		if is_instance_valid(f) and f.contains(Vector2(ahead.x, ahead.z)):
			return planar
	_orbit = -_orbit
	_pick_wander_target()
	var home := _home - global_position
	home.y = 0.0
	return home.normalized() * planar.length() * 0.6


## Is it this one's turn? (At most `max_attackers` at once, and a beat
## between claws.)
func _may_claw() -> bool:
	if Time.get_ticks_msec() < _next_claw_ms:
		return false
	return get_tree().get_nodes_in_group(ATTACKING).size() < max_attackers


func _start_windup(to: Vector3) -> void:
	state = State.WINDUP
	_timer = windup_time
	_claw_dir = to.normalized()
	add_to_group(ATTACKING)
	_next_claw_ms = Time.get_ticks_msec() + 350
	_claw.visible = false
	_aim.visible = true
	_aim_at(_claw_dir)
	_aim_mat.set_shader_parameter("amount", 0.0)
	_play(_shriek(), -9.0, randf_range(1.3, 1.5))


func _end_turn() -> void:
	remove_from_group(ATTACKING)


func _aim_at(dir: Vector3) -> void:
	var b := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	_aim.basis = b.scaled(Vector3(claw_reach + 0.5, 1.0, 1.0))
	_claw.basis = b


## The claw hits Vesper if he's along it (and not jumping clear over it, or
## dashing through it: the player skips damage mid-dash).
func _claw_hits() -> void:
	_clawed = true
	if _player == null or not _player.has_method("take_damage"):
		return
	var rel := _player.global_position - global_position
	if absf(rel.y) > 1.3:
		return
	rel.y = 0.0
	var along := clampf(rel.dot(_claw_dir), 0.0, claw_reach + 0.4)
	if (rel - _claw_dir * along).length() < 0.6:
		_player.take_damage(claw_damage, global_position)


## Light just caught it: it hisses, and a windup is broken off (a parry).
func _flinch() -> void:
	if dead or state in [State.CLAW, State.TANGLED, State.STUNNED]:
		return
	_squash = Vector3(1.3, 0.65, 1.3)
	if state == State.WINDUP:
		_cancel_attack()
		state = State.STUNNED
		_timer = light_stun
		_flash = 0.8
		Fx.pop_text(get_tree(), global_position + Vector3(0, 1.6, 0), "HSSSS!", Color(1.0, 0.85, 0.45), 30)
	elif state == State.CHASE:
		Fx.pop_text(get_tree(), global_position + Vector3(0, 1.5, 0), "hss!", Color(0.9, 0.85, 0.75), 22)


func _cancel_attack() -> void:
	_end_turn()
	_aim.visible = false
	_claw.visible = false
	_claw_len = 0.0


func _process(delta: float) -> void:
	if dead:
		return
	_time += delta
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob := sin(_time * 5.0) * 0.05 + absf(sin(_time * 11.0)) * clampf(speed / chase_speed, 0.0, 1.0) * 0.08
	_squash = _squash.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
	visual.position.y = 0.95 + bob
	visual.scale = _squash
	_flash = maxf(_flash - delta * 6.0, 0.0)
	# the face: a grin that chomps now and then, jaws wide when it hunts
	_chomp -= delta
	var want_mouth := 0.18
	var want_rage := 0.0
	match state:
		State.LURK:
			if _chomp <= 0.0:
				_chomp = randf_range(0.8, 2.2)
			want_mouth = 0.55 if _chomp < 0.15 else 0.15
		State.SHRIEK:
			want_mouth = 1.0
		State.CHASE:
			want_mouth = 0.45 + 0.2 * sin(_time * 9.0)
		State.WINDUP:
			var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
			want_mouth = 0.6 + 0.4 * k
			want_rage = 0.4 + 0.6 * k
			visual.scale *= Vector3(1.0 + 0.12 * k, 1.0 - 0.08 * k, 1.0)
		State.CLAW:
			want_mouth = 1.0
			want_rage = 1.0
		State.TANGLED:
			want_mouth = 0.25
			want_rage = 0.2
		State.STUNNED:
			want_mouth = 0.1
	_mouth = move_toward(_mouth, want_mouth, delta * 8.0)
	_rage = move_toward(_rage, want_rage, delta * 6.0)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("mouth", _mouth)
	_mat.set_shader_parameter("rage", _rage)
	_mat.set_shader_parameter("jitter", 0.05 if state == State.STUNNED else 0.025)
	if _player:
		var to := _player.global_position - global_position
		_mat.set_shader_parameter("look", Vector2(clampf(to.x * 0.3, -1, 1), clampf(-to.z * 0.3, -1, 1)))
	if _claw.visible:
		_claw.position.y = visual.position.y - 0.2
		_claw_mat.set_shader_parameter("reach", maxf(_claw_len, 0.05))
		_claw_mat.set_shader_parameter("streak", 1.0 if state == State.CLAW else 0.0)


func _become_diver() -> void:
	var diver: Node3D = load(DIVER_SCENE).instantiate()
	diver.transform = transform
	diver.respawn_time = respawn_time
	diver.sight = sight_range + 1.0
	var parent := get_parent()
	var at := get_index()
	var keep := name
	parent.remove_child(self)
	diver.name = keep
	parent.add_child(diver)
	parent.move_child(diver, at)
	queue_free()


## Only the claw hurts (_claw_hits()): brushing past the swarm is safe.
func is_harmful() -> bool:
	return false


func on_flash(_from: Vector3) -> void:
	if dead:
		return
	_cancel_attack()
	state = State.STUNNED
	_timer = 1.4
	_flash = 1.0


func _sees_player() -> bool:
	return _player != null and global_position.distance_to(_player.global_position) < sight_range


func _pick_wander_target() -> void:
	var a := randf() * TAU
	_wander_target = _home + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.5, wander_radius)
	_timer = randf_range(1.5, 3.5)


## Stunned for at least `seconds` (the weapons' specials: clearing_player.gd).
func stun_for(seconds: float) -> void:
	if dead:
		return
	if state == State.STUNNED:
		_timer = maxf(_timer, seconds)
	else:
		_cancel_attack()
		state = State.STUNNED
		_timer = seconds


## How long it stays stunned (0 = not), like monster_3d.gd's `stun`.
func stunned_for() -> float:
	return maxf(_timer, 0.0) if state == State.STUNNED else 0.0


func take_hit(damage: int, dir: Vector3, _aerial := false) -> void:
	if dead:
		return
	health -= damage
	Sfx.play("boss_hit" if is_in_group("boss") else "ink_enemy_hit", -3.0)
	_flash = 1.0
	_squash = Vector3(1.35, 0.7, 1.35)
	# light hits only nudge it, so a combo keeps connecting; the finisher
	# (damage > 1) sends it flying. Tangled up in its own claw, it barely
	# moves at all.
	var push := (1.0 if damage > 1 else 0.45) * (0.4 if state == State.TANGLED else 1.0)
	velocity = Vector3(dir.x, 0.0, dir.z).normalized() * knockback * push
	_cancel_attack()
	state = State.STUNNED
	_timer = stun_time
	if health <= 0:
		_die()


func _die() -> void:
	dead = true
	Sfx.play("ink_splat")
	_cancel_attack()
	state = State.DEAD
	remove_from_group("enemy")
	collision_layer = 0
	Fx.splat(get_tree(), global_position)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.7, 0), Color(0.05, 0.03, 0.08), 22, 5.0)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.7, 0), Color(0.85, 0.82, 0.78), 6, 3.0)
	if global_position.y > _home.y - 4.0:
		Lumen.spill(get_tree(), global_position, lumens)  # not when it fell into the void
	_mat.set_shader_parameter("mouth", 1.0)
	var t := create_tween()
	t.tween_method(func(v: float): _mat.set_shader_parameter("fray", v), 0.0, 1.0, 0.35)
	t.parallel().tween_property(visual, "scale", Vector3(1.5, 1.2, 1.5), 0.35)
	t.tween_callback(func(): visual.visible = false)
	if respawn_time <= 0.0:
		return
	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	health = max_health
	state = State.LURK
	_mat.set_shader_parameter("fray", 0.0)
	visual.visible = true
	visual.scale = Vector3(0.1, 0.1, 0.1)
	_squash = Vector3(0.1, 0.1, 0.1)
	dead = false
	collision_layer = 4
	add_to_group("enemy")
	_pick_wander_target()


func _exit_tree() -> void:
	_end_turn()


# ------------------------------------------------------------------ sound

func _play(stream: AudioStream, db: float, pitch: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"  # Sfx.BUS: every sound effect shares one, quieter than the music
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## A pen scratching hard across paper, rising into a screech.
static func _shriek() -> AudioStreamWAV:
	if _shriek_wav == null:
		_shriek_wav = SfxSynthBaked.baked("scribble_shriek")
	if _shriek_wav == null:
		_shriek_wav = _make_shriek()
	return _shriek_wav


## Made in code (tools/sfx/bake_synth.gd bakes it).
static func _make_shriek() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var f := func(t: float) -> float:
		var env := minf(t / 0.02, 1.0) * exp(-t * 5.0)
		var scratch := rng.randf_range(-1.0, 1.0) * (0.55 + 0.45 * sin(TAU * 38.0 * t))
		var screech := sin(TAU * (900.0 + 1400.0 * t) * t + 3.0 * sin(TAU * 61.0 * t))
		return (scratch * 0.55 + screech * 0.3) * env
	return _wav(0.42, f)


## The claw: a fast tearing swish.
static func _swipe() -> AudioStreamWAV:
	if _swipe_wav == null:
		_swipe_wav = SfxSynthBaked.baked("scribble_swipe")
	if _swipe_wav == null:
		_swipe_wav = _make_swipe()
	return _swipe_wav


## Made in code (tools/sfx/bake_synth.gd bakes it).
static func _make_swipe() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var last := [0.0]
	var f := func(t: float) -> float:
		var env := minf(t / 0.01, 1.0) * exp(-t * 16.0)
		# noise through a rising one-pole filter: shhhk
		var k := clampf(0.15 + t * 3.5, 0.0, 0.9)
		last[0] = lerpf(last[0], rng.randf_range(-1.0, 1.0), k)
		return last[0] * env * 0.9
	return _wav(0.22, f)


static func _wav(length: float, sample: Callable) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = sample.call(float(i) / rate)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
