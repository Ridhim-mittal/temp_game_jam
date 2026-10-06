extends Control
## Main menu, night edition (layout after the "Pasta at Night" reference):
## a rainy comic street at night runs to the horizon, VESPER towers over it
## in huge extruded neon-comic letters, Vesper stands on the road in front,
## and the menu sits in one row along the bottom. Along the top hangs a band
## of round comic halftone dots, violet ink brightening into the Writer's pale
## gold light (the "Predictive Arc" shader, shaders/menu_arc.gdshader, turned
## 180 degrees with `flip`), behind the title; it dips toward the mouse, or
## toward the focused item when using the keyboard, but never over the sign.
## Everything is tweened: the letters drop in one by one, the band rises,
## the items slide up; hovering pops an item and draws its brush stroke;
## lightning flashes now and then and a letter of the sign blinks out.
## Edit MAIN / CHAPTERS to change the options ("@chapters" / "@back" switch
## rows, "@continue" picks up the saved run, "" quits).
## CONTINUE goes back to where the last run was left (GameState's saved run:
## the level and its checkpoint, or the Gutter room), showing where under it;
## greyed out when there is none. NEW GAME starts the story from the opening.

const NightShader = preload("res://shaders/menu_night.gdshader")
const ArcShader = preload("res://shaders/menu_arc.gdshader")
const TitleShader = preload("res://shaders/menu_title.gdshader")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const PlayerVisual = preload("res://scripts/player/player_visual.gd")
const SwordScene = preload("res://scenes/player/sword.tscn")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

const INK := Color(0.04, 0.03, 0.05)
const CREAM := Color(0.98, 0.94, 0.86)
const GOLD := Color(1.0, 0.82, 0.3)
const RED := Color(0.9, 0.2, 0.16)
const SIZE := Vector2(1280, 720)
const HORIZON := Vector2(640, 468)
## Lowest point the top band dips to, toward the mouse / focused item.
const ARC_DIP := 150.0

## [label, scene to load ("" = quit, "@chapters" / "@back" switch rows)]
const MAIN := [
	["CONTINUE", "@continue"],  # the run that was left (GameState.continue_run())
	["NEW GAME", "res://scenes/cutscenes/cs_book.tscn"],  # the animated opening (cs_book.gd), into the City
	["CHAPTERS", "@chapters"],
	["SETTINGS", "res://scenes/ui/settings.tscn"],
	["QUIT", ""],
]
const CHAPTERS := [
	["THE CITY", "res://scenes/levels/test_level.tscn"],
	["THE SKETCHBOOK", "res://scenes/levels/sketchbook.tscn"],
	["THE LONG DROP", "res://scenes/levels/long_drop.tscn"],
	["THE MARGINS", "res://scenes/clearing/clearing.tscn"],
	["SHADE'S CITY", "res://scenes/levels/shades_city.tscn"],
	["THE INK CAVE", "res://scenes/levels/ink_cave.tscn"],
	["SHADE", "res://scenes/levels/shade_finale.tscn"],
	["THE ENDING", "res://scenes/cutscenes/cs_last_page.tscn"],  # the ending cutscene and its credits
	["BACK", "@back"],
]
const TITLE := "VESPER"
const TITLE_PX := 228
const TITLE_BASE := Vector2(640, 442)

@export var music := "margins"

var _time := 0.0
var _sky_mat: ShaderMaterial
var _arc_mat: ShaderMaterial
var _arc_intro := 0.0
var _flash := 0.0
var _glow := 1.0
var _next_bolt := 6.0
var _next_blink := 3.0
var _parallax := Vector2.ZERO
var _mouse_seen := -10.0
var _arc_mouse := Vector2(640, 20)
var _arc_strength := 0.0

