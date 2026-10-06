extends "res://scripts/cutscenes/cs_book.gd"
## THE LAST PAGE: the ending (about 50 s), played by shade_finale.gd after
## Vesper asks why. It is the opening (cs_book.gd, whose desk, book, hand and
## pen this is) run the other way: where that one dived from the Writer's desk
## into the page, this one climbs out of it, and Vesper sees what he was
## drawn on.
##   0-4    the finale's last frame is a panel on the book's last page; the
##          camera pulls up out of it onto the desk. It is still raining.
##   4-13   "YOU WANT TO KNOW WHY." The photo, the candle, the scarf ("I DID
##          NOT MAKE YOU UP, VESPER."), the ending he tore in two.
##   13-23  what the desk remembers, in three of its things: the photo up
##          close ("HE ASKED ME TO MAKE HIM THE HERO."), the pile of issues,
##          more and more of them landing on it ("SO I DID. EVERY PAGE WAS
##          HIS."), and the photo again as his brother fades out of it to a
##          pencil outline and the candle beside it goes out ("THEN HE WAS
##          GONE.").
##   24-33  the page of the Writer's attempts, each crossed out: "EVERY PAGE
##          YOU WON WAS A PAGE HE DIDN'T GET." (spoken aloud: the one voiced
##          line in the game). Vesper: "THEN LET ME WIN THEM FOR HIM."
##   33-46  the hand comes back and undoes what it did in the opening: it
##          strikes THE END off the last page and writes TO BE CONTINUED, puts
##          the torn ending back together and blacks out its own NO, and
##          writes FOR MY BROTHER. The rain stops; the window warms.
##   46-52  "AND VESPER CAME HOME." Fade, the title.
##   52-    the credits roll (CREDITS) to their own song, loud ("credits":
##          tools/make_credits_song.py), then the main menu.
## The brother is never named. Enter / Esc skips to the menu.
## It is also a chapter on the main menu (THE ENDING: cs_last_page_start.gd
## sets up a frame of the finale for it to climb out of).
##
## How it reuses the opening: the base script's clock (`_t`) is started past
## the end of the opening's own timeline (T0), so everything of the opening's
## that is keyed to it lies still, and this script's times ("e", seconds from
## its start) are `_t - T0`. The book lies open at its last page: `_p1` and
## `_inside` are pointed at two new pages, so the pen's jobs ("p1" / "in",
## plus "draft" for the torn page) land on them.
##
##   CsLastPage.play(get_tree(), get_viewport().get_texture().get_image())

const CaptionStyle = preload("res://scripts/ui/caption_style.gd")
const MENU := "res://scenes/ui/main_menu.tscn"
## The base clock when this starts: the opening's timeline is long over.
const T0 := 60.0

