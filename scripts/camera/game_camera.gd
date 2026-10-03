extends Camera2D
## Follow camera with trauma-based screen shake.

## Constant framing shift: shows more above the player than below (Hollow
## Knight style) and gives the comic skyline room. ComicParallax's
## reference_camera_center assumes this value.
@export var framing_offset := Vector2(0, -60)
@export var max_offset := Vector2(14, 10)
@export var decay := 3.0

var trauma := 0.0


func _ready() -> void:
	add_to_group("camera")


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(trauma - decay * delta, 0.0)
		var s := trauma * trauma
		offset = framing_offset + Vector2(randf_range(-1, 1) * max_offset.x * s, randf_range(-1, 1) * max_offset.y * s)
	else:
		offset = framing_offset
