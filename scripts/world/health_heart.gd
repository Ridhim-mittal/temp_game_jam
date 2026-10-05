@tool
extends Area2D
## Health pickup: a cute little heart with a face and tiny flapping wings,
## bobbing in the air. Touch it to heal `amount` half bottles (2 = one ink bottle). It stays put while
## you are at full health, so you can come back for it. `seek` makes it fly
## to Vesper (the Ink Blot's big drop), so it can't be left behind.

const INK := Color(0.05, 0.03, 0.1)
const ComicText = preload("res://scripts/effects/comic_text.gd")
const OnScreen = preload("res://scripts/core/on_screen.gd")

@export var amount := 2.0
@export var heart_color := Color(1.0, 0.36, 0.42)
## Fly to the player after `seek_delay` seconds instead of waiting in place.
@export var seek := false
@export var seek_delay := 0.7

var _time := 0.0
var _taken := false
var _player: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	_time = position.x * 0.02
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	cs.shape = circle
	add_child(cs)


func _physics_process(delta: float) -> void:
	# polled (not body_entered) so it also works if you stand on it until hurt
	if Engine.is_editor_hint() or _taken:
		return
	if seek:
		seek_delay -= delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and seek_delay <= 0.0:
			var to := p.global_position + Vector2(0, -20) - global_position
			global_position += to.limit_length(minf(-seek_delay * 900.0 + 200.0, 1100.0) * delta)
	for body in get_overlapping_bodies():
		if body.has_method("heal") and body.heal(amount):
			_collect()
			return


func _collect() -> void:
	_taken = true
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").play("checkpoint", -4.0, 1.25)
	set_deferred("monitoring", false)
	var pop := ComicText.new()
	pop.text = "+%s INK" % ("%d" % int(amount / 2.0) if int(amount) % 2 == 0 else str(amount / 2.0))
	pop.color = Color(0.45, 1.0, 0.55)
	pop.position = global_position + Vector2(0, -30)
	get_tree().current_scene.add_child(pop)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.8, 1.8), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.08)
	t.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	if OnScreen.near(self, 80.0):
		queue_redraw()


func _heart(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		# classic heart curve, scaled to roughly s across
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * s / 32.0)
	return pts


func _draw() -> void:
	var bob := Vector2(0, sin(_time * 2.4) * 4.0)
	var beat := 1.0 + 0.08 * maxf(sin(_time * 6.0), 0.0)
	if amount >= 6.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 1.35)  # a big heart for a big heal
	# soft glow
	draw_circle(bob, 30.0, Color(heart_color, 0.12))
	# wings flapping
	var flap := sin(_time * 14.0) * 0.5
	for side in [-1.0, 1.0]:
		var root := bob + Vector2(side * 13.0, -4.0)
		var wing := PackedVector2Array([root, root + Vector2(side * 16.0, -10.0 - flap * 8.0),
			root + Vector2(side * 20.0, -1.0 - flap * 4.0), root + Vector2(side * 10.0, 4.0)])
		draw_colored_polygon(wing, INK)
		var inner := PackedVector2Array()
		for p in wing:
			inner.append(root + (p - root) * 0.75)
		draw_colored_polygon(inner, Color(1.0, 0.98, 0.92))
	# heart body with ink outline
	var outline := _heart(bob, 40.0 * beat)
	var body := _heart(bob, 34.0 * beat)
	draw_colored_polygon(outline, INK)
	draw_colored_polygon(body, heart_color)
	draw_circle(bob + Vector2(-6, -7), 3.5, heart_color.lightened(0.5))  # shine
	# face: dot eyes, smile, blush
	for ex in [-5.0, 5.0]:
		draw_circle(bob + Vector2(ex, -1), 2.2, INK)
		draw_circle(bob + Vector2(ex + 0.7, -1.8), 0.7, Color.WHITE)
	draw_arc(bob + Vector2(0, 3), 3.0, 0.2, PI - 0.2, 8, INK, 1.6)
	for bx in [-9.0, 9.0]:
		draw_circle(bob + Vector2(bx, 3), 2.2, Color(1.0, 0.75, 0.8, 0.9))
