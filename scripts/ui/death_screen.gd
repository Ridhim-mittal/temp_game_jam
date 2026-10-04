extends Control
## The 2D death screen: the frozen game behind a dark veil, cyan/yellow
## halftone rays swirling in, a pop-art comic burst (white, pink-red ring,
## ink outline) that pops in with an elastic overshoot, "YOU DIED" letters
## (rounded, bubbly Chewy lettering) bouncing in one by one, and two pill
## buttons: RESTART (back to the last checkpoint pen)
## and MAIN MENU. Keyboard (A/D, arrows, W/S), Enter/Space/jump and mouse.
##
##   DeathScreen.open(tree)   # player.gd calls this from _die()

const FONT = preload("res://assets/fonts/Chewy-Regular.ttf")
const MENU := "res://scenes/ui/main_menu.tscn"
const INK := Color(0.05, 0.03, 0.1)
const CREAM := Color(0.99, 0.97, 0.93)
const RING := Color(0.93, 0.16, 0.36)
const TITLE := Color(0.96, 0.27, 0.3)
const TITLE_SHADOW := Color(0.16, 0.36, 0.46)
const CYAN := Color(0.22, 0.66, 0.85)
const YELLOW := Color(1.0, 0.84, 0.25)
const OPTIONS := ["RESTART", "MAIN MENU"]

const RAYS_SHADER := """
shader_type canvas_item;
uniform float intro = 0.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
void fragment() {
	vec2 px = UV * rect_size;
	vec2 d = (UV - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(d);
	float a = atan(d.y, d.x) / TAU + 0.5 + TIME * 0.01 + (1.0 - intro) * 0.25;
	float wedge = step(0.5, fract(a * 9.0));
	vec3 col = mix(vec3(0.22, 0.66, 0.85), vec3(1.0, 0.84, 0.25), wedge);
	// white halftone dots on cyan, dark dots on yellow (pop-art print)
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / 14.0;
	float dd = length(fract(g) - 0.5);
	float dots = 1.0 - smoothstep(0.2, 0.26, dd);
	col = mix(col, mix(vec3(0.97), vec3(0.85, 0.42, 0.12), wedge), dots * mix(0.8, 0.6, wedge));
	// rays reach out from behind the burst as the screen opens
	float reach = mix(0.0, 1.4, intro);
	float rays = smoothstep(reach, reach - 0.15, r) * smoothstep(0.08, 0.4, r);
	// dark veil over the frozen game underneath the rays, darker at the edges
	vec3 veil = vec3(0.03, 0.03, 0.08);
	float veil_a = 0.6 * clamp(intro * 1.6, 0.0, 1.0);
	col = mix(col, veil, smoothstep(0.55, 1.1, r) * 0.55);
	COLOR = vec4(mix(veil, col, rays), max(veil_a, rays * intro));
}
"""

var _t := 0.0
var _choice := 0
var _hover := [0.0, 0.0]
var _boil := 0
var _leaving := ""
var _leave_t := -1.0
var _rays: ColorRect
var _buttons: Array[Button] = []


static func open(tree: SceneTree) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var screen: Control = load("res://scripts/ui/death_screen.gd").new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(screen)
	tree.current_scene.add_child(layer)
	tree.paused = true


func _ready() -> void:
	_rays = ColorRect.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = RAYS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_rays.material = mat
	_rays.show_behind_parent = true
	add_child(_rays)
	for i in OPTIONS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, empty)
		b.size = Vector2(220, 64)
		b.pressed.connect(_choose.bind(i))
		b.mouse_entered.connect(func(): _choice = i)
		add_child(b)
		_buttons.append(b)


