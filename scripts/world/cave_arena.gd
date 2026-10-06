extends Node2D
## The end of the Ink Cave: two Ink Blots at once. When Vesper passes
## `trigger_x`, ink walls rise at `left_x` and `right_x` and both Blots
## (`blot_paths`) wake. Each drops its +50 heart (ink_blot.gd); when the last
## one melts the cave breaks apart (cave_backdrop.gd `collapse`: the screen
## shakes, cracks race across it, rocks rain, a white flash) and he is thrown
## back into Shade's city: `next_scene`, or "TO BE CONTINUED" and the main
## menu until the Shade fight exists. Place at the world origin.

const COMIC = preload("res://scripts/effects/comic_text.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const MENU := "res://scenes/ui/main_menu.tscn"
const INK := Color(0.03, 0.01, 0.05)
const RIM := Color(1.0, 0.27, 0.66)

@export var blot_paths: Array[NodePath] = []
@export var backdrop_path: NodePath
@export var trigger_x := 2900.0
@export var left_x := 2700.0
@export var right_x := 4100.0
@export var floor_y := 600.0
## Where the collapse throws Vesper ("" = TO BE CONTINUED, then the main menu).
@export_file("*.tscn") var next_scene := ""
## The fight's music (music.gd); it dies away when the last Blot melts.
@export var fight_music := "hunt"

enum Phase { WAITING, LOCKED, COLLAPSE }

var phase := Phase.WAITING
var _walls: Array = []
var _rise := 0.0
var _time := 0.0
var _left := 0
var _overlay: CanvasLayer
var _view: Control
var _t := 0.0  # time since the collapse began
var _cracks: Array = []  # screen-space polylines
var _rocks: Array = []  # screen-space chunks falling past the camera {p, v, rot, spin, s}


func _ready() -> void:
	z_index = 3
	for x in [left_x, right_x]:
		var b := StaticBody2D.new()
		b.collision_layer = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(40, 1200)
		cs.shape = r
		cs.position = Vector2(0, -600)
		b.add_child(cs)
		b.position = Vector2(x, floor_y)
		add_child(b)
		_walls.append(b)
	for path in blot_paths:
		var blot := get_node_or_null(path)
		if blot:
			_left += 1
			blot.defeated.connect(_on_defeated)
	for s in ["roar", "rumble", "thud", "rip", "whoosh", "splut", "screech", "scritch", "shatter"]:
		SfxSynth.get_stream(s)  # built now, not mid-fight


func _process(delta: float) -> void:
	_time += delta
	var p := get_tree().get_first_node_in_group("player")
	if phase == Phase.WAITING and p and p.global_position.x > trigger_x:
		phase = Phase.LOCKED
		for w in _walls:
			w.collision_layer = 1
		for i in blot_paths.size():
			var blot := get_node_or_null(blot_paths[i])
			if blot:
				# the second one wakes a beat later: two roars, not one
				get_tree().create_timer(0.6 * i).timeout.connect(blot.wake)
		_music(fight_music, 0.9)  # crossfades out of the cave's tune as the walls rise
		SfxSynth.play(get_tree(), "rumble", 0.0, 0.7)
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_inside_tree():
				SfxSynth.play(get_tree(), "thud", 0.0, 0.55))
	_rise = move_toward(_rise, 1.0 if phase == Phase.LOCKED else 0.0, delta * 2.0)
	if phase == Phase.COLLAPSE:
		_collapse_tick(delta)
	queue_redraw()


func _on_defeated() -> void:
	_left -= 1
	if _left > 0:
		_pop("ONE MORE!", Color(1.0, 0.85, 0.3))
		return
	_music("", 2.0)  # the cave goes quiet... then gives way
	await get_tree().create_timer(2.4).timeout  # time for its heart to reach Vesper
	_start_collapse()


func _start_collapse() -> void:
	phase = Phase.COLLAPSE
	Sfx.play("boss_intro", 0.0, 0.6)
	SfxSynth.play(get_tree(), "rumble", 2.0, 0.6)
	SfxSynth.play(get_tree(), "shatter", -4.0, 0.5)  # the rock cracking
	_overlay = CanvasLayer.new()
	_overlay.layer = 110
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_paint_collapse)
	_overlay.add_child(_view)
	get_tree().current_scene.add_child(_overlay)
	var size := get_viewport_rect().size
	for i in 7:
		var p := Vector2(randf() * size.x, randf_range(0.0, 0.3) * size.y if i % 2 == 0 else randf() * size.y)
		var line := PackedVector2Array([p])
		var dir := Vector2.from_angle(randf() * TAU)
		for k in 10:
			dir = dir.rotated(randf_range(-0.6, 0.6))
			p += dir * randf_range(30.0, 80.0)
			line.append(p)
		_cracks.append({"pts": line, "at": randf_range(0.0, 2.4)})


