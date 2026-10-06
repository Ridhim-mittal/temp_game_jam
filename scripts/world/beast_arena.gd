extends Node2D
## The Scribbled Beast's arena at the bottom of the Long Drop: runs the
## intro, the fight and the ending around scribbled_beast.gd, then hands
## Vesper to the Eraser's chase (eraser_chase.gd). The node sits on the arena
## floor at the gutter the Beast comes out of.
##
## The Margins are the gutters of the comic: the gaps between its panels.
## So the Beast doesn't come up out of the floor, it comes out of the gap
## between the columns. Intro (about 15 s, once a run; Enter skips):
## Vesper walks in and the controls are taken (player.gd `cutscene`),
## letterbox bars; the page rumbles; an ink line splits the panel from top to
## bottom, and the two halves part on the gutter, the Margins' dark between
## two inked panel borders; deep in it two eyes open, and the Beast comes up
## out of the depth, small and dark at first, its SHIELD held over its head
## against the lanterns' light (the light splashes off it); the lanterns die
## as its darkness reaches them; its claws grab the panel borders, which
## crack, and it tears out through them into Vesper's panel; the gap slams
## shut behind it. Close-up: three eyes open, it ROARS, the title card; the
## Writer: "That wasn't supposed to get out." / "...Fine. Let it finish the
## page. This is where your story ends, Vesper." Back to Vesper, a wall of
## scribble seals the way back, the boss bar fills, fight. On a retry (after
## dying) a short version plays (about 3 s).
##
## Fight: a boss bar (bottom), the gutter cracks open when the Beast calls
## Scribbles out of it (crack_gutter()), and after a couple of blocked hits
## with no lantern lit a "LIGHT IT!" tag over the nearest dark lantern (once a
## run).
##
## Ending (about 24 s; Enter skips to the Eraser): the camera frames the
## Beast dying; then Shade, the Writer, in his black balloon, breaking out of
## the narration: "NO." / "Page forty-one: 'The Beast tears Vesper apart.
## The End.' I wrote it. In ink." Vesper: "...Guess I skipped that page."
## Shade, furious (red pulse, pen scratches across the panel): "You were
## supposed to die here, Vesper. That was your ending." / "A hero who won't
## stay dead ruins the whole book." / "Fine. If ink can't finish you..." His
## ERASER slams down out of the sky (shade_eraser.gd): "...I'll rub you out
## myself." The panel's right-hand border rips open: RUN! (eraser_chase.gd).

