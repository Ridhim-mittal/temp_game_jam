extends Control
## First-run controls tutorial. One move at a time, its key flashes in the
## middle of the screen until the player does it, then it drops into a tray
## of learned keys at the bottom. Moves that only matter later (Ember, Flash,
## Heal) pop up on their own the first time they're useful.
##
## Every step is remembered in Profile, so each one plays only once (a
## restart picks up where it left off); Esc skips the rest of the mode and
## Settings -> Tutorials plays them all again. While the basics run, the
## level's "Controls" hint line is hidden.
##
##   Tutorial.start(self, self, "2d")               # scripts/player/player.gd
##   Tutorial.start(room, player, "25d", story_ui)  # scripts/world25/room.gd

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(1.0, 0.97, 0.88)
const YELLOW := Color(1.0, 0.84, 0.24)
const RED := Color(0.92, 0.3, 0.22)

## Key caps: [shown, input action]. "LMB" / "RMB" draw a mouse.
## Four keys draw as a W / A S D cluster. On a controller each step shows
## its button from PAD instead, and the move keys become the left stick.
const BASICS := {
	"2d": [
		{"id": "move", "word": "MOVE", "keys": [["A", "move_left"], ["D", "move_right"]]},
		{"id": "jump", "word": "JUMP", "keys": [["SPACE", "jump"]], "hold": 0.3},
		{"id": "attack", "word": "ATTACK", "keys": [["LMB", "attack"]]},
		{"id": "dash", "word": "DASH", "keys": [["RMB", "dash"]]},
	],
	"25d": [
		{"id": "move", "word": "MOVE", "keys": [["W", "up"], ["A", "move_left"], ["S", "down"], ["D", "move_right"]]},
		{"id": "jump", "word": "JUMP", "keys": [["SPACE", "jump"]]},
		{"id": "attack", "word": "ATTACK", "keys": [["LMB", "attack"]]},
		{"id": "dash", "word": "DASH", "keys": [["SHIFT", "dash"]]},
	],
}
## Taught once, the first time `when` holds (see _ready_for()).
const LATER := {
	"2d": [
		{"id": "ember", "word": "EMBER", "keys": [["Q", "ember"]], "hold": 0.8, "when": "near_lantern"},
		{"id": "wall", "word": "WALL JUMP", "keys": [["SPACE", "jump"]], "when": "on_wall"},
	],
	"25d": [
		{"id": "flash", "word": "FLASH", "keys": [["Q", "flash"]], "when": "near_monster"},
		{"id": "heal", "word": "HEAL", "keys": [["F", "heal"]], "hold": 0.6, "when": "hurt"},
	],
}
## Controller button per action (Xbox layout, as bound in input_setup.gd).
const PAD := {"jump": "A", "attack": "X", "dash": "RB", "flash": "Y", "heal": "B", "ember": "Y"}
const PAD_COLORS := {"A": Color(0.3, 0.72, 0.3), "B": Color(0.9, 0.28, 0.22),
	"X": Color(0.22, 0.48, 0.95), "Y": Color(0.95, 0.72, 0.1)}
const STICK_DIRS := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}
const CAP := 88.0  # key height in the middle of the screen
const CLUSTER_CAP := 64.0  # ...when a move has several keys
const TRAY_SCALE := 0.5

var mode := "2d"
var player: Node
var story: Node  # story_ui.gd: the tutorial waits while it talks
var host: Node
## Height of the key on screen (0..1); higher in 2.5D to clear the player.
var center_y := 0.3

var _basics: Array = []  # basic steps not done yet
var _later: Array = []
var _tray: Array = []  # basic steps done
var _flying: Array = []  # [step, t]
var _current := {}
var _pressed: Array = []
var _hold_t := 0.0
var _appear := 0.0
var _done_t := -1.0
var _alpha := 0.0
var _tray_alpha := 0.0
var _tray_linger := -1.0
var _wait := 0.8
var _time := 0.0
var _hint: CanvasItem
var _hint_was := true
var _hint_restored := false
var _pad := false  # the last input came from a controller


