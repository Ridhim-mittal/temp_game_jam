extends Control
## The opening, fully animated (about 20 s): a comic book lying on a desk at
## night under a warm lamp. The cover swings open (light and sparks pour out),
## the camera comes down onto the first page, where the Writer's caption types
## "I JUST HAD THE CRAZIEST ADVENTURE..." while four little panels ink
## themselves in (the City, the light, the Gutter in 2.5D, the Eraser), then
## "BUT NOW... LET'S BEGIN." The page turns and the camera dives into the
## first panel of the story, which becomes the live City level (scaled into
## the panel the same way as panel_turn.gd), until it is the game's own panel.
##
## Everything is drawn in code. The book and the desk are real 3D points run
## through a small perspective camera (_proj); pages, the cover and the desk
## are SubViewport textures mapped onto subdivided quads. Sound effects are
## synthesised (no audio files). Esc / Enter skips.
##
## Lives on the root (it survives the scene change), like panel_turn.gd:
##   scenes/cutscenes/cs_book.tscn -> cs_book_start.gd -> CsBook.start(tree)

const ComicFrame = preload("res://scripts/ui/comic_frame.gd")
const PlayerArt = preload("res://scripts/player/player_visual.gd")
const CrawlerArt = preload("res://scripts/enemies/crawler_visual.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const HAND = preload("res://assets/fonts/Chewy-Regular.ttf")
const NEXT := "res://scenes/levels/test_level.tscn"

const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.96, 0.93, 0.85)
const PENCIL := Color(0.45, 0.43, 0.42)
const CAPTION := Color(1.0, 0.9, 0.45)
const GOLD := Color(1.0, 0.8, 0.3)
const RED := Color(0.9, 0.2, 0.16)
const WARM := Color(1.0, 0.9, 0.76)

const SC := Vector2(640, 360)
const FOCAL := 990.0
const BW := 260.0    # book page, world units
const BH := 390.0
const THICK := 16.0
const TEX := Vector2i(520, 780)   # page textures: 2 px per world unit
const PSI := -0.16                # the book's angle on the desk
const LAMP := Vector2(-300, 230)  # centre of the lamp's pool of light (world xy)
const SHADOW := Vector3(0.55, -0.3, -1.0)  # light direction for shadows (book space)

const T_OPEN := Vector2(3.3, 5.7)
const T_CAP1 := 6.4
const T_PANELS := [7.5, 8.4, 9.3, 10.2]
const T_PANEL_INK := 0.75
const T_CAP2 := 11.4
const T_TURN := Vector2(13.2, 15.2)
const T_TOP := 16.4
const T_LOAD := 16.45
const T_INK := Vector2(17.0, 17.6)
const T_END := 19.6
const T_FADE := 0.4
const SETTLE_FRAMES := 3

const LINE1 := "I JUST HAD THE CRAZIEST ADVENTURE..."
const LINE2 := "BUT NOW... LET'S BEGIN."
## Page one: the four panels (page pixels).
const P1_PANELS := [Rect2(26, 196, 225, 200), Rect2(269, 196, 225, 200), Rect2(26, 412, 225, 200), Rect2(269, 412, 225, 200)]
const P1_TAGS := ["THE CITY", "THE LIGHT", "THE GUTTER?!", "THE ERASER"]
## Page two: the story's first panel (page pixels; the shape of ComicFrame.PANEL).
const P2_PANEL := Rect2(26, 72, 468, 260)

## Camera keys: time, target (book space), distance, pitch, yaw, roll (degrees).
const KEYS := [
	[0.0, Vector3(140, 40, 0), 1750.0, 29.0, -30.0, -5.0],
	[3.3, Vector3(135, 0, 0), 1180.0, 42.0, -14.0, -2.0],
	[5.7, Vector3(0, 0, 0), 1060.0, 58.0, -5.0, 0.0],
	[7.2, Vector3(130, 2, THICK), 655.0, 79.0, 0.0, 0.0],
	[12.8, Vector3(130, -6, THICK), 612.0, 83.0, 1.5, 0.0],
	[14.8, Vector3(70, 30, THICK), 880.0, 74.0, 0.0, 0.0],
	[16.4, Vector3(130, 94, THICK), 414.0, 90.0, 0.0, 0.0],
]

var _t := 0.0
var _g0 := Transform2D.IDENTITY
var _loading := false
var _stage_n := 0     # 0 cutscene, 1 building the City, 2 revealing it, 3 done
var _frames := 0
var _skip := -1.0

# camera
var _cam := Vector3.ZERO
var _cf := Vector3.FORWARD
var _cr := Vector3.RIGHT
var _cu := Vector3.UP
var _shake := Vector2.ZERO
var _bx := Vector3(cos(PSI), sin(PSI), 0)
var _by := Vector3(-sin(PSI), cos(PSI), 0)

# render targets
var _stage: SubViewport
var _world: Node2D
var _glow: Node2D
var _top: Node2D
var _wood: SubViewport
var _cover: SubViewport
var _inside: SubViewport
var _p1: SubViewport
var _p1b: SubViewport
var _p2: SubViewport
var _sheet: SubViewport
var _p1_nodes: Array = []   # per panel: [clip Control, art nodes...]

# effects
var _sparks: Array = []   # [pos (book space), vel, life, max_life, kind]
var _motes: Array = []
var _sfx: Array = []      # comic sound words: [text, screen pos, t0, size, colour, tilt]
var _typed := [0, 0]
var _sounds := {}
var _played := {}


static func start(tree: SceneTree) -> void:
	var layer := CanvasLayer.new()
	layer.name = "CsBookLayer"
	layer.layer = 96
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var fx: Control = load("res://scripts/cutscenes/cs_book.gd").new()
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fx)
	tree.root.add_child.call_deferred(layer)


func _ready() -> void:
	_g0 = get_viewport().global_canvas_transform
	_loading = ResourceLoader.load_threaded_request(NEXT) == OK
	_wood = _make_vp(Vector2i(2048, 2048), Callable(), true)
	var wood_rect := ColorRect.new()
	wood_rect.size = Vector2(2048, 2048)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = WOOD_SHADER
	wood_rect.material = mat
	_wood.add_child(wood_rect)
	_cover = _make_vp(TEX, _paint_cover, true)
	_cover_hero(_cover)
	_inside = _make_vp(TEX, _paint_inside, true)
	_sheet = _make_vp(Vector2i(400, 300), _paint_sheet, true)
	_p2 = _make_vp(TEX, _paint_p2, true)
	_p1 = _make_vp(TEX, _paint_p1_static, true)
	_p1.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # its panels and captions move
	_build_p1_panels()
	var cap := Node2D.new()
	cap.draw.connect(_paint_p1_captions.bind(cap))
	cap.set_meta("live", true)
	_p1.get_child(0).add_child(cap)
	_p1b = _make_vp(TEX, func(c: Control): _paper(c, Vector2(TEX), Color(0.93, 0.9, 0.81)), true)
	_p1b.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var through := Node2D.new()
	through.set_meta("live", true)
	through.draw.connect(_paint_p1_back.bind(through))
	_p1b.get_child(0).add_child(through)
	# the stage: the whole desk scene, drawn into a texture we show (and later cut a hole in)
	_stage = SubViewport.new()
	_stage.size = Vector2i(1280, 720)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	_stage.add_child(_world)
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	_stage.add_child(_glow)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	_stage.add_child(_top)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 46:
		_motes.append([Vector2(rng.randf() * 1280, rng.randf() * 720), rng.randf_range(0.6, 2.2), rng.randf() * TAU, rng.randf_range(4, 14)])
	_make_sounds()


func _exit_tree() -> void:
	get_viewport().global_canvas_transform = _g0


