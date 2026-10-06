extends "res://scripts/clearing/monster_3d.gd"
## The Red Pen: the Writer's editor, boss of the Drowned Margin. It floats
## out of reach above the page and corrects Vesper like a typo. Its body is
## lacquered: swings CLINK off it, except while its nib is stuck in the
## ground (STUCK) or it is dazzled (phase 2).
##  - CIRCLE: rings Vesper in wet red ink (follows her, then locks), then
##    stabs the stab point. Wet ink DRIES in the Writer's kind of light (your
##    Flash, a lit lantern, the searchlight): a dried circle can't hold the
##    nib, so the stab misses and the nib sticks fast for longer.
##  - STRIKE-THROUGH: a dashed line through Vesper, then the pen slashes
##    down it (jump or dash through it). What it strikes out comes alive:
##    a Crossed-Out crawls out of the ink.
##  - phase 2 (half health, "RED-LINED"): circles come in threes, strikes
##    aim through your lit lanterns and snuff them ("CORRECTED!"), and it
##    writes "NO." around you: three solid letters of wet ink that box you
##    in before a circle. A Flash melts them. A Flash, or a lit lantern
##    under it, also DAZZLES the pen: it drops, eye shut, open to hits.

enum State { HOVER, AIM, STAB, STUCK, STRIKE, WRITE, DAZZLED }  # same order as the 2D art (red_pen.gd)

const Mark = preload("res://scripts/clearing/red_mark.gd")
const Letter = preload("res://scripts/clearing/no_letter.gd")
const CROSSED_OUT := "res://scenes/clearing/monsters/crossed_out.tscn"
const RED := Color(0.95, 0.15, 0.18)

## Where it may fly: the room's floor, in room coordinates (x, z).
@export var arena := Rect2(-9.0, -6.5, 18.0, 13.0)
@export var hover_height := 2.6
@export var aim_time := 1.3
@export var stuck_time := 1.5
## Stuck time after stabbing a dried circle.
@export var dried_stuck_time := 2.6
@export var circle_radius := 1.7
@export var strike_aim_time := 1.0
@export var strike_time := 0.45
@export var dazzle_time := 2.4
@export var dazzle_cooldown := 6.0
@export var max_drafts := 2

var state := State.HOVER
var phase2 := false

var _timer := 1.8
var _ground := 0.0
var _tilt := 0.6
var _mark: Node3D
var _circles_left := 0
var _last_attack := ""
var _strike_a := Vector3.ZERO
var _strike_b := Vector3.ZERO
var _strike_hit := false
var _dazzle_cd := 0.0
var _drafts: Array = []
var _letters: Array = []
var _shadow: MeshInstance3D


func _ready() -> void:
	light_immune = true  # the Writer's lamps never burn his own pen
	lumens = 30
	hp = maxi(hp, 18)
	sight = 40.0
	knockback = 0.0
	contact_damage = 2  # one ink bottle
	respawn_time = 0.0
	setup_monster("res://scenes/enemies/red_pen.tscn", 384, 40)
	flying = true
	collision_mask = 0  # flies over everything; heights are set by hand
	_ground = global_position.y
	global_position.y = _ground + hover_height
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.01
	_shadow.mesh = disc
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.03, 0.02, 0.06, 0.45)
	_shadow.material_override = m
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


# ------------------------------------------------------------------- brain

