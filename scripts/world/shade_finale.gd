extends Node2D
## The last fight, back in Shade's City (shade_finale.tscn). Runs the whole
## thing as one script; place at the world origin.
##  1. Vesper is thrown back into the city; Shade's hand (shade_hand.gd) reaches
##     in and writes SHADE across the sky.
##  2. Waves: the hand draws monsters one at a time (`WAVES`: spiders, bats,
##     diving pens, erasers, and a weakened Ink Blot now and then, never two
##     at once). Kills now and then drop a heart; a cleared wave always does.
##  3. The light: a pillar of light falls on the street and heals Vesper to
##     full; the hand plunges into it and steps out as Vesper's double
##     (shade_double.gd), the hardest fight in the game.
##  4. The end: the double cracks apart with light, the name in the sky runs
##     away, the city brightens, THE END, and back to the main menu.
## Dying restarts the level; after the waves have been beaten once in this run
## it goes straight to the light (GameState.seen).
## Music (music.gd): The Hunters, low, while the hand writes; its tense cut
## ("hunt") from the first wave; silence as the light falls; "hunt" crashing back
## in when the double steps out of it; silence as it cracks apart, then The
## Hunters again, slowly, for the end.

const Hand = preload("res://scripts/effects/shade_hand.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const Heart = preload("res://scripts/world/health_heart.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const MENU := "res://scenes/ui/main_menu.tscn"
const INK := Color(0.05, 0.03, 0.1)
const CAPTION := Color(1.0, 0.9, 0.45)
const LIGHT := Color(1.0, 0.95, 0.78)
const CaptionStyle = preload("res://scripts/ui/caption_style.gd")

const SCENES := {
	"spider": "res://scenes/enemies/paper_spider.tscn",
	"bat": "res://scenes/enemies/ink_bat.tscn",
	"blot": "res://scenes/enemies/ink_blot.tscn",
	"eraser": "res://scenes/enemies/eraser.tscn",
	"pen": "res://scenes/enemies/pen_diver.tscn",
}
const WAVES := [
	["spider", "bat", "bat"],
	["pen", "spider", "eraser"],
	["blot"],
	["bat", "pen", "spider", "pen"],
	["eraser", "bat", "spider"],
	["blot", "bat", "bat"],
]

@export var arena_left := 0.0
@export var arena_right := 1600.0
@export var floor_y := 600.0
## Where the hand hovers between drawings, and where it writes its name.
@export var hand_rest := Vector2(1180, 230)
@export var name_at := Vector2(330, 30)
@export var blot_hp := 10
@export var double_hp := 30
## Chance a killed monster drops half a bottle.
@export var drop_chance := 0.35

var hand: Node2D
var boss: Node2D
var _alive: Array = []
var _drawing := 0  # monsters the hand still has to finish this wave
var _ui: CanvasLayer
var _view: Control
var _lines: Array = []  # [text, who]
var _line := ""
var _who := ""
var _line_t := 0.0
var _line_hold := 0.0
var _beam := 0.0  # 0..1 the pillar of light
var _beam_x := 800.0
var _flash := 0.0
var _bright := 0.0  # the city brightening at the end
var _end_card := 0.0
var _time := 0.0


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_paint_ui)
	_ui.add_child(_view)
	add_child(_ui)
	hand = Node2D.new()
	hand.set_script(Hand)
	hand.rest = hand_rest
	hand.hand_scale = 1.3
	add_child(hand)
	hand._nib = hand_rest + Vector2(900, -700)  # reaches in from off-screen
	hand.drawn.connect(_on_drawn)
	_beam_x = (arena_left + arena_right) * 0.5
	for snd in ["roar", "rumble", "thud", "rip", "whoosh", "splut", "screech", "scritch", "shatter", "clang"]:
		SfxSynth.get_stream(snd)  # built now, not mid-fight
	_run.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	# captions: type, hold, next
	if _line == "" and not _lines.is_empty():
		var l: Array = _lines.pop_front()
		_line = l[0]
		_who = l[1]
		_line_t = 0.0
		_line_hold = 1.6 + _line.length() * 0.045
	if _line != "":
		_line_t += delta
		if _line_t * 32.0 >= _line.length():
			_line_hold -= delta
			if _line_hold <= 0.0:
				_line = ""
	_flash = move_toward(_flash, 0.0, delta * 1.5)
	# monsters that just died: sometimes a little heart
	for m in _alive.duplicate():
		if not is_instance_valid(m) or m.dead:
			_alive.erase(m)
			if is_instance_valid(m) and not (m.get_script() and str(m.get_script().resource_path).ends_with("ink_blot.gd")) \
					and randf() < drop_chance:
				_heart(m.global_position + Vector2(0, -30), 1.0)
	queue_redraw()
	_view.queue_redraw()


