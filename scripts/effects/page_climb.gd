extends Control
## THE CLIMB: the second half of how Vesper leaves the Gutter, after
## light_capture.gd. About 6 s, all drawn in code; Enter / Esc skips.
##  1. THE PAGE (0-1 s): out of the white, the last frame of the Margins
##     shrinks into a dead panel at the foot of a comic page, and Shade's hand
##     tears up through its top border with Vesper hanging off the nib, flat
##     and drawn again.
##  2. THE CLIMB (1-3.2 s): it hauls him up the gutter between two columns of
##     panels, the beam trailing up after him. Down here they are the Margins'
##     dead panels, crooked, torn and crossed out in red; on the way up they
##     come back to life (pencil roughs, then inked, then the city in full
##     colour: crops of the city painting, page_panel.gdshader), and each one
##     flickers a little more alive as he goes by. Shade: "YOU DON'T GET TO DIE
##     OFF THE PAGE."
##  3. THE CITY (3.2-4.4 s): the hand rips up through the bottom border of the
##     big panel at the top of the page, which is a window onto Shade's City,
##     the live level, and the panel opens out to fill the screen.
##  4. THE DROP (4.4-6.3 s): the hand holds him up over the city: "NOW WATCH
##     ME DELETE IT." The claws open, he drops, and the level's own opening
##     takes over (the hard landing, the narration) while the hand withdraws.
## Lives on the root, so it survives the scene change; the level (started
## loading by light_capture.gd) is swapped in behind the page during the climb
## and paused in the window until he drops. As in panel_turn.gd, the level in
## the window is scaled with the root's global canvas transform and this layer
## cancels that for itself.
##
##   PageClimb.start(tree, last_frame, letterbox_px, skipped)

