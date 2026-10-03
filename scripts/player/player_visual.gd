extends Node2D
## Procedural Vesper art + animation: run cycle (alternating legs, body bob,
## forward lean, fluttering cloak hem, streaming ember scarf, footstep dust),
## idle breathing, jump tuck, fall billow and dash stretch.
## Origin is at the feet, faces +X; the parent CanvasGroup (outline shader)
## flips and squashes it. player.gd feeds the state vars every frame.

const INK := Color(0.05, 0.03, 0.1)
const DUST := Color(0.97, 0.94, 0.86)

@export var cloak_color := Color(0.1, 0.09, 0.2)
@export var cloak_rim := Color(0.3, 0.33, 0.62)
@export var mask_color := Color(0.98, 0.96, 0.9)
## Warm "ember" accent: the one warm saturated colour on a cool background.
@export var scarf_color := Color(1.0, 0.58, 0.14)
## Run-cycle radians per pixel travelled (bigger = shorter, quicker steps).
@export var stride := 0.07

# Driven by player.gd.
var velocity := Vector2.ZERO
var facing := 1
var on_floor := true
var dashing := false
var max_speed := 300.0
var stuck := false  # wading through goo: boots get gooey
var charge := 0.0  # 0..1 charged-attack build-up
var charge_ready := false

var _phase := 0.0
var _time := 0.0
var _run := 0.0  # 0 = standing .. 1 = full-speed run (smoothed)
var _blink := 0.0
var _blink_timer := 2.5
var _dust: Array = []
var _goo := 0.0  # 1 while in goo, fades after leaving (drips off)
var shoulder := Vector2(2, -33)  # sword arm pivot, read by sword.gd
var _upper := Transform2D()  # hips + lean, for the upper-body parts


func _process(delta: float) -> void:
	_time += delta
	_goo = 1.0 if stuck else maxf(_goo - delta * 1.2, 0.0)
	var speed := clampf(absf(velocity.x) / max_speed, 0.0, 1.0)
	_run = move_toward(_run, speed if on_floor and not dashing else 0.0, delta * 8.0)
	if on_floor and not dashing:
		var before := floori(_phase / PI)
		_phase += absf(velocity.x) * delta * stride
		if floori(_phase / PI) != before and speed > 0.4:
			_spawn_dust()
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(2.0, 4.5)
	_blink = maxf(_blink - delta, 0.0)
	for d in _dust:
		d.age += delta
	_dust = _dust.filter(func(d): return d.age < 0.35)
	queue_redraw()


func _spawn_dust() -> void:
	# a foot just planted: kick up a puff behind it (stored in world space)
	var foot_x := sin(_phase) * 8.0
	_dust.append({"p": get_global_transform() * Vector2(foot_x - 4.0, -2.0), "age": 0.0,
		"drift": Vector2(-facing * 40.0, -20.0)})


func _draw() -> void:
	_draw_dust()
	var fall := clampf(velocity.y / 700.0, -1.0, 1.0) if not on_floor else 0.0
	var bob := -absf(sin(_phase)) * 2.5 * _run + sin(_time * 2.4) * 0.7 * (1.0 - _run)
	var lean := 0.15 * _run
	if dashing:
		lean = 0.35
	elif not on_floor:
		lean = clampf(velocity.x * facing / max_speed, -1.0, 1.0) * 0.08
	var hips := Vector2(0, -15 + bob)

	# legs behind the cloak (far leg first, slightly lighter)
	for k in [1, 0]:
		var foot := _foot(k, hips, fall)
		var knee := (hips + foot) * 0.5 + Vector2(3.5, -1.0)
		var col := INK.lightened(0.12) if k == 1 else INK
		var hip := hips + Vector2(-2.5 + k * 5.0, 0)
		draw_polyline(PackedVector2Array([hip, knee, foot]), col, 5.0)
		draw_circle(knee, 2.5, col)
		draw_set_transform(foot + Vector2(1.5, 0))
		draw_colored_polygon(_ellipse(4.5, 3.0), col)  # boot
		draw_set_transform(Vector2.ZERO)
		if _goo > 0.0:
			var goo := Color(0.58, 0.95, 0.28)
			draw_circle(foot + Vector2(1, -1), 4.0 * _goo + 1.0, goo)
			draw_circle(foot + Vector2(-2, 2.0 + 4.0 * (1.0 - _goo)), 2.0 * _goo, goo)  # drip

	# upper body leans around the hips
	_upper = Transform2D(lean, hips)
	shoulder = _upper * Vector2(2, -17)
	draw_set_transform_matrix(_upper)
	_draw_scarf_tail(fall)
	_draw_cloak(fall)
	_draw_head()
	draw_set_transform(Vector2.ZERO)

	if dashing:
		for i in 3:
			var y := -10.0 - i * 13.0
			draw_line(Vector2(-22 - i * 6, y), Vector2(-58 - i * 10, y), Color(DUST, 0.9), 3.0)
	if charge > 0.0:
		_draw_charge()