## The camera comes up out of the panel.
const E_PULL := Vector2(0.6, 4.2)
## What the desk remembers: issues land on the pile from E_ISSUES (one every
## ISSUE_EVERY s); his brother fades out of the photo over E_GONE and the
## candle goes out at E_CANDLE; he is back in it (unseen) by E_BACK.
const E_ISSUES := 17.3
const ISSUE_EVERY := 0.42
const E_GONE := Vector2(20.9, 22.7)
const E_CANDLE := 21.9
const E_BACK := 26.0
## Where the pile of issues is (book space: the camera goes over to it).
const PILE := Vector3(730, 310, 30)
## The hand comes back; the torn page's halves are pushed together; the fade.
const E_HAND := 33.4
const E_MEND := Vector2(40.4, 41.4)
const E_FADE := 49.0
## The credits start rolling (the title card is gone by then), this fast (px/s).
const E_CREDITS := 52.4
const CREDITS_SPEED := 100.0
## The credits, top to bottom: [kind, text]; kinds: "title", "head" (a
## section's heading), "name", "small", "gap". EDIT THE NAMES HERE: they were
## taken from the project's commit history, and roles were not known.
const CREDITS := [
	["title", "VESPER"],
	["small", "a tale of light and ink"],
	["gap", ""],
	["head", "MADE BY"],
	["name", "Shubham Gupta"],
	["name", "Ridhim Mittal"],
	["name", "Kalp Doshi"],
	["name", "Mohd Dhila"],
	["name", "Kratik Gupta"],
	["gap", ""],
	["head", "MUSIC"],
	["name", "Cool Down"],
	["name", "A Flicker in the Deep"],
	["name", "Incisive Battle"],
	["name", "Repose"],
	["name", "The Hunters"],
	["name", "Last Page Stomp (credits)"],
	["gap", ""],
	["head", "FONTS"],
	["name", "Bangers  -  Chewy"],
	["gap", ""],
	["head", "MADE WITH"],
	["name", "Godot Engine"],
	["gap", ""],
	["gap", ""],
	["title", "THANK YOU FOR PLAYING"],
	["small", "for my brother"],
]
## Line heights of the credits' kinds, and their type sizes.
const CREDIT_STEP := {"title": 96.0, "head": 64.0, "name": 46.0, "small": 44.0, "gap": 50.0}
const CREDIT_PX := {"title": 76, "head": 30, "name": 38, "small": 30}
## Morning comes on from here.
const E_DAWN := 36.8
## THE END, stamped across the last page (page pixels): what he strikes.
const END_BOX := Rect2(70, 368, 380, 132)

## Shade's one spoken line: the team's own recording of it
## (tools/voice/build_shade_voice.py trims and levels it).
## "Every page you won was a page he didn't get."
const VOICE := "res://assets/voice/shade_every_page.wav"
const VOICE_AT := 24.1

## What is said, at the foot of the screen: [from, to, who, text].
const LINES := [
	[4.4, 7.6, "shade", "YOU WANT TO KNOW WHY."],
	[8.2, 11.4, "shade", "I DID NOT MAKE YOU UP, VESPER."],
	[13.9, 16.6, "shade", "HE ASKED ME TO MAKE HIM THE HERO."],
	[17.3, 20.1, "shade", "SO I DID. EVERY PAGE WAS HIS."],
	[20.8, 23.4, "shade", "THEN HE WAS GONE."],
	[23.9, 30.3, "shade", "EVERY PAGE YOU WON WAS A PAGE HE DIDN'T GET."],  # (spoken: VOICE_AT, 5.9 s)
	[30.7, 33.3, "vesper", "THEN LET ME WIN THEM FOR HIM."],
	[46.0, 49.0, "narrator", "AND VESPER CAME HOME."],
]

