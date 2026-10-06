extends Control
## The opening, fully animated (about 28 s): a comic book lying on a desk at
## night under a warm lamp, a framed photo of two brothers behind it (one in
## Vesper's hat and red scarf, a black ribbon over the corner). The Writer's
## hand (shade_hand.gd as a puppet, never named here) reaches in and lifts the
## cover; light and sparks pour out, throwing it back, and the cover swings
## open. The camera comes down onto the first page, where Vesper's caption
## types "I JUST HAD THE CRAZIEST ADVENTURE..." while four little panels ink
## themselves in (the City, the light, the Gutter in 2.5D, the Eraser). Then
## the hand comes back with its pen: it reads along the caption, blots out
## CRAZIEST and writes LAST over it, and on the inside of the cover sketches
## what it has in store: the Scribbled Beast (once it has its red eyes its
## lines boil, alive) and THE END beside it, the full stop stabbed in. Vesper's
## "BUT NOW... LET'S BEGIN." types; the hand flicks the page over and the
## camera dives into the first panel of the story, which becomes the live City
## level (scaled into the panel the same way as panel_turn.gd), until it is
## the game's own panel.
##
## It sounds like grief and anger: the game's tune slow and minor (the
## "margins" track) under rain on the window, the lamp's hum and a pen
## scratching that stops; thunder; and while he changes the book a growl, a
## heartbeat that hardens and a bell tolled for the dead. Vesper's own music
## only comes when the City does. The desk is the Writer's: the photo and a
## candle burning by it, his brother's red scarf, the ending he tore in two
## ("AND VESPER CAME HOME."), drafts in balls, a snapped pencil, a pile of
## earlier issues, a pocket watch, the window's cold light with rain on it. Ink flies out of the bursting book and off the
## pen and stays on the desk. Page one's panels have a far layer each and the
## Eraser breaks out of its border; page two's lower panels are pencil roughs
## of what is to come (the Sketchbook, the Long Drop, the Beast); and the
## camera holds a beat on the pencil city, its stick Vesper blinking, before
## the ink sweeps across it.
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
const EraserArt = preload("res://scripts/enemies/eraser_art.gd")
const CrawlerArt = preload("res://scripts/enemies/crawler_visual.gd")
const ShadeHand = preload("res://scripts/effects/shade_hand.gd")
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
const CANDLE := Vector3(-140, 400, 0)  # the candle burning by the photo (world)
## The window's cold light across the near right of the desk: a corner of it
## (world) and the two sides of one of its four panes.
const WINDOW := Vector3(470, -560, 0.5)
const PANE_X := Vector3(196, 44, 0)
const PANE_Y := Vector3(-70, 250, 0)
## Lightning (seconds; the second is set to the moment he stabs the full stop in).
const T_FLASH := 0.35
const SHADOW := Vector3(0.55, -0.3, -1.0)  # light direction for shadows (book space)

## The Writer's hand reaches in (it lifts the cover at T_OPEN).
const T_HAND := 1.2
const T_OPEN := Vector2(3.3, 5.7)
const T_CAP1 := 6.4
const T_PANELS := [7.5, 8.4, 9.3, 10.2]
const T_PANEL_INK := 0.75
## The hand comes back with its pen (the jobs in _build_jobs() follow).
const T_EDIT := 10.9
const T_CAP2 := 18.6
const T_TURN := Vector2(20.3, 22.3)
const T_TOP := 23.5
const T_LOAD := 23.55
## (Between T_TOP and T_INK the camera holds on the pencil city: its stick
## Vesper blinks, waiting to be inked.)
const T_INK := Vector2(24.6, 25.2)
const T_END := 27.2
const T_FADE := 0.4
const SETTLE_FRAMES := 3

const LINE1 := "I JUST HAD THE CRAZIEST ADVENTURE..."
const LINE2 := "BUT NOW... LET'S BEGIN."
## Page one's first caption (page pixels), its two lines, and the word of it
## the Writer blots out and writes his own over.
const CAP1_BOX := Rect2(26, 34, 468, 140)
const CAP1_WORDS := ["I JUST HAD THE", "CRAZIEST ADVENTURE..."]
const CAP1_PX := 46
const STRUCK := "CRAZIEST"
## The Writer's ink: black, his letters and his monsters' eyes blood red.
const BLOOD := Color(0.96, 0.13, 0.16)
## His hand: world units per pixel of its art, its turn (the arm comes in
## from the near right of the desk), the way it leaves, along the forearm,
## and where its wrist is (shade_hand.gd's art, from the nib).
const HAND_SIZE := 0.72
const HAND_TURN := 1.2
const HAND_OUT := Vector2(0.78, 0.63)
const WRIST := Vector2(240, -147)
## The nib taps the cover twice before it hooks the corner (seconds from T_OPEN).
const TAPS := [-0.64, -0.44]
## Between two strokes the pen is in the air, and quicker: what a pixel of
## that costs next to a pixel of ink.
const HOP := 0.5
## How hard the nib presses along a stroke: [from, to (shares of its length),
## share of the line's width]. It lands light, bears down, lifts light.
const NIB := [[0.0, 0.1, 0.5], [0.1, 0.22, 0.78], [0.22, 0.8, 1.0], [0.8, 0.92, 0.78], [0.92, 1.0, 0.5]]
## His capitals: pen strokes in a 24 x 30 cell.
const GLYPHS := {
	"L": [[Vector2(3, 0), Vector2(2, 30), Vector2(21, 29)]],
	"A": [[Vector2(0, 30), Vector2(12, 0), Vector2(24, 30)], [Vector2(5, 19), Vector2(19, 18)]],
	"S": [[Vector2(21, 5), Vector2(14, 0), Vector2(6, 2), Vector2(3, 8), Vector2(7, 14), Vector2(16, 17), Vector2(21, 23),
		Vector2(17, 29), Vector2(8, 30), Vector2(2, 25)]],
	"T": [[Vector2(0, 1), Vector2(24, 0)], [Vector2(12, 1), Vector2(11, 30)]],
	"H": [[Vector2(3, 0), Vector2(2, 30)], [Vector2(21, 0), Vector2(22, 30)], [Vector2(2, 15), Vector2(22, 14)]],
	"E": [[Vector2(21, 1), Vector2(3, 0), Vector2(2, 30), Vector2(21, 29)], [Vector2(3, 15), Vector2(17, 14)]],
	"N": [[Vector2(2, 30), Vector2(3, 0), Vector2(21, 30), Vector2(22, 0)]],
	"D": [[Vector2(3, 0), Vector2(2, 30), Vector2(12, 29), Vector2(20, 23), Vector2(22, 12), Vector2(15, 2), Vector2(3, 0)]],
}
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
	[11.3, Vector3(130, 4, THICK), 640.0, 81.0, 0.6, 0.0],
	[13.7, Vector3(126, 8, THICK), 628.0, 81.0, 0.6, 0.0],  # leaning in over the caption as he changes it
	# back to see both pages while he sketches on the inside of the cover
	[14.7, Vector3(14, -6, THICK), 720.0, 80.0, -0.8, 0.0],
	[18.4, Vector3(20, -8, THICK), 700.0, 81.0, 0.0, 0.0],
	[19.9, Vector3(130, -6, THICK), 612.0, 83.0, 1.5, 0.0],
	[21.9, Vector3(70, 30, THICK), 880.0, 74.0, 0.0, 0.0],
	[23.5, Vector3(130, 94, THICK), 414.0, 90.0, 0.0, 0.0],
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
var _photo: SubViewport
var _draft: SubViewport
var _p1_nodes: Array = []   # per panel: [clip Control, art nodes...]

# the Writer
var _hand: Node2D
var _hand_shadow: Node2D
var _hand_in := 0.0   # 0 out of frame .. 1 at its work
var _wrist := Vector2.ZERO  # where its wrist is on screen: it trails the nib
var _lamp := 1.0      # the lamp's strength: it dips and flickers while his hand is over the desk
var _jobs: Array = [] # his pen work, in order (_build_jobs())
var _pen_up := 0.0    # 0 nib on the paper .. 1 lifted
var _pen_job := -1    # the job and the stroke being inked right now (-1 = none)
var _pen_stroke := -1
var _pen_key := -1    # (the stroke the last scratch was for)
var _scratch_t := 0.0
var _read_from := Vector2.ZERO  # where the nib starts reading Vesper's caption (page pixels)
var _blot_t := Vector2.ZERO     # when it blots the word out, and for how long (the page shudders)
var _stab_t := 0.0              # when it stabs the full stop in
var _splats: Array = []         # ink that flew, where it landed on the desk: [world point, size, the way it was going]
var _rain: AudioStreamPlayer    # the room: rain on the window, the lamp's hum
var _hum: AudioStreamPlayer

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
	_build_jobs()
	_inside = _make_vp(TEX, _paint_inside, true)
	_inside.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # the Writer sketches on it
	var sketch := Node2D.new()
	sketch.set_meta("live", true)
	sketch.draw.connect(_paint_ink.bind(sketch, "in"))
	_inside.get_child(0).add_child(sketch)
	_sheet = _make_vp(Vector2i(400, 300), _paint_sheet, true)
	_draft = _make_vp(Vector2i(420, 300), _paint_draft, true)
	_photo = _make_vp(Vector2i(300, 380), _paint_photo, true)
	_photo_brother(_photo)
	_p2 = _make_vp(TEX, _paint_p2, true)
	_p2.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # its pencil Vesper blinks
	var waiting := Node2D.new()
	waiting.set_meta("live", true)
	waiting.draw.connect(_paint_p2_live.bind(waiting))
	_p2.get_child(0).add_child(waiting)
	_p1 = _make_vp(TEX, _paint_p1_static, true)
	_p1.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # its panels and captions move
	_build_p1_panels()
	var cap := Node2D.new()
	cap.draw.connect(_paint_p1_captions.bind(cap))
	cap.set_meta("live", true)
	_p1.get_child(0).add_child(cap)
	var ink := Node2D.new()
	ink.set_meta("live", true)
	ink.draw.connect(_paint_ink.bind(ink, "p1"))
	_p1.get_child(0).add_child(ink)
	_p1b =_make_vp(TEX, func(c: Control): _paper(c, Vector2(TEX), Color(0.93, 0.9, 0.81)), true)
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
	_hand_shadow = Node2D.new()
	_hand_shadow.draw.connect(_draw_hand_shadow)
	_hand_shadow.visible = false
	_stage.add_child(_hand_shadow)
	_hand = ShadeHand.new()
	_hand.puppet = true
	_hand.puppet_turn = HAND_TURN
	_hand.drips = false
	_hand.aura = false  # (its shadow is _draw_hand_shadow())
	_hand.visible = false
	_stage.add_child(_hand)
	_hand.z_index = 0  # under the lamp's glow and the vignette (shade_hand.gd sets 40)
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
	_rain = _room_sound("rain")
	_hum = _room_sound("hum")


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
func _cover_angle(at := -1.0) -> float:
	var x := clampf(((_t if at < 0.0 else at) - T_OPEN.x) / (T_OPEN.y - T_OPEN.x), 0.0, 1.0)
	var e := _smoother(x)
	var settle := sin(clampf((x - 0.82) / 0.18, 0.0, 1.0) * PI) * 0.035
	return PI * minf(e + settle, 1.0)


