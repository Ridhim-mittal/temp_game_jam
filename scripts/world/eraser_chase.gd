extends Node2D
## The Eraser's chase: the end of the Long Drop, after the Scribbled Beast.
## Shade sends SHADE'S ERASER (shade_eraser.gd) to rub Vesper out, and he
## runs. Everything behind the Eraser is rubbed back to blank paper (drawn
## here over the level); the corridor ahead has a few easy hops. The Eraser
## keeps up (it speeds up when it falls far behind and eases off when it's on
## his heels), so it's always there, but anyone who keeps running gets away;
## touching it costs half a bottle and throws him forward. It is a wall too:
## nothing gets past it into the rubbed-out paper (not a dash, not a jump over
## it); run back into it and it bounces him off, forward (`_hold_back()`).
## The corridor ends where its panel ends: the gutter, the dark gap between
## the columns of the page (drawn at `end_x`, a real pit). Near it the
## controls go (player.gd `cutscene` + `cutscene_run`): Vesper sprints for the
## edge, the Eraser lunges ("THE END."), he leaps into the gap and falls, and
## margins_fall.gd takes over: the fall into the Margins.
## Started by beast_arena.gd begin(), with the Eraser it dropped in; on a
## retry (beast beaten this run, dead in the chase) it starts by itself once
## Vesper sets off from the corridor's checkpoint.

