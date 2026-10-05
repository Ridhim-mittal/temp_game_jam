extends Node2D
## Vesper's Ember: a little flame that floats at her shoulder. Hold the
## "ember" action (right click) to raise it:
##  - its light makes sketch platforms solid (light rule 1) and is monster
##    light (rule 2: burns a Crossed-Out's X, unfolds Crumples, surfaces
##    Smudges, scatters Scribbles)
##  - stand still while it is raised and ink spreads out from your feet along
##    the sketch, inking it in for good (non-photo blue never takes ink)
##  - raising drains the meter. It refills slowly while lowered, fast in a
##    lit lantern's light. Running dry snuffs it until it recovers.
## Created by player.gd; the HUD reads `meter` / `max_meter`.

const Lights = preload("res://scripts/world/lights.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const INK := Color(0.05, 0.03, 0.1)
const FLAME := Color(1.0, 0.62, 0.18)
const CORE := Color(1.0, 0.95, 0.7)

@export var max_meter := 100.0
## Light radius while raised.
@export var radius := 230.0
## Meter per second while raised.
@export var drain := 25.0
## Meter per second while lowered (after `regen_delay`).
@export var regen := 20.0
@export var regen_delay := 0.6
## Meter per second inside a lit lantern's light (raised or not).
@export var lantern_regen := 60.0
## Over a light-drinking sketch (sketch_platform.gd drinks_light) the light
## drains this many times faster.
@export var blue_drain_mult := 2.0
## After running dry, the Ember can't be raised again until this much is back.
@export var relight_at := 20.0
## Inking: standing still with the Ember raised, ink spreads out from Vesper's
## feet at `ink_speed` px/s (after `ink_delay`), up to `ink_radius` each way.
@export var ink_radius := 170.0
@export var ink_speed := 260.0
@export var ink_delay := 0.15
@export var still_speed := 20.0

var meter := 100.0
var raised := false
var inks := true
var reach := 0.0  # current light radius (animates in and out)
var snuffed := false
var in_lantern := false
var over_blue := false  # over a sketch that drinks the light
var inking := false  # raised + standing still this frame
var ink_front := 0.0  # how far the spreading ink has reached (px from Vesper)

var _since_raised := 10.0
var _still := 0.0
var _time := 0.0
var _player: CharacterBody2D
var _glow: Node2D
var _pour_fx: Node2D  # in front of Vesper: the light going into him while healing


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	meter = max_meter
	add_to_group(Lights.DRAWN)
	add_to_group(Lights.MONSTER)
	z_index = -1
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_pour_fx = Node2D.new()
	_pour_fx.z_index = 12  # above the player's art (the Ember itself sits behind it)
	_pour_fx.draw.connect(_draw_pour)
	add_child(_pour_fx)


func _physics_process(delta: float) -> void:
	_time += delta
	var dead: bool = _player != null and _player.dead
	in_lantern = false
	for l in get_tree().get_nodes_in_group("lantern"):
		if l.lit and l.reaches(global_position):
			in_lantern = true
			break
	var want := Input.is_action_pressed("ember") and not dead and not snuffed
	raised = want
	if raised:
		_since_raised = 0.0
		over_blue = _over_blue()
		if not in_lantern:
			meter -= drain * delta * (blue_drain_mult if over_blue else 1.0)
		if meter <= 0.0:
			meter = 0.0
			raised = false
			snuffed = true
			_pop("FZZT...", Color(0.7, 0.7, 0.75))
	else:
		_since_raised += delta
		if _since_raised >= regen_delay:
			meter += regen * delta
	if in_lantern:
		meter += lantern_regen * delta
	meter = clampf(meter, 0.0, max_meter)
	if snuffed and meter >= relight_at:
		snuffed = false
	# light snaps up fast; when it gutters out it shrinks slowly, so the sketch
	# under you is the last thing to go (a warning, not a trapdoor)
	var rate := 10.0 if raised else (3.0 if snuffed else 5.0)
	reach = move_toward(reach, radius if raised else 0.0, delta * radius * rate)
	var still := raised and _player != null and _player.is_on_floor() and absf(_player.velocity.x) < still_speed
	_still = _still + delta if still else 0.0
	ink_front = clampf((_still - ink_delay) * ink_speed, 0.0, ink_radius)
	inking = ink_front > 0.0
	queue_redraw()
	_glow.queue_redraw()
	_pour_fx.queue_redraw()


## Spent on healing (player.gd, light or life): wait before refilling, as after raising it.
func hold_regen() -> void:
	_since_raised = 0.0


func _over_blue() -> bool:
	if _player == null:
		return false
	var feet := _player.global_position + Vector2(0, 26)
	for s in get_tree().get_nodes_in_group("sketch"):
		if not s.drinks_light:
			continue
		var p: Vector2 = s.to_local(feet)
		if absf(p.x) <= s.size.x * 0.5 and p.y > -240.0 and p.y < 30.0:  # jumping over it still counts
			return true
	return false


## Light rule 1: does the raised Ember reach `point`?
func reaches(point: Vector2) -> bool:
	return reach > 8.0 and global_position.distance_to(point) <= reach


## Light rule 2: monsters only react once the Ember is properly raised.
func lights(point: Vector2) -> bool:
	return raised and reach > radius * 0.5 and global_position.distance_to(point) <= reach * 0.9


func inks_at(point: Vector2) -> bool:
	return inking and absf(point.x - global_position.x) <= ink_front and absf(point.y - global_position.y) < 80.0


## The little flame's position (local): bobs at her shoulder, rises when raised.
func flame_pos() -> Vector2:
	var k := reach / radius
	var face := 1.0
	if _player and "facing" in _player:
		face = float(_player.facing)
	return Vector2(-16.0 * face * (1.0 - k) + 10.0 * face * k, -34.0 - 26.0 * k + sin(_time * 3.0) * 3.0)


## Light or life: sparks of the Ember spiral down into his chest, a ring of
## light tightens round him as the half bottle fills.
func _draw_pour() -> void:
	var pour := _pour()
	if pour < 0.0:
		return
	var fp := flame_pos()
	var chest := Vector2(0, -10)
	for m in 12:
		var ph := fmod(_time * 1.8 + m / 12.0, 1.0)
		var p := fp.lerp(chest, ph) + Vector2.from_angle(ph * TAU * 1.5 + m) * 26.0 * (1.0 - ph)
		var r := 3.4 * (1.0 - ph * 0.5)
		_pour_fx.draw_circle(p, r + 1.5, Color(INK, 0.5 * (1.0 - ph)))
		_pour_fx.draw_circle(p, r, Color(1.0, 0.85, 0.4, 1.0 - ph * 0.5))
	var rr := 46.0 * (1.0 - pour) + 12.0
	_pour_fx.draw_arc(chest, rr, 0, TAU, 32, Color(1.0, 0.9, 0.55, 0.35 + 0.6 * pour), 3.0)
	_pour_fx.draw_arc(chest, rr + 4.0, 0, TAU, 32, Color(INK, 0.35 * pour), 1.5)


## 0..1 while Vesper pours the Ember into ink (player.gd heal), else -1.
func _pour() -> float:
	return _player.heal_progress() if _player and _player.has_method("heal_progress") else -1.0


func _draw_glow() -> void:
	var k := reach / radius
	var fp := flame_pos()
	var pour := _pour()
	if pour >= 0.0:  # light going into him: his whole body glows warmer as it fills
		Lights.draw_glow(_glow, Vector2(0, -10), 60.0 + 40.0 * pour, Color(1.0, 0.75, 0.35, 0.5 + 0.35 * pour))
	var flick := 1.0 + sin(_time * 17.0) * 0.03 + sin(_time * 7.3) * 0.04
	Lights.draw_glow(_glow, fp, (26.0 + 6.0 * meter / max_meter) * flick, Color(1.0, 0.6, 0.2, 0.55))
	if k > 0.02:
		Lights.draw_glow(_glow, fp, reach * flick, Color(1.0, 0.72, 0.3, 0.4 * k))


func _draw() -> void:
	var k := reach / radius
	var fp := flame_pos()
	if k > 0.02:
		# dashed reach ring, so you can see what your light will hold up
		var n := 48
		for i in n:
			if i % 2 == 0:
				var a0 := TAU * i / n + _time * 0.4
				draw_arc(Vector2.ZERO, reach, a0, a0 + TAU / n, 3, Color(1.0, 0.85, 0.45, 0.8 * k), 2.5)
	# the flame itself: ink-outlined teardrop, size shows the meter
	var frac := meter / max_meter
	var s := (0.55 + 0.45 * frac) * (1.0 + 0.35 * k)
	if snuffed:
		s = 0.45
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var r := 7.0 * s
		var p := Vector2(cos(a) * r, sin(a) * r * 0.9)
		if p.y < 0.0:
			p.y *= 1.8 + 0.3 * sin(_time * 12.0)  # tip flickers
			p.x *= 1.0 - 0.4 * absf(p.y) / (r * 1.8)
		pts.append(fp + p)
	var body := FLAME if not snuffed else Color(0.55, 0.55, 0.6)
	if raised and over_blue:
		body = FLAME.lerp(Color(0.45, 0.75, 1.0), 0.6 + 0.2 * sin(_time * 20.0))  # the blue drinking it
	if raised and frac < 0.25 and fmod(_time, 0.2) < 0.1:
		body = Color(1.0, 0.95, 0.8)  # running low: the flame stutters
	for poly in Geometry2D.offset_polygon(pts, 2.5, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(pts, body)
	draw_circle(fp + Vector2(0, 1.5 * s), 3.2 * s, CORE if not snuffed else Color(0.8, 0.8, 0.85))


func _pop(text: String, col: Color) -> void:
	var p := ComicText.new()
	p.text = text
	p.color = col
	p.font_size = 22
	p.position = global_position + Vector2(0, -80)
	get_tree().current_scene.add_child(p)