## A SubViewport the size of `px` holding a Control painted by `paint`
## (paint(node) is connected to the Control's draw); `static` = drawn once.
func _make_vp(px: Vector2i, paint: Callable, is_static: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	# static textures are drawn once (the wood shader is far too costly to redraw)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE if is_static else SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(px)
	vp.add_child(root)
	if paint.is_valid():
		root.draw.connect(paint.bind(root))
		root.set_meta("live", not is_static)
	return vp


# ------------------------------------------------------------------ timing

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _k(t0: float, dur: float) -> float:
	return clampf((_t - t0) / dur, 0.0, 1.0)


## Cover angle: opens with a little overshoot and settles flat.
func _cover_angle() -> float:
	var x := _k(T_OPEN.x, T_OPEN.y - T_OPEN.x)
	var e := _smoother(x)
	var settle := sin(clampf((x - 0.82) / 0.18, 0.0, 1.0) * PI) * 0.035
	return PI * minf(e + settle, 1.0)


func _turn() -> float:
	return _smoother(_k(T_TURN.x, T_TURN.y - T_TURN.x))


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	if _skip >= 0.0:
		_skip += delta
		if _skip > 0.3 and _stage_n == 0:
			_stage_n = 3
			_finish(true)
		queue_redraw()
		return
	_cues()
	_update_camera()
	# a kick when the cover bursts open and when the page flips
	var kick := 7.0 * exp(-maxf(_t - T_OPEN.x - 0.3, 0.0) * 5.0) * float(_t > T_OPEN.x + 0.3) \
		+ 3.0 * exp(-maxf(_t - T_TURN.x - 0.2, 0.0) * 6.0) * float(_t > T_TURN.x + 0.2)
	_shake = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * kick if _t < T_TOP else Vector2.ZERO
	_update_sparks(delta)
	match _stage_n:
		0:
			if _t >= T_LOAD:
				var packed := _loaded()
				if packed:
					_stage_n = 1
					get_tree().change_scene_to_packed(packed)
		1:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == NEXT:
				_frames += 1
				get_tree().paused = _frames > SETTLE_FRAMES
				if _frames > SETTLE_FRAMES:
					_stage_n = 2
		2:
			_apply_live()
			if _t >= T_END + T_FADE:
				_stage_n = 3
				_finish(false)
				return
	for vp in [_p1, _p1b]:
		for n in vp.get_child(0).find_children("*", "CanvasItem", true, false) + [vp.get_child(0)]:
			if n.get_meta("live", false):
				n.queue_redraw()
	_world.queue_redraw()
	_glow.queue_redraw()
	_top.queue_redraw()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _skip >= 0.0 or _stage_n > 0:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip = 0.0


func _loaded() -> PackedScene:
	if not _loading:
		return load(NEXT) as PackedScene
	var st := ResourceLoader.load_threaded_get_status(NEXT)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(NEXT) as PackedScene
	return load(NEXT) as PackedScene


func _finish(skipped: bool) -> void:
	var tree := get_tree()
	tree.paused = false
	get_viewport().global_canvas_transform = _g0
	if skipped:
		tree.change_scene_to_file(NEXT)
	get_parent().queue_free()


## Sounds and one-off effects on the timeline.
func _cues() -> void:
	for i in 4:
		var tick := 0.4 + i * 0.85
		if _t >= tick:
			_once("tick%d" % i, func(): _play("tick", -14.0 + i * 1.5))
	_once_at(T_OPEN.x - 0.05, "creak", func(): _play("thump", -6.0))
	_once_at(T_OPEN.x + 0.35, "whoosh", func():
		_play("whoosh", -4.0)
		_word("WHOOSH!", Vector2(900, 210), 92, GOLD, -0.12))
	_once_at(T_OPEN.x + 0.5, "music", func():
		var music := get_node_or_null("/root/Music")
		if music:
			music.play("city", 2.5))
	_once_at(T_OPEN.y - 0.25, "land", func():
		_play("thump", -10.0)
		_play("chime", -9.0))
	for i in 4:
		_once_at(T_PANELS[i], "scratch%d" % i, func(): _play("scratch", -12.0))
	_once_at(T_PANELS[0] + T_PANEL_INK * 0.6, "thwack", func(): _play("pop", -10.0))
	_once_at(T_TURN.x, "flip", func():
		_play("flip", -3.0)
		_word("FLIP!", Vector2(1010, 300), 74, CAPTION, 0.1))
	_once_at(T_INK.x - 0.4, "dive", func(): _play("dive", -4.0))
	_once_at(T_INK.x + 0.1, "chime2", func(): _play("chime", -8.0))
	# typing
	for li in 2:
		var shown := _shown(li)
		if shown > _typed[li]:
			if shown % 2 == 0:
				_play("type", -20.0)
			_typed[li] = shown


func _once(key: String, f: Callable) -> void:
	if not _played.has(key):
		_played[key] = true
		f.call()


func _once_at(at: float, key: String, f: Callable) -> void:
	if _t >= at:
		_once(key, f)


func _word(text: String, at: Vector2, px: int, col: Color, tilt: float) -> void:
	_sfx.append([text, at, _t, px, col, tilt])


# ------------------------------------------------------------------ camera

func _key_vals(k: Array) -> PackedFloat32Array:
	var tg: Vector3 = k[1]
	return PackedFloat32Array([tg.x, tg.y, tg.z, log(k[2]), k[3], k[4], k[5]])


## Smooth path through the keys (cubic Hermite, Catmull-Rom tangents).
func _camera_at(t: float) -> PackedFloat32Array:
	var n := KEYS.size()
	if t <= KEYS[0][0]:
		return _key_vals(KEYS[0])
	if t >= KEYS[n - 1][0]:
		return _key_vals(KEYS[n - 1])
	var i := 0
	while i < n - 2 and t > KEYS[i + 1][0]:
		i += 1
	var t0: float = KEYS[i][0]
	var t1: float = KEYS[i + 1][0]
	var h := t1 - t0
	var s := (t - t0) / h
	var p0 := _key_vals(KEYS[i])
	var p1 := _key_vals(KEYS[i + 1])
	var out := PackedFloat32Array()
	out.resize(p0.size())
	for c in p0.size():
		var m0 := 0.0
		var m1 := 0.0
		if i > 0:
			m0 = (p1[c] - _key_vals(KEYS[i - 1])[c]) / (t1 - KEYS[i - 1][0])
		if i < n - 2:
			m1 = (_key_vals(KEYS[i + 2])[c] - p0[c]) / (KEYS[i + 2][0] - t0)
		var s2 := s * s
		var s3 := s2 * s
		out[c] = (2 * s3 - 3 * s2 + 1) * p0[c] + (s3 - 2 * s2 + s) * h * m0 + (-2 * s3 + 3 * s2) * p1[c] + (s3 - s2) * h * m1
	return out


func _update_camera() -> void:
	var v := _camera_at(_t)
	var target := _bk(Vector3(v[0], v[1], v[2]))
	var dist := exp(v[3])
	if _t > T_TOP:  # straight down over the first panel, then the dive into it
		var w0 := 2.0 * FOCAL * (P2_PANEL.size.x * 0.25) / exp(v[3])  # its width on screen at T_TOP
		var k := _smoother((_t - T_INK.y) / (T_END - T_INK.y))
		var w := lerpf(w0 * (1.0 + 0.04 * _ease((_t - T_TOP) / (T_INK.y - T_TOP))), ComicFrame.PANEL.size.x, k)
		dist = FOCAL * (P2_PANEL.size.x * 0.25) / (w * 0.5)
	var pitch := deg_to_rad(v[4])
	var yaw := deg_to_rad(v[5])
	var roll := deg_to_rad(v[6])
	var fwd := _by.rotated(Vector3(0, 0, 1), yaw)
	_cam = target + (-fwd * cos(pitch) + Vector3(0, 0, 1) * sin(pitch)) * dist
	_cf = (target - _cam).normalized()
	var r := _cf.cross(fwd).normalized()
	var u := r.cross(_cf)
	_cr = r * cos(roll) + u * sin(roll)
	_cu = u * cos(roll) - r * sin(roll)


## Book space (x from the spine, y up the page, z up) -> world.
func _bk(p: Vector3) -> Vector3:
	return _bx * p.x + _by * p.y + Vector3(0, 0, p.z)


func _proj(p: Vector3) -> Vector2:
	var d := p - _cam
	var z := maxf(d.dot(_cf), 1.0)
	return SC + _shake + Vector2(d.dot(_cr), -d.dot(_cu)) * (FOCAL / z)


func _projb(p: Vector3) -> Vector2:
	return _proj(_bk(p))


## Light of the lamp's pool at a world point (0 dark .. ~1.15 in the middle).
func _pool(p: Vector3) -> float:
	var d := Vector2(p.x, p.y).distance_to(LAMP)
	return 0.12 + 1.05 / (1.0 + pow(d / 620.0, 2.4))


func _lit(p: Vector3, k := 1.0) -> Color:
	var b := _pool(p) * k
	return Color(WARM.r * b, WARM.g * b, WARM.b * b * 0.95, 1.0)


# ------------------------------------------------------------- surfaces

## A grid of world points [i][j] (u along i, v along j) textured with `tex`
## (texture x = u, or 1 - u when `flip`), lit per vertex, as one draw call.
func _grid_surface(ci: CanvasItem, tex: Texture2D, grid: Array, flip := false, shade := 1.0, normals: Array = []) -> void:
	var nu: int = grid.size() - 1
	var nv: int = grid[0].size() - 1
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in nu + 1:
		for j in nv + 1:
			var p: Vector3 = grid[i][j]
			pts.append(_proj(p))
			var u := float(i) / nu
			uvs.append(Vector2(1.0 - u if flip else u, float(j) / nv))
			var k := shade
			if not normals.is_empty():
				k *= normals[mini(i, nu - 1)]
			cols.append(_lit(p, k))
	for i in nu:
		for j in nv:
			var a := i * (nv + 1) + j
			var b := a + nv + 1
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(),
		PackedFloat32Array(), tex.get_rid())


## A flat rectangle in book space at height z: x0..x1, y0..y1 (texture top = y1).
func _flat_grid(x0: float, x1: float, y0: float, y1: float, z: float, nu := 8, nv := 12) -> Array:
	var g := []
	for i in nu + 1:
		var row := []
		for j in nv + 1:
			row.append(_bk(Vector3(lerpf(x0, x1, float(i) / nu), lerpf(y1, y0, float(j) / nv), z)))
		g.append(row)
	return g


## A page hinged at the spine, turning by `s` (0 flat on the right, 1 flat on
## the left), curling: the outer edge leads. Book-space points [i][j].
func _turn_grid(s: float, z_from: float, z_to: float, stiff: float, nu := 22, nv := 10) -> Array:
	var g := []
	for i in nu + 1:
		g.append([])
	for j in nv + 1:
		var v := float(j) / nv
		var y := lerpf(BH * 0.5, -BH * 0.5, v)
		var twist := (v - 0.5) * 0.16 * sin(s * PI)  # the near corner lags a little
		var p := Vector3(0, y, lerpf(z_from, z_to, s))
		g[0].append(_bk(p))
		for i in nu:
			var um := (i + 0.5) / nu
			var th := clampf((s * (1.0 + stiff) - (1.0 - um) * stiff + twist) , 0.0, 1.0) * PI
			p += Vector3(cos(th), 0, sin(th)) * (BW / nu)
			g[i + 1].append(_bk(p))
	return g


## Which way each strip of a grid faces the camera (true = front), and its light.
func _strip_facing(grid: Array) -> Array:
	var out := []
	var nv: int = grid[0].size() - 1
	var mid := nv / 2
	for i in grid.size() - 1:
		var a := _proj(grid[i][mid])
		var b := _proj(grid[i + 1][mid])
		var c := _proj(grid[i][mid + 1])
		out.append((b - a).cross(c - a) > 0.0)
	return out


func _strip_light(grid: Array) -> Array:
	var out := []
	var nv: int = grid[0].size() - 1
	var l := (-SHADOW).normalized()
	for i in grid.size() - 1:
		var du: Vector3 = grid[i + 1][nv / 2] - grid[i][nv / 2]
		var dv: Vector3 = grid[i][nv / 2 + 1] - grid[i][nv / 2]
		var n := dv.cross(du).normalized()
		if n.z < 0.0:
			n = -n
		var lb := (_bx * l.x + _by * l.y + Vector3(0, 0, l.z)).normalized()
		out.append(0.62 + 0.42 * clampf(n.dot(lb), 0.0, 1.0))
	return out