## Adds the tutorial for `mode` over the game, unless it has all been seen.
static func start(host_node: Node, the_player: Node, the_mode: String, story_ui: Node = null) -> void:
	var profile := host_node.get_node_or_null("/root/Profile")
	if profile == null:
		return
	var todo := false
	for s in BASICS[the_mode] + LATER[the_mode]:
		todo = todo or not profile.tutorial_seen(the_mode + "." + s.id)
	if not todo:
		return
	var layer := CanvasLayer.new()
	layer.name = "Tutorial"
	layer.layer = 60
	var t: Control = load("res://scripts/ui/tutorial.gd").new()
	t.mode = the_mode
	t.player = the_player
	t.story = story_ui
	t.host = host_node
	t.center_y = 0.25 if the_mode == "25d" else 0.3
	layer.add_child(t)
	host_node.add_child.call_deferred(layer)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # to hide under pause menus (below)
	for s in BASICS[mode]:
		if _seen(s):
			_tray.append(s)
		else:
			_basics.append(s)
	for s in LATER[mode]:
		if not _seen(s):
			_later.append(s)
	_tray_alpha = 1.0 if not _basics.is_empty() and not _tray.is_empty() else 0.0
	var scope := host.owner if host.owner else host  # the 2D player lives in a level scene
	_hint = scope.find_child("Controls", true, false) as CanvasItem
	if _hint:
		_hint_was = _hint.visible
	_hint_restored = _basics.is_empty()
	_pad = not Input.get_connected_joypads().is_empty()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_pad = false
	if _current.is_empty() or _alpha < 0.5 or get_tree().paused:
		return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK)
	if skip:
		get_viewport().set_input_as_handled()  # skip, don't pause / leave
		for s in BASICS[mode] + LATER[mode]:
			_mark(s)
		_basics.clear()
		_later.clear()
		_current = {}
		_flying.clear()
		_tray_linger = 0.0
		_restore_hint()


func _process(delta: float) -> void:
	visible = not get_tree().paused
	if not visible:
		return
	_time += delta
	if not is_instance_valid(player):
		return
	var quiet := _quiet()
	_wait -= delta
	if _current.is_empty() and quiet and _wait <= 0.0:
		_next()
	_alpha = move_toward(_alpha, 1.0 if quiet and not _current.is_empty() else 0.0, delta * 5.0)
	if not _current.is_empty():
		_appear = minf(_appear + delta * 3.5, 1.0)
		if _done_t < 0.0:
			if _alpha > 0.9:
				_check_input(delta)
		else:
			_done_t += delta
			if _done_t > (0.35 if _is_basic(_current) else 0.9):
				_finish_step()
	for f in _flying:
		f[1] += delta * 2.6
	while not _flying.is_empty() and _flying[0][1] >= 1.0:
		_tray.append(_flying.pop_front()[0])
		if _basics.is_empty() and _flying.is_empty():
			_tray_linger = 2.5
	if _hint and not _hint_restored and (not _basics.is_empty() or not _flying.is_empty() or _is_basic(_current)):
		_hint.visible = false
	if _tray_linger >= 0.0:
		_tray_linger -= delta
		if _tray_linger < 0.0:
			_restore_hint()
	var tray_on := not _basics.is_empty() or not _flying.is_empty() or _tray_linger >= 0.0 \
		or _is_basic(_current)
	_tray_alpha = move_toward(_tray_alpha, 1.0 if tray_on and not _tray.is_empty() else 0.0, delta * 3.0)
	if _basics.is_empty() and _later.is_empty() and _current.is_empty() and _flying.is_empty() \
			and _tray_alpha <= 0.0 and _alpha <= 0.0:
		get_parent().queue_free()
		return
	queue_redraw()


## Nothing else is talking and the player can act.
func _quiet() -> bool:
	if "dead" in player and player.dead:
		return false
	return story == null or not story.has_method("busy") or not story.busy()


func _next() -> void:
	if not _basics.is_empty():
		_show(_basics.pop_front())
		return
	if not _flying.is_empty() or _tray_linger >= 0.0:
		return  # let the finished tray settle first
	for s in _later:
		if _ready_for(s.when):
			_later.erase(s)
			_show(s)
			return