## (Flicked over: it leaves the hand quicker than it would lift by itself.)
func _turn() -> float:
	return _smoother(pow(_k(T_TURN.x, T_TURN.y - T_TURN.x), 0.8))


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
		+ 3.0 * exp(-maxf(_t - T_TURN.x - 0.2, 0.0) * 6.0) * float(_t > T_TURN.x + 0.2) \
		+ 1.3 * float(_t > _blot_t.x and _t < _blot_t.x + _blot_t.y) \
		+ 6.0 * exp(-maxf(_t - _stab_t, 0.0) * 8.0) * float(_t > _stab_t)
	_shake = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * kick if _t < T_TOP else Vector2.ZERO
	_update_writer(delta)
	_update_room()
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
	for vp in [_p1, _p1b, _inside, _p2]:
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
	# his grief: the game's tune, minor, slow and far away (the menu's; it
	# stays until the City loads and its LevelMusic brings Vesper's own in)
	_once("grief", func():
		var music := get_node_or_null("/root/Music")
		if music:
			music.play("margins", 2.0))
	# a storm outside: lightning (_lightning()), the thunder a moment behind it
	_once_at(T_FLASH + 0.7, "thunder", func(): _play("thunder", -10.0, 0.85))
	_once_at(_stab_t + 0.12, "thunder2", func(): _play("thunder", -4.0, 1.15))
	# his anger, while he changes the book: a growl as he blots the word out,
	# a heart that beats harder up to the full stop, a bell for the dead when
	# LAST is written and when THE END is
	_once_at(_blot_t.x, "growl", func(): _play("growl", -7.0))
	_once_at(T_EDIT + 4.0, "dread2", func(): _play("dread", -8.0, 0.9))
	var beat := 0
	var at := T_EDIT + 0.5
	while at < _stab_t - 0.3:
		var loud := -15.0 + 5.0 * (at - T_EDIT) / (_stab_t - T_EDIT)
		_once_at(at, "lub%d" % beat, func(): _play("thump", loud, 0.55))
		_once_at(at + 0.2, "dub%d" % beat, func(): _play("thump", loud - 4.0, 0.48))
		beat += 1
		at += lerpf(0.95, 0.7, (at - T_EDIT) / (_stab_t - T_EDIT))
	_once_at(_jobs[1].t0 + _jobs[1].dur, "toll", func(): _play("toll", -8.0))
	_once_at(_stab_t + 0.05, "toll2", func(): _play("toll", -6.0, 0.84))
	# somebody is writing, close by; then the pen stops
	for i in 3:
		_once_at(0.15 + i * 0.36, "writing%d" % i, func(): _play("scratch", -15.0 + i * 1.5, [1.15, 0.92, 1.3][i]))
	for i in 4:
		var tick := 0.4 + i * 0.85
		if _t >= tick:
			_once("tick%d" % i, func(): _play("tick", -14.0 + i * 1.5))
	_once_at(T_OPEN.x - 0.05, "creak", func(): _play("thump", -6.0))
	_once_at(T_OPEN.x + 0.35, "whoosh", func():
		_play("whoosh", -4.0)
		_word("WHOOSH!", Vector2(900, 210), 92, GOLD, -0.12))
	_once_at(T_OPEN.y - 0.25, "land", func():
		_play("thump", -10.0)
		_play("lament", -10.0))
	for i in 4:
		_once_at(T_PANELS[i], "scratch%d" % i, func(): _play("scratch", -12.0))
	_once_at(T_PANELS[0] + T_PANEL_INK * 0.6, "thwack", func(): _play("pop", -10.0))
	_once_at(T_TURN.x, "flip", func():
		_play("flip", -3.0)
		_word("FLIP!", Vector2(1010, 300), 74, CAPTION, 0.1))
	# the Writer's hand: the nib taps the cover; later, his pen at work (its
	# scratching is played stroke by stroke in _update_writer())
	for i in TAPS.size():
		_once_at(T_OPEN.x + TAPS[i], "tap%d" % i, func(): _play("tick", -6.0, 0.6 + i * 0.08))
	_once_at(T_OPEN.x + 0.34, "spatter", _spatter)
	_once_at(T_EDIT, "dread", func(): _play("dread", -7.0))
	_once_at(_stab_t, "stab", func(): _play("thump", -5.0))
	_once_at(_jobs[0].t0 + 0.1, "skritch", func(): _word("SKRITCH!", Vector2(330, 118), 58, BLOOD, -0.08))
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
	return (0.12 + 1.05 / (1.0 + pow(d / 620.0, 2.4))) * _lamp


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


# ------------------------------------------------------------- the Writer

## One pen job: ink strokes on a page (page pixels; "p1" = page one, "in" =
## the inside of the cover), drawn from `t0` over `dur` seconds. The nib
## follows the wet end of the line and hops, lifted, from one stroke to the
## next. `snd` is what a stroke sounds like.
func _job(page: String, t0: float, dur: float, strokes: Array, width: float, col: Color, snd := "scratch", pitch := 1.0) -> Dictionary:
	var lens := PackedFloat32Array()
	var starts := PackedFloat32Array()  # how far into the job each stroke begins (ink + hops)
	var cost := 0.0
	for si in strokes.size():
		var st: PackedVector2Array = strokes[si]
		if si > 0:
			var before: PackedVector2Array = strokes[si - 1]
			cost += before[before.size() - 1].distance_to(st[0]) * HOP
		starts.append(cost)
		var l := 0.0
		for i in st.size() - 1:
			l += st[i].distance_to(st[i + 1])
		lens.append(l)
		cost += l
	var job := {"page": page, "t0": t0, "dur": dur, "strokes": strokes, "lens": lens, "starts": starts, "cost": cost,
		"width": width, "col": col, "snd": snd, "pitch": pitch}
	_jobs.append(job)
	return job


## How far into a job the pen is right now (see `starts`).
func _job_at(job: Dictionary) -> float:
	return job.cost * clampf((_t - job.t0) / job.dur, 0.0, 1.0)


## A scribbled loop round `c`: `turns` times round a wobbling ellipse.
func _loop(c: Vector2, rx: float, ry: float, turns: float, rng: RandomNumberGenerator, wobble := 0.13) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := rng.randf() * TAU
	for i in int(turns * 16.0) + 1:
		var a := a0 + TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * (1.0 + rng.randf_range(-wobble, wobble)))
	return pts


## A zigzag from `a` to `b`, `n` strokes swinging `amp` either side.
func _zigzag(a: Vector2, b: Vector2, n: int, amp: float, rng: RandomNumberGenerator, jitter := 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var side := (b - a).orthogonal().normalized()
	for i in n + 1:
		pts.append(a.lerp(b, float(i) / n) + side * (amp if i % 2 == 0 else -amp)
			+ Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	return pts


## `text` in his capitals (GLYPHS), as pen strokes: `size` times the cell,
## slanted, from `at` (the top left, in `xf`'s space).
func _write(text: String, at: Vector2, size: float, xf: Transform2D, rng: RandomNumberGenerator) -> Array:
	var out := []
	for ci in text.length():
		for st: Array in GLYPHS.get(text[ci], []):
			var pts := PackedVector2Array()
			for p: Vector2 in st:
				var q := Vector2(ci * 33.0 + p.x - (p.y - 15.0) * 0.14, p.y)
				pts.append(xf * (at + (q + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))) * size))
			out.append(pts)
	return out


## Everything the Writer's pen does, in order, from T_EDIT.
func _build_jobs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var t := T_EDIT + 1.2
	# Vesper's caption: he reads along its second line (_pen_state()), then
	# CRAZIEST is blotted out into a black bar...
	var cap := Transform2D(-0.02, CAP1_BOX.get_center())  # as _paint_p1_captions() draws it
	var line_w := FONT.get_string_size(CAP1_WORDS[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CAP1_PX).x
	var word_w := FONT.get_string_size(STRUCK, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP1_PX).x
	var base := -CAP1_BOX.size.y * 0.5 + 18.0 + CAP1_PX * 1.95  # the second line's baseline
	var bar := Rect2(-line_w * 0.5 - 7.0, base - CAP1_PX * 0.8, word_w + 13.0, CAP1_PX * 0.92)
	var mid := bar.get_center()
	_read_from = cap * Vector2(line_w * 0.5 + 2.0, base + 6.0)
	_blot_t = Vector2(t, 0.7)
	var blot := _job("p1", t, 0.7, [
		cap * _zigzag(Vector2(bar.position.x, mid.y), Vector2(bar.end.x, mid.y), 13, bar.size.y * 0.5 - 4.0, rng),
		cap * _zigzag(Vector2(bar.end.x, mid.y), Vector2(bar.position.x, mid.y), 5, 5.0, rng)], 10.0, INK, "scratch", 0.7)
	var edge := PackedVector2Array()
	for i in 9:
		edge.append(cap * Vector2(lerpf(bar.position.x, bar.end.x, i / 8.0), bar.position.y + rng.randf_range(-2.5, 2.5)))
	for i in 9:
		edge.append(cap * Vector2(lerpf(bar.end.x, bar.position.x, i / 8.0), bar.end.y + rng.randf_range(-2.5, 2.5)))
	blot["bar"] = edge
	t += 0.7 + 0.15
	# ...and LAST written over it, in his red
	_job("p1", t, 0.9, _write("LAST", mid - Vector2(33.0 * 4.0 - 9.0, 30.0) * 0.5, 1.0, cap, rng), 5.0, BLOOD, "scratch", 1.25)
	t += 0.9 + 0.9  # across to the inside of the cover, where it hangs a moment, thinking
	# there: the Scribbled Beast as he means to draw it (two heads, long clawed arms, spindly legs)
	var o := Vector2(170, 338)
	var beast := [_loop(o + Vector2(-46, -66), 31, 28, 2.6, rng, 0.2), _loop(o + Vector2(40, -74), 29, 27, 2.6, rng, 0.2),
		_zigzag(o + Vector2(-70, -54), o + Vector2(-24, -52), 7, 7.0, rng, 1.0),
		_zigzag(o + Vector2(18, -62), o + Vector2(62, -60), 7, 7.0, rng, 1.0),
		_loop(o + Vector2(0, 14), 58, 64, 3.3, rng, 0.2),
		_zigzag(o + Vector2(-44, 44), o + Vector2(40, -18), 9, 30.0, rng, 5.0)]  # hatched in, hard
	for sx: float in [-1.0, 1.0]:
		var hand := o + Vector2(sx * 106, 90)
		for pass_n in 2:  # gone over twice
			var arm := PackedVector2Array([o + Vector2(sx * 52, -4), o + Vector2(sx * 94, 20), o + Vector2(sx * 114, 62), hand])
			var leg := PackedVector2Array([o + Vector2(sx * 24, 72), o + Vector2(sx * 31, 112), o + Vector2(sx * 50, 118)])
			for pts: PackedVector2Array in [arm, leg]:
				for i in pts.size():
					pts[i] += Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)) * pass_n
				beast.append(pts)
		for d: Vector2 in [Vector2(-16, 18), Vector2(0, 24), Vector2(16, 18)]:
			beast.append(PackedVector2Array([hand, hand + d]))
	var body := _job("in", t, 1.85, beast, 3.6, Color(INK, 0.95), "scratch", 0.9)
	body["think"] = 0.38
	t += 1.85 + 0.1
	# its eyes, stabbed in (four, and the one in its chest): with them it is
	# alive, and its lines boil like a monster's in the game
	var eyes := []
	for e: Vector2 in [Vector2(-56, -74), Vector2(-37, -76), Vector2(31, -82), Vector2(50, -80)]:
		eyes.append(_loop(o + e, 3.0, 3.0, 1.2, rng, 0.05))
	eyes.append(_loop(o + Vector2(0, 8), 6.5, 6.5, 1.6, rng, 0.05))
	var looks := _job("in", t, 0.45, eyes, 4.5, BLOOD, "pop", 1.5)
	looks["glow"] = true
	looks["boil"] = t + 0.45
	body["boil"] = t + 0.45
	t += 0.45 + 0.15
	# beside it, how the book ends, underlined twice...
	var stamp := Transform2D(-0.07, Vector2(322, 300))
	var end := _write("THE", Vector2.ZERO, 1.2, stamp, rng) + _write("END", Vector2(0, 46), 1.2, stamp, rng)
	end.append(stamp * PackedVector2Array([Vector2(-6, 94), Vector2(112, 92)]))
	end.append(stamp * PackedVector2Array([Vector2(110, 102), Vector2(-4, 104)]))
	_job("in", t, 0.9, end, 4.2, BLOOD, "scratch", 1.2)
	t += 0.9 + 0.22
	# ...and a full stop, stabbed in so hard the ink bursts
	var dot := stamp * Vector2(130, 80)
	var burst := [_loop(dot, 3.5, 3.5, 1.5, rng, 0.1)]
	for i in 9:
		var d := Vector2.from_angle(TAU * i / 9.0 + rng.randf_range(-0.25, 0.25))
		burst.append(PackedVector2Array([dot + d * 4.0, dot + d * rng.randf_range(10.0, 24.0)]))
	_stab_t = t
	_job("in", t, 0.09, burst, 5.0, BLOOD, "pop", 0.7)["hold"] = dot


