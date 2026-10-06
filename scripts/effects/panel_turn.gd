extends Control
## "Move to the next panel": the comic page transition between 2D levels.
##  1. the frozen frame shrinks into a panel on a printed comic page while the
##     view glides across the gutter to the next panel (a pencil rough with
##     the next level's name; tall for a vertical level), a tiny Vesper
##     hopping across. The next level loads in the background meanwhile.
##  2. the new level is built and given a few frames to settle (camera,
##     backdrop) behind the closed page,
##  3. ink floods the next panel (top down in a tall panel, left to right in
##     a wide one), which is a window onto the live new level, scaled to fit,
##     and the panel opens out into the screen.
## The level inside the window is scaled with the root viewport's global
## canvas transform, so the world, its pencil surroundings and its HUD all
## zoom together; this layer cancels that scale for itself.
## Lives on the root (not the level), so it survives the scene change.
##
##   PanelTurn.start(self, "res://scenes/levels/sketchbook.tscn", "THE SKETCHBOOK")
##   PanelTurn.start(self, "res://scenes/levels/long_drop.tscn", "THE LONG DROP", true)

const ScenePrefetch = preload("res://scripts/core/scene_prefetch.gd")
const ComicFrame = preload("res://scripts/ui/comic_frame.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.96, 0.93, 0.86)
const PANEL_PAPER := Color(0.99, 0.97, 0.92)
const PENCIL := Color(0.55, 0.53, 0.5)
const CAPTION := Color(1.0, 0.9, 0.45)
const S := Vector2(640, 360)
## The old panel and the two shapes of next panel (page space = screen space
## before zooming). The wide one is the in-game panel's shape (comic_frame.gd).
const P1 := Rect2(150, 190, 460, 255.4)
const P2_WIDE := Rect2(670, 190, 460, 255.4)
const P2_TALL := Rect2(680, 40, 300, 640)
const T_SHRINK := 0.65
const T_PAN0 := 0.35  # the glide starts while the frame is still shrinking
const T_PAN := 1.35
const T_INK := 0.5
const T_ZOOM0 := 0.38  # the panel starts opening before the ink is quite done
const T_ZOOM := 0.85
const SETTLE_FRAMES := 3

var target := ""
var title := ""
var tall := false
var _p2 := P2_WIDE
var _shot: Texture2D
var _shot_src := Rect2()
var _t := 0.0
var _stage := 0  # 0 old level, 1 building the new one, 2 revealing it
var _t2 := 0.0
var _frames := 0
var _loading := false
var _target_rect := Rect2()  # where the panel ends up on screen
var _comic := false  # the new level has its own comic page round it
var _r0 := Rect2()  # the new level's screen, fitted round the panel at first
var _g0 := Transform2D.IDENTITY  # the root's own global canvas transform (window stretch)
var _page: Node2D  # static page art (cached draw), moved with the view
var _front: Node2D
var _dots: ImageTexture


static func start(from: Node, scene: String, next_title := "", tall_panel := false) -> void:
	Sfx.play("teleport", -4.0, 1.1)
	var tree := from.get_tree()
	var fx: Control = load("res://scripts/effects/panel_turn.gd").new()
	fx.target = scene
	fx.title = next_title
	fx.tall = tall_panel
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
	Engine.time_scale = 1.0  # a hit-stop must not slow the page down


func _ready() -> void:
	_p2 = P2_TALL if tall else P2_WIDE
	ScenePrefetch.start(target)
	_loading = true
	_g0 = get_viewport().global_canvas_transform
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 9:
			var d := Vector2(x - 4, y - 4).length()
			img.set_pixel(x, y, Color(0.84, 0.78, 0.68, clampf(1.6 - d, 0.0, 1.0)))
	_dots = ImageTexture.create_from_image(img)
	_page = Node2D.new()
	_page.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_page.draw.connect(_draw_page)
	add_child(_page)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)


func _exit_tree() -> void:
	get_viewport().global_canvas_transform = _g0


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)  # a long frame (the level building) never skips the animation
	match _stage:
		0:
			_t += delta
			if _t >= T_PAN:
				_t = T_PAN
				var packed := _loaded()
				if packed:
					_stage = 1
					_frames = 0
					Engine.time_scale = 1.0
					get_tree().change_scene_to_packed(packed)
		1:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == target:
				# let it run a few frames behind the page: the camera finds
				# Vesper, the backdrop and the pencil surroundings catch up
				_frames += 1
				get_tree().paused = _frames > SETTLE_FRAMES
				if _frames > SETTLE_FRAMES:
					_begin_reveal(scene)
		2:
			_t2 += delta
			if _t2 >= T_ZOOM0 + T_ZOOM:
				get_tree().paused = false
				get_parent().queue_free()
				return
			_apply_zoom()
	_view_update()
	queue_redraw()
	_front.queue_redraw()