var _scene: Node2D      # street, buildings, lamps
var _title: Node2D      # holds one node per letter
var _letters: Array[Node2D] = []
var _hero: CanvasGroup
var _hero_art: Node2D
var _menu: Node2D       # draws the labels on top of the band
var _items: Array = []  # {label, target, button, appear, hover, pos, size}
var _row := "main"
var _busy := false
var _wipe := -1.0
var _wipe_from := Vector2.ZERO
var _windows: Array = []
var _rng := RandomNumberGenerator.new()
var _place := ""          # where the saved run is (_saved_place()), "" = none
var _software_gl := false # (browser build) WebGL is drawn without the graphics card


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	_rng.seed = 7
	var state := get_node_or_null("/root/GameState")
	if state:
		state.leave_run()  # the run that was going is saved for CONTINUE...
		state.reset()  # ...and the menu starts afresh: no checkpoint, no banked coins
	_place = _saved_place()
	_software_gl = _browser_gl_is_software()
	_sky_mat = _shader_rect(NightShader)
	_scene = Node2D.new()
	_scene.draw.connect(_draw_street)
	add_child(_scene)
	_build_windows()
	_build_title()
	_build_hero()
	_arc_mat = _shader_rect(ArcShader)
	move_child(_arc_mat.get_meta("rect"), _scene.get_index() + 1)  # behind the windows, title and Vesper
	_arc_mat.set_shader_parameter("flip", true)
	_arc_mat.set_shader_parameter("round_dots", true)
	_arc_mat.set_shader_parameter("thick", 0.8)
	_arc_mat.set_shader_parameter("dot_size", 10.0)
	_arc_mat.set_shader_parameter("base_col", Color(0.2, 0.07, 0.36))
	_arc_mat.set_shader_parameter("accent_col", Color(0.52, 0.3, 0.86))
	_arc_mat.set_shader_parameter("high_col", Color(1.0, 0.88, 0.58))
	_menu = Node2D.new()
	_menu.draw.connect(_draw_menu)
	add_child(_menu)
	_build_row(MAIN, 0.9)
	_intro()
	var player := get_node_or_null("/root/Music")
	if player and music != "":
		player.play(music)


func _shader_rect(shader: Shader) -> ShaderMaterial:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("rect_size", SIZE)
	r.material = m
	add_child(r)
	m.set_meta("rect", r)
	return m


# ------------------------------------------------------------------- build

