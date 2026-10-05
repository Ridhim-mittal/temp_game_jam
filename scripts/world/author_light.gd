extends Node2D
## The author's light in 2D (Shade's City): a beam from the moon in the
## painting sweeps the street around Vesper while he is between `zone_from`
## and `zone_to`. Standing in it fills an erase meter over his head; a full
## meter costs `damage` half ink bottles ("ERASED!"). Anything in the "light_cover" group
## (light_cover.gd: awnings, scaffolds, the billboard) blocks it and throws a
## visible shadow inside the beam: that's where to hide.
## Place at the world origin; `street_y` is the street top in world space.

const COMIC = preload("res://scripts/effects/comic_text.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const BEAM := Color(1.0, 0.96, 0.78)
const ERASER := Color(1.0, 0.55, 0.62)

@export var zone_from := 3200.0
@export var zone_to := 5600.0
@export var street_y := 600.0
## Where the moon sits on the screen (fraction of the viewport).
@export var moon := Vector2(0.52, 0.08)
@export var half_width := 95.0
## How far either side of Vesper the beam roams, and its top speed (px/s).
@export var roam := 420.0
@export var max_speed := 300.0
@export var fill_time := 1.3
@export var damage := 3.0

var meter := 0.0
var _x := 0.0
var _t := 0.0
var _on := 0.0
var _lit := false
var _origin := Vector2.ZERO
var _cooldown := 0.0


func _ready() -> void:
	z_index = -2
	_x = zone_from


func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player")
	return null if p == null or p.dead else p


func _process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var p := _player()
	var cam := get_viewport().get_camera_2d()
	if cam:
		_origin = cam.get_screen_center_position() - get_viewport_rect().size * 0.5 + get_viewport_rect().size * moon
	var active := p != null and p.global_position.x > zone_from and p.global_position.x < zone_to
	_on = move_toward(_on, 1.0 if active else 0.0, delta * 1.5)
	if p:
		var want := p.global_position.x + roam * sin(_t * 0.9) + roam * 0.35 * sin(_t * 2.3 + 1.0)
		if absf(want - _x) > roam * 2.0:
			_x = want - signf(want - _x) * roam  # far behind (a respawn): catch up
		_x = move_toward(_x, want, max_speed * delta)
		if _on <= 0.0:
			_x = p.global_position.x - roam  # come in from the side next time
	_lit = active and _on > 0.6 and p != null and lights(p.global_position + Vector2(0, -10))
	if _lit:
		if meter <= 0.0:
			_pop(p.global_position + Vector2(0, -80), "!", BEAM)
		meter = minf(meter + delta / fill_time, 1.0)
		if meter >= 1.0 and _cooldown <= 0.0:
			p.take_damage(damage, _origin)
			_pop(p.global_position + Vector2(0, -90), "ERASED!", ERASER)
			meter = 0.0
			_cooldown = 1.0
	else:
		meter = maxf(meter - delta * 0.6, 0.0)
	queue_redraw()


## Is `point` in the beam and not shaded by cover?
func lights(point: Vector2) -> bool:
	if _on <= 0.0 or point.y < _origin.y:
		return false
	var t := (point.y - _origin.y) / (street_y - _origin.y)
	var cx := lerpf(_origin.x, _x, t)
	if absf(point.x - cx) > half_width * t + 6.0:
		return false
	for c in get_tree().get_nodes_in_group("light_cover"):
		if _blocks(c.get_cover_rect(), _origin, point):
			return false
	return true


func _blocks(r: Rect2, a: Vector2, b: Vector2) -> bool:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return r.has_point(b)


func _draw() -> void:
	if _on <= 0.0:
		return
	var a := _on
	var l := Vector2(_x - half_width, street_y)
	var r := Vector2(_x + half_width, street_y)
	var beam := PackedVector2Array([_origin + Vector2(-8, 0), _origin + Vector2(8, 0), r, l])
	var pulse := 0.85 + 0.15 * sin(_t * 6.0)
	draw_colored_polygon(beam, Color(BEAM, 0.42 * a * pulse))
	draw_colored_polygon(PackedVector2Array([_origin, Vector2(_x + half_width * 0.45, street_y), Vector2(_x - half_width * 0.45, street_y)]),
		Color(1.0, 1.0, 0.95, 0.35 * a))
	for e in [[_origin + Vector2(-8, 0), l], [_origin + Vector2(8, 0), r]]:
		draw_line(e[0], e[1], Color(INK, 0.5 * a), 5.0)
		draw_line(e[0], e[1], Color(1.0, 0.98, 0.85, 0.9 * a), 2.0)
	var pool := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		pool.append(Vector2(_x + cos(t) * half_width * 1.2, street_y + sin(t) * 14.0))
	draw_colored_polygon(pool, Color(1.0, 0.98, 0.85, 0.7 * a))
	# shadows the cover throws inside the beam
	for c in get_tree().get_nodes_in_group("light_cover"):
		var cr: Rect2 = c.get_cover_rect()
		var bl := Vector2(cr.position.x, cr.end.y)
		var br := cr.end
		var quad := PackedVector2Array([bl, br, _proj(br), _proj(bl)])
		for piece in Geometry2D.intersect_polygons(beam, quad):
			draw_colored_polygon(piece, Color(0.05, 0.03, 0.12, 0.45 * a))
	# the erase meter over Vesper's head
	var p := _player()
	if p and meter > 0.0:
		var at := p.global_position + Vector2(-32, -78)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(68, 12)), INK)
		draw_rect(Rect2(at, Vector2(64, 8)), Color(0.3, 0.26, 0.36))
		draw_rect(Rect2(at, Vector2(64 * meter, 8)), ERASER.lerp(Color(1, 0.2, 0.25), meter))
		draw_string(FONT, at + Vector2(0, -4), "ERASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ERASER if _lit else Color(ERASER, 0.6))


func _proj(p: Vector2) -> Vector2:
	if p.y <= _origin.y + 1.0:
		return p
	return _origin + (p - _origin) * ((street_y - _origin.y) / (p.y - _origin.y))


func _pop(at: Vector2, text: String, col: Color) -> void:
	var c := COMIC.new()
	c.text = text
	c.color = col
	c.position = at
	get_tree().current_scene.add_child(c)
