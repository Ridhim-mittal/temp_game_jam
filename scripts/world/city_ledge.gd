@tool
extends StaticBody2D
## A hover platform for the City and the Sketchbook (replaces the wooden
## plank): a sleek rounded steel deck with a neon top line and an inset light
## strip, two thruster pods underneath whose light beams flicker. One-way:
## jump up through it, land on top. Origin = centre of the deck.

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const OnScreen = preload("res://scripts/core/on_screen.gd")
const INK := Color(0.05, 0.03, 0.1)

@export var size := Vector2(160, 16):
	set(value):
		size = value
		queue_redraw()
@export var trim := Color(0.38, 0.95, 1.0)
@export var thruster := Color(1.0, 0.45, 0.78)
@export var deck_top := Color(0.9, 0.93, 1.0)
@export var deck_bottom := Color(0.5, 0.55, 0.78)

var _time := 0.0
var _glow: Node2D


func _ready() -> void:
	collision_layer = 1
	_time = float(absi(hash(Vector2i(position))) % 100) * 0.1
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.show_behind_parent = true
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.one_way_collision = true
	add_child(cs)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if OnScreen.near(self, size.x):
		_glow.queue_redraw()  # the thrusters flicker; the deck itself never changes


func _pods() -> Array:
	return [Vector2(-size.x * 0.3, size.y * 0.5 + 5.0), Vector2(size.x * 0.3, size.y * 0.5 + 5.0)]


func _capsule(r: Rect2) -> PackedVector2Array:
	var rad := r.size.y * 0.5
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(Vector2(r.end.x - rad, r.position.y + rad) + Vector2.from_angle(-PI * 0.5 + PI * i / 8.0) * rad)
	for i in 9:
		pts.append(Vector2(r.position.x + rad, r.position.y + rad) + Vector2.from_angle(PI * 0.5 + PI * i / 8.0) * rad)
	return pts


func _draw() -> void:
	var b := InkBatch.new()
	var r := Rect2(-size * 0.5, size)
	# thruster pods under the deck
	for p in _pods():
		var pod := PackedVector2Array([p + Vector2(-13, -6), p + Vector2(13, -6), p + Vector2(9, 5), p + Vector2(-9, 5)])
		var o := pod.duplicate()
		o.append(pod[0])
		b.draw_colored_polygon(pod, Color(0.16, 0.15, 0.3))
		b.draw_polyline(o, INK, 2.5)
		b.draw_rect(Rect2(p + Vector2(-7, 3), Vector2(14, 3)), thruster)
	# the deck: a rounded steel capsule, light on top, darker underneath
	var deck := _capsule(r)
	var cols := PackedColorArray()
	for p in deck:
		cols.append(deck_top.lerp(deck_bottom, clampf((p.y - r.position.y) / size.y, 0.0, 1.0)))
	var outline := _capsule(r.grow(2.5))
	b.draw_colored_polygon(outline, INK)
	b.draw_polygon(deck, cols)
	# an inset light strip along the middle, with end caps
	var strip := Rect2(r.position.x + size.y, r.position.y + size.y * 0.5 - 1.5, size.x - size.y * 2.0, 3.0)
	b.draw_rect(strip.grow(1.0), Color(INK, 0.55))
	b.draw_rect(strip, Color(trim, 0.85))
	# neon top line and a white highlight
	b.draw_line(Vector2(r.position.x + size.y * 0.5, r.position.y + 1.0), Vector2(r.end.x - size.y * 0.5, r.position.y + 1.0), trim, 2.5)
	b.draw_line(Vector2(r.position.x + size.y * 0.7, r.position.y + 0.5), Vector2(r.end.x - size.y * 0.7, r.position.y + 0.5), Color(1, 1, 1, 0.8), 1.0)
	b.flush(self)


func _draw_glow() -> void:
	# the thrusters' beams (flickering) and a faint neon haze over the deck
	for i in 2:
		var p: Vector2 = _pods()[i] + Vector2(0, 6)
		var f := 0.75 + 0.25 * sin(_time * 23.0 + i * 1.7) * sin(_time * 7.0 + i)
		var beam := 34.0 * f
		_glow.draw_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(7, 0), p + Vector2(12, beam), p + Vector2(-12, beam)]),
			PackedColorArray([Color(thruster, 0.55 * f), Color(thruster, 0.55 * f), Color(thruster, 0.0), Color(thruster, 0.0)]))
	var y := -size.y * 0.5
	var x0 := -size.x * 0.5 + size.y * 0.5
	var x1 := size.x * 0.5 - size.y * 0.5
	_glow.draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y - 12), Vector2(x0, y - 12)]),
		PackedColorArray([Color(trim, 0.22), Color(trim, 0.22), Color(trim, 0.0), Color(trim, 0.0)]))