func _collapse_tick(delta: float) -> void:
	_t += delta
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_trauma") and _t < 3.6:
		cam.add_trauma(delta * (0.6 + _t * 0.3))
	var bd := get_node_or_null(backdrop_path)
	if bd:
		bd.collapse = clampf(_t / 2.0, 0.0, 1.0)
	if _t < 3.0 and randf() < delta * (4.0 + _t * 6.0):
		_rocks.append({"p": Vector2(randf() * _view.size.x, -40.0), "v": Vector2(randf_range(-60, 60), randf_range(80, 260)),
			"rot": randf() * TAU, "spin": randf_range(-5, 5), "s": randf_range(14.0, 40.0)})
	for r in _rocks:
		r.v.y += 1300.0 * delta
		r.p += r.v * delta
		r.rot += r.spin * delta
	_rocks = _rocks.filter(func(r): return r.p.y < _view.size.y + 80.0)
	for c in _cracks:
		if c.at <= _t and not c.get("heard", false):
			c.heard = true
			Sfx.play("ink_splat", -2.0, randf_range(0.5, 0.7))
	if _t > 3.0 and _t - delta <= 3.0:
		Sfx.play("teleport")
		var p := get_tree().get_first_node_in_group("player")
		if p:
			p.set_physics_process(false)
			p.velocity = Vector2.ZERO
	var done := 7.5 if next_scene == "" else 4.2
	if _t > done or (next_scene == "" and _t > 5.5 and Input.is_anything_pressed()):
		set_process(false)
		get_tree().change_scene_to_file(next_scene if next_scene != "" else MENU)
	_view.queue_redraw()


func _paint_collapse() -> void:
	var s := _view.size
	# cracks race across the screen
	for c in _cracks:
		var grow := clampf((_t - c.at) / 0.5, 0.0, 1.0)
		if grow <= 0.0:
			continue
		var pts: PackedVector2Array = c.pts
		var n := maxi(int(pts.size() * grow), 2)
		var part := pts.slice(0, n)
		_view.draw_polyline(part, Color(1.0, 0.9, 0.95, 0.9), 9.0)
		_view.draw_polyline(part, INK, 5.0)
		_view.draw_polyline(part, RIM, 1.5)
	# chunks of the ceiling falling past, lit pink by the fire
	for r in _rocks:
		var sz: float = r.s
		var pts := PackedVector2Array()
		for k in 7:
			var ang: float = r.rot + k * TAU / 7.0
			pts.append(r.p + Vector2(cos(ang), sin(ang)) * sz * (0.7 + 0.3 * sin(k * 2.3 + sz)))
		var ring := pts.duplicate()
		ring.append(pts[0])
		_view.draw_colored_polygon(pts, Color(0.24, 0.18, 0.3))
		_view.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], r.p]), Color(RIM, 0.55))
		_view.draw_polyline(ring, INK, 3.0)
		_view.draw_line(r.p - Vector2(0, sz * 1.2), r.p - Vector2(0, sz * 2.6), Color(1.0, 0.95, 0.9, 0.5), 2.0)
	# white flash as the cave gives way
	if _t > 2.8:
		var a := clampf((_t - 2.8) / 0.25, 0.0, 1.0)  # and stays white till the scene changes
		_view.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.97, 0.9, a))
	if _t > 3.3:
		var a2 := clampf((_t - 3.3) / 0.5, 0.0, 1.0)
		var line := "THE CAVE GIVES WAY..."
		var w := FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		_view.draw_string(FONT, Vector2((s.x - w) * 0.5, s.y * 0.42), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(INK, a2))
		if next_scene == "":
			var sub := "...AND SPITS VESPER BACK INTO SHADE'S CITY."
			var sw := FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			var a3 := clampf((_t - 3.9) / 0.5, 0.0, 1.0)
			_view.draw_string(FONT, Vector2((s.x - sw) * 0.5, s.y * 0.42 + 54), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.35, 0.2, 0.45, a3))
	if next_scene == "" and _t > 5.0:
		var a := clampf((_t - 5.0) / 0.6, 0.0, 1.0)
		var cap := "SHADE AWAITS. TO BE CONTINUED..."
		var cw := FONT.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var r := Rect2(s.x - cw - 90, s.y - 130, cw + 40, 56)
		_view.draw_rect(r.grow(3), Color(INK, a))
		_view.draw_rect(r, Color(1.0, 0.9, 0.45, a))
		_view.draw_string(FONT, r.position + Vector2(20, 40), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(INK, a))


func _pop(text: String, col: Color) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var c := COMIC.new()
	c.text = text
	c.color = col
	c.position = p.global_position + Vector2(0, -90)
	get_tree().current_scene.add_child(c)


## Music autoload: a track ("" = fade out).
func _music(track: String, fade: float) -> void:
	var m := get_node_or_null("/root/Music")
	if m == null:
		return
	if track == "":
		m.stop(fade)
	else:
		m.play(track, fade)

func _draw() -> void:
	# ink walls sealing the arena, lit pink by the fire
	if _rise <= 0.0:
		return
	for x in [left_x, right_x]:
		var h := 900.0 * _rise
		draw_rect(Rect2(x - 22, floor_y - h, 44, h), INK)
		for k in 5:
			var dx := -18.0 + k * 9.0
			var drip := fmod(_time * 60.0 + k * 37.0, 80.0)
			draw_circle(Vector2(x + dx, floor_y - h + drip), 4.0, INK)
		draw_rect(Rect2(x - 22, floor_y - h, 44, 6), RIM)
		draw_rect(Rect2(x + (18 if x == left_x else -22), floor_y - h, 4, h), Color(RIM, 0.5))