## His ink on a page, as far as the pen has got.
func _paint_ink(c: Node2D, page: String) -> void:
	var frame := int(_t * 12.0)
	for ji in _jobs.size():
		var job: Dictionary = _jobs[ji]
		if job.page != page or _t < job.t0:
			continue
		if job.has("bar"):
			c.draw_colored_polygon(job.bar, Color(INK, smoothstep(0.3, 1.0, (_t - job.t0) / job.dur)))
		var at := _job_at(job)
		# a finished monster's lines boil (redrawn 12 times a second, as in the game)
		var boil: float = 1.7 * _k(job.boil, 0.3) if job.has("boil") else 0.0
		for si in job.strokes.size():
			var drawn: float = at - job.starts[si]
			if drawn <= 0.0:
				break
			var st: PackedVector2Array = job.strokes[si]
			if boil > 0.0:
				st = st.duplicate()
				for i in st.size():
					st[i] += _hash2(ji * 7919 + si * 131 + i + frame * 977) * boil
			if job.has("glow"):  # an eye burns
				var mid := Vector2.ZERO
				for q in st:
					mid += q
				mid /= st.size()
				c.draw_circle(mid, 5.0 + job.lens[si] * 0.22, Color(BLOOD, 0.2 + 0.09 * sin(_t * 7.0 + si * 1.9)))
			_stroke(c, st, drawn, job.lens[si], job.width, job.col)


## One stroke as far as it is drawn (`drawn` of its `full` pixels), pressed
## as NIB says, and still wet and shining just behind the nib.
func _stroke(c: Node2D, pts: PackedVector2Array, drawn: float, full: float, width: float, col: Color) -> void:
	var bands: Array = NIB if full > 36.0 else [[0.0, 1.0, 1.0]]  # (a short one is one touch)
	var tip := pts[0]
	for band: Array in bands:
		if drawn <= band[0] * full:
			break
		var part := _slice(pts, band[0] * full, minf(drawn, band[1] * full))
		if part.size() < 2:
			continue
		var w: float = width * band[2]
		c.draw_polyline(part, col, w, true)
		c.draw_circle(part[0], w * 0.5, col)
		tip = part[part.size() - 1]
		c.draw_circle(tip, w * 0.5, col)
	if drawn < full:
		var wet := _slice(pts, maxf(drawn - 44.0, 0.0), drawn)
		if wet.size() >= 2:
			c.draw_polyline(wet, Color(1, 1, 1, 0.3), maxf(width * 0.3, 1.2), true)
		c.draw_circle(tip, width * 0.62, col)  # the bead of ink at the nib