const InkBits = preload("res://scripts/effects/ink_bits.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const GameCamera = preload("res://scripts/camera/game_camera.gd")
const Eraser = preload("res://scripts/enemies/shade_eraser.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const CAPTION := Color(1.0, 0.9, 0.45)
const FURY := Color(0.95, 0.32, 0.25)
const PAPER := Color(0.93, 0.9, 0.82)
const RIM := Color(0.86, 0.92, 1.0)
const VOID := Color(0.006, 0.006, 0.014)
const LIGHT := Color(1.0, 0.92, 0.6)
const BAR_RED := Color(0.78, 0.12, 0.12)
## Half the width of the gutter between the columns when it's wide open.
const GUTTER_HALF := 150.0
const LINES_INTRO := ["THAT WASN'T SUPPOSED TO GET OUT.", "...FINE. LET IT FINISH THE PAGE. THIS IS WHERE YOUR STORY ENDS, VESPER."]
## The ending: [time, who, line, fury]. "shade" = his black balloon, "vesper" = Vesper's own.
const DIALOGUE := [
	[5.2, "shade", "NO.", true],
	[7.0, "shade", "PAGE FORTY-ONE: \"THE BEAST TEARS VESPER APART. THE END.\" I WROTE IT. IN INK.", false],
	[10.8, "vesper", "...GUESS I SKIPPED THAT PAGE.", false],
	[13.4, "shade", "YOU WERE SUPPOSED TO DIE HERE, VESPER. THAT WAS YOUR ENDING.", true],
	[16.6, "shade", "A HERO WHO WON'T STAY DEAD RUINS THE WHOLE BOOK.", true],
	[19.6, "shade", "FINE. IF INK CAN'T FINISH YOU...", true],
	[21.9, "shade", "...I'LL RUB YOU OUT MYSELF.", true],
]
const T_ERASER := 21.2
const T_RIP := 24.4
const T_RUN := 25.0

enum Phase { WAIT, INTRO, FIGHT, OUTRO, CHASE, DONE }

@export var beast_path: NodePath
@export var lantern_paths: Array[NodePath] = []
## The intro starts once Vesper is right of this x (world).
@export var trigger_x := 0.0
## Where the wall of scribble seals the way back (world x).
@export var barrier_x := 0.0
## The arena's right-hand panel border (world x): it rips open for the chase.
@export var east_x := 0.0
## How high the room is above the floor (px), for the walls.
@export var room_height := 1000.0
## The chase it hands Vesper to (eraser_chase.gd).
@export var chase_path: NodePath

var phase := Phase.WAIT
## How far the gutter between the columns is open (0 shut .. 1 wide).
var gap_open := 0.0

var _t := 0.0
var _short := false
var _fired := {}
var _beast: Node2D
var _lanterns: Array = []
var _player: Node2D
var _eraser: Node2D
var _cam: Camera2D
var _cam_goal := Vector2.ZERO
var _zoom_goal := 1.0
var _cam_rate := 2.5
var _layer: CanvasLayer
var _ui: Control
var _back: Node2D
var _front: Node2D
var _beams: Node2D
var _hint: Node2D
var _barrier: StaticBody2D
var _barrier_shape: CollisionShape2D
var _barrier_up := 0.0
var _east: StaticBody2D
var _east_shape: CollisionShape2D
var _east_open := 0.0
var _bars := 0.0
var _bars_goal := 0.0
var _title := -1.0
var _caption := ""
var _caption_t := -1.0
var _caption_fury := false
var _line := ""
var _who := ""
var _line_t := -1.0
var _line_fury := false
var _split := 0.0  # the ink line splitting the panel, top to bottom (0..1)
var _cracks := 0.0  # the panel borders cracking under its claws
var _shatter := 0.0  # the borders broken as it tears out
var _crack_t := 0.0  # seconds the gutter stays cracked open in the fight
var _bar_shown := 0.0
var _bar_lag := 1.0
var _blocked := 0
var _hint_t := -1.0
var _hint_lamp: Node2D
var _flash := 0.0
var _rumble := 0.0
var _shadow := 0.0  # the Eraser's shadow falling over the panel
var _time := 0.0
var _batch := InkBatch.new()


func _ready() -> void:
	add_to_group("beast_arena")
	_beast = get_node_or_null(beast_path)
	for p in lantern_paths:
		var l := get_node_or_null(p)
		if l:
			_lanterns.append(l)
	_build()
	var state := get_node_or_null("/root/GameState")
	if state and state.seen.has("beast_dead"):
		# already beaten this run (a retry after dying in the chase): the way on is open
		phase = Phase.DONE
		if _beast:
			_beast.queue_free()
			_beast = null
		_east_open = 1.0
		_east_shape.disabled = true
		return
	_short = state != null and state.seen.has("beast_intro")
	if _beast:
		_beast.gap_x = global_position.x
		_beast.arena_lanterns = _lanterns
		_beast.visible = false
		_place_beast(0.0)
		if _beast.has_signal("defeated"):
			_beast.defeated.connect(_on_defeated)
	if _short:
		for l in _lanterns:
			l.lit = false  # it already put them out once


func _build() -> void:
	_back = _drawer(1, _draw_back)
	_front = _drawer(3, _draw_front)
	_beams = _drawer(4, _draw_beams)
	_hint = _drawer(6, _draw_hint)
	_barrier = StaticBody2D.new()
	_barrier.collision_layer = 1
	_barrier_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, room_height)
	_barrier_shape.shape = rect
	_barrier_shape.disabled = true
	_barrier.add_child(_barrier_shape)
	add_child(_barrier)
	_barrier.global_position = Vector2(barrier_x, global_position.y - room_height * 0.5)
	var wall := Node2D.new()
	wall.z_index = 3
	wall.draw.connect(_draw_barrier.bind(wall))
	_barrier.add_child(wall)
	# the right-hand panel border: shut until the chase
	_east = StaticBody2D.new()
	_east.collision_layer = 1
	_east_shape = CollisionShape2D.new()
	var er := RectangleShape2D.new()
	er.size = Vector2(40, room_height)
	_east_shape.shape = er
	_east.add_child(_east_shape)
	add_child(_east)
	_east.global_position = Vector2(east_x if east_x != 0.0 else global_position.x + 1000.0, global_position.y - room_height * 0.5)
	var border := Node2D.new()
	border.z_index = 3
	border.draw.connect(_draw_east.bind(border))
	_east.add_child(border)
	_cam = Camera2D.new()
	_cam.set_script(GameCamera)
	_cam.framing_offset = Vector2.ZERO
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	add_child(_cam)
	_cam.remove_from_group("camera")
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_layer.add_child(_ui)


func _drawer(z: int, painter: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.draw.connect(painter.bind(n))
	add_child(n)
	return n


# ------------------------------------------------------------------ flow

func _process(delta: float) -> void:
	_time += delta
	_player = get_tree().get_first_node_in_group("player")
	match phase:
		Phase.WAIT:
			if _player and not _player.dead and _player.global_position.x > trigger_x and _beast:
				_start_intro()
		Phase.INTRO:
			_t += delta
			if _short:
				_intro_short()
			else:
				_intro_long()
		Phase.FIGHT:
			if _beast and _beast.state == _beast.State.DYING:
				_start_outro()
			_update_hint(delta)
			# the gutter cracks open while the Beast calls Scribbles out of it
			_crack_t = maxf(_crack_t - delta, 0.0)
			gap_open = move_toward(gap_open, 0.45 if _crack_t > 0.0 else 0.0, delta * 1.5)
		Phase.OUTRO:
			_t += delta
			_outro()
	# smooth camera, letterbox, walls, bar
	if _cam.is_current():
		var k := 1.0 - exp(-_cam_rate * delta)
		_cam.global_position = _cam.global_position.lerp(_cam_goal, k)
		_cam.zoom = _cam.zoom.lerp(Vector2.ONE * _zoom_goal, k)
		if _rumble > 0.0:
			_cam.add_trauma(_rumble * delta * 3.0)
	_bars = move_toward(_bars, _bars_goal, delta * 2.5)
	var hud := get_tree().current_scene.get_node_or_null("UI") as CanvasLayer
	if hud:
		hud.visible = _bars_goal < 0.5 and _bars < 0.3
	var want_wall := 1.0 if phase == Phase.FIGHT else 0.0
	_barrier_up = move_toward(_barrier_up, want_wall, delta * 1.6)
	_barrier_shape.disabled = _barrier_up < 0.5
	if _beast and is_instance_valid(_beast) and _beast.max_hp > 0:
		var frac := clampf(float(_beast.health) / _beast.max_hp, 0.0, 1.0)
		_bar_lag = move_toward(_bar_lag, frac, delta * (0.25 if _bar_lag > frac else 2.0))
		if _bar_lag < frac:
			_bar_lag = frac
	var bar_goal := 1.0 if phase == Phase.FIGHT else 0.0
	_bar_shown = move_toward(_bar_shown, bar_goal, delta * 1.4)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	if _title >= 0.0:
		_title += delta
		if _title > 3.2:
			_title = -1.0
	if _caption_t >= 0.0:
		_caption_t += delta
	if _line_t >= 0.0:
		_line_t += delta
	_back.queue_redraw()
	_front.queue_redraw()
	_beams.queue_redraw()
	_hint.queue_redraw()
	_ui.queue_redraw()
	for c in _barrier.get_children() + _east.get_children():
		if c is Node2D:
			c.queue_redraw()


## Fires once when the scene's clock passes `time`.
func _at(time: float) -> bool:
	if _t >= time and not _fired.has(time):
		_fired[time] = true
		return true
	return false


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]):
		return
	if phase == Phase.INTRO and not _short:
		get_viewport().set_input_as_handled()
		_skip_intro()
	elif phase == Phase.OUTRO and _t < T_ERASER - 0.4:
		# skip the talk, not the Eraser's entrance
		get_viewport().set_input_as_handled()
		for d in DIALOGUE:
			if d[0] < T_ERASER:
				_fired[d[0]] = true
		_line_t = -1.0
		_t = T_ERASER - 0.4


