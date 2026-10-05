extends Control
## Minimap (top right), drawn as a scrap of torn paper pinned to the screen:
## every room visited this run is a hand-inked box with a faint wash of its
## biome's colour, joined by wobbly ink lines where the player walked
## through a gate. Cleared rooms are hatched in; the current room carries an
## ink blot and a ring that breathes.

const INK := Color(0.08, 0.07, 0.09)
const PAPER := Color(0.66, 0.63, 0.56)
const PAPER_DARK := Color(0.5, 0.47, 0.41)
const CELL := Vector2(24, 17)
const GAP := 9.0
const SCRAP := Vector2(196, 86)

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Deterministic 0..1 noise, so the torn edge and the ink wobble hold still.
static func _rand(k: float) -> float:
	return fposmod(sin(k * 12.9898 + 4.1414) * 43758.5453, 1.0)


func _draw() -> void:
	var world := get_node_or_null("/root/World25")
	if world == null or world.visited.is_empty():
		return
	var cur: Dictionary = world.visited.get(world.current_room, {})
	if cur.is_empty():
		return
	var origin := Vector2(size.x - 124.0, 50.0)
	# the scrap sits a little crooked
	draw_set_transform(origin, -0.035, Vector2.ONE)
	var torn := _torn_rect(Rect2(-SCRAP * 0.5, SCRAP))
	draw_set_transform(origin + Vector2(4, 5), -0.035, Vector2.ONE)
	draw_colored_polygon(torn, Color(0, 0, 0, 0.4))  # shadow
	draw_set_transform(origin, -0.035, Vector2.ONE)
	draw_colored_polygon(torn, PAPER)
	draw_polyline(torn + PackedVector2Array([torn[0]]), PAPER_DARK, 1.5)
	# faint ruled lines: it was torn out of a notebook
	for i in 4:
		var y := -SCRAP.y * 0.5 + 18.0 + i * 17.0
		draw_line(Vector2(-SCRAP.x * 0.5 + 6, y), Vector2(SCRAP.x * 0.5 - 6, y), Color(0.35, 0.42, 0.5, 0.18), 1.0)
	var step := CELL + Vector2(GAP, GAP)
	var centre: Vector2i = cur.cell
	var area := Rect2(-SCRAP * 0.5, SCRAP).grow(-8.0)
	var to_map := func(cell: Vector2i) -> Vector2:
		return Vector2(cell - centre) * step
	for l in world.links:
		var a: Vector2 = to_map.call(l[0])
		var b: Vector2 = to_map.call(l[1])
		if area.has_point(a) or area.has_point(b):
			_ink_line(_clip(a, area), _clip(b, area), 2.2, a.x + b.y)
	for id in world.visited:
		var r: Dictionary = world.visited[id]
		var c: Vector2 = to_map.call(r.cell)
		if not area.grow(-6.0).has_point(c):
			continue
		var rect := Rect2(c - CELL * 0.5, CELL)
		draw_rect(rect, Color(r.color.lerp(PAPER, 0.35), 0.55))  # wash
		var seed := float(id.hash() % 997)
		_ink_box(rect, seed)
		if world.is_cleared(id) and id != world.current_room:
			for k in 3:
				var x := rect.position.x + 5.0 + k * 7.0
				draw_line(Vector2(x, rect.end.y - 3.0), Vector2(x + 6.0, rect.position.y + 3.0), Color(INK, 0.55), 1.5)
		if id == world.current_room:
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			_ink_ring(c, CELL.x * 0.62 + pulse * 2.5, seed)
			draw_circle(c, 3.6, INK)
			draw_circle(c + Vector2(2.6, 1.8), 1.6, INK)  # the blot spatters
	draw_set_transform(Vector2.ZERO)


## A rectangle with every edge torn: small jagged steps all the way round.
func _torn_rect(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var n := int(a.distance_to(b) / 7.0)
		var out := (b - a).normalized().orthogonal() * -1.0
		for i in n:
			var t := float(i) / n
			var k := side * 31.0 + i
			pts.append(a.lerp(b, t) + out * (_rand(k) - 0.5) * 5.0)
	return pts


## A hand-drawn line: slightly bowed, with a thicker blot at each end.
func _ink_line(a: Vector2, b: Vector2, width: float, seed: float) -> void:
	var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * (_rand(seed) - 0.5) * 3.0
	draw_polyline(PackedVector2Array([a, mid, b]), INK, width)
	draw_circle(a, width * 0.6, INK)
	draw_circle(b, width * 0.6, INK)


func _ink_box(r: Rect2, seed: float) -> void:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = c[i] + Vector2(_rand(seed + i) - 0.5, _rand(seed + i + 7.0) - 0.5) * 2.0
		var b: Vector2 = c[(i + 1) % 4] + Vector2(_rand(seed + i + 1.0) - 0.5, _rand(seed + i + 8.0) - 0.5) * 2.0
		# overshoot the corners a touch, as a pen does
		var d := (b - a).normalized() * 1.5
		draw_line(a - d, b + d, INK, 1.8)


func _ink_ring(c: Vector2, radius: float, seed: float) -> void:
	var pts := PackedVector2Array()
	for i in 19:
		var a := TAU * i / 18.0 + 0.3
		pts.append(c + Vector2(cos(a), sin(a) * 0.8) * (radius + (_rand(seed + i) - 0.5) * 1.6))
	draw_polyline(pts, Color(INK, 0.85), 1.6)


func _clip(p: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