## The piece of a polyline between `a` and `b` pixels along it.
func _slice(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var at := 0.0
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		var lo := maxf(a, at)
		var hi := minf(b, at + d)
		if hi > lo:
			if out.is_empty():
				out.append(pts[i].lerp(pts[i + 1], (lo - at) / d))
			out.append(pts[i].lerp(pts[i + 1], (hi - at) / d))
		at += d
		if at >= b:
			break
	return out


## A steady little random offset for `n` (-1 .. 1 each way).
func _hash2(n: int) -> Vector2:
	return Vector2(fposmod(sin(n * 12.9898) * 43758.5453, 1.0), fposmod(sin(n * 78.233) * 24634.6345, 1.0)) * 2.0 - Vector2.ONE


## The first `length` pixels of a polyline (all of it, if it is shorter).
func _cut(pts: PackedVector2Array, length: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		if d >= length:
			out.append(pts[i].lerp(pts[i + 1], length / maxf(d, 0.001)))
			return out
		out.append(pts[i + 1])
		length -= d
	return out


## A point of a page (page pixels) in book space.
func _page_point(page: String, p: Vector2) -> Vector3:
	if page == "in":  # the open cover lies to the left of the spine
		return Vector3(p.x * 0.5 - BW, BH * 0.5 - p.y * 0.5, 1.6)
	return Vector3(p.x * 0.5, BH * 0.5 - p.y * 0.5, THICK + 0.6)


## The pen once its work has begun: [the nib in book space, 0 on the paper ..
## 1 lifted]. On the wet end of the line being drawn (then _pen_job and
## _pen_stroke say which), or in the air: reading, thinking, or on its way to
## the next line.
func _pen_state() -> Array:
	_pen_job = -1
	_pen_stroke = -1
	var from := Vector3.ZERO
	var from_t := T_EDIT
	for i in _jobs.size():
		var job: Dictionary = _jobs[i]
		if _t < job.t0:
			var first := _page_point(job.page, job.strokes[0][0])
			if i == 0:
				# the nib runs back along Vesper's line as he reads it, stops over
				# the word, and comes down on it
				var read := _ease((_t - T_EDIT - 0.6) / maxf(job.t0 - 0.3 - T_EDIT - 0.6, 0.01))
				return [_page_point(job.page, _read_from).lerp(first, read), 0.75 * (1.0 - _ease((_t - job.t0 + 0.12) / 0.12))]
			var think: float = job.get("think", 0.0)
			var k := _ease((_t - from_t) / maxf(job.t0 - think - from_t, 0.01))
			if think <= 0.0:
				return [from.lerp(first, k), sin(k * PI)]
			# it gets there and hangs over the paper, circling, before it starts
			var h := clampf((_t - job.t0 + think) / think, 0.0, 1.0)
			var round_it := Vector3(cos(h * TAU * 1.5), sin(h * TAU * 1.5), 0.0) * 6.0 * sin(h * PI)
			return [from.lerp(first, k) + round_it, sin(k * PI * 0.5) * (1.0 - _ease((h - 0.75) / 0.25)) * 0.85]
		if _t <= job.t0 + job.dur:
			if job.has("hold"):  # a stab: the nib stays where it struck
				_pen_job = i
				_pen_stroke = 0
				return [_page_point(job.page, job.hold), 0.0]
			var at := _job_at(job)
			for si in job.strokes.size():
				var st: PackedVector2Array = job.strokes[si]
				if at < job.starts[si]:  # hopping over to this stroke
					var before: PackedVector2Array = job.strokes[si - 1]
					var a := before[before.size() - 1]
					var h0: float = job.starts[si - 1] + job.lens[si - 1]
					var hop := _ease((at - h0) / maxf(job.starts[si] - h0, 0.001))
					return [_page_point(job.page, a.lerp(st[0], hop)), sin(hop * PI) * minf(a.distance_to(st[0]) / 40.0, 1.0) * 0.8]
				if at <= job.starts[si] + job.lens[si] or si == job.strokes.size() - 1:
					_pen_job = i
					_pen_stroke = si
					var part := _cut(st, at - job.starts[si])
					return [_page_point(job.page, part[part.size() - 1]), 0.0]
		if job.has("hold"):
			from = _page_point(job.page, job.hold)
		else:
			var last: PackedVector2Array = job.strokes[job.strokes.size() - 1]
			from = _page_point(job.page, last[last.size() - 1])
		from_t = job.t0 + job.dur
	return [from, 0.0]


## The corner of the cover he lifts (at time `at`), and the edge of page one
## he flicks over (world).
func _cover_corner(at: float) -> Vector3:
	return _turn_grid(_cover_angle(at) / PI, THICK + 1.0, 1.2, 0.18, 18, 8)[18][6]


func _page_edge() -> Vector3:
	return _turn_grid(_turn(), THICK + 0.2, 2.0, 0.75)[22][6]


## Ease out with a little overshoot: an arriving hand settles back.
func _back(x: float) -> float:
	x = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + x * x * (1.8 * x + 0.8)


## Ink flung off the pen as the light throws the hand back: drops that fly
## out over the desk and stay where they land (_splats).
func _spatter() -> void:
	var w := _cover_corner(T_OPEN.x + 0.34)
	var from := Vector3(w.dot(_bx), w.dot(_by), w.z + 14.0)  # (book space, as the sparks are)
	for i in 16:
		var v := Vector3(randf_range(150, 520), randf_range(-380, 40), randf_range(120, 330))
		_sparks.append([from, v, 2.5, 2.5, 1, randf_range(1.4, 3.6)])


## The Writer's hand, its pen's sounds and the lamp it dims.
func _update_writer(delta: float) -> void:
	var goal := Vector3.ZERO   # where the nib is, world
	var reach := 0.0           # 0 out of frame .. 1 there
	var up := 0.0              # 0 nib down .. 1 lifted
	var flex := 0.5            # finger curl
	var shove := Vector2.ZERO  # thrown about (screen)
	var lit := 0.0             # the book's light on it
	_pen_job = -1
	var done: float = _jobs[-1].t0 + _jobs[-1].dur
	if _t < T_EDIT:
		# it comes in over the cover, fingers drumming, taps it twice with the
		# nib and hooks the corner up; the light that pours out throws it back
		var burst := T_OPEN.x + 0.34
		reach = _back((_t - T_HAND) / (T_OPEN.x - 0.85 - T_HAND))
		goal = _cover_corner(minf(_t, burst))
		up = 1.0 - _ease((_t - T_OPEN.x + 0.24) / 0.16)
		for tap: float in TAPS:
			up = minf(up, absf(_t - T_OPEN.x - tap) / 0.09)
		flex = 0.6 + 0.3 * (1.0 - up) + 0.14 * sin(_t * 17.0) * up
		if _t > burst:
			var jerk := _ease((_t - burst) / 0.12)
			var leave := _ease((_t - burst - 0.45) / 0.4)
			shove = (HAND_OUT * 180.0 + Vector2(0, -50)) * jerk + Vector2(sin(_t * 71.0), cos(_t * 83.0)) * 5.0 * jerk * (1.0 - leave)
			reach = 1.0 - leave
			up = jerk
			flex = -0.35  # fingers thrown open
			lit = jerk * (1.0 - leave)
	elif _t < done:
		reach = _back((_t - T_EDIT) / 0.6)
		var pen := _pen_state()
		goal = _bk(pen[0])
		up = pen[1]
		flex = 0.55 if _pen_job < 0 else 0.86 + 0.08 * sin(_t * 41.0)
	else:
		# the nib stays pressed where it stabbed, then it goes over to the edge
		# of page one, drums its fingers there, flicks the page over and is gone
		var k := _ease((_t - done - 0.28) / 0.75)
		var hook := _k(T_TURN.x - 0.2, 0.2)
		var leave := _ease((_t - T_TURN.x - 0.46) / 0.45)
		goal = _bk(_pen_state()[0]).lerp(_page_edge(), k)
		up = maxf(sin(k * PI), 0.4 * k * (1.0 - hook))
		reach = 1.0 - leave
		shove = Vector2(-30, -70) * sin(leave * PI)  # it follows the flick through
		flex = 0.5 + 0.4 * hook - 0.7 * leave + 0.16 * sin(_t * 15.0) * floorf(k) * (1.0 - hook)
		if k <= 0.0:
			flex = 1.0
	# the pen on the paper: a scratch for each stroke (and on through the long ones), a stab for an eye
	if _pen_job >= 0:
		var job: Dictionary = _jobs[_pen_job]
		var key := _pen_job * 1000 + _pen_stroke
		var fresh := key != _pen_key
		_pen_key = key
		_scratch_t -= delta
		if _scratch_t <= 0.0 or (fresh and (job.snd != "scratch" or _scratch_t < 0.16)):
			_play(job.snd, -8.0, job.pitch * randf_range(0.85, 1.05))
			_scratch_t = 0.3
	else:
		_pen_key = -1
	var seen := reach > 0.002
	var s := HAND_SIZE * FOCAL / maxf((goal - _cam).dot(_cf), 1.0) * (1.0 + 0.05 * up)
	var nib := _proj(goal + Vector3(0, 0, 22.0 * up)) + HAND_OUT * (1.0 - reach) * 1000.0 + shove
	# the wrist trails the nib, so the hand turns about its pen as it writes instead of sliding stiffly
	var rest := nib + (WRIST * s).rotated(HAND_TURN)
	_wrist = _wrist.lerp(rest, 1.0 - exp(-delta * 10.0)) if seen and _hand.visible else rest
	_hand_in = clampf(reach, 0.0, 1.0)
	_pen_up = up
	_lamp = 1.0 - _hand_in * (0.13 + 0.05 * sin(_t * 23.0) * sin(_t * 7.3))
	_hand.visible = seen
	_hand.hand_scale = s
	_hand.puppet_nib = nib
	_hand.puppet_turn = HAND_TURN + clampf((rest - nib).angle_to(_wrist - nib) * 0.75, -0.26, 0.26)
	_hand.puppet_flex = flex
	_hand.modulate = Color.WHITE.lerp(Color(1.7, 1.45, 1.05), lit)
	_hand_shadow.visible = seen
	_hand_shadow.queue_redraw()


## The hand's shadow on the desk and the pages: it parts from the hand as the nib lifts.
func _draw_hand_shadow() -> void:
	var s: float = _hand.hand_scale
	var off := Vector2(16, 20) * s * (0.5 + 1.3 * _pen_up)
	# along the pen, the fingers, the wrist and the forearm (shade_hand.gd's art: x, y, radius)
	for b: Vector3 in [Vector3(70, -62, 44), Vector3(130, -90, 74), Vector3(200, -130, 88), Vector3(338, -196, 82),
			Vector3(437, -245, 92), Vector3(535, -294, 100)]:
		_radial(_hand_shadow, _hand.puppet_nib + (Vector2(b.x, b.y) * s).rotated(_hand.puppet_turn) + off, b.z * s,
			Color(0.01, 0.0, 0.03, 0.22))


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
	_draw_splats(w)
	_frame(w, Vector3(-310, 445, 0))
	_candle(w)
	_scarf(w)
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
	_watch(w, Vector3(250, 340, 0))
	_mug(w, Vector3(560, 380, 0))
	_stack(w, Vector3(770, 190, 0))
	_ink_bottle(w, Vector3(430, 150, 0))
	_rod(w, Vector3(330, 40, 4), Vector3(520, -170, 4), 4.0, Color(0.1, 0.09, 0.12), "pen")
	_rod(w, Vector3(-560, -90, 6), Vector3(-300, -260, 6), 6.5, Color(1.0, 0.78, 0.18), "pencil")
	_eraser(w, Vector3(-420, -330, 0))
	_shavings(w)
	# what he threw away: the ending he tore up, drafts in balls, a pencil snapped in two
	_torn(w, _draft.get_texture(), Vector3(-130, -480, 0), 0.22, Vector2(310, 222))
	_crumple(w, Vector3(150, -335, 0), 34.0, 3)
	_crumple(w, Vector3(235, -430, 0), 27.0, 7)
	_crumple(w, Vector3(650, -150, 0), 31.0, 12)
	_crumple(w, Vector3(-650, -330, 0), 30.0, 19)
	_crumple(w, Vector3(120, 470, 0), 26.0, 25)
	_stub(w, Vector3(330, -500, 5), Vector3(410, -462, 5), false)
	_stub(w, Vector3(430, -470, 5), Vector3(500, -520, 5), true)
	# the book
	_book(w)


## Ink that flew and landed on the desk: each a blot and the smaller drops it
## threw on ahead of itself. One draw call for all of them.
func _draw_splats(w: Node2D) -> void:
	if _splats.is_empty():
		return
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	var flat := clampf(absf(_cf.z), 0.25, 1.0)
	for sp in _splats:
		for j in 3:
			var at: Vector3 = sp[0] + sp[2] * (j * (j + 1.0) * sp[1] * 1.9)
			var r: float = sp[1] * 2.3 / (1.0 + j * 1.1) * FOCAL / maxf((at - _cam).dot(_cf), 1.0)
			var c := _proj(at)
			var first := pts.size()
			pts.append(c)
			for k in 8:
				pts.append(c + Vector2(cos(TAU * k / 8.0) * r, sin(TAU * k / 8.0) * r * flat))
				idx.append_array([first, first + 1 + k, first + 1 + (k + 1) % 8])
	RenderingServer.canvas_item_add_triangle_array(w.get_canvas_item(), idx, pts, PackedColorArray([Color(0.03, 0.02, 0.05, 0.9)]))


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


## The framed photo standing at the back of the desk, in the lamp's light,
## leaning on its strut and looking at the chair: the biggest thing on it.
func _frame(w: Node2D, base: Vector3) -> void:
	var size := Vector2(236, 298)
	var face := Vector3(-0.56, -0.83, 0.0).normalized()
	var right := Vector3(-face.y, face.x, 0.0)
	var up := Vector3(0, 0, 1) * cos(0.24) - face * sin(0.24)
	var corner := func(u: float, v: float) -> Vector3:
		return base + right * (u - 0.5) * size.x + up * (1.0 - v) * size.y
	var cast := Vector3(SHADOW.x, SHADOW.y, 0).rotated(Vector3(0, 0, 1), PSI)
	var tl: Vector3 = corner.call(0.0, 0.0)
	var tr: Vector3 = corner.call(1.0, 0.0)
	_poly3(w, [corner.call(0.0, 1.0), corner.call(1.0, 1.0), Vector3(tr.x, tr.y, 0.3) + cast * tr.z, Vector3(tl.x, tl.y, 0.3) + cast * tl.z],
		Color(0, 0, 0, 0.45))
	var prop: Vector3 = corner.call(0.5, 0.3)
	w.draw_line(_proj(prop), _proj(base - face * 105.0), Color(0.07, 0.04, 0.03), 4.0)
	# the thickness of its wood (the side and the top we can see)
	var back := -face * 12.0
	for edge: Array in [[corner.call(1.0, 0.0), corner.call(1.0, 1.0)], [corner.call(0.0, 0.0), corner.call(1.0, 0.0)]]:
		_poly3(w, [edge[0], edge[1], edge[1] + back, edge[0] + back], Color(0.12, 0.06, 0.03))
	var grid := []
	for i in 4:
		var row := []
		for j in 4:
			row.append(corner.call(i / 3.0, j / 3.0))
		grid.append(row)
	_grid_surface(w, _photo.get_texture(), grid, false, 1.12)
	var rim := PackedVector2Array()
	for c: Array in [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.0, 0.0]]:
		rim.append(_proj(corner.call(c[0], c[1])))
	w.draw_polyline(rim, Color(INK, 0.9), 2.5)
	# the lamp on its glass
	_fill(w, PackedVector2Array([_proj(corner.call(0.16, 0.12)), _proj(corner.call(0.34, 0.12)), _proj(corner.call(0.2, 0.66)),
		_proj(corner.call(0.13, 0.66))]), Color(1.0, 0.95, 0.85, 0.08 * _pool(base)))


## A candle burning down beside the photo (its flame and glow are in _draw_glow()).
func _candle(w: Node2D) -> void:
	var c := _cyl_screen(CANDLE, 19, 56)
	var b: Vector2 = c[0]
	var t: Vector2 = c[1]
	var rx: float = c[2]
	var ry: float = c[3]
	var lit := _pool(CANDLE) * 1.1
	_fill(w, _ellipse(b + Vector2(rx * 0.5, ry * 0.4), rx * 1.5, ry * 1.5), Color(0, 0, 0, 0.4))
	_fill(w, _ellipse(b, rx * 1.7, ry * 1.7, 14), Color(0.78, 0.72, 0.58) * lit)  # wax run down and set on the desk
	_fill(w, PackedVector2Array([b + Vector2(-rx, 0), t + Vector2(-rx, 0), t + Vector2(rx, 0), b + Vector2(rx, 0)]), Color(0.93, 0.88, 0.74) * lit)
	_fill(w, _ellipse(b, rx, ry), Color(0.93, 0.88, 0.74) * lit)
	for k in 3:  # drips down its side
		var dx := (k - 1) * rx * 0.6
		w.draw_line(t + Vector2(dx, 0), t.lerp(b, 0.3 + k * 0.2) + Vector2(dx, 0), Color(1.0, 0.97, 0.88) * lit, maxf(rx * 0.22, 1.0))
	_fill(w, _ellipse(t, rx, ry), Color(1.0, 0.95, 0.8) * lit)
	_fill(w, _ellipse(t, rx * 0.5, ry * 0.5), Color(1.0, 0.8, 0.45))  # the melted well, lit from inside
	w.draw_line(t, _proj(CANDLE + Vector3(0, 0, 62)), Color(0.1, 0.07, 0.05), maxf(rx * 0.12, 1.0))


## His brother's red scarf, laid in front of the photo: a long soft strip,
## its folds catching the lamp, frayed at the end.
func _scarf(w: Node2D) -> void:
	var red := Color(0.86, 0.13, 0.1)
	var mids := []
	for i in 15:
		var u := i / 14.0
		mids.append(Vector3(lerpf(-486.0, -196.0, u), 376.0 - 50.0 * u + sin(u * 7.0) * 13.0, 1.0))
	var a_side := []
	var b_side := []
	for i in 15:
		var along: Vector3 = mids[mini(i + 1, 14)] - mids[maxi(i - 1, 0)]
		var n := Vector3(-along.y, along.x, 0).normalized() * 16.0 * (0.6 + 0.4 * sqrt(sin(clampf(i / 14.0, 0.02, 0.98) * PI)))
		a_side.append(mids[i] + n)
		b_side.append(mids[i] - n)
	_soft_shadow(w, [a_side[0], a_side[7], a_side[14], b_side[14], b_side[7], b_side[0]], 5.0, 0.3)
	for i in 14:
		var lit := _pool(mids[i]) * (0.84 + 0.16 * sin(i * 1.3))
		_poly3(w, [a_side[i], a_side[i + 1], b_side[i + 1], b_side[i]], Color(red.r * lit, red.g * lit, red.b * lit))
	var edge := PackedVector2Array()
	for i in 15:
		edge.append(_proj(a_side[i]))
	for i in range(14, -1, -1):
		edge.append(_proj(b_side[i]))
	edge.append(edge[0])
	w.draw_polyline(edge, Color(0.25, 0.02, 0.03, 0.8), 1.5)
	for k in 5:  # its frayed end
		var from: Vector3 = mids[14] + Vector3(0, -10 + k * 5, 0)
		w.draw_line(_proj(from), _proj(from + Vector3(20, -8 + k * 3, 0)), Color(red.r, red.g, red.b, 0.9) * _pool(from), 1.8)


## A page torn in two, its halves lying apart: `tex` runs across both, split
## down a ragged line.
func _torn(w: Node2D, tex: Texture2D, c: Vector3, turn: float, size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var rows := 9
	var tear := PackedFloat32Array()
	for j in rows + 1:
		tear.append(0.5 + rng.randf_range(-0.03, 0.03) + (0.022 if j % 2 == 0 else -0.022))
	var along := Vector3(cos(turn), sin(turn), 0)
	var halves := []  # [points, uvs, colours, indices] each
	for half in 2:
		var a := turn + (half - 0.5) * 0.2
		var ex := Vector3(cos(a), sin(a), 0)
		var ey := Vector3(-sin(a), cos(a), 0)
		var at := c + along * ((half - 0.5) * 52.0) + Vector3(0, -22.0 * half, 0.6)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		var outline := []
		for j in rows + 1:
			var v := float(j) / rows
			for u: float in ([0.0, tear[j]] if half == 0 else [tear[j], 1.0]):
				var q := at + ex * (u - 0.5) * size.x + ey * (0.5 - v) * size.y
				pts.append(_proj(q))
				uvs.append(Vector2(u, v))
				cols.append(_lit(q))
				if j == 0 or j == rows:
					outline.append(q)
			if j < rows:
				idx.append_array([j * 2, j * 2 + 1, j * 2 + 3, j * 2, j * 2 + 3, j * 2 + 2])
		_soft_shadow(w, [outline[0], outline[1], outline[3], outline[2]], 4.0, 0.22)
		halves.append([pts, uvs, cols, idx])
	for h: Array in halves:  # (both shadows first: neither falls on the other half)
		RenderingServer.canvas_item_add_triangle_array(w.get_canvas_item(), h[3], h[0], h[2], h[1], PackedInt32Array(),
			PackedFloat32Array(), tex.get_rid())


## A draft crushed into a ball and thrown down.
func _crumple(w: Node2D, c: Vector3, r: float, seed_n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var mid := c + Vector3(0, 0, r * 0.75)
	var k: float = FOCAL / maxf((mid - _cam).dot(_cf), 1.0)
	var at := _proj(mid)
	var floor_at := _proj(c + Vector3(SHADOW.x, SHADOW.y, 0) * r * 0.5)
	_fill(w, _ellipse(floor_at, r * k * 1.25, r * k * 1.25 * clampf(absf(_cf.z), 0.25, 1.0), 12), Color(0, 0, 0, 0.4))
	var lit := _pool(c)
	var rim := PackedVector2Array()
	for i in 10:
		rim.append(at + Vector2.from_angle(TAU * i / 10.0 + rng.randf_range(-0.15, 0.15)) * r * k * rng.randf_range(0.74, 1.06))
	var heart := at + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)) * r * k
	for i in 10:  # its facets: some turned to the lamp, some away
		var shade := (0.62 + 0.36 * rng.randf()) * lit
		w.draw_colored_polygon(PackedVector2Array([heart, rim[i], rim[(i + 1) % 10]]), Color(0.93 * shade, 0.89 * shade, 0.78 * shade))
	for i in 10:
		w.draw_line(heart, rim[i].lerp(heart, rng.randf_range(0.1, 0.5)), Color(0.3, 0.26, 0.24, 0.45), 1.0)
	w.draw_polyline(rim + PackedVector2Array([rim[0]]), Color(INK, 0.8), 1.5)
	if seed_n % 2 == 1:  # a line of his red pen showing on one
		w.draw_line(rim[2].lerp(heart, 0.4), rim[6].lerp(heart, 0.3), Color(0.85, 0.15, 0.14, 0.8), 1.6)


## Half of a pencil he snapped (`point`: the half with its point on).
func _stub(w: Node2D, a: Vector3, b: Vector3, point: bool) -> void:
	var off := Vector3(SHADOW.x, SHADOW.y, 0) * a.z * 1.4
	var pa := _proj(a)
	var pb := _proj(b)
	var r := 6.5 * FOCAL / maxf((a - _cam).dot(_cf), 1.0)
	var n := (pb - pa).orthogonal().normalized() * r
	var sa := _proj(a - Vector3(0, 0, a.z) + off)
	var sb := _proj(b - Vector3(0, 0, b.z) + off)
	_fill(w, PackedVector2Array([sa + n, sb + n, sb - n, sa - n]), Color(0, 0, 0, 0.35))
	var lit := _lit(a)
	var body := Color(1.0 * lit.r, 0.78 * lit.g, 0.18 * lit.b)
	_fill(w, PackedVector2Array([pa + n, pb + n, pb - n, pa - n]), body)
	w.draw_line(pa, pb, body.lightened(0.3), maxf(r * 0.5, 1.0))
	var along := (pb - pa).normalized() * r
	# the broken end: splinters of pale wood
	_fill(w, PackedVector2Array([pa + n, pa - along * 1.6 + n * 0.3, pa - along * 0.5, pa - along * 1.9 - n * 0.5, pa - n]), Color(0.9, 0.74, 0.52) * lit)
	if point:
		var tip := pb + along * 6.0
		_fill(w, PackedVector2Array([pb + n, tip, pb - n]), Color(0.86, 0.68, 0.48) * lit)
		_fill(w, PackedVector2Array([pb.lerp(tip, 0.65) + n * 0.35, tip, pb.lerp(tip, 0.65) - n * 0.35]), Color(0.2, 0.2, 0.22))
	else:
		_fill(w, PackedVector2Array([pb + n, pb - n, pb + along * 2.2 - n * 0.9, pb + along * 2.2 + n * 0.9]), Color(0.95, 0.5, 0.55) * lit)


## Earlier issues of the comic in a loose pile (he has written it for years).
func _stack(w: Node2D, c: Vector3) -> void:
	for i in 4:
		var a: float = 0.5 + [0.0, 0.16, -0.1, 0.07][i]
		var ex := Vector3(cos(a), sin(a), 0)
		var ey := Vector3(-sin(a), cos(a), 0)
		var at := c + Vector3([0, 14, -8, 5][i], [0, -6, 9, 2][i], 3.0 + i * 7.0)
		var grid := []
		for u in 3:
			var row := []
			for v in 3:
				row.append(at + ex * (u / 2.0 - 0.5) * 200.0 + ey * (0.5 - v / 2.0) * 300.0)
			grid.append(row)
		_soft_shadow(w, [grid[0][0], grid[2][0], grid[2][2], grid[0][2]], 9.0, 0.4)
		_grid_surface(w, _cover.get_texture(), grid, false, 0.62 + i * 0.1)
		var rim := PackedVector2Array([_proj(grid[0][0]), _proj(grid[2][0]), _proj(grid[2][2]), _proj(grid[0][2]), _proj(grid[0][0])])
		w.draw_polyline(rim, Color(INK, 0.85), 1.5)


## A pocket watch lying open, its chain trailing off: the ticking.
func _watch(w: Node2D, c: Vector3) -> void:
	var k: float = FOCAL / maxf((c - _cam).dot(_cf), 1.0)
	var flat := clampf(absf(_cf.z), 0.25, 1.0)
	var at := _proj(c + Vector3(0, 0, 4))
	var lit := _pool(c)
	var chain := PackedVector2Array()
	for i in 12:
		chain.append(_proj(c + Vector3(30 + i * 13.0, 18 + sin(i * 0.9) * 16.0 + i * 5.0, 1)))
	w.draw_polyline(chain, Color(0.75, 0.58, 0.25) * lit, maxf(2.5 * k, 1.0))
	_fill(w, _ellipse(at + Vector2(5, 5) * k, 40 * k, 40 * k * flat), Color(0, 0, 0, 0.4))
	_fill(w, _ellipse(at, 38 * k, 38 * k * flat), Color(0.78, 0.6, 0.26) * lit)
	_fill(w, _ellipse(at, 31 * k, 31 * k * flat), Color(0.96, 0.93, 0.84) * lit)
	for i in 12:
		var d := Vector2(sin(TAU * i / 12.0), -cos(TAU * i / 12.0) * flat)
		w.draw_line(at + d * 25.0 * k, at + d * 30.0 * k, Color(INK, 0.8), maxf(1.5 * k, 1.0))
	for hand: Array in [[TAU * 0.92, 17.0, 2.6], [TAU * 0.19, 25.0, 1.8], [TAU * floorf(_t) / 60.0, 27.0, 1.0]]:  # (it is late)
		w.draw_line(at, at + Vector2(sin(hand[0]), -cos(hand[0]) * flat) * hand[1] * k, Color(0.75, 0.1, 0.1) if hand[2] == 1.0 else INK, maxf(hand[2] * k, 1.0))


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
	var rng_rate := 70.0 if opening else (22.0 if turning else (4.0 * (1.0 - _hand_in) if _t > T_OPEN.y and _t < T_TURN.y else 0.0))
	var n := int(rng_rate * delta + randf())
	for i in n:
		var kind := 0  # sparkles (ink drops read as holes on the page)
		var p := Vector3(randf_range(-BW * 0.8, BW * 0.9), randf_range(-BH * 0.45, BH * 0.45), THICK + 2)
		var v := Vector3(randf_range(-60, 60), randf_range(-60, 60), randf_range(160, 420))
		if kind == 1:
			v.z *= 1.3
		var life := randf_range(0.8, 1.8)
		_sparks.append([p, v, life, life, kind, randf_range(1.5, 4.0)])
	# ink thrown out of the book as the cover bursts open, outwards from its
	# edges: it lands on the desk and stays (_splats)
	if _t > T_OPEN.x + 0.3 and _t < T_OPEN.x + 1.1:
		for i in int(46.0 * delta + randf()):
			var a := randf() * TAU
			var d := Vector3(cos(a), sin(a), 0.0)
			_sparks.append([Vector3(BW * 0.5 + d.x * BW * 0.45, d.y * BH * 0.45, THICK + 4.0),
				d * randf_range(180, 560) + Vector3(0, 0, randf_range(160, 380)), 2.5, 2.5, 1, randf_range(1.2, 4.2)])
	for s in _sparks:
		s[0] += s[1] * delta
		s[1].z -= (120.0 if s[4] == 0 else 520.0) * delta
		s[1] *= 1.0 - 0.6 * delta
		s[2] -= delta
	for s in _sparks:
		if s[4] == 1 and s[0].z <= 0.5 and s[2] > 0.0:  # a drop of ink lands and stays
			if _splats.size() < 70:
				_splats.append([_bk(Vector3(s[0].x, s[0].y, 0.4)), s[5], _bk(Vector3(s[1].x, s[1].y, 0.0).normalized())])
			s[2] = 0.0
	_sparks = _sparks.filter(func(s): return s[2] > 0.0 and s[0].z > -2.0)


## 0..1: lightning outside, a flash and its flicker (at the start, and when
## he stabs the full stop in).
func _lightning() -> float:
	var out := 0.0
	for at: float in [T_FLASH, _stab_t + 0.02]:
		var d := _t - at
		if d > 0.0:
			out = maxf(out, maxf(exp(-d * 16.0), 0.75 * exp(-(d - 0.16) * 20.0) * float(d > 0.16)))
	return minf(out, 1.0)


func _draw_glow() -> void:
	var g := _glow
	# the window: its four panes lie cold across the near right of the desk,
	# rain running down them; lightning fills them, and the room
	var flash := _lightning()
	for i in 2:
		for j in 2:
			var o := WINDOW + PANE_X * (i * 1.08) + PANE_Y * (j * 1.06)
			var pane := PackedVector2Array([_proj(o), _proj(o + PANE_X), _proj(o + PANE_X + PANE_Y), _proj(o + PANE_Y)])
			var far := 0.045 + 0.02 * sin(_t * 1.7 + i * 2.0 + j) + 0.4 * flash
			g.draw_polygon(pane, PackedColorArray([Color(0.4, 0.58, 1.0, far * 1.5), Color(0.4, 0.58, 1.0, far * 1.5),
				Color(0.4, 0.58, 1.0, far * 0.7), Color(0.4, 0.58, 1.0, far * 0.7)]))
	for k in 16:
		var u := fposmod(k * 0.377, 1.0) * 2.08
		var fall := fposmod(_t * (0.16 + (k % 5) * 0.05) + k * 0.61, 1.0)
		var top := WINDOW + PANE_X * u + PANE_Y * (2.06 * (1.0 - fall))
		g.draw_line(_proj(top), _proj(top - PANE_Y * 0.16), Color(0.55, 0.7, 1.0, 0.07 * sin(fall * PI)), 2.0)
	if flash > 0.01:
		g.draw_rect(Rect2(0, 0, 1280, 720), Color(0.5, 0.62, 1.0, 0.2 * flash))
	# the candle by the photo
	var wick := CANDLE + Vector3(0, 0, 60)
	var ck: float = FOCAL / maxf((wick - _cam).dot(_cf), 1.0)
	var lick := 0.85 + 0.1 * sin(_t * 11.0) + 0.05 * sin(_t * 27.0)
	var tip := _proj(wick + Vector3(sin(_t * 6.3) * 2.0, 0, 26.0 * lick))
	var foot := _proj(wick)
	_radial(g, foot, 210.0 * ck * lick, Color(1.0, 0.62, 0.25, 0.2))
	var side := (tip - foot).orthogonal().normalized() * 7.0 * ck
	g.draw_colored_polygon(PackedVector2Array([foot - side, foot.lerp(tip, 0.45) - side * 1.25, tip, foot.lerp(tip, 0.45) + side * 1.25, foot + side]),
		Color(1.0, 0.72, 0.25, 0.9))
	g.draw_colored_polygon(PackedVector2Array([foot - side * 0.5, tip.lerp(foot, 0.4), foot + side * 0.5]), Color(1.0, 0.95, 0.8, 0.9))
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
	var edge := Color(0.0, 0.0, 0.0, 0.7 + 0.2 * _hand_in)  # closes in a little under the Writer's hand
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


## The photo in the frame: two brothers in deep sepia, the City behind them.
## The small one holds a sketchbook; the tall one (_photo_brother()) wears
## Vesper's hat and scarf, the only colour left in it. A black ribbon is tied
## over the corner, and "brothers." is written under it in the Writer's hand.
func _paint_photo(c: Control) -> void:
	var s := Vector2(300, 380)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.15, 0.07, 0.03))
	c.draw_rect(Rect2(6, 6, s.x - 12, s.y - 12), Color(0.44, 0.24, 0.1), false, 7.0)
	c.draw_rect(Rect2(13, 13, s.x - 26, s.y - 26), Color(0.24, 0.12, 0.05), false, 4.0)
	c.draw_rect(Rect2(18, 18, s.x - 36, s.y - 36), Color(0.95, 0.74, 0.3), false, 2.5)  # gilt
	c.draw_rect(Rect2(21, 21, s.x - 42, s.y - 42), Color(0.9, 0.85, 0.7))              # the mount
	var ph := Rect2(34, 34, s.x - 68, s.y - 92)
	c.draw_polygon(PackedVector2Array([ph.position, Vector2(ph.end.x, ph.position.y), ph.end, Vector2(ph.position.x, ph.end.y)]),
		PackedColorArray([Color(0.86, 0.68, 0.42), Color(0.8, 0.6, 0.36), Color(0.5, 0.33, 0.18), Color(0.56, 0.38, 0.2)]))
	c.draw_circle(ph.position + Vector2(52, 50), 26.0, Color(0.97, 0.86, 0.6, 0.85))  # a low sun
	var ground := ph.end.y - 46.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var x := ph.position.x
	while x < ph.end.x - 8.0:  # the City, far off
		var bw := minf(rng.randf_range(20, 40), ph.end.x - x)
		var bh := rng.randf_range(50, 150)
		c.draw_rect(Rect2(x, ground - bh, bw, bh), Color(0.4, 0.27, 0.16, 0.9))
		for wy in range(int(ground - bh + 8), int(ground - 8), 16):
			if rng.randf() < 0.5:
				c.draw_rect(Rect2(x + 5, wy, 5, 7), Color(0.95, 0.8, 0.5, 0.7))
		x += bw + rng.randf_range(2, 8)
	c.draw_rect(Rect2(ph.position.x, ground, ph.size.x, ph.end.y - ground), Color(0.27, 0.17, 0.1))
	# the small brother: messy hair, a sketchbook under his arm, a pencil in his fist
	var dark := Color(0.12, 0.07, 0.04)
	var coat := Color(0.36, 0.24, 0.15)
	var f := Vector2(98, ground + 10.0)
	for lx: float in [-7.0, 8.0]:
		c.draw_line(f + Vector2(lx, 0), f + Vector2(lx * 0.8, -40), dark, 8.0)
		c.draw_circle(f + Vector2(lx + 3.0, 0), 5.5, dark)
	c.draw_colored_polygon(PackedVector2Array([f + Vector2(-19, -36), f + Vector2(20, -36), f + Vector2(15, -98), f + Vector2(-14, -98)]), coat)
	c.draw_polyline(PackedVector2Array([f + Vector2(-19, -36), f + Vector2(20, -36), f + Vector2(15, -98), f + Vector2(-14, -98), f + Vector2(-19, -36)]), dark, 2.0)
	c.draw_circle(f + Vector2(1, -118), 23.0, Color(0.97, 0.85, 0.64))
	c.draw_arc(f + Vector2(1, -118), 23.0, 0, TAU, 20, dark, 2.0)
	c.draw_arc(f + Vector2(0, -122), 21.0, PI * 1.02, PI * 1.98, 14, dark, 10.0)
	for k in 5:
		c.draw_line(f + Vector2(-16 + k * 8, -138), f + Vector2(-20 + k * 9, -149 - (k % 2) * 5), dark, 3.5)
	c.draw_circle(f + Vector2(8, -118), 3.0, dark)
	c.draw_circle(f + Vector2(18, -118), 3.0, dark)
	c.draw_arc(f + Vector2(12, -109), 7.0, 0.3, PI - 0.3, 8, dark, 2.5)
	c.draw_set_transform(f + Vector2(8, -80), -0.2)
	c.draw_rect(Rect2(0, 0, 31, 40), Color(0.96, 0.9, 0.74))
	c.draw_rect(Rect2(0, 0, 31, 40), dark, false, 2.5)
	c.draw_set_transform(Vector2.ZERO)
	c.draw_line(f + Vector2(-9, -90), f + Vector2(16, -60), coat.darkened(0.3), 8.0)
	c.draw_line(f + Vector2(16, -62), f + Vector2(35, -88), Color(0.86, 0.62, 0.22), 4.0)
	# an old photo: dark at the edges
	for k in 5:
		c.draw_rect(ph.grow(-k * 4.0), Color(0.1, 0.05, 0.02, 0.13), false, 8.0)
	c.draw_rect(ph, dark, false, 2.0)
	c.draw_string(HAND, Vector2(96, s.y - 30), "brothers.", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.24, 0.13, 0.07))
	# the mourning ribbon over the corner
	c.draw_colored_polygon(PackedVector2Array([Vector2(s.x - 104, 0), Vector2(s.x - 62, 0), Vector2(s.x, 62), Vector2(s.x, 104)]),
		Color(0.02, 0.01, 0.03))
	c.draw_line(Vector2(s.x - 90, 0), Vector2(s.x, 90), Color(1, 1, 1, 0.12), 2.0)