const ScenePrefetch = preload("res://scripts/core/scene_prefetch.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const PlayerArt = preload("res://scripts/player/player_visual.gd")
const ShadeHand = preload("res://scripts/effects/shade_hand.gd")
const ComicFrame = preload("res://scripts/ui/comic_frame.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const PANEL_SHADER = preload("res://shaders/page_panel.gdshader")
const PAINTING = preload("res://assets/backgrounds/shades_city.webp")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const TARGET := "res://scenes/levels/shades_city.tscn"

const PAPER := Color(0.95, 0.92, 0.85)
const DARK_PAGE := Color(0.05, 0.04, 0.07)
const INK := Color(0.05, 0.03, 0.1)
const RED := Color(0.86, 0.16, 0.14)
const GOLD := Color(1.0, 0.8, 0.42)
const S := Vector2(640, 360)
## Page space (1 px = 1 screen px at zoom 1, y up is negative). The gutter he
## is hauled up runs from the dead panel's top (y = 0) to the city panel.
const LENGTH := 2300.0
const GUTTER_X := 640.0
const LEFT := Vector2(150, 548)  # the columns of panels either side (x from, to)
const RIGHT := Vector2(732, 1130)
const DEAD_PANEL := Rect2(340, 0, 600, 277.5)  # the last frame of the Margins
const CITY := Rect2(150, -LENGTH - 544, 980, 544)  # the window onto Shade's City
const Z0 := 1280.0 / 600.0  # the dead panel fills the screen
const Z_CLIMB := 0.94
const HAND_SCALE := 0.55
const COLLAR := Vector2(-3, -44)  # from his feet to where the nib holds him
const FEET := Vector2(0, 26)  # the 2D player's body centre to its feet
const SETTLE_FRAMES := 3

const T_TEAR := 0.32
const T_SHRUNK := 0.95
const T_SWAP := 2.1
const T_TOP := 3.15
const T_RIP := 3.4
const T_OPEN := 4.4
const T_DROP := 5.5
const T_DONE := 6.3

var _shot: Texture2D
var _bar := 64.0
var _t := 0.0
var _stage := 0  # 0 the old room under the page, 1 the level settling, 2 the level in the window
var _frames := 0
var _skip := false
var _cover := 0.0  # skipping: plain paper over it all until the level is in
var _dropped := false
var _fired := {}
var _g0 := Transform2D.IDENTITY
var _target_rect := Rect2(ComicFrame.PANEL.position, Vector2(1280, 720) - ComicFrame.PANEL.position * 2.0)
var _target_page := Vector2.ZERO  # where the live player stands, in page space
var _comic := true
var _player: Node2D
var _hidden: Array = []  # the level's narration, held back till he drops
var _panels: Array = []
var _shards: Array = []
var _page: Node2D
var _fills: Node2D
var _ink: Node2D
var _fx: Node2D
var _front: Control
var _hand: Node2D
var _vesper: Node2D
var _line := ""
var _line_t := 0.0
var _line_end := 0.0
var _rng := RandomNumberGenerator.new()


static func start(tree: SceneTree, shot: Texture2D, bar: float, skipped: bool) -> void:
	var fx = load("res://scripts/effects/page_climb.gd").new()
	fx._shot = shot
	fx._bar = bar
	fx._skip = skipped or shot == null
	var layer := CanvasLayer.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fx)
	tree.root.add_child(layer)
	tree.paused = true
	Engine.time_scale = 1.0


## Starts loading Shade's City in the background (light_capture.gd calls it
## as the cutscene begins, so it's ready by the climb).
static func preload_level() -> void:
	ScenePrefetch.start(TARGET)


func _ready() -> void:
	_rng.seed = 23
	_g0 = get_viewport().global_canvas_transform
	preload_level()
	_target_page = _to_page(Vector2(640, 598))
	_page = Node2D.new()
	_page.draw.connect(_draw_page)
	add_child(_page)
	_fills = Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = PANEL_SHADER
	_fills.material = mat
	_fills.draw.connect(_draw_fills)
	_page.add_child(_fills)
	_ink = Node2D.new()
	_ink.draw.connect(_draw_ink)
	_page.add_child(_ink)
	_hand = ShadeHand.new()
	_hand.puppet = true
	_hand.hand_scale = HAND_SCALE
	_hand.puppet_turn = -1.0
	_hand.puppet_flex = 1.0
	_hand.visible = false
	_page.add_child(_hand)  # (z 40, shade_hand.gd)
	_vesper = PlayerArt.new()
	_vesper.on_floor = false
	_vesper.visible = false
	_vesper.z_index = 41  # in front of the hand: the nib holds him from behind
	_page.add_child(_vesper)
	_apply_look()
	_fx = Node2D.new()
	_fx.z_index = 42
	_fx.draw.connect(_draw_fx)
	_page.add_child(_fx)
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.z_index = 43
	_front.draw.connect(_draw_front)
	add_child(_front)
	_make_panels()
	if _skip:
		_cover = 1.0


func _exit_tree() -> void:
	get_viewport().global_canvas_transform = _g0


func _input(event: InputEvent) -> void:
	var skip := event.is_action_pressed("pause")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		skip = true
	if skip and not _dropped:
		get_viewport().set_input_as_handled()
		_skip = true


func _apply_look() -> void:
	var profile := get_node_or_null("/root/Profile")
	if profile == null or not profile.has_method("look"):
		return
	var look: Dictionary = profile.look()
	for k in [["scarf", "scarf_color"], ["mask", "mask_color"], ["cloak", "cloak_color"], ["cloak_rim", "cloak_rim"],
			["hat", "hat_color"], ["band", "band_color"]]:
		if look.has(k[0]):
			_vesper.set(k[1], look[k[0]])


## The two columns of panels up the gutter, a few dead ones beside the
## Margins' panel at the foot, each a crop of the city painting.
func _make_panels() -> void:
	for col in 2:
		var xs: Vector2 = LEFT if col == 0 else RIGHT
		var y := -34.0 - col * 150.0
		while y > -LENGTH + 120.0:
			var top := maxf(y - _rng.randf_range(210.0, 330.0), -LENGTH + 40.0)
			if y - top > 120.0:
				_panels.append(_panel(Rect2(xs.x, top, xs.y - xs.x, y - top), col))
			y = top - 32.0
	_panels.append(_panel(Rect2(150, 12, 168, 250), 0))
	_panels.append(_panel(Rect2(962, 12, 168, 250), 1))


func _panel(r: Rect2, col: int) -> Dictionary:
	var size := PAINTING.get_size()
	var w := _rng.randf_range(340.0, 720.0)
	var h := w * r.size.y / r.size.x
	if h > size.y * 0.95:
		h = size.y * 0.95
		w = h * r.size.x / r.size.y
	var region := Rect2(_rng.randf_range(0.0, size.x - w), _rng.randf_range(0.0, size.y - h), w, h)
	var base := clampf((-r.get_center().y - 300.0) / (LENGTH * 0.8), 0.0, 1.0)
	return {"rect": r, "region": region, "seed": _rng.randi() % 1000, "base": base, "col": col,
		"cross": base < 0.32 and _rng.randf() < 0.6, "tilt": _rng.randf_range(-0.045, 0.045) * (1.0 - base) * (1.0 - base)}


# ------------------------------------------------------------------ timing

func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _at(t: float) -> bool:
	if _t >= t and not _fired.has(t):
		_fired[t] = true
		return not _skip
	return false


## A point on the live level's screen (identity transform) -> page space,
## through the city panel.
func _to_page(screen: Vector2) -> Vector2:
	return CITY.position + (screen - _target_rect.position) * (CITY.size.x / _target_rect.size.x)


## Vesper's feet on the page: bursting up out of the dead panel, racing up
## the gutter and slowing near the top, a breath under the city's border, the
## punch through it, then over to where the level will drop him.
func _vesper_at(t: float) -> Vector2:
	var y := 0.0
	var top := -LENGTH + 160.0
	if t < T_TOP:
		var k := clampf((t - T_TEAR) / (T_TOP - T_TEAR), 0.0, 1.0)
		y = lerpf(70.0, top, 1.0 - pow(1.0 - k, 2.2))
	elif t < T_RIP:
		y = top + 26.0 * sin((t - T_TOP) / (T_RIP - T_TOP) * PI * 0.5)  # the hand draws back...
	else:
		var k := clampf((t - T_RIP) / 0.32, 0.0, 1.0)
		y = lerpf(top + 26.0, -LENGTH - 150.0, k * k)  # ...and punches through
	var x := GUTTER_X + sin(t * 2.3) * 16.0
	var p := Vector2(x, y)
	if t > T_RIP + 0.25:
		var goal := _target_page + Vector2(sin(t * 2.0) * 3.0, sin(t * 3.1) * 4.0)
		p = p.lerp(goal, _smoother((t - T_RIP - 0.25) / (T_OPEN - T_RIP - 0.25)))
	return p


func _view() -> Transform2D:
	var v := _vesper_at(_t)
	var follow := Vector2(GUTTER_X, v.y - 110.0)
	var k := _smoother(_t / T_SHRUNK)
	var focus := DEAD_PANEL.get_center().lerp(follow, k)
	var z := lerpf(Z0, Z_CLIMB, k)
	# then onto the city panel until it fills the screen
	var k2 := _smoother((_t - T_TOP + 0.25) / (T_OPEN - T_TOP + 0.25))
	var z_end := _target_rect.size.x / CITY.size.x
	focus = focus.lerp(CITY.get_center() + (S - _target_rect.get_center()) / z_end, k2)
	z = lerpf(z, z_end, k2)
	return Transform2D(0.0, Vector2(z, z), 0.0, S - focus * z)


func _paper_alpha() -> float:
	return 1.0 - _smooth((_t - T_OPEN) / 0.3) if _comic else 1.0


# ------------------------------------------------------------------- live

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)  # a long frame (the level building) never skips the animation
	var rate := 1.0
	if _stage < 2 and _t > T_TOP - 0.6:
		rate = 0.15  # the level still isn't in: dawdle at the top
	_t += delta * rate
	if _skip and not _dropped:
		_cover = minf(_cover + delta * 6.0, 1.0)
	match _stage:
		0:
			if _t >= T_SWAP or (_skip and _cover >= 1.0):
				var packed := _loaded()
				if packed:
					_stage = 1
					_frames = 0
					get_tree().paused = false  # let it build and settle behind the page
					get_tree().change_scene_to_packed(packed)
					var world := get_node_or_null("/root/World25")
					if world:
						world.transitioning = false
						world.reset()  # the Gutter's run is over
		1:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == TARGET:
				_frames += 1
				if _frames > SETTLE_FRAMES:
					get_tree().paused = true
					_open_window(scene)
	if _stage == 2 and _skip and not _dropped:
		_t = maxf(_t, T_DROP)
	if _skip and _dropped:
		_cover = maxf(_cover - delta * 4.0, 0.0)
	if _stage == 2 and _t >= T_DROP and not _dropped:
		_drop()
	if _t >= T_DONE and _dropped and _cover <= 0.0:
		get_viewport().global_canvas_transform = _g0
		get_parent().queue_free()
		return
	_sounds()
	_update_figures(delta)
	_update_shards(delta)
	_page.transform = _view()
	if _stage == 2:
		_apply_window()
	_page.queue_redraw()
	_fills.queue_redraw()
	_ink.queue_redraw()
	_fx.queue_redraw()
	_front.queue_redraw()