func _process(delta: float) -> void:
	_t += delta
	_boil = int(_t * 8.0)
	(_rays.material as ShaderMaterial).set_shader_parameter("intro", _ease_out(_t / 0.6))
	(_rays.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	for i in _hover.size():
		_hover[i] = move_toward(_hover[i], 1.0 if i == _choice else 0.0, delta * 7.0)
	# buttons sit side by side in the lower part of the burst
	var c := size * 0.5
	for i in _buttons.size():
		_buttons[i].position = c + Vector2(-240 + i * 260, 92)
	if _leave_t >= 0.0:
		_leave_t += delta
		if _leave_t > 0.4:
			_leave_t = -100.0
			get_tree().paused = false
			Engine.time_scale = 1.0
			if _leaving == "restart":
				get_tree().reload_current_scene()  # GameState respawns you at the last pen
			else:
				get_tree().change_scene_to_file(MENU)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _t < 0.9 or _leave_t >= 0.0:
		return  # let the animation land before accepting input
	var step := 0
	if event.is_action_pressed("move_left") or event.is_action_pressed("up"):
		step = -1
	elif event.is_action_pressed("move_right") or event.is_action_pressed("down"):
		step = 1
	if step != 0:
		_choice = (_choice + step + OPTIONS.size()) % OPTIONS.size()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_choose(_choice)


func _choose(i: int) -> void:
	if _t < 0.9 or _leave_t >= 0.0:
		return
	_choice = i
	_leaving = "restart" if i == 0 else "menu"
	_leave_t = 0.0


# ------------------------------------------------------------------ easing

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


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var c := size * 0.5
	var pop := _pop((_t - 0.12) / 0.7)
	if pop > 0.0:
		_draw_burst(c + Vector2(0, -10), pop)
		_draw_title(c + Vector2(0, -40))
		for i in OPTIONS.size():
			_draw_button(i)
	if _leave_t >= 0.0:
		# ink blot swallows the screen before the scene changes
		var k := clampf(_leave_t / 0.4, 0.0, 1.0)
		draw_circle(_buttons[_choice].position + _buttons[_choice].size * 0.5, k * k * 1600.0, INK)


func _burst_points(c: Vector2, rx: float, ry: float, spikes: int, depth: float, seed_i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := TAU * i / (spikes * 2)
		var k := 1.0 if i % 2 == 0 else 1.0 - depth
		k += _jit(seed_i + i, 0.05)  # hand-drawn wobble, re-rolled 8x a second
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts


func _draw_burst(c: Vector2, s: float) -> void:
	var rx := 390.0 * s
	var ry := 250.0 * s
	draw_colored_polygon(_burst_points(c + Vector2(10, 12), rx * 1.08, ry * 1.1, 14, 0.16, 7), Color(INK, 0.35))  # drop shadow
	draw_colored_polygon(_burst_points(c, rx * 1.08, ry * 1.1, 14, 0.16, 7), INK)
	draw_colored_polygon(_burst_points(c, rx * 1.04, ry * 1.06, 14, 0.16, 7), RING)
	draw_colored_polygon(_burst_points(c, rx * 0.92, ry * 0.93, 14, 0.13, 29), INK)
	draw_colored_polygon(_burst_points(c, rx * 0.9, ry * 0.91, 14, 0.13, 29), CREAM)


func _draw_title(c: Vector2) -> void:
	var text := "YOU DIED"
	var size_px := 150
	var total := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := c.x - total * 0.5
	for i in text.length():
		var ch := text[i]
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var land := _pop((_t - 0.35 - i * 0.06) / 0.45)  # letters drop in one by one
		if land > 0.0 and ch != " ":
			var drop := (1.0 - minf(land, 1.0)) * -160.0
			var bob := sin(_t * 2.6 + i * 0.7) * 3.0
			var p := Vector2(x + w * 0.5, c.y + 50 + drop + bob)
			draw_set_transform(p, sin(_t * 1.8 + i) * 0.04, Vector2(land, land))
			var o := Vector2(-w * 0.5, 0)
			draw_string(FONT, o + Vector2(6, 9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, TITLE_SHADOW)
			draw_string_outline(FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 16, INK)
			draw_string(FONT, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, TITLE)
			draw_set_transform(Vector2.ZERO)
		x += w


func _draw_button(i: int) -> void:
	var b := _buttons[i]
	var appear := _pop((_t - 0.75 - i * 0.08) / 0.5)
	if appear <= 0.0:
		return
	var h: float = _hover[i]
	var c := b.position + b.size * 0.5 + Vector2(0, (1.0 - minf(appear, 1.0)) * 40.0)
	var wob := sin(_t * 9.0) * 0.04 * h
	var sc := appear * (1.0 + 0.1 * h)
	draw_set_transform(c, wob, Vector2(sc, sc))
	var r := Rect2(-b.size * 0.5, b.size)
	var pill := _pill(r)
	draw_colored_polygon(_shift(pill, Vector2(4, 6)), Color(INK, 0.4))  # shadow
	draw_colored_polygon(_grow(pill, 3.5), INK)
	draw_colored_polygon(pill, YELLOW.lerp(CREAM, 1.0 - h))
	# icon
	var ic := Vector2(r.position.x + 34, 0)
	if i == 0:
		draw_arc(ic, 11.0, 0.6, TAU - 0.4, 16, INK, 4.0)  # circular arrow
		draw_colored_polygon(PackedVector2Array([ic + Vector2(14, -10), ic + Vector2(14, 2), ic + Vector2(4, -4)]), INK)
	else:
		draw_colored_polygon(PackedVector2Array([ic + Vector2(-13, 0), ic + Vector2(0, -12), ic + Vector2(13, 0)]), INK)  # house
		draw_rect(Rect2(ic + Vector2(-9, 0), Vector2(18, 12)), INK)
	var label: String = OPTIONS[i]
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(FONT, Vector2(r.position.x + 58 + (r.size.x - 70 - w) * 0.5, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	draw_set_transform(Vector2.ZERO)


func _pill(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := r.size.y * 0.5
	for i in 11:
		var a := -PI * 0.5 + PI * i / 10.0
		pts.append(Vector2(r.end.x - rad, 0) + Vector2.from_angle(a) * rad)
	for i in 11:
		var a := PI * 0.5 + PI * i / 10.0
		pts.append(Vector2(r.position.x + rad, 0) + Vector2.from_angle(a) * rad)
	return pts


func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


func _grow(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := Geometry2D.offset_polygon(poly, d, Geometry2D.JOIN_ROUND)
	return out[0] if not out.is_empty() else poly