func _build_title() -> void:
	_title = Node2D.new()
	_title.position = TITLE_BASE
	add_child(_title)
	var total := FONT.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX).x
	var x := -total * 0.5
	for i in TITLE.length():
		var ch := TITLE[i]
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX).x
		var letter := Node2D.new()
		letter.position = Vector2(x + w * 0.5, 0)
		letter.set_meta("w", w)
		letter.set_meta("ch", ch)
		var back := Node2D.new()  # glow, 3D extrusion, ink outline, drips
		back.draw.connect(_draw_letter_back.bind(back, ch, w, i))
		letter.add_child(back)
		var face := Node2D.new()  # gradient face (shader)
		var m := ShaderMaterial.new()
		m.shader = TitleShader
		m.set_shader_parameter("top_y", -TITLE_PX * 0.74)
		m.set_shader_parameter("bottom_y", 0.0)
		face.material = m
		face.draw.connect(func(): face.draw_string(FONT, Vector2(-w * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX, Color.WHITE))
		letter.add_child(face)
		letter.set_meta("face", m)
		letter.set_meta("back", back)
		letter.set_meta("drip", 0.0)
		_title.add_child(letter)
		_letters.append(letter)
		x += w - 4.0


func _build_hero() -> void:
	_hero = CanvasGroup.new()
	_hero.position = Vector2(640, 586)
	_hero.scale = Vector2(2.1, 2.1)
	_hero.fit_margin = 30.0
	var m := ShaderMaterial.new()
	m.shader = OutlineShader
	m.set_shader_parameter("pop_color", Color(1.0, 0.85, 0.7))
	m.set_shader_parameter("ink_width", 2.0)
	m.set_shader_parameter("pop_width", 4.0)
	_hero.material = m
	_hero_art = Node2D.new()
	_hero_art.name = "Art"
	_hero_art.set_script(PlayerVisual)
	_hero.add_child(_hero_art)
	_hero.add_child(SwordScene.instantiate())
	add_child(_hero)


func _build_windows() -> void:
	# lit windows on the two rows of buildings: [rect, phase, layer]
	for side: int in [-1, 1]:
		for k in 46:
			var near := k % 3 != 0
			var x := 640.0 + side * _rng.randf_range(260.0 if near else 200.0, 640.0)
			var y := _rng.randf_range(150.0, 450.0)
			_windows.append([Rect2(x, y, 8 if near else 5, 11 if near else 7), _rng.randf() * TAU, 1 if near else 0])


## A row of items: MAIN on one line, CHAPTERS on two.
func _build_row(list: Array, delay := 0.0) -> void:
	for it in _items:
		it.button.queue_free()
	_items.clear()
	var half := ceili(list.size() * 0.5)
	var rows: Array = [list] if list.size() <= 5 else [list.slice(0, half), list.slice(half)]
	var px := (46 if list.size() <= 4 else 42) if rows.size() == 1 else 34
	for r in rows.size():
		var row: Array = rows[r]
		var y := 652.0 if rows.size() == 1 else 618.0 + r * 58.0
		for k in row.size():
			var label: String = row[k][0]
			var cx := SIZE.x * (k + 0.5) / row.size() if rows.size() == 1 else 640.0 + (k - (row.size() - 1) * 0.5) * minf(300.0, 1210.0 / row.size())
			var sz := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
			var b := Button.new()
			b.flat = true
			b.focus_mode = Control.FOCUS_ALL
			var empty := StyleBoxEmpty.new()
			for s in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(s, empty)
			b.position = Vector2(cx - sz.x * 0.5 - 16, y - px - 6)
			b.size = Vector2(sz.x + 32, px + 20)
			var it := {"label": label, "target": row[k][1], "button": b, "appear": 0.0, "hover": 0.0,
				"pos": Vector2(cx, y), "px": px, "w": sz.x, "focused": false, "pop": 0.0, "deny": 0.0}
			b.pressed.connect(_choose.bind(it))
			b.mouse_entered.connect(b.grab_focus)
			add_child(b)
			_items.append(it)
	# staggered slide-up
	for i in _items.size():
		var it: Dictionary = _items[i]
		var t := create_tween()
		t.tween_interval(delay + i * 0.07)
		t.tween_method(func(v: float): it.appear = v, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# CONTINUE when there's a run to go back to, else the first thing that works
	for it in _items:
		if _why_not(it) == "":
			it.button.grab_focus()
			break


func _intro() -> void:
	# letters drop in one by one with an elastic landing, the band rises
	for i in _letters.size():
		var l := _letters[i]
		var home := l.position
		l.position = home + Vector2(0, -260)
		l.scale = Vector2(0.4, 1.6)
		l.modulate.a = 0.0
		var t := create_tween().set_parallel()
		t.tween_property(l, "position", home, 0.7).set_delay(0.1 + i * 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "scale", Vector2.ONE, 0.6).set_delay(0.1 + i * 0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "modulate:a", 1.0, 0.2).set_delay(0.1 + i * 0.08)
	_glow = 0.0
	create_tween().tween_method(func(v: float): _glow = v, 0.0, 1.0, 1.2).set_delay(0.6)
	create_tween().tween_method(func(v: float): _arc_intro = v, 0.0, 1.0, 1.4).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hero.modulate.a = 0.0
	var h := create_tween()
	h.tween_interval(0.8)
	h.tween_property(_hero, "modulate:a", 1.0, 0.4)


# ------------------------------------------------------------------- live

func _process(delta: float) -> void:
	_time += delta
	var mouse := get_viewport().get_mouse_position()
	var target_par := (mouse / SIZE - Vector2(0.5, 0.5)) * 2.0
	_parallax = _parallax.lerp(target_par.clamp(Vector2(-1, -1), Vector2(1, 1)), 1.0 - exp(-3.0 * delta))
	_scene.position = -_parallax * Vector2(8, 3)
	_title.position = TITLE_BASE - _parallax * Vector2(14, 6) + Vector2(0, sin(_time * 1.1) * 3.0)
	_hero.position = Vector2(640, 586) - _parallax * Vector2(22, 4)
	_update_focus(delta)
	_update_arc(delta, mouse)
	_update_weather(delta)
	_sky_mat.set_shader_parameter("time", _time)
	_sky_mat.set_shader_parameter("glow", _glow * (0.85 + 0.15 * sin(_time * 2.3)))
	_sky_mat.set_shader_parameter("flash", _flash)
	_sky_mat.set_shader_parameter("parallax", _parallax)
	_sky_mat.set_shader_parameter("glow_center", TITLE_BASE + Vector2(0, -90))
	for l in _letters:
		(l.get_meta("back") as Node2D).queue_redraw()
	_scene.queue_redraw()
	_menu.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = _time


func _update_focus(delta: float) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	for it in _items:
		var on: bool = it.button == focused
		if on != it.focused:
			it.focused = on
			if on and _time > 0.3:
				Sfx.play("menu_hover")
		# each frame every item eases toward lit (the one focused) or unlit (all the
		# others): only one can ever be lit, however fast the mouse sweeps across
		it.hover = move_toward(it.hover, 1.0 if on else 0.0, delta * (5.0 if on else 7.0))


func _update_arc(delta: float, mouse: Vector2) -> void:
	# the band bends to the mouse while it moves, otherwise to the focused item
	# (the band hangs from the top: it dips toward the pointer, never as far as the sign)
	var target := Vector2(640, 0)
	var strength := 0.34
	if _time - _mouse_seen < 1.5:
		target = Vector2(mouse.x, minf(mouse.y, ARC_DIP))
	else:
		for it in _items:
			if it.focused:
				target = Vector2(it.pos.x, ARC_DIP)
				strength = 0.5
	_arc_mouse = _arc_mouse.lerp(target, minf(1.0, delta * 12.0))
	_arc_strength = lerpf(_arc_strength, strength, minf(1.0, delta * 6.0))
	_arc_mat.set_shader_parameter("time", fmod(_time * 1.8, 6283.0))
	_arc_mat.set_shader_parameter("mouse", _arc_mouse)
	_arc_mat.set_shader_parameter("mouse_strength", _arc_strength)
	_arc_mat.set_shader_parameter("intro", _arc_intro)


func _update_weather(delta: float) -> void:
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = randf_range(7.0, 12.0)
		var t := create_tween()
		for k in 2:  # a double flicker
			t.tween_method(func(v: float): _flash = v, 0.0, 1.0, 0.05)
			t.tween_method(func(v: float): _flash = v, 1.0, 0.0, 0.18 + k * 0.25)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.5, 5.0)
		# one letter of the sign sputters, like a tired neon tube
		var m: ShaderMaterial = _letters.pick_random().get_meta("face")
		var t := create_tween()
		var prev := 1.0
		for v in [0.25, 1.0, 0.4, 1.0]:
			t.tween_method(func(p: float): m.set_shader_parameter("power", p), prev, v, 0.06)
			prev = v
	# Vesper glances around now and then
	if fmod(_time, 6.0) < delta and _time > 2.0:
		var t := create_tween()
		t.tween_property(_hero, "scale:x", -_hero.scale.x, 0.18).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	# cheat (for the jam's judges, in the submission notes, never shown in the
	# game): Shift+0 unlocks CHAPTERS without playing the story through
	if event is InputEventKey and event.pressed and not event.echo and event.shift_pressed and event.physical_keycode == KEY_0:
		var profile := get_node_or_null("/root/Profile")
		if profile:
			profile.mark_finished()
			Sfx.play("gate_unlock")
		return
	if _busy:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var i := -1
	for k in _items.size():
		if _items[k].button == focused:
			i = k
	if i < 0:
		return
	var step := 0
	if event.is_action_pressed("move_left") or event.is_action_pressed("up"):
		step = -1
	elif event.is_action_pressed("move_right") or event.is_action_pressed("down"):
		step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		_items[(i + step + _items.size()) % _items.size()].button.grab_focus()
	elif event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()  # before the scene can change
		_choose(_items[i])
	elif event.is_action_pressed("ui_cancel") and _row == "chapters":
		get_viewport().set_input_as_handled()
		_switch(MAIN, "main")


## CHAPTERS stay locked until the story has been played to its end
## (Profile.finished, set by shade_finale.gd).
func _locked(it: Dictionary) -> bool:
	var profile := get_node_or_null("/root/Profile")
	return it.target == "@chapters" and not (profile and profile.finished)


## Why an item can't be chosen ("" = it can): a locked CHAPTERS, or
## CONTINUE with no saved run.
func _why_not(it: Dictionary) -> String:
	if _locked(it):
		return "FINISH THE STORY TO UNLOCK"
	if it.target == "@continue" and _place == "":
		return "NO GAME TO CONTINUE"
	return ""


## In a browser: is WebGL running without the graphics card (Chrome's SwiftShader,
## Mesa's llvmpipe, Windows' Basic Render Driver)? Then every frame is drawn by
## the CPU and the game crawls at ~8 fps with crackling sound, however light it
## is: hardware acceleration is off in the browser, or the GPU is blocklisted.
## The real renderer's name is logged to the browser console either way.
func _browser_gl_is_software() -> bool:
	if not OS.has_feature("web"):
		return false
	var js := "(function(){try{var c=document.createElement('canvas');var gl=c.getContext('webgl2')||c.getContext('webgl');" \
		+ "if(!gl)return 'no webgl';var e=gl.getExtension('WEBGL_debug_renderer_info');" \
		+ "return String(gl.getParameter(e?e.UNMASKED_RENDERER_WEBGL:gl.RENDERER));}catch(x){return '';}})()"
	var name := str(JavaScriptBridge.eval(js)).to_lower()
	print("Vesper: WebGL renderer: ", name)
	for mark in ["swiftshader", "llvmpipe", "softpipe", "software", "basic render"]:
		if name.contains(mark):
			return true
	return false


## Where the saved run is, by its chapter's name ("" = no saved run).
func _saved_place() -> String:
	var state := get_node_or_null("/root/GameState")
	var path: String = state.saved_scene() if state else ""
	if path == "":
		return ""
	for c in CHAPTERS:
		if c[1] == path:
			return c[0]
	return "THE MARGINS"  # a room of the Gutter


func _choose(it: Dictionary) -> void:
	if _busy:
		return
	if _why_not(it) != "":
		Sfx.play("menu_close", -4.0, 0.8)
		var no := create_tween()  # it shakes its head
		no.tween_method(func(v: float): it.deny = v, 1.0, 0.0, 0.45)
		return
	Sfx.play("menu_close" if it.target == "@back" else ("menu_open" if it.target == "@chapters" else "menu_select"))
	var t := create_tween()  # the label punches out
	t.tween_method(func(v: float): it.pop = v, 0.0, 1.0, 0.12)
	t.tween_method(func(v: float): it.pop = v, 1.0, 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	match it.target:
		"@chapters":
			_switch(CHAPTERS, "chapters")
		"@back":
			_switch(MAIN, "main")
		_:
			_leave(it)


func _switch(list: Array, row: String) -> void:
	_busy = true
	var t := create_tween().set_parallel()
	for it in _items:
		t.tween_method(func(v: float): it.appear = v, it.appear, 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(func():
		_row = row
		_build_row(list)
		_busy = false)


func _leave(it: Dictionary) -> void:
	_busy = true
	_wipe_from = it.pos + Vector2(0, -20)
	var t := create_tween()
	t.tween_method(func(v: float): _wipe = v, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		if it.target == "":
			get_tree().quit()
		else:
			var profile := get_node_or_null("/root/Profile")
			var state := get_node_or_null("/root/GameState")
			if it.target == "@continue":
				# back where he left off: the purse, the checkpoint and the story as they were
				get_tree().change_scene_to_file(state.continue_run())
				return
			if state:
				state.clear_run()  # a new game (or a chapter) replaces the saved run
			if profile and _starts_run(it.label):
				profile.new_run()  # the coins come back, so the purse starts at 0
			if it.label == "NEW GAME" and profile:  # a new run always teaches the controls again
				profile.reset_tutorials("2d.")
			get_tree().change_scene_to_file(it.target))


## NEW GAME and the 2D chapters start a new run (the purse back to 0); SETTINGS
## doesn't, and nor does THE MARGINS: the 2.5D half spends the coins brought
## from the 2D levels, so the purse carries over.
func _starts_run(label: String) -> bool:
	if label == "NEW GAME":
		return true
	for c in CHAPTERS:
		if c[0] == label and c[1].begins_with("res://scenes/levels/"):
			return true
	return false


# ----------------------------------------------------------------- drawing

func _draw_street() -> void:
	var c := _scene
	var hz := HORIZON
	# far skyline across the horizon
	var far := PackedVector2Array([Vector2(0, hz.y)])
	var x := 0.0
	var k := 0
	while x < SIZE.x:
		var hgt := 60.0 + absf(sin(k * 1.7)) * 90.0 + (1.0 - absf(x - 640.0) / 640.0) * -30.0
		far.append(Vector2(x, hz.y - hgt))
		x += 46.0 + absf(cos(k * 2.3)) * 40.0
		far.append(Vector2(x, hz.y - hgt))
		k += 1
	far.append(Vector2(SIZE.x, hz.y))
	c.draw_colored_polygon(far, Color(0.1, 0.05, 0.14))
	# near buildings: two walls of tall blocks, leaving the street open
	for side: int in [-1, 1]:
		var bx := 0.0
		var j := 0
		while bx < 470.0:
			var w := 70.0 + absf(sin(j * 2.1 + side)) * 60.0
			var top := 140.0 + absf(cos(j * 1.3 + side * 2.0)) * 170.0 + bx * 0.25
			var x0 := 640.0 + side * (640.0 - bx)
			var x1 := 640.0 + side * (640.0 - bx - w)
			var r := Rect2(minf(x0, x1), top, absf(x1 - x0), hz.y + 30.0 - top)
			c.draw_rect(r, Color(0.05, 0.03, 0.08))
			c.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0.45, 0.12, 0.2, 0.8))  # red rim light
			if j % 2 == 0:  # water tower
				var tx := r.position.x + r.size.x * 0.5
				c.draw_rect(Rect2(tx - 12, top - 26, 24, 20), Color(0.05, 0.03, 0.08))
				c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 15, top - 26), Vector2(tx, top - 38), Vector2(tx + 15, top - 26)]), Color(0.05, 0.03, 0.08))
			bx += w + 6.0
			j += 1
	for wnd in _windows:
		var on := sin(_time * 0.6 + wnd[1]) > -0.6
		if on:
			c.draw_rect(wnd[0], Color(1.0, 0.8, 0.35, 0.75 if wnd[2] == 1 else 0.4))
	# the road, running to the horizon, with dashes rushing toward us
	var road := PackedVector2Array([Vector2(hz.x - 26, hz.y), Vector2(hz.x + 26, hz.y), Vector2(1260, SIZE.y), Vector2(20, SIZE.y)])
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, hz.y), Vector2(SIZE.x, hz.y), Vector2(SIZE.x, SIZE.y), Vector2(0, SIZE.y)]), Color(0.03, 0.02, 0.05))
	c.draw_colored_polygon(road, Color(0.07, 0.05, 0.1))
	for e in [[road[0], road[3]], [road[1], road[2]]]:
		c.draw_line(e[0], e[1], Color(0.5, 0.16, 0.24, 0.8), 2.0)
	var n := 9
	for d in n:
		var t0 := fmod(d / float(n) + _time * 0.18, 1.0)
		var t1 := t0 + 0.035
		var y0 := hz.y + (SIZE.y - hz.y) * t0 * t0
		var y1 := hz.y + (SIZE.y - hz.y) * minf(t1 * t1, 1.0)
		c.draw_line(Vector2(hz.x, y0), Vector2(hz.x, y1), Color(1.0, 0.85, 0.45, 0.25 + 0.6 * t0), 1.0 + 7.0 * t0)
	# street lamps down both sides, glowing
	for side: float in [-1.0, 1.0]:
		for d in 5:
			var t := 0.12 + d * 0.2
			var foot := Vector2(hz.x + side * (40.0 + 640.0 * t), hz.y + (SIZE.y - hz.y) * t * 0.9)
			var hgt := 40.0 + 260.0 * t
			var top := foot + Vector2(0, -hgt)
			c.draw_line(foot, top, INK, 2.0 + 4.0 * t)
			c.draw_line(top, top + Vector2(-side * 22.0 * (0.4 + t), 0), INK, 2.0 + 3.0 * t)
			var bulb := top + Vector2(-side * 22.0 * (0.4 + t), 4.0)
			var flick := 0.85 + 0.15 * sin(_time * 7.0 + d * 3.0 + side)
			c.draw_circle(bulb, 22.0 * (0.3 + t), Color(1.0, 0.6, 0.3, 0.12 * flick))
			c.draw_circle(bulb, 9.0 * (0.3 + t), Color(1.0, 0.8, 0.5, 0.35 * flick))
			c.draw_circle(bulb, 3.0 * (0.4 + t), Color(1.0, 0.95, 0.8, flick))
			# light pool on the wet road
			c.draw_colored_polygon(PackedVector2Array([bulb, foot + Vector2(-side * 70.0 * t, 0), foot + Vector2(-side * 10.0, 4)]), Color(1.0, 0.65, 0.35, 0.05 * flick))
	# Vesper's shadow on the road
	var hp := _hero.position if _hero else Vector2(640, 586)
	c.draw_set_transform(hp + Vector2(8, 2), 0.0, Vector2(1.0, 0.25))
	c.draw_circle(Vector2.ZERO, 46.0, Color(0, 0, 0, 0.45))
	c.draw_set_transform(Vector2.ZERO)


