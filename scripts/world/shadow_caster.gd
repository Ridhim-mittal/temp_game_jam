@tool
extends StaticBody2D
## A cardboard cut-out (a star on a stick) that throws SHADOW INK: while a
## lit, shadow-casting lantern reaches it, its shadow is a solid black beam
## pointing away from that lantern (light rule 3, turned into a tool).
## Switch lanterns on and off to aim the beam; a swinging lantern sweeps it.
## The beam stops at walls. Like sketches it is one-way: jump up through it,
## land on top. The cut-out itself is solid and blocks light.

const Lights = preload("res://scripts/world/lights.gd")
const INK := Color(0.05, 0.03, 0.1)
const CARD := Color(0.86, 0.72, 0.5)

@export var radius := 30.0:
	set(value):
		radius = value
		queue_redraw()
@export var shadow_length := 420.0
@export var shadow_thickness := 22.0
## Stick from the cut-out down to the floor (0 = none, it hangs on a string).
@export var stick := 0.0:
	set(value):
		stick = value
		queue_redraw()

var _beams := {}  # lantern -> {body, grow}
var _time := 0.0
var _ink: Node2D


func _ready() -> void:
	collision_layer = 1
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.8
	cs.shape = circle
	add_child(cs)
	_ink = Node2D.new()
	_ink.top_level = true
	_ink.z_index = -1
	_ink.draw.connect(_draw_shadows)
	add_child(_ink)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var me := global_position
	var seen := {}
	for l in get_tree().get_nodes_in_group("lantern"):
		if not l.lit or not l.casts_shadows:
			continue
		var lamp: Vector2 = l.lamp_position()
		if lamp.distance_to(me) > l.radius or Lights.blocked(get_world_2d(), lamp, me, [get_rid()]):
			continue
		seen[l] = true
		if not _beams.has(l):
			_beams[l] = {"body": _make_beam(), "grow": 0.0, "len": 0.0}
		var b: Dictionary = _beams[l]
		b.grow = minf(b.grow + delta * 6.0, 1.0)
		var d: Vector2 = (me - lamp).normalized()
		var start := me + d * radius * 0.8
		# the shadow ends where it hits solid world
		var q := PhysicsRayQueryParameters2D.create(start, start + d * shadow_length, Lights.MASK_WORLD, [get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		b.len = (start.distance_to(hit.position) if not hit.is_empty() else shadow_length) * b.grow
		_place(b, start, d)
	for l in _beams.keys():
		if not seen.has(l):
			var b: Dictionary = _beams[l]
			b.grow -= delta * 6.0
			if b.grow <= 0.0 or not is_instance_valid(l):
				b.body.queue_free()
				_beams.erase(l)
			else:
				b.len = shadow_length * b.grow * 0.5
				b.body.get_child(0).set_deferred("disabled", true)
	_ink.queue_redraw()


func _make_beam() -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.collision_layer = Lights.LAYER_SKETCH
	body.collision_mask = 0
	body.sync_to_physics = false
	body.top_level = true
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.one_way_collision = true
	body.add_child(cs)
	add_child(body)
	body.global_position = global_position
	return body


func _place(b: Dictionary, start: Vector2, d: Vector2) -> void:
	var body: AnimatableBody2D = b.body
	var cs: CollisionShape2D = body.get_child(0)
	var length: float = maxf(b.len, 1.0)
	body.global_position = start
	body.global_rotation = d.angle()
	(cs.shape as RectangleShape2D).size = Vector2(length, shadow_thickness)
	cs.position = Vector2(length * 0.5, 0)
	# one-way points along local -Y: keep it facing up whichever way the beam goes
	cs.rotation = PI if d.x < 0.0 else 0.0
	b.start = start
	b.dir = d
	cs.set_deferred("disabled", b.grow < 0.8)


## Is `point` standing on a beam? (tests)
func beam_count() -> int:
	return _beams.size()


func _draw_shadows() -> void:
	for l in _beams:
		var b: Dictionary = _beams[l]
		if not b.has("start"):
			continue
		var s: Vector2 = b.start
		var d: Vector2 = b.dir
		var n := d.orthogonal()
		var length: float = b.len
		var w0 := shadow_thickness * 0.5
		var w1 := shadow_thickness * 0.5 + 8.0
		var quad := PackedVector2Array([s + n * w0, s + d * length + n * w1, s + d * length - n * w1, s - n * w0])
		_ink.draw_colored_polygon(quad, INK)
		# halftone speckle along the edges, boiling a little
		var boil := int(_time * 6.0)
		var k := 14.0
		while k < length - 6.0:
			var t := k / maxf(length, 1.0)
			var w := lerpf(w0, w1, t)
			for side in [-1.0, 1.0]:
				var j := float(absi(hash(Vector3i(int(k), int(side), boil))) % 100) / 100.0
				_ink.draw_circle(s + d * k + n * side * (w + 3.0 + j * 3.0), 2.0 + j, Color(INK, 0.7))
			k += 16.0
		# a highlight on the top edge so it reads as something you can stand on
		var up := n if n.y < 0.0 else -n
		_ink.draw_line(s + up * (w0 - 2.0), s + d * length + up * (w1 - 2.0), Color(0.45, 0.4, 0.65, 0.8), 2.0)


func _draw() -> void:
	if stick > 0.0:
		draw_rect(Rect2(-4, 0, 8, stick), INK)
		draw_rect(Rect2(-2, 2, 4, stick - 4), CARD.darkened(0.3))
	# five-point cardboard star
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(Vector2.from_angle(a) * (radius if i % 2 == 0 else radius * 0.48))
	for poly in Geometry2D.offset_polygon(pts, 3.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(pts, CARD)
	for i in range(0, 10, 2):  # corrugated card lines
		draw_line(Vector2.ZERO, pts[i] * 0.7, CARD.darkened(0.25), 1.5)
	draw_circle(Vector2.ZERO, 3.0, INK)