func _tick(delta: float) -> void:
	_timer -= delta
	_dazzle_cd -= delta
	_drafts = _drafts.filter(func(d): return is_instance_valid(d) and not d.dead)
	if not phase2 and float(health) <= hp * 0.5:
		_enter_phase2()
	if _player:
		face_dir(to_player())
	if phase2 and _dazzle_cd <= 0.0 and state in [State.HOVER, State.AIM, State.WRITE] and _lantern_under():
		_dazzle("DAZZLED!")
	match state:
		State.HOVER:
			_tilt_to(0.6 + sin(time * 1.3) * 0.15, delta)
			var want := _hover_spot()
			_fly_to(want, 4.5 if phase2 else 3.5, delta)
			if _timer <= 0.0 and _player:
				_pick_attack()
		State.AIM:
			_tilt_to(0.0, delta)
			var total := aim_time * (0.6 if _circles_left < 2 and phase2 else 1.0)
			if is_instance_valid(_mark):
				if _timer > total * 0.4 and _player:
					_mark.place(_player.global_position)  # follows, then locks on
				_mark.progress = 1.0 - _timer / total
				_fly_to(_mark.global_position + Vector3(0, hover_height + 0.2, 0), 9.0, delta)
			if _timer <= 0.0:
				state = State.STAB
				pop("STAB!", RED, 3.5, 32)
		State.STAB:
			var target: Vector3 = (_mark.global_position if is_instance_valid(_mark) else global_position) + Vector3(0, -0.35, 0)
			target.y = _ground - 0.35
			velocity = (target - global_position).normalized() * 24.0
			if global_position.distance_to(target) < 0.5:
				_impact(target)
		State.STUCK:
			velocity = Vector3.ZERO
			_tilt_to(0.0, delta)
			if _timer <= 0.0:
				pop("SHLUCK!", PALE, 2.2, 26)
				if _circles_left > 0 and is_instance_valid(_player):
					_start_circle(aim_time * 0.6)
				else:
					_to_hover(1.6 if phase2 else 2.2)
		State.STRIKE:
			_update_strike(delta)
		State.WRITE:
			_tilt_to(0.5 + sin(time * 18.0) * 0.25, delta)  # scribbling
			if _player:
				_fly_to(_player.global_position + Vector3(0, hover_height + 0.2, 0), 6.0, delta)
			if _timer <= 0.0:
				_write_no()
				_circles_left = 1
				_start_circle(aim_time * 0.85)
		State.DAZZLED:
			_tilt_to(1.45, delta)
			_fly_to(Vector3(global_position.x, _ground + 0.05, global_position.z), 10.0, delta)
			if _timer <= 0.0:
				pop("HMPH.", PALE, 2.0, 24)
				_to_hover(1.0)


func _process(delta: float) -> void:
	super(delta)
	if _shadow and not dead:
		var h := clampf((global_position.y - _ground) / hover_height, 0.0, 1.5)
		_shadow.global_position = Vector3(global_position.x, _ground + 0.04, global_position.z)
		_shadow.scale = Vector3.ONE * (1.1 - 0.35 * h)


func _pick_attack() -> void:
	var options := ["circle", "circle", "strike"]
	if phase2:
		options = ["circle", "strike", "write"]
	options.erase(_last_attack)  # never the same thing twice in a row
	var pick: String = options.pick_random()
	_last_attack = pick
	match pick:
		"circle":
			_circles_left = 3 if phase2 else 1
			_start_circle(aim_time)
		"strike":
			_start_strike()
		"write":
			state = State.WRITE
			_timer = 0.8
			pop("NO.", RED, 3.6, 40)


func _to_hover(wait: float) -> void:
	state = State.HOVER
	_timer = wait


func _enter_phase2() -> void:
	phase2 = true
	puppet.figure.rage = 1.0
	pop("RED-LINED!", RED, 3.8, 40)
	_shake(0.6)
	var room := get_tree().current_scene
	if room and "ui" in room and room.ui:
		room.ui.caption("Every line. Every single line. WRONG.", "shaky")
		room.ui.caption("Light blinds it now. Get it under a lantern.")


# ------------------------------------------------------------------ circle

func _start_circle(t: float) -> void:
	_clear_mark()
	_circles_left -= 1
	state = State.AIM
	_timer = t
	_mark = Mark.new()
	_mark.radius = circle_radius
	get_tree().current_scene.add_child(_mark)
	var at: Vector3 = _player.global_position if _player else global_position
	_mark.global_position = Vector3(at.x, _ground + 0.06, at.z)


