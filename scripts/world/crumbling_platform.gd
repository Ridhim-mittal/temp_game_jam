@tool
extends StaticBody2D
## Cracked slab that gives way: once the player lands on it, it shakes for
## `warn_time`, falls apart (no collision) and reforms after `respawn_time`.

const INK := Color(0.05, 0.03, 0.1)
const ComicText = preload("res://scripts/effects/comic_text.gd")

@export var size := Vector2(140, 22):
	set(value):
		size = value
		queue_redraw()
@export var stone := Color(0.86, 0.8, 0.7)
@export var warn_time := 0.55
@export var respawn_time := 2.6

enum State { SOLID, SHAKING, GONE }
var _state := State.SOLID
var _timer := 0.0
var _shape: CollisionShape2D
var _player: Node2D
var _cracks: Array = []


func _ready() -> void:
	collision_layer = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7.0 + position.y)
	for i in maxi(int(size.x / 40.0), 2):
		var x := rng.randf_range(-0.42, 0.42) * size.x
		_cracks.append([Vector2(x, -size.y * 0.5), Vector2(x + rng.randf_range(-8, 8), 0), Vector2(x + rng.randf_range(-10, 10), size.y * 0.5)])
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _state:
		State.SOLID:
			if _player_on_top():
				_state = State.SHAKING
				_timer = warn_time
		State.SHAKING:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.GONE
				_timer = respawn_time
				_shape.set_deferred("disabled", true)
				var pop := ComicText.new()
				pop.text = "KRUNCH!"
				pop.color = stone
				pop.font_size = 22
				pop.position = global_position + Vector2(0, -20)
				get_tree().current_scene.add_child(pop)
		State.GONE:
			_timer -= delta
			if _timer <= 0.0 and not _player_inside():
				_state = State.SOLID
				_shape.set_deferred("disabled", false)
	queue_redraw()


func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _player_on_top() -> bool:
	var p := _get_player() as CharacterBody2D
	if p == null or not p.is_on_floor():
		return false
	var feet := p.global_position + Vector2(0, 26)
	var top := global_position.y - size.y * 0.5
	return absf(feet.y - top) < 6.0 and absf(feet.x - global_position.x) < size.x * 0.5 + 12.0


func _player_inside() -> bool:
	var p := _get_player()
	if p == null:
		return false
	var d := p.global_position - global_position
	return absf(d.x) < size.x * 0.5 + 14.0 and absf(d.y) < size.y * 0.5 + 27.0


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if _state == State.GONE:
		# faint outline where it will reform
		var a := 0.25 + 0.25 * (1.0 - _timer / respawn_time)
		draw_rect(r, Color(stone, a * 0.4))
		draw_rect(r, Color(INK, a), false, 1.5)
		return
	var shake := Vector2.ZERO
	if _state == State.SHAKING:
		shake = Vector2(randf_range(-2.5, 2.5), randf_range(-1.0, 1.0))
	draw_set_transform(shake)
	draw_rect(r.grow(2.5), INK)
	draw_rect(r, stone)
	draw_rect(Rect2(r.position, Vector2(size.x, 4)), stone.lightened(0.3))
	var w := 1.5 if _state == State.SOLID else 2.5
	for c in _cracks:
		draw_polyline(PackedVector2Array(c), INK, w)
	draw_set_transform(Vector2.ZERO)