# --- the story ------------------------------------------------------------------

func _run() -> void:
	var gs := get_node_or_null("/root/GameState")
	var retry: bool = gs != null and gs.seen.has("finale:waves")
	await _wait(1.6)  # Vesper lands
	if retry:
		hand.write_name(name_at, 0.75)
		hand.draw_speed = 3000.0
		await hand.wrote_name
		hand.draw_speed = 1100.0
		_say("SHADE IS WAITING FOR YOU.", "writer")
	else:
		_say("THE CAVE SPITS VESPER BACK INTO THE CITY. THE INK IS EVERYWHERE NOW.", "writer")
		await _wait(2.0)
		_say("THE AUTHOR, SHADE, IS HERE. HE IS WRITING YOUR END.", "writer")
		hand.write_name(name_at, 0.75)
		await hand.wrote_name
		_say("YOU WANTED A STORY, LITTLE DRAWING? HERE ARE YOUR CHAPTERS.", "shade")
		await _wait(1.5)
		_music("hunt", 0.2)
		for i in WAVES.size():
			await _wave(WAVES[i])
			if i == 2:
				_say("STILL STANDING? THEN I'LL DRAW FASTER.", "shade")
				hand.draw_speed = 1400.0
			await _wait(1.6)
		if gs:
			gs.seen["finale:waves"] = true
	await _the_light()
	await boss.defeated
	await _the_end()


func _wave(kinds: Array) -> void:
	_drawing = kinds.size()
	var used: Array = []
	for kind in kinds:
		var at := _spot(kind, used)
		used.append(at.x)
		hand.draw_monster(kind, at)
	while _drawing > 0 or not _alive.is_empty():
		await get_tree().process_frame
	# a cleared wave always pays out a bottle
	var p := _player()
	if p:
		_heart(Vector2(clampf(p.global_position.x + 120.0, arena_left + 80, arena_right - 80), floor_y - 200), 2.0)


func _spot(kind: String, used: Array) -> Vector2:
	var p := _player()
	var px := p.global_position.x if p else (arena_left + arena_right) * 0.5
	for i in 30:
		var x := randf_range(arena_left + 120.0, arena_right - 120.0)
		if absf(x - px) < 260.0:
			continue
		var clash := false
		for u in used:
			if absf(x - u) < 160.0:
				clash = true
		if clash:
			continue
		return Vector2(x, floor_y - (190.0 if kind == "bat" or kind == "pen" else 0.0))
	return Vector2(arena_left + 200.0 if px > (arena_left + arena_right) * 0.5 else arena_right - 200.0, floor_y)


func _on_drawn(kind: String, at: Vector2) -> void:
	if not SCENES.has(kind):
		return
	var m: Node2D = load(SCENES[kind]).instantiate()
	match kind:
		"spider":
			m.position = at + Vector2(0, -33)
		"bat":
			m.position = at + Vector2(0, -40)
		"pen":
			m.position = at + Vector2(0, -40)
			m.hp = 4
		"eraser":
			m.position = at + Vector2(0, -46)  # half its body (eraser.gd setup): feet on the street
			m.hp = 6
		"blot":
			m.position = at + Vector2(0, -75)
			m.asleep = false
			m.hp = blot_hp
	get_parent().add_child(m)
	if kind == "bat":
		m.state = 1  # straight out of the light, awake
		m.set_harmful(true)
	if kind != "blot":
		m.remove_from_group("boss")  # only the Blot gets a health bar
	Hand.materialize(m)
	_alive.append(m)
	_drawing -= 1