## Draw a turning sheet: front strips with `front`, back strips with `back`.
func _sheet_surface(ci: CanvasItem, grid: Array, front: Texture2D, back: Texture2D) -> void:
	var facing := _strip_facing(grid)
	var light := _strip_light(grid)
	for side in 2:
		var sub := []
		var subl := []
		var start := -1
		for i in facing.size() + 1:
			var want: bool = i < facing.size() and facing[i] == (side == 0)
			if want and start < 0:
				start = i
			if (not want or i == facing.size()) and start >= 0:
				sub = grid.slice(start, i + 1)
				subl = light.slice(start, i)
				_grid_surface_part(ci, front if side == 0 else back, sub, start, grid.size() - 1, side == 1, subl)
				start = -1


## Part of a grid (columns start..), keeping the texture coordinates of the whole.
func _grid_surface_part(ci: CanvasItem, tex: Texture2D, sub: Array, first: int, total: int, flip: bool, light: Array) -> void:
	var nv: int = sub[0].size() - 1
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in sub.size():
		for j in nv + 1:
			var p: Vector3 = sub[i][j]
			pts.append(_proj(p))
			var u := float(first + i) / total
			uvs.append(Vector2(1.0 - u if flip else u, float(j) / nv))
			cols.append(_lit(p, light[mini(i, light.size() - 1)]))
	for i in sub.size() - 1:
		for j in nv:
			var a := i * (nv + 1) + j
			var b := a + nv + 1
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(),
		PackedFloat32Array(), tex.get_rid())