func _show(s: Dictionary) -> void:
	_current = s
	_pressed.resize(s.keys.size())
	_pressed.fill(false)
	_hold_t = 0.0
	_appear = 0.0
	_done_t = -1.0


func _ready_for(when: String) -> bool:
	match when:
		"near_lantern":
			for l in get_tree().get_nodes_in_group("lantern"):
				if l is Node2D and l.global_position.distance_to(player.global_position) < 320.0:
					return true
		"on_wall":
			return "_wall_dir" in player and player._wall_dir != 0
		"near_monster":
			return _nearest_monster() < 6.0
		"hurt":
			return player.health < player.max_health and player.fuel >= player.heal_cost \
				and player.is_on_floor() and _nearest_monster() > 7.0
	return false


func _nearest_monster() -> float:
	var best := INF
	var enemies := host.get_node_or_null("Enemies")
	if enemies:
		for m in enemies.get_children():
			if m is Node3D and m.is_visible_in_tree() and not ("dead" in m and m.dead):
				best = minf(best, m.global_position.distance_to(player.global_position))
	return best


func _check_input(delta: float) -> void:
	var keys: Array = _current.keys
	if _current.has("hold"):
		var down := _down(keys[0][1])
		_hold_t = clampf(_hold_t + (delta if down else -delta * 2.0), 0.0, _current.hold)
		_pressed[0] = down
		if _hold_t >= _current.hold:
			_done_t = 0.0
		return
	for i in keys.size():
		_pressed[i] = _pressed[i] or _down(keys[i][1])
	if not false in _pressed:
		_done_t = 0.0


func _down(action: String) -> bool:
	# right click is Flash in 2.5D, not dash (clearing_player.gd)
	if action == "dash" and mode == "25d" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return false
	return Input.is_action_pressed(action)


func _finish_step() -> void:
	_mark(_current)
	if _is_basic(_current):
		_flying.append([_current, 0.0])
	_current = {}
	_wait = 0.25


func _is_basic(s: Dictionary) -> bool:
	return not s.is_empty() and BASICS[mode].has(s)


func _seen(s: Dictionary) -> bool:
	return get_node("/root/Profile").tutorial_seen(mode + "." + s.id)


func _mark(s: Dictionary) -> void:
	get_node("/root/Profile").mark_tutorial(mode + "." + s.id)


func _exit_tree() -> void:
	_restore_hint()


