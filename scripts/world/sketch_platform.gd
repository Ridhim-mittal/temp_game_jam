@tool
extends StaticBody2D
## A pencil sketch of a platform (light rule 1), split into narrow cells along
## its width. A cell is solid while any light reaches any part of it (the
## raised Ember, a lit lantern that isn't shadowed, an ink wave flying past).
## When the light leaves, the cell fades out over `warn_time` and then you
## fall through it, so the edge of your light reads as a soft glow, not a cliff.
## Stand still with the Ember raised and ink spreads out from your feet along
## the sketch: inked cells are solid for good and are safe ground (hazard
## respawns return you there). Sketches in non-photo blue (`inkable = false`)
## never take ink: keep them lit all the way across.
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
## Width of one cell (the piece that turns solid or not).
@export var cell := 24.0
## false = non-photo blue pencil: can be lit but never inked.
@export var inkable := true:
	set(value):
		inkable = value
		queue_redraw()
## Seconds a cell keeps holding (fading) after its light leaves.
@export var warn_time := 0.45
## Starts fully inked (a solid stepping stone drawn by the Writer).
@export var start_inked := false

var _n := 1
var _shapes: Array[CollisionShape2D] = []
var _solid: Array[bool] = []
var _lit: Array[bool] = []
var _hold: Array[float] = []   # fade-out time left after the light leaves
var _glow: Array[float] = []   # 0..1 eased brightness, for smooth edges
var _inked: Array[bool] = []
var _ink_age: Array[float] = []  # seconds since inked (splash animation)
var _time := 0.0
var _pop_cd := 0.0
var _was_inking := false


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
		rect.size = Vector2(w + 0.5, size.y)  # a hair of overlap: no seams to snag on
		cs.shape = rect
		cs.position = Vector2(-size.x * 0.5 + w * (i + 0.5), 0)
		cs.one_way_collision = true
		cs.disabled = not start_inked
		add_child(cs)
		_shapes.append(cs)
		_solid.append(start_inked)
		_lit.append(start_inked)
		_hold.append(0.0)
		_glow.append(1.0 if start_inked else 0.0)
		_inked.append(start_inked)
		_ink_age.append(10.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_pop_cd = maxf(_pop_cd - delta, 0.0)
	if not OnScreen.near(self, size.x * 0.5 + 260.0):
		return
	var tree := get_tree()
	var w := size.x / _n
	var top := -size.y * 0.5
	var newly := 0
	var any_ink := false
	for i in _n:
		var x0 := -size.x * 0.5 + w * i
		_ink_age[i] += delta
		var lit := _inked[i]
		if not lit:
			# lit if the light reaches either end or the middle of the cell
			for fx in [0.5, 0.0, 1.0]:
				if Lights.reaches(tree, to_global(Vector2(x0 + w * fx, top))):
					lit = true
					break
		_lit[i] = lit
		if inkable and not _inked[i]:
			if Lights.inks(tree, to_global(Vector2(x0 + w * 0.5, top))):
				_inked[i] = true
				_ink_age[i] = 0.0
				newly += 1
				lit = true
		if _inked[i] and _ink_age[i] < 0.5:
			any_ink = true
		if lit:
			_hold[i] = warn_time
			if not _solid[i]:
				_set_solid(i, true)
		elif _solid[i]:
			_hold[i] -= delta
			if _hold[i] <= 0.0:
				_set_solid(i, false)
		var target := 1.0 if lit else (clampf(_hold[i] / warn_time, 0.0, 1.0) * 0.8 if _solid[i] else 0.0)
		_glow[i] = move_toward(_glow[i], target, delta * 6.0)
	# one "INKED!" per stroke, not per cell
	if newly > 0 and not _was_inking and _pop_cd <= 0.0:
		_pop_cd = 1.0
		var p: Vector2 = tree.get_first_node_in_group("player").global_position if tree.get_first_node_in_group("player") else global_position
		_pop(Vector2(p.x, global_position.y), "INKED!")
	_was_inking = newly > 0 or (any_ink and _was_inking)
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
	p.font_size = 22
	p.position = at + Vector2(0, -60)
	get_tree().current_scene.add_child(p)


# ------------------------------------------------------------------ drawing

func _jit(i: int, k: int, amount: float) -> float:
	var boil := int(_time * 6.0)
	return (float(absi(hash(Vector3i(i, k, boil))) % 1000) / 1000.0 - 0.5) * amount


func _draw() -> void:
	var n := maxi(1, int(round(size.x / cell)))
	var w := size.x / n
	var r := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
	var pencil := PENCIL if inkable else BLUE
	# the pencil sketch underneath everything, always there to plan by
	_draw_pencil(r, pencil)
	if Engine.is_editor_hint() or _glow.is_empty():
		if start_inked:
			_draw_inked(r)
		return
	# lit cells: a warm glow whose brightness eases cell to cell (soft edges)
	var lit_fill := LIT_FILL if inkable else LIT_FILL.lerp(Color(0.75, 0.88, 1.0), 0.5)
	for i in n:
		var g: float = _glow[i]
		if g <= 0.02 or _inked[i]:
			continue
		var c := Rect2(r.position.x + w * i, r.position.y, w + 0.5, r.size.y)
		var fading := not _lit[i]
		var a := g if not fading else g * (0.6 + 0.4 * sin(_time * 30.0 + i))  # a nervous shimmer, not a strobe
		draw_rect(c.grow_individual(0, 4, 0, 4), Color(1.0, 0.8, 0.35, 0.25 * a))  # halo
		draw_rect(c, Color(lit_fill, a))
		draw_rect(Rect2(c.position, Vector2(c.size.x, 4)), Color(1, 1, 1, 0.5 * a))
		# ink outline only along the top and bottom (neighbours join up)
		draw_line(c.position, Vector2(c.end.x, c.position.y), Color(INK, a), 2.5)
		draw_line(Vector2(c.position.x, c.end.y), c.end, Color(INK, a), 2.5)
		# caps at the ends of a lit run
		if i == 0 or _glow[i - 1] <= 0.02 or _inked[i - 1]:
			draw_line(c.position, Vector2(c.position.x, c.end.y), Color(INK, a), 2.5)
		if i == n - 1 or _glow[i + 1] <= 0.02 or _inked[i + 1]:
			draw_line(Vector2(c.end.x, c.position.y), c.end, Color(INK, a), 2.5)
	# inked runs: bold pen and hatching, splashing in as the ink arrives
	var i := 0
	while i < n:
		if not _inked[i]:
			i += 1
			continue
		var j := i
		while j + 1 < n and _inked[j + 1]:
			j += 1
		_draw_inked(Rect2(r.position.x + w * i, r.position.y, w * (j - i + 1), r.size.y))
		i = j + 1
	for k in n:
		var age: float = _ink_age[k]
		if _inked[k] and age < 0.5:
			var cx := r.position.x + w * (k + 0.5)
			var t := age / 0.5
			draw_circle(Vector2(cx, 0), (size.y * 0.9) * (1.0 - t), Color(INK, 1.0 - t))  # wet blot drying in
			draw_circle(Vector2(cx + _jit(k, 1, 18.0), -size.y * 0.5 - 6.0 * t), 2.5 * (1.0 - t), Color(INK, 1.0 - t))


func _draw_inked(r: Rect2) -> void:
	draw_rect(r.grow(3.5), INK)
	draw_rect(r, INKED_FILL)
	var x := r.position.x + 6.0
	while x < r.end.x - 2.0:  # bold pen cross-hatching: it's inked now
		draw_line(Vector2(x, r.end.y), Vector2(x - 8, r.position.y + 5), Color(INK, 0.75), 1.5)
		draw_line(Vector2(x - 8, r.end.y), Vector2(x, r.position.y + 5), Color(INK, 0.4), 1.0)
		x += 8.0
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), INKED_FILL)


## Wobbly double pencil line, overshooting the corners, with light hatching.
func _draw_pencil(r: Rect2, col: Color) -> void:
	var o := 6.0
	for k in 2:
		var y := r.position.y if k == 0 else r.end.y
		draw_line(Vector2(r.position.x - o + _jit(0, k, 6.0), y + _jit(0, k + 4, 3.0)),
			Vector2(r.end.x + o + _jit(1, k + 8, 6.0), y + _jit(1, k + 12, 3.0)), col, 1.6)
	draw_line(Vector2(r.position.x + _jit(0, 20, 3.0), r.position.y - 3), Vector2(r.position.x + _jit(0, 21, 3.0), r.end.y + 3), col, 1.4)
	draw_line(Vector2(r.end.x + _jit(1, 22, 3.0), r.position.y - 3), Vector2(r.end.x + _jit(1, 23, 3.0), r.end.y + 3), col, 1.4)
	draw_rect(r, Color(col, col.a * 0.08))
	var x := r.position.x + 4.0
	while x < r.end.x - 2.0:
		draw_line(Vector2(x, r.end.y - 2), Vector2(x + 7, r.position.y + 2), Color(col, col.a * 0.45), 1.2)
		x += 9.0
