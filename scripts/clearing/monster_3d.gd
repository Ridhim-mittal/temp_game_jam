extends CharacterBody3D
## Shared base for the clearing's monsters (crumple, crossed-out, smudge,
## inkwell, eraser, the Half-Drawn). Mirrors the platformer's enemy_base.gd in 3D: health,
## hits and knockback, stun, contact damage, death and respawn, and the
## "am I in light?" question (the clearing's braziers are the light).
## The look comes from the platformer's own 2D monster via MonsterPuppet,
## or from a 3D model of the monster's own (setup_monster_model()).
##
## A monster script extends this, sets `art_scene` / `hp` / sizes, and
## overrides:
##   _tick(delta)                    behaviour, every physics frame
##   _blocks(dir, aerial) -> bool    true to shrug off a hit
##   is_harmful() -> bool            true while touching it hurts
##   _sync_puppet()                  copy state into puppet.figure

const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const Puppet = preload("res://scripts/clearing/monster_puppet.gd")
const Light = preload("res://scripts/world25/light.gd")
const DANGER := Color(1.0, 0.86, 0.2)
const PALE := Color(0.98, 0.96, 0.9)

@export var hp := 3
@export var contact_damage := 1
@export var gravity := 30.0
@export var knockback := 6.0
@export var sight := 9.0
## Seconds before a defeated monster scribbles itself back (0 = never).
@export var respawn_time := 8.0
## Unused: the Gutter has no coins any more (lumen.gd is unhooked). Kept so
## scenes and scripts that set it still load.
@export var lumens := 2

var health := 0
var dead := false
## Flying monsters ignore gravity (the dive-bomber Scribble).
var flying := false
var stun := 0.0
var facing := 1
var time := 0.0
var puppet: Node3D

var _home := Vector3.ZERO
var _player: Node3D


## Called by the subclass in _ready().
func setup_monster(art_scene: String, viewport_size := 256, feet_margin := 40, blend := false) -> void:
	_setup_common()
	puppet = Puppet.new()
	add_child(puppet)
	puppet.setup(art_scene, viewport_size, feet_margin, blend)


## Like setup_monster(), for a monster with its own 3D model instead of the
## platformer's 2D art (the Half-Drawn): `model`, already a child, takes the
## puppet's place, so it needs `facing`, look_at_point() and flash().
func setup_monster_model(model: Node3D) -> void:
	_setup_common()
	puppet = model


func _setup_common() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 5
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.get_value("difficulty") == "hard":
		hp = int(ceil(hp * 1.5))
		contact_damage += 1
	health = hp
	_home = global_position
	time = randf() * 10.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	time += delta
	_player = get_tree().get_first_node_in_group("player")
	if _player and "dead" in _player and _player.dead:
		_player = null
	if global_position.y < _home.y - 8.0:
		_die()  # fell into the void (off a vanished bridge)
		return
	if stun > 0.0:
		stun -= delta
		_slow_to_stop(18.0, delta)
	else:
		_tick(delta)
	if flying:
		if stun > 0.0:
			velocity.y = move_toward(velocity.y, 0.0, 20.0 * delta)
	elif not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


func _process(_delta: float) -> void:
	if puppet == null or dead:
		return
	puppet.facing = facing
	if _player:
		puppet.look_at_point(_player.global_position)
	_sync_puppet()


# ------------------------------------------------------------ overridables

func _tick(_delta: float) -> void:
	pass


func _blocks(_dir: Vector3, _aerial: bool) -> bool:
	return false


func is_harmful() -> bool:
	return not dead and stun <= 0.0


func _sync_puppet() -> void:
	pass


func _on_hurt() -> void:
	pass


## Caught in the Ember's Flash: stunned (monsters override for their own
## light rules).
func on_flash(_from: Vector3) -> void:
	if dead:
		return
	stun = maxf(stun, 1.4)
	puppet.flash()


## Caught in the Writer's searchlight: crossed-out things are erased.
func on_searchlight(damage: int) -> void:
	if dead:
		return
	health -= damage
	Sfx.play("boss_hit" if is_in_group("boss") else "ink_enemy_hit", -3.0)
	puppet.flash()
	pop("SIZZLE!", Color(1.0, 0.95, 0.7), 1.6, 22)
	if health <= 0:
		_die()


# ----------------------------------------------------------------- helpers

func to_player() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var d := _player.global_position - global_position
	d.y = 0.0
	return d


func sees_player() -> bool:
	return _player != null and to_player().length() < sight


## Faces the 2D art left / right towards a ground direction.
func face_dir(d: Vector3) -> void:
	if absf(d.x) > 0.05:
		facing = 1 if d.x > 0.0 else -1


func move_planar(target: Vector3, rate: float, delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(target.x, 0.0, target.z), rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z


func _slow_to_stop(rate: float, delta: float) -> void:
	move_planar(Vector3.ZERO, rate, delta)


## The Writer's kind of light over `point`, if any: braziers, the
## searchlight, a Flash (not the Ember's steady glow). See world25/light.gd.
func light_at(point: Vector3) -> Node3D:
	return Light.light_at(get_tree(), point, true)


func is_lit() -> bool:
	return light_at(global_position) != null


func pop(text: String, color := DANGER, height := 1.6, size := 30) -> void:
	Fx.pop_text(get_tree(), global_position + Vector3(0, height, 0), text, color, size)


# ------------------------------------------------------------------ damage

## Called by the player's attack. Returns false when the hit was blocked.
func take_hit(damage: int, dir: Vector3, aerial := false) -> bool:
	if dead:
		return false
	if _blocks(dir, aerial):
		return false
	health -= damage
	puppet.flash()
	var push := Vector3(dir.x, 0.0, dir.z).normalized() * knockback * (1.4 if damage > 1 else 1.0)
	velocity.x = push.x
	velocity.z = push.z
	stun = 0.25
	_on_hurt()
	if health <= 0:
		_die()
	return true


func _die() -> void:
	dead = true
	Sfx.play("ink_splat")
	remove_from_group("enemy")
	collision_layer = 0
	Fx.splat(get_tree(), global_position)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.6, 0), Color(0.08, 0.05, 0.12), 18, 4.5)
	var t := create_tween()
	t.tween_property(puppet, "scale", Vector3(1.5, 0.1, 1.5), 0.1)
	t.tween_callback(func(): puppet.visible = false)
	if respawn_time <= 0.0:
		return
	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	health = hp
	stun = 0.0
	dead = false
	collision_layer = 4
	add_to_group("enemy")
	puppet.visible = true
	puppet.scale = Vector3(0.1, 0.1, 0.1)
	create_tween().tween_property(puppet, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_on_respawn()


func _on_respawn() -> void:
	pass