func _the_light() -> void:
	_music("", 2.0)  # everything holds its breath
	_say("ENOUGH SCRIBBLES. IF YOU WANT AN ENDING SO BADLY...", "shade")
	hand.rest = Vector2(_beam_x + 60.0, floor_y - 380.0)
	await _wait(2.2)
	_say("...I'LL WRITE IT MYSELF.", "shade")
	await _wait(1.2)
	# the pillar of light falls on the street
	Sfx.play("teleport", 2.0, 0.6)
	SfxSynth.play(get_tree(), "whoosh", 0.0, 0.45)
	SfxSynth.play(get_tree(), "rumble", -2.0, 0.8)
	var t := create_tween()
	t.tween_property(self, "_beam", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	await t.finished
	_flash = 1.0
	var p := _player()
	if p:
		p.health = p.max_health
		p.health_changed.emit(p.health, p.max_health)
		_pop(p.global_position + Vector2(0, -80), "FULL HEALTH!", Color(0.55, 1.0, 0.6))
		Sfx.play("checkpoint", 2.0, 0.8)
	_say("THE LIGHT FINDS VESPER. HIS INK RUNS FULL.", "writer")
	# the hand plunges into the light and is gone
	hand.rest = Vector2(_beam_x, floor_y - 120.0)
	await _wait(1.0)
	SfxSynth.play(get_tree(), "whoosh", -2.0, 0.6)  # the hand plunges into the light
	var h := create_tween().set_parallel()
	h.tween_property(hand, "hand_scale", 0.35, 1.1).set_ease(Tween.EASE_IN)
	h.tween_property(hand, "self_modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)  # the name in the sky stays
	await h.finished
	_flash = 1.0
	Sfx.play("boss_intro", 2.0, 0.7)
	SfxSynth.play(get_tree(), "shatter", -4.0, 0.8)
	SfxSynth.play(get_tree(), "thud", 0.0, 0.6)
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.add_trauma(0.8)
	# ...and steps out of it as Vesper
	boss = load("res://scenes/enemies/shade_double.tscn").instantiate()
	boss.hp = double_hp
	boss.position = Vector2(_beam_x, floor_y - 26.0)
	boss.modulate = Color(6, 6, 6, 0)
	get_parent().add_child(boss)
	var p2 := _player()
	if p2:
		boss.facing = -1 if p2.global_position.x < _beam_x else 1
	var e := create_tween()
	e.tween_property(boss, "modulate", Color(6, 6, 6, 1), 0.5)
	e.tween_property(boss, "modulate", Color.WHITE, 1.2)
	await e.finished
	_say("I AM THE VESPER I SHOULD HAVE WRITTEN.", "shade")
	var b := create_tween()
	b.tween_property(self, "_beam", 0.0, 1.4)
	await _wait(2.4)
	_music("hunt", 0.15)  # (from the top: it stopped for the light)
	boss.begin()


func _the_end() -> void:
	var p := _player()
	if p:
		p.set_physics_process(false)
		p.velocity = Vector2.ZERO
		# swing the camera so both of them are in the shot
		var cam := p.get_node_or_null("Camera2D")
		if cam and "framing_offset" in cam:
			var want := Vector2((boss.global_position.x - p.global_position.x) * 0.5, cam.framing_offset.y)
			create_tween().tween_property(cam, "framing_offset", want, 1.2).set_trans(Tween.TRANS_SINE)
	_music("", 2.5)
	await _wait(1.0)
	_say("...YOU WERE NEVER... SUPPOSED... TO WIN...", "shade")
	SfxSynth.play(get_tree(), "rip", -4.0, 0.6)  # cracking open with light
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_inside_tree():
			SfxSynth.play(get_tree(), "rip", -2.0, 0.75))
	var c := create_tween()
	c.tween_method(boss.crumble, 0.0, 1.0, 3.0)
	await c.finished
	_flash = 1.0
	Sfx.play("ink_splat", 6.0, 0.5)
	SfxSynth.play(get_tree(), "shatter", 2.0, 0.6)
	boss.visible = false
	_music("hunters", 5.0)  # the city's tune, slowly, as it brightens
	# the name in the sky runs away, the city brightens
	var n := create_tween().set_parallel()
	n.tween_property(hand._name_layer, "modulate:a", 0.0, 3.0)
	n.tween_property(self, "_bright", 0.55, 4.0)
	_say("THE INK RUNS DRY. SHADE'S PEN FALLS SILENT.", "writer")
	await _wait(4.5)
	_say("FOR THE FIRST TIME, VESPER WRITES HIS OWN NEXT PAGE.", "writer")
	await _wait(4.5)
	_say("WHY, SHADE? WHY DID YOU WANT ME DEAD?", "vesper")  # the answer is the ending cutscene
	await _wait(4.0)
	var e := create_tween()
	e.tween_property(self, "_end_card", 1.0, 1.5)
	await e.finished
	await _wait(2.0)
	var waited := 0.0
	while waited < 8.0 and not Input.is_anything_pressed():
		await get_tree().process_frame
		waited += get_process_delta_time()
	get_tree().change_scene_to_file(MENU)


# --- helpers --------------------------------------------------------------------

func _say(text: String, who: String) -> void:
	_lines.append([text, who])


## Music autoload: a track ("" = fade out).
func _music(track: String, fade: float) -> void:
	var m := get_node_or_null("/root/Music")
	if m == null:
		return
	if track == "":
		m.stop(fade)
	else:
		m.play(track, fade)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player")
	return p if p and not p.dead else null


func _heart(at: Vector2, amount: float) -> void:
	if Heart.player_full(get_tree()):
		return  # full ink: no heart to fly in and sit on him
	var h := Area2D.new()
	h.set_script(Heart)
	h.amount = amount
	h.seek = true
	h.position = at
	get_parent().add_child.call_deferred(h)


func _pop(at: Vector2, text: String, col: Color) -> void:
	var c := preload("res://scripts/effects/comic_text.gd").new()
	c.text = text
	c.color = col
	c.position = at
	get_tree().current_scene.add_child(c)


# --- drawing --------------------------------------------------------------------

func _draw() -> void:
	if _beam <= 0.0:
		return
	# the pillar of light from the sky, ink pouring down it while the hand dissolves
	var w := 140.0 * _beam
	var top := floor_y - 1400.0
	for k in 5:
		var ww := w * (1.0 + k * 0.5)
		draw_rect(Rect2(_beam_x - ww * 0.5, top, ww, floor_y - top), Color(LIGHT, 0.12 * _beam))
	draw_rect(Rect2(_beam_x - w * 0.25, top, w * 0.5, floor_y - top), Color(1, 1, 1, 0.55 * _beam))
	draw_set_transform(Vector2(_beam_x, floor_y), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, w * 1.6, Color(LIGHT, 0.3 * _beam))
	draw_set_transform(Vector2.ZERO)
	for k in 14:
		var y := fmod(_time * 520.0 + k * 97.0, floor_y - top) + top
		draw_line(Vector2(_beam_x - w * 0.4 + k * w * 0.06, y), Vector2(_beam_x - w * 0.4 + k * w * 0.06, y + 40.0),
			Color(1, 1, 1, 0.5 * _beam), 2.0)


func _paint_ui() -> void:
	var s := _view.size
	if _bright > 0.0:
		_view.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.93, 0.75, _bright * 0.5))
	if _flash > 0.0:
		_view.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, _flash * 0.85))
	if _line != "":
		_paint_caption(s)
	if _end_card > 0.0:
		_paint_end(s)