func _restore_hint() -> void:
	if _hint and is_instance_valid(_hint) and not _hint_restored:
		_hint.visible = _hint_was
	_hint_restored = true


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * center_y)
	if _tray_alpha > 0.0:
		_draw_tray()
	for f in _flying:
		var t := ease(clampf(f[1], 0.0, 1.0), -2.0)
		var to := _tray_slot(f[0])
		var k := lerpf(1.0, TRAY_SCALE, t)
		_draw_keys(f[0], c.lerp(to, t), k, 1.0, true)
	if _current.is_empty() or _alpha <= 0.0:
		return
	var pop := _back_out(_appear)
	var done := _done_t >= 0.0
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var a := _alpha
	# starburst
	var r := (96.0 + 8.0 * pulse) * pop
	_burst(c, r, Color(YELLOW, (0.28 + 0.2 * pulse) * a), _time * 0.4)
	_draw_keys(_current, c, pop, a, done)
	var ext := _keys_size(_current, pop)
	var rr := maxf(ext.x, ext.y) * 0.5 + 22.0  # hold ring
	var above := rr + 18.0 if _current.has("hold") else ext.y * 0.5 + 34.0
	var below := rr + 38.0 if _current.has("hold") else ext.y * 0.5 + 44.0
	if _current.has("hold") and not done:
		draw_arc(c, rr, 0, TAU, 64, Color(INK, a), 12.0)
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * _hold_t / _current.hold, 64, Color(YELLOW, a), 6.0)
		_text(Vector2(c.x + rr + 12, c.y + 8), "HOLD", 22, Color(YELLOW, a), a, false)
	if done:
		var t := clampf(_done_t / 0.35, 0.0, 1.0)
		draw_arc(c, maxf(ext.x, ext.y) * 0.5 + 10.0 + 70.0 * t, 0, TAU, 64, Color(PAPER, (1.0 - t) * a), 6.0 * (1.0 - t) + 1.0)
		if not _is_basic(_current):
			_nice(c + Vector2(ext.x * 0.5 + 40.0, -ext.y * 0.5 - 10.0), minf(_done_t * 5.0, 1.0) * a)
	_text(Vector2(c.x, c.y + below), _current.word, 34, Color(PAPER, a), a)
	if _is_basic(_current):
		var n: int = BASICS[mode].size()
		var lit: int = BASICS[mode].find(_current) + (1 if done else 0)
		for i in n:
			var p := Vector2(c.x + (i - (n - 1) * 0.5) * 20.0, c.y - above)
			draw_circle(p, 6.5, Color(INK, a))
			draw_circle(p, 4.0, Color(YELLOW, a) if i < lit else Color(PAPER, 0.35 * a))
	# skip
	var hint_up := _hint != null and is_instance_valid(_hint) and _hint.visible
	var sk := Vector2(size.x - 34, size.y - (100.0 if hint_up else 40.0))
	_text(sk + Vector2(0, 8), "SKIP", 22, Color(PAPER, 0.9 * a), a, false, true)
	var sw := FONT.get_string_size("SKIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var key := "BACK" if _pad else "ESC"
	_cap(sk - Vector2(sw + 14 + _key_w(key, 30.0) * 0.5, 0), key, 30.0, 0.0, false, a)


func _draw_tray() -> void:
	for s in _tray:
		_draw_keys(s, _tray_slot(s), TRAY_SCALE, _tray_alpha, false)
		var ext := _keys_size(s, TRAY_SCALE)
		_text(_tray_slot(s) + Vector2(0, ext.y * 0.5 + 20.0), s.word, 17, Color(PAPER, _tray_alpha), _tray_alpha)


## Where a basic step sits in the tray (every basic has a fixed slot).
func _tray_slot(s: Dictionary) -> Vector2:
	var steps: Array = BASICS[mode]
	var gap := 30.0
	var total := -gap
	for o in steps:
		total += _keys_size(o, TRAY_SCALE).x + gap
	var x := size.x * 0.5 - total * 0.5
	for o in steps:
		var w := _keys_size(o, TRAY_SCALE).x
		if o == s:
			break
		x += w + gap
	return Vector2(x + _keys_size(s, TRAY_SCALE).x * 0.5, size.y - 78.0)


## What the caps of a step show: its keys, or its controller button.
func _labels(s: Dictionary) -> Array:
	if _pad:
		return ["STICK"] if STICK_DIRS.has(s.keys[0][1]) else [PAD.get(s.keys[0][1], "?")]
	var out := []
	for key in s.keys:
		out.append(key[0])
	return out


func _cap_h(s: Dictionary) -> float:
	return CAP if _labels(s).size() == 1 else CLUSTER_CAP


## Offsets of each key cap from the middle of the group.
func _key_offsets(s: Dictionary, k: float) -> Array:
	var h := _cap_h(s) * k
	var gap := 10.0 * k
	var labels := _labels(s)
	var out := []
	if labels.size() == 4:
		var step := h + gap
		out = [Vector2(0, -step * 0.5), Vector2(-step, step * 0.5), Vector2(0, step * 0.5), Vector2(step, step * 0.5)]
		return out
	var total := -gap
	for label in labels:
		total += _key_w(label, h) + gap
	var x := -total * 0.5
	for label in labels:
		var w := _key_w(label, h)
		out.append(Vector2(x + w * 0.5, 0))
		x += w + gap
	return out


func _keys_size(s: Dictionary, k: float) -> Vector2:
	var h := _cap_h(s) * k
	var gap := 10.0 * k
	var labels := _labels(s)
	if labels.size() == 4:
		return Vector2(h * 3.0 + gap * 2.0, h * 2.0 + gap)
	if labels[0] == "STICK":
		return Vector2.ONE * _key_w("STICK", h)
	var total := -gap
	for label in labels:
		total += _key_w(label, h) + gap
	return Vector2(total, h)


func _draw_keys(s: Dictionary, at: Vector2, k: float, a: float, lit: bool) -> void:
	var offs := _key_offsets(s, k)
	var labels := _labels(s)
	var live := s == _current and _done_t < 0.0
	var pulse := 0.5 + 0.5 * sin(_time * 7.0) if s == _current else 0.0
	for i in labels.size():
		var h := _cap_h(s) * k
		if labels[i] == "STICK":
			_stick(at + offs[i], h, s, lit, pulse, a)
			continue
		var on: bool = lit or (s == _current and i < _pressed.size() and _pressed[i])
		var glow := 1.0 if on else pulse * 0.35
		if _pad and PAD_COLORS.has(labels[i]):
			_face(at + offs[i], labels[i], h, glow, on and live, a)
		else:
			_cap(at + offs[i], labels[i], h, glow, on and live, a)


func _key_w(label: String, h: float) -> float:
	if label == "STICK":
		return h * 1.25
	if _pad and PAD_COLORS.has(label):
		return h
	if label == "LMB" or label == "RMB":
		return h * 0.8
	return maxf(h, FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.5)).x + h * 0.6)