func _photo_brother(vp: SubViewport) -> void:
	var b: Node2D = PlayerArt.new()
	b.position = Vector2(200, 300)
	b.scale = Vector2(-2.55, 2.55)  # turned to his brother
	b.cloak_color = Color(0.2, 0.12, 0.07)
	b.cloak_rim = Color(0.46, 0.32, 0.2)
	b.mask_color = Color(0.98, 0.9, 0.74)
	b.hat_color = Color(0.11, 0.06, 0.04)
	b.scarf_color = Color(0.92, 0.14, 0.1)
	b.band_color = Color(0.92, 0.14, 0.1)
	b.page_color = Color(0.82, 0.7, 0.5)
	b.pencil_color = Color(0.6, 0.46, 0.28)
	b.eye_color = Color(0.12, 0.07, 0.04)
	vp.get_child(0).add_child(b)


## The page he tore in two (_torn()): the ending he first wrote, where
## Vesper comes home, and his red NO across it.
func _paint_draft(c: Control) -> void:
	var s := Vector2(420, 300)
	_paper(c, s, Color(0.95, 0.93, 0.86))
	c.draw_rect(Rect2(12, 12, s.x - 24, s.y - 24), Color(PENCIL, 0.7), false, 2.0)
	var cap := Rect2(28, 24, s.x - 56, 58)
	c.draw_rect(cap.grow(3.0), INK)
	c.draw_rect(cap, CAPTION)
	var line := "AND VESPER CAME HOME."
	var lw := FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	c.draw_string(FONT, Vector2((s.x - lw) * 0.5, cap.position.y + 43), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, INK)
	# a house with a light on, and him walking up to it
	var pc := Color(PENCIL, 0.75)
	c.draw_line(Vector2(24, 250), Vector2(s.x - 24, 250), pc, 1.5)
	c.draw_rect(Rect2(250, 160, 110, 90), pc, false, 1.8)
	c.draw_polyline(PackedVector2Array([Vector2(240, 162), Vector2(305, 112), Vector2(370, 162)]), pc, 1.8)
	c.draw_rect(Rect2(292, 200, 26, 50), pc, false, 1.5)
	c.draw_rect(Rect2(326, 178, 22, 22), Color(1.0, 0.85, 0.4, 0.75))
	c.draw_rect(Rect2(326, 178, 22, 22), pc, false, 1.5)
	_stick(c, Vector2(150, 250), 1.7, 0.08, 1)
	var end_w := FONT.get_string_size("THE END", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(FONT, Vector2(s.x - end_w - 34, s.y - 22), "THE END", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(INK, 0.85))
	# NO.
	var red := Color(0.86, 0.1, 0.1, 0.9)
	c.draw_set_transform(Vector2(96, 236), -0.2)
	c.draw_string(HAND, Vector2.ZERO, "NO", HORIZONTAL_ALIGNMENT_LEFT, -1, 150, red)
	c.draw_set_transform(Vector2.ZERO)
	c.draw_polyline(PackedVector2Array([Vector2(40, 96), Vector2(380, 128), Vector2(60, 150), Vector2(372, 190), Vector2(80, 214)]), red, 4.0)


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
	_border(c, r, 4.0)  # (its pencil Vesper is drawn live: _paint_p2_live())
	# the rest of the page: the story still to come, roughed out in pencil
	_rough_sketchbook(c, Rect2(26, 350, 225, 200))
	_rough_long_drop(c, Rect2(269, 350, 225, 200))
	_rough_beast(c, Rect2(26, 568, 468, 180))


## Page two, live: the pencil Vesper in the first panel. He blinks while he
## waits to be inked (twice in the held beat before the ink comes).
func _paint_p2_live(c: Node2D) -> void:
	var shut := false
	for b: float in [T_TURN.y - 0.35, T_TOP + 0.35, T_TOP + 0.8]:
		shut = shut or (_t > b and _t < b + 0.13)
	_stick(c, Vector2(P2_PANEL.position.x + 62, P2_PANEL.end.y - 70), 1.2, 0.05 * sin(_t * 1.3), 2 if shut else 1, _t)


## A pencil stick-figure Vesper: hat, round head, a red scarf (as on the
## sketch sheet). `at` = his feet, `k` his size; `eyes` 0 none, 1 open, 2 shut;
## `wave` moves his scarf.
func _stick(c: CanvasItem, at: Vector2, k: float, lean := 0.0, eyes := 0, wave := 0.0) -> void:
	var pc := Color(PENCIL, 0.85)
	c.draw_set_transform(at, lean, Vector2(k, k))
	c.draw_line(Vector2(0, -10), Vector2(-5, 0), pc, 1.5)
	c.draw_line(Vector2(0, -10), Vector2(5, 0), pc, 1.5)
	c.draw_line(Vector2(0, -10), Vector2(0, -22), pc, 1.5)
	c.draw_polyline(PackedVector2Array([Vector2(-2, -22), Vector2(-13, -19 + sin(wave * 5.0) * 1.5), Vector2(-22, -23 + sin(wave * 5.0 + 1.3) * 2.5)]),
		Color(0.85, 0.3, 0.25, 0.85), 2.2)
	c.draw_arc(Vector2(0, -31), 9.0, 0, TAU, 16, pc, 1.5)
	c.draw_line(Vector2(-13, -39), Vector2(13, -40), pc, 2.0)
	c.draw_rect(Rect2(-7, -50, 14, 10), pc, false, 1.5)
	for ex: float in [2.5, 6.5]:
		if eyes == 1:
			c.draw_circle(Vector2(ex, -31), 1.3, pc)
		elif eyes == 2:
			c.draw_line(Vector2(ex - 1.5, -31), Vector2(ex + 1.5, -31), pc, 1.0)
	c.draw_set_transform(Vector2.ZERO)


## A rough panel on page two: blank paper in a pencil box, the diagonals an
## artist rules in blue to find its middle, its number circled in the corner.
func _rough_box(c: CanvasItem, r: Rect2, number: String) -> void:
	c.draw_rect(r, Color(0.98, 0.96, 0.9))
	c.draw_line(r.position, r.end, Color(0.4, 0.6, 0.95, 0.14), 1.0)
	c.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.4, 0.6, 0.95, 0.14), 1.0)
	c.draw_rect(r, Color(PENCIL, 0.6), false, 1.5)
	c.draw_arc(r.position + Vector2(17, 17), 10.0, 0, TAU, 14, Color(PENCIL, 0.55), 1.2)
	c.draw_string(HAND, r.position + Vector2(12, 23), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(PENCIL, 0.85))