## Camera keys, as the opening's: time (e), target (book space), distance,
## pitch, yaw, roll (degrees).
const E_KEYS := [
	[0.0, Vector3(130, 94, THICK), 181.0, 90.0, 0.0, 0.0],   # the panel fills the screen
	[0.6, Vector3(130, 94, THICK), 181.0, 90.0, 0.0, 0.0],
	[2.3, Vector3(130, 40, THICK), 600.0, 90.0, 0.0, 0.0],    # straight up off the page first
	[4.6, Vector3(60, 20, 0), 1500.0, 52.0, -12.0, -2.0],     # the desk
	[6.4, Vector3(30, 40, 0), 1400.0, 50.0, -10.0, -1.5],
	[8.2, Vector3(-320, 345, 70), 640.0, 46.0, -6.0, 0.0],    # the photo, the candle, the scarf
	[10.2, Vector3(-326, 348, 70), 600.0, 46.0, -5.0, 0.0],
	[11.7, Vector3(-52, -490, 0), 640.0, 70.0, 4.0, 0.0],     # the ending he tore up
	[12.8, Vector3(-52, -488, 0), 615.0, 71.0, 4.0, 0.0],
	[13.8, Vector3(-372, 398, 150), 345.0, 40.0, -4.0, 0.0],  # the photo, close: the two of them
	[16.5, Vector3(-372, 398, 150), 325.0, 40.0, -4.0, 0.0],
	[17.9, PILE, 640.0, 58.0, 6.0, 0.0],                      # the pile of issues, growing
	[20.0, PILE, 600.0, 58.0, 6.0, 0.0],
	[21.2, Vector3(-300, 384, 110), 470.0, 42.0, -5.0, 0.0],  # the photo and the candle
	[23.2, Vector3(-300, 384, 110), 445.0, 42.0, -5.0, 0.0],
	[24.2, Vector3(-124, 6, THICK), 570.0, 78.0, -1.0, 0.0],  # the page of his attempts
	[29.6, Vector3(-116, 4, THICK), 548.0, 79.0, 0.0, 0.0],
	[31.0, Vector3(130, 50, THICK), 530.0, 80.0, 1.0, 0.0],   # the last page
	[38.7, Vector3(126, -20, THICK), 560.0, 80.0, 1.0, 0.0],
	[40.3, Vector3(-52, -485, 0), 600.0, 72.0, 3.0, 0.0],     # the torn page, mended
	[42.3, Vector3(-52, -485, 0), 585.0, 72.0, 3.0, 0.0],
	[43.2, Vector3(-125, -70, THICK), 520.0, 78.0, -1.0, 0.0],  # the dedication
	[45.6, Vector3(-125, -70, THICK), 505.0, 78.0, -1.0, 0.0],
	[52.3, Vector3(20, 60, 0), 1650.0, 56.0, -14.0, -3.0],    # up and away from the desk
]

## The finale's last frame: the panel the camera comes out of.
var snapshot: Image

var _snap: ImageTexture
var _brother: Node2D  # the tall brother in the photo (he fades out of it)
var _dawn := 0.0
var _over := false
var _end := 0.0  # when it is over (e): once the credits have rolled off


## Plays the ending over whatever is on screen (the finale), `frame` being
## that screen; when it is done it goes to the main menu.
static func play(tree: SceneTree, frame: Image) -> void:
	var layer := CanvasLayer.new()
	layer.name = "CsLastPageLayer"
	layer.layer = 96
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var fx: Control = load("res://scripts/cutscenes/cs_last_page.gd").new()
	fx.snapshot = frame
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fx)
	tree.root.add_child.call_deferred(layer)


func _ready() -> void:
	if snapshot and not snapshot.is_empty():
		_snap = ImageTexture.create_from_image(snapshot)
	super._ready()
	_t = T0
	var roll := 0.0
	for line: Array in CREDITS:
		roll += CREDIT_STEP[line[0]]
	_end = E_CREDITS + (roll + 760.0) / CREDITS_SPEED
	_stab_t = 1.0e9  # (no lightning: the storm is passing)
	get_tree().paused = true  # the finale waits underneath
	# the book lies open at its last page: the opening's pages are put away
	for vp: SubViewport in [_p1, _p1b, _inside, _p2]:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_p1 = _page(_paint_last, "p1")
	_inside = _page(_paint_left, "in")
	_draft.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # he writes on it
	var over_no := Node2D.new()
	over_no.set_meta("live", true)
	over_no.draw.connect(_paint_ink.bind(over_no, "draft"))
	_draft.get_child(0).add_child(over_no)
	# the photo is live here: his brother fades out of it, down to a pencil outline
	_photo.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for n in _photo.get_child(0).get_children():
		if n.get_script() == PlayerArt:
			_brother = n
	var ghost := Node2D.new()
	ghost.set_meta("live", true)
	ghost.draw.connect(_paint_gone.bind(ghost))
	_photo.get_child(0).add_child(ghost)


## A page of the book that the pen can write on (`name`: the pen jobs' page).
func _page(paint: Callable, page: String) -> SubViewport:
	var vp := _make_vp(TEX, paint, true)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ink := Node2D.new()
	ink.set_meta("live", true)
	ink.draw.connect(_paint_ink.bind(ink, page))
	vp.get_child(0).add_child(ink)
	return vp


