@tool
extends Node3D
## Wide mossy stone staircase climbing away from the camera (towards -Z),
## with low side walls. Each step is a block reaching down into the void,
## so the stairs read as one solid structure. A hidden ramp is the floor.

const Toon = preload("res://scripts/clearing/toon.gd")

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
	Toon.merge_when_built(root)  # one mesh per material: far fewer draw calls
	for i in steps:
		var top := (i + 1) * step_height
		var h := top + base_depth
		Toon.part(root, Toon.box(Vector3(width, h, step_depth)), stone.darkened(0.25),
			Vector3(0, top - h * 0.5, -(i + 0.5) * step_depth), Vector3.ZERO, {"moss": 0.25})
		# a lighter tread slab with a lip, so every step reads as a step
		Toon.part(root, Toon.box(Vector3(width - 0.1, 0.1, step_depth + 0.08)), stone.lightened(0.08 * (i % 2)),
			Vector3(0, top - 0.04, -(i + 0.5) * step_depth + 0.06), Vector3.ZERO, {"moss": 0.2})
	var run := steps * step_depth
	var rise := steps * step_height
	for side in [-1, 1]:
		var wall_h := rise + base_depth + 0.6
		Toon.part(root, Toon.box(Vector3(0.7, wall_h, run)), stone.darkened(0.1),
			Vector3(side * (width * 0.5 + 0.35), rise + 0.6 - wall_h * 0.5, -run * 0.5), Vector3.ZERO,
			{"moss": 0.5, "tile": 0.6})
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