## Page two, panel 2: the Sketchbook. A bridge that is only sketched, real
## where his light falls, over spikes.
func _rough_sketchbook(c: CanvasItem, r: Rect2) -> void:
	_rough_box(c, r, "2")
	var o := r.position
	var pc := Color(PENCIL, 0.55)
	c.draw_rect(Rect2(o + Vector2(1, 150), Vector2(57, 49)), pc, false, 1.3)
	c.draw_rect(Rect2(o + Vector2(167, 150), Vector2(57, 49)), pc, false, 1.3)
	var x := 60.0
	while x < 164.0:
		c.draw_polyline(PackedVector2Array([o + Vector2(x, 199), o + Vector2(x + 6.5, 183), o + Vector2(x + 13, 199)]), pc, 1.2)
		x += 13.0
	var ember := o + Vector2(120, 96)
	for k in 6:
		var cell := Rect2(o + Vector2(60 + k * 17.5, 143), Vector2(16, 8))
		if absf(cell.get_center().x - ember.x) < 30.0:
			c.draw_rect(cell, Color(PENCIL, 0.2))
			c.draw_rect(cell, Color(PENCIL, 0.85), false, 1.6)
		else:
			c.draw_dashed_line(cell.position, Vector2(cell.end.x, cell.position.y), pc, 1.0, 3.0)
			c.draw_dashed_line(Vector2(cell.position.x, cell.end.y), cell.end, pc, 1.0, 3.0)
	_stick(c, o + Vector2(108, 143), 0.95)
	c.draw_line(o + Vector2(110, 122), ember + Vector2(-2, 4), Color(PENCIL, 0.85), 1.4)  # his arm, the Ember held up
	c.draw_circle(ember, 4.0, Color(0.95, 0.6, 0.2, 0.55))
	c.draw_arc(ember, 4.0, 0, TAU, 10, Color(PENCIL, 0.85), 1.0)
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0 + 0.2)
		c.draw_line(ember + d * 8.0, ember + d * 14.0, pc, 1.0)
	c.draw_arc(ember, 47.0, 0, TAU, 40, Color(PENCIL, 0.28), 1.0)  # how far it reaches
	c.draw_line(o + Vector2(26, 150), o + Vector2(26, 114), pc, 1.5)  # a lantern on the near bank
	c.draw_rect(Rect2(o + Vector2(19, 98), Vector2(14, 16)), pc, false, 1.3)
	c.draw_string(HAND, o + Vector2(62, 34), "light makes it real", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(PENCIL, 0.8))