func _loaded() -> PackedScene:
	return ScenePrefetch.ready_scene(TARGET)


## The level is in and paused: find where its Vesper hangs (he'll drop from
## there), hide him and its opening caption, and make the city panel a window.
func _open_window(scene: Node) -> void:
	_stage = 2
	_comic = scene.find_child("ComicFrame", false, false) != null
	_target_rect = Rect2(ComicFrame.PANEL.position, size - ComicFrame.PANEL.position * 2.0) if _comic else Rect2(Vector2.ZERO, size)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		_target_page = _to_page(_player.get_viewport().get_canvas_transform() * (_player.global_position + FEET))
		_player.visible = false
	for n in scene.get_children():
		if n is CanvasLayer and n.get_script() and str(n.get_script().resource_path).ends_with("narration.gd"):
			n.visible = false
			_hidden.append(n)
	_apply_window()


## Scales the live level so its comic panel sits exactly on the page's city
## panel (and keeps this layer out of it).
func _apply_window() -> void:
	var view := _view()
	var hole := Rect2(view * CITY.position, CITY.size * view.get_scale().x)
	var k := hole.size.x / _target_rect.size.x
	var z := Transform2D(0.0, Vector2(k, k), 0.0, hole.position - _target_rect.position * k)
	get_viewport().global_canvas_transform = _g0 * z
	(get_parent() as CanvasLayer).transform = z.affine_inverse()


