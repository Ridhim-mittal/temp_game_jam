extends "res://scripts/enemies/enemy_base.gd"
## Paper spider (Shade's City): a crumpled heap of comic pages with a
## red-veined grin, scuttling on wire legs that end in fountain-pen nibs.
## Can hang on an ink thread and drop when Vesper comes close; on the ground
## it closes in, rears up (a clear tell) and lunges with a nib stab. Being
## paper, light scares it: lit, it backs off and won't attack.

enum State { HANG, DROP, CHASE, WINDUP, STAB, RECOVER, FLINCH }

@export var hp := 5
## Start hanging this far above the floor on a thread (0 = on the ground).
@export var hang_height := 0.0
## Drop when the player is this close sideways.
@export var drop_range := 260.0
@export var speed := 170.0
@export var stab_range := 120.0
@export var stab_speed := 420.0
@export var stab_damage := 18.0
@export var touch_damage := 12.0
@export var art_scale := 0.62
## Further than this from Vesper it wanders its patch of street instead.
@export var notice_range := 650.0
@export var wander_range := 160.0

const PAPER := Color(0.93, 0.9, 0.8)
const OLD := Color(0.84, 0.79, 0.68)
const RULE := Color(0.5, 0.58, 0.78, 0.55)
const RED := Color(0.86, 0.14, 0.2)
const STEEL := Color(0.78, 0.8, 0.86)
const STEEL_D := Color(0.42, 0.44, 0.52)

var state := State.CHASE
var _timer := 0.0
var _thread_top := 0.0
var _rear := 0.0  # 0..1 rearing back before a stab
var _home := 0.0
var _wander_dir := 1
var _pause := 0.0


func _ready() -> void:
	setup(Vector2(70, 66), hp)
	_home = global_position.x
	_wander_dir = 1 if randf() < 0.5 else -1
	outline.scale = Vector2.ONE * art_scale
	if hang_height > 0.0:
		state = State.HANG
		_thread_top = global_position.y - hang_height - 40.0
		global_position.y -= hang_height
		set_harmful(false)


func damage_default() -> float:
	return stab_damage if state == State.STAB else touch_damage


func _tick(delta: float) -> void:
	_timer -= delta
	var d := to_player()
	match state:
		State.HANG:
			velocity = Vector2.ZERO
			if _player and absf(d.x) < drop_range and d.y > -40.0:
				state = State.DROP
				set_harmful(true)
				pop("SKREEE!", Color(1.0, 0.86, 0.2), Vector2(0, -70), 30)
				Sfx.play("ink_enemy_hit", 0.0, 1.6)
			return
		State.DROP:
			_fall(delta)
			velocity.y = minf(velocity.y + 1200.0 * delta, 900.0)
			if is_on_floor():
				state = State.RECOVER
				_timer = 0.45
		State.CHASE:
			_fall(delta)
			if is_lit():
				_flinch()
			elif _player == null or absf(d.x) > notice_range or absf(d.y) > 200.0:
				_wander(delta)
			elif _player:
				face_player()
				var want := facing * speed * (1.0 + 0.25 * sin(time * 9.0))
				if absf(d.x) < stab_range * 0.7 or absf(d.y) > 200.0 or (is_on_floor() and at_ledge()):
					want = 0.0
				velocity.x = move_toward(velocity.x, want, 1100.0 * delta)
				if absf(d.x) < stab_range and absf(d.y) < 90.0 and is_on_floor():
					state = State.WINDUP
					_timer = 0.45
			else:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		State.WINDUP:
			_fall(delta)
			face_player()
			velocity.x = move_toward(velocity.x, -facing * 40.0, 900.0 * delta)
			_rear = minf(_rear + delta / 0.45, 1.0)
			if is_lit():
				_flinch()
			elif _timer <= 0.0:
				state = State.STAB
				_timer = 0.2
				velocity.x = facing * stab_speed
				_rear = 0.0
		State.STAB:
			_fall(delta)
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = 0.6
		State.RECOVER:
			_fall(delta)
			velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE
		State.FLINCH:
			_fall(delta)
			velocity.x = move_toward(velocity.x, -facing * speed * 1.3, 1400.0 * delta)
			if _timer <= 0.0 and not is_lit():
				state = State.CHASE
	if state != State.WINDUP:
		_rear = move_toward(_rear, 0.0, delta * 4.0)
	move_and_slide()