func _start_intro() -> void:
	phase = Phase.INTRO
	_t = 0.0
	_fired.clear()
	_player.cutscene = true
	var pcam := _player.get_node_or_null("Camera2D") as Camera2D
	_cam.global_position = _view_from(pcam)
	_cam.zoom = Vector2.ONE
	_cam_goal = _cam.global_position
	_zoom_goal = 1.0
	_cam_rate = 2.2
	_cam.make_current()
	_bars_goal = 1.0
	_music("", 2.5)  # the Long Drop's tune fades: only the rumble as the page splits


## Puts the Beast at depth `k` in the gutter: 0 = deep in it (small and dark),
## 1 = out on the floor of the panel, full size.
func _emerge(k: float) -> void:
	if _beast == null:
		return
	var s := lerpf(0.32, 1.0, k)
	_beast.outline.scale = Vector2(s, s)
	var d := lerpf(0.12, 1.0, clampf(k * 1.3, 0.0, 1.0))
	_beast.modulate = Color(d, d, d * 1.05)


func _intro_long() -> void:
	var fl := global_position.y
	var gx := global_position.x
	if _at(0.4):
		_rumble = 0.35
		SfxSynth.play(get_tree(), "rumble", -2.0)
		_say(Vector2(gx - 300, fl - 380), "RMMBL...", RIM, 30)
	if _t > 0.4 and _t < 2.4 and fmod(_t, 0.2) < get_process_delta_time():
		InkBits.burst(get_tree(), Vector2(gx + randf_range(-500, 500), fl - room_height + 40), 3, 80.0, Vector2.DOWN, 0.6)
	if _at(0.8):
		_cam_goal = Vector2(gx, fl - 300)
		_zoom_goal = 0.92  # wide: the whole height of the panel and both lanterns
		_cam_rate = 2.2
	# an ink line splits the panel from top to bottom...
	if _at(1.6):
		SfxSynth.play(get_tree(), "scritch", 0.0, 0.5)
		_say(Vector2(gx + 60, fl - 600), "SKRRRT", PAPER, 34)
	if _t >= 1.6 and _t < 2.2:
		_split = _ease((_t - 1.6) / 0.6)
	# ...and the two halves part on the gutter between them
	if _at(2.2):
		_split = 1.0
		SfxSynth.play(get_tree(), "rip", 0.0)
		_say(Vector2(gx + 170, fl - 460), "RRRIIIP!", PAPER, 44)
		_cam.add_trauma(0.5)
		for i in 6:
			InkBits.burst(get_tree(), Vector2(gx, fl - room_height * (i + 0.5) / 6.0), 8, 380.0, Vector2.ZERO, 0.9)
	if _t >= 2.2 and _t < 3.0:
		gap_open = _ease((_t - 2.2) / 0.8)
	# deep in the dark, something comes: small and far, the shield held up over its head
	if _at(3.0):
		_beast.visible = true
		_beast.shield_lift = 1.0
		_beast.eyes_open = [0.0, 0.0, 0.0]
		_beast.facing = -1 if _player.global_position.x < gx else 1
		_place_beast(0.0)
		_emerge(0.0)
	if _t >= 3.0 and _t < 4.8:
		# it comes up out of the depth in heaving steps
		var k := (_t - 3.0) / 1.8
		var step := (floorf(k * 4.0) + _ease(fmod(k * 4.0, 1.0))) / 4.0
		_emerge(step * 0.82)
		_beast.light_on_shield = 1.0 if _any_lit() else 0.0
	if _at(3.2) or _at(3.65) or _at(4.1) or _at(4.55):
		SfxSynth.play(get_tree(), "thud", -6.0, 0.6)
		_cam.add_trauma(0.2)
	# its darkness puts the lanterns out as it comes
	if _at(4.0):
		_snuff(0)
	if _at(4.4):
		_snuff(1)
	# claws on the panel borders, which crack
	if _at(4.8):
		_beast.grip = 1.0
		_beast.grip_point = Vector2(gx - GUTTER_HALF * _beast.facing * -1.0, fl - 190.0)
		SfxSynth.play(get_tree(), "scritch", -2.0, 0.6)
		_say(Vector2(gx - 220, fl - 300), "KRAKK!", RIM, 40)
	if _t >= 4.8 and _t < 5.3:
		_cracks = _ease((_t - 4.8) / 0.4)
		_emerge(lerpf(0.82, 0.9, (_t - 4.8) / 0.5))
	# it tears out through them into Vesper's panel, and the gap slams shut
	if _at(5.3):
		_shatter = 1.0
		_beast.grip = 0.0
		SfxSynth.play(get_tree(), "shatter", 0.0, 0.8)
		SfxSynth.play(get_tree(), "roar", -6.0, 1.3)
		_cam.add_trauma(0.8)
		for i in 10:
			for side: float in [-1.0, 1.0]:
				InkBits.burst(get_tree(), Vector2(gx + side * GUTTER_HALF, fl - room_height * (i + 0.5) / 10.0), 4, 520.0, Vector2(side, 0), 0.6)
	if _t >= 5.3 and _t < 5.75:
		var k := (_t - 5.3) / 0.45
		_emerge(lerpf(0.9, 1.0, k))
		_place_beast(-sin(k * PI) * 50.0, _beast.facing * 150.0 * _ease(k))
		gap_open = 1.0 - _ease(k)
	if _at(5.75):
		_emerge(1.0)
		_place_beast(0.0, _beast.facing * 150.0)
		gap_open = 0.0
		_split = 0.0
		SfxSynth.play(get_tree(), "thud", 2.0)
		_say(Vector2(gx + 40, fl - 520), "WHAM!", PAPER, 52)
		_flash = 0.35
		InkBits.burst(get_tree(), _beast.global_position + Vector2(0, 100), 20, 380.0, Vector2.UP, 0.3)
	# push in on it; the eyes open one at a time
	if _at(6.0):
		_cam_goal = _beast_head()
		_zoom_goal = 1.75
		_cam_rate = 2.4
	for i in 3:
		var t0: float = [6.4, 6.7, 7.0][i]
		if _t >= t0:
			_beast.eyes_open[i] = clampf((_t - t0) / 0.12, 0.0, 1.0)
		if _at(t0):
			SfxSynth.play(get_tree(), "scritch", -10.0, 1.6 + i * 0.2)
	# the shield comes down, and it roars
	if _t >= 7.3 and _t < 7.6:
		_beast.shield_lift = 1.0 - _ease((_t - 7.3) / 0.3)
	if _at(7.45):
		SfxSynth.play(get_tree(), "roar", 2.0)
		_music("beast", 0.15)  # the fight's music crashes in on the roar
		_rumble = 0.9
		_say(_beast_head() + Vector2(-_beast.facing * 40.0, -40.0), "GRRRAAAAHHH!!", Color(1.0, 0.25, 0.18), 54)
	if _t >= 7.45 and _t < 9.0:
		_beast.roar = clampf((_t - 7.45) / 0.2, 0.0, 1.0) * (1.0 - clampf((_t - 8.7) / 0.3, 0.0, 1.0))
		if fmod(_t, 0.1) < get_process_delta_time():
			InkBits.burst(get_tree(), _beast_head() + Vector2(_beast.facing * 30, 10), 3, 420.0, Vector2(_beast.facing, 0.2), 0.0)
	if _at(7.8):
		_title = 0.0
		Sfx.play("boss_intro")
		_cam_goal = _beast_head() + Vector2(0, 60)
		_zoom_goal = 1.35
		_cam_rate = 1.4
	if _at(9.0):
		_rumble = 0.0
		_beast.roar = 0.0
	if _at(9.6):
		_show_caption(LINES_INTRO[0], false)
	if _at(11.5):
		_show_caption(LINES_INTRO[1], false)
	if _at(14.6):
		_cam_goal = _player_view()
		_zoom_goal = 1.0
		_cam_rate = 2.4
	if _at(15.5):
		_start_fight()