const InkBits = preload("res://scripts/effects/ink_bits.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const Eraser = preload("res://scripts/enemies/shade_eraser.gd")
const MarginsFall = preload("res://scripts/effects/margins_fall.gd")
const GameCamera = preload("res://scripts/camera/game_camera.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const CaptionStyle = preload("res://scripts/ui/caption_style.gd")
const PAPER := Color(0.95, 0.93, 0.87)
const SMUDGE := Color(0.72, 0.7, 0.68)
const INK := Color(0.04, 0.03, 0.07)
const VOID := Color(0.01, 0.01, 0.02)
const RIM := Color(0.92, 0.94, 1.0)

enum Phase { WAIT, CHASE, FINALE, DONE }

## Where the page ends and the gutter opens (world x; the pit's middle).
@export var end_x := 0.0
## The gutter's half width.
@export var gutter_half := 125.0
## Where the rubbing-out starts (world x): everything from here to the
## Eraser goes blank.
@export var erase_from := 0.0
## The corridor's ceiling (world y), for the drawings.
@export var room_top := -800.0
@export var speed := 250.0
## How hard the Eraser bounces him off when he runs into it (px/s: forward, up).
@export var bounce := Vector2(560, -380)

var phase := Phase.WAIT
var eraser: Node2D

var _t := 0.0
var _erase_x := -1.0e9
var _player: Node2D
var _cam: Camera2D
var _layer: CanvasLayer
var _ui: Control
var _gutter: Node2D
var _paper: Node2D
var _bars := 0.0
var _line := ""
var _line_t := -1.0
var _leapt := false
var _fell := false
var _bounced := 0.0
var _time := 0.0
var _batch := InkBatch.new()


func _ready() -> void:
	add_to_group("eraser_chase")
	_paper = _drawer(4, _draw_paper)
	_gutter = _drawer(3, _draw_gutter)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_layer.add_child(_ui)
	_cam = Camera2D.new()
	_cam.set_script(GameCamera)
	_cam.framing_offset = Vector2.ZERO
	add_child(_cam)
	_cam.remove_from_group("camera")


func _drawer(z: int, painter: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.draw.connect(painter.bind(n))
	add_child(n)
	return n


## beast_arena.gd: RUN! `with` is the Eraser it dropped into the arena.
func begin(with: Node2D) -> void:
	eraser = with
	if eraser == null:
		eraser = Eraser.new()
		get_parent().add_child(eraser)
		var p := get_tree().get_first_node_in_group("player") as Node2D
		eraser.global_position = Vector2((p.global_position.x if p else global_position.x) - 650.0, global_position.y)
	eraser.heading = 1.0
	var m := get_node_or_null("/root/Music")
	if m:
		m.play("beast", 0.2)  # RUN: the fight's music again, under the chase
	eraser.rubbing = 1.0
	eraser.set_harmful(true)
	_erase_x = eraser.global_position.x - 40.0
	if erase_from == 0.0:
		erase_from = eraser.global_position.x - 300.0
	phase = Phase.CHASE
	_t = 0.0


func _process(delta: float) -> void:
	_time += delta
	_player = get_tree().get_first_node_in_group("player")
	match phase:
		Phase.WAIT:
			_maybe_restart()
		Phase.CHASE:
			_chase(delta)
		Phase.FINALE:
			_t += delta
			_finale(delta)
	if _cam.is_current() and _player:
		var goal := Vector2(end_x - 120.0, global_position.y - 200.0)
		_cam.global_position = _cam.global_position.lerp(goal, 1.0 - exp(-3.0 * delta))
	_bars = move_toward(_bars, 1.0 if phase == Phase.FINALE else 0.0, delta * 2.5)
	if phase == Phase.FINALE:
		var hud := get_tree().current_scene.get_node_or_null("UI") as CanvasLayer
		if hud:
			hud.visible = false
	if _line_t >= 0.0:
		_line_t += delta
	_paper.queue_redraw()
	_gutter.queue_redraw()
	_ui.queue_redraw()


## A retry after dying in the chase: it starts again as soon as he moves on.
func _maybe_restart() -> void:
	var state := get_node_or_null("/root/GameState")
	if _player == null or state == null or not state.seen.has("beast_dead"):
		return
	if _player.global_position.x > global_position.x + 80.0 and _player.global_position.x < end_x - 400.0:
		begin(null)
		_pop(_player.global_position + Vector2(0, -90), "RUN!", Color(1.0, 0.3, 0.25), 52)


func _chase(delta: float) -> void:
	if eraser == null or not is_instance_valid(eraser):
		return
	if _player == null or _player.dead:
		eraser.rubbing = 0.4
		eraser.set_harmful(false)
		return
	var gap := _player.global_position.x - eraser.global_position.x
	var want := speed
	if gap > 700.0:
		want = speed * 1.6  # never falls far behind
	elif gap < 280.0:
		want = speed * 0.55  # but looms right behind him rather than running him down
	eraser.global_position.x += want * delta
	eraser.global_position.y = global_position.y
	_erase_x = maxf(_erase_x, eraser.global_position.x - eraser.block.x * 0.3)
	if fmod(_time, 0.9) < delta:
		SfxSynth.play(get_tree(), "scritch", -8.0, randf_range(0.5, 0.7))
	eraser.lunge = move_toward(eraser.lunge, 0.0, delta * 2.0)
	_hold_back()
	if _player.global_position.x > end_x - 380.0 and _player.global_position.y < global_position.y + 40.0:
		_start_finale()


## The rubbed-out paper is gone: Vesper can't get behind the Eraser's front.
## Walking, dashing or jumping into it, he's put back in front of it and
## bounced off, forward and up (a rubbery THWUMP); a hit throws him forward
## too (player.gd take_damage), so either way he ends up running again.
func _hold_back() -> void:
	_bounced = maxf(_bounced - get_process_delta_time(), 0.0)
	var front: float = eraser.global_position.x + eraser.block.x * 0.4 + 13.0  # + half his body
	if _player.global_position.x >= front + 6.0:
		return
	_player.global_position.x = maxf(_player.global_position.x, front)
	if _player.velocity.x < 0.0:
		_player.velocity.x = 0.0
	if _bounced > 0.0:
		return
	_bounced = 0.4
	if _player.has_method("shove"):
		_player.shove(bounce)
	eraser.lunge = 0.6  # it shoves back
	_pop(_player.global_position + Vector2(-20, -80), "THWUMP!", Color(0.95, 0.5, 0.55), 40)
	SfxSynth.play(get_tree(), "thud", -4.0, 1.5)


func _start_finale() -> void:
	phase = Phase.FINALE
	_t = 0.0
	var m := get_node_or_null("/root/Music")
	if m:
		m.stop(2.5)  # it drains away as he runs out of page
	_player.cutscene = true
	_player.cutscene_run = 1.0
	var pcam := _player.get_node_or_null("Camera2D") as Camera2D
	_cam.global_position = _view_from(pcam)
	_cam.make_current()
	eraser.set_harmful(false)
	eraser.lunge = 1.0
	eraser.roar = 1.0
	SfxSynth.play(get_tree(), "roar", -4.0, 1.4)
	_say("THE END, VESPER.")


func _finale(delta: float) -> void:
	# the Eraser lunges after him, right to the edge
	if eraser and is_instance_valid(eraser):
		var to := minf(_player.global_position.x - 90.0, end_x - gutter_half - eraser.block.x * 0.4)
		eraser.global_position.x = move_toward(eraser.global_position.x, to, 420.0 * delta)
		_erase_x = maxf(_erase_x, eraser.global_position.x - eraser.block.x * 0.3)
	# at the edge he leaps
	if not _leapt and _player.global_position.x > end_x - gutter_half - 30.0:
		_leapt = true
		_player.velocity.y = -560.0
		SfxSynth.play(get_tree(), "whoosh", -2.0, 0.8)
	if _leapt and _player.global_position.x > end_x - 10.0:
		_player.cutscene_run = 0.15  # out over the gap: let him drop
	# the Eraser slams the edge where he stood
	if _leapt and _t > 0.4 and eraser and eraser.rubbing < 2.0:
		eraser.rubbing = 2.0
		_pop(Vector2(end_x - gutter_half - 40.0, global_position.y - 220.0), "SKRRRRK!", Color(0.95, 0.5, 0.55), 46)
		SfxSynth.play(get_tree(), "thud", 0.0, 0.9)
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.8)
	# swallowed by the dark: the fall
	if not _fell and (_player.global_position.y > global_position.y + 220.0 or _t > 4.5):
		_fell = true
		phase = Phase.DONE
		var state := get_node_or_null("/root/GameState")
		if state:
			state.seen["chase_done"] = true
		MarginsFall.start(get_tree().current_scene, _player)


func _say(text: String) -> void:
	_line = text
	_line_t = 0.0


func _pop(at: Vector2, text: String, col: Color, size: int) -> void:
	var p := ComicText.new()
	p.text = text
	p.color = col
	p.font_size = size
	p.position = at
	get_tree().current_scene.add_child(p)


# ------------------------------------------------------------------ drawing

## Everything behind the Eraser rubbed out: blank paper, a few grey smudges
## where the world was, crumbs along the ragged edge.
func _draw_paper(n: Node2D) -> void:
	if _erase_x <= erase_from:
		return
	var o := n.global_position
	var top := room_top - 400.0
	var bottom := global_position.y + 700.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0)
	var edge := PackedVector2Array([Vector2(erase_from, top) - o])
	var steps := 24
	for i in steps + 1:
		var y := top + (bottom - top) * i / steps
		var wob := sin(y * 0.02 + _time * 3.0) * 18.0 + rng.randf_range(-6, 6)
		edge.append(Vector2(_erase_x + wob, y) - o)
	edge.append(Vector2(erase_from, bottom) - o)
	_batch.draw_colored_polygon(edge, PAPER)
	# ghosts of what was here: faint smudges and rubbed-out lines
	var x := erase_from + 40.0
	var k := 0
	while x < _erase_x - 40.0:
		var y := global_position.y - 20.0 - fposmod(k * 137.0, 600.0)
		_batch.draw_line(Vector2(x, y) - o, Vector2(x + 90.0, y + 8.0) - o, Color(SMUDGE, 0.35), 6.0)
		_batch.draw_line(Vector2(x + 20.0, global_position.y) - o, Vector2(x + 110.0, global_position.y) - o, Color(SMUDGE, 0.5), 3.0)
		x += 160.0
		k += 1
	# the ragged rubbed edge, grey where the rubber dragged
	for i in steps:
		var y := top + (bottom - top) * (i + 0.5) / steps
		var ex := _erase_x + sin(y * 0.02 + _time * 3.0) * 18.0
		_batch.draw_line(Vector2(ex - 30.0, y) - o, Vector2(ex, y + 10.0) - o, Color(SMUDGE, 0.6), 4.0)
	_batch.flush(n)


## The gutter where the corridor's panel ends: the dark gap between the
## columns, its panel borders inked down both sides.
func _draw_gutter(n: Node2D) -> void:
	var o := n.global_position
	var top := room_top - 400.0
	var bottom := global_position.y + 700.0
	var l := end_x - gutter_half
	var r := end_x + gutter_half
	_batch.draw_rect(Rect2(Vector2(l, top) - o, Vector2(r - l, bottom - top)), VOID)
	# dead panels drifting in the dark down there
	for i in 6:
		var y := global_position.y + 60.0 + fposmod(i * 140.0 - _time * 40.0, 700.0)
		var w := gutter_half * (1.4 - i * 0.12)
		var rr := Rect2(Vector2(end_x - w * 0.5, y) - o, Vector2(w, 90))
		_batch.draw_rect(rr, Color(0.6, 0.62, 0.7, 0.1), false, 1.5)
	# the panel borders either side: thick ink with a white edge
	for side: float in [-1.0, 1.0]:
		var x := end_x + side * gutter_half
		_batch.draw_rect(Rect2(Vector2(x - (12.0 if side > 0 else 0.0), top) - o, Vector2(12, bottom - top)), INK)
		_batch.draw_line(Vector2(x - side * 2.0, top) - o, Vector2(x - side * 2.0, bottom) - o, Color(RIM, 0.9), 2.5)
	_batch.flush(n)


func _draw_ui() -> void:
	var s := _ui.size
	if _bars > 0.0:
		var bh := 74.0 * _bars
		_ui.draw_rect(Rect2(0, 0, s.x, bh), Color.BLACK)
		_ui.draw_rect(Rect2(0, s.y - bh, s.x, bh), Color.BLACK)
	if _line_t >= 0.0 and _line != "":
		var dur := 3.0
		var a := clampf(_line_t / 0.2, 0.0, 1.0) * clampf((dur - _line_t) / 0.3, 0.0, 1.0)
		if a > 0.0:
			var fs := 34
			var w := FONT.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var box := Rect2(s.x * 0.5 - w * 0.5 - 30.0, 96.0, w + 60.0, 66.0)
			box.position += Vector2(randf_range(-2, 2), randf_range(-2, 2))
			CaptionStyle.panel(_ui, box, "shade", a)  # Shade's red caption panel
			_ui.draw_string(FONT, box.position + Vector2(30, 46), _line.substr(0, int(_line_t * 30.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CaptionStyle.text_color("shade", a))


## Where the cutscene camera takes over from the player's: what it was showing,
## unless that's stale (far from Vesper, e.g. just after a respawn).
func _view_from(pcam: Camera2D) -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var here := p.global_position + Vector2(0, -60) if p else global_position
	if pcam == null:
		return here
	var c := pcam.get_screen_center_position()
	return c if c.distance_to(here) < 600.0 else here