## Pace back and forth round `_home`, stopping now and then, turning at
## walls, ledges and the edge of its patch.
func _wander(delta: float) -> void:
	_pause -= delta
	if _pause > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	var off := global_position.x - _home
	if (off > wander_range and _wander_dir > 0) or (off < -wander_range and _wander_dir < 0) \
			or (is_on_floor() and (hitting_wall() or at_ledge())):
		_wander_dir = -_wander_dir
		_pause = randf_range(0.4, 1.2)
	facing = _wander_dir
	velocity.x = move_toward(velocity.x, _wander_dir * speed * 0.45, 700.0 * delta)


func _flinch() -> void:
	if state != State.FLINCH:
		pop("HSSS!", Color(0.98, 0.95, 0.9), Vector2(0, -60), 22)
	state = State.FLINCH
	_timer = 0.6
	_rear = 0.0


func _on_hurt() -> void:
	if state == State.WINDUP or state == State.STAB:
		state = State.RECOVER
		_timer = 0.35
	_rear = 0.0


# ------------------------------------------------------------------ art

func paint(c: CanvasItem) -> void:
	var walking := (state == State.CHASE or state == State.FLINCH) and absf(velocity.x) > 10.0
	var bob := sin(time * 3.0) * 3.0
	var body := Vector2(-8.0 * _rear, -100.0 + bob - 22.0 * _rear)
	if state == State.HANG or state == State.DROP:
		var top := _thread_top - global_position.y
		c.draw_line(Vector2(0, top / art_scale), body + Vector2(0, -30), INK, 2.5)
	var hanging := state == State.HANG
	for side in [-1.0, 1.0]:
		for i in 4:
			var root := body + Vector2(side * (14.0 + i * 5.0), -6.0 + i * 7.0)
			var ph := time * (9.0 if walking else 2.0) + i * 1.7 + (0.0 if side > 0.0 else PI)
			var reach := 70.0 + i * 30.0 - (12.0 if i == 3 else 0.0)
			var foot := Vector2(side * reach + sin(ph) * 7.0, -maxf(0.0, cos(ph)) * (9.0 if walking else 2.0))
			if hanging:
				foot = body + Vector2(side * (30.0 + i * 12.0), 40.0 + i * 4.0)
			if i == 0 and side > 0.0 and (_rear > 0.0 or state == State.STAB):
				# the front nib cocks back, then spears forward
				foot = body + Vector2(70.0 + 70.0 * (1.0 - _rear), 40.0 - 50.0 * _rear) if state != State.STAB \
					else Vector2(150.0, -40.0)
			var knee := Vector2(side * (44.0 + i * 22.0), body.y - 58.0 + i * 9.0 + sin(ph) * 3.0)
			var ankle := foot + Vector2(-side * 5.0, -18.0)
			c.draw_polyline(PackedVector2Array([root, knee, ankle]), INK, 4.0)
			c.draw_polyline(PackedVector2Array([root, knee, ankle]), STEEL_D, 1.4)
			c.draw_circle(knee, 3.2, INK)
			c.draw_circle(knee, 1.6, STEEL)
			_nib(c, ankle, foot)
	var sheets := [[-26, -14, 44, 36, -0.5, OLD], [24, -18, 46, 34, 0.45, PAPER], [-20, 16, 48, 30, 0.25, PAPER],
		[26, 14, 42, 34, -0.3, OLD], [0, -30, 52, 30, 0.1, PAPER], [-36, 0, 30, 40, 1.1, PAPER], [38, -2, 30, 38, -1.0, OLD]]
	for s in sheets:
		_sheet(c, body + Vector2(s[0], s[1]) + Vector2(sin(time * 2.0 + s[0]), 0) * 1.5, Vector2(s[2], s[3]), s[4], s[5])
	for k in 6:
		var a := k * 1.3 + 0.4
		c.draw_circle(body + Vector2(cos(a) * 34.0, sin(a) * 24.0), 5.0 + (k % 3) * 2.0, INK)
	_sheet(c, body + Vector2(4, 2), Vector2(64, 54), -0.06, PAPER)
	c.draw_set_transform(body + Vector2(4, 2), -0.06)
	var look := Vector2(1, 0.1) if _player else Vector2(1, 0)
	var wide := 1.0 + 0.25 * _rear
	for e in [[-14.0, -10.0, 10.0], [14.0, -12.0, 11.0]]:
		var ec := Vector2(e[0], e[1])
		c.draw_circle(ec, e[2] * wide + 1.5, INK)
		c.draw_circle(ec, e[2] * wide, Color(0.98, 0.95, 0.9))
		for v in 4:
			var dv := Vector2.from_angle(v * 1.6 + 0.3)
			c.draw_line(ec + dv * e[2] * 0.95, ec + dv * e[2] * 0.45, RED, 1.2)
		c.draw_circle(ec + look * e[2] * 0.35, 3.8, INK)
	c.draw_line(Vector2(-24, -24), Vector2(-6, -18), INK, 3.0)
	c.draw_line(Vector2(24, -26), Vector2(6, -20), INK, 3.0)
	var open := 6.0 * _rear + (8.0 if state == State.STAB else 0.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-22, 6), Vector2(22, 4), Vector2(16, 18 + open), Vector2(-16, 19 + open)]), INK)
	for t in 6:
		var x := -18.0 + t * 7.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 6), Vector2(x + 6, 5.5), Vector2(x + 3, 11)]), PAPER)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 2, 18.5 + open), Vector2(x + 7, 18 + open), Vector2(x + 4.5, 13 + open)]), PAPER)
	c.draw_line(Vector2(-26, 2), Vector2(-20, 12), RED, 2.0)
	c.draw_line(Vector2(26, 0), Vector2(20, 11), RED, 2.0)
	c.draw_set_transform(Vector2.ZERO)
	for k in 4:
		var a := time * 1.2 + k * TAU / 4.0
		var p := body + Vector2(cos(a) * 78.0, sin(a) * 30.0 - 10.0)
		c.draw_set_transform(p, a * 2.0)
		c.draw_rect(Rect2(-6, -4, 12, 8), INK)
		c.draw_rect(Rect2(-5, -3, 10, 6), PAPER)
		c.draw_set_transform(Vector2.ZERO)


