@tool
extends StaticBody2D
## A pencil sketch of a platform (light rule 1). Split into cells along its
## width; each cell is solid only while some light reaches it: Vesper's
## raised Ember, a lit lantern (whose light walls and cut-outs can shadow),
## an ink wave flying past. A cell that loses its light flickers for
## `warn_time`, then you fall through it.
## Stand still with the Ember raised and the cells near you INK in: solid
## for good, and safe ground (hazard respawns return you there). Sketches
## drawn in non-photo blue (`inkable = false`) never take ink; you have to
## keep them lit all the way across.
## One-way like a plank: jump up through it, land on top.

const Lights = preload("res://scripts/world/lights.gd")
const OnScreen = preload("res://scripts/core/on_screen.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const INK := Color(0.05, 0.03, 0.1)
const PENCIL := Color(0.92, 0.9, 0.84, 0.85)  # light lead: reads on the dark pits
const BLUE := Color(0.45, 0.78, 1.0, 0.9)
const LIT_FILL := Color(1.0, 0.86, 0.45)
const INKED_FILL := Color(0.98, 0.96, 0.9)

@export var size := Vector2(400, 20):
	set(value):
		size = value
		queue_redraw()
## Width of one cell (one piece that turns solid or not).
@export var cell := 40.0
## false = non-photo blue pencil: can be lit but never inked.
@export var inkable := true:
	set(value):
		inkable = value
		queue_redraw()
## Seconds of standing still in your raised Ember to ink a cell.
@export var ink_time := 1.0
## Seconds a cell flickers after losing light before it vanishes.
@export var warn_time := 0.3
## Starts fully inked (a solid stepping stone drawn by the Writer).
@export var start_inked := false

var _n := 1
var _shapes: Array[CollisionShape2D] = []
var _solid: Array[bool] = []
var _lit: Array[bool] = []
var _warn: Array[float] = []
var _ink: Array[float] = []
var _inked: Array[bool] = []
var _time := 0.0
var _pop_cd := 0.0


func _ready() -> void:
	_n = maxi(1, int(round(size.x / cell)))
	if Engine.is_editor_hint():
		return
	collision_layer = Lights.LAYER_SKETCH
	collision_mask = 0
	var w := size.x / _n
	for i in _n:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, size.y)
		cs.shape = rect
		cs.position = Vector2(-size.x * 0.5 + w * (i + 0.5), 0)
		cs.one_way_collision = true
		cs.disabled = not start_inked
		add_child(cs)
		_shapes.append(cs)
		_solid.append(start_inked)
		_lit.append(false)
		_warn.append(0.0)
		_ink.append(1.0 if start_inked else 0.0)
		_inked.append(start_inked)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_pop_cd = maxf(_pop_cd - delta, 0.0)
	if not OnScreen.near(self, size.x * 0.5 + 260.0):
		return
	var tree := get_tree()
	var w := size.x / _n
	for i in _n:
		var p := to_global(Vector2(-size.x * 0.5 + w * (i + 0.5), 0))
		var lit := _inked[i] or Lights.reaches(tree, p)
		_lit[i] = lit
		if inkable and not _inked[i]:
			if Lights.inks(tree, p):
				_ink[i] += delta / ink_time
				if _ink[i] >= 1.0:
					_ink[i] = 1.0
					_inked[i] = true
					if _pop_cd <= 0.0:
						_pop_cd = 0.5
						_pop(p, ["SCRITCH!", "INKED!", "SKRITCH!"].pick_random())
			else:
				_ink[i] = maxf(_ink[i] - delta * 0.4, 0.0)
		if lit:
			_warn[i] = warn_time
			if not _solid[i]:
				_set_solid(i, true)
		elif _solid[i]:
			_warn[i] -= delta
			if _warn[i] <= 0.0:
				_set_solid(i, false)
	queue_redraw()


func _set_solid(i: int, on: bool) -> void:
	_solid[i] = on
	_shapes[i].set_deferred("disabled", not on)


## Safe ground for hazard respawns: only inked cells (light can go away).
func is_stable_at(point: Vector2) -> bool:
	var i := _cell_at(point)
	return i >= 0 and _inked[i]


func is_solid_at(point: Vector2) -> bool:
	var i := _cell_at(point)
	return i >= 0 and _solid[i]


func inked_count() -> int:
	return _inked.count(true)