func _drop() -> void:
	_dropped = true
	get_tree().paused = false
	if is_instance_valid(_player):
		_player.visible = true
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_vesper.visible = false
	_hand.puppet_flex = -0.35
	if not _skip:
		_play("whoosh", -3.0, 1.3)
		_play("scritch", -8.0, 0.8)


func _update_figures(delta: float) -> void:
	var v := _vesper_at(_t)
	var shown := _t >= T_TEAR - 0.05 and not _skip
	_vesper.visible = shown and not _dropped
	_hand.visible = shown
	_vesper.position = v
	_vesper.rotation = sin(_t * 3.1) * 0.1 * (1.0 - _smooth((_t - T_OPEN) / 0.5) * 0.6)
	_vesper.velocity = Vector2(0.0, -650.0 if _t < T_RIP + 0.4 else -120.0)
	# washed white by the light he came up, his colours come back on the page
	var w := 1.0 - _smooth((_t - T_TEAR) / 0.9)
	_vesper.modulate = Color(1.0 + w * 1.6, 1.0 + w * 1.6, 1.0 + w * 1.4)
	var nib := v + COLLAR.rotated(_vesper.rotation)
	if _dropped:
		# lets go, and goes back up into the sky
		var k := _t - T_DROP
		nib = v + COLLAR + Vector2(10.0 * k, -40.0 * k - 900.0 * k * k)
		_hand.modulate.a = 1.0 - _smooth(k / 0.7)
	_hand.puppet_nib = nib
	if _stage == 2 and _t > T_OPEN and not _dropped:
		_hand.puppet_flex = 1.0 + 0.15 * sin(_t * 9.0)  # it shakes him


# ----------------------------------------------------------------- sounds

