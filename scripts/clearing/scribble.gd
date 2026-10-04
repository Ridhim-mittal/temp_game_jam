extends CharacterBody3D
## Scribble (from the design doc): a small, fast, weak tangle of crossed-out
## ink. Wanders near where it was placed, hops after the player when it
## spots them and pounces when close (touching it mid-pounce hurts), gets
## knocked back by hits and bursts into an ink splat. Outside story rooms it
## scribbles itself back into existence a few seconds later.

const Fx = preload("res://scripts/clearing/clearing_fx.gd")

enum State { WANDER, CHASE, STUNNED, DEAD, WINDUP, POUNCE }

@export var max_health := 3
@export var wander_speed := 1.6
@export var chase_speed := 3.2
@export var wander_radius := 3.0
@export var sight_range := 7.0
## Stops this close to the player, then winds up and pounces.
@export var keep_distance := 1.6
@export var pounce_speed := 7.0
@export var pounce_cooldown := 1.2
@export var contact_damage := 1
@export var knockback := 9.0
@export var stun_time := 0.3
@export var respawn_time := 5.0
@export var gravity := 30.0

var health := 0
var dead := false
var state := State.WANDER

var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _timer := 0.0
var _hop := 0.0
var _squash := Vector3.ONE
var _flash := 0.0
var _player: Node3D
var _pounce_cd := 0.8
var _pounce_dir := Vector3.ZERO

@onready var visual: MeshInstance3D = $Visual
@onready var _mat: ShaderMaterial = visual.material_override.duplicate()


const DIVER_SCENE := "res://scenes/clearing/monsters/scribble_diver.tscn"


func _ready() -> void:
	# Settings can swap every Scribble for the platformer's flying dive-bomber
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.scribble_style == "diver" and not Engine.is_editor_hint():
		_become_diver.call_deferred()
	add_to_group("enemy")
	visual.material_override = _mat
	_mat.set_shader_parameter("seed", randf() * 100.0)
	_home = global_position
	health = max_health
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_player = get_tree().get_first_node_in_group("player")
	_timer -= delta
	_pounce_cd -= delta
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	match state:
		State.WANDER:
			var to := _wander_target - global_position
			to.y = 0.0
			if to.length() < 0.3 or _timer <= 0.0:
				_pick_wander_target()
			planar = planar.move_toward(to.normalized() * wander_speed, 12.0 * delta)
			if _sees_player():
				state = State.CHASE
				_squash = Vector3(0.8, 1.3, 0.8)  # startled hop
				Fx.pop_text(get_tree(), global_position + Vector3(0, 1.4, 0), "!", Color(1, 0.9, 0.3), 40)
		State.CHASE:
			var to := _player.global_position - global_position if _player else Vector3.ZERO
			to.y = 0.0
			if _player == null or to.length() > sight_range * 1.6:
				state = State.WANDER
			elif to.length() > keep_distance:
				planar = planar.move_toward(to.normalized() * chase_speed, 20.0 * delta)
			else:
				planar = planar.move_toward(Vector3.ZERO, 30.0 * delta)
				if _pounce_cd <= 0.0:
					state = State.WINDUP
					_timer = 0.35
					_pounce_dir = to.normalized()
		State.WINDUP:
			planar = planar.move_toward(Vector3.ZERO, 30.0 * delta)
			_squash = Vector3(1.25, 0.75, 1.25)
			if _timer <= 0.0:
				state = State.POUNCE
				_timer = 0.35
				planar = _pounce_dir * pounce_speed
				velocity.y = 4.0
		State.POUNCE:
			if _timer <= 0.0 and is_on_floor():
				state = State.CHASE
				_pounce_cd = pounce_cooldown
		State.STUNNED:
			planar = planar.move_toward(Vector3.ZERO, 28.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE if _player else State.WANDER
	velocity.x = planar.x
	velocity.z = planar.z
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _process(delta: float) -> void:
	if dead:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	_hop += delta * (6.0 + speed * 2.5)
	var bounce := absf(sin(_hop)) * clampf(speed / chase_speed, 0.25, 1.0) * 0.22
	_squash = _squash.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
	visual.position.y = 0.62 + bounce
	visual.scale = _squash
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_mat.set_shader_parameter("flash", _flash)
	if _player:
		var to := _player.global_position - global_position
		_mat.set_shader_parameter("look", Vector2(clampf(to.x * 0.3, -1, 1), clampf(-to.z * 0.3, -1, 1)))


func _become_diver() -> void:
	var diver: Node3D = load(DIVER_SCENE).instantiate()
	diver.transform = transform
	diver.respawn_time = respawn_time
	diver.sight = sight_range + 1.0
	var parent := get_parent()
	var at := get_index()
	var keep := name
	parent.remove_child(self)
	diver.name = keep
	parent.add_child(diver)
	parent.move_child(diver, at)
	queue_free()


func is_harmful() -> bool:
	return not dead and state == State.POUNCE


func _sees_player() -> bool:
	return _player != null and global_position.distance_to(_player.global_position) < sight_range


func _pick_wander_target() -> void:
	var a := randf() * TAU
	_wander_target = _home + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.5, wander_radius)
	_timer = randf_range(1.5, 3.5)


func take_hit(damage: int, dir: Vector3, _aerial := false) -> void:
	if dead:
		return
	health -= damage
	_flash = 1.0
	_squash = Vector3(1.35, 0.7, 1.35)
	# light hits only nudge it, so a combo keeps connecting; the finisher
	# (damage > 1) sends it flying
	velocity = Vector3(dir.x, 0.0, dir.z).normalized() * knockback * (1.0 if damage > 1 else 0.45)
	state = State.STUNNED
	_timer = stun_time
	if health <= 0:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("enemy")
	collision_layer = 0
	Fx.splat(get_tree(), global_position)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.6, 0), Color(0.08, 0.05, 0.12), 16, 4.5)
	var t := create_tween()
	t.tween_property(visual, "scale", Vector3(1.6, 0.1, 1.6), 0.08)
	t.tween_callback(func(): visual.visible = false)
	if respawn_time <= 0.0:
		return
	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	health = max_health
	state = State.WANDER
	visual.visible = true
	visual.scale = Vector3(0.1, 0.1, 0.1)
	_squash = Vector3(0.1, 0.1, 0.1)
	dead = false
	collision_layer = 4
	add_to_group("enemy")
	_pick_wander_target()
