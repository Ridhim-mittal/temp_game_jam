extends Control
## Cult of the Lamb style minimap (top right): every room visited this run
## as a tile in its biome's colour, joined where the player walked through
## a gate. The current room pulses.

const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)
const CELL := Vector2(26, 18)
const GAP := 8.0

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var world := get_node_or_null("/root/World25")
	if world == null or world.visited.is_empty():
		return
	var cur: Dictionary = world.visited.get(world.current_room, {})
	if cur.is_empty():
		return
	var origin := Vector2(size.x - 120.0, 46.0)
	var step := CELL + Vector2(GAP, GAP)
	var centre: Vector2i = cur.cell
	var to_screen := func(cell: Vector2i) -> Vector2:
		return origin + Vector2(cell - centre) * step
	# backing plate
	var plate := Rect2(origin - Vector2(98, 40), Vector2(196, 80))
	draw_rect(plate, Color(INK, 0.55))
	for l in world.links:
		draw_line(to_screen.call(l[0]), to_screen.call(l[1]), PAPER, 3.0)
	for id in world.visited:
		var r: Dictionary = world.visited[id]
		var c: Vector2 = to_screen.call(r.cell)
		if not plate.grow(-4).has_point(c):
			continue
		var rect := Rect2(c - CELL * 0.5, CELL)
		draw_rect(rect.grow(2.0), INK)
		draw_rect(rect, r.color)
		if id == world.current_room:
			var pulse := 0.5 + 0.5 * sin(_time * 5.0)
			draw_rect(rect.grow(3.0 + pulse), PAPER, false, 2.0)
			draw_circle(c, 3.0, PAPER)
		elif world.is_cleared(id):
			draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), Color(INK, 0.6), 2.0)
			draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), Color(INK, 0.6), 2.0)
