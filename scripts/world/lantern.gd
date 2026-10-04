@tool
extends Node2D
## A paper lantern: the Writer's kind of light in the platformer.
##  - holds sketch platforms solid and refills Vesper's Ember inside `radius`
##  - monster light: Crossed-Outs lose their X, Crumples unfold, Scribbles flee
##  - with `casts_shadows`, solid world between it and a point blocks it
##    (light rule 3), and lit shadow casters throw shadow ink away from it
##  - hit it (slash, pogo or ink wave) to switch it on / off
##  - `swing` > 0 makes it a pendulum, so its light and shadows sweep.
## The node sits at the pivot; the lamp hangs `chain` px below it.

const Lights = preload("res://scripts/world/lights.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const INK := Color(0.05, 0.03, 0.1)

@export var lit := true:
	set(value):
		lit = value
		queue_redraw()
@export var radius := 220.0:
	set(value):
		radius = value
		queue_redraw()
@export var casts_shadows := true
## Chain length from the pivot (this node) down to the lamp. Use a short
## chain with `post = true` for a lamp on a post instead.
@export var chain := 60.0:
	set(value):
		chain = value
		queue_redraw()
## Draw a post from the lamp down to the floor this many px below it (0 = hanging).
@export var post := 0.0:
	set(value):
		post = value
		queue_redraw()
## Pendulum swing amplitude (degrees); 0 = still.
@export var swing := 0.0
@export var swing_period := 3.0
@export var swing_phase := 0.0
## Paper colour of the shade.
@export var paper := Color(0.95, 0.3, 0.24)

var _time := 0.0
var _hit_cd := 0.0
var _body: StaticBody2D
var _glow: Node2D
var _flare := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("lantern")
	add_to_group(Lights.DRAWN)
	add_to_group(Lights.MONSTER)
	_time = swing_phase
	# hit target on the enemy layer so slashes and ink waves find it; it
	# never collides with anything and isn't in the "enemy" group
	_body = StaticBody2D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	_body.set_script(preload("res://scripts/world/lantern_hitbox.gd"))
	_body.lantern = self
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 52)
	cs.shape = rect
	_body.add_child(cs)
	add_child(_body)
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.z_index = -1
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_flare = maxf(_flare - delta * 3.0, 0.0)
	_body.position = _lamp_local()
	queue_redraw()
	_glow.queue_redraw()


func _angle() -> float:
	if swing <= 0.0:
		return 0.0
	return deg_to_rad(swing) * sin(TAU * _time / swing_period)


func _lamp_local() -> Vector2:
	return Vector2(0, chain).rotated(_angle())


## Where the light comes from, in world space.
func lamp_position() -> Vector2:
	return to_global(_lamp_local())


func reaches(point: Vector2) -> bool:
	if not lit:
		return false
	var from := lamp_position()
	if from.distance_squared_to(point) > radius * radius:
		return false
	return not (casts_shadows and Lights.blocked(get_world_2d(), from, point))


func lights(point: Vector2) -> bool:
	return reaches(point)


## Slash / pogo / ink wave: toggle.
func take_hit(_damage: int, _hit_dir: Vector2, _from_pos: Vector2) -> void:
	if _hit_cd > 0.0:
		return
	_hit_cd = 0.3
	lit = not lit
	_flare = 1.0
	var p := ComicText.new()
	p.text = "FWUMP!" if lit else "PFFT!"
	p.color = Color(1.0, 0.85, 0.4) if lit else Color(0.7, 0.7, 0.78)
	p.font_size = 24
	p.position = lamp_position() + Vector2(0, -50)
	get_tree().current_scene.add_child(p)


func _draw_glow() -> void:
	if not lit:
		return
	var lp := _lamp_local()
	var flick := 1.0 + sin(_time * 11.0) * 0.015 + sin(_time * 4.7) * 0.02
	Lights.draw_glow(_glow, lp, radius * flick, Color(1.0, 0.75, 0.35, 0.3 + 0.3 * _flare))
	Lights.draw_glow(_glow, lp, 60.0 * flick, Color(1.0, 0.7, 0.3, 0.5))


func _draw() -> void:
	var lp := _lamp_local()
	var ang := _angle()
	if lit:
		# faint edge of the light, so you can read its reach
		draw_arc(lp, radius, 0, TAU, 64, Color(1.0, 0.85, 0.45, 0.3), 2.0)
	if post > 0.0:
		draw_rect(Rect2(lp + Vector2(-4, 20), Vector2(8, post - 20)), INK)
		draw_rect(Rect2(lp + Vector2(-14, post - 8), Vector2(28, 8)), INK)
	if chain > 0.0 and post <= 0.0:
		var n := int(chain / 10.0)
		for k in n:  # chain links
			var p := Vector2(0, (k + 0.5) * chain / n).rotated(ang)
			draw_set_transform(p, ang + (PI * 0.5 if k % 2 else 0.0), Vector2(1, 0.6))
			draw_arc(Vector2.ZERO, 4.0, 0, TAU, 8, INK, 2.5)
			draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2.ZERO, 5.0, INK)
	# the shade: a ribbed paper lantern with ink caps
	draw_set_transform(lp, ang, Vector2.ONE)
	var body := paper if lit else paper.lerp(Color(0.45, 0.45, 0.5), 0.75)
	var shade := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		shade.append(Vector2(cos(a) * 18.0, sin(a) * 22.0))
	for poly in Geometry2D.offset_polygon(shade, 3.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(shade, body)
	if lit:
		draw_circle(Vector2(0, 2), 9.0, Color(1.0, 0.92, 0.6))  # flame through the paper
	for x in [-9.0, 0.0, 9.0]:  # ribs
		draw_line(Vector2(x, -20), Vector2(x * 1.15, 0), Color(INK, 0.5), 1.5)
		draw_line(Vector2(x * 1.15, 0), Vector2(x, 20), Color(INK, 0.5), 1.5)
	draw_rect(Rect2(-10, -27, 20, 7), INK)
	draw_rect(Rect2(-10, 20, 20, 7), INK)
	if not lit:
		draw_line(Vector2(-6, -4), Vector2(6, 6), INK, 2.5)
		draw_line(Vector2(6, -4), Vector2(-6, 6), INK, 2.5)
	draw_set_transform(Vector2.ZERO)
