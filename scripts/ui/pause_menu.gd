extends Control
## The pause screen, the same in 2D levels and 2.5D rooms (Esc / Start):
## a veil of ink over the frozen game, ink-navy and Ember-gold halftone
## rays swirling in, a hand-drawn comic burst (the Writer's red-pen ring)
## that pops in, "PAUSED" in gold lettering, and five slanted comic-tag
## buttons, each in a colour of the book (Ember gold, paper, Cavern teal,
## pencil blue, red pen). Nothing else is drawn over it.
## Keyboard (WASD / arrows, Enter / Space, Esc), controller, mouse.
##
##   PauseMenu.open_2d(player)   # player.gd, on the "pause" action
##   room.gd builds one for 2.5D and handles `chosen`
##
## Settings and Quire's shop (shop.gd; B opens it too) open on top of it
## and come back to it (the shop refreshes Vesper's loadout as it closes);
## for the rest it emits `chosen` (2.5D: room.gd acts) or, opened by
## open_2d(), acts itself: resume, retry (reload: back to the last
## checkpoint), main menu.

signal chosen(action: String)

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const Shop = preload("res://scripts/ui/shop.gd")
const MENU := "res://scenes/ui/main_menu.tscn"
const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.98, 0.95, 0.87)
const GOLD := Color(1.0, 0.82, 0.26)
const RED := Color(0.9, 0.2, 0.16)
const DULL := Color(0.5, 0.48, 0.58)
const BUTTON := Vector2(250, 58)
const SKEW := 11.0

## [label, action, colour, icon], three to a row (the last row centred)
const ITEMS := [
	["RESUME", "resume", Color(1.0, 0.76, 0.26), "play"],
	["RETRY", "retry", Color(0.98, 0.95, 0.87), "retry"],
	["SHOP", "shop", Color(0.42, 0.86, 0.8), "coin"],
	["SETTINGS", "settings", Color(0.52, 0.8, 1.0), "gear"],
	["MAIN MENU", "menu", Color(0.97, 0.45, 0.38), "door"],
]
const COLS := 3
const TILTS := [-0.03, 0.025, -0.02, 0.02, -0.025]

const RAYS_SHADER := """
shader_type canvas_item;
uniform float intro = 0.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
void fragment() {
	vec2 px = UV * rect_size;
	vec2 d = (UV - vec2(0.5, 0.4)) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(d);
	float a = atan(d.y, d.x) / TAU + 0.5 + TIME * 0.008 + (1.0 - intro) * 0.2;
	float wedge = step(0.5, fract(a * 11.0));
	// ink navy and Ember gold, printed: halftone dots in the opposite tone
	vec3 navy = vec3(0.08, 0.07, 0.2);
	vec3 gold = vec3(0.93, 0.7, 0.2);
	vec3 col = mix(navy, gold, wedge);
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / 13.0;
	float dots = 1.0 - smoothstep(0.18, 0.25, length(fract(g) - 0.5));
	col = mix(col, mix(vec3(0.2, 0.18, 0.42), vec3(0.62, 0.32, 0.1), wedge), dots * 0.7);
	// the rays reach out from behind the burst; darker toward the edges
	float reach = mix(0.0, 1.5, intro);
	float rays = smoothstep(reach, reach - 0.2, r);
	col = mix(col, navy * 0.5, smoothstep(0.45, 1.05, r) * 0.7);
	vec3 veil = vec3(0.02, 0.02, 0.06);
	COLOR = vec4(mix(veil, col, rays), max(0.7 * clamp(intro * 2.0, 0.0, 1.0), rays * intro * 0.97));  // nothing of the game reads through
}
"""

## Set by open_2d(): the menu acts on its own choices.
var handle_2d := false
var player: Node

var _items: Array = []  # the ITEMS shown, in order
var _rects: Array[Rect2] = []
var _focus := 0
var _hover: Array[float] = []
var _t := 0.0
var _boil := 0
var _rays: ColorRect
var _sub: Control  # Settings, on top
var _closing := -1.0  # resume: fading out
var _leaving := ""    # retry / menu: the ink blot
var _leave_t := -1.0


