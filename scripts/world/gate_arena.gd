extends Node2D
## The Ink Blot's gate in Shade's City. When Vesper passes `trigger_x`, ink
## walls rise at `left_x` and `right_x` and the gatekeeper (`blot_path`,
## ink_blot.gd) wakes. When it melts (dropping its +50 heart) the walls sink,
## the "DO NOT CROSS" tape burns off and the
## gate at `gate_x` opens; walking in springs Shade's trap (shade_trap.gd),
## which goes on to `next_scene`. Place at the world origin.
## While the Blot lives the city's tune gives way to its tense cut
## (`fight_music`, music.gd "hunt"); the walls rumble up and slam home.

const ShadeTrap = preload("res://scripts/effects/shade_trap.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const TAPE := Color(1.0, 0.85, 0.2)

@export var blot_path: NodePath
@export var trigger_x := 6000.0
@export var left_x := 5850.0
@export var right_x := 6950.0
@export var gate_x := 6760.0
@export var street_y := 600.0
## Where the trap leads ("" = the main menu after "to be continued").
@export_file("*.tscn") var next_scene := ""
## The fight's music and what comes back once the Blot melts (music.gd).
@export var fight_music := "hunt"
@export var after_music := "hunters"

enum Phase { WAITING, LOCKED, CLEARED, SPRUNG }

var phase := Phase.WAITING
var _walls: Array = []
var _rise := 0.0
var _open := 0.0
var _time := 0.0
var _gate: Area2D


func _ready() -> void:
	z_index = -1
	for x in [left_x, right_x]:
		var b := StaticBody2D.new()
		b.collision_layer = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(40, 900)
		cs.shape = r
		cs.position = Vector2(0, -450)
		b.add_child(cs)
		b.position = Vector2(x, street_y)
		add_child(b)
		_walls.append(b)
	_gate = Area2D.new()
	_gate.collision_layer = 0
	_gate.collision_mask = 2
	var gcs := CollisionShape2D.new()
	var gr := RectangleShape2D.new()
	gr.size = Vector2(60, 160)
	gcs.shape = gr
	gcs.position = Vector2(gate_x, street_y - 80)
	_gate.add_child(gcs)
	_gate.monitoring = false
	_gate.body_entered.connect(_on_gate)
	add_child(_gate)
	var blot := get_node_or_null(blot_path)
	if blot:
		blot.defeated.connect(_on_defeated)
	for s in ["roar", "rumble", "thud", "rip", "whoosh", "splut", "screech", "scritch"]:
		SfxSynth.get_stream(s)  # built now, not mid-fight


func _process(delta: float) -> void:
	_time += delta
	var p := get_tree().get_first_node_in_group("player")
	if phase == Phase.WAITING and p and p.global_position.x > trigger_x:
		phase = Phase.LOCKED
		for w in _walls:
			w.collision_layer = 1
		var blot := get_node_or_null(blot_path)
		if blot:
			blot.wake()
		_music(fight_music, 0.2)
		SfxSynth.play(get_tree(), "rumble", 0.0, 0.7)  # the ink walls heave up...
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_inside_tree():
				SfxSynth.play(get_tree(), "thud", 0.0, 0.55))  # ...and slam home
	_rise = move_toward(_rise, 1.0 if phase == Phase.LOCKED else 0.0, delta * 2.0)
	if phase == Phase.CLEARED or phase == Phase.SPRUNG:
		_open = move_toward(_open, 1.0, delta * 0.8)
	queue_redraw()


func _on_defeated() -> void:
	_music(after_music, 3.0)  # the city's own tune creeps back
	await get_tree().create_timer(1.2).timeout
	phase = Phase.CLEARED
	Sfx.play("gate_unlock")
	SfxSynth.play(get_tree(), "rumble", -6.0, 1.1)  # the walls sink
	SfxSynth.play(get_tree(), "rip", -2.0, 0.8)  # the tape burns off
	for w in _walls:
		w.collision_layer = 0
	_gate.monitoring = true


func _on_gate(body: Node2D) -> void:
	if phase != Phase.CLEARED or not body.is_in_group("player"):
		return
	phase = Phase.SPRUNG
	Sfx.play("teleport")
	ShadeTrap.start(get_tree(), body, next_scene)


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
	# the gate: a tall comic panel doorway, taped shut until the Blot falls
	var g := Rect2(gate_x - 60, street_y - 200, 120, 200)
	draw_rect(g.grow(6), INK)
	draw_rect(g, Color(0.95, 0.85, 0.45))
	var inner := g.grow(-10)
	var glow := 0.5 + 0.5 * sin(_time * 3.0)
	draw_rect(inner, Color(0.16, 0.1, 0.28).lerp(Color(1.0, 0.92, 0.6), _open * (0.75 + 0.25 * glow)))
	if _open > 0.0:
		draw_rect(Rect2(g.position.x - 30, street_y - 8, 180, 8), Color(1.0, 0.92, 0.6, 0.4 * _open))
	for k in 2:
		var fall := _open * (180.0 + k * 40.0)
		draw_set_transform(g.get_center() + Vector2(0, fall), (0.55 if k == 0 else -0.55) + _open * (0.8 if k == 0 else -0.6))
		var a := 1.0 - _open
		if a > 0.0:
			draw_rect(Rect2(-140, -14, 280, 28), Color(0.02, 0.02, 0.03, a))
			draw_string(FONT, Vector2(-62, 7), "DO NOT CROSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(TAPE, a))
		draw_set_transform(Vector2.ZERO)
	# ink walls sealing the arena
	if _rise > 0.0:
		for x in [left_x, right_x]:
			var h := 700.0 * _rise
			draw_rect(Rect2(x - 22, street_y - h, 44, h), INK)
			for k in 5:
				var dx := -18.0 + k * 9.0
				var drip := fmod(_time * 60.0 + k * 37.0, 80.0)
				draw_circle(Vector2(x + dx, street_y - h + drip), 4.0, INK)
			draw_rect(Rect2(x - 22, street_y - h, 44, 6), Color(0.44, 0.38, 0.62))
