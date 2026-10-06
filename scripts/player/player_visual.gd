extends Node2D
## Procedural Vesper art + animation ("Wanderer" look: wide hat, long coat
## with a torn-page hem, red scarf, pencil sword on his back): run cycle
## (alternating legs, body bob, forward lean, fluttering hem, streaming scarf, footstep dust),
## idle breathing, jump tuck, fall billow and dash stretch.
## Origin is at the feet, faces +X; the parent CanvasGroup (outline shader)
## flips and squashes it. player.gd feeds the state vars every frame.

const INK := Color(0.05, 0.03, 0.1)
const DUST := Color(0.97, 0.94, 0.86)

@export var cloak_color := Color(0.14, 0.11, 0.16)
@export var cloak_rim := Color(0.36, 0.3, 0.42)
@export var mask_color := Color(0.98, 0.96, 0.9)
## Warm "ember" accent: the one warm saturated colour on a cool background.
@export var scarf_color := Color(0.92, 0.3, 0.2)
## The hat and its band (outfits from Quire's shop).
@export var hat_color := Color(0.14, 0.11, 0.16)
@export var band_color := Color(0.92, 0.3, 0.2)
## Torn comic-page lining that shows along the coat hem.
@export var page_color := Color(0.92, 0.89, 0.8)
@export var pencil_color := Color(0.96, 0.76, 0.2)
## Eye colour (Shade's double has burning red eyes, shade_double.gd).
@export var eye_color := INK
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
var crouch := 0.0       # 0..1 crouch-jump coil depth
var crouching := false  # crouch held (even before the coil counts)
var land := 0.0  # hard-landing kneel left, 1 at impact .. 0 standing (player.gd)
var wall := 0.0  # 1 while sliding down a wall (the wall is behind him, at -x)

var _phase := 0.0
var _time := 0.0
var _run := 0.0  # 0 = standing .. 1 = full-speed run (smoothed)
var _blink := 0.0
var _blink_timer := 2.5
var _dust: Array = []
var _goo := 0.0  # 1 while in goo, fades after leaving (drips off)
var shoulder := Vector2(2, -33)  # sword arm pivot, read by sword.gd
var _coil_draw := 0.0
var _upper := Transform2D()  # hips + lean, for the upper-body parts
var _kneel := 0.0
var _wall := 0.0  # eased `wall`


func _process(delta: float) -> void:
	_time += delta
	_goo = 1.0 if stuck else maxf(_goo - delta * 1.2, 0.0)
	_wall = move_toward(_wall, wall, delta * 10.0)
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
	# crouch-jump: hips sink, body tips forward, shivers when fully coiled
	var coil := (0.25 + 0.75 * crouch) if crouching else 0.0
	_coil_draw = coil
	if coil > 0.0:
		hips.y += 9.0 * coil
		lean += 0.14 * coil
		if crouch >= 1.0:
			hips.x += sin(_time * 70.0) * 1.0
	# hard landing (Hollow Knight): drop to one knee, hand down, head bowed;
	# held for the first half, then she rises
	_kneel = smoothstep(0.0, 0.5, land)
	if _kneel > 0.0:
		hips.y += 17.0 * _kneel
		lean += 0.2 * _kneel
		_coil_draw = maxf(_coil_draw, _kneel)
	# wall slide (Hollow Knight): back pressed to the wall, leaning on it
	if _wall > 0.0:
		hips.x -= 3.0 * _wall
		lean -= 0.14 * _wall

	# legs behind the cloak (far leg first, slightly lighter)
	for k in [1, 0]:
		var foot := _foot(k, hips, fall)
		var knee := (hips + foot) * 0.5 + Vector2(3.5 + 6.0 * _coil_draw, -1.0 - 3.0 * _coil_draw)
		var col := INK.lightened(0.12) if k == 1 else INK
		var hip := hips + Vector2(-2.5 + k * 5.0, 0)
		if _kneel > 0.0:
			if k == 1:  # back knee on the ground, boot tucked behind
				knee = knee.lerp(Vector2(hip.x - 3.0, -3.0), _kneel)
				foot = foot.lerp(Vector2(-15.0, -1.0), _kneel)
			else:  # front foot planted forward
				foot = foot.lerp(Vector2(9.0, 0.0), _kneel)
				knee = knee.lerp(Vector2(10.0, -12.0), _kneel)
		if _wall > 0.0:
			if k == 1:  # back boot braced flat on the wall
				foot = foot.lerp(Vector2(-12.0, -5.0), _wall)
				knee = knee.lerp(Vector2(-3.0, -11.0), _wall)
			else:  # front leg hangs bent
				foot = foot.lerp(Vector2(4.0, 9.0), _wall)
				knee = knee.lerp(Vector2(7.0, -1.0), _wall)
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
	_draw_pencil()
	_draw_scarf_tail(fall)
	_draw_cloak(fall)
	_draw_head()
	draw_set_transform(Vector2.ZERO)
	if _wall > 0.3:  # hand dragging along the wall behind him
		var w := clampf((_wall - 0.3) / 0.4, 0.0, 1.0)
		var grip := Vector2(-13.0, -27.0)
		var bend := (shoulder + grip) * 0.5 + Vector2(-2.0, 5.0)
		draw_polyline(PackedVector2Array([shoulder, bend.lerp(shoulder, 1.0 - w), grip.lerp(shoulder, 1.0 - w)]),
			INK, 4.5)
		draw_circle(grip.lerp(shoulder, 1.0 - w), 3.5, INK)
	if _kneel > 0.3:  # hand braced on the floor
		var a := clampf((_kneel - 0.3) / 0.3, 0.0, 1.0)
		var hand := Vector2(17.0, -3.0)
		var elbow := (shoulder + hand) * 0.5 + Vector2(5.0, 1.0)
		draw_polyline(PackedVector2Array([shoulder.lerp(hand, 1.0 - a), elbow.lerp(hand, 1.0 - a), hand]),
			INK, 4.5)
		draw_circle(hand, 3.5, INK)

	if dashing:
		for i in 3:
			var y := -10.0 - i * 13.0
			draw_line(Vector2(-22 - i * 6, y), Vector2(-58 - i * 10, y), Color(DUST, 0.9), 3.0)
	if charge > 0.0:
		_draw_charge()
	if _coil_draw > 0.3:
		_draw_coil()