## Page two, panel 3: the Long Drop. A shaft, ledges stepping down it, and
## him falling.
func _rough_long_drop(c: CanvasItem, r: Rect2) -> void:
	_rough_box(c, r, "3")
	var o := r.position
	var pc := Color(PENCIL, 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for wall: float in [76.0, 152.0]:
		var side := -1.0 if wall < 100.0 else 1.0
		var line := PackedVector2Array()
		for i in 11:
			line.append(o + Vector2(wall + rng.randf_range(-3, 3), 1.0 + i * 19.8))
		c.draw_polyline(line, pc, 1.6)
		for i in 9:  # rock, hatched
			c.draw_line(o + Vector2(wall + side * 5.0, 8 + i * 21), o + Vector2(wall + side * 24.0, 24 + i * 21), Color(PENCIL, 0.28), 1.0)
	for k in 4:
		var lx := 78.0 if k % 2 == 0 else 120.0
		c.draw_line(o + Vector2(lx, 42 + k * 42), o + Vector2(lx + 30, 42 + k * 42), Color(PENCIL, 0.8), 2.2)
	_stick(c, o + Vector2(118, 130), 0.9, 0.55)
	for k in 4:  # how fast
		c.draw_line(o + Vector2(98 + k * 9, 38 + (k % 2) * 9), o + Vector2(98 + k * 9, 70 + (k % 2) * 9), Color(PENCIL, 0.35), 1.0)
	c.draw_line(o + Vector2(196, 44), o + Vector2(196, 158), pc, 1.6)  # down
	c.draw_polyline(PackedVector2Array([o + Vector2(189, 148), o + Vector2(196, 160), o + Vector2(203, 148)]), pc, 1.6)
	c.draw_string(HAND, o + Vector2(156, 186), "a LONG way", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(PENCIL, 0.8))


## Page two, panel 4: the Beast, as a shape only: a hulk with two heads gone
## over and over in pencil, its eyes left empty for the ink, and him very
## small in front of it.
func _rough_beast(c: CanvasItem, r: Rect2) -> void:
	_rough_box(c, r, "4")
	var o := r.position
	var pc := Color(PENCIL, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var ground := 160.0
	c.draw_line(o + Vector2(8, ground), o + Vector2(r.size.x - 8, ground), Color(PENCIL, 0.6), 1.3)
	var b := o + Vector2(322, 96)
	for k in 17:  # shaded in with the side of the pencil
		var hx := -72.0 + k * 9.0
		var half := 52.0 * sqrt(maxf(1.0 - pow(hx / 80.0, 2.0), 0.0))
		c.draw_line(b + Vector2(hx - 9, 8 + half), b + Vector2(hx + 9, 8 - half), Color(PENCIL, 0.2), 2.5)
	for pass_n in 3:
		c.draw_polyline(_loop(b + Vector2(0, 8), 80, 54, 1.07, rng, 0.07), pc, 1.2)
		c.draw_polyline(_loop(b + Vector2(-50, -50), 30, 26, 1.07, rng, 0.09), pc, 1.2)
		c.draw_polyline(_loop(b + Vector2(44, -56), 28, 25, 1.07, rng, 0.09), pc, 1.2)
	for arm: Array in [[Vector2(-72, 0), Vector2(-130, 20), Vector2(-154, 50)], [Vector2(74, -4), Vector2(120, 28), Vector2(114, 60)]]:
		c.draw_polyline(PackedVector2Array([b + arm[0], b + arm[1], b + arm[2]]), Color(PENCIL, 0.7), 1.8)
		for d: Vector2 in [Vector2(-10, 10), Vector2(-1, 14), Vector2(8, 11)]:
			c.draw_line(b + arm[2], b + arm[2] + d, Color(PENCIL, 0.7), 1.3)
	for e: Vector2 in [Vector2(-60, -54), Vector2(-42, -56), Vector2(36, -60), Vector2(54, -58)]:
		c.draw_arc(b + e, 4.5, 0, TAU, 10, Color(PENCIL, 0.85), 1.3)
	_stick(c, o + Vector2(98, ground), 0.8)
	c.draw_line(o + Vector2(101, ground - 17), o + Vector2(128, ground - 30), Color(PENCIL, 0.85), 1.5)  # his sword, out
	c.draw_string(HAND, o + Vector2(36, 36), "the big one", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(PENCIL, 0.8))


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
		var box := CAP1_BOX if line == 0 else Rect2(70, 638, 380, 104)
		var px := CAP1_PX if line == 0 else 44
		var text: String = LINE1 if line == 0 else LINE2
		var words: Array = CAP1_WORDS if line == 0 else ["BUT NOW...", "LET'S BEGIN."]
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
	var out := Node2D.new()  # over the borders
	out.set_meta("live", true)
	out.draw.connect(_paint_breakout.bind(out))
	root.add_child(out)


## Where the Eraser is in its panel: scrubbing side to side, wider once the
## panel is inked.
func _eraser_x(t: float) -> float:
	return 100.0 + sin(t * 6.0) * (46.0 + 18.0 * _ease((t - T_PANEL_INK) / 0.6))


## Over the panels' borders: once its panel is inked the Eraser won't stay in
## it. It swells, and its scrubbing carries its claws out across the gutter.
func _paint_breakout(c: Node2D) -> void:
	var t := _panel_t(3)
	if t < T_PANEL_INK:
		return
	var grow := _ease((t - T_PANEL_INK) / 0.6)
	EraserArt.draw(c, Transform2D(0.0, Vector2.ONE * (0.38 + 0.08 * grow), 0.0, P1_PANELS[3].position + Vector2(_eraser_x(t), 190.0 + 3.0 * grow)),
		{"time": _t, "rubbing": 1.0, "roar": 0.7})


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
			var slide := maxf(t, 0.0) * 7.0
			for k in 11:  # far towers, paler, sliding by behind the near ones
				var n := k + int(slide / 26.0)
				var far_h := 112.0 + (n * 53 % 70)
				var far := Rect2(k * 26 - 14 - fmod(slide, 26.0), s.y - 34 - far_h, 20, far_h)
				c.draw_rect(far, Color(0.74, 0.72, 0.96, 0.8))
				c.draw_rect(far, Color(1, 1, 1, 0.35), false, 1.0)
			var cols := [Color(0.95, 0.45, 0.65), Color(0.55, 0.45, 0.85), Color(0.95, 0.6, 0.75), Color(0.4, 0.55, 0.9)]
			for k in 7:
				var h := 60.0 + (k * 37 % 70)
				c.draw_rect(Rect2(k * 34 - 6, s.y - 34 - h, 30, h), cols[k % 4])
				c.draw_rect(Rect2(k * 34 - 6, s.y - 34 - h, 30, h), Color(INK, 0.8), false, 1.5)
				for j in 3:  # its windows, going on and off
					if sin(t * 2.6 + k * 2.1 + j * 1.7) > 0.1:
						c.draw_rect(Rect2(k * 34 + (j % 2) * 12, s.y - 34 - h + 12 + j * 15, 6, 8), Color(1.0, 0.95, 0.6, 0.9))
			c.draw_rect(Rect2(0, s.y - 34, s.x, 34), Color(0.18, 0.14, 0.26))
		1:  # the light: a sketch bridge over spikes, held up by the Ember
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.09, 0.2))
			var ember_x := 50.0 + fmod(t * 34.0, 140.0)
			var by := 152.0
			for k in 4:  # behind: pencilled pillars, real only where the Ember's light falls
				var pil := Rect2(14.0 + k * 58.0, 36, 26, by - 36)
				var real := clampf(1.0 - absf(pil.get_center().x - ember_x) / 75.0, 0.0, 1.0)
				c.draw_rect(pil, Color(0.5, 0.42, 0.62, 0.6 * real))
				c.draw_rect(pil, Color(0.8, 0.8, 0.92, 0.16 + 0.5 * real), false, 1.0)
				c.draw_arc(Vector2(pil.get_center().x, 36), 13, PI, TAU, 10, Color(0.8, 0.8, 0.92, 0.16 + 0.5 * real), 1.0)
			var gleam := fmod(maxf(t, 0.0) * 85.0, s.x + 120.0) - 40.0  # runs along the spikes' points
			var x := 0.0
			while x < s.x:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x, s.y), Vector2(x + 9, s.y - 22), Vector2(x + 18, s.y)]), Color(1.0, 0.86, 0.2))
				c.draw_polyline(PackedVector2Array([Vector2(x, s.y), Vector2(x + 9, s.y - 22), Vector2(x + 18, s.y)]), INK, 1.5)
				var g := clampf(1.0 - absf(x + 9.0 - gleam) / 24.0, 0.0, 1.0)
				if g > 0.0:
					var tip := Vector2(x + 9, s.y - 22)
					c.draw_line(tip - Vector2(7 * g, 0), tip + Vector2(7 * g, 0), Color(1, 1, 1, g), 1.5)
					c.draw_line(tip - Vector2(0, 9 * g), tip + Vector2(0, 9 * g), Color(1, 1, 1, g), 1.5)
				x += 18.0
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
			for k in 6:  # behind it, a pencilled city it is rubbing out
				var tower := 50.0 + (k * 41 % 70)
				c.draw_rect(Rect2(k * 37 + 5, 186 - tower, 28, tower), Color(PENCIL, 0.45), false, 1.2)
			c.draw_line(Vector2(0, 186), Vector2(s.x, 186), Color(PENCIL, 0.5), 1.2)
			var ex := _eraser_x(t)
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
			# Scribbles watching from the dark: eyes that shut when the lamp comes their way
			var lamp_x := _iso(sin(t * 1.1) * 2.4, cos(t * 0.8) * 1.6, s).x
			for k in 6:
				var e := Vector2(24.0 + k * 36.0 + (k % 2) * 6.0, 15.0 + (k * 7 % 13)) if k < 5 else Vector2(13, 78)
				var open := clampf(absf(e.x - lamp_x) / 34.0 - 0.5, 0.0, 1.0) * clampf((t - 0.9 - k * 0.12) / 0.3, 0.0, 1.0)
				if fmod(t + k * 0.77, 2.6) < 0.1:
					open = 0.0  # a blink
				for sx: float in [-1.0, 1.0]:
					c.draw_colored_polygon(PackedVector2Array([e + Vector2(sx * 8.0, -2.5 * open), e + Vector2(sx * 1.5, 0.5 * open),
						e + Vector2(sx * 2.5, 2.5 * open), e + Vector2(sx * 8.0, 0.5)]), Color(1, 1, 1, 0.9 * minf(open * 3.0, 1.0)))
		3:
			var ex := _eraser_x(t)
			# SHADE'S ERASER (eraser_art.gd, the same as in the game), scrubbing the panel out
			c.draw_colored_polygon(PackedVector2Array([Vector2(ex - 60, 186), Vector2(ex + 60, 186), Vector2(ex + 50, 192), Vector2(ex - 50, 192)]), Color(INK, 0.25))
			if t < T_PANEL_INK:  # (once its panel is inked it is drawn over the border: _paint_breakout())
				EraserArt.draw(c, Transform2D(0.0, Vector2.ONE * 0.38, 0.0, Vector2(ex, 190)), {"time": _t, "rubbing": 1.0, "roar": 0.7})
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
		"dread": _wav(_dread()), "rain": _wav(_rain_snd(), true), "hum": _wav(_hum_snd(), true),
		"thunder": _wav(_thunder()), "toll": _wav(_toll()), "growl": _wav(_growl()), "lament": _wav(_lament()),
	}


