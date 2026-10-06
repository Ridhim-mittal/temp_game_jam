extends Node2D
## The Scribbled Beast's arena at the bottom of the Long Drop: runs the
## intro, the fight and the ending around scribbled_beast.gd. The node sits on
## the arena floor at the tear the beast climbs out of (the gutter, showing
## through a rip in the page).
##
## Intro (about 14 s, once a run; Enter skips): Vesper walks in and the
## controls are taken (player.gd `cutscene`), letterbox bars, the floor
## rumbles and the camera pans to the tear; it rips open, the gutter's dark
## beneath; the SHIELD punches up first, held over its head against the
## lanterns' light (the light splashes off it); claws grab the lip and the
## Beast hauls itself out; the lanterns die as its darkness passes them; the
## camera pushes in, three eyes open one by one, it ROARS, the title card
## slams in; the Writer: "That wasn't supposed to get out." / "...Fine. You
## were never meant to leave this page anyway, Vesper." Back to Vesper, a
## wall of scribble seals the way back, the boss bar fills, fight. On a retry
## (after dying) a short version plays (about 3 s).
##
## Fight: a boss bar (bottom), and after a few blocked hits with no lantern
## lit, a "LIGHT IT!" tag over the nearest dark lantern (once a run).
##
## Ending: the Beast dying (light through its cracking shield, it unravels)
## is framed by the camera; then the Writer, furious (a shaking red caption):
## "No. No, no, no." / "That is NOT how this page ends." The wall comes down
## and a way on opens (level_exit.gd) until the Eraser's chase is built.

