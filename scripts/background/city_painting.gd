extends Node2D
## Backdrop of Shade's corrupted comic city: the team's concept painting
## (assets/backgrounds/shades_city.webp), scaled to the screen width above the
## street. It stays fixed on screen like a painted stage backdrop while the
## street scrolls past (the painting is one screen wide, so any drift would
## show its edge repeating; `drift` > 0 brings that back). A navy fill sits
## behind it in case a jump lifts the camera past its top edge.

const ParallaxScript = preload("res://scripts/background/comic_parallax.gd")
const PAINTING = preload("res://assets/backgrounds/shades_city.webp")

@export var camera_center := Vector2(640, 348)
## Screen y of the painting's top edge at `camera_center` (a little above
## the screen keeps the moon in view and more of the junk above the street).
@export var top_y := -30.0
## How fast the painting slides by as the camera moves (0 = fixed).
@export var drift := 0.0
@export var sky_fill := Color(0.08, 0.1, 0.24)


func _ready() -> void:
	var fill := CanvasLayer.new()
	fill.layer = -100
	var rect := ColorRect.new()
	rect.color = sky_fill
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(rect)
	add_child(fill)
	var width := get_viewport_rect().size.x
	var p := Parallax2D.new()
	p.set_script(ParallaxScript)
	p.reference_camera_center = camera_center
	p.scroll_scale = Vector2(drift, drift)
	if drift > 0.0:
		p.repeat_size = Vector2(width, 0)
		p.repeat_times = 3
	p.z_index = -10
	var art := Sprite2D.new()
	art.texture = PAINTING
	art.centered = false
	var k := width / PAINTING.get_width()
	art.scale = Vector2(k, k)
	art.position = Vector2(0, top_y)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	p.add_child(art)
	add_child(p)
