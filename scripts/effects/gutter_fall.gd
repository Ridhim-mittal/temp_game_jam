extends Control
## The panel-to-gutter transition (2D comic panels -> the 2.5D gutter).
## Freezes the game, then:
##   1. the frozen frame shrinks into a panel on a printed comic page,
##   2. the page rushes upward: we fall out of the panel, down the page,
##   3. we dive into the gutter (the white strip between panels), which
##      darkens into ink while a tiny Vesper tumbles in the middle,
##   4. hands over to World25, which drops her into the 2.5D clearing.
## Start it with GutterFall.start(any_node, platformer_player).

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const PAPER := Color(0.96, 0.93, 0.86)
const INK := Color(0.05, 0.03, 0.1)
const GUTTER_DARK := Color(0.06, 0.05, 0.09)
const PANEL_FRAC := Rect2(0.2, 0.1, 0.6, 0.52)  # the shrunken panel, as a share of the screen
const GUTTER := 34.0
const T_SHRINK := 0.55
const T_FALL := 1.35
const T_DIVE := 2.15
const T_END := 2.35

var _shot: Texture2D
var _health_frac := 1.0
var _t := 0.0
var _done := false


static func start(from: Node, player: Node) -> void:
	var tree := from.get_tree()
	var fx = load("res://scripts/effects/gutter_fall.gd").new()
	fx._shot = ImageTexture.create_from_image(from.get_viewport().get_texture().get_image())
	if player and "health" in player and "max_health" in player:
		fx._health_frac = clampf(float(player.health) / maxf(float(player.max_health), 1.0), 0.0, 1.0)
	if player:
		player.remove_from_group("player")  # World25.go must not read platformer stats
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fx)
	tree.current_scene.add_child(layer)
	tree.paused = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= T_END and not _done:
		_done = true
		var world := get_node_or_null("/root/World25")
		if world:
			world.fall_in_from_panel(_health_frac)
		else:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/clearing/clearing.tscn")


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var shrink := _ease(_t / T_SHRINK)
	var fall_k := _ease((_t - T_SHRINK) / (T_FALL - T_SHRINK))
	var dive_k := clampf((_t - T_FALL) / (T_DIVE - T_FALL), 0.0, 1.0)
	var zoom := lerpf(1.0, 28.0, dive_k * dive_k * dive_k)

	var panel_end := Rect2(s * PANEL_FRAC.position, s * PANEL_FRAC.size)
	var panel := _lerp_rect(Rect2(Vector2.ZERO, s), panel_end, shrink)
	var gutter_y := panel_end.end.y + GUTTER * 0.5
	var fall := (gutter_y - c.y) * fall_k
	# page space -> screen: zoom about the screen centre, after falling
	draw_set_transform(c - (c + Vector2(0, fall)) * zoom, 0.0, Vector2(zoom, zoom))

	# the page: paper with a halftone screen, sketched neighbour panels
	draw_rect(Rect2(-s.x, -s.y, s.x * 3.0, s.y * 4.0), PAPER)
	var neigh_a := shrink
	for r: Rect2 in _neighbour_panels(panel_end, s):
		draw_rect(r, Color(0.86, 0.84, 0.8, neigh_a))
		var x := r.position.x + 10.0
		while x < r.end.x - 10.0:  # pencil hatching
			draw_line(Vector2(x, r.position.y + 10), Vector2(x - 26, r.position.y + 36), Color(0.6, 0.58, 0.55, 0.35 * neigh_a), 1.0)
			x += 14.0
		draw_rect(r, Color(INK, neigh_a), false, 4.0)
	# the gutter strip under our panel darkens into ink as we dive in
	var gutter_rect := Rect2(-s.x, panel_end.end.y + 3.0, s.x * 3.0, GUTTER - 6.0)
	draw_rect(gutter_rect, PAPER.lerp(GUTTER_DARK, _ease(dive_k * 1.4)))
	# the frozen frame as a panel
	draw_texture_rect(_shot, panel, false)
	draw_rect(panel, INK, false, lerpf(0.0, 6.0, shrink))
	draw_set_transform(Vector2.ZERO)

	# full ink once the gutter fills the screen
	if dive_k > 0.75:
		draw_rect(Rect2(Vector2.ZERO, s), Color(GUTTER_DARK, _ease((dive_k - 0.75) / 0.25)))
	if _t > T_DIVE:
		draw_rect(Rect2(Vector2.ZERO, s), GUTTER_DARK)

	# tiny Vesper tumbling down the middle once we start falling
	if fall_k > 0.0:
		_draw_vesper(c + Vector2(0, -40.0 * (1.0 - fall_k)), lerpf(0.6, 1.4, dive_k), _t * 6.0, minf(fall_k * 3.0, 1.0))

	# narrator caption
	if _t > T_SHRINK * 0.8:
		var a := minf((_t - T_SHRINK * 0.8) / 0.25, 1.0)
		draw_set_transform(Vector2(60, 60), -0.04)
		var text := "MEANWHILE, IN THE GUTTER..."
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_rect(Rect2(-14, -36, w + 28, 50).grow(3.0), Color(INK, a))
		draw_rect(Rect2(-14, -36, w + 28, 50), Color(1.0, 0.9, 0.45, a))
		draw_string(FONT, Vector2(0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(INK, a))
		draw_set_transform(Vector2.ZERO)


func _neighbour_panels(p: Rect2, s: Vector2) -> Array:
	# a comic page grid around our panel: one beside it, a row below, a row above
	var g := GUTTER
	var below := p.end.y + g
	return [
		Rect2(p.end.x + g, p.position.y, s.x - p.end.x - g * 2.0 + s.x, p.size.y),
		Rect2(-s.x, p.position.y, s.x + p.position.x - g, p.size.y),
		Rect2(-s.x, below, s.x + p.position.x + p.size.x * 0.45, s.y * 0.55),
		Rect2(p.position.x + p.size.x * 0.45 + g, below, s.x * 2.0, s.y * 0.55),
		Rect2(-s.x, -s.y, s.x * 3.0, s.y + p.position.y - g),
	]


func _lerp_rect(a: Rect2, b: Rect2, k: float) -> Rect2:
	return Rect2(a.position.lerp(b.position, k), a.size.lerp(b.size, k))


func _draw_vesper(p: Vector2, sc: float, spin: float, a: float) -> void:
	draw_set_transform(p, sin(spin) * 0.6, Vector2(sc, sc))
	var cloak := PackedVector2Array([Vector2(-12, -6), Vector2(12, -6), Vector2(16, 22), Vector2(-16, 22)])
	draw_colored_polygon(cloak, Color(INK, a))
	draw_line(Vector2(-6, -6), Vector2(-22, -18 + sin(spin * 2.0) * 5.0), Color(0.92, 0.3, 0.2, a), 4.0)  # scarf
	draw_circle(Vector2(0, -16), 11.0, Color(0.98, 0.96, 0.9, a))
	draw_circle(Vector2(4, -17), 2.5, Color(INK, a))
	draw_rect(Rect2(-16, -30, 32, 5), Color(INK, a))  # hat brim
	draw_rect(Rect2(-9, -39, 18, 10), Color(INK, a))
	draw_set_transform(Vector2.ZERO)