func _paint_caption(s: Vector2) -> void:
	var shown := _line.substr(0, int(_line_t * 32.0))
	var a := clampf(_line_hold / 0.3, 0.0, 1.0) if _line_t * 32.0 >= _line.length() else 1.0
	var size := 30
	var w := minf(FONT.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, s.x - 120.0)
	if _who == "shade":
		# Shade speaks: his red caption panel (caption_style.gd), under the name in the sky
		var box := Rect2(s.x * 0.5 - w * 0.5 - 28.0, 240.0, w + 56.0, 64.0)
		CaptionStyle.panel(_view, box, "shade", a)
		_view.draw_string(FONT, box.position + Vector2(28, 44), shown, HORIZONTAL_ALIGNMENT_LEFT, w + 4.0, size, CaptionStyle.text_color("shade", a))
	else:
		# the comic's yellow caption ("writer" = the narration) or Vesper's (with his tab)
		var who := "vesper" if _who == "vesper" else "narrator"
		var box := Rect2(60.0, 236.0 if who == "vesper" else 226.0, w + 44.0, 56.0)
		CaptionStyle.panel(_view, box, who, a)
		_view.draw_string(FONT, box.position + Vector2(22, 39), shown, HORIZONTAL_ALIGNMENT_LEFT, w + 4.0, size, CaptionStyle.text_color(who, a))


func _paint_end(s: Vector2) -> void:
	var a := _end_card
	_view.draw_rect(Rect2(Vector2.ZERO, s), Color(0.97, 0.94, 0.86, a))
	# a comic page's last panel border
	var r := Rect2(s * 0.1, s * 0.8)
	_view.draw_rect(r, Color(INK, a), false, 6.0)
	var title := "THE END"
	var tw := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x
	var tp := Vector2((s.x - tw) * 0.5, s.y * 0.5)
	_view.draw_string_outline(FONT, tp + Vector2(6, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, 18, Color(INK, 0.35 * a))
	_view.draw_string(FONT, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, Color(INK, a))
	_view.draw_line(Vector2(tp.x, tp.y + 20), Vector2(tp.x + tw, tp.y + 16), Color(0.86, 0.2, 0.18, a), 6.0)
	var sub := "...OR IS IT? VESPER'S STORY IS HIS OWN NOW."
	var sw := FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_view.draw_string(FONT, Vector2((s.x - sw) * 0.5, s.y * 0.5 + 80.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.35, 0.25, 0.45, a))
	var thanks := "THANKS FOR PLAYING"
	var thw := FONT.get_string_size(thanks, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_view.draw_string(FONT, Vector2((s.x - thw) * 0.5, s.y * 0.9 - 30.0), thanks, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(INK, a * 0.8))