func _load_next() -> bool:
	return false  # nothing to load: it ends at the main menu


## The book stays open at its last page.
func _cover_angle(_at := -1.0) -> float:
	return PI


func _turn() -> float:
	return 0.0


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	var e := _t - T0
	if _skip >= 0.0:
		_skip += delta
		if _skip > 0.3:
			_leave()
		queue_redraw()
		return
	_cues()
	_update_camera()
	# the pen coming down on THE END, hard
	var struck: float = e - (_jobs[0].t0 - T0)
	_shake = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 4.0 * exp(-maxf(struck, 0.0) * 6.0) * float(struck > 0.0)
	_dawn = _ease((e - E_DAWN) / 10.0)
	_update_writer(delta)
	_update_room()
	_update_sparks(delta)
	# what the desk remembers: the pile grows; he goes out of the photo; the candle goes out
	_issues = 4.0 + clampf((e - E_ISSUES) / ISSUE_EVERY, 0.0, 7.0)
	_exposure = 1.0 + 1.7 * _ease((e - 17.0) / 0.9) * (1.0 - _ease((e - 20.0) / 1.0))  # (the pile lies in the dark: open up for it)
	var gone := _gone(e)
	if _brother:
		_brother.modulate.a = 1.0 - gone
	_flame = 1.0 - _ease((e - E_CANDLE) / 0.5)
	for vp: SubViewport in [_p1, _inside, _draft, _photo]:
		for n in vp.get_child(0).find_children("*", "CanvasItem", true, false):
			if n.get_meta("live", false):
				n.queue_redraw()
	_world.queue_redraw()
	_glow.queue_redraw()
	_top.queue_redraw()
	queue_redraw()
	if e >= _end:
		_leave()


## To the main menu (at the end, or on a skip).
func _leave() -> void:
	if _over:
		return
	_over = true
	var tree := get_tree()
	tree.paused = false
	Engine.time_scale = 1.0
	tree.change_scene_to_file(MENU)
	get_parent().queue_free()


func _cues() -> void:
	var e := _t - T0
	if e >= 0.3:
		_once("goodbye", func():
			var music := get_node_or_null("/root/Music")
			if music:
				music.play("ending", 2.5))  # the game's tune, slow, on a piano: a goodbye
	if e >= E_PULL.x:
		_once("out", func(): _play("dive", -7.0, 0.6))
	for i in 7:  # each issue landing on the pile
		if e >= E_ISSUES + (i + 1) * ISSUE_EVERY - 0.04:
			_once("issue%d" % i, func(): _play("thump", -14.0 + i, 1.5 - i * 0.05))
	if e >= E_GONE.x + 0.5:
		_once("gone", func(): _play("toll", -7.0, 0.84))
	if e >= E_CANDLE:
		_once("snuffed", func(): _play("whoosh", -16.0, 1.6))
	if e >= VOICE_AT:
		_once("voice", _speak)
	if e >= E_CREDITS - 0.3:
		_once("credits", func():
			var music := get_node_or_null("/root/Music")
			if music:
				music.play("credits", 0.4))  # the mood lifts: he lived
	if e >= E_MEND.x:
		_once("mend", func(): _play("flip", -8.0, 1.3))
	var first: float = _jobs[0].t0 - T0
	if e >= first:
		_once("strike", func(): _play("thump", -6.0, 0.8))
	if e >= _jobs[-1].t0 + _jobs[-1].dur - T0 + 0.2:
		_once("for_him", func(): _play("lament", -8.0))


## Shade says it aloud (the one spoken line in the game).
func _speak() -> void:
	if not ResourceLoader.exists(VOICE):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(VOICE)
	p.volume_db = 2.0  # (on Master, not the quieter SFX bus: it must carry over the piano)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Rain on the window, thinning as the morning comes; the lamp's hum.
