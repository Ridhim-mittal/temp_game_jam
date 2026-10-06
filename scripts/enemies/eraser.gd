extends "res://scripts/enemies/enemy_base.gd"
## The Eraser (mini-boss): SHADE'S ERASER from the team's sheet, drawn by
## eraser_art.gd like every Eraser (the Rubbing Room's boss in the Gutter shows
## this same art on a billboard: eraser_3d.gd). Rubber body: hits bounce off
## ("BOING!") except while it is TIRED. Two attacks:
##  - LUNGE: leans back, then charges. If the charge misses the player or
##    slams a wall it is left TIRED and vulnerable.
##  - RUB:   if the player stands on a block in the group "erasable", it
##    rubs that block out of existence for a few seconds.

enum State { WALK, WINDUP, LUNGE, TIRED, RUB }

const Art = preload("res://scripts/enemies/eraser_art.gd")
## Height of the art in px (the sheet's block, scaled to this).
const ART_HEIGHT := 100.0

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
## 0..1: its eyes burn red (the Rubbing Room's boss sets it when FURIOUS).
var rage := 0.0


func _ready() -> void:
	add_to_group("boss")
	setup(Vector2(62, 92), hp)
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
	# the art layer is mirrored to face the player; un-mirror it so the lettering
	# reads, and let the art lean / charge the way it faces instead
	var flip := signf(art.scale.x) if art and art.scale.x != 0.0 else 1.0
	var k := ART_HEIGHT / Art.H
	var p := {"time": time, "heading": float(facing), "rage": rage, "seed": get_instance_id() % 97}
	match state:
		State.WINDUP:
			p["windup"] = 1.0
		State.LUNGE:
			p["side"] = true
			p["trail"] = 0.4
		State.TIRED:
			p["tired"] = 1.0
		State.RUB:
			p["rubbing"] = 1.0
			p["roar"] = 0.5
		_:
			p["roar"] = 0.15 if absf(velocity.x) > 10.0 else 0.0
	Art.draw(c, Transform2D(0.0, Vector2(flip * k, k), 0.0, Vector2.ZERO), p)


func damage_default() -> float:
	return 3.0  # mini-boss charge