## A comic key cap: ink outline, drop shadow, paper face that warms to
## yellow with `glow`; `down` sinks it into its shadow.
func _cap(c: Vector2, label: String, h: float, glow: float, down: bool, a: float) -> void:
	var w := _key_w(label, h)
	var sink := h * 0.07 if down else 0.0
	var r := Rect2(c - Vector2(w, h) * 0.5 + Vector2(0, sink), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(h * 0.2))
	sb.anti_aliasing = true
	sb.bg_color = Color(INK, 0.4 * a)
	draw_style_box(sb, Rect2(c - Vector2(w, h) * 0.5 + Vector2(h * 0.05, h * 0.11), Vector2(w, h)))
	sb.bg_color = Color(INK, a)
	draw_style_box(sb, r.grow(maxf(h * 0.05, 2.0)))
	sb.bg_color = Color(PAPER.lerp(YELLOW, glow * 0.9), a)
	draw_style_box(sb, r)
	sb.bg_color = Color(1, 1, 1, 0.5 * a)
	sb.set_corner_radius_all(int(h * 0.1))
	draw_style_box(sb, Rect2(r.position + Vector2(h * 0.12, h * 0.08), Vector2(w - h * 0.24, h * 0.14)))
	if label == "LMB" or label == "RMB":
		_mouse(r.get_center(), h * 0.62, label == "LMB", a)
		return
	var fs := int(h * 0.5)
	var s := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(FONT, Vector2(r.get_center().x - s.x * 0.5, r.get_center().y + fs * 0.36), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, a))


## A round controller face button with its letter in the button's colour.
func _face(c: Vector2, label: String, h: float, glow: float, down: bool, a: float) -> void:
	var r := h * 0.5
	var at := c + Vector2(0, h * 0.07 if down else 0.0)
	draw_circle(c + Vector2(h * 0.05, h * 0.11), r, Color(INK, 0.4 * a), true, -1.0, true)
	draw_circle(at, r + maxf(h * 0.05, 2.0), Color(INK, a), true, -1.0, true)
	draw_circle(at, r, Color(PAPER.lerp(YELLOW, glow * 0.9), a), true, -1.0, true)
	var fs := int(h * 0.56)
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(at.x - w * 0.5, at.y + fs * 0.36)
	draw_string_outline(FONT, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(int(h * 0.08), 2) * 2, Color(INK, a))
	draw_string(FONT, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAD_COLORS[label], a))


