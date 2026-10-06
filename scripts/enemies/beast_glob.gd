extends CharacterBody2D
## The Scribbled Beast's ink glob (scribbled_beast.gd): lobbed in an arc at a
## lit lantern to snuff it ("SPLUT!"). Slash it out of the air to keep the
## light on (it's on the enemy layer, so swings and ink waves find it); it
## stings if it lands on Vesper instead.

const InkBatch = preload("res://scripts/depth/ink_batch.gd")
const InkBits = preload("res://scripts/effects/ink_bits.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const INK := Color(0.04, 0.03, 0.07)
const GRAVITY := 1400.0

var dead := false
var contact_damage := 1.0  # half ink bottles
## The lantern it's aimed at (lantern.gd).
var target: Node2D

var _time := 0.0
var _flight := 0.8
var _batch := InkBatch.new()


## Throws a glob from `from` at `lamp` (its lamp_position()).
static func throw(tree: SceneTree, from: Vector2, lamp: Node2D) -> Node2D:
	var g: CharacterBody2D = load("res://scripts/enemies/beast_glob.gd").new()
	g.target = lamp
	tree.current_scene.add_child(g)
	g.global_position = from
	var to: Vector2 = lamp.lamp_position()
	g._flight = clampf(from.distance_to(to) / 900.0, 0.55, 1.1)
	g.velocity = (to - from) / g._flight - Vector2(0, 0.5 * GRAVITY * g._flight)
	return g


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemy")
	z_index = 5
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	cs.shape = c
	add_child(cs)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	velocity.y += GRAVITY * delta
	position += velocity * delta
	if _time >= _flight:
		_land()
	queue_redraw()


func _land() -> void:
	if target and is_instance_valid(target) and target.lit:
		target.lit = false
		_say("SPLUT!", Color(0.75, 0.72, 0.85))
	_pop()


## A slash or an ink wave cuts it out of the air.
func take_hit(_damage: int, _hit_dir: Vector2, _from_pos: Vector2) -> void:
	_say("SPLAT!", Color(1.0, 0.85, 0.4))
	_pop()


func on_hit_player() -> void:
	_pop()


func _pop() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	InkBits.burst(get_tree(), global_position, 14, 260.0, Vector2.ZERO, 0.0)
	SfxSynth.play(get_tree(), "splut", -6.0)
	queue_free()


func _say(text: String, col: Color) -> void:
	var p := ComicText.new()
	p.text = text
	p.color = col
	p.font_size = 26
	p.position = global_position + Vector2(0, -30)
	get_tree().current_scene.add_child(p)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0) + 7
	var pts := PackedVector2Array()
	var stretch := clampf(velocity.length() / 900.0, 0.0, 0.6)
	var along := velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT
	for i in 11:
		var a := TAU * i / 11.0
		var r := 13.0 * rng.randf_range(0.75, 1.2)
		var p := Vector2.from_angle(a) * r
		p += along * p.dot(along) * stretch
		pts.append(p)
	_batch.draw_colored_polygon(pts, INK)
	for i in 3:
		var tail := -along * (16.0 + i * 9.0) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		_batch.draw_circle(tail, 5.0 - i * 1.4, INK)
	_batch.draw_circle(Vector2(-4, -4), 3.0, Color(0.9, 0.9, 1.0, 0.5))
	_batch.flush(self)