## The next level, once the background load is done (null while it's still loading).
func _loaded() -> PackedScene:
	if not _loading:
		return load(target) as PackedScene
	return ScenePrefetch.ready_scene(target)


func _begin_reveal(scene: Node) -> void:
	_stage = 2
	_t2 = 0.0
	_comic = scene.find_child("ComicFrame", false, false) != null
	_target_rect = Rect2(ComicFrame.PANEL.position, size - ComicFrame.PANEL.position * 2.0) if _comic else Rect2(Vector2.ZERO, size)
	# the level's screen, scaled to cover the panel, Vesper in the middle of it
	var hole := _hole0()
	var k := maxf(hole.size.x / _target_rect.size.x, hole.size.y / _target_rect.size.y)
	var u := Vector2(0.5, 0.5)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		var sp := p.get_viewport().get_canvas_transform() * p.global_position
		u = ((sp - _target_rect.position) / _target_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	var sz := _target_rect.size * k
	var pos := hole.get_center() - u * sz
	pos.x = clampf(pos.x, hole.end.x - sz.x, hole.position.x)
	pos.y = clampf(pos.y, hole.end.y - sz.y, hole.position.y)
	_r0 = Rect2(pos, sz)
	_apply_zoom()


# ------------------------------------------------------------------ timing

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _shrink() -> float:
	return _ease(_t / T_SHRINK)  # starts gently: the frame freezes, then lets go


func _pan() -> float:
	return _smoother((_t - T_PAN0) / (T_PAN - T_PAN0))


func _ink() -> float:
	return _ease(_t2 / T_INK) if _stage == 2 else 0.0


func _open() -> float:
	return _smoother((_t2 - T_ZOOM0) / T_ZOOM) if _stage == 2 else 0.0


## Page space -> screen: centre on the old panel, glide to the new one, zoom in.
func _view() -> Transform2D:
	var focus := S.lerp(_p2.get_center(), _pan())
	var z_end := 3.0 if tall else _target_rect.size.x / _p2.size.x
	var z := lerpf(1.0, z_end, _open())
	return Transform2D(0.0, Vector2(z, z), 0.0, S - focus * z)


## The next panel on screen as the reveal starts, then opening out to the screen.
func _hole0() -> Rect2:
	return Rect2(S - _p2.size * 0.5, _p2.size)


func _hole() -> Rect2:
	var h := _hole0()
	var e := _open()
	return Rect2(h.position.lerp(_target_rect.position, e), h.size.lerp(_target_rect.size, e))


## Scale the live level so its screen sits on the opening panel.
func _apply_zoom() -> void:
	var e := _open()
	var r := Rect2(_r0.position.lerp(_target_rect.position, e), _r0.size.lerp(_target_rect.size, e))
	var k := r.size.x / _target_rect.size.x
	var z := Transform2D(0.0, Vector2(k, k), 0.0, r.position - _target_rect.position * k)
	get_viewport().global_canvas_transform = _g0 * z
	(get_parent() as CanvasLayer).transform = z.affine_inverse()  # but not the page itself


func _view_update() -> void:
	_page.transform = _view()
	_page.modulate.a = 1.0 - _ease(_open() / 0.4)


# ------------------------------------------------------------------ drawing

func _paper_alpha() -> float:
	return 1.0 - _ease((_open() - 0.8) / 0.2) if _comic else 1.0


## Paper over everything except the open part of the next panel.
func _draw() -> void:
	var outer := Rect2(-200, -200, size.x + 400, size.y + 400)
	var a := _paper_alpha()
	var open := _open_rect()
	if open.size.x > 0.5 and open.size.y > 0.5:
		var r := open
		var col := Color(PAPER, a)
		draw_rect(Rect2(outer.position, Vector2(outer.size.x, r.position.y - outer.position.y)), col)
		draw_rect(Rect2(outer.position.x, r.end.y, outer.size.x, outer.end.y - r.end.y), col)
		draw_rect(Rect2(outer.position.x, r.position.y, r.position.x - outer.position.x, r.size.y), col)
		draw_rect(Rect2(r.end.x, r.position.y, outer.end.x - r.end.x, r.size.y), col)
	else:
		draw_rect(outer, PAPER)


## The inked (see-through) part of the next panel, on screen.
func _open_rect() -> Rect2:
	if _stage < 2:
		return Rect2()
	var h := _hole()
	var ink := _ink()
	if tall:
		return Rect2(h.position, Vector2(h.size.x, h.size.y * ink))
	return Rect2(h.position, Vector2(h.size.x * ink, h.size.y))


## The rest of the page, drawn once and moved with the view.
func _draw_page() -> void:
	var c := _page
	# halftone on the page round the next panel (the panel itself stays clear:
	# the new level shows through it)
	var outer := Rect2(-360, -600, 2100, 1900)
	var q := _p2.grow(4.0)
	for r: Rect2 in [Rect2(outer.position, Vector2(outer.size.x, q.position.y - outer.position.y)),
			Rect2(outer.position.x, q.end.y, outer.size.x, outer.end.y - q.end.y),
			Rect2(outer.position.x, q.position.y, q.position.x - outer.position.x, q.size.y),
			Rect2(q.end.x, q.position.y, outer.end.x - q.end.x, q.size.y)]:
		c.draw_texture_rect_region(_dots, r, r)  # region = rect: the dots line up across pieces
	var rows := [Rect2(150, -120, 300, 280), Rect2(480, -120, 650, 280), Rect2(150, 476, 600, 290), Rect2(780, 476, 350, 290),
		Rect2(-340, 190, 460, 256), Rect2(1160, 190, 460, 256)]
	if tall:
		rows = [Rect2(150, -120, 460, 280), Rect2(150, 476, 460, 290), Rect2(-340, 190, 460, 256),
			Rect2(1060, 40, 380, 300), Rect2(1060, 370, 380, 310), Rect2(680, -560, 300, 570), Rect2(680, 710, 300, 300)]
	for r: Rect2 in rows:
		c.draw_rect(r, Color(0.9, 0.87, 0.8))
		var x := r.position.x + 12.0
		while x < r.end.x - 12.0:
			c.draw_line(Vector2(x, r.position.y + 14), Vector2(x - 30, r.position.y + 44), Color(PENCIL, 0.35), 1.0)
			x += 16.0
		ComicFrame.draw_border(c, r, 5.0, int(r.position.x))


func _draw_front() -> void:
	var c := _front
	var view := _view()
	var shrink := _shrink()
	var fade := 1.0 - _ease(_open() / 0.4)
	# the next panel: the pencil rough until the ink floods it
	var hole := _hole() if _stage == 2 else Rect2(view * _p2.position, _p2.size * view.get_scale())
	var open := _open_rect()
	if _stage < 2 or _ink() < 1.0:
		var rest := hole
		if open.size.x > 0.5 and open.size.y > 0.5:
			if tall:
				rest = Rect2(hole.position.x, open.end.y, hole.size.x, hole.end.y - open.end.y)
			else:
				rest = Rect2(open.end.x, hole.position.y, hole.end.x - open.end.x, hole.size.y)
		c.draw_rect(rest, PANEL_PAPER)
		c.draw_set_transform_matrix(view)
		_draw_sketch(c, 1.0 - _ease(_ink() / 0.25))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		if open.size.x > 0.5 and open.size.y > 0.5:
			_draw_ink_front(c, open)
	var bw := lerpf(6.0, 5.0 if _comic else 0.0, _open())
	if bw > 0.3:
		ComicFrame.draw_border(c, hole, bw, 2)
	# the old frame, shrinking into its panel (over the next one until it's small)
	if fade > 0.0:
		c.draw_set_transform_matrix(view)
		var full := _shot_src
		var p1 := Rect2(full.position.lerp(P1.position, shrink), full.size.lerp(P1.size, shrink))
		c.draw_texture_rect_region(_shot, p1, _shot_src, Color(1, 1, 1, fade))
		if fade >= 1.0:
			ComicFrame.draw_border(c, p1, lerpf(5.0, 6.0, shrink), 1)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# narrator caption in the corner of the next panel
	if shrink > 0.6 and _stage < 2:
		var a := clampf((shrink - 0.6) / 0.4, 0.0, 1.0)
		var text := "MEANWHILE, ONE PANEL LATER..."
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var box := Rect2(view * (_p2.position + Vector2(-14, -18)), Vector2(w + 24, 36))
		c.draw_rect(Rect2(box.position + Vector2(4, 4), box.size), Color(INK, 0.35 * a))
		c.draw_rect(box.grow(3.0), Color(INK, a))
		c.draw_rect(box, Color(CAPTION, a))
		c.draw_string(FONT, box.position + Vector2(12, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, a))
	# tiny Vesper hopping across the gutter (into the top of a tall panel)
	var pan := _pan()
	if pan > 0.0 and _stage < 2:
		var from := P1.get_center() + Vector2(120, 70)
		var to := _p2.get_center() + Vector2(-120, 70)
		var lift := 120.0
		if tall:
			to = Vector2(_p2.position.x + 80, _p2.position.y + 178)  # onto the first ledge
			lift = 160.0
		var p := from.lerp(to, pan) + Vector2(0, -sin(pan * PI) * lift)
		_draw_vesper(c, view * p, pan)


## The wet edge of the ink flooding the panel: a thick band with drips.
func _draw_ink_front(c: Node2D, open: Rect2) -> void:
	if tall:
		var y := open.end.y
		c.draw_rect(Rect2(open.position.x, y - 3.0, open.size.x, 6.0), INK)
		var x := open.position.x + 10.0
		var i := 0
		while x < open.end.x - 6.0:
			var ln := 6.0 + 14.0 * absf(sin(i * 2.7 + _t2 * 9.0))
			c.draw_rect(Rect2(x - 2.5, y, 5.0, ln), INK)
			c.draw_circle(Vector2(x, y + ln), 4.5, INK)
			x += 23.0 + 9.0 * absf(sin(i * 1.3))
			i += 1
	else:
		var x := open.end.x
		c.draw_rect(Rect2(x - 3.0, open.position.y, 6.0, open.size.y), INK)
		var y := open.position.y + 10.0
		var i := 0
		while y < open.end.y - 6.0:
			var ln := 6.0 + 12.0 * absf(sin(i * 2.7 + _t2 * 9.0))
			c.draw_rect(Rect2(x, y - 2.5, ln, 5.0), INK)
			c.draw_circle(Vector2(x + ln, y), 4.5, INK)
			y += 23.0 + 9.0 * absf(sin(i * 1.3))
			i += 1


## Pencil roughs of the next panel and its name (page space).
func _draw_sketch(c: Node2D, a: float) -> void:
	if a <= 0.0:
		return
	var p := _p2
	var col := Color(PENCIL, 0.7 * a)
	var boil := int(_t * 6.0)  # the lines boil a little, even while it loads
	var j := func(k: int) -> float: return (float(absi(hash(Vector2i(k, boil))) % 100) / 100.0 - 0.5) * 2.0
	if tall:
		# a shaft dropping out of sight, ledges zigzagging down it
		var l := p.position.x + 70.0
		var r := p.end.x - 70.0
		c.draw_line(Vector2(l + j.call(1), p.position.y + 150), Vector2(l + 10 + j.call(2), p.end.y - 10), col, 1.5)
		c.draw_line(Vector2(r + j.call(3), p.position.y + 150), Vector2(r - 8 + j.call(4), p.end.y - 10), col, 1.5)
		for k in 6:
			var y := p.position.y + 200.0 + k * 72.0
			var left := k % 2 == 0
			var x0 := l if left else r - 90.0
			c.draw_line(Vector2(x0 + j.call(10 + k), y), Vector2(x0 + 90.0, y + j.call(20 + k)), col, 2.0)
		var cx := p.get_center().x
		var y := p.position.y + 240.0
		while y < p.end.y - 60.0:
			c.draw_line(Vector2(cx, y), Vector2(cx, y + 14.0), Color(PENCIL, 0.5 * a), 1.5)
			y += 26.0
		c.draw_line(Vector2(cx - 12, p.end.y - 70), Vector2(cx, p.end.y - 50), col, 2.0)
		c.draw_line(Vector2(cx + 12, p.end.y - 70), Vector2(cx, p.end.y - 50), col, 2.0)
	else:
		c.draw_line(Vector2(p.position.x + 20, p.position.y + p.size.y * 0.72), Vector2(p.end.x - 20, p.position.y + p.size.y * 0.7), col, 1.5)
		for k in 5:
			var x := p.position.x + 40 + k * 90.0
			c.draw_line(Vector2(x + j.call(k), p.position.y + p.size.y * 0.72), Vector2(x + 20, p.position.y + 40 + k * 7.0), Color(PENCIL, 0.4 * a), 1.0)
	if title != "":
		var fs := 40
		var w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(FONT, Vector2(p.get_center().x - w * 0.5, p.position.y + (120.0 if tall else 110.0)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PENCIL, 0.8 * a))


func _draw_vesper(c: Node2D, p: Vector2, k: float) -> void:
	c.draw_set_transform(p, sin(k * TAU) * 0.3, Vector2.ONE)  # p is in screen space
	var cloak := PackedVector2Array([Vector2(-12, -6), Vector2(12, -6), Vector2(16, 22), Vector2(-16, 22)])
	c.draw_colored_polygon(cloak, INK)
	c.draw_line(Vector2(-6, -6), Vector2(-24, -14 + sin(_t * 14.0) * 5.0), Color(0.92, 0.3, 0.2), 4.0)  # scarf
	c.draw_circle(Vector2(0, -16), 11.0, Color(0.98, 0.96, 0.9))
	c.draw_circle(Vector2(4, -17), 2.5, INK)
	c.draw_rect(Rect2(-16, -30, 32, 5), INK)  # hat brim
	c.draw_rect(Rect2(-9, -39, 18, 10), INK)
	# speed lines behind her
	for i in 3:
		c.draw_line(Vector2(-22, -8 + i * 10), Vector2(-46 - i * 6, -8 + i * 10), Color(INK, 0.5), 2.0)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