## The left stick for a move step: an arrow per direction it needs, lit
## once pushed; the knob follows the stick while it's being taught.
func _stick(c: Vector2, h: float, s: Dictionary, lit: bool, pulse: float, a: float) -> void:
	var r := _key_w("STICK", h) * 0.5
	draw_circle(c + Vector2(h * 0.05, h * 0.11), r, Color(INK, 0.4 * a), true, -1.0, true)
	draw_circle(c, r + maxf(h * 0.05, 2.0), Color(INK, a), true, -1.0, true)
	draw_circle(c, r, Color(PAPER.lerp(YELLOW, 0.9 if lit else pulse * 0.25), a), true, -1.0, true)
	for i in s.keys.size():
		var dir: Vector2 = STICK_DIRS[s.keys[i][1]]
		var on: bool = lit or (s == _current and i < _pressed.size() and _pressed[i])
		var side := dir.orthogonal() * r * 0.17
		draw_colored_polygon(PackedVector2Array([c + dir * r * 0.9, c + dir * r * 0.64 + side, c + dir * r * 0.64 - side]),
			Color(YELLOW if on else INK, a if on else 0.55 * a))
	var knob := Vector2.ZERO
	if s == _current and not lit:
		knob = Input.get_vector("move_left", "move_right", "up", "down") * r * 0.2
	draw_circle(c + knob, r * 0.4 + maxf(h * 0.04, 1.5), Color(INK, a), true, -1.0, true)
	draw_circle(c + knob, r * 0.4, Color(PAPER.darkened(0.12), a), true, -1.0, true)
	draw_circle(c + knob + Vector2(-r, -r) * 0.12, r * 0.14, Color(1, 1, 1, 0.5 * a), true, -1.0, true)


## A mouse with the button to press in red.
func _mouse(c: Vector2, h: float, left: bool, a: float) -> void:
	var w := h * 0.66
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var line := maxf(h * 0.06, 1.5)
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.set_corner_radius_all(int(w * 0.5))
	sb.bg_color = Color(INK, a)
	draw_style_box(sb, r.grow(line))
	sb.bg_color = Color(1, 1, 1, a)
	draw_style_box(sb, r)
	var btn := StyleBoxFlat.new()
	btn.anti_aliasing = true
	btn.bg_color = Color(RED, a)
	if left:
		btn.corner_radius_top_left = int(w * 0.5)
	else:
		btn.corner_radius_top_right = int(w * 0.5)
	draw_style_box(btn, Rect2(r.position + Vector2(0.0 if left else w * 0.5, 0), Vector2(w * 0.5, h * 0.42)))
	draw_line(Vector2(c.x, r.position.y), Vector2(c.x, r.position.y + h * 0.42), Color(INK, a), line)
	draw_line(Vector2(r.position.x, r.position.y + h * 0.42), Vector2(r.end.x, r.position.y + h * 0.42), Color(INK, a), line)


func _burst(c: Vector2, r: float, col: Color, spin: float) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		pts.append(c + Vector2.from_angle(spin + TAU * i / 28.0) * (r if i % 2 == 0 else r * 0.66))
	draw_colored_polygon(pts, col)


func _nice(c: Vector2, a: float) -> void:
	if a <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(c + Vector2.from_angle(TAU * i / 20.0) * (52.0 if i % 2 == 0 else 34.0) * Vector2(1.25, 0.85) * a)
	draw_colored_polygon(pts, Color(INK, a))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.84)
	draw_colored_polygon(inner, Color(RED, a))
	draw_set_transform(c, -0.18)
	_text(Vector2(0, 10), "NICE!", 28, Color(YELLOW, a), a)
	draw_set_transform(Vector2.ZERO)


## Outlined comic text; centered on x unless `centered` is false
## (`right` aligns its end to x).
func _text(p: Vector2, t: String, fs: int, col: Color, a: float, centered := true, right := false) -> void:
	var w := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if centered:
		p.x -= w * 0.5
	elif right:
		p.x -= w
	draw_string_outline(FONT, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(fs / 4, 4) * 2, Color(INK, a))
	draw_string(FONT, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _back_out(t: float) -> float:
	var s := 1.7
	t -= 1.0
	return t * t * ((s + 1.0) * t + s) + 1.0