func _intro_short() -> void:
	var fl := global_position.y
	var gx := global_position.x
	if _at(0.0):
		_cam_goal = Vector2(gx, fl - 250)
		_zoom_goal = 0.95
		_cam_rate = 3.0
		SfxSynth.play(get_tree(), "rip", -2.0)
	_split = _ease(_t / 0.25)
	if _t < 0.55:
		gap_open = _ease((_t - 0.15) / 0.4)
	if _at(0.3):
		_beast.visible = true
		_beast.shield_lift = 1.0
		_beast.facing = -1 if _player.global_position.x < gx else 1
		_place_beast(0.0)
	if _t >= 0.3 and _t < 1.2:
		_emerge(_ease((_t - 0.3) / 0.9) * 0.9)
	if _t >= 1.2 and _t < 1.6:
		var k := (_t - 1.2) / 0.4
		_emerge(lerpf(0.9, 1.0, k))
		_place_beast(-sin(k * PI) * 40.0, _beast.facing * 120.0 * _ease(k))
		gap_open = 1.0 - _ease(k)
		_beast.shield_lift = 1.0 - k
	if _at(1.6):
		_emerge(1.0)
		_place_beast(0.0, _beast.facing * 120.0)
		gap_open = 0.0
		_split = 0.0
		SfxSynth.play(get_tree(), "thud", 2.0)
		SfxSynth.play(get_tree(), "roar", -2.0, 1.1)
		_music("beast", 0.3)
		_cam.add_trauma(0.7)
	if _t >= 1.6 and _t < 2.4:
		_beast.roar = 1.0 - clampf((_t - 2.1) / 0.3, 0.0, 1.0)
	if _at(2.2):
		_cam_goal = _player_view()
		_zoom_goal = 1.0
	if _at(2.9):
		_start_fight()


func _skip_intro() -> void:
	for l in _lanterns:
		l.lit = false
	gap_open = 0.0
	_split = 0.0
	_beast.visible = true
	_beast.facing = -1 if _player.global_position.x < global_position.x else 1
	_place_beast(0.0, _beast.facing * 150.0)
	_emerge(1.0)
	_beast.grip = 0.0
	_beast.light_on_shield = 0.0
	_title = -1.0
	_caption_t = -1.0
	_rumble = 0.0
	_start_fight()


func _start_fight() -> void:
	phase = Phase.FIGHT
	_music("beast", 0.3)  # Enter may have skipped past the roar
	gap_open = 0.0
	_split = 0.0
	_bars_goal = 0.0
	_rumble = 0.0
	_emerge(1.0)
	_player.cutscene = false
	var pcam := _player.get_node_or_null("Camera2D") as Camera2D
	if pcam:
		pcam.make_current()
		pcam.reset_smoothing()
	_beast.begin_fight()
	var state := get_node_or_null("/root/GameState")
	if state:
		state.seen["beast_intro"] = true
	SfxSynth.play(get_tree(), "scritch", -4.0, 0.5)


## Music autoload: a track ("" = fade out).
func _music(track: String, fade: float) -> void:
	var m := get_node_or_null("/root/Music")
	if m == null:
		return
	if track == "":
		m.stop(fade)
	else:
		m.play(track, fade)


## beast.gd: Scribbles come out of the gutter; it cracks open for a moment.
func crack_gutter(seconds: float) -> void:
	_crack_t = seconds
	_split = 1.0
	_cracks = 0.0
	_shatter = 0.0


func _start_outro() -> void:
	phase = Phase.OUTRO
	_t = 0.0
	_fired.clear()
	_music("", 3.0)  # it dies in silence: Shade's lines land on nothing
	_crack_t = 0.0
	if _player and not _player.dead:
		_player.cutscene = true
	var pcam := _player.get_node_or_null("Camera2D") as Camera2D if _player else null
	_cam.global_position = _view_from(pcam)
	_cam.zoom = Vector2.ONE
	_cam_goal = _beast.global_position + Vector2(0, -60)
	_zoom_goal = 1.35
	_cam_rate = 2.0
	_cam.make_current()
	_bars_goal = 1.0


