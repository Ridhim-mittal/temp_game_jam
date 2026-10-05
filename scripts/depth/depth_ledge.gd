@tool
extends StaticBody2D
## A ledge in a zone's style: near-black slab with a lit top edge. By default
## it is one-way (jump up through it, land on top), which is what makes tall
## rooms climbable. Origin = centre of the top surface's slab.

const Style = preload("res://scripts/depth/depth_style.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")

@export var size := Vector2(180, 18):
	set(value):
		size = value
		queue_redraw()
@export_enum("Cavern", "Archive", "Works") var theme := 0:
	set(value):
		theme = value
		queue_redraw()
@export var one_way := true


func _ready() -> void:
	collision_layer = 1
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.one_way_collision = one_way
	add_child(cs)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position))
	var half := size * 0.5
	var b := InkBatch.new()  # one draw call
	var dark: Color = Style.PALETTES[theme].dark
	match theme:
		Style.CAVERN:  # a floating clod: rounded belly, roots trailing below
			b.draw_colored_polygon(Style.arc_pts(Vector2(0, -half.y), half.x, size.y + 22.0, 0, PI, 14), dark)
			for i in int(size.x / 30.0):
				var x := rng.randf_range(-half.x * 0.8, half.x * 0.8)
				var pts := PackedVector2Array()
				for k in 6:
					pts.append(Vector2(x + sin(k * 1.1 + i) * 4.0, half.y + 6.0 + k * rng.randf_range(4.0, 9.0)))
				b.draw_polyline(pts, dark, 2.0, true)
		Style.ARCHIVE:  # a little humped bridge on scrolled brackets
			var body := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y + 16.0)])
			body.append_array(Style.arc_pts(Vector2(0, half.y + 16.0), half.x * 0.72, 14.0, 0, -PI, 12))
			body.append(Vector2(-half.x, half.y + 16.0))
			b.draw_colored_polygon(body, dark)
			b.draw_polyline(Style.arc_pts(Vector2(0, half.y + 16.0), half.x * 0.72, 14.0, 0, -PI, 12), Style.depth(theme, 0.6), 1.5)
			for sx in [-1.0, 1.0]:
				Style.spiral(b, Vector2(sx * (half.x - 10.0), half.y + 10.0), 7.0, 1.5, Style.depth(theme, 0.6), 1.5, sx)
		Style.WORKS:  # a plank on two braces
			for sx in [-1.0, 1.0]:
				b.draw_line(Vector2(sx * half.x * 0.6, half.y), Vector2(sx * half.x * 0.25, half.y + 30.0), dark, 6.0)
			b.draw_rect(Rect2(-half, size), dark)
	Style.floor_trim(b, -half.x, half.x, -half.y, theme, rng)
	b.flush(self)