## 2D levels: pause and show the menu over the current scene.
static func open_2d(the_player: Node) -> void:
	var tree := the_player.get_tree()
	var layer := CanvasLayer.new()
	layer.name = "Pause"
	layer.layer = 85
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var menu: Control = load("res://scripts/ui/pause_menu.gd").new()
	menu.handle_2d = true
	menu.player = the_player
	layer.add_child(menu)
	tree.current_scene.add_child(layer)
	tree.paused = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_items = ITEMS.duplicate()
	_hover.resize(_items.size())
	_hover.fill(0.0)
	_rays = ColorRect.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.show_behind_parent = true
	var sh := Shader.new()
	sh.code = RAYS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_rays.material = mat
	add_child(_rays)


func _process(delta: float) -> void:
	_t += delta
	_boil = int(_t * 8.0)
	var mat := _rays.material as ShaderMaterial
	mat.set_shader_parameter("intro", _ease_out(_t / 0.35))
	mat.set_shader_parameter("rect_size", size)
	for i in _hover.size():
		_hover[i] = move_toward(_hover[i], 1.0 if i == _focus else 0.0, delta * 8.0)
	if _closing >= 0.0:
		_closing += delta
		modulate.a = 1.0 - clampf(_closing / 0.16, 0.0, 1.0)
		if _closing >= 0.16:
			_closing = -100.0
			_act("resume")
	if _leave_t >= 0.0:
		_leave_t += delta
		if _leave_t >= 0.35:
			_leave_t = -100.0
			_act(_leaving)
	queue_redraw()


# ------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if _sub != null or _closing >= 0.0 or _leave_t >= 0.0:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _t > 0.1:
			_closing = 0.0
		return
	var move := Vector2i.ZERO
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		move.x = -1
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		move.x = 1
	elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		move.y = -1
	elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		move.y = 1
	if move != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_step(move)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_choose(_focus)


func _gui_input(event: InputEvent) -> void:
	if _sub != null or not ("position" in event):
		return
	for i in _rects.size():
		if _rects[i].has_point(event.position):
			_focus = i
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_choose(i)


## Move the focus round the grid (wrapping).
func _step(move: Vector2i) -> void:
	var n := _items.size()
	if move.x != 0:
		_focus = (_focus + move.x + n) % n
	else:
		_focus = (_focus + move.y * COLS + n) % n


func _choose(i: int) -> void:
	if _t < 0.1 or _closing >= 0.0 or _leave_t >= 0.0:
		return
	_focus = i
	var action: String = _items[i][1]
	match action:
		"resume":
			_closing = 0.0
		"settings", "shop":
			_open_sub(action)
		"retry", "menu":
			_leaving = action
			_leave_t = 0.0
		_:
			_act(action)


## Settings / the shop on top; the pause screen comes back when it closes.
func _open_sub(action: String) -> void:
	_sub = Control.new()
	_sub.set_script(SettingsMenu if action == "settings" else Shop)
	if action == "settings":
		_sub.set("overlay", true)
	_sub.connect("closed", func():
		if is_instance_valid(_sub) and not _sub.is_queued_for_deletion():
			_sub.queue_free()
		_sub = null
		visible = true
		if action == "shop":
			_refresh_loadout())
	visible = false
	get_parent().add_child(_sub)


## What was bought or equipped takes effect at once (2D and 2.5D players).
func _refresh_loadout() -> void:
	var p: Node = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
	if p and p.has_method("refresh_loadout"):
		p.refresh_loadout()


func _act(action: String) -> void:
	if not handle_2d:
		chosen.emit(action)  # room.gd takes it from here
		return
	var tree := get_tree()
	match action:
		"resume":
			tree.paused = false
			get_parent().queue_free()
		"retry":
			tree.paused = false
			Engine.time_scale = 1.0
			tree.reload_current_scene()  # GameState puts you back at the last checkpoint
		"menu":
			tree.paused = false
			Engine.time_scale = 1.0
			tree.change_scene_to_file(MENU)


# ----------------------------------------------------------------- drawing

