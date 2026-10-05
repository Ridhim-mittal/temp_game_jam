extends "res://scripts/enemies/enemy_base.gd"
## The Eraser (mini-boss). Rubber body: hits bounce off ("BOING!") except
## while it is TIRED. Two attacks:
##  - LUNGE: leans back, then charges. If the charge misses the player or
##    slams a wall it is left TIRED and vulnerable.
##  - RUB:   if the player stands on a block in the group "erasable", it
##    rubs that block out of existence for a few seconds.

enum State { WALK, WINDUP, LUNGE, TIRED, RUB }

@export var hp := 10
@export var walk_speed := 55.0
@export var lunge_speed := 430.0
@export var tired_time := 1.8
@export var erase_time := 3.5

var state := State.WALK
var _timer := 0.0
var _cooldown := 1.5
var _player_hp := 0.0
var _target: Node2D


func _ready() -> void:
	add_to_group("boss")
	setup(Vector2(60, 68), hp)
	knockback_speed = 90.0


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	_fall(delta)
	var d := to_player()
	match state:
		State.WALK:
			face_player()
			var blocked := is_on_floor() and (hitting_wall() or at_ledge())
			var want := facing * walk_speed if _player and absf(d.x) > 50.0 and absf(d.x) < 700.0 and not blocked else 0.0
			velocity.x = move_toward(velocity.x, want, 500.0 * delta)
			if _player and _cooldown <= 0.0 and is_on_floor():
				var block := _player_floor()
				if block and absf(d.x) < 560.0:
					_target = block
					state = State.RUB
					_timer = 0.9
					pop("RUB RUB!", Color(0.93, 0.55, 0.6))
				elif absf(d.x) < 300.0 and absf(d.y) < 100.0:
					state = State.WINDUP
					_timer = 0.6
		State.WINDUP:
			velocity.x = move_toward(velocity.x, -facing * 30.0, 500.0 * delta)
			if _timer <= 0.0:
				state = State.LUNGE
				_timer = 0.55
				_player_hp = _player.health if _player else 0.0
		State.LUNGE:
			velocity.x = facing * lunge_speed
			var hit_wall := hitting_wall()
			if hit_wall or _timer <= 0.0 or (is_on_floor() and at_ledge()):
				velocity.x = 0.0
				var landed: bool = _player != null and _player.health < _player_hp
				if hit_wall or not landed:
					state = State.TIRED
					_timer = tired_time
					pop("PHEW...", PALE)
				else:
					state = State.WALK
				_cooldown = 1.2
		State.TIRED:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _timer <= 0.0:
				state = State.WALK
		State.RUB:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if is_instance_valid(_target):
				_target.modulate.a = 0.55 + 0.4 * sin(time * 30.0)  # warning flicker
			if _timer <= 0.0:
				_erase(_target)
				_target = null
				state = State.WALK
				_cooldown = 2.5
	move_and_slide()


## The erasable block the player is standing on, if any.
func _player_floor() -> Node2D:
	var from := _player.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 60), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.is_in_group("erasable"):
		return null
	return hit.collider


func _erase(block: Node2D) -> void:
	if not is_instance_valid(block):
		return
	var shape: CollisionShape2D
	for child in block.get_children():
		if child is CollisionShape2D:
			shape = child
	if shape == null:
		block.modulate.a = 1.0
		return
	shape.set_deferred("disabled", true)
	block.modulate.a = 0.15
	# The tween lives on the block, so the block comes back even if I die.
	var t := block.create_tween()
	t.tween_interval(erase_time)
	t.tween_callback(shape.set_deferred.bind("disabled", false))
	t.tween_property(block, "modulate:a", 1.0, 0.25)


func _blocks(_hit_dir: Vector2, _from_pos: Vector2) -> bool:
	if state == State.TIRED:
		return false
	pop("BOING!", Color(0.93, 0.55, 0.6), Vector2(0, -80), 22)
	return true


func _die(kx: float) -> void:
	if is_instance_valid(_target):
		_target.modulate.a = 1.0
	super(kx)


func paint(c: CanvasItem) -> void:
	var pink := Color(0.93, 0.55, 0.6)
	var lean := 0.0
	var squash := 1.0
	match state:
		State.WINDUP:
			lean = -0.22
		State.LUNGE:
			lean = 0.25
		State.TIRED:
			squash = 0.88 + 0.03 * sin(time * 8.0)  # panting
		State.RUB:
			lean = sin(time * 30.0) * 0.12
	c.draw_set_transform(Vector2.ZERO, lean, Vector2(2.0 - squash, squash))
	c.draw_colored_polygon(pts([-30, -68, 24, -68, 31, -60, 31, 0, -30, 0]), pink)
	c.draw_colored_polygon(pts([24, -68, 31, -60, 31, 0, 24, 0]), pink.darkened(0.2))
	c.draw_colored_polygon(pts([-30, -32, 31, -32, 31, 0, -30, 0]), Color(0.25, 0.4, 0.75))
	c.draw_line(Vector2(-30, -32), Vector2(31, -32), INK, 2.0)
	c.draw_rect(Rect2(-20, -22, 40, 4), PALE)
	c.draw_rect(Rect2(-20, -13, 26, 4), PALE)
	if state == State.TIRED:
		for sx in [-11.0, 11.0]:
			c.draw_arc(Vector2(sx, -47), 5.0, time * 9.0, time * 9.0 + 4.6, 10, INK, 2.0)
		c.draw_arc(Vector2(0, -37), 5.0, 0.2, PI - 0.2, 8, INK, 2.0)
		c.draw_circle(Vector2(0, -78 - sin(time * 6.0) * 3.0), 6.0, DANGER)  # weak-spot marker
		c.draw_circle(Vector2(-36, -52), 3.0, Color(0.6, 0.8, 1.0))
	else:
		var look := to_player().normalized() * Vector2(facing, 1) if _player else Vector2.RIGHT
		c.draw_line(Vector2(-21, -57), Vector2(-5, -51), INK, 3.5)
		c.draw_line(Vector2(21, -57), Vector2(5, -51), INK, 3.5)
		draw_eye(c, Vector2(-11, -46), 5.5, look)
		draw_eye(c, Vector2(11, -46), 5.5, look)
		c.draw_line(Vector2(-7, -38), Vector2(9, -38), INK, 2.5)
	c.draw_set_transform(Vector2.ZERO)
	if state == State.LUNGE:
		for k in 3:
			c.draw_line(Vector2(-40, -14.0 - k * 20.0), Vector2(-62, -14.0 - k * 20.0), pink.darkened(0.1), 3.0)


func damage_default() -> float:
	return 35.0  # mini-boss charge