const InkBits = preload("res://scripts/effects/ink_bits.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const GameCamera = preload("res://scripts/camera/game_camera.gd")
const LevelExit = preload("res://scripts/world/level_exit.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const CAPTION := Color(1.0, 0.9, 0.45)
const FURY := Color(0.95, 0.32, 0.25)
const PAPER := Color(0.93, 0.9, 0.82)
const RIM := Color(0.86, 0.92, 1.0)
const VOID := Color(0.006, 0.006, 0.014)
const ROCK := Color(0.015, 0.02, 0.045)
const LIGHT := Color(1.0, 0.92, 0.6)
const BAR_RED := Color(0.78, 0.12, 0.12)
const SHAFT_HALF := 150.0
const SHAFT_DEPTH := 640.0
const LINES_INTRO := ["THAT WASN'T SUPPOSED TO GET OUT.", "...FINE. YOU WERE NEVER MEANT TO LEAVE THIS PAGE ANYWAY, VESPER."]
const LINES_END := ["NO. NO, NO, NO.", "THAT IS NOT HOW THIS PAGE ENDS."]

enum Phase { WAIT, INTRO, FIGHT, OUTRO, DONE }

@export var beast_path: NodePath
@export var lantern_paths: Array[NodePath] = []
## The intro starts once Vesper is right of this x (world).
@export var trigger_x := 0.0
## Where the wall of scribble seals the way back (world x).
@export var barrier_x := 0.0
## How high the room is above the floor (px), for the wall.
@export var room_height := 1000.0
@export_file("*.tscn") var exit_target := "res://scenes/ui/main_menu.tscn"
@export var exit_label := "THE END OF THE DROP"
## Where the way on opens after the fight (world x on this floor).
@export var exit_x := 0.0

var phase := Phase.WAIT
## How far the tear is open: 0.12 a seam in the floor, 1 the shaft the Beast climbs.
var gap_open := 0.12

var _t := 0.0
var _short := false
var _fired := {}
var _beast: Node2D
var _lanterns: Array = []
var _player: Node2D
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
var _bars := 0.0
var _bars_goal := 0.0
var _title := -1.0
var _caption := ""
var _caption_t := -1.0
var _caption_fury := false
var _bar_shown := 0.0
var _bar_lag := 1.0
var _blocked := 0
var _hint_t := -1.0
var _hint_lamp: Node2D
var _flash := 0.0
var _rumble := 0.0
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
		# already beaten this run (a retry from the pause menu): the way on is open
		phase = Phase.DONE
		if _beast:
			_beast.queue_free()
			_beast = null
		_open_exit()
		return
	_short = state != null and state.seen.has("beast_intro")
	if _beast:
		_beast.gap_x = global_position.x
		_beast.arena_lanterns = _lanterns
		_beast.visible = false
		_place_beast(SHAFT_DEPTH)
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
		Phase.OUTRO:
			_t += delta
			_outro()
	# smooth camera, letterbox, wall, bar
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
	_back.queue_redraw()
	_front.queue_redraw()
	_beams.queue_redraw()
	_hint.queue_redraw()
	_ui.queue_redraw()
	for c in _barrier.get_children():
		if c is Node2D:
			c.queue_redraw()


## Fires once when the scene's clock passes `time`.
func _at(time: float) -> bool:
	if _t >= time and not _fired.has(time):
		_fired[time] = true
		return true
	return false


func _input(event: InputEvent) -> void:
	if phase != Phase.INTRO or _short:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_skip_intro()


func _start_intro() -> void:
	phase = Phase.INTRO
	_t = 0.0
	_fired.clear()
	_player.cutscene = true
	var pcam := _player.get_node_or_null("Camera2D") as Camera2D
	_cam.global_position = pcam.get_screen_center_position() if pcam else _player.global_position
	_cam.zoom = Vector2.ONE
	_cam_goal = _cam.global_position
	_zoom_goal = 1.0
	_cam_rate = 2.2
	_cam.make_current()
	_bars_goal = 1.0


func _intro_long() -> void:
	var fl := global_position.y
	var gx := global_position.x
	if _at(0.4):
		_rumble = 0.35
		SfxSynth.play(get_tree(), "rumble", -2.0)
		_say(Vector2(gx - 260, fl - 330), "RMMBL...", RIM, 30)
	if _t > 0.4 and _t < 2.4 and fmod(_t, 0.2) < get_process_delta_time():
		InkBits.burst(get_tree(), Vector2(gx + randf_range(-500, 500), fl - room_height + 40), 3, 80.0, Vector2.DOWN, 0.6)
	if _at(0.8):
		_cam_goal = Vector2(gx, fl - 150)
		_zoom_goal = 1.0  # wide: the tear and both lanterns in frame
		_cam_rate = 1.6
	if _t >= 2.2 and _t < 2.8:
		gap_open = lerpf(0.12, 1.0, _ease((_t - 2.2) / 0.6))
	if _at(2.2):
		SfxSynth.play(get_tree(), "rip", 0.0)
		_say(Vector2(gx + 120, fl - 120), "RRRIIIP!", PAPER, 44)
		InkBits.burst(get_tree(), Vector2(gx, fl), 40, 520.0, Vector2.UP, 0.8)
		_cam.add_trauma(0.5)
	# the shield first, held up over its head against the light
	if _at(2.85):
		_beast.visible = true
		_beast.shield_lift = 1.0
		_beast.eyes_open = [0.0, 0.0, 0.0]
		_beast.facing = -1 if _player.global_position.x < gx else 1
	if _t >= 2.85 and _t < 3.25:
		_place_beast(lerpf(SHAFT_DEPTH, 300.0, _ease((_t - 2.85) / 0.4)))
		_beast.light_on_shield = 1.0 if _any_lit() else 0.0
	if _at(3.1):
		_rumble = 0.0
		_cam.add_trauma(0.7)
		SfxSynth.play(get_tree(), "thud", 0.0, 0.7)
		_say(Vector2(gx - 150, fl - 260), "KRAKK!", RIM, 40)
		InkBits.burst(get_tree(), Vector2(gx, fl - 20), 30, 600.0, Vector2.UP, 0.6)
	# claws on the lip, then it hauls itself up in three heaves
	if _t >= 3.4 and _t < 4.9:
		var k := (_t - 3.4) / 1.5
		var heave := (floorf(k * 3.0) + _ease(fmod(k * 3.0, 1.0))) / 3.0
		_place_beast(lerpf(300.0, 30.0, heave))
		_beast.grip = clampf((_t - 3.4) / 0.2, 0.0, 1.0) * (1.0 - clampf((_t - 4.6) / 0.3, 0.0, 1.0))
		_beast.grip_point = Vector2(gx - 160.0 * _beast.facing * -1.0, fl - 6.0)
	if _at(3.4) or _at(3.9) or _at(4.4):
		SfxSynth.play(get_tree(), "scritch", -4.0, randf_range(0.6, 0.8))
		_cam.add_trauma(0.25)
	# its darkness puts the lanterns out as it rises
	if _at(4.0):
		_snuff(0)
	if _at(4.45):
		_snuff(1)
	if _t >= 4.0:
		_beast.light_on_shield = move_toward(_beast.light_on_shield, 1.0 if _any_lit() else 0.0, 0.1)
	# out onto the floor
	if _t >= 4.9 and _t < 5.35:
		var k := (_t - 4.9) / 0.45
		_place_beast(lerpf(30.0, 0.0, k) - sin(k * PI) * 46.0)
	if _at(5.35):
		_place_beast(0.0)
		SfxSynth.play(get_tree(), "thud", 2.0)
		_cam.add_trauma(0.6)
		InkBits.burst(get_tree(), Vector2(gx, fl), 20, 380.0, Vector2.UP, 0.3)
	if _t >= 5.35 and _t < 6.3:
		gap_open = lerpf(1.0, 0.12, _ease((_t - 5.35) / 0.95))
	# push in on it; the eyes open one at a time
	if _at(5.6):
		_cam_goal = _beast_head()
		_zoom_goal = 1.75
		_cam_rate = 2.4
	for i in 3:
		var t0: float = [6.0, 6.3, 6.6][i]
		if _t >= t0:
			_beast.eyes_open[i] = clampf((_t - t0) / 0.12, 0.0, 1.0)
		if _at(t0):
			SfxSynth.play(get_tree(), "scritch", -10.0, 1.6 + i * 0.2)
	# the shield comes down, and it roars
	if _t >= 6.9 and _t < 7.2:
		_beast.shield_lift = 1.0 - _ease((_t - 6.9) / 0.3)
	if _at(7.05):
		SfxSynth.play(get_tree(), "roar", 2.0)
		_rumble = 0.9
		_say(_beast_head() + Vector2(-_beast.facing * 40.0, -40.0), "GRRRAAAAHHH!!", Color(1.0, 0.25, 0.18), 54)
	if _t >= 7.05 and _t < 8.6:
		_beast.roar = clampf((_t - 7.05) / 0.2, 0.0, 1.0) * (1.0 - clampf((_t - 8.3) / 0.3, 0.0, 1.0))
		if fmod(_t, 0.1) < get_process_delta_time():
			InkBits.burst(get_tree(), _beast_head() + Vector2(_beast.facing * 30, 10), 3, 420.0, Vector2(_beast.facing, 0.2), 0.0)
	if _at(7.4):
		_title = 0.0
		Sfx.play("boss_intro")
		_cam_goal = _beast_head() + Vector2(0, 60)
		_zoom_goal = 1.35
		_cam_rate = 1.4
	if _at(8.6):
		_rumble = 0.0
		_beast.roar = 0.0
	if _at(9.2):
		_show_caption(LINES_INTRO[0], false)
	if _at(11.1):
		_show_caption(LINES_INTRO[1], false)
	if _at(13.9):
		_cam_goal = _player_view()
		_zoom_goal = 1.0
		_cam_rate = 2.4
	if _at(14.8):
		_start_fight()


func _intro_short() -> void:
	var fl := global_position.y
	var gx := global_position.x
	if _at(0.0):
		_cam_goal = Vector2(gx, fl - 150)
		_zoom_goal = 1.0
		_cam_rate = 3.0
	if _t < 0.4:
		gap_open = lerpf(0.12, 1.0, _ease(_t / 0.4))
	if _at(0.2):
		SfxSynth.play(get_tree(), "rip", -2.0)
		_beast.visible = true
		_beast.shield_lift = 1.0
		_beast.facing = -1 if _player.global_position.x < gx else 1
	if _t >= 0.3 and _t < 1.1:
		var k := (_t - 0.3) / 0.8
		_place_beast(lerpf(SHAFT_DEPTH, 0.0, _ease(k)) - sin(k * PI) * 40.0)
	if _at(1.1):
		_place_beast(0.0)
		SfxSynth.play(get_tree(), "thud", 2.0)
		_cam.add_trauma(0.6)
	if _t >= 1.1 and _t < 1.6:
		gap_open = lerpf(1.0, 0.12, (_t - 1.1) / 0.5)
		_beast.shield_lift = 1.0 - (_t - 1.1) / 0.5
	if _at(1.4):
		SfxSynth.play(get_tree(), "roar", -2.0, 1.1)
		_cam.add_trauma(0.7)
	if _t >= 1.4 and _t < 2.4:
		_beast.roar = 1.0 - clampf((_t - 2.1) / 0.3, 0.0, 1.0)
	if _at(2.2):
		_cam_goal = _player_view()
		_zoom_goal = 1.0
	if _at(2.9):
		_start_fight()


func _skip_intro() -> void:
	for l in _lanterns:
		l.lit = false
	gap_open = 0.12
	_beast.visible = true
	_beast.facing = -1 if _player.global_position.x < global_position.x else 1
	_place_beast(0.0)
	_beast.grip = 0.0
	_beast.light_on_shield = 0.0
	_title = -1.0
	_caption_t = -1.0
	_rumble = 0.0
	_start_fight()


func _start_fight() -> void:
	phase = Phase.FIGHT
	gap_open = 0.12  # the page knits shut behind it
	_bars_goal = 0.0
	_rumble = 0.0
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


func _start_outro() -> void:
	phase = Phase.OUTRO
	_t = 0.0
	_fired.clear()
	if _player and not _player.dead:
		_player.cutscene = true
	var pcam := _player.get_node_or_null("Camera2D") as Camera2D if _player else null
	_cam.global_position = pcam.get_screen_center_position() if pcam else _beast.global_position
	_cam.zoom = Vector2.ONE
	_cam_goal = _beast.global_position + Vector2(0, -60)
	_zoom_goal = 1.35
	_cam_rate = 2.0
	_cam.make_current()
	_bars_goal = 1.0


func _outro() -> void:
	if _at(0.2):
		_rumble = 0.25
	if _t > 3.6 and _t < 3.8:
		_rumble = 0.0
	if _at(6.0):
		_cam.add_trauma(0.9)
		_show_caption(LINES_END[0], true)
		SfxSynth.play(get_tree(), "rumble", 0.0, 0.8)
	if _at(8.2):
		_cam.add_trauma(1.0)
		_show_caption(LINES_END[1], true)
	if _at(11.0):
		_cam_goal = _player_view()
		_zoom_goal = 1.0
	if _at(11.8):
		phase = Phase.DONE
		_bars_goal = 0.0
		if _player and not _player.dead:
			_player.cutscene = false
			var pcam := _player.get_node_or_null("Camera2D") as Camera2D
			if pcam:
				pcam.make_current()
				pcam.reset_smoothing()
		_open_exit()


func _on_defeated() -> void:
	_flash = 1.0
	_cam.add_trauma(0.8)
	var state := get_node_or_null("/root/GameState")
	if state:
		state.seen["beast_dead"] = true


func _open_exit() -> void:
	var ex: Area2D = LevelExit.new()
	ex.target_scene = exit_target
	ex.label = exit_label
	get_parent().add_child(ex)
	ex.global_position = Vector2(exit_x if exit_x != 0.0 else global_position.x + 500.0, global_position.y)
	InkBits.burst(get_tree(), ex.global_position + Vector2(0, -60), 24, 300.0, Vector2.ZERO, 0.8)


## beast.gd: a hit bounced off the shield.
func on_blocked() -> void:
	_blocked += 1


func _update_hint(delta: float) -> void:
	var state := get_node_or_null("/root/GameState")
	if _hint_t < 0.0:
		if _blocked >= 4 and not _any_lit() and not (state and state.seen.has("beast_hint")):
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

func _place_beast(depth: float) -> void:
	if _beast:
		_beast.global_position = Vector2(global_position.x, global_position.y + depth - _beast.body_size.y * 0.5)


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


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# ------------------------------------------------------------------ drawing

## The shaft under the tear: the gutter's dark, white panel lines falling
## away into it, a cold glow from far below. Behind the Beast.
func _draw_back(n: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0)
	if gap_open <= 0.14:
		_draw_seam(n, rng)
		return
	var hw := lerpf(10.0, SHAFT_HALF, gap_open)
	var pts := PackedVector2Array([Vector2(-hw, 0)])
	for i in 8:
		var y := SHAFT_DEPTH * (i + 1) / 8.0
		pts.append(Vector2(-hw + rng.randf_range(-8, 8) * gap_open - y * 0.04, y))
	for i in range(8, 0, -1):
		var y := SHAFT_DEPTH * i / 8.0
		pts.append(Vector2(hw + rng.randf_range(-8, 8) * gap_open + y * 0.04, y))
	pts.append(Vector2(hw, 0))
	_batch.draw_colored_polygon(pts, VOID)
	# cold glow welling up from the deep
	for k in 5:
		var w := hw * (1.0 - k * 0.15)
		_batch.draw_rect(Rect2(-w, 40 + k * 90, w * 2, SHAFT_DEPTH - 40 - k * 90), Color(0.5, 0.65, 1.0, 0.035 * gap_open))
	# the Margins: panel borders falling away down there
	if gap_open > 0.3:
		var a := (gap_open - 0.3) / 0.7
		for i in 4:
			var y := 80.0 + i * 130.0 + fmod(_time * 30.0, 130.0)
			var w := hw * (0.9 - i * 0.12)
			_batch.draw_rect(Rect2(-w, y, w * 2.0, 90), Color(RIM, 0.0), false)
			var r := PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(w, y + 90), Vector2(-w, y + 90), Vector2(-w, y)])
			_batch.draw_polyline(r, Color(RIM, 0.18 * a * (1.0 - i * 0.2)), 1.5)
	_batch.flush(n)