## Sparkle ring at the boots once the crouch is fully coiled (the pose itself
## shows the build-up; extra lines here would catch the sticker outline).
func _draw_coil() -> void:
	if crouch >= 1.0:
		for j in 4:
			var ang := _time * 9.0 + j * TAU / 4.0
			draw_circle(Vector2(cos(ang) * 14.0, -2.0 + sin(ang) * 3.0), 1.8, Color(1.0, 0.92, 0.55))


## Ground puffs thrown out by a coiled launch (player.gd calls this).
func launch_burst(depth: float) -> void:
	for j in int(3 + depth * 5.0):
		var dir := -1.0 if j % 2 == 0 else 1.0
		_dust.append({"p": get_global_transform() * Vector2(dir * (4.0 + j * 2.0), -2.0), "age": 0.0,
			"drift": Vector2(dir * (60.0 + j * 25.0) * depth, -10.0 - j * 4.0)})


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
	var spread := 1.0 + 0.8 * _coil_draw  # feet plant wider in a crouch
	var stance := Vector2((-3.0 + k * 6.0) * spread, 0.0)
	var run := Vector2(sin(ph) * 9.0, -maxf(0.0, cos(ph)) * 7.0)  # lifted while swinging forward
	return stance.lerp(run, _run)


func _draw_pencil() -> void:
	# pencil sword slung across the back, tip up
	var grip := Vector2(-13, 3)
	var tip := Vector2(7, -47)
	var dir := (tip - grip).normalized()
	draw_line(grip, tip, INK, 6.5)
	draw_line(grip, tip - dir * 2.0, pencil_color, 3.5)
	draw_line(grip, grip + dir * 5.0, Color(0.9, 0.5, 0.55), 3.5)  # eraser end
	draw_colored_polygon(PackedVector2Array([tip - dir.orthogonal() * 3.0, tip + dir * 8.0,
		tip + dir.orthogonal() * 3.0]), Color(0.9, 0.8, 0.65))
	draw_line(tip + dir * 5.0, tip + dir * 8.0, INK, 2.0)


func _draw_cloak(fall: float) -> void:
	var trail := 7.0 * _run + (8.0 if dashing else 0.0)
	var flutter := sin(_time * 16.0) * 1.6 * maxf(maxf(_run, absf(fall)), _wall)
	var lift := -6.0 * maxf(fall, 0.0) - 5.0 * _wall  # hem billows up while falling / sliding
	var flare := 1.0 + 0.55 * _kneel  # a hard landing spreads the hem over the floor
	# hem points, front to back
	var hem := PackedVector2Array([
		Vector2(14 * flare, lift * 0.4 + 3.0 * _kneel),
		Vector2(6 * flare, lift * 0.5 + 4.0 * _kneel),
		Vector2(0, lift * 0.7 + flutter * 0.5 + 4.0 * _kneel),
		Vector2(-7 * flare, lift + flutter + 4.0 * _kneel),
		Vector2((-15 - trail) * flare, -trail * 0.3 + lift + flutter + 3.0 * _kneel),
	])
	# torn-page lining: a zigzag strip hanging below the hem
	var page := PackedVector2Array()
	for p in hem:
		page.append(p + Vector2(0, -3))
	for i in range(hem.size() - 1, -1, -1):
		page.append(hem[i] + Vector2(0, 2.5))
		if i > 0:
			page.append((hem[i] + hem[i - 1]) * 0.5 + Vector2(0, 7.0 + flutter * 0.4))
	draw_colored_polygon(page, page_color)
	var coat := PackedVector2Array([Vector2(-10, -20), Vector2(10, -20)])
	coat.append_array(hem)
	draw_colored_polygon(coat, cloak_color)
	# front rim light so the dark coat keeps some form
	draw_colored_polygon(PackedVector2Array([Vector2(6, -20), Vector2(10, -20),
		hem[0], Vector2(9, lift * 0.45)]), cloak_rim)


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
	# round pale face
	draw_colored_polygon(_round_rect(Rect2(-10, -44, 21, 21), 9.0), mask_color)
	# two eyes (blink together)
	var open := 1.0 if _blink <= 0.0 else 0.15
	for ex in [1.5, 8.0]:
		draw_set_transform_matrix(_upper * Transform2D(0.0, Vector2(1.0, open), 0.0, Vector2(ex, -33)))
		draw_colored_polygon(_ellipse(1.8, 3.8), eye_color)
	draw_set_transform_matrix(_upper)
	# wide-brimmed hat with a coloured band; the brim tips with speed
	var tip := clampf(velocity.x * facing / max_speed, -1.0, 1.0) * -0.06
	draw_set_transform_matrix(_upper * Transform2D(tip, Vector2(1, -41)))
	draw_colored_polygon(_ellipse(21.0, 4.8), hat_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(-8, -17), Vector2(9, -15),
		Vector2(11, -2)]), hat_color)
	draw_line(Vector2(-10, -4.5), Vector2(11, -4.5), band_color, 3.0)
	draw_line(Vector2(-16, -1.5), Vector2(8, -2.5), hat_color.lightened(0.25), 1.5)
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