func _cell_at(point: Vector2) -> int:
	if _inked.is_empty():
		return -1
	var x := to_local(point).x + size.x * 0.5
	return clampi(int(x / (size.x / _n)), 0, _n - 1)


func _pop(at: Vector2, text: String) -> void:
	var p := ComicText.new()
	p.text = text
	p.color = INKED_FILL
	p.font_size = 20
	p.position = at + Vector2(0, -36)
	get_tree().current_scene.add_child(p)


# ------------------------------------------------------------------ drawing

func _jit(i: int, k: int, amount: float) -> float:
	var boil := int(_time * 6.0)
	return (float(absi(hash(Vector3i(i, k, boil))) % 1000) / 1000.0 - 0.5) * amount


## 0 ghost, 1 lit (solid), 2 inked; a flickering cell alternates 0/1.
func _state(i: int) -> int:
	if Engine.is_editor_hint() or _inked.is_empty():
		return 2 if start_inked else 0
	if _inked[i]:
		return 2
	if _solid[i]:
		if not _lit[i] and fmod(_time, 0.12) < 0.06:
			return 0
		return 1
	return 0


func _draw() -> void:
	var n := maxi(1, int(round(size.x / cell)))
	var w := size.x / n
	var top := -size.y * 0.5
	var h := size.y
	var pencil := PENCIL if inkable else BLUE
	# merge neighbouring cells in the same state into one run
	var i := 0
	while i < n:
		var st := _state(i)
		var j := i
		while j + 1 < n and _state(j + 1) == st:
			j += 1
		var r := Rect2(-size.x * 0.5 + w * i, top, w * (j - i + 1), h)
		match st:
			0:
				_draw_pencil(r, i, j, pencil)
			1:
				draw_rect(r.grow(5.0), Color(1.0, 0.8, 0.35, 0.3))  # glow halo
				draw_rect(r.grow(2.5), INK)
				draw_rect(r, LIT_FILL if inkable else LIT_FILL.lerp(Color(0.75, 0.88, 1.0), 0.5))
				draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(1, 1, 1, 0.55))
				_draw_pencil(r, i, j, Color(pencil, 0.35))
			2:
				draw_rect(r.grow(4.0), INK)
				draw_rect(r, INKED_FILL)
				var x := r.position.x + 6.0
				while x < r.end.x - 2.0:  # bold pen cross-hatching: it's inked now
					draw_line(Vector2(x, r.end.y), Vector2(x - 8, r.position.y + 5), Color(INK, 0.75), 1.5)
					draw_line(Vector2(x - 8, r.end.y), Vector2(x, r.position.y + 5), Color(INK, 0.4), 1.0)
					x += 8.0
				draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), INKED_FILL)
		i = j + 1
	# ink filling in (bottom up) where the Ember is inking
	if not _ink.is_empty():
		for k in n:
			if not _inked[k] and _ink[k] > 0.01:
				var ih := h * _ink[k]
				var r := Rect2(-size.x * 0.5 + w * k, top + h - ih, w, ih)
				draw_rect(r, Color(INK, 0.85))
				var nib := Vector2(r.position.x + w * (0.5 + 0.4 * sin(_time * 25.0 + k)), r.position.y)
				draw_circle(nib, 3.0, Color(1.0, 0.95, 0.8))


## Wobbly double pencil line, overshooting the corners, with light hatching.
func _draw_pencil(r: Rect2, i: int, j: int, col: Color) -> void:
	var o := 6.0
	for k in 2:
		var y := r.position.y if k == 0 else r.end.y
		draw_line(Vector2(r.position.x - o + _jit(i, k, 6.0), y + _jit(i, k + 4, 3.0)),
			Vector2(r.end.x + o + _jit(j, k + 8, 6.0), y + _jit(j, k + 12, 3.0)), col, 1.6)
	draw_line(Vector2(r.position.x + _jit(i, 20, 3.0), r.position.y - 3), Vector2(r.position.x + _jit(i, 21, 3.0), r.end.y + 3), col, 1.4)
	draw_line(Vector2(r.end.x + _jit(j, 22, 3.0), r.position.y - 3), Vector2(r.end.x + _jit(j, 23, 3.0), r.end.y + 3), col, 1.4)
	draw_rect(r, Color(col, col.a * 0.08))
	var x := r.position.x + 4.0
	while x < r.end.x - 2.0:
		draw_line(Vector2(x, r.end.y - 2), Vector2(x + 7, r.position.y + 2), Color(col, col.a * 0.45), 1.2)
		x += 9.0