## A flat polygon in world space, one colour per vertex (projected).
func _poly3(ci: CanvasItem, pts3: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for q in pts3:
		p.append(_proj(q))
	if p.size() >= 3:
		_fill(ci, p, col)


## Shadow of a book-space grid on the plane z = `on_z` along SHADOW, clamped to x in [x0, x1].
func _grid_shadow(ci: CanvasItem, grid: Array, on_z: float, x0: float, x1: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var nu: int = grid.size() - 1
	var nv: int = grid[0].size() - 1
	for i in nu + 1:
		for j in nv + 1:
			var w: Vector3 = grid[i][j]
			var b := Vector3(w.dot(_bx), w.dot(_by), w.z)  # back to book space
			var k := (b.z - on_z) / -SHADOW.z
			var s := b + SHADOW * k
			s.x = clampf(s.x, x0, x1)
			s.y = clampf(s.y, -BH * 0.5, BH * 0.5)
			pts.append(_projb(Vector3(s.x, s.y, on_z + 0.3)))
			cols.append(Color(0.02, 0.01, 0.04, alpha * clampf(k / 60.0, 0.25, 1.0)))
	for i in nu:
		for j in nv:
			var a := i * (nv + 1) + j
			var bb := a + nv + 1
			idx.append_array([a, bb, bb + 1, a, bb + 1, a + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


# ------------------------------------------------------------------ world

func _draw_world() -> void:
	var w := _world
	w.draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.02, 0.025))
	# the desk
	var desk := []
	for i in 17:
		var row := []
		for j in 17:
			row.append(Vector3(lerpf(-1900, 1900, i / 16.0), lerpf(1700, -1100, j / 16.0), 0))
		desk.append(row)
	_grid_surface(w, _wood.get_texture(), desk)
	# a loose sheet of character sketches, the pencil, the eraser, ink, the pen
	var sheet := []
	var sc := Vector3(-470, 120, 0.4)
	var sx := Vector3(cos(0.35), sin(0.35), 0)
	var sy := Vector3(-sin(0.35), cos(0.35), 0)
	for i in 5:
		var row := []
		for j in 5:
			row.append(sc + sx * lerpf(-200, 200, i / 4.0) + sy * lerpf(150, -150, j / 4.0))
		sheet.append(row)
	_soft_shadow(w, [sc + sx * -200 + sy * 150, sc + sx * 200 + sy * 150, sc + sx * 200 + sy * -150, sc + sx * -200 + sy * -150], 6.0, 0.35)
	_grid_surface(w, _sheet.get_texture(), sheet)
	_mug(w, Vector3(560, 380, 0))
	_ink_bottle(w, Vector3(430, 150, 0))
	_rod(w, Vector3(330, 40, 4), Vector3(520, -170, 4), 4.0, Color(0.1, 0.09, 0.12), "pen")
	_rod(w, Vector3(-560, -90, 6), Vector3(-300, -260, 6), 6.5, Color(1.0, 0.78, 0.18), "pencil")
	_eraser(w, Vector3(-420, -330, 0))
	_shavings(w)
	# the book
	_book(w)


func _soft_shadow(ci: CanvasItem, pts3: Array, lift: float, alpha: float) -> void:
	var c := Vector3.ZERO
	for p in pts3:
		c += p
	c /= pts3.size()
	var off := Vector3(SHADOW.x, SHADOW.y, 0).rotated(Vector3(0, 0, 1), PSI) * lift
	for k in 4:
		var g := 1.0 + 0.035 * k
		var pp := []
		for p in pts3:
			pp.append(c + (p - c) * g + off + Vector3(0, 0, 0.2))
		_poly3(ci, pp, Color(0.0, 0.0, 0.0, alpha * 0.32))


func _book(w: Node2D) -> void:
	var ca := _cover_angle()
	var s := _turn()
	var open := ca / PI
	# shadow of the book on the desk
	var x_left := lerpf(0.0, -BW, open)
	_soft_shadow(w, [_bk(Vector3(minf(x_left, 0.0), BH * 0.5, 0)), _bk(Vector3(BW, BH * 0.5, 0)),
		_bk(Vector3(BW, -BH * 0.5, 0)), _bk(Vector3(minf(x_left, 0.0), -BH * 0.5, 0))], THICK * 1.4, 0.55)
	# the block of pages: its sides (only those facing us)
	_block_sides(w)
	# page two (under page one)
	_grid_surface(w, _p2.get_texture(), _flat_grid(0, BW, -BH * 0.5, BH * 0.5, THICK - 0.3))
	var cover := _turn_grid(open, THICK + 1.0, 1.2, 0.18, 18, 8)
	if open > 0.5:
		_sheet_surface(w, cover, _cover.get_texture(), _inside.get_texture())
	# page one turning, its shadow on page two first
	var page := _turn_grid(s, THICK + 0.2, 2.0, 0.75)
	if s > 0.001 and s < 0.999:
		_grid_shadow(w, page, THICK - 0.3, 0.0, BW, 0.38 * sin(s * PI))
	_sheet_surface(w, page, _p1.get_texture(), _p1b.get_texture())
	if open <= 0.5:
		if open > 0.01:  # the lifting cover shades the page under it
			_grid_shadow(w, cover, THICK + 0.25, 0.0, BW, 0.45 * sin(open * PI))
		_sheet_surface(w, cover, _cover.get_texture(), _inside.get_texture())
		_cover_edges(w, cover)


func _block_sides(w: Node2D) -> void:
	# near side (y = -BH/2) and fore edge (x = BW): stacked paper
	var faces := [
		[Vector3(0, -BH * 0.5, 0), Vector3(BW, -BH * 0.5, 0), Vector3(BW, -BH * 0.5, THICK), Vector3(0, -BH * 0.5, THICK)],
		[Vector3(BW, -BH * 0.5, 0), Vector3(BW, BH * 0.5, 0), Vector3(BW, BH * 0.5, THICK), Vector3(BW, -BH * 0.5, THICK)],
	]
	for f in faces:
		var p := PackedVector2Array()
		for q in f:
			p.append(_projb(q))
		if (p[1] - p[0]).cross(p[3] - p[0]) > 0.0:
			continue
		var base := _lit(_bk(f[0]), 0.78)
		_fill(w, p, Color(0.93 * base.r, 0.89 * base.g, 0.8 * base.b))
		for k in range(1, 9):  # the edges of the pages
			var z := THICK * k / 9.0
			var a := _projb(Vector3(f[0].x, f[0].y, z))
			var b := _projb(Vector3(f[1].x, f[1].y, z))
			w.draw_line(a, b, Color(0.55, 0.5, 0.45, 0.5), 1.0)
		w.draw_polyline(p + PackedVector2Array([p[0]]), Color(INK, 0.8), 1.5)


func _cover_edges(w: Node2D, cover: Array) -> void:
	# a dark board edge round the cover so it reads as a cover
	var nv: int = cover[0].size() - 1
	var line := PackedVector2Array()
	for i in cover.size():
		line.append(_proj(cover[i][nv]))
	for j in range(nv, -1, -1):
		line.append(_proj(cover[cover.size() - 1][j]))
	w.draw_polyline(line, Color(INK, 0.85), 2.0)


func _rod(w: Node2D, a: Vector3, b: Vector3, r: float, col: Color, kind: String) -> void:
	var off := Vector3(SHADOW.x, SHADOW.y, 0) * a.z * 1.4
	var pa := _proj(a)
	var pb := _proj(b)
	var sa := _proj(a - Vector3(0, 0, a.z) + off)
	var sb := _proj(b - Vector3(0, 0, b.z) + off)
	var ra := r * FOCAL / maxf((a - _cam).dot(_cf), 1.0)
	var rb := r * FOCAL / maxf((b - _cam).dot(_cf), 1.0)
	var n := (pb - pa).orthogonal().normalized()
	_fill(w, PackedVector2Array([sa + n * ra, sb + n * rb, sb - n * rb, sa - n * ra]), Color(0, 0, 0, 0.35))
	var lit := _lit(a)
	var body := Color(col.r * lit.r, col.g * lit.g, col.b * lit.b)
	var tip := pb + (pb - pa).normalized() * rb * (6.0 if kind == "pencil" else 9.0)
	if kind == "pencil":
		_fill(w, PackedVector2Array([pa + n * ra, pb + n * rb, pb - n * rb, pa - n * ra]), body)
		w.draw_line(pa, pb, body.lightened(0.3), maxf(ra * 0.5, 1.0))
		var wood := Color(0.86, 0.68, 0.48) * lit
		_fill(w, PackedVector2Array([pb + n * rb, tip, pb - n * rb]), Color(wood, 1.0))
		_fill(w, PackedVector2Array([pb.lerp(tip, 0.65) + n * rb * 0.35, tip, pb.lerp(tip, 0.65) - n * rb * 0.35]), Color(0.2, 0.2, 0.22))
		var back := pa - (pb - pa).normalized() * ra * 2.4
		_fill(w, PackedVector2Array([pa + n * ra, pa - n * ra, back - n * ra, back + n * ra]), Color(0.72, 0.72, 0.76) * lit)
		var end := back - (pb - pa).normalized() * ra * 2.2
		_fill(w, PackedVector2Array([back + n * ra, back - n * ra, end - n * ra * 0.9, end + n * ra * 0.9]), Color(0.95, 0.5, 0.55) * lit)
	else:
		_fill(w, PackedVector2Array([pa + n * ra, pb + n * rb, pb - n * rb, pa - n * ra]), body)
		w.draw_line(pa + n * ra * 0.4, pb + n * rb * 0.4, Color(1, 1, 1, 0.25), 1.5)
		_fill(w, PackedVector2Array([pb + n * rb, tip, pb - n * rb]), Color(0.8, 0.78, 0.72) * lit)  # steel nib
		w.draw_line(pb, tip, Color(0.15, 0.12, 0.2), 1.2)


func _eraser(w: Node2D, c: Vector3) -> void:
	# the pink eraser (the Eraser's little cousin): a box, a cross brow drawn on it
	var size := Vector3(84, 40, 26)
	var a := 0.55
	var ex := Vector3(cos(a), sin(a), 0)
	var ey := Vector3(-sin(a), cos(a), 0)
	var corner := func(sxx: float, syy: float, szz: float) -> Vector3:
		return c + ex * size.x * 0.5 * sxx + ey * size.y * 0.5 * syy + Vector3(0, 0, size.z * szz)
	_soft_shadow(w, [corner.call(-1, 1, 0), corner.call(1, 1, 0), corner.call(1, -1, 0), corner.call(-1, -1, 0)], 22.0, 0.5)
	var lit := _lit(c)
	var pink := Color(0.96, 0.55, 0.6)
	var sides := [[[-1, -1], [1, -1]], [[1, -1], [1, 1]], [[1, 1], [-1, 1]], [[-1, 1], [-1, -1]]]
	for sd in sides:
		var p := PackedVector2Array([_proj(corner.call(sd[0][0], sd[0][1], 0)), _proj(corner.call(sd[1][0], sd[1][1], 0)),
			_proj(corner.call(sd[1][0], sd[1][1], 1)), _proj(corner.call(sd[0][0], sd[0][1], 1))])
		if (p[1] - p[0]).cross(p[3] - p[0]) < 0.0:
			var k := 0.62 if sd[0][1] == -1 else 0.78
			_fill(w, p, Color(pink.r * lit.r * k, pink.g * lit.g * k, pink.b * lit.b * k))
			w.draw_polyline(p + PackedVector2Array([p[0]]), Color(INK, 0.7), 1.5)
	var top := PackedVector2Array([_proj(corner.call(-1, 1, 1)), _proj(corner.call(1, 1, 1)), _proj(corner.call(1, -1, 1)), _proj(corner.call(-1, -1, 1))])
	_fill(w, top, Color(pink.r * lit.r, pink.g * lit.g, pink.b * lit.b))
	w.draw_polyline(top + PackedVector2Array([top[0]]), Color(INK, 0.75), 1.5)
	# a doodled angry face on top
	var f := func(x: float, y: float) -> Vector2: return _proj(c + ex * x + ey * y + Vector3(0, 0, size.z + 0.2))
	w.draw_line(f.call(-18, 8), f.call(-6, 3), INK, 2.0)
	w.draw_line(f.call(18, 8), f.call(6, 3), INK, 2.0)
	w.draw_circle(f.call(-11, -1), 2.2, INK)
	w.draw_circle(f.call(11, -1), 2.2, INK)
	w.draw_line(f.call(-9, -9), f.call(9, -9), INK, 2.0)


func _cyl_screen(base: Vector3, r: float, h: float) -> Array:
	var b := _proj(base)
	var t := _proj(base + Vector3(0, 0, h))
	var rx := r * FOCAL / maxf((base - _cam).dot(_cf), 1.0)
	var ry := rx * clampf(absf(_cf.z), 0.15, 1.0)
	return [b, t, rx, ry]


func _ink_bottle(w: Node2D, base: Vector3) -> void:
	var c := _cyl_screen(base, 34, 70)
	var b: Vector2 = c[0]
	var t: Vector2 = c[1]
	var rx: float = c[2]
	var ry: float = c[3]
	var lit := _pool(base)
	_fill(w, _ellipse(b + Vector2(rx * 0.5, ry * 0.4), rx * 1.25, ry * 1.25), Color(0, 0, 0, 0.4))
	var shoulder := t.lerp(b, 0.22)
	var body := PackedVector2Array([b + Vector2(-rx, 0), shoulder + Vector2(-rx, 0), shoulder + Vector2(-rx * 0.5, -ry * 0.6),
		t + Vector2(-rx * 0.42, 0), t + Vector2(rx * 0.42, 0), shoulder + Vector2(rx * 0.5, -ry * 0.6), shoulder + Vector2(rx, 0), b + Vector2(rx, 0)])
	_fill(w, _ellipse(b, rx, ry), Color(0.04, 0.03, 0.08))
	_fill(w, body, Color(0.05, 0.04, 0.12))
	w.draw_line(b.lerp(t, 0.15) + Vector2(-rx * 0.6, 0), b.lerp(t, 0.7) + Vector2(-rx * 0.6, 0), Color(0.6, 0.65, 0.9, 0.35 * lit), maxf(rx * 0.12, 1.0))
	var lab := Rect2(b.lerp(t, 0.42) - Vector2(rx * 0.75, rx * 0.35), Vector2(rx * 1.5, rx * 0.7))
	w.draw_rect(lab, Color(0.93, 0.88, 0.76) * lit)
	w.draw_string(FONT, lab.position + Vector2(lab.size.x * 0.18, lab.size.y * 0.8), "INK", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(rx * 0.55, 6)), INK)
	_fill(w, _ellipse(t, rx * 0.42, ry * 0.42), Color(0.12, 0.1, 0.16))
	w.draw_polyline(body + PackedVector2Array([body[0]]), Color(INK, 0.9), 1.5)


func _mug(w: Node2D, base: Vector3) -> void:
	var c := _cyl_screen(base, 52, 90)
	var b: Vector2 = c[0]
	var t: Vector2 = c[1]
	var rx: float = c[2]
	var ry: float = c[3]
	var lit := _pool(base)
	var col := Color(0.82, 0.3, 0.26) * lit
	_fill(w, _ellipse(b + Vector2(rx * 0.4, ry * 0.4), rx * 1.2, ry * 1.2), Color(0, 0, 0, 0.4))
	_fill(w, PackedVector2Array([b + Vector2(-rx, 0), t + Vector2(-rx, 0), t + Vector2(rx, 0), b + Vector2(rx, 0)]), Color(col, 1.0))
	_fill(w, _ellipse(b, rx, ry), Color(col, 1.0))
	w.draw_arc(t.lerp(b, 0.45) + Vector2(rx, 0), rx * 0.45, -PI * 0.5, PI * 0.5, 12, Color(col, 1.0), maxf(rx * 0.16, 1.5))
	_fill(w, _ellipse(t, rx, ry), Color(0.75, 0.25, 0.22) * lit)
	_fill(w, _ellipse(t, rx * 0.86, ry * 0.86), Color(0.2, 0.11, 0.06))  # coffee
	for k in 3:  # steam
		var x := t.x + (k - 1) * rx * 0.35
		var pts := PackedVector2Array()
		for m in 8:
			var yy := t.y - m * rx * 0.25
			pts.append(Vector2(x + sin(_t * 1.6 + m * 0.8 + k * 2.0) * rx * 0.12, yy))
		w.draw_polyline(pts, Color(1, 1, 1, 0.12 * lit), maxf(rx * 0.08, 1.0), true)


func _shavings(w: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var p := Vector3(-330 + rng.randf_range(-70, 70), -300 + rng.randf_range(-50, 60), 0.5)
		var s := _proj(p)
		var r := 9.0 * FOCAL / maxf((p - _cam).dot(_cf), 1.0)
		var a0 := rng.randf() * TAU
		w.draw_arc(s, r, a0, a0 + 3.6, 10, Color(0.85, 0.66, 0.45) * _pool(p), maxf(r * 0.45, 1.0))
		w.draw_arc(s, r * 1.1, a0, a0 + 3.6, 10, Color(0.95, 0.75, 0.2) * _pool(p), maxf(r * 0.12, 1.0))


## Skips shapes seen edge-on (no area to triangulate: a book side, a shadow).
func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var area := 0.0
	for i in pts.size():
		area += pts[i].cross(pts[(i + 1) % pts.size()])
	if absf(area) > 2.0:
		ci.draw_colored_polygon(pts, col)


func _ellipse(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		p.append(c + Vector2(cos(TAU * i / n) * rx, sin(TAU * i / n) * ry))
	return p


# ------------------------------------------------------------- light, fx

func _update_sparks(delta: float) -> void:
	var opening := _t > T_OPEN.x + 0.2 and _t < T_OPEN.y + 0.4
	var turning := _t > T_TURN.x + 0.4 and _t < T_TURN.y
	var rng_rate := 70.0 if opening else (22.0 if turning else (4.0 if _t > T_OPEN.y and _t < T_TURN.y else 0.0))
	var n := int(rng_rate * delta + randf())
	for i in n:
		var kind := 0  # sparkles (ink drops read as holes on the page)
		var p := Vector3(randf_range(-BW * 0.8, BW * 0.9), randf_range(-BH * 0.45, BH * 0.45), THICK + 2)
		var v := Vector3(randf_range(-60, 60), randf_range(-60, 60), randf_range(160, 420))
		if kind == 1:
			v.z *= 1.3
		var life := randf_range(0.8, 1.8)
		_sparks.append([p, v, life, life, kind, randf_range(1.5, 4.0)])
	for s in _sparks:
		s[0] += s[1] * delta
		s[1].z -= (120.0 if s[4] == 0 else 520.0) * delta
		s[1] *= 1.0 - 0.6 * delta
		s[2] -= delta
	_sparks = _sparks.filter(func(s): return s[2] > 0.0 and s[0].z > -2.0)


func _draw_glow() -> void:
	var g := _glow
	# the lamp: a warm cone from off the top left and its pool on the desk
	var pool := _proj(Vector3(LAMP.x, LAMP.y, 0))
	_radial(g, pool, 760.0, Color(1.0, 0.72, 0.4, 0.09))
	var src := Vector2(-120, -160)
	g.draw_polygon(PackedVector2Array([src, pool + Vector2(-700, 260), pool + Vector2(620, -40)]),
		PackedColorArray([Color(1.0, 0.85, 0.6, 0.08), Color(1, 0.8, 0.5, 0.0), Color(1, 0.8, 0.5, 0.0)]))
	# light pouring out of the book as it opens
	var open := _cover_angle() / PI
	var burst := sin(clampf(open, 0.0, 1.0) * PI) * 0.9 + 0.25 * _ease((_t - T_OPEN.y) / 0.6) * (1.0 - _ease((_t - T_CAP1) / 1.5))
	burst += 0.6 * sin(_turn() * PI)
	if burst > 0.01:
		var c := _projb(Vector3(BW * 0.45, 0, THICK + 6))
		_radial(g, c, 420.0 * (0.7 + burst * 0.5), Color(1.0, 0.75, 0.35, 0.42 * burst))
		for k in 14:  # rays
			var a := TAU * k / 14.0 + _t * 0.35
			var d := Vector2.from_angle(a)
			var ray := (520.0 + 160.0 * sin(_t * 3.0 + k * 1.7)) * burst
			g.draw_polygon(PackedVector2Array([c + d.orthogonal() * 10.0, c + d * ray + d.orthogonal() * 46.0, c + d * ray - d.orthogonal() * 46.0, c - d.orthogonal() * 10.0]),
				PackedColorArray([Color(1, 0.85, 0.5, 0.22 * burst), Color(1, 0.8, 0.4, 0.0), Color(1, 0.8, 0.4, 0.0), Color(1, 0.85, 0.5, 0.22 * burst)]))
	# sparkles
	for s in _sparks:
		if s[4] != 0:
			continue
		var p := _projb(s[0])
		var a: float = clampf(s[2] / s[3], 0.0, 1.0)
		var r: float = s[5] * (FOCAL / maxf((_bk(s[0]) - _cam).dot(_cf), 1.0)) * 1.6
		_radial(g, p, r * 5.0, Color(1.0, 0.8, 0.4, 0.45 * a))
		g.draw_line(p - Vector2(r * 2.2, 0), p + Vector2(r * 2.2, 0), Color(1, 0.95, 0.75, a), 1.5)
		g.draw_line(p - Vector2(0, r * 2.2), p + Vector2(0, r * 2.2), Color(1, 0.95, 0.75, a), 1.5)
	# dust in the lamp light
	for m in _motes:
		var p: Vector2 = m[0] + Vector2(sin(_t * 0.4 + m[2]) * 30.0, -fmod(_t * m[3], 720.0))
		p.y = fposmod(p.y, 720.0)
		var lit := clampf(1.0 - p.distance_to(pool) / 900.0, 0.0, 1.0)
		g.draw_circle(p, m[1], Color(1.0, 0.85, 0.6, 0.35 * lit))


func _radial(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	var idx := PackedInt32Array()
	for i in 32:
		pts.append(c + Vector2.from_angle(TAU * i / 32.0) * r)
		cols.append(Color(col, 0.0))
		idx.append_array([0, 1 + i, 1 + (i + 1) % 32])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


func _draw_top() -> void:
	var c := _top
	# ink drops thrown out of the book
	for s in _sparks:
		if s[4] != 1:
			continue
		var p := _projb(s[0])
		var r: float = s[5] * 1.8 * (FOCAL / maxf((_bk(s[0]) - _cam).dot(_cf), 1.0))
		c.draw_circle(p, r, INK)
		c.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.4))
	# vignette, warmer at the lamp side
	var edge := Color(0.0, 0.0, 0.0, 0.7)
	var clear := Color(0, 0, 0, 0)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 150), Vector2(0, 150)]), PackedColorArray([edge, edge, clear, clear]))
	c.draw_polygon(PackedVector2Array([Vector2(0, 570), Vector2(1280, 570), Vector2(1280, 720), Vector2(0, 720)]), PackedColorArray([clear, clear, edge, edge]))
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(240, 0), Vector2(240, 720), Vector2(0, 720)]), PackedColorArray([edge, clear, clear, edge]))
	c.draw_polygon(PackedVector2Array([Vector2(1040, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(1040, 720)]), PackedColorArray([clear, edge, edge, clear]))
	# comic sound words
	for wd in _sfx:
		var age: float = _t - wd[2]
		if age > 1.4:
			continue
		var pop := _pop_ease(age / 0.35)
		var a := 1.0 - clampf((age - 0.9) / 0.5, 0.0, 1.0)
		var px: int = wd[3]
		var text: String = wd[0]
		var tw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		c.draw_set_transform(wd[1] + Vector2(0, -age * 40.0), wd[5], Vector2(pop, pop) * (1.0 + age * 0.15))
		c.draw_string_outline(FONT, Vector2(-tw * 0.5 + 6, px * 0.35 + 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 14, Color(RED, a))
		c.draw_string_outline(FONT, Vector2(-tw * 0.5, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 16, Color(INK, a))
		c.draw_string(FONT, Vector2(-tw * 0.5, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(wd[4], a))
		c.draw_set_transform(Vector2.ZERO)


func _pop_ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x >= 1.0:
		return 1.0
	return 1.0 + pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * TAU / 3.0)


# ------------------------------------------------------- the screen itself

## The first panel of page two on screen (once the camera looks straight down).
func _panel_rect() -> Rect2:
	var p0 := _projb(Vector3(P2_PANEL.position.x * 0.5, BH * 0.5 - P2_PANEL.position.y * 0.5, THICK - 0.3))
	var p1 := _projb(Vector3(P2_PANEL.end.x * 0.5, BH * 0.5 - P2_PANEL.end.y * 0.5, THICK - 0.3))
	return Rect2(p0, Vector2.ZERO).expand(p1)


func _ink_frac() -> float:
	return _smoother(_k(T_INK.x, T_INK.y - T_INK.x)) if _stage_n >= 2 else 0.0


## Scale the live City so its panel (ComicFrame.PANEL) sits on the book's panel.
func _apply_live() -> void:
	var r := _panel_rect()
	var t := ComicFrame.PANEL
	var k := r.size.x / t.size.x
	var z := Transform2D(0.0, Vector2(k, k), 0.0, r.position - t.position * k)
	get_viewport().global_canvas_transform = _g0 * z
	(get_parent() as CanvasLayer).transform = z.affine_inverse()


func _draw() -> void:
	var tex := _stage.get_texture()
	var full := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var fade := 1.0 - clampf((_t - T_END) / T_FADE, 0.0, 1.0) if _stage_n >= 2 else 1.0
	var mod := Color(1, 1, 1, fade)
	var ink := _ink_frac()
	if ink <= 0.0:
		draw_texture_rect(tex, full, false, mod)
	else:
		var hole := _panel_rect()
		hole.size.x *= ink
		hole = hole.intersection(full) if hole.intersects(full) else Rect2(hole.position, Vector2.ZERO)
		for r in [Rect2(0, 0, 1280, hole.position.y), Rect2(0, hole.end.y, 1280, 720 - hole.end.y),
				Rect2(0, hole.position.y, hole.position.x, hole.size.y), Rect2(hole.end.x, hole.position.y, 1280 - hole.end.x, hole.size.y)]:
			if r.size.x > 0.0 and r.size.y > 0.0:
				draw_texture_rect_region(tex, r, r, mod)
		if ink < 1.0:  # the wet front of the ink
			var x := hole.end.x
			draw_rect(Rect2(x - 3, hole.position.y, 6, hole.size.y), Color(INK, fade))
			var y := hole.position.y + 8.0
			var i := 0
			while y < hole.end.y - 6.0:
				var l := 5.0 + 12.0 * absf(sin(i * 2.7 + _t * 9.0))
				draw_rect(Rect2(x, y - 2.5, l, 5.0), Color(INK, fade))
				draw_circle(Vector2(x + l, y), 4.0, Color(INK, fade))
				y += 21.0 + 8.0 * absf(sin(i * 1.3))
				i += 1
	if _skip >= 0.0:  # skipping: ink closes over everything
		draw_rect(full, Color(INK, clampf(_skip / 0.3, 0.0, 1.0)))


# ------------------------------------------------------------------ pages

func _paper(c: CanvasItem, size: Vector2, col := PAPER) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, size), col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 260:  # paper fibre and print speckle
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		c.draw_line(p, p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-2, 2)), Color(0.6, 0.55, 0.45, 0.12), 1.0)
	var x := 6.0
	while x < size.x:  # faint halftone
		var y := 6.0
		while y < size.y:
			c.draw_rect(Rect2(x, y, 1.6, 1.6), Color(0.8, 0.74, 0.62, 0.35))
			y += 10.0
		x += 10.0