func _draw_letter_back(c: Node2D, ch: String, w: float, i: int) -> void:
	var o := Vector2(-w * 0.5, 0)
	var g := _glow
	# neon glow halo
	for k in 3:
		c.draw_string_outline(FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX, 60 - k * 18, Color(1.0, 0.3, 0.18, 0.05 * g * (k + 1)))
	# 3D extrusion going down-right into the dark
	var depth := 16
	for k in range(depth, 0, -1):
		var off := Vector2(k * 0.9, k * 1.5)
		var col := Color(0.42, 0.04, 0.08).lerp(Color(0.1, 0.02, 0.05), float(k) / depth)
		if k == depth:
			c.draw_string_outline(FONT, o + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX, 12, INK)
		c.draw_string(FONT, o + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX, col)
	c.draw_string_outline(FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX, 9, INK)
	# ink drips sliding off the bottom of the letter
	for d in 2:
		var dx := -w * 0.25 + d * w * 0.45 + sin(i * 3.1 + d) * 8.0
		var cycle := fmod(_time * (0.25 + 0.07 * ((i + d) % 3)) + i * 0.37 + d * 0.5, 1.0)
		var length := 30.0 * smoothstep(0.0, 0.7, cycle)
		var a := 1.0 - smoothstep(0.85, 1.0, cycle)
		var base := Vector2(dx, 10.0)
		c.draw_line(base, base + Vector2(0, length), Color(INK, a), 6.0)
		c.draw_circle(base + Vector2(0, length), 5.0, Color(INK, a))
		c.draw_circle(base + Vector2(1, length - 1), 2.0, Color(0.6, 0.12, 0.16, a))


