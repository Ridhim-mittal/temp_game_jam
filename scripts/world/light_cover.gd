@tool
extends StaticBody2D
## Something to hide under from the author's light (author_light.gd): a slab
## that blocks the beam and throws a shadow, standing on posts down to the
## street. Its top is a one-way platform. Origin = top-left of the slab.
##   AWNING     a redaction bar (black, pale rim) on two posts
##   SCAFFOLD   a steel deck with cross-bracing and hanging cables
##   BILLBOARD  a collapsed comic billboard leaning on legs (the big hideout)
##   BAR        a redaction bar floating free (a platform, no posts)

enum Kind { AWNING, SCAFFOLD, BILLBOARD, BAR }

const INK := Color(0.05, 0.03, 0.1)
const RIM := Color(1.0, 0.95, 0.8)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

@export var kind := Kind.AWNING:
	set(value):
		kind = value
		queue_redraw()
@export var size := Vector2(220, 22):
	set(value):
		size = value
		queue_redraw()
		_update_shape()
## Distance from the slab's underside down to the street (for the posts).
@export var post_height := 150.0:
	set(value):
		post_height = value
		queue_redraw()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	add_to_group("light_cover")
	_update_shape()


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.one_way_collision = true
		add_child(_shape)
	var box := _box()
	var r := RectangleShape2D.new()
	r.size = box.size
	_shape.shape = r
	_shape.position = box.get_center()


## The solid, light-blocking part (local): the billboard's face stands above
## its slab.
func _box() -> Rect2:
	if kind == Kind.BILLBOARD:
		return Rect2(Vector2(0, -90), size + Vector2(0, 90))
	return Rect2(Vector2.ZERO, size)


func get_cover_rect() -> Rect2:
	var b := _box()
	return Rect2(global_position + b.position, b.size)


func _draw() -> void:
	match kind:
		Kind.AWNING, Kind.BAR:
			if kind == Kind.AWNING:
				for x in [12.0, size.x - 20.0]:
					draw_rect(Rect2(x - 1, size.y, 10, post_height), INK)
					draw_rect(Rect2(x + 1, size.y, 6, post_height), Color(0.3, 0.3, 0.38))
			draw_rect(Rect2(Vector2(4, 6), size), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(Vector2.ZERO, size).grow(2), RIM)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
			var w := FONT.get_string_size("REDACTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(FONT, Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 + 5), "REDACTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(RIM, 0.35))
		Kind.SCAFFOLD:
			for x in [8.0, size.x * 0.5 - 4.0, size.x - 16.0]:
				draw_rect(Rect2(x, size.y, 8, post_height), INK)
			for k in 2:
				var x0 := 12.0 + k * size.x * 0.5
				draw_line(Vector2(x0, size.y + 6), Vector2(x0 + size.x * 0.45, size.y + post_height - 10), INK, 3.0)
				draw_line(Vector2(x0 + size.x * 0.45, size.y + 6), Vector2(x0, size.y + post_height - 10), INK, 3.0)
			draw_rect(Rect2(Vector2.ZERO, size).grow(2), INK)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.56, 0.62))
			draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 4)), RIM)
			for x in range(20, int(size.x), 40):
				draw_line(Vector2(x, 4), Vector2(x, size.y), Color(0.35, 0.36, 0.42), 2.0)
			for k in 3:  # cables dangling
				var x := size.x * (0.2 + k * 0.3)
				draw_polyline(PackedVector2Array([Vector2(x, size.y), Vector2(x + 12, size.y + 40), Vector2(x + 4, size.y + 70 + k * 15)]), INK, 2.0)
		Kind.BILLBOARD:
			for x in [20.0, size.x - 30.0]:
				draw_rect(Rect2(x, size.y, 12, post_height), INK)
			draw_line(Vector2(30, size.y + post_height), Vector2(size.x - 30, size.y + 10), INK, 4.0)
			var face := Rect2(Vector2(0, -90), Vector2(size.x, 90 + size.y))
			draw_rect(face.grow(3), INK)
			draw_rect(face, Color(0.95, 0.62, 0.72))
			draw_rect(Rect2(face.position + Vector2(10, 10), Vector2(face.size.x * 0.45, face.size.y - 20)), Color(0.55, 0.72, 0.95))
			draw_string(FONT, face.position + Vector2(face.size.x * 0.52, 44), "CORRUPTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.75, 0.08, 0.12))
			draw_rect(Rect2(face.position + Vector2(face.size.x * 0.5, 56), Vector2(face.size.x * 0.4, 16)), Color(0.02, 0.02, 0.03))
			for k in 4:  # torn strips
				var x := face.position.x + face.size.x * (0.15 + k * 0.22)
				draw_colored_polygon(PackedVector2Array([Vector2(x, face.end.y), Vector2(x + 14, face.end.y), Vector2(x + 6, face.end.y + 18 + k * 4)]), Color(0.92, 0.9, 0.82))
			draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 4)), RIM)
