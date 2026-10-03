extends CharacterBody2D
## Vesper - player controller.
## Hollow Knight style movement and "nail" combat:
##  - snappy run, variable jump height, apex hang, fast-fall
##  - coyote time + jump buffering
##  - dash with brief invincibility (vs enemies), resets on ground / pogo
##  - directional slashes (side / up / down-in-air)
##  - down-slash pogo off enemies and hazards, side-slash recoil
##  - damage, knockback, i-frames, hazard respawn to last safe ground

signal health_changed(current: int, maximum: int)
signal died
signal coins_changed(total: int)

const SlashEffect = preload("res://scripts/effects/slash_effect.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const InkWave = preload("res://scripts/effects/ink_wave.gd")

const MASK_ENEMY := 4   # physics layer 3
const MASK_HAZARD := 8  # physics layer 4
const HIT_WORDS := ["THWACK!", "SLASH!", "POW!", "WHAM!", "SHNK!"]
const BODY_HALF_HEIGHT := 26.0

@export_group("Run")
@export var max_speed := 300.0
@export var ground_accel := 4000.0
@export var ground_decel := 5000.0
@export var air_accel := 2600.0
@export var air_decel := 2000.0

@export_group("Jump")
@export var jump_velocity := -800.0
@export var gravity := 2000.0
@export var fall_gravity_mult := 1.35
@export var max_fall_speed := 950.0
@export var jump_cut_mult := 0.4
@export var apex_hang_threshold := 80.0
@export var apex_gravity_mult := 0.55
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Dash")
@export var dash_speed := 760.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.45

@export_group("Attack")
@export var attack_damage := 1
@export var attack_cooldown := 0.32
@export var attack_active_time := 0.1
@export var attack_buffer_time := 0.12
@export var attack_reach := 80.0
@export var attack_width := 64.0
@export var pogo_velocity := -660.0
@export var recoil_speed := 280.0
@export var recoil_time := 0.09

@export_group("Charged Attack")
## Hold attack this long (after the normal slash) to charge the ink wave.
@export var charge_time := 0.6
## Holding shorter than this shows no charge effect (it was just a tap).
@export var charge_show_delay := 0.15
@export var wave_damage := 2
@export var wave_speed := 1100.0
@export var wave_range := 520.0
@export var wave_recoil := 160.0

@export_group("Health")
@export var max_health := 5
@export var invuln_time := 1.2
@export var hurt_knockback := Vector2(320, -380)
@export var hurt_stun_time := 0.22

var facing := 1
var health := 0
var coins := 0
var can_dash := true
var is_jumping := false
var dead := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _attack_buffer_timer := 0.0
var _attack_dir := Vector2.RIGHT
var _attack_hit_targets: Array = []
var _attack_pogoed := false
var _attack_recoiled := false
var _recoil_timer := 0.0
var _recoil_dir := 0.0
var _invuln_timer := 0.0
var _hurt_timer := 0.0
var _was_on_floor := false
var _squash := Vector2.ONE
var _last_safe_position := Vector2.ZERO
var _charge := -1.0  # seconds attack has been held; -1 = not charging
var _charge_ready := false
var _slow_sources := {}  # source -> Vector2(speed_mult, jump_mult)

@onready var visual: Node2D = $Visual
@onready var art = $Visual/Art
@onready var sword = $Visual/Sword
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	health = max_health
	_last_safe_position = global_position
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if Input.is_action_just_pressed("restart"):
		_reload()
		return

	_tick_timers(delta)
	var input_x := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = attack_buffer_time
		_charge = 0.0
		_charge_ready = false
	_update_charge(delta)

	# Hit-stun: no control, just fall with knockback.
	if _hurt_timer > 0.0:
		_apply_gravity(delta)
		move_and_slide()
		_post_move(delta)
		return

	if Input.is_action_just_pressed("dash") and can_dash and _dash_cooldown_timer <= 0.0:
		_start_dash(input_x)

	if _dash_timer > 0.0:
		velocity = Vector2(facing * dash_speed, 0.0)
		move_and_slide()
		_post_move(delta)
		return

	_update_horizontal(input_x, delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_attack_input()
	if _attack_timer > 0.0:
		_process_attack_hits()

	move_and_slide()
	_post_move(delta)


# ---------------------------------------------------------------- movement

func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	_recoil_timer = maxf(_recoil_timer - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dash_timer = 0.0
			velocity.x = facing * max_speed  # exit dash at run speed


func _update_horizontal(input_x: float, delta: float) -> void:
	if _recoil_timer > 0.0:
		velocity.x = _recoil_dir * recoil_speed
		return
	# Facing is locked while a slash is active.
	if input_x != 0.0 and _attack_timer <= 0.0:
		facing = 1 if input_x > 0.0 else -1
	var target := input_x * max_speed * _slow_mult().x
	var accelerating := absf(target) > 0.01
	var rate: float
	if is_on_floor():
		rate = ground_accel if accelerating else ground_decel
	else:
		rate = air_accel if accelerating else air_decel
	velocity.x = move_toward(velocity.x, target, rate * delta)


func _apply_gravity(delta: float) -> void:
	var g := gravity
	if is_jumping and Input.is_action_pressed("jump") and absf(velocity.y) < apex_hang_threshold:
		g *= apex_gravity_mult  # floaty apex, like HK
	elif velocity.y > 0.0:
		g *= fall_gravity_mult  # snappier fall
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity * _slow_mult().y
		is_jumping = true
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_squash = Vector2(0.75, 1.25)
	# Variable jump height: releasing jump while rising cuts the jump short.
	if is_jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_mult
		is_jumping = false


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


## Called by slowing obstacles (e.g. goo_pool.gd). Multipliers of 1 remove
## the source; overlapping sources use the strongest slow.
func set_slowed(source: Object, speed_mult := 1.0, jump_mult := 1.0) -> void:
	if speed_mult >= 1.0 and jump_mult >= 1.0:
		_slow_sources.erase(source)
	else:
		_slow_sources[source] = Vector2(speed_mult, jump_mult)


func _slow_mult() -> Vector2:
	var m := Vector2.ONE
	for v in _slow_sources.values():
		m = m.min(v)
	return m


func _start_dash(input_x: float) -> void:
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	can_dash = false
	is_jumping = false
	_attack_timer = 0.0
	_recoil_timer = 0.0
	_cancel_charge()
	_squash = Vector2(1.3, 0.75)


func _post_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = coyote_time
		can_dash = true
		if velocity.y >= 0.0:
			is_jumping = false
		if not _was_on_floor:
			_squash = Vector2(1.25, 0.8)
		if not _touching_hazard():
			_last_safe_position = global_position
	_was_on_floor = on_floor
	_check_hurtbox()
	_update_visuals(delta)


# ------------------------------------------------------------------ combat

func _handle_attack_input() -> void:
	if _attack_buffer_timer <= 0.0 or _attack_cooldown_timer > 0.0:
		return
	_attack_buffer_timer = 0.0
	if Input.is_action_pressed("up"):
		_attack_dir = Vector2.UP
	elif Input.is_action_pressed("down") and not is_on_floor():
		_attack_dir = Vector2.DOWN
	else:
		_attack_dir = Vector2(facing, 0)
	_attack_timer = attack_active_time
	_attack_cooldown_timer = attack_cooldown
	_attack_hit_targets.clear()
	_attack_pogoed = false
	_attack_recoiled = false
	_spawn_slash()
	sword.swing(_attack_dir)


## Hold-to-charge, Hollow Knight "nail art" style: the press already did a
## normal slash, keep holding to charge, release when charged to fire.
func _update_charge(delta: float) -> void:
	if _charge < 0.0:
		return
	if Input.is_action_pressed("attack"):
		_charge += delta
		if not _charge_ready and _charge >= charge_time:
			_charge_ready = true
			_squash = Vector2(1.1, 0.92)
		return
	if _charge_ready:
		_release_wave()
	_cancel_charge()


func _cancel_charge() -> void:
	_charge = -1.0
	_charge_ready = false


func _release_wave() -> void:
	var wave := InkWave.new()
	wave.direction = facing
	wave.speed = wave_speed
	wave.max_range = wave_range
	wave.damage = wave_damage
	wave.position = global_position + Vector2(facing * 30.0, -4.0)
	get_tree().current_scene.add_child(wave)
	_pop_text(global_position + Vector2(facing * 30.0, -60), "KA-SHOOM!", Color(1.0, 0.58, 0.14))
	velocity.x -= facing * wave_recoil
	_squash = Vector2(1.25, 0.8)
	_shake(0.3)
	sword.thrust()


## Returns [center (local), size] of the current slash hitbox.
func _get_attack_box() -> Array:
	if _attack_dir.y < 0.0:
		return [Vector2(0, -BODY_HALF_HEIGHT - attack_reach * 0.5), Vector2(attack_width, attack_reach)]
	if _attack_dir.y > 0.0:
		return [Vector2(0, BODY_HALF_HEIGHT + attack_reach * 0.5), Vector2(attack_width * 1.15, attack_reach)]
	return [Vector2(_attack_dir.x * (13.0 + attack_reach * 0.5), -4), Vector2(attack_reach, attack_width)]


func _process_attack_hits() -> void:
	var box := _get_attack_box()
	var shape := RectangleShape2D.new()
	shape.size = box[1]
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position + box[0])
	params.collision_mask = MASK_ENEMY | MASK_HAZARD
	params.collide_with_bodies = true
	params.collide_with_areas = true
	for result in get_world_2d().direct_space_state.intersect_shape(params, 16):
		var target: Object = result.collider
		if target == null or target in _attack_hit_targets:
			continue
		_attack_hit_targets.append(target)
		_on_attack_connect(target)


func _on_attack_connect(target: Object) -> void:
	var landed := false
	if target.has_method("take_hit"):
		if "dead" in target and target.dead:
			return
		target.take_hit(attack_damage, _attack_dir, global_position)
		landed = true
		_pop_text(target.global_position + Vector2(0, -40), HIT_WORDS.pick_random())
		_hitstop(0.06)
		_shake(0.35)
	elif target is Node and target.is_in_group("pogo"):
		landed = true
		if _attack_dir.y > 0.0:
			_pop_text(global_position + Vector2(0, 50), "CLANG!", Color(0.85, 0.9, 1.0))
		_shake(0.15)
	if not landed:
		return

	if _attack_dir.y > 0.0 and not _attack_pogoed:
		# Pogo! Bounce off whatever we hit below us.
		_attack_pogoed = true
		velocity.y = pogo_velocity
		is_jumping = false
		can_dash = true
		_squash = Vector2(0.8, 1.2)
	elif _attack_dir.y == 0.0 and not _attack_recoiled:
		_attack_recoiled = true
		_recoil_timer = recoil_time
		_recoil_dir = -_attack_dir.x


func _spawn_slash() -> void:
	var box := _get_attack_box()
	var slash := SlashEffect.new()
	slash.position = box[0]
	slash.radius = attack_reach * 0.5
	slash.rotation = _attack_dir.angle()
	add_child(slash)


# ------------------------------------------------------------------ damage

## Everything (enemies + hazards) currently overlapping the Hurtbox shape,
## optionally grown by `grow` pixels. A direct query is used because Area2D
## overlap lists don't report StaticBody2D hazards reliably.
func _hurtbox_overlaps(grow := Vector2.ZERO) -> Array:
	var cs: CollisionShape2D = hurtbox.get_node("CollisionShape2D")
	var shape := RectangleShape2D.new()
	shape.size = (cs.shape as RectangleShape2D).size + grow
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = cs.global_transform
	params.collision_mask = MASK_ENEMY | MASK_HAZARD
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var out: Array = []
	for result in get_world_2d().direct_space_state.intersect_shape(params, 16):
		if result.collider is Node:
			out.append(result.collider)
	return out


## True if a hazard is within `margin` px - used so the respawn checkpoint
## is never recorded right at the edge of spikes.
func _touching_hazard(margin := 48.0) -> bool:
	for body in _hurtbox_overlaps(Vector2(margin * 2.0, 8.0)):
		if body.is_in_group("hazard"):
			return true
	return false


func _check_hurtbox() -> void:
	for body in _hurtbox_overlaps():
		# Hazards always hurt, even during i-frames (Hollow Knight spikes).
		if body.is_in_group("hazard"):
			take_damage(1, body.global_position, true)
			return
		if _invuln_timer > 0.0 or _dash_timer > 0.0:
			continue  # dash i-frames protect from enemies only
		if body.is_in_group("enemy") and not ("dead" in body and body.dead):
			var dmg: int = body.contact_damage if "contact_damage" in body else 1
			take_damage(dmg, body.global_position)
			if body.has_method("on_hit_player"):
				body.on_hit_player()  # projectiles pop instead of flying on
			return


func take_damage(amount: int, source_pos: Vector2, from_hazard := false) -> void:
	if dead or (_invuln_timer > 0.0 and not from_hazard):
		return
	health = maxi(health - amount, 0)
	_cancel_charge()
	health_changed.emit(health, max_health)
	_invuln_timer = invuln_time
	_hurt_timer = hurt_stun_time
	_dash_timer = 0.0
	_attack_timer = 0.0
	_recoil_timer = 0.0
	is_jumping = false
	_pop_text(global_position + Vector2(0, -50), "OOF!", Color(1.0, 0.4, 0.35))
	_hitstop(0.12, 0.02)
	_shake(0.6)

	if health <= 0:
		_die()
		return
	if from_hazard:
		velocity = Vector2.ZERO
		global_position = _last_safe_position
		_hurt_timer = 0.4  # brief freeze after respawn
	else:
		var dir := signf(global_position.x - source_pos.x)
		if dir == 0.0:
			dir = -facing
		velocity = Vector2(dir * hurt_knockback.x, hurt_knockback.y)


func _die() -> void:
	dead = true
	died.emit()
	velocity = Vector2.ZERO
	var t := create_tween()
	t.tween_property(visual, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(1.2, true, false, true).timeout
	_reload()


func _reload() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ------------------------------------------------------------------- juice

func _update_visuals(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	visual.scale = Vector2(facing * _squash.x, _squash.y)
	art.velocity = velocity
	art.facing = facing
	art.on_floor = is_on_floor()
	art.dashing = _dash_timer > 0.0
	art.max_speed = max_speed
	art.stuck = _slow_mult().x < 1.0
	art.charge = clampf((_charge - charge_show_delay) / (charge_time - charge_show_delay), 0.0, 1.0) if _charge >= 0.0 else 0.0
	art.charge_ready = _charge_ready
	sword.charge = art.charge
	sword.charge_ready = _charge_ready
	var col := Color.WHITE
	if _dash_timer > 0.0:
		col = Color(1.5, 1.5, 1.8)
	if _invuln_timer > 0.0 and fmod(_invuln_timer, 0.16) < 0.08:
		col.a = 0.3
	visual.modulate = col


func _hitstop(duration: float, time_scale := 0.05) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.add_trauma(amount)


func _pop_text(pos: Vector2, text: String, color := Color(1.0, 0.82, 0.15)) -> void:
	var pop := ComicText.new()
	pop.text = text
	pop.color = color
	pop.position = pos
	get_tree().current_scene.add_child(pop)