## Closed, the tear is only a seam in the page: a jagged crack along the floor
## with a cold light breathing out of it (the floor stays solid).
func _draw_seam(n: Node2D, rng: RandomNumberGenerator) -> void:
	var glow := 0.3 + 0.15 * sin(_time * 2.5)
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var x := -90.0 + 180.0 * i / steps
		pts.append(Vector2(x, 3.0 + (rng.randf_range(0, 3) if i % 2 else 0.0)))
	for i in range(steps, -1, -1):
		var x := -90.0 + 180.0 * i / steps
		var depth := 9.0 * (1.0 - absf(x) / 90.0)
		pts.append(Vector2(x, 4.0 + depth))
	_batch.draw_colored_polygon(pts, VOID)
	_batch.draw_polyline(pts.slice(0, steps + 1), Color(0.6, 0.75, 1.0, glow), 1.6)
	for k in 3:
		_batch.draw_circle(Vector2(0, 2), 40.0 + k * 30.0, Color(0.5, 0.65, 1.0, 0.02 * glow))
	_batch.flush(n)


## The rock either side of the shaft, in front of the Beast (it hides what of
## it is still underground), and the torn edges of the page curling down into
## the tear. Only while the tear is open; closed, it is just a seam.
func _draw_front(n: Node2D) -> void:
	if gap_open <= 0.14:
		return
	var hw := lerpf(10.0, SHAFT_HALF, gap_open)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0)
	for side: float in [-1.0, 1.0]:
		var inner := PackedVector2Array()
		inner.append(Vector2(side * hw, 10))
		for i in 8:
			var y := SHAFT_DEPTH * (i + 1) / 8.0
			inner.append(Vector2(side * (hw + y * 0.04 + rng.randf_range(-8, 8) * gap_open), y))
		inner.append(Vector2(side * (SHAFT_HALF + 170.0), SHAFT_DEPTH + 40.0))
		inner.append(Vector2(side * (SHAFT_HALF + 170.0), 10))
		_batch.draw_colored_polygon(inner, ROCK)
		# the page's torn edge: a ragged paper lip hanging down into the tear
		var lip := PackedVector2Array()
		var steps := 7
		for i in steps + 1:
			var x := side * (hw + 40.0 - 40.0 * i / steps)
			lip.append(Vector2(x, 1.0 + (rng.randf_range(0, 5) if i % 2 else 0.0)))
		for i in range(steps, -1, -1):
			var x := side * (hw + 40.0 - 40.0 * i / steps)
			lip.append(Vector2(x, 4.0 + (i / float(steps)) * 14.0 * gap_open + rng.randf_range(-2, 4)))
		_batch.draw_colored_polygon(lip, Color(PAPER, 0.55))
		_batch.draw_polyline(lip, Color(INK, 0.9), 1.2)
	_batch.flush(n)


