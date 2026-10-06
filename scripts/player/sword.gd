extends Node2D
## Vesper's weapon (the nib-sword by default: a steel blade shaped like a
## fountain-pen nib, slit, breather hole, ink-dipped tip - the hero of a
## drawn world fights with the artist's pen). `style` picks the weapon from
## Quire's shop (catalog.gd look "weapon"): nib, quill, brush, corkscrew,
## prism or lantern. Owns the sword arm too: shoulder -> hand -> blade.
##
## Lives inside the player's Visual CanvasGroup (so it gets the outline and
## is flipped with the body); faces +X. player.gd calls swing() / thrust()
## and feeds charge, spin() (the Corkscrew's drill) and whirl() (the
## Lantern Flail's orbit); the shoulder position comes from the sibling Art
## node.

const INK := Color(0.05, 0.03, 0.1)
const STEEL_LIGHT := Color(0.9, 0.92, 0.98)
const STEEL_DARK := Color(0.5, 0.53, 0.68)
const GUARD := Color(0.3, 0.32, 0.5)
const SWEEP_TIME := 0.09
const HOLD_TIME := 0.07
const RECOVER_TIME := 0.16

enum Move { NONE, SIDE, UP, DOWN, THRUST, SPIN, WHIRL }
## Sweep [start angle, end angle] per slash, radians in facing space
## (0 = forward, +PI/2 = down). Plain lerp, so the sweep direction is kept.
const SWEEPS := {
	Move.SIDE: Vector2(-2.1, 1.3),   # overhead, down through the front
	Move.UP: Vector2(0.7, -2.7),     # low front, up over the head
	Move.DOWN: Vector2(-1.0, 2.5),   # front, down under the feet
}

@export var blade_length := 36.0
@export var arm_length := 9.0
@export var grip_color := Color(1.0, 0.58, 0.14)  # wrapped in scarf cloth
@export var cloak_color := Color(0.1, 0.09, 0.2)
@export var style := "nib"
## Chain length of the Lantern Flail while whirling (px).
@export var whirl_reach := 70.0

# Fed by player.gd.
var charge := 0.0
var charge_ready := false

var _move := Move.NONE
var _t := 0.0
var _angle := 2.55
var _extend := 0.0  # thrust lunge distance
var _time := 0.0
var _hand := Vector2.ZERO
@onready var _art: Node2D = get_node_or_null("../Art")


func swing(dir: Vector2) -> void:
	_move = Move.UP if dir.y < 0.0 else (Move.DOWN if dir.y > 0.0 else Move.SIDE)
	_t = 0.0


func thrust() -> void:
	_move = Move.THRUST
	_t = 0.0


func is_swinging() -> bool:
	return _move != Move.NONE


## The Corkscrew's drill: held straight out, spinning, while `on`.
func spin(on: bool) -> void:
	if on:
		_move = Move.SPIN
		_t = 0.0
	elif _move == Move.SPIN:
		_move = Move.NONE


## The Lantern Flail's whirl: the lantern swings round on a long chain.
func whirl(on: bool) -> void:
	if on:
		_move = Move.WHIRL
		_t = 0.0
	elif _move == Move.WHIRL:
		_move = Move.NONE


## Where the lantern is while whirling (global), for the player's hits.
func lantern_global() -> Vector2:
	var shoulder: Vector2 = _art.shoulder if _art else Vector2(2, -33)
	return to_global(shoulder + Vector2.from_angle(_angle) * (arm_length + whirl_reach))


func _rest_angle() -> float:
	# Held low behind the body (Hollow Knight nail at rest): the tip never
	# dips below the feet, and it never covers the face.
	if _art == null:
		return 2.55
	if _art.dashing:
		return 2.95  # trailing straight back
	if not _art.on_floor:
		return 2.3 if _art.velocity.y < 0.0 else -2.6  # tip lifts while falling
	var run := clampf(absf(_art.velocity.x) / _art.max_speed, 0.0, 1.0)
	return lerpf(2.55, 2.8, run) + sin(_time * 2.4) * 0.04


