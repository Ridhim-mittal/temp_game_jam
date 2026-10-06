extends Node2D
## Backdrop of the Ink Cave (Shade's trap): the team's painting
## (assets/backgrounds/ink_cave.webp) fixed on screen like city_painting.gd,
## brought to life like a live wallpaper: shaders/ink_cave_live.gdshader makes
## the ink-fire lick and flicker and the ink river ripple, and a screen-space
## layer adds embers drifting up from the fire, ash, and ink dripping from the
## stalactites. `collapse` (0..1, cave_arena.gd) shakes it and rains rocks.

const ParallaxScript = preload("res://scripts/background/comic_parallax.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const PAINTING = preload("res://assets/backgrounds/ink_cave.webp")
const LIVE = preload("res://shaders/ink_cave_live.gdshader")

@export var camera_center := Vector2(640, 348)
## Screen y of the painting's top edge.
@export var top_y := 0.0
@export var fill := Color(0.04, 0.02, 0.06)
@export var embers := 46
@export var drips := 9

const EMBER_COLS := [Color(1.0, 0.25, 0.65), Color(1.0, 0.85, 0.25), Color(0.3, 0.85, 1.0), Color(1.0, 0.5, 0.3)]
const INK := Color(0.02, 0.01, 0.04)

## The cave giving way (0 = calm, 1 = falling apart).
var collapse := 0.0:
	set(value):
		collapse = value
		if _mat:
			_mat.set_shader_parameter("shake", value)

var _mat: ShaderMaterial
var _fx: Node2D
var _time := 0.0
var _embers: Array = []  # {p, v, life, age, col, r}
var _drips: Array = []  # {x, len, t, speed}
var _rocks: Array = []  # {p, v, rot, spin, s}
var _size := Vector2(1280, 720)


func _ready() -> void:
	_size = get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = -100
	var rect := ColorRect.new()
	rect.color = fill
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var p := Parallax2D.new()
	p.set_script(ParallaxScript)
	p.reference_camera_center = camera_center
	p.scroll_scale = Vector2.ZERO
	p.z_index = -10
	var art := Sprite2D.new()
	art.texture = PAINTING
	art.centered = false
	var k := _size.x / PAINTING.get_width()
	art.scale = Vector2(k, k) * 1.02  # a hair over-size so the shake never shows an edge
	art.position = Vector2(-_size.x * 0.01, top_y)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = LIVE
	art.material = _mat
	p.add_child(art)
	_fx = Node2D.new()
	_fx.draw.connect(_paint)
	p.add_child(_fx)
	add_child(p)
	for i in embers:
		_embers.append(_new_ember(true))
	for i in drips:
		_drips.append({"x": randf_range(0.05, 0.95) * _size.x, "len": randf_range(30.0, 110.0),
			"t": randf() * 4.0, "speed": randf_range(0.5, 1.0)})


func _new_ember(anywhere := false) -> Dictionary:
	# most rise out of the fire in the middle of the painting
	var x := _size.x * (0.5 + randf_range(-0.28, 0.28) * randf_range(0.4, 1.0))
	var y := _size.y * randf_range(0.55, 0.78)
	var life := randf_range(2.5, 5.5)
	return {"p": Vector2(x, y), "v": Vector2(randf_range(-14, 14), -randf_range(30, 90)),
		"life": life, "age": randf() * life if anywhere else 0.0,
		"col": EMBER_COLS[randi() % EMBER_COLS.size()], "r": randf_range(1.2, 3.2), "seed": randf() * 10.0}


func _process(delta: float) -> void:
	_time += delta
	for e in _embers:
		e.age += delta
		e.v.x += sin(_time * 1.7 + e.seed) * 30.0 * delta
		e.p += e.v * delta
		if e.age >= e.life:
			e.merge(_new_ember(), true)
	for d in _drips:
		d.t += delta * d.speed
	if collapse > 0.0 and randf() < collapse * 0.5:
		_rocks.append({"p": Vector2(randf() * _size.x, -30.0), "v": Vector2(randf_range(-40, 40), randf_range(100, 300)),
			"rot": randf() * TAU, "spin": randf_range(-4, 4), "s": randf_range(6.0, 22.0)})
	for r in _rocks:
		r.v.y += 900.0 * delta
		r.p += r.v * delta
		r.rot += r.spin * delta
	_rocks = _rocks.filter(func(r): return r.p.y < _size.y + 60.0)
	_fx.queue_redraw()


func _paint() -> void:
	var b := InkBatch.new()
	# ink drips gathering on the stalactites and falling
	for d in _drips:
		var cycle := fmod(d.t, 4.0)
		var top := 0.0
		if cycle < 2.6:
			var grow := cycle / 2.6
			b.draw_colored_polygon(PackedVector2Array([Vector2(d.x - 4, top), Vector2(d.x + 4, top),
				Vector2(d.x + 2, top + d.len * grow), Vector2(d.x - 2, top + d.len * grow)]), INK)
			b.draw_circle(Vector2(d.x, top + d.len * grow), 2.0 + 3.0 * grow, INK)
		else:
			var f := (cycle - 2.6) / 1.4
			var y: float = top + d.len + f * f * _size.y * 1.1
			b.draw_colored_polygon(PackedVector2Array([Vector2(d.x - 3, y - 14), Vector2(d.x + 3, y - 14),
				Vector2(d.x + 5, y), Vector2(d.x, y + 6), Vector2(d.x - 5, y)]), INK)
	# embers: glowing sparks with a soft halo, fading as they cool
	for e in _embers:
		var t: float = e.age / e.life
		var a := minf(t * 5.0, 1.0) * (1.0 - t)
		var flick := 0.7 + 0.3 * sin(_time * 12.0 + e.seed * 7.0)
		var col: Color = e.col
		b.draw_circle(e.p, e.r * 3.0, Color(col, 0.18 * a * flick))
		b.draw_circle(e.p, e.r, Color(col.lightened(0.4), a * flick))
	# the cave coming down: rocks tumbling past
	for r in _rocks:
		var s: float = r.s
		var pts := PackedVector2Array()
		for k in 6:
			var ang: float = r.rot + k * TAU / 6.0
			pts.append(r.p + Vector2(cos(ang), sin(ang)) * s * (0.75 + 0.25 * sin(k * 2.7 + s)))
		b.draw_colored_polygon(pts, Color(0.16, 0.12, 0.2))
		b.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2.0)
	b.flush(_fx)