func _outro() -> void:
	var fl := global_position.y
	if _at(0.2):
		_rumble = 0.25
	if _t > 3.6 and _t < 3.8:
		_rumble = 0.0
	# quiet: Vesper alone in the panel where his story was meant to end
	if _at(4.4):
		_cam_goal = _player_view() + Vector2(0, -20)
		_zoom_goal = 1.25
		_cam_rate = 1.2
	for d in DIALOGUE:
		if _at(d[0]):
			_speak(d[1], d[2], d[3])
			if d[3]:
				_cam.add_trauma(0.5)
				SfxSynth.play(get_tree(), "rumble", -8.0, 1.3)
	# a shadow falls over the panel...
	if _t >= 19.6 and _t < T_ERASER:
		_shadow = _ease((_t - 19.6) / 1.6)
		_rumble = 0.4
	# ...and the Eraser slams down out of the sky
	if _at(T_ERASER):
		_eraser = Eraser.new()
		get_parent().add_child(_eraser)
		var ex := _player.global_position.x - 560.0 if _player else global_position.x
		ex = maxf(ex, barrier_x + 200.0)
		_eraser.global_position = Vector2(ex, fl - 1300.0)
		_eraser.set_harmful(false)
		_eraser.heading = 1.0
		_cam_goal = Vector2((ex + _player.global_position.x) * 0.5, fl - 240.0)
		_zoom_goal = 0.95
		SfxSynth.play(get_tree(), "whoosh", 0.0, 0.5)
	if _eraser and _t >= T_ERASER and _t < T_ERASER + 0.35:
		_eraser.global_position.y = lerpf(fl - 1300.0, fl, _ease((_t - T_ERASER) / 0.35))
	if _at(T_ERASER + 0.35):
		_eraser.global_position.y = fl
		_rumble = 0.0
		_shadow = 0.0
		_cam.add_trauma(1.0)
		SfxSynth.play(get_tree(), "thud", 3.0, 0.6)
		_say(_eraser.global_position + Vector2(0, -380), "WHAM!!", PAPER, 64)
		var dust := InkBits.burst(get_tree(), _eraser.global_position, 40, 520.0, Vector2.UP, 1.0)
		if dust:
			dust.modulate = Color(0.75, 0.75, 0.78)
	if _at(T_ERASER + 0.8):
		_eraser.roar = 1.0
		SfxSynth.play(get_tree(), "roar", 0.0, 1.5)
		_say(_eraser.global_position + Vector2(60, -360), "SKRRRRK!", Color(0.95, 0.5, 0.55), 48)
	if _eraser and _t >= T_ERASER + 0.8 and _t < T_RIP:
		_eraser.rubbing = 1.0 if _t < T_ERASER + 2.2 else 0.0
		_eraser.roar = maxf(_eraser.roar - get_process_delta_time() * 0.5, 0.0)
	# the panel's right-hand border rips open: the way out
	if _at(T_RIP):
		SfxSynth.play(get_tree(), "rip", 0.0, 0.9)
		_say(_east.global_position + Vector2(-40, -200), "RRRIP!", PAPER, 46)
		for i in 8:
			InkBits.burst(get_tree(), _east.global_position + Vector2(0, room_height * ((i + 0.5) / 8.0 - 0.5)), 6, 420.0, Vector2.RIGHT, 0.9)
	if _t >= T_RIP:
		_east_open = _ease((_t - T_RIP) / 0.5)
		_east_shape.disabled = _east_open > 0.3
	if _at(T_RUN):
		_say(_player.global_position + Vector2(0, -110), "RUN!", Color(1.0, 0.28, 0.22), 72)
		phase = Phase.CHASE
		_bars_goal = 0.0
		if _player and not _player.dead:
			_player.cutscene = false
			var pcam := _player.get_node_or_null("Camera2D") as Camera2D
			if pcam:
				pcam.make_current()
				pcam.reset_smoothing()
		var chase := get_node_or_null(chase_path)
		if chase:
			chase.begin(_eraser)


func _on_defeated() -> void:
	_flash = 1.0
	_cam.add_trauma(0.8)
	var state := get_node_or_null("/root/GameState")
	if state:
		state.seen["beast_dead"] = true


## beast.gd: a hit bounced off the shield.
func on_blocked() -> void:
	_blocked += 1


func _update_hint(delta: float) -> void:
	var state := get_node_or_null("/root/GameState")
	if _hint_t < 0.0:
		if _blocked >= 2 and not _any_lit() and not (state and state.seen.has("beast_hint")):
			_hint_t = 0.0
			if state:
				state.seen["beast_hint"] = true
			var best := 1.0e9
			for l in _lanterns:
				var d: float = l.global_position.distance_to(_player.global_position) if _player else 0.0
				if d < best:
					best = d
					_hint_lamp = l
		return
	_hint_t += delta
	if _hint_t > 7.0 or _any_lit():
		_hint_t = 99.0


# ------------------------------------------------------------------ helpers

## Stands the Beast on the floor at the gutter (`dx` along, `up` px off the floor: negative = higher).
func _place_beast(up: float, dx := 0.0) -> void:
	if _beast:
		_beast.global_position = Vector2(global_position.x + dx, global_position.y + up - _beast.body_size.y * 0.5)


func _beast_head() -> Vector2:
	return _beast.global_position + Vector2(_beast.facing * 20.0, -170.0)


func _player_view() -> Vector2:
	if _player == null:
		return _cam.global_position
	return _player.global_position + Vector2(0, -60)


func _any_lit() -> bool:
	for l in _lanterns:
		if l.lit:
			return true
	return false


func _snuff(i: int) -> void:
	if i >= _lanterns.size() or not _lanterns[i].lit:
		return
	_lanterns[i].lit = false
	SfxSynth.play(get_tree(), "splut", -4.0, 0.7)
	_say(_lanterns[i].lamp_position() + Vector2(0, -50), "PFFT...", Color(0.7, 0.72, 0.82), 26)