func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Elastic overshoot 0 -> ~1.12 -> 1 (the comic "pop").
func _pop(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x >= 1.0:
		return 1.0
	return 1.0 + pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * TAU / 3.0)


func _jit(seed_i: int, amount: float) -> float:
	return (float(absi(hash(Vector2i(seed_i, _boil))) % 1000) / 1000.0 - 0.5) * amount


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.4)
	var pop := _pop((_t - 0.02) / 0.42)
	if pop > 0.0:
		_draw_burst(c, pop)
		_draw_title(c + Vector2(0, 8))
	_rects.clear()
	var n := _items.size()
	for i in n:
		var row := floori(float(i) / COLS)
		var in_row := mini(COLS, n - row * COLS)
		var col := i % COLS
		var cx := size.x * 0.5 + (col - (in_row - 1) * 0.5) * 300.0
		var cy := c.y + 205.0 + row * 80.0
		_rects.append(Rect2(Vector2(cx, cy) - BUTTON * 0.5, BUTTON))
		_draw_button(i, Vector2(cx, cy))
	var hint := "ESC  RESUME      WASD / ARROWS  CHOOSE      ENTER  SELECT"
	var hw := FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var ha := clampf(_t / 0.4, 0.0, 1.0)
	var band := Rect2(size.x * 0.5 - hw * 0.5 - 22, size.y - 50, hw + 44, 34)
	draw_colored_polygon(_tag(band), Color(INK, 0.85 * ha))  # an ink strip so it reads on the rays
	draw_string(FONT, Vector2(size.x * 0.5 - hw * 0.5, size.y - 26), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(PAPER, 0.8 * ha))
	if _leave_t >= 0.0:  # an ink blot swallows the page before the scene changes
		var k := clampf(_leave_t / 0.35, 0.0, 1.0)
		draw_circle(_rects[_focus].get_center(), k * k * 1600.0, INK)