func _paint_cover(c: Control) -> void:
	var s := Vector2(TEX)
	# night sky, a huge moon, the city skyline, Vesper on a roof
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([Color(0.08, 0.06, 0.2), Color(0.12, 0.07, 0.24), Color(0.62, 0.2, 0.32), Color(0.5, 0.16, 0.3)]))
	for k in 18:  # light rays from the moon
		var a := TAU * k / 18.0
		var d := Vector2.from_angle(a)
		var mc := Vector2(330, 360)
		c.draw_colored_polygon(PackedVector2Array([mc, mc + d * 700 + d.orthogonal() * 60, mc + d * 700 - d.orthogonal() * 60]), Color(1, 0.85, 0.6, 0.06))
	c.draw_circle(Vector2(330, 360), 150, Color(0.98, 0.92, 0.75))
	for i in 9:
		for j in 9:
			var p := Vector2(230 + i * 24, 260 + j * 24)
			if p.distance_to(Vector2(330, 360)) < 140 and (i + j) % 2 == 0:
				c.draw_circle(p, 4.0 + (j % 3), Color(0.92, 0.82, 0.62))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var x := -10.0
	while x < s.x:
		var w := rng.randf_range(44, 90)
		var h := rng.randf_range(120, 300)
		c.draw_rect(Rect2(x, s.y - 150 - h, w, h + 150), Color(0.06, 0.04, 0.12))
		for wy in range(int(s.y - 140 - h), int(s.y - 160), 22):
			for wx in range(int(x + 8), int(x + w - 8), 14):
				if rng.randf() < 0.35:
					c.draw_rect(Rect2(wx, wy, 6, 9), Color(1.0, 0.82, 0.4, 0.85))
		x += w + rng.randf_range(2, 12)
	c.draw_rect(Rect2(0, s.y - 170, s.x, 170), Color(0.04, 0.03, 0.08))  # the roof
	for i in 40:  # halftone over everything
		for j in 60:
			c.draw_circle(Vector2(i * 13 + (j % 2) * 6, j * 13), 1.2, Color(0, 0, 0, 0.12))
	# masthead
	var title := "VESPER"
	var tw := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 150).x
	c.draw_string_outline(FONT, Vector2((s.x - tw) * 0.5 + 8, 172), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, 20, RED)
	c.draw_string_outline(FONT, Vector2((s.x - tw) * 0.5, 164), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, 22, INK)
	c.draw_string(FONT, Vector2((s.x - tw) * 0.5, 164), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color(1.0, 0.62, 0.22))
	c.draw_string(FONT, Vector2((s.x - tw) * 0.5, 150), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color(1.0, 0.86, 0.4, 0.55))
	# issue box
	c.draw_rect(Rect2(14, 14, 74, 92), INK)
	c.draw_rect(Rect2(18, 18, 66, 84), PAPER)
	c.draw_string(FONT, Vector2(26, 52), "No.", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
	c.draw_string(FONT, Vector2(34, 92), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, RED)
	c.draw_string(FONT, Vector2(s.x - 70, 46), "10¢", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PAPER)
	# tagline banner
	var band := Rect2(0, s.y - 92, s.x, 58)
	c.draw_rect(band.grow(4), INK)
	c.draw_rect(band, CAPTION)
	var tag := "A TALE OF LIGHT AND INK!"
	var gw := FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	c.draw_string(FONT, Vector2((s.x - gw) * 0.5, s.y - 50), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, INK)
	c.draw_string(FONT, Vector2(18, s.y - 10), "CD PROJECT BLAXK COMICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.75))
	# worn corners and a crease
	c.draw_line(Vector2(0, 520), Vector2(s.x, 470), Color(1, 1, 1, 0.08), 3.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(s.x, s.y), Vector2(s.x - 26, s.y), Vector2(s.x, s.y - 26)]), Color(0.9, 0.86, 0.76))


