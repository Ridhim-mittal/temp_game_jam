@tool
extends StaticBody2D
## Trapdoor out of the comic panel: a wooden hatch set into the floor over a
## dark shaft. Chained shut while its `guardian` (e.g. the Eraser) lives;
## once the guardian falls the chains snap ("CLANK!"). Stand on it and it
## creaks, shakes, then swings open and drops Vesper into the shaft. Falling
## past the shaft's trigger plays the panel-to-gutter transition
## (gutter_fall.gd) and lands her in the 2.5D world.
## Origin = centre of the closed lid; put the floor gap right under it.

const INK := Color(0.05, 0.03, 0.1)
const ComicText = preload("res://scripts/effects/comic_text.gd")
const GutterFall = preload("res://scripts/effects/gutter_fall.gd")

@export var size := Vector2(140, 18):
	set(value):
		size = value
		queue_redraw()
## Stays chained shut while this node exists and isn't dead.
@export var guardian: NodePath
## How far below the lid the fall turns into the transition.
@export var fall_depth := 260.0
@export var wood := Color(0.62, 0.38, 0.22)

enum State { LOCKED, CLOSED, CREAKING, OPEN }
var _state := State.CLOSED
var _timer := 0.0
var _swing := 0.0  # 0 closed .. 1 hanging open
var _shape: CollisionShape2D
var _player: CharacterBody2D
var _falling := false
var _time := 0.0
var _locked_hint := 0.0


func _ready() -> void:
	collision_layer = 1
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	if _guardian_alive():
		_state = State.LOCKED


func _guardian_alive() -> bool:
	if guardian.is_empty():
		return false
	var g := get_node_or_null(guardian)
	return g != null and not ("dead" in g and g.dead)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_locked_hint = maxf(_locked_hint - delta, 0.0)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	match _state:
		State.LOCKED:
			if not _guardian_alive():
				_state = State.CLOSED
				_pop("CLANK!", Color(0.85, 0.9, 1.0))
			elif _on_lid() and _locked_hint <= 0.0:
				_locked_hint = 2.0
				_pop("LOCKED!", Color(1.0, 0.86, 0.2))
		State.CLOSED:
			if _on_lid():
				_state = State.CREAKING
				_timer = 0.45
				_pop("CREAK...", wood.lightened(0.4))
		State.CREAKING:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.OPEN
				_shape.set_deferred("disabled", true)
				_pop("KA-CHUNK!", Color(1.0, 0.95, 0.85))
		State.OPEN:
			_swing = minf(_swing + delta * 5.0, 1.0)
			if not _falling and _player and _player.global_position.y > global_position.y + fall_depth \
					and absf(_player.global_position.x - global_position.x) < size.x:
				_falling = true
				GutterFall.start(self, _player)
	queue_redraw()


func _on_lid() -> bool:
	if _player == null or not _player.is_on_floor():
		return false
	var feet := _player.global_position + Vector2(0, 26)
	return absf(feet.y - (global_position.y - size.y * 0.5)) < 6.0 and absf(feet.x - global_position.x) < size.x * 0.5


func _pop(text: String, color: Color) -> void:
	var pop := ComicText.new()
	pop.text = text
	pop.color = color
	pop.font_size = 24
	pop.position = global_position + Vector2(0, -70)
	get_tree().current_scene.add_child(pop)


func _draw() -> void:
	var half := size * 0.5
	# the shaft below: ink-black, with a faint glow of the gutter far down
	draw_rect(Rect2(-half.x, half.y - 2.0, size.x, 520.0), INK)
	for k in 4:
		draw_rect(Rect2(-half.x + 10 + k * 6, half.y + 60 + k * 70, size.x - 20 - k * 12, 50), Color(0.35, 0.3, 0.45, 0.06 + k * 0.03))
	var shake := Vector2.ZERO
	if _state == State.CREAKING:
		shake = Vector2(randf_range(-2.5, 2.5), randf_range(-1.0, 1.5))
	# lid hinges on its left edge and swings down when open
	var hinge := Vector2(-half.x, -half.y)
	var ang := _swing * PI * 0.5 * 0.98
	draw_set_transform(hinge + shake, ang)
	var lid := Rect2(0, 0, size.x, size.y)
	draw_rect(lid.grow(2.5), INK)
	draw_rect(lid, wood)
	for k in range(1, 4):  # plank seams
		var x := size.x * k / 4.0
		draw_line(Vector2(x, 2), Vector2(x, size.y - 2), wood.darkened(0.45), 2.0)
	draw_rect(Rect2(0, 0, size.x, 4), wood.lightened(0.25))
	for bx in [14.0, size.x - 22.0]:  # iron bands + rivets
		draw_rect(Rect2(bx, -1, 8, size.y + 2), Color(0.3, 0.3, 0.36))
		draw_circle(Vector2(bx + 4, 5), 1.6, Color(0.75, 0.78, 0.85))
		draw_circle(Vector2(bx + 4, size.y - 5), 1.6, Color(0.75, 0.78, 0.85))
	# a ring handle + stencilled arrow
	draw_arc(Vector2(size.x * 0.5, size.y * 0.5), 6.0, 0, TAU, 14, INK, 2.5)
	draw_set_transform(Vector2.ZERO)
	if _state == State.LOCKED:
		_draw_chains(half)
	elif _state != State.OPEN:
		# bobbing "down" arrow invites the player on
		var y := -half.y - 34.0 + sin(_time * 4.0) * 5.0
		var tri := PackedVector2Array([Vector2(-12, y), Vector2(12, y), Vector2(0, y + 16)])
		draw_colored_polygon(tri, INK)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, y + 2), Vector2(8, y + 2), Vector2(0, y + 12)]), Color(1.0, 0.95, 0.85))


func _draw_chains(half: Vector2) -> void:
	# two chains crossing the lid, padlock in the middle
	for side in [-1.0, 1.0]:
		var a := Vector2(-half.x - 6, -half.y - 4) if side < 0 else Vector2(half.x + 6, -half.y - 4)
		var b := Vector2(half.x * 0.9, half.y) if side < 0 else Vector2(-half.x * 0.9, half.y)
		var n := 9
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			draw_set_transform(p, (b - a).angle(), Vector2(1, 0.55))
			draw_arc(Vector2.ZERO, 6.0, 0, TAU, 12, INK, 4.0)
			draw_arc(Vector2.ZERO, 6.0, 0, TAU, 12, Color(0.62, 0.64, 0.72), 2.0)
		draw_set_transform(Vector2.ZERO)
	var lock := Rect2(-11, -8, 22, 18)
	draw_arc(Vector2(0, -8), 7.0, PI, TAU, 10, INK, 4.0)
	draw_rect(lock.grow(2.0), INK)
	draw_rect(lock, Color(1.0, 0.82, 0.3))
	draw_circle(Vector2(0, 0), 2.5, INK)