func _sheet(c: CanvasItem, at: Vector2, size: Vector2, rot: float, col: Color) -> void:
	c.draw_set_transform(at, rot)
	var h := size * 0.5
	var poly := PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x * 0.6, -h.y - 3), Vector2(h.x, -h.y * 0.4),
		Vector2(h.x + 2, h.y), Vector2(-h.x * 0.3, h.y + 3), Vector2(-h.x - 2, h.y * 0.5)])
	c.draw_colored_polygon(poly, INK)
	var inner := PackedVector2Array()
	for p in poly:
		inner.append(p * 0.92)
	c.draw_colored_polygon(inner, col)
	for r in range(int(-h.y) + 8, int(h.y) - 4, 7):
		c.draw_line(Vector2(-h.x * 0.8, r), Vector2(h.x * 0.8, r), RULE, 1.0)
	c.draw_set_transform(Vector2.ZERO)


func _nib(c: CanvasItem, top: Vector2, tip: Vector2) -> void:
	var dir := (tip - top).normalized()
	var side := dir.orthogonal()
	var l := top.distance_to(tip)
	c.draw_colored_polygon(PackedVector2Array([top + side * 6.0, top - side * 6.0, top + dir * l * 0.55 - side * 4.0, tip,
		top + dir * l * 0.55 + side * 4.0]), INK)
	c.draw_colored_polygon(PackedVector2Array([top + side * 4.5 + dir, top - side * 4.5 + dir, top + dir * l * 0.55 - side * 2.8,
		tip - dir * 2.0, top + dir * l * 0.55 + side * 2.8]), STEEL)
	c.draw_line(top + dir * l * 0.3, tip, INK, 1.2)
