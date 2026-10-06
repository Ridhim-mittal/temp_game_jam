@tool
extends Area2D
## "Lumen" coin: a spinning gold token with an embossed V on the front and a
## sunburst (the Lamp's light) on the back. The spin is a real 3D flip:
## the face squashes by cos(angle) and the rim thickness shows on the side
## turning away. Walk through it to collect it.
## draw_coin() is static so the HUD counter can draw the exact same coin.

const ComicText = preload("res://scripts/effects/comic_text.gd")
const INK := Color(0.05, 0.03, 0.1)
const OUTLINE := Color(1.0, 0.98, 0.9)  # cream = friendly (same as Vesper)
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.78, 0.46, 0.1)
const GOLD_LIGHT := Color(1.0, 0.95, 0.65)
const OnScreen = preload("res://scripts/core/on_screen.gd")

@export var value := 1
@export var radius := 13.0
@export var spin_speed := 3.2
## The word that pops up when it is picked up.
@export var pop_text := "CLINK!"
@export var pop_size := 20

var _time := 0.0
var _collected := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	_time = position.x * 0.013  # neighbours spin out of phase
	if Engine.is_editor_hint():
		return
	var state := get_node_or_null("/root/GameState")
	if state and state.collected.has(state.id_of(self)):
		queue_free()  # already banked before a death / restart
		return
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius + 4.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.has_method("add_coins"):
		return
	_collected = true
	set_deferred("monitoring", false)
	var state := get_node_or_null("/root/GameState")
	if state:
		state.collected[state.id_of(self)] = true
	body.add_coins(value)
	var pop := ComicText.new()
	pop.text = pop_text
	pop.color = GOLD
	pop.font_size = pop_size
	pop.position = global_position + Vector2(0, -radius - 13.0)
	get_tree().current_scene.add_child(pop)
	# fast spin, jump up, flash and vanish
	spin_speed = 18.0
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:y", position.y - 34.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.5, 1.5), 0.25)
	t.tween_property(self, "modulate:a", 0.0, 0.15).set_delay(0.18)
	t.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	if OnScreen.near(self, 80.0):
		queue_redraw()


func _draw() -> void:
	var bob := sin(_time * 2.6) * 3.0
	draw_coin(self, Vector2(0, bob), radius, _time * spin_speed)
	if _collected:
		var burst := clampf(scale.x - 1.0, 0.0, 1.0)
		for k in 8:
			var a := TAU * k / 8.0
			var d := Vector2(cos(a), sin(a))
			draw_line(d * (radius + 4.0 + 10.0 * burst), d * (radius + 10.0 + 18.0 * burst), GOLD_LIGHT, 2.5)


static func draw_coin(ci: CanvasItem, pos: Vector2, r: float, angle: float) -> void:
	var c := cos(angle)
	var w := maxf(absf(c), 0.08)
	var thick := r * 0.3 * sqrt(1.0 - c * c)  # rim visible when edge-on
	var side := -1.0 if sin(angle) > 0.0 else 1.0
	var rim_pos := pos + Vector2(side * thick, 0)
	# outlines around the whole silhouette (face + rim)
	for layer in [[r + 4.5, OUTLINE], [r + 2.0, INK]]:
		ci.draw_set_transform(rim_pos, 0.0, Vector2(w, 1.0))
		ci.draw_circle(Vector2.ZERO, layer[0], layer[1])
		ci.draw_set_transform(pos, 0.0, Vector2(w, 1.0))
		ci.draw_circle(Vector2.ZERO, layer[0], layer[1])
		ci.draw_rect(Rect2(Vector2(minf(0.0, side * thick) / w, -layer[0]), Vector2(thick / w, layer[0] * 2.0)), layer[1])
	# rim (coin edge) behind the face
	ci.draw_set_transform(rim_pos, 0.0, Vector2(w, 1.0))
	ci.draw_circle(Vector2.ZERO, r, GOLD_DARK)
	ci.draw_set_transform(pos, 0.0, Vector2(w, 1.0))
	ci.draw_rect(Rect2(Vector2(minf(0.0, side * thick) / w, -r), Vector2(thick / w, r * 2.0)), GOLD_DARK)
	# face
	ci.draw_circle(Vector2.ZERO, r, GOLD if c > 0.0 else GOLD.darkened(0.08))
	ci.draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 20, GOLD_DARK, 1.6)
	if c > 0.0:
		# front: embossed V (shadow, then light)
		var v := PackedVector2Array([Vector2(-0.42, -0.4), Vector2(-0.2, -0.4), Vector2(0, 0.12),
			Vector2(0.2, -0.4), Vector2(0.42, -0.4), Vector2(0.08, 0.45), Vector2(-0.08, 0.45)])
		for i in v.size():
			v[i] *= r
		var shadow := v.duplicate()
		for i in shadow.size():
			shadow[i] += Vector2(1.2, 1.2)
		ci.draw_colored_polygon(shadow, GOLD_DARK)
		ci.draw_colored_polygon(v, GOLD_LIGHT)
	else:
		# back: the Lamp's sunburst
		for k in 8:
			var a := TAU * k / 8.0
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x) * r * 0.1
			ci.draw_colored_polygon(PackedVector2Array([d * r * 0.2 + n, d * r * 0.6, d * r * 0.2 - n]), GOLD_LIGHT)
		ci.draw_circle(Vector2.ZERO, r * 0.2, GOLD_LIGHT)
	# shine streak
	ci.draw_line(Vector2(-r * 0.5, -r * 0.45), Vector2(-r * 0.15, -r * 0.75), Color(1, 1, 1, 0.9), 2.0)
	ci.draw_set_transform(Vector2.ZERO)