func _process(delta: float) -> void:
	_time += delta
	_t += delta
	var rest := _rest_angle()
	match _move:
		Move.NONE:
			_angle = lerp_angle(_angle, rest, 1.0 - exp(-14.0 * delta))
			_extend = move_toward(_extend, 0.0, delta * 80.0)
		Move.SPIN:
			_angle = lerp_angle(_angle, 0.05 * sin(_time * 40.0), 1.0 - exp(-30.0 * delta))
			_extend = move_toward(_extend, 8.0, delta * 80.0)
		Move.WHIRL:
			_angle = wrapf(_angle - delta * 13.0, -PI, PI)
			_extend = 0.0
		Move.THRUST:
			_angle = lerp_angle(_angle, 0.0, 1.0 - exp(-40.0 * delta))
			_extend = 14.0 * (1.0 - clampf((_t - 0.12) / 0.15, 0.0, 1.0)) * minf(_t / 0.04, 1.0)
			if _t > 0.3:
				_move = Move.NONE
		_:
			var s: Vector2 = SWEEPS[_move]
			if _t < SWEEP_TIME:
				var k := 1.0 - pow(1.0 - _t / SWEEP_TIME, 3.0)  # ease out: fast start
				_angle = lerpf(s.x, s.y, k)
			elif _t < SWEEP_TIME + HOLD_TIME:
				_angle = s.y
			elif _t < SWEEP_TIME + HOLD_TIME + RECOVER_TIME:
				var k := (_t - SWEEP_TIME - HOLD_TIME) / RECOVER_TIME
				_angle = lerp_angle(s.y, rest, k * k * (3.0 - 2.0 * k))
			else:
				_move = Move.NONE
	queue_redraw()


func _draw() -> void:
	var shoulder: Vector2 = _art.shoulder if _art else Vector2(2, -33)
	var dir := Vector2.from_angle(_angle)
	_hand = shoulder + dir * (arm_length + _extend)

	if _move in SWEEPS and _t < SWEEP_TIME + HOLD_TIME and absf(_angle - SWEEPS[_move].x) > 0.1:
		_draw_smear(shoulder)

	# arm (sleeve) + fist
	draw_line(shoulder, _hand, cloak_color, 5.0)
	draw_circle(shoulder, 2.5, cloak_color)

	draw_set_transform(_hand, _angle)
	_draw_blade()
	draw_set_transform(Vector2.ZERO)
	draw_circle(_hand, 3.4, cloak_color.lightened(0.15))


func _draw_blade() -> void:
	match style:
		"quill":
			_draw_quill()
		"brush":
			_draw_brush()
		"corkscrew":
			_draw_corkscrew()
		"prism":
			_draw_prism()
		"lantern":
			_draw_lantern()
		_:
			_draw_nib()
	_draw_charge()


func _draw_nib() -> void:
	var L := blade_length
	# grip + pommel behind the hand
	draw_rect(Rect2(-8, -2, 9, 4), grip_color)
	for k in 3:
		draw_line(Vector2(-7 + k * 3, -2), Vector2(-5 + k * 3, 2), grip_color.darkened(0.35), 1.0)
	draw_circle(Vector2(-9, 0), 2.6, GUARD)
	# blade: two-tone so it reads as a ridged 3D edge
	var upper := PackedVector2Array([Vector2(2, -3.6), Vector2(L * 0.55, -3.3), Vector2(L, 0), Vector2(2, 0)])
	var lower := PackedVector2Array([Vector2(2, 0), Vector2(L, 0), Vector2(L * 0.55, 3.3), Vector2(2, 3.6)])
	draw_colored_polygon(upper, STEEL_LIGHT)
	draw_colored_polygon(lower, STEEL_DARK)
	# ink-dipped nib tip with the nib slit
	draw_colored_polygon(PackedVector2Array([Vector2(L * 0.72, -2.3), Vector2(L, 0), Vector2(L * 0.72, 2.3)]), INK)
	draw_line(Vector2(L * 0.66, 0), Vector2(L * 0.97, 0), STEEL_LIGHT, 1.0)
	draw_circle(Vector2(L * 0.63, 0), 1.7, INK)  # breather hole
	# cross-guard on top
	draw_rect(Rect2(0, -6, 3, 12), GUARD)


