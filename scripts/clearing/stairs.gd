@tool
extends Node3D
## A staircase of the Writer's giant books climbing away from the camera
## (towards -Z): each step is a book lying on the pile below it (coloured
## boards, cream pages at the edges, the spine to one side), the pile
## reaching down into the void as a ream of page edges, so the stairs read
## as one solid structure; a stack of paper stands either side as a low
## wall. A hidden ramp is the floor. (Was mossy stone; `stone` now tints the
## paper.)

const Toon = preload("res://scripts/clearing/toon.gd")
## The books' boards, faded.
const COVERS := [Color(0.42, 0.18, 0.2), Color(0.18, 0.26, 0.4), Color(0.24, 0.34, 0.26), Color(0.46, 0.36, 0.2),
	Color(0.3, 0.2, 0.38)]
const PAGES := Color(0.86, 0.82, 0.72)
const INK := Color(0.08, 0.06, 0.1)

@export var steps := 9:
	set(v):
		steps = v
		_rebuild()
@export var width := 4.0:
	set(v):
		width = v
		_rebuild()
@export var step_height := 0.32:
	set(v):
		step_height = v
		_rebuild()
@export var step_depth := 0.7:
	set(v):
		step_depth = v
		_rebuild()
@export var base_depth := 7.0
## Wall off the top (when the stairs lead nowhere yet).
@export var top_wall := true
@export var stone := Color(0.62, 0.6, 0.58):
	set(v):
		stone = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var paper := PAGES.lerp(stone, 0.25)
	var edges := {"pages": 0.09, "line": paper.darkened(0.55)}
	for i in steps:
		var top := (i + 1) * step_height
		var z := -(i + 0.5) * step_depth
		# the pile under this book, down into the void: page edges
		var h := top - step_height + base_depth
		Toon.part(root, Toon.box(Vector3(width, h, step_depth)), paper.darkened(0.42), Vector3(0, top - step_height - h * 0.5, z),
			Vector3.ZERO, edges)
		# the book itself, a little askew on the pile
		var book := Node3D.new()
		book.position = Vector3(0.07 * sin(i * 2.3), top - step_height * 0.5, z)
		book.rotation_degrees.y = 1.6 * sin(i * 1.7)
		root.add_child(book)
		var cover: Color = COVERS[(i * 3 + 1) % COVERS.size()]
		var board := 0.05
		for y in [step_height * 0.5 - board * 0.5, -step_height * 0.5 + board * 0.5]:
			Toon.part(book, Toon.box(Vector3(width + 0.06, board, step_depth + 0.08)), cover, Vector3(0, y, 0.0), Vector3.ZERO,
				{"outline": 0.02})
		Toon.part(book, Toon.box(Vector3(width - 0.06, step_height - board * 2.0, step_depth)), PAGES, Vector3(0.03, 0, 0.02),
			Vector3.ZERO, {"pages": 0.035, "line": PAGES.darkened(0.3), "outline": 0.0})
		var spine := -1.0 if i % 2 == 0 else 1.0
		Toon.part(book, Toon.box(Vector3(0.1, step_height, step_depth + 0.08)), cover.darkened(0.2),
			Vector3(spine * (width * 0.5 + 0.02), 0, 0), Vector3.ZERO, {"outline": 0.02})
		# a gilt band across the spine
		Toon.part(book, Toon.box(Vector3(0.11, 0.035, step_depth + 0.09)), Color(0.72, 0.6, 0.34), Vector3(spine * (width * 0.5 + 0.02), 0, 0),
			Vector3.ZERO, {"outline": 0.0})
	var run := steps * step_depth
	var rise := steps * step_height
	for side in [-1, 1]:
		# a ream of paper stacked high, capped with a board
		var wall_h := rise + base_depth + 0.6
		Toon.part(root, Toon.box(Vector3(0.7, wall_h, run)), paper.darkened(0.3),
			Vector3(side * (width * 0.5 + 0.35), rise + 0.6 - wall_h * 0.5, -run * 0.5), Vector3.ZERO, edges)
		Toon.part(root, Toon.box(Vector3(0.78, 0.06, run + 0.08)), COVERS[1 if side < 0 else 3],
			Vector3(side * (width * 0.5 + 0.35), rise + 0.63, -run * 0.5), Vector3.ZERO, {"outline": 0.02})
	if not Engine.is_editor_hint():
		# The walkable ramp passes through the middle of every tread, so the
		# feet stay on the stone instead of sinking into the steps. It starts
		# half a step in front of the stairs (a gentle lead-in from the
		# ground) and ends half a step before the top.
		var slope := atan2(rise, run)
		var thick := 0.2
		var ramp_len := run / cos(slope)
		var center := Vector3(0, rise * 0.5, (step_depth - run) * 0.5)
		center += Vector3(0, -cos(slope), -sin(slope)) * thick * 0.5  # top face on the line
		Toon.collider(root, Toon.box_shape(Vector3(width, thick, ramp_len)), center, Vector3(rad_to_deg(slope), 0, 0))
		# flat landing on the back half of the top tread, where the ramp ends
		Toon.collider(root, Toon.box_shape(Vector3(width, thick, step_depth * 0.5)),
			Vector3(0, rise - thick * 0.5, -run + step_depth * 0.25))
		for side in [-1, 1]:
			Toon.collider(root, Toon.box_shape(Vector3(0.7, 4.0, run)),
				Vector3(side * (width * 0.5 + 0.35), rise * 0.5 + 1.0, -run * 0.5))
		if top_wall:  # don't walk off the top
			Toon.collider(root, Toon.box_shape(Vector3(width, 4.0, 0.4)), Vector3(0, rise + 2.0, -run - 0.2))