## A sound of the room that goes on and on (it loops; _update_room() sets its level).
func _room_sound(snd: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[snd]
	p.bus = "SFX"  # (Sfx.BUS, as _play())
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p


## The room: rain on the window and the lamp's hum, under the slow minor
## tune. The rain eases a little once the book is open; the hum swells and
## stutters while the Writer's hand is over the desk; both are gone by the dive.
func _update_room() -> void:
	var out := 1.0 - _ease((_t - T_TOP) / 1.2)
	var rain := _ease(_t / 0.5) * lerpf(1.0, 0.6, _ease((_t - T_OPEN.x - 0.5) / 2.5)) * out
	_rain.volume_db = -15.0 + linear_to_db(maxf(rain, 0.001))
	var hum := _ease(_t / 0.5) * (0.55 + 0.9 * _hand_in * (0.75 + 0.25 * signf(sin(_t * 23.0) * sin(_t * 7.3)))) * out
	_hum.volume_db = -29.0 + linear_to_db(maxf(hum, 0.001))


func _play(snd: String, db: float, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[snd]
	p.bus = "SFX"  # Sfx.BUS: every sound effect shares one, quieter than the music
	p.volume_db = db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


const RATE := 22050


func _wav(s: PackedFloat32Array, loops := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loops:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
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


## Rain on the window (loops): a soft hiss, drops tapping the glass.
func _rain_snd() -> PackedFloat32Array:
	var n := int(RATE * 3.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var low := 0.0
	for i in n:
		lp += (randf_range(-1, 1) - lp) * 0.42  # the top rolled off
		low += (lp - low) * 0.02                # and the rumble taken out
		s[i] = (lp - low) * (0.3 + 0.05 * sin(TAU * 2.0 * i / n))
	for d in 44:
		var at := randi() % (n - 800)
		var f := randf_range(900.0, 2600.0)
		var amp := randf_range(0.04, 0.2)
		for j in 700:
			s[at + j] += sin(TAU * f * j / RATE) * exp(-j / 85.0) * amp
	# the end runs on into the start, so the loop has no seam
	var x := int(RATE * 0.2)
	for i in x:
		s[i] = lerpf(s[n - x + i], s[i], float(i) / x)
	s.resize(n - x)
	return s


## The lamp's hum (loops): mains buzz, a little dirty.
func _hum_snd() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	for i in RATE:
		var t := float(i) / RATE
		s.append((sin(TAU * 100.0 * t) * 0.5 + sin(TAU * 200.0 * t) * 0.24 + sin(TAU * 300.0 * t) * 0.13
			+ sin(TAU * 500.0 * t) * 0.06) * 0.6)
	return s


## Thunder: a crack, then a long uneven roll.
func _thunder() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var a := 0.0
	var b := 0.0
	for i in int(RATE * 2.8):
		var t := float(i) / RATE
		a += (randf_range(-1, 1) - a) * 0.03
		b += (a - b) * 0.06
		var roll := exp(-t * 1.1) * (0.55 + 0.45 * sin(t * 9.0 + 3.0 * sin(t * 2.3)))
		s.append(clampf((b * 14.0 + randf_range(-1, 1) * exp(-t * 26.0) * 0.5) * minf(t / 0.03, 1.0) * roll, -1.0, 1.0))
	return s


## A bell tolled once, low and long: for the dead.
func _toll() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var parts := [[146.8, 1.0, 1.1], [174.7, 0.5, 1.5], [293.7, 0.5, 2.0], [369.0, 0.28, 2.8]]  # hum, a minor third, its octave, a sour upper
	for i in int(RATE * 2.6):
		var t := float(i) / RATE
		var v := 0.0
		for q: Array in parts:
			v += sin(TAU * q[0] * t) * q[1] * exp(-t * q[2])
		s.append(v * 0.4 * minf(t / 0.004, 1.0))
	return s


## His anger, low in the throat: two rough notes grinding against each other.
func _growl() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var n := 0.0
	for i in int(RATE * 1.0):
		var t := float(i) / RATE
		n += (randf_range(-1, 1) - n) * 0.02
		var v := clampf(sin(TAU * 55.0 * t) * 2.6, -1.0, 1.0) * 0.5 + clampf(sin(TAU * 58.3 * t) * 2.2, -1.0, 1.0) * 0.4
		s.append(v * (0.7 + n * 4.0) * pow(sin(minf(t, 1.0) * PI), 0.7) * 0.6)
	return s


## Three notes falling down a minor chord, slowly: the light finds the photo.
func _lament() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var notes := [880.0, 698.5, 587.3]
	for i in int(RATE * 2.4):
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var t0 := k * 0.34
			if t > t0:
				v += (sin(TAU * notes[k] * (t - t0)) + 0.3 * sin(TAU * notes[k] * 2.0 * (t - t0))) * exp(-(t - t0) * 2.3) * 0.2
		s.append(v)
	return s


## A low, uneasy swell under the Writer's pen (two notes a semitone apart, beating).
func _dread() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var dur := 4.5
	for i in int(RATE * dur):
		var t := float(i) / RATE
		var env := pow(sin(minf(t / dur, 1.0) * PI), 1.5)
		s.append((sin(TAU * 55.0 * t) * 0.45 + sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 116.5 * t) * 0.24
			+ sin(TAU * 164.8 * t) * 0.08) * env * 0.7)
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