## Charge glow along the edge (any weapon).
func _draw_charge() -> void:
	if charge <= 0.0:
		return
	var L := blade_length if style != "lantern" else 24.0
	var a := charge
	if charge_ready:
		a = 0.6 + 0.4 * sin(_time * 22.0)
	draw_line(Vector2(4, -3.8), Vector2(L * 0.55, -3.5), Color(grip_color, a), 2.5)
	draw_line(Vector2(L * 0.55, -3.5), Vector2(L + 1, 0), Color(grip_color, a), 2.5)
	if charge_ready:
		draw_circle(Vector2(L + 1, 0), 3.0 + 1.5 * sin(_time * 22.0), grip_color.lightened(0.4))


## Quill Rapier: a long white feather with a tinted vane and a steel nib.
func _draw_quill() -> void:
	var L := blade_length
	draw_rect(Rect2(-8, -1.6, 9, 3.2), grip_color.darkened(0.4))
	var vane := PackedVector2Array([Vector2(3, 0), Vector2(L * 0.25, -5.5), Vector2(L * 0.7, -4.2), Vector2(L * 0.86, -1.0),
		Vector2(L * 0.86, 1.0), Vector2(L * 0.6, 3.6), Vector2(L * 0.2, 2.6)])
	draw_colored_polygon(vane, grip_color.lerp(Color.WHITE, 0.6))
	for k in 5:  # barbs
		var x := L * (0.2 + k * 0.13)
		draw_line(Vector2(x, 0), Vector2(x + 5, -4.0), grip_color.darkened(0.1), 1.0)
	draw_line(Vector2(0, 0), Vector2(L * 0.88, 0), Color(0.97, 0.95, 0.88), 1.6)  # the shaft
	draw_colored_polygon(PackedVector2Array([Vector2(L * 0.84, -2.2), Vector2(L + 4, 0), Vector2(L * 0.84, 2.2)]), STEEL_LIGHT)
	draw_line(Vector2(L * 0.88, 0), Vector2(L + 2, 0), INK, 0.8)


## Brush Maul: a wooden handle, a gold ferrule, a fat bristle head dipped in ink.
func _draw_brush() -> void:
	var L := blade_length
	draw_rect(Rect2(-8, -2.4, L * 0.6 + 8, 4.8), Color(0.5, 0.3, 0.18))
	draw_rect(Rect2(L * 0.55, -4.2, 6, 8.4), Color(0.95, 0.75, 0.3))
	var head := PackedVector2Array([Vector2(L * 0.62, -5.0), Vector2(L * 0.9, -6.5), Vector2(L + 8, 0), Vector2(L * 0.9, 6.5),
		Vector2(L * 0.62, 5.0)])
	draw_colored_polygon(head, Color(0.88, 0.82, 0.68))
	draw_colored_polygon(PackedVector2Array([Vector2(L * 0.9, -6.5), Vector2(L + 8, 0), Vector2(L * 0.9, 6.5), Vector2(L * 0.84, 0)]), INK)
	draw_circle(Vector2(-9, 0), 2.6, GUARD)


## Corkscrew Nib: a wooden pen grip with silver rings and a twisted steel
## drill of a nib; its spiral turns while it spins.
func _draw_corkscrew() -> void:
	var L := blade_length
	draw_rect(Rect2(-9, -2.6, 13, 5.2), grip_color)
	draw_rect(Rect2(2, -3.4, 2.5, 6.8), STEEL_LIGHT)
	draw_rect(Rect2(5.5, -3.4, 2.5, 6.8), STEEL_LIGHT)
	var cone := PackedVector2Array([Vector2(8, -4.4), Vector2(L + 4, 0), Vector2(8, 4.4)])
	draw_colored_polygon(cone, STEEL_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -4.4), Vector2(L + 4, 0), Vector2(8, 0)]), STEEL_LIGHT)
	var turn := fmod(_time * (60.0 if _move == Move.SPIN else 6.0), 7.0)
	var x := 8.0 + turn
	while x < L:
		var hw := 4.4 * (1.0 - (x - 8.0) / (L - 4.0))
		draw_line(Vector2(x, hw), Vector2(x + 4.0, -hw), INK, 1.2)
		x += 7.0