func _burst_points(c: Vector2, rx: float, ry: float, spikes: int, depth: float, seed_i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := TAU * i / (spikes * 2) + 0.12
		var k := 1.0 if i % 2 == 0 else 1.0 - depth
		k += _jit(seed_i + i, 0.045)  # hand-drawn wobble, re-rolled 8x a second
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts


func _draw_burst(c: Vector2, s: float) -> void:
	var rx := 360.0 * s
	var ry := 200.0 * s
	draw_colored_polygon(_burst_points(c + Vector2(12, 14), rx * 1.08, ry * 1.1, 13, 0.17, 3), Color(INK, 0.45))  # shadow
	draw_colored_polygon(_burst_points(c, rx * 1.08, ry * 1.1, 13, 0.17, 3), INK)
	draw_colored_polygon(_burst_points(c, rx * 1.03, ry * 1.05, 13, 0.17, 3), RED)  # the red pen
	draw_colored_polygon(_burst_points(c, rx * 0.9, ry * 0.91, 13, 0.14, 41), INK)
	draw_colored_polygon(_burst_points(c, rx * 0.875, ry * 0.885, 13, 0.14, 41), PAPER)
	# a warm glow in the middle of the page (light, the Ember's colour) and pencil hatching
	for k in 4:
		draw_circle(c, (150.0 - k * 32.0) * s, Color(GOLD, 0.07))
	var x := c.x - rx * 0.62
	while x < c.x + rx * 0.62:
		draw_line(Vector2(x, c.y + ry * 0.5), Vector2(x + 26, c.y + ry * 0.5 - 26), Color(0.55, 0.52, 0.5, 0.22 * s), 1.2)
		x += 13.0


func _draw_title(c: Vector2) -> void:
	var text := "PAUSED"
	var px := 150
	var total := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := c.x - total * 0.5
	for i in text.length():
		var ch := text[i]
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var land := _pop((_t - 0.1 - i * 0.04) / 0.36)  # letters drop in one by one
		if land > 0.0:
			var drop := (1.0 - minf(land, 1.0)) * -120.0
			var p := Vector2(x + w * 0.5, c.y + 52 + drop + sin(_t * 2.4 + i * 0.8) * 2.5)
			draw_set_transform(p, sin(_t * 1.6 + i * 1.3) * 0.035 + (i % 2 - 0.5) * 0.06, Vector2(land, land))
			var o := Vector2(-w * 0.5, 0)
			draw_string(FONT, o + Vector2(7, 9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, RED)  # red-pen shadow
			draw_string_outline(FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 18, INK)
			draw_string(FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, GOLD)
			draw_string(FONT, o + Vector2(0, -4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1.0, 0.95, 0.7, 0.35))  # top shine
			draw_set_transform(Vector2.ZERO)
		x += w


func _tag(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(SKEW, 0), Vector2(r.end.x + SKEW, r.position.y),
		r.end - Vector2(SKEW, 0), Vector2(r.position.x - SKEW, r.end.y)])


func _draw_button(i: int, at: Vector2) -> void:
	var appear := _pop((_t - 0.2 - i * 0.045) / 0.34)
	if appear <= 0.0:
		return
	var h: float = _hover[i]
	var it: Array = _items[i]
	var col: Color = it[2]
	var sc := minf(appear, 1.15) * (1.0 + 0.08 * h)
	var rot: float = TILTS[i % TILTS.size()] + sin(_t * 8.0) * 0.025 * h
	draw_set_transform(at + Vector2(0, (1.0 - minf(appear, 1.0)) * 30.0), rot, Vector2(sc, sc))
	var r := Rect2(-BUTTON * 0.5, BUTTON)
	var tag := _tag(r)
	var big := _tag(r.grow(4.0))
	draw_colored_polygon(_shifted(big, Vector2(6, 8)), Color(INK, 0.5))  # drop shadow
	if h > 0.05:  # focused: a paper edge round it, like a sticker on the page
		draw_colored_polygon(_tag(r.grow(4.0 + 5.0 * h)), Color(PAPER, h))
	draw_colored_polygon(big, INK)
	draw_colored_polygon(tag, col.lerp(DULL, 0.5 * (1.0 - h)))
	draw_colored_polygon(_tag(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 7))), Color(1, 1, 1, 0.35 + 0.25 * h))  # shine
	_icon(it[3], Vector2(r.position.x + 32, 0), Color(INK, 0.85 + 0.15 * h))
	var label: String = it[0]
	var lw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	draw_string(FONT, Vector2(r.position.x + 58 + (r.size.x - 70 - lw) * 0.5, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, INK)
	if h > 0.5:  # comic emphasis marks at the corners
		for k in 3:
			var d := Vector2.from_angle(-2.4 + k * 0.35)
			var o := Vector2(r.position.x - 6, r.position.y - 4)
			draw_line(o + d * 10.0, o + d * (20.0 + 4.0 * sin(_t * 12.0 + k)), PAPER, 3.0)
	draw_set_transform(Vector2.ZERO)


func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


func _icon(kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -11), c + Vector2(11, 0), c + Vector2(-8, 11)]), col)
		"retry":
			draw_arc(c, 10.0, 0.7, TAU - 0.3, 16, col, 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(12, -11), c + Vector2(13, 2), c + Vector2(3, -4)]), col)
		"coin":  # a little stack of coins
			for k in 3:
				var o := c + Vector2(-3 + k * 2, 8 - k * 7)
				draw_colored_polygon(PackedVector2Array([o + Vector2(-10, -3), o + Vector2(10, -3), o + Vector2(10, 3), o + Vector2(-10, 3)]), col)
				draw_arc(o + Vector2(0, -3), 10.0, PI, TAU, 10, PAPER, 1.5)
		"gear":
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0 + _t * 0.6)
				draw_line(c + d * 7.0, c + d * 13.0, col, 4.5)
			draw_arc(c, 8.0, 0, TAU, 16, col, 4.0)
		"door":
			draw_rect(Rect2(c + Vector2(-8, -12), Vector2(16, 24)), col, false, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -12), c + Vector2(4, -8), c + Vector2(4, 14), c + Vector2(-8, 12)]), col)
			draw_circle(c + Vector2(1, 1), 1.8, PAPER)
