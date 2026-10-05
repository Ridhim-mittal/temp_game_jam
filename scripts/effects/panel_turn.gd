extends Control
## "Move to the next panel": the comic page transition between 2D levels.
##  1. the frozen frame shrinks into a panel on a printed comic page,
##  2. the view pans across the gutter to the next panel, still a pencil
##     sketch with the next level's name, while a tiny Vesper hops across,
##  3. the new level loads; the next panel inks itself in from left to right
##     (it is a window onto the live new level) and the view zooms into it.
## Lives on the root (not the level), so it survives the scene change.
##
##   PanelTurn.start(self, "res://scenes/levels/sketchbook.tscn", "THE SKETCHBOOK")

const ComicFrame = preload("res://scripts/ui/comic_frame.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.96, 0.93, 0.86)
const PENCIL := Color(0.55, 0.53, 0.5)
const CAPTION := Color(1.0, 0.9, 0.45)
const S := Vector2(640, 360)
## The two panels on the page (page space = screen space before zooming).
## Same shape as the in-game panel (comic_frame.gd), so the zoom ends exactly on it.
const P1 := Rect2(150, 190, 460, 255.4)
const P2 := Rect2(670, 190, 460, 255.4)
const T_SHRINK := 0.55
const T_PAN := 1.25
const T_INK := 0.35
const T_ZOOM := 0.65

var target := ""
var title := ""
var _shot: Texture2D
var _shot_src := Rect2()
var _t := 0.0
var _stage := 0  # 0 old level, 1 loading, 2 new level
var _t2 := 0.0
var _wait := 0
var _end_w := 1232.0  # panel width the zoom ends on (full screen if the level has no comic frame)


static func start(from: Node, scene: String, next_title := "") -> void:
	var tree := from.get_tree()
	var fx: Control = load("res://scripts/effects/panel_turn.gd").new()
	fx.target = scene
	fx.title = next_title
	var img := from.get_viewport().get_texture().get_image()
	fx._shot = ImageTexture.create_from_image(img)
	# only the panel's inside: the snapshot's own page margin is redrawn here
	var sz := Vector2(img.get_size())
	fx._shot_src = Rect2(ComicFrame.PANEL.position, sz - ComicFrame.PANEL.position * 2.0)
	var layer := CanvasLayer.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fx)
	tree.root.add_child(layer)
	tree.paused = true


func _process(delta: float) -> void:
	match _stage:
		0:
			_t += delta
			if _t >= T_PAN:
				_stage = 1
				Engine.time_scale = 1.0
				get_tree().change_scene_to_file(target)
		1:
			# give the new level two frames to build and draw behind us
			_wait += 1
			var scene := get_tree().current_scene
			if _wait > 2 and scene and scene.scene_file_path == target:
				_stage = 2
				_end_w = ComicFrame.PANEL.size.x if scene.find_child("ComicFrame", false, false) else size.x
		2:
			_t2 += delta
			if _t2 >= T_INK + T_ZOOM:
				get_tree().paused = false
				get_parent().queue_free()
	queue_redraw()


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	var shrink := _ease(_t / T_SHRINK)
	var pan := _ease((_t - T_SHRINK) / (T_PAN - T_SHRINK))
	var ink := _ease(_t2 / T_INK) if _stage == 2 else 0.0
	var zk := _ease((_t2 - T_INK) / T_ZOOM) if _stage == 2 else 0.0
	# view: centre on the old panel, pan to the new one, then zoom into it
	var focus := S.lerp(P2.get_center(), pan)
	var zoom := lerpf(1.0, _end_w / P2.size.x, zk)
	draw_set_transform(S - focus * zoom, 0.0, Vector2(zoom, zoom))
	# the panel the old frame shrinks into
	var full := Rect2(_shot_src.position, _shot_src.size)
	var p1 := Rect2(full.position.lerp(P1.position, shrink), full.size.lerp(P1.size, shrink))
	# the next panel's window: opens (inks in) from the left once the new level is up
	var hole := Rect2(P2.position, Vector2(P2.size.x * ink, P2.size.y))
	# page paper everywhere except the open part of the next panel
	var outer := Rect2(-3000, -3000, 7000, 7000)
	if hole.size.x > 0.5:
		ComicFrame.draw_page_margin(self, hole, outer)
	else:
		draw_rect(outer, PAPER)
	_draw_halftone(hole)
	_draw_neighbours(shrink)
	# the old frame inside its panel
	draw_texture_rect_region(_shot, p1, _shot_src)
	ComicFrame.draw_border(self, p1, lerpf(5.0, 6.0, shrink), 1)
	# the next panel: pencil sketch of the level to come, until the ink arrives
	var rest := Rect2(hole.end.x, P2.position.y, P2.end.x - hole.end.x, P2.size.y)
	if rest.size.x > 0.5:
		draw_rect(rest, Color(0.99, 0.97, 0.92))
		if hole.size.x < 0.5:
			_draw_sketch()
		if ink > 0.0 and ink < 1.0:  # the nib laying the ink down
			var nib := Vector2(hole.end.x, P2.position.y + P2.size.y * (0.5 + 0.4 * sin(_t2 * 40.0)))
			draw_line(Vector2(hole.end.x, P2.position.y), Vector2(hole.end.x, P2.end.y), INK, 4.0)
			draw_circle(nib, 6.0, INK)
			draw_circle(nib, 2.5, Color(1.0, 0.85, 0.4))
	ComicFrame.draw_border(self, P2, 6.0, 2)
	# narrator caption over the gutter
	if shrink > 0.6 and _stage < 2:
		var a := clampf((shrink - 0.6) / 0.4, 0.0, 1.0)
		var text := "MEANWHILE, ONE PANEL LATER..."
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var box := Rect2(P2.position + Vector2(-8, -54), Vector2(w + 24, 36))
		draw_rect(Rect2(box.position + Vector2(4, 4), box.size), Color(INK, 0.35 * a))
		draw_rect(box.grow(3.0), Color(INK, a))
		draw_rect(box, Color(CAPTION, a))
		draw_string(FONT, box.position + Vector2(12, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, a))
	# tiny Vesper hopping across the gutter
	if pan > 0.0 and _stage < 2:
		var from := P1.get_center() + Vector2(120, 70)
		var to := P2.get_center() + Vector2(-120, 70)
		var p := from.lerp(to, pan) + Vector2(0, -sin(pan * PI) * 120.0)
		_draw_vesper(S - focus + p, pan)
	draw_set_transform(Vector2.ZERO)