## Prism Saber: a brass guard and a long faceted crystal blade, glowing,
## with a rainbow down its face.
func _draw_prism() -> void:
	var L := blade_length
	draw_rect(Rect2(-8, -2, 9, 4), grip_color)
	draw_circle(Vector2(-9, 0), 2.6, Color(0.95, 0.75, 0.3))
	var pulse := 0.85 + 0.15 * sin(_time * 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -4.6), Vector2(L * 0.8, -4.0), Vector2(L + 6, 0), Vector2(L * 0.8, 4.0),
		Vector2(2, 4.6)]), Color(0.6, 1.0, 0.97, 0.9 * pulse))
	draw_colored_polygon(PackedVector2Array([Vector2(2, -4.6), Vector2(L * 0.8, -4.0), Vector2(L + 6, 0), Vector2(2, 0)]),
		Color(0.92, 1.0, 1.0, pulse))
	var bands := [Color(1.0, 0.4, 0.5), Color(1.0, 0.85, 0.35), Color(0.5, 1.0, 0.6), Color(0.45, 0.65, 1.0)]
	for k in bands.size():
		draw_line(Vector2(6 + k * L * 0.18, 2.4), Vector2(6 + (k + 1) * L * 0.18, 2.0), bands[k], 1.6)
	draw_rect(Rect2(0, -6.5, 3, 13), Color(0.95, 0.75, 0.3))


## Lantern Flail: a short handle, a chain and a small lit lantern at its end
## (a long chain while it whirls).
func _draw_lantern() -> void:
	var reach := whirl_reach if _move == Move.WHIRL else 22.0
	draw_rect(Rect2(-8, -2.2, 10, 4.4), Color(0.3, 0.2, 0.14))
	var links := int(reach / 5.0)
	for k in links:
		draw_circle(Vector2(3 + k * 5.0, 0), 1.5, Color(0.55, 0.55, 0.6))
	var c := Vector2(reach + 6, 0)
	draw_circle(c, 9.0, Color(1.0, 0.8, 0.4, 0.25))
	draw_rect(Rect2(c - Vector2(5, 6), Vector2(10, 12)), Color(1.0, 0.85, 0.45))
	draw_rect(Rect2(c - Vector2(5, 6), Vector2(10, 12)), INK, false, 1.4)
	draw_line(c - Vector2(6, 6.5), c + Vector2(6, -6.5), INK, 2.0)
	draw_line(c - Vector2(6, -6.5), c + Vector2(6, 6.5), INK, 2.0)
	draw_circle(c, 2.6, Color(1.0, 1.0, 0.85))


## Motion smear following the blade through its sweep (comic "swoosh").
func _draw_smear(pivot: Vector2) -> void:
	var s: Vector2 = SWEEPS[_move]
	var fade := 1.0 - clampf((_t - SWEEP_TIME) / HOLD_TIME, 0.0, 1.0)
	var inner := arm_length + blade_length * 0.75
	var outer := arm_length + blade_length + 6.0
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		pts.append(pivot + Vector2.from_angle(lerpf(s.x, _angle, float(i) / steps)) * outer)
	for i in range(steps, -1, -1):
		var w := float(i) / steps  # thin at the tail, full at the blade
		pts.append(pivot + Vector2.from_angle(lerpf(s.x, _angle, w)) * lerpf(outer - 2.0, inner, w))
	draw_colored_polygon(pts, Color(1.0, 0.98, 0.9, 0.8 * fade))
