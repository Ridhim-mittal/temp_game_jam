extends CanvasLayer
## Puts the game inside a comic panel: a strip of printed page (paper with
## a halftone screen, printer's marks, a page number) round the edge of the
## screen and a thick, slightly hand-drawn ink border on the panel. The
## page and border match the next-panel transition (panel_turn.gd), so
## zooming out of the screen reveals the same page.
## Outside the level's playable areas (`live_areas`, world rects) the world
## is redrawn as a pencil sketch of itself (shaders/pencil_outside.gdshader),
## like the unfinished part of the page; the HUD sits above and stays as is.
## Drop one into a level (layer 1: above the world, under the HUD).

const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.96, 0.93, 0.86)
## The panel inside the page, in screen px (the rest is page margin).
const PANEL := Rect2(24, 18, 1232, 684)

@export var page_number := 1
## Playable parts of the level (world coordinates); the rest is pencil.
@export var live_areas: Array[Rect2] = []

var _art: Control
var _sketch_mat: ShaderMaterial


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps the pencil mask right while paused (and in panel_turn.gd)
	if not live_areas.is_empty():
		var sketch := ColorRect.new()
		sketch.set_anchors_preset(Control.PRESET_FULL_RECT)
		sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sketch_mat = ShaderMaterial.new()
		_sketch_mat.shader = preload("res://shaders/pencil_outside.gdshader")
		var areas := PackedVector4Array()
		for a in live_areas:
			areas.append(Vector4(a.position.x, a.position.y, a.end.x, a.end.y))
		while areas.size() < 8:
			areas.append(Vector4.ZERO)
		_sketch_mat.set_shader_parameter("areas", areas)
		_sketch_mat.set_shader_parameter("area_count", mini(live_areas.size(), 8))
		sketch.material = _sketch_mat
		add_child(sketch)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_frame)
	add_child(_art)


func _process(_delta: float) -> void:
	if _sketch_mat == null:
		return
	# screen px -> world, for the pencil mask
	var xf := get_viewport().get_canvas_transform().affine_inverse()
	_sketch_mat.set_shader_parameter("xf_x", xf.x)
	_sketch_mat.set_shader_parameter("xf_y", xf.y)
	_sketch_mat.set_shader_parameter("xf_o", xf.origin)
	_sketch_mat.set_shader_parameter("base_size", get_viewport().get_visible_rect().size)


## The page round a panel `r` (also used by panel_turn.gd).
static func draw_page_margin(c: CanvasItem, r: Rect2, outer: Rect2) -> void:
	c.draw_rect(Rect2(outer.position, Vector2(outer.size.x, r.position.y - outer.position.y)), PAPER)
	c.draw_rect(Rect2(outer.position.x, r.end.y, outer.size.x, outer.end.y - r.end.y), PAPER)
	c.draw_rect(Rect2(outer.position.x, r.position.y, r.position.x - outer.position.x, r.size.y), PAPER)
	c.draw_rect(Rect2(r.end.x, r.position.y, outer.end.x - r.end.x, r.size.y), PAPER)


## Thick ink panel border with a little hand-drawn wobble.
static func draw_border(c: CanvasItem, r: Rect2, width := 5.0, seed_i := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + seed_i
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var pts := PackedVector2Array()
		var n := maxi(2, int(a.distance_to(b) / 60.0))
		var side := (b - a).normalized().orthogonal()
		for i in n + 1:
			var t := float(i) / n
			var j := 0.0 if i == 0 or i == n else rng.randf_range(-0.8, 0.8)
			pts.append(a.lerp(b, t) + side * j)
		c.draw_polyline(pts, INK, width, true)
	for p in corners:  # square the corners off
		c.draw_rect(Rect2(p - Vector2(width, width) * 0.5, Vector2(width, width)), INK)


func _draw_frame() -> void:
	var c := _art
	var screen := Rect2(Vector2.ZERO, c.size)
	var r := Rect2(PANEL.position, c.size - PANEL.position * 2.0)
	draw_page_margin(c, r, screen)
	# halftone on the paper margin, fading toward the panel
	var x := 4.0
	while x < screen.end.x:
		var y := 4.0
		while y < screen.end.y:
			if not r.grow(2.0).has_point(Vector2(x, y)):
				c.draw_circle(Vector2(x, y), 0.9, Color(0.86, 0.8, 0.7))
			y += 9.0
		x += 9.0
	# printer's registration marks in the corners
	for p in [Vector2(9, 9), Vector2(screen.end.x - 9, 9), Vector2(9, screen.end.y - 9), screen.end - Vector2(9, 9)]:
		c.draw_arc(p, 4.0, 0, TAU, 12, Color(INK, 0.5), 1.0)
		c.draw_line(p - Vector2(7, 0), p + Vector2(7, 0), Color(INK, 0.5), 1.0)
		c.draw_line(p - Vector2(0, 7), p + Vector2(0, 7), Color(INK, 0.5), 1.0)
	# a soft drop shadow of the panel onto the page, then the ink border
	c.draw_rect(Rect2(r.end.x, r.position.y + 6, 4, r.size.y), Color(INK, 0.18))
	c.draw_rect(Rect2(r.position.x + 6, r.end.y, r.size.x, 4), Color(INK, 0.18))
	draw_border(c, r, 5.0)
	var font := preload("res://assets/fonts/Bangers-Regular.ttf")
	var label := "PAGE %d" % page_number
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	c.draw_string(font, Vector2(screen.end.x * 0.5 - w * 0.5, screen.end.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(INK, 0.6))