func _sounds() -> void:
	if _at(0.02):
		_play("whoosh", -4.0, 0.55)
	if _at(T_TEAR):
		_play("rip", 0.0, 1.0)
		_play("splut", -6.0, 0.9)
		_tear(Vector2(GUTTER_X, 0.0), -1.0)
	if _at(T_SHRUNK - 0.2):
		_play("rumble", -9.0, 1.4)
	for k in 4:
		if _at(1.0 + k * 0.5):
			_play("whoosh", -10.0 + k, 0.8 + k * 0.15)
	if _at(1.15):
		_say("YOU DON'T GET TO DIE OFF THE PAGE.", 1.1)
	if _at(T_RIP + 0.12):
		_play("rip", 2.0, 0.8)
		_play("thud", -3.0, 1.2)
		_tear(Vector2(GUTTER_X, -LENGTH), -1.0)
	if _at(T_OPEN - 0.25):
		Sfx.play("teleport", -6.0, 1.2)
	if _at(T_OPEN + 0.05):
		_say("NOW WATCH ME DELETE IT.", 0.55)


## A one-shot sound on this layer (SfxSynth.play would hang it on the scene,
## which is swapped out halfway through).
func _play(sound: String, db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SfxSynth.get_stream(sound)
	p.bus = "SFX"  # Sfx.BUS: every sound effect shares one, quieter than the music
	p.volume_db = db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _say(text: String, hold: float) -> void:
	_line = text
	_line_t = _t
	_line_end = _t + text.length() / 30.0 + hold


## Paper and ink flung off a border he's been pulled through.
func _tear(at: Vector2, up: float) -> void:
	for i in 34:
		var paper := i % 3 != 0
		_shards.append({"p": at + Vector2(_rng.randf_range(-50, 50), _rng.randf_range(-6, 6)),
			"v": Vector2(_rng.randf_range(-420, 420), up * _rng.randf_range(250, 900)),
			"rot": _rng.randf() * TAU, "spin": _rng.randf_range(-12, 12),
			"size": _rng.randf_range(6, 15) if paper else _rng.randf_range(3, 6),
			"color": PAPER.darkened(_rng.randf() * 0.15) if paper else INK, "paper": paper, "age": 0.0,
			"life": _rng.randf_range(0.7, 1.3)})


func _update_shards(delta: float) -> void:
	for s in _shards:
		s.age += delta
		s.v.y += 1500.0 * delta
		s.v.x *= 1.0 - 1.5 * delta
		s.p += s.v * delta
		s.rot += s.spin * delta
	_shards = _shards.filter(func(s): return s.age < s.life)


# ----------------------------------------------------------------- drawing

func _page_color(y: float) -> Color:
	return DARK_PAGE.lerp(PAPER, _smooth((y + 120.0) / (-LENGTH * 0.85)))


## The page round everything: dark down in the Margins, paper up top; with a
## hole where the live level shows through.
func _draw_page() -> void:
	var b := InkBatch.new()
	var a := _paper_alpha()
	var outer := Rect2(-500, -LENGTH - 1500, 2280, LENGTH + 2400)
	var pieces: Array[Rect2] = [outer]
	if _stage == 2:
		var h := CITY
		pieces = [Rect2(outer.position, Vector2(outer.size.x, h.position.y - outer.position.y)),
			Rect2(outer.position.x, h.end.y, outer.size.x, outer.end.y - h.end.y),
			Rect2(outer.position.x, h.position.y, h.position.x - outer.position.x, h.size.y),
			Rect2(h.end.x, h.position.y, outer.end.x - h.end.x, h.size.y)]
	for r in pieces:
		var y := r.position.y
		while y < r.end.y - 0.5:
			var y2 := minf(y + 300.0 - fposmod(y, 300.0), r.end.y)
			var c1 := Color(_page_color(y), a)
			var c2 := Color(_page_color(y2), a)
			b.draw_polygon(PackedVector2Array([Vector2(r.position.x, y), Vector2(r.end.x, y), Vector2(r.end.x, y2), Vector2(r.position.x, y2)]),
				PackedColorArray([c1, c1, c2, c2]))
			y = y2
	# the beam trailing up the gutter after him, from the dead panel's tear
	var beam := (1.0 - _smooth((_t - T_RIP) / 0.8)) * _smooth((_t - T_TEAR) / 0.2)
	if beam > 0.0:
		var top := _vesper_at(_t).y - 30.0
		var clear := Color(GOLD, 0.0)
		for side in [-1.0, 1.0]:
			for layer in [[70.0, 0.3], [26.0, 0.55], [7.0, 0.9]]:
				var w: float = layer[0] * (1.0 + 0.08 * sin(_t * 17.0 + side))
				var hot := Color(GOLD.lightened(0.5 * float(layer[1])), float(layer[1]) * beam)
				b.draw_polygon(PackedVector2Array([Vector2(GUTTER_X, top), Vector2(GUTTER_X + side * w, top),
					Vector2(GUTTER_X + side * w, 4.0), Vector2(GUTTER_X, 4.0)]), PackedColorArray([hot, clear, clear, hot]))
	b.flush(_page)


## The pictures: the Margins' last frame (greying once he's out of it), the
## panels up the gutter, and the city panel until the level shows through.
func _draw_fills() -> void:
	var c := _fills
	var seen := _seen()
	if _shot:
		var life := 1.0 - 0.92 * _smooth((_t - 0.45) / 1.3)
		c.draw_texture_rect_region(_shot, DEAD_PANEL, Rect2(0, _bar, 1280, 720 - 2.0 * _bar), Color(life, 0, 0, 1))
	for p in _panels:
		var r: Rect2 = p.rect
		if not seen.intersects(r.grow(40.0)):
			continue
		c.draw_set_transform(r.get_center(), p.tilt, Vector2.ONE)
		c.draw_texture_rect_region(PAINTING, Rect2(-r.size * 0.5, r.size), p.region, Color(_life(p), 0, 0, 1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _stage < 2 and seen.intersects(CITY):
		var sz := PAINTING.get_size()
		var w := sz.y * CITY.size.x / CITY.size.y
		c.draw_texture_rect_region(PAINTING, CITY, Rect2((sz.x - w) * 0.5, 0, w, sz.y), Color(0.84, 0, 0, 1))


## How alive a panel is: by its height up the page, and a little more once
## the light has gone past it.
func _life(p: Dictionary) -> float:
	var r: Rect2 = p.rect
	var by := smoothstep(r.end.y + 40.0, r.position.y - 60.0, _vesper_at(_t).y)
	return clampf(float(p.base) * 0.9 + 0.22 * by, 0.0, 0.84)


## The part of the page on screen.
func _seen() -> Rect2:
	var inv := _view().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * size
	return Rect2(a, b - a).abs()


## Borders, tears, the red pen through the dead panels, sound effects.
func _draw_ink() -> void:
	var c := _ink
	var b := InkBatch.new()
	var seen := _seen()
	for p in _panels:
		var r: Rect2 = p.rect
		if not seen.intersects(r.grow(40.0)):
			continue
		b.draw_set_transform(r.get_center(), p.tilt, Vector2.ONE)
		var local := Rect2(-r.size * 0.5, r.size)
		var life := _life(p)
		_border(b, local, lerpf(3.0, 5.0, life), int(p.seed), Color(INK.lerp(Color(0.32, 0.3, 0.34), 1.0 - smoothstep(0.1, 0.4, life)), 1.0))
		if p.base < 0.3:
			_torn_edge(b, local, p.col == 0, int(p.seed), _page_color(r.get_center().y))
		if p.cross:
			var o := Vector2(local.size.x * 0.32, local.size.y * 0.3)
			b.draw_line(-o, o + Vector2(0, 8), Color(RED, 0.85), 7.0)
			b.draw_line(Vector2(o.x, -o.y + 10), Vector2(-o.x, o.y), Color(RED, 0.85), 6.0)
	b.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the dead panel, torn open where he came out
	_border(b, DEAD_PANEL, 5.0, 3, INK.lerp(Color(0.3, 0.28, 0.32), _smooth((_t - 0.5) / 1.2)))
	if _t >= T_TEAR:
		_hole(b, Vector2(GUTTER_X, DEAD_PANEL.position.y), 1.0, 40.0, _page_color(-10.0))
	# the city panel, and the tear the hand rips in its bottom border
	var a := _paper_alpha()
	if a > 0.0:
		_border(b, CITY, 6.0, 8, Color(INK, a))
		if _t >= T_RIP:
			_hole(b, Vector2(GUTTER_X, CITY.end.y), 1.0, 12.0, Color(_page_color(CITY.end.y + 10.0), a))
	b.draw_set_transform_matrix(Transform2D.IDENTITY)
	b.flush(c)
	# sound effects, stamped on the page
	if _t >= T_TEAR and _t < T_TEAR + 1.4:
		_sfx(c, "RRRIP!", Vector2(GUTTER_X + 70.0, -28.0), -0.18, _t - T_TEAR, 58)
	if _t >= T_RIP + 0.12 and _t < T_RIP + 1.6:
		_sfx(c, "SKRRRIP!", Vector2(GUTTER_X + 90.0, CITY.end.y + 70.0), -0.12, _t - T_RIP - 0.12, 66)


## A hand-drawn ink border (the same wobble as comic_frame.gd's).
func _border(b, r: Rect2, width: float, seed_i: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + seed_i
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var e: Vector2 = corners[(k + 1) % 4]
		var pts := PackedVector2Array()
		var n := maxi(2, int(a.distance_to(e) / 60.0))
		var side := (e - a).normalized().orthogonal()
		for i in n + 1:
			var t := float(i) / n
			var j := 0.0 if i == 0 or i == n else rng.randf_range(-0.9, 0.9)
			pts.append(a.lerp(e, t) + side * j)
		b.draw_polyline(pts, color, width)
	for p in corners:
		b.draw_rect(Rect2(p - Vector2(width, width) * 0.5, Vector2(width, width)), color)


## The edge of a dead panel facing the gutter, ripped ragged.
func _torn_edge(b, r: Rect2, right_side: bool, seed_i: int, page: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + seed_i
	var x := r.end.x if right_side else r.position.x
	var dir := 1.0 if right_side else -1.0
	var pts := PackedVector2Array([Vector2(x + dir * 12.0, r.position.y - 8.0)])
	var y := r.position.y - 8.0
	while y < r.end.y + 8.0:
		pts.append(Vector2(x - dir * rng.randf_range(4.0, 34.0), y))
		y += rng.randf_range(10.0, 26.0)
	pts.append(Vector2(x - dir * 6.0, r.end.y + 8.0))
	pts.append(Vector2(x + dir * 12.0, r.end.y + 8.0))
	b.draw_colored_polygon(pts, page)
	for i in range(1, pts.size() - 2):  # the paper's ragged white fibres along the rip
		b.draw_line(pts[i], pts[i + 1], Color(PAPER, 0.55), 2.0)


## A ragged hole torn through a border at `at`: a notch `depth` deep into
## the panel on the `into` side (+1 down the page), scorched by the light, and
## two flaps of paper bent up the page, the way he went.
func _hole(b, at: Vector2, into: float, depth: float, page: Color) -> void:
	var pts := PackedVector2Array()
	var n := 9
	for i in n + 1:
		var u := float(i) / n
		var d := depth * (0.6 + 0.4 * absf(sin(i * 2.7))) * sin(u * PI)
		pts.append(at + Vector2(lerpf(-64.0, 64.0, u), into * (d + (3.0 if i % 2 == 0 else -3.0))))
	for i in n + 1:
		var u := 1.0 - float(i) / n
		pts.append(at + Vector2(lerpf(-60.0, 60.0, u), -into * (7.0 + 5.0 * absf(sin(i * 1.3)))))
	b.draw_colored_polygon(pts, page)
	b.draw_polyline(pts, Color(GOLD, 0.5 * page.a), 3.0)
	for side in [-1.0, 1.0]:
		var base := at + Vector2(side * 58.0, 0.0)
		var tip := base + Vector2(side * 6.0, -34.0)
		b.draw_colored_polygon(PackedVector2Array([base, tip, base + Vector2(-side * 30.0, -20.0)]), Color(PAPER.darkened(0.08), page.a))
		b.draw_line(base, tip, Color(INK, page.a), 2.5)


func _sfx(c: CanvasItem, text: String, at: Vector2, rot: float, age: float, size: int) -> void:
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - age / 0.12)
	var a := 1.0 - _smooth((age - 0.9) / 0.5)
	c.draw_set_transform(at, rot, Vector2.ONE * pop)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string_outline(FONT, Vector2(-w * 0.5 + 5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(INK, 0.5 * a))
	c.draw_string_outline(FONT, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(INK, a))
	c.draw_string(FONT, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.92, 0.5, a))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## Flung paper and ink, and a glow round the nib while it climbs.
func _draw_fx() -> void:
	var b := InkBatch.new()
	if _hand.visible and not _dropped and _t < T_RIP + 0.5:
		var at := _vesper_at(_t) + COLLAR
		for k in 6:
			b.draw_circle(at, 18.0 + k * 16.0, Color(GOLD, 0.06))
	for s in _shards:
		var a: float = 1.0 - _smooth((s.age - s.life * 0.6) / (s.life * 0.4))
		var sz: float = s.size
		var x := Vector2.from_angle(s.rot) * sz
		var y := Vector2.from_angle(s.rot + 1.9) * sz * 0.7
		if s.paper:
			b.draw_colored_polygon(PackedVector2Array([s.p + x, s.p + y, s.p - x * 0.8]), Color(s.color, a))
		else:
			b.draw_circle(s.p, sz, Color(INK, a))
	b.flush(_fx)


## Screen space: speed lines, the white it opens on, the bars it closes off,
## Shade's balloon, the skip cover.
func _draw_front() -> void:
	var c := _front
	var s := size
	# speed lines while he's hauled up
	var speed := _smooth((_t - T_TEAR) / 0.2) * (1.0 - _smooth((_t - 2.4) / 0.8))
	if speed > 0.0 and not _skip:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var dark := _page_color(_vesper_at(_t).y).get_luminance() < 0.45
		for i in 34:
			var x := rng.randf_range(0.0, s.x)
			if absf(x - S.x) < 120.0:
				continue
			var length := rng.randf_range(70.0, 220.0)
			var y := fposmod(rng.randf() * 1200.0 + _t * rng.randf_range(1800.0, 2800.0), s.y + length * 2.0) - length
			var col := Color(1, 1, 1, 0.3 * speed) if dark else Color(INK, 0.35 * speed)
			c.draw_line(Vector2(x, y), Vector2(x, y + length), col, rng.randf_range(1.5, 3.0))
	# the letterbox it came in with, drawn back
	var bars := _bar * (1.0 - _smooth(_t / 0.45))
	if bars > 0.5 and _shot:
		c.draw_rect(Rect2(0, 0, s.x, bars), Color.BLACK)
		c.draw_rect(Rect2(0, s.y - bars, s.x, bars), Color.BLACK)
	if _line != "" and _t < _line_end and not _skip:
		_draw_balloon(c, s)
	var white := 1.0 - _smooth(_t / 0.3)
	if white > 0.0 and _shot:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.98, 0.93, white))
	if _cover > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(PAPER, _cover))


## Shade's black speech balloon (as in light_capture.gd and the final fight).
func _draw_balloon(c: Control, s: Vector2) -> void:
	var shown := _line.substr(0, int((_t - _line_t) * 30.0))
	var a := clampf((_line_end - _t) / 0.25, 0.0, 1.0)
	var size := 34
	var w := FONT.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := Rect2(s.x * 0.3 - w * 0.5 - 30.0, 64.0, w + 60.0, 66.0)
	box.position += Vector2(sin(_t * 41.0), cos(_t * 37.0)) * 1.2
	var tx := box.position.x + box.size.x * 0.62
	var tail := PackedVector2Array([Vector2(tx, box.position.y + 2), Vector2(tx + 34, box.position.y + 2), Vector2(tx + 52, 8)])
	var rim := Color(0.85, 0.2, 0.25, a)
	c.draw_rect(box.grow(4), rim)
	c.draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(-5, 0), tail[1] + Vector2(5, 0), tail[2] + Vector2(3, -3)]), rim)
	c.draw_rect(box, Color(0.02, 0.01, 0.04, a))
	c.draw_colored_polygon(tail, Color(0.02, 0.01, 0.04, a))
	c.draw_string(FONT, box.position + Vector2(30, 47), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.86, 0.88, a))
	c.draw_string(FONT, box.position + Vector2(box.size.x - 88, box.size.y + 26), "- SHADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.35, 0.4, a))
