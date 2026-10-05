@tool
extends Node2D
## Decoration along one edge of solid terrain, in a zone's style (see
## depth_style.gd). No collision: put it on the edge of a rock block.
## Origin = the start of the edge; it runs `length` px right (floor, ceiling)
## or down (walls).

const Style = preload("res://scripts/depth/depth_style.gd")

enum Mode { FLOOR, CEILING, WALL_FACING_RIGHT, WALL_FACING_LEFT }

@export var length := 200.0:
	set(value):
		length = value
		queue_redraw()
@export var mode := Mode.FLOOR:
	set(value):
		mode = value
		queue_redraw()
@export_enum("Cavern", "Archive", "Works") var theme := 0:
	set(value):
		theme = value
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position))
	match mode:
		Mode.FLOOR:
			Style.floor_trim(self, 0.0, length, 0.0, theme, rng)
		Mode.CEILING:
			Style.ceiling_trim(self, 0.0, length, 0.0, theme, rng)
		Mode.WALL_FACING_RIGHT:
			Style.wall_trim(self, 0.0, 0.0, length, 1.0, theme, rng)
		Mode.WALL_FACING_LEFT:
			Style.wall_trim(self, 0.0, 0.0, length, -1.0, theme, rng)