func _cover_hero(vp: SubViewport) -> void:
	var hero: Node2D = PlayerArt.new()
	hero.position = Vector2(320, TEX.y - 170)
	hero.scale = Vector2(4.2, 4.2)
	vp.get_child(0).add_child(hero)


func _paint_inside(c: Control) -> void:
	var s := Vector2(TEX)
	_paper(c, s, Color(0.94, 0.9, 0.8))
	c.draw_rect(Rect2(40, 60, s.x - 80, 150), Color(INK, 0.85), false, 3.0)
	c.draw_string(FONT, Vector2(64, 108), "THIS BOOK BELONGS TO:", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, INK)
	c.draw_line(Vector2(64, 176), Vector2(s.x - 64, 176), Color(INK, 0.6), 2.0)
	c.draw_set_transform(Vector2(90, 168), -0.06)
	c.draw_string(HAND, Vector2.ZERO, "Vesper", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, RED)
	c.draw_set_transform(Vector2.ZERO)
	# a coffee ring and a doodle in the margin
	c.draw_arc(Vector2(380, 560), 70, 0, TAU, 48, Color(0.55, 0.35, 0.18, 0.35), 6.0)
	c.draw_arc(Vector2(386, 566), 64, 0.3, 4.4, 40, Color(0.55, 0.35, 0.18, 0.2), 3.0)
	var pts := PackedVector2Array()
	for i in 40:
		var a := i * 0.6
		pts.append(Vector2(140, 520) + Vector2(cos(a), sin(a * 1.3)) * (20.0 + i * 0.9))
	c.draw_polyline(pts, Color(INK, 0.65), 2.5, true)
	c.draw_circle(Vector2(132, 514), 5, PAPER)
	c.draw_circle(Vector2(150, 514), 5, PAPER)
	c.draw_circle(Vector2(132, 514), 2.5, INK)
	c.draw_circle(Vector2(150, 514), 2.5, INK)
	c.draw_string(HAND, Vector2(70, 640), "don't let the Writer", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(INK, 0.6))
	c.draw_string(HAND, Vector2(70, 672), "finish this one...", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(INK, 0.6))