func _draw_menu() -> void:
	var m := _menu
	for it in _items:
		var a: float = clampf(it.appear, 0.0, 1.0)
		if a <= 0.01:
			continue
		var h: float = it.hover
		var px: int = it.px
		var p: Vector2 = it.pos + Vector2(0, (1.0 - it.appear) * 50.0 + sin(_time * 3.0 + it.pos.x) * 1.5 * h)
		var why := _why_not(it)
		var locked := why != ""
		var s := 1.0 + 0.16 * h * (0.4 if locked else 1.0) + 0.25 * float(it.pop)
		p.x += sin(_time * 55.0) * 9.0 * float(it.deny)
		m.draw_set_transform(p, sin(_time * 7.0) * 0.02 * h * float(not locked), Vector2(s, s))
		var o := Vector2(-it.w * 0.5, 0)
		var col := CREAM.lerp(GOLD, h)
		if locked:
			# greyed out, a padlock hung on it, and why, while it is looked at
			col = Color(0.5, 0.48, 0.54).lerp(Color(0.72, 0.68, 0.7), h)
			if _locked(it):
				var lock := Vector2(o.x - 30.0, -px * 0.36)
				m.draw_arc(lock + Vector2(0, -9), 9.0, PI, TAU, 12, Color(INK, a), 9.0)
				m.draw_arc(lock + Vector2(0, -9), 9.0, PI, TAU, 12, Color(col, a), 4.0)
				m.draw_rect(Rect2(lock + Vector2(-15, -10), Vector2(30, 25)), Color(INK, a))
				m.draw_rect(Rect2(lock + Vector2(-12, -7), Vector2(24, 19)), Color(col, a))
				m.draw_circle(lock + Vector2(0, 1), 3.5, Color(INK, a))
			if h > 0.02:
				var ww := FONT.get_string_size(why, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				m.draw_string_outline(FONT, Vector2(-ww * 0.5, 34), why, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 7, Color(INK, a * h))
				m.draw_string(FONT, Vector2(-ww * 0.5, 34), why, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GOLD, a * h))
		# shadow, ink outline, face
		m.draw_string(FONT, o + Vector2(4, 5), it.label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(RED.darkened(0.3), 0.85 * a))
		m.draw_string_outline(FONT, o, it.label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 9, Color(INK, a))
		m.draw_string(FONT, o, it.label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, a))
		if h > 0.02 and not locked and it.target == "@continue":
			# where the run was left, under CONTINUE
			var place := _place
			var pw := FONT.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			m.draw_string_outline(FONT, Vector2(-pw * 0.5, 34), place, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 7, Color(INK, a * h))
			m.draw_string(FONT, Vector2(-pw * 0.5, 34), place, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GOLD, a * h))
		if h > 0.02 and not locked:
			# a brush stroke draws itself in under the focused item
			var pts := PackedVector2Array()
			var n := 16
			for k in int(n * h) + 1:
				var t := k / float(n)
				pts.append(Vector2(o.x - 6 + (it.w + 12) * t, 12 + sin(t * 7.0 + _time * 4.0) * 2.0))
			if pts.size() > 1:
				m.draw_polyline(pts, Color(INK, a), 7.0)
				m.draw_polyline(pts, Color(RED, a), 4.0)
			# little chevrons either side, pulsing
			var pulse := 6.0 + 3.0 * sin(_time * 8.0)
			for side: float in [-1.0, 1.0]:
				var cx := (o.x - 22 - pulse) if side < 0 else (-o.x + 22 + pulse)
				var tri := PackedVector2Array([Vector2(cx, -px * 0.45 - 9), Vector2(cx, -px * 0.45 + 9), Vector2(cx + side * -11, -px * 0.45)])
				m.draw_colored_polygon(tri, Color(GOLD, a * h))
		m.draw_set_transform(Vector2.ZERO)
	if _software_gl:
		_draw_gl_warning(m)
	if _wipe >= 0.0:
		m.draw_circle(_wipe_from, _wipe * 1500.0, INK)


## The browser is drawing without the graphics card: say so, and how to fix it.
func _draw_gl_warning(m: Node2D) -> void:
	var lines := ["YOUR BROWSER IS RUNNING THE GAME WITHOUT YOUR GRAPHICS CARD, SO IT WILL LAG.",
		"TURN ON HARDWARE ACCELERATION IN THE BROWSER'S SETTINGS (OR TRY CHROME / EDGE), THEN RELOAD."]
	var box := Rect2(150, 12, 980, 64)
	m.draw_rect(box.grow(3.0), INK)
	m.draw_rect(box, RED.darkened(0.25))
	for i in lines.size():
		var w := FONT.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		m.draw_string(FONT, Vector2(640 - w * 0.5, box.position.y + 27 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, CREAM)