## Ember sparks spiral in while charging; a pulsing ring when ready to fire.
func _draw_charge() -> void:
	var c := Vector2(10, -24)
	if charge_ready:
		var pulse := 0.5 + 0.5 * sin(_time * 22.0)
		draw_arc(c, 15.0 + pulse * 3.0, 0, TAU, 20, scarf_color, 3.0)
		draw_circle(c, 5.0 + pulse * 1.5, scarf_color.lightened(0.5))
		return
	var r := lerpf(34.0, 8.0, charge)
	for k in 6:
		var a := TAU * k / 6.0 + _time * 7.0
		var p := c + Vector2(cos(a), sin(a)) * r
		draw_circle(p, 1.5 + 2.0 * charge, scarf_color)


func _foot(k: int, hips: Vector2, fall: float) -> Vector2:
	if dashing:
		return hips + Vector2(-11.0 - k * 4.0, 9.0 + k * 2.0)
	if not on_floor:
		# rising: knees tucked; falling: legs dangle and spread
		var tuck := Vector2(-1.0 + k * 6.0, 9.0)
		var dangle := Vector2(-4.0 + k * 8.0, 14.0)
		return hips + tuck.lerp(dangle, clampf(fall + 0.5, 0.0, 1.0))
	var ph := _phase + k * PI
	var stance := Vector2(-3.0 + k * 6.0, 0.0)
	var run := Vector2(sin(ph) * 9.0, -maxf(0.0, cos(ph)) * 7.0)  # lifted while swinging forward
	return stance.lerp(run, _run)


func _draw_cloak(fall: float) -> void:
	var trail := 7.0 * _run + (8.0 if dashing else 0.0)
	var flutter := sin(_time * 16.0) * 1.6 * maxf(_run, absf(fall))
	var lift := -6.0 * maxf(fall, 0.0)  # hem billows up while falling
	var hem_y := 0.0
	var cloak := PackedVector2Array([
		Vector2(-10, -20), Vector2(10, -20),
		Vector2(13, hem_y + lift * 0.4),
		Vector2(6, hem_y + 3 + lift * 0.5),
		Vector2(0, hem_y + lift * 0.7 + flutter * 0.5),
		Vector2(-7, hem_y + 3 + lift + flutter),
		Vector2(-14 - trail, hem_y - trail * 0.3 + lift + flutter),
	])
	draw_colored_polygon(cloak, cloak_color)
	# front rim light so the dark cloak keeps some form
	draw_colored_polygon(PackedVector2Array([Vector2(6, -20), Vector2(10, -20),
		Vector2(13, hem_y + lift * 0.4), Vector2(8, hem_y + 1.5 + lift * 0.45)]), cloak_rim)


func _draw_scarf_tail(fall: float) -> void:
	var speed := clampf(absf(velocity.x) / max_speed, 0.0, 1.0)
	var pts := PackedVector2Array([Vector2(-6, -21)])
	for i in range(1, 6):
		var t := float(i)
		var back := t * (2.5 + 4.5 * speed + (4.0 if dashing else 0.0))
		var wave := sin(_time * 11.0 - t * 0.9) * t * (0.35 + 0.6 * speed)
		var droop := t * (1.6 * (1.0 - speed) - 2.2 * maxf(fall, 0.0) + 0.8 * minf(fall, 0.0))
		pts.append(Vector2(-6 - back, -21 + wave + droop))
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], scarf_color, lerpf(6.0, 2.5, i / 4.0))
		draw_circle(pts[i + 1], lerpf(3.0, 1.25, i / 4.0), scarf_color)


func _draw_head() -> void:
	# scarf wrap around the neck
	draw_colored_polygon(_round_rect(Rect2(-11, -24, 22, 6), 3.0), scarf_color)
	draw_line(Vector2(-9, -19.5), Vector2(9, -19.5), scarf_color.darkened(0.35), 1.5)
	# mask
	draw_colored_polygon(_round_rect(Rect2(-11, -46, 23, 23), 7.0), mask_color)
	draw_line(Vector2(-8, -25.5), Vector2(8, -25.5), mask_color.darkened(0.18), 2.0)
	# eye (blinks)
	var open := 1.0 if _blink <= 0.0 else 0.15
	draw_set_transform_matrix(_upper * Transform2D(0.0, Vector2(1.0, open), 0.0, Vector2(5.5, -35)))
	draw_colored_polygon(_ellipse(3.0, 5.5), INK)
	draw_set_transform_matrix(_upper)


func _draw_dust() -> void:
	var inv := get_global_transform().affine_inverse()
	for d in _dust:
		var t: float = d.age / 0.35
		var p: Vector2 = inv * (d.p + d.drift * d.age)
		draw_circle(p, 3.0 + t * 7.0, Color(DUST, 0.3 * (1.0 - t)))  # faint: below the outline threshold


func _round_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - radius, radius), r.end - Vector2(radius, radius),
		r.position + Vector2(radius, r.size.y - radius), r.position + Vector2(radius, radius)]
	for c in 4:
		for s in 5:
			var a := -PI * 0.5 + (c + s / 4.0) * PI * 0.5
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * radius)
	return pts


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