func _paint_sheet(c: Control) -> void:
	var s := Vector2(400, 300)
	_paper(c, s, Color(0.95, 0.94, 0.9))
	for k in 12:  # ruled lines
		c.draw_line(Vector2(0, 30 + k * 22), Vector2(s.x, 30 + k * 22), Color(0.5, 0.65, 0.9, 0.35), 1.0)
	c.draw_line(Vector2(48, 0), Vector2(48, s.y), Color(0.9, 0.35, 0.35, 0.5), 1.5)
	# pencil roughs of Vesper: hat, egg head, scarf
	for k in 3:
		var o := Vector2(100 + k * 100, 150)
		c.draw_arc(o, 26, 0, TAU, 20, Color(PENCIL, 0.8), 1.5)
		c.draw_line(o + Vector2(-34, -24), o + Vector2(34, -26), Color(PENCIL, 0.8), 2.0)
		c.draw_rect(Rect2(o + Vector2(-18, -54), Vector2(36, 28)), Color(PENCIL, 0.8), false, 1.5)
		c.draw_line(o + Vector2(-20, 24), o + Vector2(-50, 40 + k * 6), Color(0.85, 0.3, 0.25, 0.8), 3.0)
		c.draw_line(o + Vector2(0, 26), o + Vector2(0, 90), Color(PENCIL, 0.6), 1.5)
	c.draw_string(HAND, Vector2(70, 270), "scarf: RED. always.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, 0.6))


func _paint_p2(c: Control) -> void:
	var s := Vector2(TEX)
	_paper(c, s)
	c.draw_string(FONT, Vector2(26, 54), "VESPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, RED)
	c.draw_string(FONT, Vector2(150, 54), "CHAPTER ONE: THE CITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	c.draw_string(FONT, Vector2(s.x - 40, s.y - 16), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, 0.6))
	# the first panel: a pencil rough of the City that is about to come to life
	var r := P2_PANEL
	c.draw_rect(r, Color(0.99, 0.97, 0.92))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var x := r.position.x + 6
	while x < r.end.x - 20:
		var w := rng.randf_range(30, 60)
		var h := rng.randf_range(50, 150)
		c.draw_rect(Rect2(x, r.end.y - 70 - h, w, h), Color(PENCIL, 0.5), false, 1.2)
		x += w + rng.randf_range(4, 14)
	c.draw_line(Vector2(r.position.x, r.end.y - 70), Vector2(r.end.x, r.end.y - 70), Color(PENCIL, 0.8), 1.5)
	c.draw_arc(Vector2(r.position.x + 60, r.end.y - 92), 9, 0, TAU, 12, Color(PENCIL, 0.8), 1.5)
	c.draw_line(Vector2(r.position.x + 50, r.end.y - 102), Vector2(r.position.x + 70, r.end.y - 103), Color(PENCIL, 0.8), 2.0)
	c.draw_line(Vector2(r.position.x + 60, r.end.y - 84), Vector2(r.position.x + 60, r.end.y - 70), Color(PENCIL, 0.8), 1.5)
	_border(c, r, 4.0)
	# the rest of the page: roughs, still to be drawn
	for pr in [Rect2(26, 350, 225, 200), Rect2(269, 350, 225, 200), Rect2(26, 568, 468, 180)]:
		c.draw_rect(pr, Color(0.98, 0.96, 0.9))
		for k in 6:
			c.draw_line(pr.position + Vector2(10 + k * 34, pr.size.y - 12), pr.position + Vector2(40 + k * 30, 20 + k * 9), Color(PENCIL, 0.25), 1.0)
		c.draw_rect(pr, Color(PENCIL, 0.6), false, 1.5)


func _border(c: CanvasItem, r: Rect2, w: float, a := 1.0) -> void:
	c.draw_rect(r, Color(INK, a), false, w)


func _paint_p1_static(c: Control) -> void:
	var s := Vector2(TEX)
	_paper(c, s)
	c.draw_string(FONT, Vector2(s.x * 0.5 - 6, s.y - 16), "i", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, 0.5))
	for i in 4:  # where the panels will be: light pencil boxes
		c.draw_rect(P1_PANELS[i], Color(PENCIL, 0.35), false, 1.0)


func _paint_p1_back(c: Node2D) -> void:
	var s := Vector2(TEX)
	# page one showing through the paper, mirrored
	c.draw_set_transform(Vector2(s.x, 0), 0.0, Vector2(-1, 1))
	c.draw_texture(_p1.get_texture(), Vector2.ZERO, Color(1, 1, 1, 0.06))
	c.draw_set_transform(Vector2.ZERO)


## Page one: the captions, typed in.
func _shown(line: int) -> int:
	var t0: float = T_CAP1 if line == 0 else T_CAP2
	var text: String = LINE1 if line == 0 else LINE2
	var cps := 21.0 if line == 0 else 15.0
	return clampi(int((_t - t0) * cps), 0, text.length())


func _paint_p1_captions(c: Node2D) -> void:
	for line in 2:
		var shown := _shown(line)
		var t0: float = T_CAP1 if line == 0 else T_CAP2
		if _t < t0 - 0.2:
			continue
		var a := clampf((_t - t0 + 0.2) / 0.25, 0.0, 1.0)
		var box := Rect2(26, 34, 468, 140) if line == 0 else Rect2(70, 638, 380, 104)
		var px := 46 if line == 0 else 44
		var text: String = LINE1 if line == 0 else LINE2
		var words := ["I JUST HAD THE", "CRAZIEST ADVENTURE..."] if line == 0 else ["BUT NOW...", "LET'S BEGIN."]
		c.draw_set_transform(box.get_center(), -0.02 if line == 0 else 0.025, Vector2(a, a))
		var r := Rect2(-box.size * 0.5, box.size)
		c.draw_rect(Rect2(r.position + Vector2(6, 7), r.size), Color(INK, 0.35))
		c.draw_rect(r.grow(4.0), INK)
		c.draw_rect(r, CAPTION)
		var left := shown
		for k in words.size():
			var wds: String = words[k]
			var part := wds.substr(0, clampi(left, 0, wds.length()))
			left -= wds.length() + 1
			var w := FONT.get_string_size(wds, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			c.draw_string(FONT, Vector2(-w * 0.5, r.position.y + 18 + px * (k + 0.95)), part, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)
		if line == 0 and shown >= text.length():
			c.draw_string(HAND, Vector2(r.end.x - 120, r.end.y - 8), "- Vesper", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(RED, clampf((_t - T_CAP1 - 2.0) * 2.0, 0.0, 1.0)))
		c.draw_set_transform(Vector2.ZERO)


func _build_p1_panels() -> void:
	var root := _p1.get_child(0)
	for i in 4:
		var r: Rect2 = P1_PANELS[i]
		var clip := Control.new()
		clip.position = r.position
		clip.size = r.size
		clip.clip_contents = true
		root.add_child(clip)
		var bg := Node2D.new()
		bg.set_meta("live", true)
		bg.draw.connect(_paint_panel_bg.bind(bg, i))
		clip.add_child(bg)
		var art := []
		match i:
			0:
				var v: Node2D = PlayerArt.new()
				v.position = Vector2(78, 160)
				v.scale = Vector2(1.5, 1.5)
				clip.add_child(v)
				var cr: Node2D = CrawlerArt.new()
				cr.position = Vector2(168, 166)
				cr.scale = Vector2(1.3, 1.3)
				clip.add_child(cr)
				art = [v, cr]
			1:
				var v2: Node2D = PlayerArt.new()
				v2.position = Vector2(60, 132)
				v2.scale = Vector2(1.3, 1.3)
				clip.add_child(v2)
				art = [v2]
			2:
				var v3: Node2D = PlayerArt.new()
				v3.scale = Vector2(0.62, 0.62)
				clip.add_child(v3)
				art = [v3]
		var fx := Node2D.new()
		fx.set_meta("live", true)
		fx.draw.connect(_paint_panel_fx.bind(fx, i))
		clip.add_child(fx)
		var mask := Node2D.new()
		mask.set_meta("live", true)
		mask.draw.connect(_paint_panel_mask.bind(mask, i))
		clip.add_child(mask)
		_p1_nodes.append([clip] + art)
		var frame := Node2D.new()
		frame.set_meta("live", true)
		frame.draw.connect(_paint_panel_frame.bind(frame, i))
		root.add_child(frame)


func _panel_t(i: int) -> float:
	return _t - T_PANELS[i]


func _paint_panel_bg(c: Node2D, i: int) -> void:
	var r: Rect2 = P1_PANELS[i]
	var s := r.size
	var t := _panel_t(i)
	match i:
		0:  # the City: pink and blue towers under a striped sky
			c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]),
				PackedColorArray([Color(0.35, 0.75, 0.95), Color(0.3, 0.6, 0.95), Color(0.98, 0.7, 0.85), Color(0.98, 0.8, 0.8)]))
			for k in 9:
				var a := -0.9 + k * 0.22 + t * 0.05
				c.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.5, s.y * 1.1), Vector2(s.x * 0.5, s.y * 1.1) + Vector2.from_angle(a - PI * 0.5) * 400 + Vector2(12, 0),
					Vector2(s.x * 0.5, s.y * 1.1) + Vector2.from_angle(a - PI * 0.5) * 400 - Vector2(12, 0)]), Color(1, 1, 1, 0.18))
			var cols := [Color(0.95, 0.45, 0.65), Color(0.55, 0.45, 0.85), Color(0.95, 0.6, 0.75), Color(0.4, 0.55, 0.9)]
			for k in 7:
				var h := 60.0 + (k * 37 % 70)
				c.draw_rect(Rect2(k * 34 - 6, s.y - 34 - h, 30, h), cols[k % 4])
				c.draw_rect(Rect2(k * 34 - 6, s.y - 34 - h, 30, h), Color(INK, 0.8), false, 1.5)
			c.draw_rect(Rect2(0, s.y - 34, s.x, 34), Color(0.18, 0.14, 0.26))
		1:  # the light: a sketch bridge over spikes, held up by the Ember
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.09, 0.2))
			var x := 0.0
			while x < s.x:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x, s.y), Vector2(x + 9, s.y - 22), Vector2(x + 18, s.y)]), Color(1.0, 0.86, 0.2))
				c.draw_polyline(PackedVector2Array([Vector2(x, s.y), Vector2(x + 9, s.y - 22), Vector2(x + 18, s.y)]), INK, 1.5)
				x += 18.0
			var ember_x := 50.0 + fmod(t * 34.0, 140.0)
			var by := 152.0
			for k in 12:
				var cx := 6.0 + k * 18.0
				var lit := absf(cx + 9 - ember_x) < 70.0
				var cell := Rect2(cx, by, 17, 9)
				if lit:
					c.draw_rect(cell, Color(1.0, 0.85, 0.45))
					c.draw_rect(cell, INK, false, 1.5)
				else:
					c.draw_rect(cell, Color(0.92, 0.9, 0.84, 0.6), false, 1.0)
		2:  # the Gutter: a tilted stone floor seen from above (the 2.5D world)
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.04))
			var lamp := Vector2(sin(t * 1.1) * 2.4, cos(t * 0.8) * 1.6)
			for gx in range(-5, 6):
				for gy in range(-5, 6):
					var q := [_iso(gx - 0.5, gy - 0.5, s), _iso(gx + 0.5, gy - 0.5, s), _iso(gx + 0.5, gy + 0.5, s), _iso(gx - 0.5, gy + 0.5, s)]
					var d := Vector2(gx, gy).distance_to(lamp)
					var lit := clampf(1.2 - d / 1.6, 0.0, 1.0)
					var base := Color(0.08, 0.16, 0.12) if (gx + gy) % 2 == 0 else Color(0.06, 0.12, 0.1)
					c.draw_colored_polygon(PackedVector2Array(q), base.lerp(Color(0.85, 0.82, 0.55), lit * 0.55))
					c.draw_polyline(PackedVector2Array(q + [q[0]]), Color(0, 0, 0, 0.7), 1.0)
			# glowing runes, the lamp's searching circle
			for k in 3:
				var rp := _iso(-3 + k * 3, 2 - k, s)
				c.draw_arc(rp, 9, 0, TAU, 14, Color(0.4, 0.95, 0.8, 0.7), 2.0)
			var lc := _iso(lamp.x, lamp.y, s)
			c.draw_colored_polygon(_ellipse(lc, 52, 26), Color(1.0, 0.95, 0.7, 0.18))
			c.draw_arc(lc, 52, 0, TAU, 32, Color(1.0, 0.95, 0.7, 0.6), 2.0)
		3:  # the Eraser rubbing the panel out
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.98, 0.96, 0.9))
			for k in 10:
				c.draw_line(Vector2(k * 26, s.y), Vector2(k * 26 + 60, 30), Color(PENCIL, 0.35), 1.0)
			var rub := sin(t * 6.0)
			var ex := 112 + rub * 46
			c.draw_rect(Rect2(ex - 60 - 50, 98, 200 * clampf(t / 1.5, 0.0, 1.0) + 40, 44), Color(0.99, 0.98, 0.95))  # rubbed clean


## The Gutter panel's little perspective (tilted camera over a floor).
func _iso(x: float, y: float, s: Vector2) -> Vector2:
	var depth := 7.0 - y * 0.55
	return Vector2(s.x * 0.5 + x * 150.0 / depth, s.y * 0.62 + y * 70.0 / depth)