func _say(at: Vector2, text: String, col: Color, size: int) -> void:
	var p := ComicText.new()
	p.text = text
	p.color = col
	p.font_size = size
	p.position = at
	get_tree().current_scene.add_child(p)


func _show_caption(text: String, fury: bool) -> void:
	_caption = text
	_caption_t = 0.0
	_caption_fury = fury


## A line of the ending's dialogue: "shade" (his black balloon) or "vesper".
func _speak(who: String, text: String, fury: bool) -> void:
	_who = who
	_line = text
	_line_t = 0.0
	_line_fury = fury


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# ------------------------------------------------------------------ drawing

func _gutter_rect() -> Rect2:
	var hw := GUTTER_HALF * gap_open
	return Rect2(-hw, -room_height - 300.0, hw * 2.0, room_height + 900.0)


## The gutter between the columns: the Margins' dark, dead panels drifting
## up through it, a cold glow from far back. Behind the Beast.
func _draw_back(n: Node2D) -> void:
	if gap_open <= 0.01:
		return
	var r := _gutter_rect()
	_batch.draw_rect(r, VOID)
	for k in 5:
		var w := r.size.x * (0.9 - k * 0.15) * 0.5
		_batch.draw_rect(Rect2(-w, r.position.y, w * 2.0, r.size.y), Color(0.45, 0.6, 1.0, 0.03 * gap_open))
	# dead panels, far back in the dark, drifting up
	for i in 9:
		var y := r.position.y + fposmod(i * 160.0 - _time * 50.0, r.size.y)
		var w := r.size.x * (0.35 + 0.4 * fposmod(sin(i * 3.7) * 9.1, 1.0))
		var pr := Rect2(-w * 0.5 + sin(i * 2.1) * r.size.x * 0.15, y, w, 70.0 + 40.0 * fposmod(sin(i * 5.3) * 7.7, 1.0))
		_batch.draw_rect(pr, Color(0.55, 0.58, 0.68, 0.12 * gap_open), false, 1.5)
	_batch.flush(n)


## The panel borders either side of the gutter (in front of the Beast while
## it's still in there), the ink line that splits the panel, cracks where its
## claws grab, and the borders breaking as it tears out.
func _draw_front(n: Node2D) -> void:
	var top := -room_height - 300.0
	var bottom := 600.0
	if _split > 0.0 and gap_open <= 0.02:
		var y1 := lerpf(top, bottom, _split)
		_batch.draw_line(Vector2(0, top), Vector2(0, y1), INK, 7.0)
		_batch.draw_line(Vector2(2, top), Vector2(2, y1), Color(RIM, 0.6), 1.5)
		_batch.flush(n)
		return
	if gap_open <= 0.01:
		return
	var hw := GUTTER_HALF * gap_open
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0)
	for side: float in [-1.0, 1.0]:
		var x := side * hw
		var broken := _shatter > 0.0
		var y := top
		while y < bottom:
			var seg := 90.0
			var gap := (rng.randf() < 0.45) if broken else false
			if not gap:
				# the white paper edge right at the gutter, the panel's ink border outside it
				_batch.draw_line(Vector2(x, y), Vector2(x, y + seg), Color(RIM, 0.95), 3.0)
				_batch.draw_rect(Rect2(Vector2(x + side * 1.5 - (0.0 if side > 0.0 else 9.0), y), Vector2(9, seg)), INK)
			y += seg
		# cracks spreading from where the claws hold
		if _cracks > 0.0:
			for i in 5:
				var p := Vector2(x, -190.0 + rng.randf_range(-60, 60))
				var line := PackedVector2Array([p])
				var d := Vector2(side, rng.randf_range(-1.0, 1.0)).normalized()
				for k in 4:
					d = d.rotated(rng.randf_range(-0.6, 0.6))
					p += d * 20.0 * _cracks
					line.append(p)
				_batch.draw_polyline(line, Color(RIM, _cracks), 2.0)
	_batch.flush(n)


## The lanterns' light hitting the shield and splashing off it (intro).
func _draw_beams(n: Node2D) -> void:
	if phase != Phase.INTRO or _beast == null or not _beast.visible or _beast.shield_lift < 0.5:
		return
	var s: float = _beast.outline.scale.x
	var shield := _beast.global_position + Vector2(_beast.facing * 10.0 * s, _beast.body_size.y * 0.5 - 325.0 * s)
	for l in _lanterns:
		if not l.lit:
			continue
		var from: Vector2 = l.lamp_position() - n.global_position
		var to := shield - n.global_position
		var side := (to - from).orthogonal().normalized()
		_batch.draw_colored_polygon(PackedVector2Array([from - side * 6.0, to - side * 60.0 * s, to + side * 60.0 * s, from + side * 6.0]),
			Color(LIGHT, 0.12 + 0.05 * sin(_time * 20.0)))
	_batch.flush(n)


## "LIGHT IT!" over the nearest dark lantern, once a run.
func _draw_hint(n: Node2D) -> void:
	if _hint_t < 0.0 or _hint_t > 7.0 or _hint_lamp == null:
		return
	var at: Vector2 = _hint_lamp.lamp_position() - n.global_position + Vector2(0, -80 + sin(_time * 5.0) * 6.0)
	var a := clampf(_hint_t / 0.3, 0.0, 1.0) * clampf((7.0 - _hint_t) / 0.5, 0.0, 1.0)
	var text := "LIGHT IT!"
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	n.draw_string_outline(FONT, at + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(INK, a))
	n.draw_string(FONT, at + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(CAPTION, a))
	n.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 12), at + Vector2(10, 12), at + Vector2(0, 26)]), Color(CAPTION, a))