func _update_room() -> void:
	var e := _t - T0
	var out := 1.0 - _ease((e - E_FADE) / 2.5)
	var rain := _ease((e - E_PULL.x) / 2.5) * (1.0 - _ease((e - E_DAWN) / 8.0))
	_rain.volume_db = -15.0 + linear_to_db(maxf(rain, 0.001))
	_hum.volume_db = -31.0 + linear_to_db(maxf((0.6 + 0.6 * _hand_in) * out, 0.001))


# ----------------------------------------------------------------- camera

func _camera_at(t: float) -> PackedFloat32Array:
	t -= T0
	var n := E_KEYS.size()
	if t <= E_KEYS[0][0]:
		return _key_vals(E_KEYS[0])
	if t >= E_KEYS[n - 1][0]:
		return _key_vals(E_KEYS[n - 1])
	var i := 0
	while i < n - 2 and t > E_KEYS[i + 1][0]:
		i += 1
	var t0: float = E_KEYS[i][0]
	var t1: float = E_KEYS[i + 1][0]
	var h := t1 - t0
	var s := (t - t0) / h
	var p0 := _key_vals(E_KEYS[i])
	var p1 := _key_vals(E_KEYS[i + 1])
	var out := PackedFloat32Array()
	out.resize(p0.size())
	for c in p0.size():
		# (eased from key to key, each one a place it comes to rest: no swing through)
		out[c] = lerpf(p0[c], p1[c], _smoother(s))
	return out


func _update_camera() -> void:
	var v := _camera_at(_t)
	var target := _bk(Vector3(v[0], v[1], v[2]))
	var dist := exp(v[3])
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


# ------------------------------------------------------------- the Writer

## What his pen does this time: it takes back what it did in the opening.
func _build_jobs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# THE END struck off the last page, twice through...
	var mid := END_BOX.get_center()
	_job("p1", T0 + 34.7, 0.8, [
		_zigzag(Vector2(END_BOX.position.x, mid.y + 26.0), Vector2(END_BOX.end.x, mid.y - 22.0), 3, 10.0, rng),
		_zigzag(Vector2(END_BOX.end.x - 8.0, mid.y + 30.0), Vector2(END_BOX.position.x + 6.0, mid.y - 6.0), 3, 9.0, rng)], 9.0, INK, "scratch", 0.7)
	# ...and under it, in his red: TO BE CONTINUED
	var page := Transform2D(-0.03, Vector2(0, 0))
	_job("p1", T0 + 35.9, 2.7, _write("TO BE", Vector2(152, 566), 1.3, page, rng) + _write("CONTINUED", Vector2(68, 628), 1.3, page, rng),
		5.5, BLOOD, "scratch", 1.2)
	# the ending he tore up, put back together (_mend), and his NO blacked out
	_job("draft", T0 + 41.6, 0.8, [_zigzag(Vector2(70, 222), Vector2(312, 132), 7, 30.0, rng, 4.0),
		_zigzag(Vector2(306, 150), Vector2(84, 204), 4, 12.0, rng, 4.0)], 11.0, INK, "scratch", 0.75)
	# and on the facing page, under everything he tried: who it was for
	var ded := Transform2D(-0.04, Vector2(0, 0))
	_job("in", T0 + 43.3, 2.2, _write("FOR MY", Vector2(170, 622), 1.1, ded, rng) + _write("BROTHER", Vector2(140, 676), 1.1, ded, rng),
		5.0, BLOOD, "scratch", 1.25)


## The torn page is a page too (as it lies once it is mended).
func _page_point(page: String, p: Vector2) -> Vector3:
	if page != "draft":
		return super._page_point(page, p)
	var ex := Vector3(cos(DRAFT_TURN), sin(DRAFT_TURN), 0)
	var ey := Vector3(-sin(DRAFT_TURN), cos(DRAFT_TURN), 0)
	var w := DRAFT_AT + ex * (p.x / 420.0 - 0.5) * DRAFT_SIZE.x + ey * (0.5 - p.y / 300.0) * DRAFT_SIZE.y + Vector3(0, 0, 1.2)
	return Vector3(w.dot(_bx), w.dot(_by), w.z)  # (world -> book space)