## The lanterns' light hitting the shield and splashing off it (intro).
func _draw_beams(n: Node2D) -> void:
	if phase != Phase.INTRO or _beast == null or not _beast.visible or _beast.shield_lift < 0.5:
		return
	var shield := _beast.global_position + Vector2(_beast.facing * 10.0, _beast.body_size.y * 0.5 - 325.0)
	for l in _lanterns:
		if not l.lit:
			continue
		var from: Vector2 = l.lamp_position() - n.global_position
		var to := shield - n.global_position
		var side := (to - from).orthogonal().normalized()
		_batch.draw_colored_polygon(PackedVector2Array([from - side * 6.0, to - side * 60.0, to + side * 60.0, from + side * 6.0]),
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
	_draw_fury(size)
	_draw_title(size)
	_draw_caption(size)
	_draw_boss_bar(size)
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 0.85))


## The Writer, furious (the ending): the panel pulses red and his pen slashes
## angry scratches across it, a few at a time at 12 fps.
func _draw_fury(size: Vector2) -> void:
	if not _caption_fury or _caption_t < 0.0:
		return
	var total := _caption.length() / 30.0 + 2.2
	var a := clampf(_caption_t / 0.3, 0.0, 1.0) * clampf((total - _caption_t) / 0.5, 0.0, 1.0)
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