## The wall of scribble that seals the way back during the fight.
func _draw_barrier(n: Node2D) -> void:
	if _barrier_up <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0) * 31
	var h := room_height * _ease(_barrier_up)
	var bottom := room_height * 0.5
	for i in 26:
		var line := PackedVector2Array()
		var y := bottom
		var x := rng.randf_range(-26, 26)
		while y > bottom - h:
			line.append(Vector2(x, y))
			y -= rng.randf_range(20, 60)
			x = clampf(x + rng.randf_range(-30, 30), -30, 30)
		if line.size() > 1:
			_batch.draw_polyline(line, INK, rng.randf_range(2.0, 4.5))
	for i in 12:
		var y := bottom - rng.randf() * h
		_batch.draw_line(Vector2(-30, y), Vector2(30, y + rng.randf_range(-20, 20)), Color(RIM, 0.35), 1.2)
	_batch.flush(n)


func _draw_ui() -> void:
	var size := _ui.size
	# letterbox
	if _bars > 0.0:
		var bh := 74.0 * _ease(_bars)
		_ui.draw_rect(Rect2(0, 0, size.x, bh), Color.BLACK)
		_ui.draw_rect(Rect2(0, size.y - bh, size.x, bh), Color.BLACK)
	if phase == Phase.INTRO and not _short:
		var a := clampf(_t - 1.0, 0.0, 1.0) * 0.55
		var tw := FONT.get_string_size("ENTER  SKIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_ui.draw_string(FONT, Vector2(size.x - tw - 30, size.y - 28), "ENTER  SKIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, a))
	if _shadow > 0.0:
		# the Eraser's shadow falling over the panel from above
		var sh := size.y * 0.9 * _shadow
		_ui.draw_rect(Rect2(0, 0, size.x, sh), Color(0, 0, 0, 0.45 * _shadow))
	_draw_fury(size)
	_draw_title(size)
	_draw_caption(size)
	_draw_line(size)
	_draw_boss_bar(size)
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 0.85))


## Shade, furious (the ending): the panel pulses red and his pen slashes
## angry scratches across it, a few at a time at 12 fps.
func _draw_fury(size: Vector2) -> void:
	if not _line_fury or _line_t < 0.0 or _who != "shade":
		return
	var total := _line_dur()
	var a := clampf(_line_t / 0.3, 0.0, 1.0) * clampf((total - _line_t) / 0.5, 0.0, 1.0)
	if a <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 9.0)
	_ui.draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.0, 0.0, (0.08 + 0.08 * pulse) * a))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0) * 97
	for i in 3:
		if rng.randf() > 0.55:
			continue
		var from := Vector2(rng.randf_range(-100, size.x * 0.4), rng.randf_range(80, size.y - 80))
		var line := PackedVector2Array([from])
		var p := from
		var d := Vector2.from_angle(rng.randf_range(-0.5, 0.5))
		for k in 6:
			d = (-d if k % 2 else d).rotated(rng.randf_range(-0.3, 0.3))
			p += Vector2(rng.randf_range(120, 260), rng.randf_range(-70, 70)) * Vector2(1, 1 if k % 2 else -1)
			line.append(p)
		_ui.draw_polyline(line, Color(INK, 0.55 * a), rng.randf_range(3.0, 7.0))


func _draw_title(size: Vector2) -> void:
	if _title < 0.0:
		return
	var slam := clampf(_title / 0.18, 0.0, 1.0)
	var scale := lerpf(2.4, 1.0, _ease(slam))
	var a := slam * clampf((3.2 - _title) / 0.5, 0.0, 1.0)
	var center := Vector2(size.x * 0.5, size.y * 0.72)
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) * (1.0 - clampf((_title - 0.18) / 0.4, 0.0, 1.0))
	# an ink splat behind the name
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var splat := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		var r := (rng.randf_range(0.75, 1.0) if i % 2 else rng.randf_range(0.9, 1.25))
		splat.append(center + shake + Vector2(cos(ang) * 380.0 * r, sin(ang) * 70.0 * r) * scale)
	_ui.draw_colored_polygon(splat, Color(0, 0, 0, 0.75 * a))
	var title := "THE SCRIBBLED BEAST"
	var fs := int(88 * scale)
	var w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := center + shake + Vector2(-w * 0.5, fs * 0.3)
	_ui.draw_set_transform(center, -0.03, Vector2.ONE)
	_ui.draw_string_outline(FONT, base - center, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(INK, a))
	_ui.draw_string(FONT, base - center, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAPER, a))
	var sub := "IT CRAWLED OUT OF THE GUTTER"
	var sw := FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var sb := Vector2(-sw * 0.5, fs * 0.3 + 44)
	_ui.draw_string_outline(FONT, sb, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(INK, a))
	_ui.draw_string(FONT, sb, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.35, 0.28, a))
	_ui.draw_set_transform(Vector2.ZERO)


## The Writer's caption (narration.gd's yellow box); furious, it turns red
## and shakes.
func _draw_caption(_size: Vector2) -> void:
	if _caption_t < 0.0:
		return
	var lps := 30.0 if _caption_fury else 38.0
	var shown := int(maxf(_caption_t - 0.15, 0.0) * lps)
	var total := _caption.length() / lps + 2.2
	var a := clampf(_caption_t / 0.2, 0.0, 1.0) * clampf((total - _caption_t) / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	var fs := 34 if _caption_fury else 30
	var lines := _wrap(_caption, fs, 760.0)
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var lh := fs * 1.2
	var box := Rect2(48, 104, widest + 34, lh * lines.size() + 22)
	var shake := Vector2.ZERO
	if _caption_fury:
		shake = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	_ui.draw_set_transform(shake, -0.015 if not _caption_fury else -0.03)
	_ui.draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(INK, 0.35 * a))
	_ui.draw_rect(box.grow(3.0), Color(INK, a))
	_ui.draw_rect(box, Color(FURY if _caption_fury else CAPTION, a))
	var left := shown
	for i in lines.size():
		var line: String = lines[i]
		var part := line.substr(0, clampi(left, 0, line.length()))
		var jig := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) if _caption_fury else Vector2.ZERO
		_ui.draw_string(FONT, box.position + Vector2(16, 12 + lh * (i + 0.8)) + jig, part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(PAPER if _caption_fury else INK, a))
		left -= line.length() + 1
	_ui.draw_set_transform(Vector2.ZERO)