func _update_writer(delta: float) -> void:
	var e := _t - T0
	_pen_job = -1
	var first: float = _jobs[0].t0 - T0
	var done: float = _jobs[-1].t0 + _jobs[-1].dur - T0
	var goal := Vector3.ZERO
	var reach := 0.0
	var up := 0.0
	var flex := 0.55
	if e >= E_HAND and e < done + 1.6:
		reach = _back((e - E_HAND) / 0.9) * (1.0 - _ease((e - done - 0.5) / 0.9))
		if e < first:  # it hangs over THE END, then comes down on it
			goal = _bk(_page_point("p1", _jobs[0].strokes[0][0]))
			up = 0.85 * (1.0 - _ease((e - first + 0.14) / 0.14))
		else:
			var pen := _pen_state()
			goal = _bk(pen[0])
			up = pen[1]
		flex = 0.55 if _pen_job < 0 else 0.86 + 0.08 * sin(_t * 41.0)
	_mend = _ease((e - E_MEND.x) / (E_MEND.y - E_MEND.x))
	_apply_hand(goal, reach, up, flex, Vector2.ZERO, 0.0, delta)


# ------------------------------------------------------------- light, fx

func _draw_glow() -> void:
	super._draw_glow()
	var e := _t - T0
	if e > E_CANDLE + 0.2 and e < E_CANDLE + 5.0:
		# the candle's last smoke, going up and thinning
		var age := e - E_CANDLE - 0.2
		var smoke := PackedVector2Array()
		for i in 12:
			var h := i * 11.0 * minf(age / 1.2, 1.0)
			smoke.append(_proj(CANDLE + Vector3(sin(i * 0.8 + _t * 1.6) * (2.0 + i * 1.3), 0, 62.0 + h)))
		_glow.draw_polyline(smoke, Color(0.8, 0.8, 0.9, 0.22 * (1.0 - age / 4.8)), 3.0, true)
	if _dawn <= 0.0:
		return
	# morning: the window's light turns from cold to gold, and the room with it
	for i in 2:
		for j in 2:
			var o := WINDOW + PANE_X * (i * 1.08) + PANE_Y * (j * 1.06)
			_glow.draw_colored_polygon(PackedVector2Array([_proj(o), _proj(o + PANE_X), _proj(o + PANE_X + PANE_Y), _proj(o + PANE_Y)]),
				Color(1.0, 0.72, 0.36, 0.16 * _dawn))
	_glow.draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.78, 0.5, 0.1 * _dawn))


# ------------------------------------------------------- the screen itself

func _draw() -> void:
	var e := _t - T0
	var full := Rect2(Vector2.ZERO, Vector2(1280, 720))
	draw_texture_rect(_stage.get_texture(), full, false)
	# the finale's last frame, sharp, in its panel while the camera is still near it
	var near := 1.0 - _ease((e - 1.5) / 0.7)
	if _snap and near > 0.0:
		draw_texture_rect(_snap, _panel_rect(), false, Color(1, 1, 1, near))
	_draw_lines(e)
	# the end: dark, the title, who it was for
	var dark := _ease((e - E_FADE) / 1.4)
	if dark > 0.0:
		draw_rect(full, Color(INK, dark))
		var card := _ease((e - E_FADE - 1.2) / 0.8) * (1.0 - _ease((e - E_CREDITS + 0.7) / 0.6))
		var title := "VESPER"
		var tw := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x
		draw_string_outline(FONT, Vector2(640 - tw * 0.5 + 6, 366), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, 14, Color(RED, card))
		draw_string(FONT, Vector2(640 - tw * 0.5, 360), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, Color(1.0, 0.72, 0.3, card))
		var sub := "to be continued"
		var sw := HAND.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		draw_string(HAND, Vector2(640 - sw * 0.5, 424), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(PAPER, card))
		_draw_credits(e)
	if _skip >= 0.0:
		draw_rect(full, Color(INK, clampf(_skip / 0.3, 0.0, 1.0)))


