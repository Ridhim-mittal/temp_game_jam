extends Node2D
## Backdrop of Shade's corrupted comic city, built like the City's
## (comic_background.tscn): layers at different depths that slide by at
## different speeds, so the street has real 3D depth.
##   far    the team's concept painting (assets/backgrounds/shades_city.webp):
##          the moon, the sky and the towers, drifting very slowly; it repeats
##          mirrored (every other copy flipped) so no seam ever shows
##   haze   a navy-violet wash over the painting's lower half
##   mid / near / roofs   procedural one-point-perspective skylines
##          (comic_skyline.gd) in the painting's pinks, blues and violets,
##          each nearer one faster, darker and more saturated; the rooftops are
##          near-black silhouettes so the street reads first
##   motes  drifting paper dust
##   front  dark railings and rubble passing in front of Vesper
## Because every layer is a real parallax plane, the pencil sketch outside the
## comic frame's live area (pencil_outside.gdshader) is a sketch of the same
## deep city, as in the City, instead of a cut through one pinned picture.
## Coordinates are screen space at `camera_center` (comic_parallax.gd).

const ParallaxScript = preload("res://scripts/background/comic_parallax.gd")
const Skyline = preload("res://scripts/background/comic_skyline.gd")
const Motes = preload("res://scripts/background/drift_motes.gd")
const Foreground = preload("res://scripts/background/comic_foreground.gd")
const HALFTONE = preload("res://shaders/comic_halftone.gdshader")
const PAINTING = preload("res://assets/backgrounds/shades_city.webp")

## Camera centre while Vesper stands on the street (player y 574, framing -226).
@export var camera_center := Vector2(640, 348)
## Screen y of the painting's top edge at `camera_center`.
@export var top_y := -30.0
## How fast the painting slides by as the camera moves (0 = pinned).
@export var drift := 0.05
## Screen y of the street's top at `camera_center` (600 - 348 + 360).
@export var street_y := 612.0
@export var sky_fill := Color(0.08, 0.1, 0.24)
@export var haze_color := Color(0.16, 0.12, 0.34)


func _ready() -> void:
	var fill := CanvasLayer.new()
	fill.layer = -100
	var rect := ColorRect.new()
	rect.color = sky_fill
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(rect)
	add_child(fill)
	_painting()
	_haze()
	# far to near: [seed, scroll, slot, widths, heights, depth, palette, ink, outline, haze, windows, lit]
	_skyline(707, 0.2, 150.0, Vector2(0.55, 0.95), Vector2(90, 230), Vector2(0.06, 0.1),
		[Color(0.62, 0.42, 0.82), Color(0.42, 0.5, 0.9), Color(0.85, 0.48, 0.72)],
		Color(0.12, 0.07, 0.24), 2.0, 0.5, Vector2(4, 6), 0.3, 4.5, 0.32)
	_skyline(808, 0.38, 210.0, Vector2(0.5, 0.9), Vector2(70, 200), Vector2(0.1, 0.16),
		[Color(0.92, 0.36, 0.62), Color(0.36, 0.46, 0.9), Color(0.62, 0.32, 0.78), Color(0.98, 0.56, 0.5)],
		Color(0.08, 0.04, 0.18), 3.0, 0.18, Vector2(6, 9), 0.35, 5.5, 0.4)
	_skyline(909, 0.62, 320.0, Vector2(0.18, 0.4), Vector2(18, 64), Vector2(0.16, 0.24),
		[Color(0.36, 0.24, 0.52), Color(0.3, 0.22, 0.48), Color(0.42, 0.26, 0.56)],
		Color(0.06, 0.03, 0.13), 3.5, 0.08, Vector2.ZERO, 0.0, 7.0, 0.4)
	var motes := _plane(0.85, -10)
	var m := Node2D.new()
	m.set_script(Motes)
	motes.add_child(m)
	var front := _plane(1.35, 50)
	var f := Node2D.new()
	f.set_script(Foreground)
	f.set("street_y", street_y + 314.0)
	f.set("lamp_top_y", street_y - 306.0)
	f.set("color", Color(0.05, 0.02, 0.1))
	f.set("rim_color", Color(0.95, 0.36, 0.66))
	front.add_child(f)


func _plane(scroll: float, z: int) -> Parallax2D:
	var p := Parallax2D.new()
	p.set_script(ParallaxScript)
	p.reference_camera_center = camera_center
	p.scroll_scale = Vector2(scroll, scroll)
	p.z_index = z
	add_child(p)
	return p


## The painting, mirrored on repeat: copy, flipped copy, copy... so each
## edge meets its own mirror image.
func _painting() -> void:
	var width := get_viewport_rect().size.x
	var k := width / PAINTING.get_width()
	var p := _plane(drift, -12)
	if drift > 0.0:
		p.repeat_size = Vector2(width * 2.0, 0)
		p.repeat_times = 3
	for i in 2:
		var art := Sprite2D.new()
		art.texture = PAINTING
		art.centered = false
		art.flip_h = i == 1
		art.scale = Vector2(k, k)
		art.position = Vector2(width * i, top_y)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		p.add_child(art)


## A wash over the painting's lower half (it holds the painting's own street
## junk, which must not read as somewhere to stand): pinned to the screen.
func _haze() -> void:
	var p := _plane(0.0, -11)
	var h := Polygon2D.new()
	var x0 := -400.0
	var x1 := get_viewport_rect().size.x + 400.0
	var y0 := street_y - 330.0
	var y1 := street_y + 400.0
	h.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	h.vertex_colors = PackedColorArray([Color(haze_color, 0.0), Color(haze_color, 0.0), Color(haze_color, 0.92), Color(haze_color, 0.92)])
	p.add_child(h)


func _skyline(seed: int, scroll: float, slot: float, widths: Vector2, heights: Vector2, depth: Vector2,
		palette: Array, ink: Color, outline: float, haze: float, windows: Vector2, lit: float,
		dot_spacing: float, dot_darkness: float) -> void:
	var p := _plane(scroll, -10)
	var d := Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = HALFTONE
	mat.set_shader_parameter("dot_spacing", dot_spacing)
	mat.set_shader_parameter("dot_darkness", dot_darkness)
	d.material = mat
	d.set_script(Skyline)
	d.set("seed", seed)
	d.set("slot_width", slot)
	d.set("width_range", widths)
	d.set("height_range", heights)
	d.set("street_y", street_y - 6.0 + scroll * 8.0)
	d.set("depth_range", depth)
	d.set("palette", PackedColorArray(palette))
	d.set("ink", ink)
	d.set("outline_width", outline)
	d.set("street_color", haze_color.darkened(0.3))
	d.set("haze", haze)
	d.set("haze_color", haze_color)
	d.set("window_size", windows)
	d.set("lit_chance", lit)
	d.set("lit_color", Color(1.0, 0.88, 0.6))
	d.set("side_windows", windows.x > 0.0 and scroll > 0.3)
	p.add_child(d)