func _draw_halftone(hole: Rect2) -> void:
	# a few rows of halftone on the page, in page space round the panels
	var y := 120.0
	while y < 520.0:
		var x := 100.0
		while x < 1180.0:
			var p := Vector2(x, y)
			if not P1.grow(4).has_point(p) and not P2.grow(4).has_point(p):
				draw_circle(p, 1.3, Color(0.84, 0.78, 0.68))
			x += 9.0
		y += 9.0


func _draw_neighbours(a: float) -> void:
	# the rest of the page: panels above and below, sketched and hatched
	var rows := [Rect2(150, -120, 300, 280), Rect2(480, -120, 650, 280), Rect2(150, 476, 600, 290), Rect2(780, 476, 350, 290),
		Rect2(-340, 190, 460, 256), Rect2(1160, 190, 460, 256)]
	for r: Rect2 in rows:
		draw_rect(r, Color(0.9, 0.87, 0.8, a))
		var x := r.position.x + 12.0
		while x < r.end.x - 12.0:
			draw_line(Vector2(x, r.position.y + 14), Vector2(x - 30, r.position.y + 44), Color(PENCIL, 0.35 * a), 1.0)
			x += 16.0
		if a > 0.01:
			ComicFrame.draw_border(self, r, 5.0, int(r.position.x))


func _draw_sketch() -> void:
	# pencil roughs of the next panel: a horizon, construction lines, its name
	var p := P2
	draw_line(Vector2(p.position.x + 20, p.position.y + p.size.y * 0.72), Vector2(p.end.x - 20, p.position.y + p.size.y * 0.7), Color(PENCIL, 0.7), 1.5)
	for k in 5:
		var x := p.position.x + 40 + k * 90.0
		draw_line(Vector2(x, p.position.y + p.size.y * 0.72), Vector2(x + 20, p.position.y + 40 + k * 7.0), Color(PENCIL, 0.4), 1.0)
	if title != "":
		var w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(FONT, Vector2(p.get_center().x - w * 0.5, p.position.y + 110), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(PENCIL, 0.8))


func _draw_vesper(p: Vector2, k: float) -> void:
	draw_set_transform(p, sin(k * TAU) * 0.3, Vector2.ONE)  # p is in screen space
	var cloak := PackedVector2Array([Vector2(-12, -6), Vector2(12, -6), Vector2(16, 22), Vector2(-16, 22)])
	draw_colored_polygon(cloak, INK)
	draw_line(Vector2(-6, -6), Vector2(-24, -14 + sin(_t * 14.0) * 5.0), Color(0.92, 0.3, 0.2), 4.0)  # scarf
	draw_circle(Vector2(0, -16), 11.0, Color(0.98, 0.96, 0.9))
	draw_circle(Vector2(4, -17), 2.5, INK)
	draw_rect(Rect2(-16, -30, 32, 5), INK)  # hat brim
	draw_rect(Rect2(-9, -39, 18, 10), INK)
	# speed lines behind her
	for i in 3:
		draw_line(Vector2(-22, -8 + i * 10), Vector2(-46 - i * 6, -8 + i * 10), Color(INK, 0.5), 2.0)