func _wrap(s: String, fs: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var test := word if line == "" else line + " " + word
		if FONT.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


## The boss bar: the name over a long, scratchy ink-framed bar.
func _draw_boss_bar(size: Vector2) -> void:
	if _bar_shown <= 0.0 or _beast == null or not is_instance_valid(_beast):
		return
	var a := _ease(_bar_shown)
	var w := 620.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 54, w, 18)
	r.position.y += (1.0 - a) * 60.0
	var frac := clampf(float(_beast.health) / _beast.max_hp, 0.0, 1.0) * minf(_bar_shown * 1.6, 1.0)
	var name := "THE SCRIBBLED BEAST"
	var nw := FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_ui.draw_string_outline(FONT, Vector2(size.x * 0.5 - nw * 0.5, r.position.y - 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color(INK, a))
	_ui.draw_string(FONT, Vector2(size.x * 0.5 - nw * 0.5, r.position.y - 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(PAPER, a))
	_ui.draw_rect(r.grow(4.0), Color(INK, a))
	_ui.draw_rect(r, Color(0.12, 0.1, 0.14, a))
	_ui.draw_rect(Rect2(r.position, Vector2(r.size.x * _bar_lag, r.size.y)), Color(1.0, 0.85, 0.75, 0.6 * a))
	_ui.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(BAR_RED, a))
	# scratchy hatching over the fill, re-drawn at 12 fps
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0)
	var x := r.position.x + 4.0
	while x < r.position.x + r.size.x * frac - 4.0:
		_ui.draw_line(Vector2(x, r.end.y - 2), Vector2(x + 7 + rng.randf_range(-2, 2), r.position.y + 2), Color(0.45, 0.04, 0.06, a), 1.5)
		x += 9.0
	if _beast.phase_two:
		_ui.draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 1, r.position.y - 3, 2, r.size.y + 6), Color(INK, a))


## The arena's right-hand panel border: a thick ink frame line; for the chase
## it rips open, its pieces falling away.
func _draw_east(n: Node2D) -> void:
	var h := room_height
	if _east_open >= 1.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := 1.0 - _east_open
	var pieces := 9
	for i in pieces:
		var y0 := -h * 0.5 + h * i / pieces
		var y1 := y0 + h / pieces
		var fall := _east_open * (200.0 + 500.0 * rng.randf())
		var drift := _east_open * rng.randf_range(20, 120)
		var off := Vector2(drift, fall)
		var rot := _east_open * rng.randf_range(-0.6, 0.6)
		var c := Vector2(0, (y0 + y1) * 0.5) + off
		var pts := PackedVector2Array([Vector2(-10, y0), Vector2(10, y0 + rng.randf_range(-8, 8)), Vector2(10, y1), Vector2(-10, y1 + rng.randf_range(-8, 8))])
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(c + (p - Vector2(0, (y0 + y1) * 0.5)).rotated(rot))
		_batch.draw_colored_polygon(moved, Color(INK, a))
		_batch.draw_line(moved[0] + Vector2(-2, 0), moved[3] + Vector2(-2, 0), Color(RIM, 0.8 * a), 2.0)
	_batch.flush(n)


func _line_dur() -> float:
	return 1.2 + _line.length() / 30.0


## The ending's dialogue: Shade's black balloon (top centre, red letters,
## shaking when he's furious) or Vesper's own white balloon over his head.
func _draw_line(size: Vector2) -> void:
	if _line_t < 0.0 or _line == "":
		return
	var dur := _line_dur()
	var a := clampf(_line_t / 0.2, 0.0, 1.0) * clampf((dur - _line_t) / 0.3, 0.0, 1.0)
	if a <= 0.0:
		return
	var shown := _line.substr(0, int(_line_t * 32.0))
	if _who == "shade":
		var fs := 34 if _line_fury else 30
		var lines := _wrap(_line, fs, 820.0)
		var widest := 0.0
		for l in lines:
			widest = maxf(widest, FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var lh := fs * 1.2
		var box := Rect2(size.x * 0.5 - widest * 0.5 - 30.0, 96.0, widest + 60.0, lh * lines.size() + 26.0)
		if _line_fury:
			box.position += Vector2(randf_range(-3, 3), randf_range(-3, 3))
		_ui.draw_rect(box.grow(4.0), Color(0.85, 0.2, 0.25, a))
		_ui.draw_rect(box, Color(0.02, 0.01, 0.04, a))
		var left := shown.length()
		for i in lines.size():
			var line: String = lines[i]
			var part := line.substr(0, clampi(left, 0, line.length()))
			var jig := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) if _line_fury else Vector2.ZERO
			_ui.draw_string(FONT, box.position + Vector2(30, 14 + lh * (i + 0.8)) + jig, part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.88, a))
			left -= line.length() + 1
		_ui.draw_string(FONT, box.position + Vector2(box.size.x - 92, box.size.y + 24), "- SHADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.35, 0.4, a))
	elif _player:
		var fs := 28
		var w := FONT.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var head := get_viewport().get_canvas_transform() * (_player.global_position + Vector2(0, -60))
		var box := Rect2(head + Vector2(-w * 0.5 - 20 + 40, -110), Vector2(w + 40, 50))
		_ui.draw_colored_polygon(PackedVector2Array([Vector2(box.position.x + 30, box.end.y - 2), Vector2(box.position.x + 58, box.end.y - 2),
			head + Vector2(6, -14)]), Color(1, 1, 1, a))
		_ui.draw_rect(box.grow(3.0), Color(INK, a))
		_ui.draw_rect(box, Color(1, 1, 1, a))
		_ui.draw_string(FONT, box.position + Vector2(20, 35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, a))


## Where the cutscene camera takes over from the player's: what it was showing,
## unless that's stale (far from Vesper, e.g. just after a respawn).
func _view_from(pcam: Camera2D) -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var here := p.global_position + Vector2(0, -60) if p else global_position
	if pcam == null:
		return here
	var c := pcam.get_screen_center_position()
	return c if c.distance_to(here) < 600.0 else here