func _impact(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	var wet: bool = is_instance_valid(_mark) and _mark.wet
	Fx.splat(get_tree(), Vector3(at.x, _ground, at.z), 1.4)
	_shake(0.5)
	if wet:
		pop("SKRITCH!", RED, 2.4, 30)
		if _player and _flat(_player.global_position, at) < circle_radius + 0.25:
			_player.take_damage(2, at)
		state = State.STUCK
		_timer = stuck_time * (0.45 if _circles_left > 0 else 1.0)
	else:
		# the nib skids on dried ink and buries itself: the big opening
		pop("STUCK!", Color(1.0, 0.85, 0.5), 2.6, 36)
		_circles_left = 0
		state = State.STUCK
		_timer = dried_stuck_time
	if is_instance_valid(_mark):
		_mark.fade_out()
	_mark = null


# ------------------------------------------------------------------ strike

func _start_strike() -> void:
	_clear_mark()
	state = State.STRIKE
	_timer = strike_aim_time
	_strike_hit = false
	var p: Vector3 = _player.global_position
	var dir := Vector3.RIGHT.rotated(Vector3.UP, randf() * PI)
	if phase2:
		var lamp := _nearest_lit_lantern(p)
		if lamp and _flat(lamp.global_position, p) > 0.5:
			dir = Vector3(lamp.global_position.x - p.x, 0, lamp.global_position.z - p.z).normalized()
	_strike_a = _clamp_arena(p - dir * 7.0)
	_strike_b = _clamp_arena(p + dir * 7.0)
	if _strike_a.distance_to(_strike_b) < 5.0:  # squashed into a corner: turn it
		dir = Vector3(-dir.z, 0, dir.x)
		_strike_a = _clamp_arena(p - dir * 7.0)
		_strike_b = _clamp_arena(p + dir * 7.0)
	_strike_a.y = _ground + 0.06
	_strike_b.y = _ground + 0.06
	_mark = Mark.new()
	_mark.kind = Mark.Kind.LINE
	_mark.can_dry = false
	get_tree().current_scene.add_child(_mark)
	_mark.global_position = _strike_a
	_mark.a = _strike_a
	_mark.b = _strike_b


func _update_strike(delta: float) -> void:
	if _timer > 0.0:
		# aiming: hang over the start of the line, pen cocked back
		_tilt_to(0.9, delta)
		_fly_to(_strike_a + Vector3(0, 1.4, 0), 10.0, delta)
		if is_instance_valid(_mark):
			_mark.progress = 1.0 - _timer / strike_aim_time
		if _timer - delta <= 0.0:
			pop("SCRATCH!", RED, 2.6, 34)
		return
	# slashing down the line, low and fast
	var k := clampf(-_timer / strike_time, 0.0, 1.0)
	var at := _strike_a.lerp(_strike_b, k)
	global_position = Vector3(at.x, _ground + 0.2, at.z)
	velocity = Vector3.ZERO
	_tilt_to(1.0, delta)
	if not _strike_hit and _player and _player_on_segment(_strike_a, at, 0.75):
		_strike_hit = true
		_player.take_damage(2, at)
	if phase2:
		for l in get_tree().get_nodes_in_group("lantern"):
			if l.lit and _dist_to_segment(l.global_position, _strike_a, at) < 1.0:
				l.lit = false
				Fx.pop_text(get_tree(), l.global_position + Vector3(0, 2.2, 0), "CORRECTED!", RED, 30)
	if k >= 1.0:
		if is_instance_valid(_mark):
			_mark.fade_out()
		_mark = null
		_spawn_draft((_strike_a + _strike_b) * 0.5)
		_to_hover(1.4 if phase2 else 2.0)


func _player_on_segment(a: Vector3, b: Vector3, width: float) -> bool:
	if _player.global_position.y - _ground > 0.9:
		return false  # jumped over the stroke
	return _dist_to_segment(_player.global_position, a, b) < width


func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


func _spawn_draft(at: Vector3) -> void:
	if _drafts.size() >= max_drafts:
		return
	var m: Node3D = load(CROSSED_OUT).instantiate()
	m.respawn_time = 0.0
	m.lumens = 0
	get_parent().add_child(m)
	var p := _clamp_arena(at)
	m.global_position = Vector3(p.x, _ground + 0.05, p.z)
	_drafts.append(m)
	pop("STRUCK OUT!", RED, 1.8, 30)
	Fx.burst(get_tree(), m.global_position + Vector3(0, 0.5, 0), RED, 16, 3.5)


# -------------------------------------------------------------------- "NO."

func _write_no() -> void:
	if _player == null:
		return
	var c := _player.global_position
	# N to the west, O to the east, the full stop behind: only the near side is open
	for item in [["N", Vector3(-2.3, 0, 0)], ["O", Vector3(2.3, 0, 0)], [".", Vector3(0, 0, -2.3)]]:
		var l := Letter.new()
		l.letter = item[0]
		var p := _clamp_arena(c + item[1])
		get_tree().current_scene.add_child(l)
		l.global_position = Vector3(p.x, _ground, p.z)
		_letters.append(l)
	_shake(0.4)


# ------------------------------------------------------------------- light

func on_flash(from: Vector3) -> void:
	if dead:
		return
	puppet.flash()
	if phase2 and _dazzle_cd <= 0.0 and state != State.STUCK:
		_dazzle("DAZZLED!")
	elif not phase2:
		pop("SQUINT.", PALE, 3.4, 24)  # not yet...


func _dazzle(word: String) -> void:
	_clear_mark()
	_circles_left = 0
	state = State.DAZZLED
	_timer = dazzle_time
	_dazzle_cd = dazzle_cooldown
	pop(word, Color(1.0, 0.95, 0.6), 3.0, 36)
	_shake(0.3)


func _lantern_under() -> bool:
	var ground := Vector3(global_position.x, _ground + 0.5, global_position.z)
	for l in get_tree().get_nodes_in_group("lantern"):
		if l.lit and l.lights(ground):
			return true
	return false


func _nearest_lit_lantern(p: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for l in get_tree().get_nodes_in_group("lantern"):
		if l.lit:
			var d := _flat(l.global_position, p)
			if d < bd:
				bd = d
				best = l
	return best


# ------------------------------------------------------------------ combat

func _blocks(dir: Vector3, _aerial: bool) -> bool:
	if state == State.STUCK or state == State.DAZZLED:
		return false
	pop("CLINK!", Color(0.98, 0.76, 0.28), 2.0, 26)
	if _player and _player.has_method("bounce_back"):
		_player.bounce_back(-dir)
	return true


func is_harmful() -> bool:
	return false  # it never hurts by touch: only the wet stab and the stroke do


func _on_hurt() -> void:
	stun = 0.0  # hits never pause its clock: the stuck window is all you get


func _die() -> void:
	_clear_mark()
	for d in _drafts:
		if is_instance_valid(d) and not d.dead:
			d._die()  # its corrections go with it
	for l in _letters:
		if is_instance_valid(l):
			l.melt("")
	if _shadow:
		_shadow.visible = false
	pop("...STET.", PALE, 3.0, 40)
	super()


func _sync_puppet() -> void:
	puppet.figure.state = state
	puppet.figure.tilt = _tilt * float(facing)
	puppet.figure.ink = float(health) / float(maxi(hp, 1))


# ----------------------------------------------------------------- helpers

func _hover_spot() -> Vector3:
	if _player == null:
		return global_position
	# circle the player at a respectful editor's distance
	var a := time * (0.5 if phase2 else 0.35)
	var p := _player.global_position + Vector3(cos(a) * 3.5, 0, sin(a) * 2.5 - 1.0)
	p = _clamp_arena(p)
	p.y = _ground + hover_height + sin(time * 2.0) * 0.2
	return p


func _fly_to(target: Vector3, speed: float, delta: float) -> void:
	var want := (target - global_position) * 4.0  # ease in as it arrives
	if want.length() > speed:
		want = want.normalized() * speed
	velocity = velocity.move_toward(want, 40.0 * delta)


func _tilt_to(t: float, delta: float) -> void:
	_tilt = move_toward(_tilt, t, delta * 5.0)


func _clamp_arena(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, arena.position.x, arena.end.x), p.y, clampf(p.z, arena.position.y, arena.end.y))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _clear_mark() -> void:
	if is_instance_valid(_mark):
		_mark.fade_out()
	_mark = null


func _shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)