## The credits, rolling up the dark.
func _draw_credits(e: float) -> void:
	var y := 760.0 - (e - E_CREDITS) * CREDITS_SPEED
	if e < E_CREDITS:
		return
	for line: Array in CREDITS:
		var kind: String = line[0]
		if kind != "gap" and y > -80.0 and y < 800.0:
			var text: String = line[1]
			var px: int = CREDIT_PX[kind]
			var font: Font = HAND if kind == "small" else FONT
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var a := clampf(minf(y - 20.0, 700.0 - y) / 90.0, 0.0, 1.0)  # (in at the foot, out at the head)
			var col := Color(1.0, 0.72, 0.3) if kind == "title" else (Color(BLOOD.r, BLOOD.g, BLOOD.b) if kind == "head" else PAPER)
			if kind == "title":
				draw_string_outline(font, Vector2(640 - w * 0.5 + 4, y + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 10, Color(RED, a))
			draw_string(font, Vector2(640 - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, a))
		y += CREDIT_STEP[kind]


## What is being said, in its caption panel at the foot of the screen.
func _draw_lines(e: float) -> void:
	for line: Array in LINES:
		if e < line[0] or e > line[1]:
			continue
		var a := clampf((e - line[0]) / 0.3, 0.0, 1.0) * clampf((line[1] - e) / 0.3, 0.0, 1.0)
		var text: String = line[3]
		var shown := text.substr(0, int((e - line[0]) * 34.0))
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var box := Rect2(640 - w * 0.5 - 26, 618, w + 52, 62)
		CaptionStyle.panel(self, box, line[2], a)
		draw_string(FONT, box.position + Vector2(26, 44), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, CaptionStyle.text_color(line[2], a))


# ------------------------------------------------------------- the photo

## 0..1: how far his brother has gone out of the photo (and he is back in
## it, with nobody looking, by E_BACK).
func _gone(e: float) -> float:
	return _ease((e - E_GONE.x) / (E_GONE.y - E_GONE.x)) * (1.0 - _ease((e - E_BACK) / 0.4))


## Where his brother stood in the photo, once he has faded: his outline in
## dashed pencil, the way the unfinished are drawn in this book. (The photo's
## own pixels: see _photo_brother().)
func _paint_gone(c: Node2D) -> void:
	var a := _gone(_t - T0)
	if a <= 0.0:
		return
	var pc := Color(0.24, 0.15, 0.08, 0.75 * a)
	var feet := Vector2(200, 300)
	var shape := [Vector2(-52, -150), Vector2(52, -150), Vector2(26, -150), Vector2(24, -190), Vector2(-24, -190), Vector2(-26, -150),  # the hat
		Vector2(-24, -150), Vector2(-26, -100), Vector2(-36, -60), Vector2(-44, -4), Vector2(44, -4), Vector2(36, -60), Vector2(26, -100), Vector2(24, -150)]  # head and cloak
	for i in shape.size():
		var p: Vector2 = feet + shape[i]
		var q: Vector2 = feet + shape[(i + 1) % shape.size()]
		c.draw_dashed_line(p, q, pc, 2.5, 7.0)


# ------------------------------------------------------------------ pages

## The book's last page: the finale, as its top panel; under it THE END as
## the Writer stamped it; room below for what he writes instead.
func _paint_last(c: Control) -> void:
	var s := Vector2(TEX)
	_paper(c, s)
	c.draw_string(FONT, Vector2(26, 54), "VESPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, RED)
	c.draw_string(FONT, Vector2(150, 54), "THE LAST PAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	c.draw_rect(P2_PANEL, Color(0.08, 0.06, 0.12))
	if _snap:
		c.draw_texture_rect(_snap, P2_PANEL, false)
	_border(c, P2_PANEL, 4.0)
	# THE END, in his red, pressed hard
	c.draw_set_transform(END_BOX.get_center(), -0.05)
	var tw := FONT.get_string_size("THE END", HORIZONTAL_ALIGNMENT_LEFT, -1, 118).x
	c.draw_string_outline(FONT, Vector2(-tw * 0.5, 40), "THE END", HORIZONTAL_ALIGNMENT_LEFT, -1, 118, 10, Color(INK, 0.9))
	c.draw_string(FONT, Vector2(-tw * 0.5, 40), "THE END", HORIZONTAL_ALIGNMENT_LEFT, -1, 118, BLOOD)
	c.draw_set_transform(Vector2.ZERO)
	c.draw_string(FONT, Vector2(s.x - 54, s.y - 16), "64", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, 0.6))


## The page before it: everything the Writer threw at him, each crossed out,
## because each time he got up. (FOR MY BROTHER is written under them.)
func _paint_left(c: Control) -> void:
	var s := Vector2(TEX)
	_paper(c, s, Color(0.93, 0.89, 0.8))
	c.draw_string(HAND, Vector2(40, 52), "he keeps getting up.", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(BLOOD, 0.85))
	var tries := [[Rect2(34, 74, 214, 176), "p.41"], [Rect2(272, 74, 214, 176), "p.52"], [Rect2(152, 272, 214, 176), "p.63"]]
	for i in tries.size():
		var r: Rect2 = tries[i][0]
		_rough_box(c, r, "")
		var o := r.position
		var pc := Color(PENCIL, 0.7)
		c.draw_line(o + Vector2(8, 150), o + Vector2(r.size.x - 8, 150), pc, 1.3)
		_stick(c, o + Vector2(48, 150), 0.85)
		match i:
			0:  # the Beast
				for q: Array in [[Vector2(140, 104), 44.0, 38.0], [Vector2(114, 54), 20.0, 18.0], [Vector2(164, 50), 19.0, 17.0]]:
					c.draw_arc(o + q[0], q[1], 0, TAU, 18, pc, 1.6)
				c.draw_polyline(PackedVector2Array([o + Vector2(100, 96), o + Vector2(76, 116), o + Vector2(70, 136)]), pc, 1.6)
			1:  # the Eraser
				c.draw_rect(Rect2(o + Vector2(118, 54), Vector2(54, 96)), pc, false, 1.8)
				c.draw_line(o + Vector2(118, 80), o + Vector2(172, 80), pc, 1.4)
				c.draw_line(o + Vector2(128, 96), o + Vector2(140, 102), pc, 1.6)
				c.draw_line(o + Vector2(162, 96), o + Vector2(150, 102), pc, 1.6)
				c.draw_polyline(PackedVector2Array([o + Vector2(128, 126), o + Vector2(136, 118), o + Vector2(144, 126), o + Vector2(152, 118), o + Vector2(160, 126)]), pc, 1.4)
			2:  # the lamp
				c.draw_arc(o + Vector2(150, 40), 16.0, 0, TAU, 14, pc, 1.6)
				c.draw_polyline(PackedVector2Array([o + Vector2(140, 52), o + Vector2(96, 150), o + Vector2(204, 150), o + Vector2(160, 52)]), Color(PENCIL, 0.45), 1.3)
		# crossed out, hard
		c.draw_line(r.position + Vector2(12, 14), r.end - Vector2(12, 14), Color(BLOOD, 0.9), 6.0)
		c.draw_line(Vector2(r.end.x - 12, r.position.y + 14), Vector2(r.position.x + 12, r.end.y - 14), Color(BLOOD, 0.9), 6.0)
		c.draw_string(HAND, r.position + Vector2(8, r.size.y - 8), tries[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(PENCIL, 0.9))
	c.draw_string(HAND, Vector2(300, 520), "again.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(BLOOD, 0.85))