func _paint_panel_fx(c: Node2D, i: int) -> void:
	var r: Rect2 = P1_PANELS[i]
	var s := r.size
	var t := _panel_t(i)
	var nodes: Array = _p1_nodes[i] if i < _p1_nodes.size() else []
	match i:
		0:
			var cyc := fmod(maxf(t, 0.0), 1.3) / 1.3
			if cyc < 0.35:  # the slash
				var k := cyc / 0.35
				c.draw_arc(Vector2(98, 136), 46, -1.6 + k * 1.2, -0.2 + k * 1.4, 16, Color(1, 1, 1, 1.0 - k), 10.0)
				c.draw_arc(Vector2(98, 136), 46, -1.6 + k * 1.2, -0.2 + k * 1.4, 16, Color(INK, 0.8 - k * 0.8), 2.0)
			if nodes.size() > 2:
				var cr: Node2D = nodes[2]
				var hit := cyc > 0.18 and cyc < 0.6
				cr.position = Vector2(168 + (10.0 if hit else 0.0), 166)
				cr.rotation = 0.35 if hit else 0.0
			if cyc > 0.18 and cyc < 0.75:
				var k2 := _pop_ease((cyc - 0.18) / 0.2)
				c.draw_set_transform(Vector2(160, 66), -0.15, Vector2(k2, k2))
				c.draw_string_outline(FONT, Vector2(-52, 12), "THWACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 10, INK)
				c.draw_string(FONT, Vector2(-52, 12), "THWACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, CAPTION)
				c.draw_set_transform(Vector2.ZERO)
		1:
			var ember_x := 50.0 + fmod(maxf(t, 0.0) * 34.0, 140.0)
			if nodes.size() > 1:
				var v: Node2D = nodes[1]
				v.position = Vector2(ember_x, 132)
				v.set("velocity", Vector2(34, 0))
			var fp := Vector2(ember_x + 8, 92 + sin(_t * 3.0) * 3.0)
			for k in 4:
				c.draw_circle(fp, 70.0 - k * 16.0, Color(1.0, 0.75, 0.3, 0.08 + k * 0.03))
			c.draw_circle(fp, 6.0, Color(1.0, 0.62, 0.18))
			c.draw_circle(fp, 3.0, Color(1.0, 0.95, 0.7))
		2:
			if nodes.size() > 1:
				var v3: Node2D = nodes[1]
				v3.position = _iso(0.2, 0.4, s) + Vector2(0, -6)
			# darkness at the top (the Gutter is dark)
			c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, 40), Vector2(0, 40)]),
				PackedColorArray([Color(0, 0, 0, 0.9), Color(0, 0, 0, 0.9), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		3:
			var rub := sin(t * 6.0)
			var ex := 112 + rub * 46
			c.draw_set_transform(Vector2(ex, 120), -0.25 + rub * 0.06)
			var body := Rect2(-62, -34, 124, 68)
			c.draw_rect(Rect2(body.position + Vector2(6, 8), body.size), Color(INK, 0.3))
			c.draw_rect(body.grow(3.0), INK)
			c.draw_rect(body, Color(0.96, 0.52, 0.6))
			c.draw_rect(Rect2(body.position, Vector2(body.size.x, 18)), Color(0.4, 0.6, 0.95))
			c.draw_line(Vector2(-34, -2), Vector2(-12, 6), INK, 4.0)  # angry brows
			c.draw_line(Vector2(34, -2), Vector2(12, 6), INK, 4.0)
			c.draw_circle(Vector2(-22, 12), 5, INK)
			c.draw_circle(Vector2(22, 12), 5, INK)
			c.draw_rect(Rect2(-18, 22, 36, 8), INK)
			for k in 4:
				c.draw_rect(Rect2(-16 + k * 9, 22, 6, 4), PAPER)
			c.draw_set_transform(Vector2.ZERO)
			for k in 7:  # crumbs
				var cp := Vector2(ex + sin(_t * 9.0 + k) * 70.0, 160 + fmod(_t * 60.0 + k * 13.0, 40.0))
				c.draw_circle(cp, 2.5, Color(0.9, 0.5, 0.55))
			var k2 := _pop_ease(clampf((t - 0.4) / 0.3, 0.0, 1.0))
			c.draw_set_transform(Vector2(150, 40), 0.12, Vector2(k2, k2))
			c.draw_string_outline(FONT, Vector2(-50, 10), "RRRUB!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 10, INK)
			c.draw_string(FONT, Vector2(-50, 10), "RRRUB!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.96, 0.55, 0.62))
			c.draw_set_transform(Vector2.ZERO)


## Each panel inks itself in: paper with a pencil rough until the ink front passes.
func _paint_panel_mask(c: Node2D, i: int) -> void:
	var r: Rect2 = P1_PANELS[i]
	var s := r.size
	var k := _smoother(clampf(_panel_t(i) / T_PANEL_INK, 0.0, 1.0))
	if k >= 1.0:
		return
	var x := s.x * k
	c.draw_rect(Rect2(x, 0, s.x - x, s.y), Color(0.98, 0.96, 0.9))
	for m in 9:  # the pencil rough under the ink
		var y := 18.0 + m * 21.0
		c.draw_line(Vector2(maxf(x, 8), y), Vector2(s.x - 8, y + sin(m * 1.7) * 8.0), Color(PENCIL, 0.25), 1.0)
	if k > 0.0:
		c.draw_rect(Rect2(x - 3, 0, 6, s.y), INK)
		for m in 8:
			var y2 := 12.0 + m * 26.0
			var l := 6.0 + 10.0 * absf(sin(m * 2.3 + _t * 8.0))
			c.draw_circle(Vector2(x + l, y2), 4.0, INK)
			c.draw_rect(Rect2(x, y2 - 2.5, l, 5), INK)


func _paint_panel_frame(c: Node2D, i: int) -> void:
	var r: Rect2 = P1_PANELS[i]
	var k := clampf(_panel_t(i) / T_PANEL_INK, 0.0, 1.0)
	if k <= 0.0:
		return
	_border(c, r, 4.0, k)
	var tag: String = P1_TAGS[i]
	var tw := FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var box := Rect2(r.position + Vector2(-6, -10), Vector2(tw + 16, 26))
	c.draw_rect(box.grow(2.0), Color(INK, k))
	c.draw_rect(box, Color(CAPTION, k))
	c.draw_string(FONT, box.position + Vector2(8, 20), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, k))


# ------------------------------------------------------------------ sound

func _make_sounds() -> void:
	_sounds = {
		"tick": _wav(_tick()), "thump": _wav(_thump()), "whoosh": _wav(_whoosh(0.9, 400.0, 2400.0)),
		"chime": _wav(_chime()), "scratch": _wav(_scratch()), "type": _wav(_type_click()),
		"flip": _wav(_flip()), "dive": _wav(_whoosh(1.3, 300.0, 5000.0)), "pop": _wav(_pop_snd()),
	}


func _play(snd: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[snd]
	p.volume_db = db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


const RATE := 22050


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tick() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var prev := 0.0
	for i in int(RATE * 0.05):
		var n := randf_range(-1, 1)
		s.append((n - prev) * exp(-i / 90.0) * 0.8 + sin(i * 0.9) * exp(-i / 60.0) * 0.4)
		prev = n
	return s


func _thump() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var ph := 0.0
	for i in int(RATE * 0.45):
		var t := float(i) / RATE
		ph += TAU * lerpf(95.0, 42.0, minf(t / 0.3, 1.0)) / RATE
		s.append(sin(ph) * exp(-t * 9.0) * 0.9 + randf_range(-1, 1) * exp(-t * 60.0) * 0.4)
	return s


func _whoosh(dur: float, f0: float, f1: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var lp := 0.0
	var lp2 := 0.0
	for i in int(RATE * dur):
		var t := float(i) / (RATE * dur)
		var f := lerpf(f0, f1, t * t)
		var a := 1.0 - exp(-TAU * f / RATE)
		lp += (randf_range(-1, 1) - lp) * a
		lp2 += (lp - lp2) * a
		s.append(lp2 * sin(t * PI) * 2.6)
	return s


func _chime() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var notes := [1318.5, 1760.0, 2637.0, 3520.0]
	for i in int(RATE * 1.6):
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var t0 := k * 0.07
			if t > t0:
				v += sin(TAU * notes[k] * (t - t0)) * exp(-(t - t0) * 3.2) * 0.22
		s.append(v)
	return s


func _scratch() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var prev := 0.0
	for i in int(RATE * 0.6):
		var t := float(i) / RATE
		var n := randf_range(-1, 1)
		var amp := (0.5 + 0.5 * sin(t * 70.0)) * sin(minf(t / 0.6, 1.0) * PI)
		s.append((n - prev) * amp * 0.35)
		prev = n
	return s


func _type_click() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	for i in int(RATE * 0.02):
		s.append(randf_range(-1, 1) * exp(-i / 40.0) * 0.6)
	return s


func _pop_snd() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var ph := 0.0
	for i in int(RATE * 0.25):
		var t := float(i) / RATE
		ph += TAU * lerpf(300.0, 90.0, t / 0.25) / RATE
		s.append(sin(ph) * exp(-t * 18.0) * 0.8 + randf_range(-1, 1) * exp(-t * 80.0) * 0.5)
	return s


func _flip() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var lp := 0.0
	var prev := 0.0
	for i in int(RATE * 0.7):
		var t := float(i) / (RATE * 0.7)
		var n := randf_range(-1, 1)
		lp += (n - lp) * 0.35
		var flap := 0.6 + 0.4 * sin(t * 40.0)
		var env := pow(sin(t * PI), 0.6) * (1.0 - t * 0.6)
		s.append(((n - prev) * 0.6 + lp * 0.8) * env * flap * 0.7)
		prev = n
	return s


const WOOD_SHADER := """
shader_type canvas_item;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec2 p = UV * vec2(1.0, 11.0);
	float plank = floor(p.y);
	float seed = h(vec2(plank, 3.7));
	vec2 q = vec2(UV.x * 2.2 + seed * 10.0, fract(p.y));
	float warp = fbm(vec2(q.x * 3.0, q.y * 2.0 + seed * 5.0));
	float grain = fbm(vec2(q.x * 1.5, q.y * 14.0 + warp * 3.0));
	float rings = sin((q.y * 9.0 + warp * 5.0 + q.x * 0.3) * 6.2831);
	vec3 dark = vec3(0.2, 0.1, 0.05);
	vec3 light = vec3(0.47, 0.27, 0.13);
	vec3 col = mix(dark, light, clamp(0.3 + 0.45 * grain + 0.1 * rings + (seed - 0.5) * 0.3, 0.0, 1.0));
	float e = min(fract(p.y), 1.0 - fract(p.y));
	col *= mix(0.35, 1.0, smoothstep(0.0, 0.03, e));
	float stain = smoothstep(0.66, 0.7, fbm(UV * 6.0 + 31.0));
	col = mix(col, vec3(0.04, 0.03, 0.08), stain * 0.6);
	float scratch = smoothstep(0.992, 1.0, sin(UV.x * 1300.0 + fbm(UV * 18.0) * 40.0)) * step(0.68, n(UV * 9.0));
	col += scratch * 0.07;
	COLOR = vec4(col, 1.0);
}
"""
