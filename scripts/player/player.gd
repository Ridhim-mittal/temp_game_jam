extends CharacterBody2D
## Vesper - player controller.
## Hollow Knight style movement and "nail" combat:
##  - snappy run, variable jump height, apex hang, fast-fall
##  - coyote time + jump buffering
##  - double jump: one extra jump in the air, refilled on landing or a pogo
##  - wall cling / slide / wall jump (Hollow Knight's Mantis Claw)
##  - hard landing after a long fall (kneel, dust, shake); longer falls hurt
##  - dash with brief invincibility (vs enemies), resets on ground / pogo
##  - directional slashes (side / up / down-in-air)
##  - down-slash pogo off enemies and hazards, side-slash recoil
##  - damage, knockback, i-frames; spikes send you back to the last checkpoint
##  - the Ember (ember.gd): hold Q/E to raise a light that makes sketches real

signal health_changed(current: float, maximum: float)
signal died
signal coins_changed(total: int)

const SlashEffect = preload("res://scripts/effects/slash_effect.gd")
const JumpPuff = preload("res://scripts/effects/jump_puff.gd")
const ComicText = preload("res://scripts/effects/comic_text.gd")
const InkWave = preload("res://scripts/effects/ink_wave.gd")
const LandImpact = preload("res://scripts/effects/land_impact.gd")
const FallStreaks = preload("res://scripts/effects/fall_streaks.gd")
const WallFx = preload("res://scripts/effects/wall_fx.gd")
const DeathScreen = preload("res://scripts/ui/death_screen.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const Ember = preload("res://scripts/player/ember.gd")

const MASK_ENEMY := 4   # physics layer 3
const MASK_HAZARD := 8  # physics layer 4
const HIT_WORDS := ["THWACK!", "SLASH!", "POW!", "WHAM!", "SHNK!"]
const BODY_HALF_HEIGHT := 26.0
const HAZARD_DAMAGE := 20.0

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
## Extra jumps allowed in mid-air (1 = double jump, 0 = off). Refilled on
## landing and by a pogo.
@export var air_jumps := 1
## Launch speed of an air jump: a little weaker than the ground jump.
@export var air_jump_velocity := -700.0

@export_group("Hard Landing")
## Falls at least this long (px, from the top of the last rise) end in a
## Hollow Knight-style hard landing: Vesper slams down and kneels, unable to
## act for `hard_land_time`. A normal jump is ~170 px.
@export var hard_land_height := 400.0
@export var hard_land_time := 0.4
## Falls at least this long also hurt (0 = no fall damage) and kneel longer.
@export var fall_damage_height := 750.0
@export var fall_damage := 15.0
## Extra damage per 300 px fallen beyond `fall_damage_height`, up to the max.
@export var fall_damage_step := 10.0
@export var max_fall_damage := 45.0

@export_group("Wall")
## Hollow Knight-style wall cling: pushing into a wall while falling grabs it
## and slides down slowly; jump kicks off it. The wall just kicked off can't be
## grabbed again until landing or touching the opposite wall, so shafts can be
## climbed wall to wall but a single wall can't (no skipping puzzles).
@export var wall_cling := true
@export var wall_slide_speed := 150.0
## Kick-off speed: x away from the wall, y up.
@export var wall_jump_velocity := Vector2(430, -720)
## Seconds after a kick before steering takes over again.
@export var wall_jump_lock := 0.15

@export_group("Crouch Jump")
## Standing still, holding jump crouches and coils the legs; releasing
## launches. Legs act as a spring (E = 1/2 k x^2 -> v proportional to the
## crouch depth x), so launch speed scales linearly with how deep you
## crouched and the height scales with its square. A quick tap still gives a
## normal full jump; running jumps stay instant.
@export var crouch_time := 0.45
## Holds shorter than this are a tap: normal jump, no bonus.
@export var crouch_tap := 0.1
## Launch speed at a full crouch (1.2 -> 1.44x the height).
@export var crouch_jump_mult := 1.2

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
## Continuous health in HP. Monsters deal different amounts (see their
## damage_default()); spikes deal HAZARD_DAMAGE.
@export var max_health := 100.0
@export var invuln_time := 1.2
@export var hurt_knockback := Vector2(320, -380)
@export var hurt_stun_time := 0.22

var facing := 1
var health := 0.0
var coins := 0
var can_dash := true
var is_jumping := false
var dead := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _air_jumps_left := 0
var _crouch := -1.0  # seconds spent crouching; -1 = not crouching
var _fall_top := 0.0  # y where the current fall began (top of the last rise)
var _land_timer := 0.0  # hard-landing kneel left
var _land_length := 0.4
var _streaks: Node2D
var _wall_dir := 0  # side of the wall being slid down (1 right, -1 left), 0 = none
var _wall_coyote := 0.0  # a kick still counts this long after letting go
var _wall_coyote_dir := 0
var _wall_lock := 0.0
var _banned_wall := 0  # the side just kicked off (can't re-grab it)
var _wall_fx: Node2D
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
var _level_start := Vector2.ZERO  # where the level put Vesper (before any checkpoint)
var _charge := -1.0  # seconds attack has been held; -1 = not charging
var _charge_ready := false
var _slow_sources := {}  # source -> Vector2(speed_mult, jump_mult)

@onready var visual: Node2D = $Visual
@onready var art = $Visual/Art
@onready var sword = $Visual/Sword
@onready var hurtbox: Area2D = $Hurtbox
var ember: Node2D


func _ready() -> void:
	health = max_health
	ember = Ember.new()
	ember.name = "Ember"
	add_child(ember)
	_level_start = global_position
	var state := get_node_or_null("/root/GameState")
	if state:
		var spawn = state.spawn_point(get_tree())
		if spawn != null:
			global_position = spawn  # respawn at the last checkpoint pen
		coins = state.coins
	_fall_top = global_position.y
	_streaks = FallStreaks.new()
	add_child(_streaks)
	_wall_fx = WallFx.new()
	add_child(_wall_fx)
	health_changed.emit(health, max_health)
	coins_changed.emit(coins)
	# first run only; waits while the Writer's narration (narration.gd) is writing
	Tutorial.start(self, self, "2d", get_tree().get_first_node_in_group("narration"))


func _physics_process(delta: float) -> void:
	if dead:
		return
	if Input.is_action_just_pressed("restart"):
		_reload()
		return

	_tick_timers(delta)
	var input_x := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() and absf(input_x) < 0.2 and _hurt_timer <= 0.0 and _dash_timer <= 0.0:
			_crouch = 0.0  # standing still: crouch and coil instead of jumping at once
		else:
			_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = attack_buffer_time
		_charge = 0.0
		_charge_ready = false
	_update_charge(delta)

	# Hit-stun: no control, just fall with knockback. A hard landing kneels.
	if _hurt_timer > 0.0 or _land_timer > 0.0:
		if _land_timer > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
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
	_update_wall(input_x)
	_update_crouch(input_x, delta)
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
	_land_timer = maxf(_land_timer - delta, 0.0)
	_wall_coyote = maxf(_wall_coyote - delta, 0.0)
	_wall_lock = maxf(_wall_lock - delta, 0.0)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dash_timer = 0.0
			velocity.x = facing * max_speed  # exit dash at run speed


func _update_horizontal(input_x: float, delta: float) -> void:
	if _recoil_timer > 0.0:
		velocity.x = _recoil_dir * recoil_speed
		return
	if _wall_lock > 0.0:
		return  # carried by the wall kick
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


## Wall cling: falling while pushing into a wall grabs it and slides down.
func _update_wall(input_x: float) -> void:
	_wall_dir = 0
	if is_on_floor():
		_banned_wall = 0
		return
	if not wall_cling or not is_on_wall() or velocity.y < -60.0:
		return
	var side := -int(signf(get_wall_normal().x))
	if side == 0 or side == _banned_wall or signf(input_x) != side:
		return
	_wall_dir = side
	_banned_wall = 0  # touching the other wall frees the one kicked off before
	velocity.y = minf(velocity.y, wall_slide_speed)
	facing = -side  # back to the wall, like the Knight
	is_jumping = false
	can_dash = true
	_air_jumps_left = air_jumps
	_wall_coyote = 0.1
	_wall_coyote_dir = side


func _wall_jump() -> void:
	var away := -_wall_coyote_dir
	velocity = Vector2(away * wall_jump_velocity.x, wall_jump_velocity.y * _slow_mult().y)
	facing = away
	is_jumping = true
	_jump_buffer_timer = 0.0
	_wall_coyote = 0.0
	_wall_lock = wall_jump_lock
	_banned_wall = _wall_coyote_dir
	_wall_dir = 0
	_squash = Vector2(0.7, 1.3)
	var puff := JumpPuff.new()
	puff.position = global_position + Vector2(-away * 13.0, 4.0)
	puff.rotation = -away * PI * 0.5  # fans out from the wall
	get_tree().current_scene.add_child(puff)


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
	elif _jump_buffer_timer > 0.0 and _wall_coyote > 0.0 and not is_on_floor():
		_wall_jump()
	elif Input.is_action_just_pressed("jump") and not is_on_floor() and _air_jumps_left > 0:
		# Double jump: only on the press itself, so a jump buffered just before
		# landing still becomes a ground jump instead of spending this.
		_air_jumps_left -= 1
		velocity.y = air_jump_velocity * _slow_mult().y
		is_jumping = true
		_jump_buffer_timer = 0.0
		_squash = Vector2(0.7, 1.3)
		var puff := JumpPuff.new()
		puff.position = global_position + Vector2(0, BODY_HALF_HEIGHT)
		get_tree().current_scene.add_child(puff)
	# Variable jump height: releasing jump while rising cuts the jump short.
	if is_jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_mult
		is_jumping = false


func add_coins(amount: int) -> void:
	coins += amount
	var state := get_node_or_null("/root/GameState")
	if state:
		state.coins = coins  # banked: kept when you die
	coins_changed.emit(coins)


## Restores HP (health pickups). Returns false when already at full health.
func heal(amount: float) -> bool:
	if dead or health >= max_health:
		return false
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)
	return true


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


## Crouch-jump: coil while held, launch on release (see "Crouch Jump").
func _update_crouch(input_x: float, delta: float) -> void:
	if _crouch < 0.0:
		return
	if not is_on_floor() or absf(input_x) >= 0.2 or _hurt_timer > 0.0:
		# started running or walked off a ledge mid-crouch: jump right away
		_crouch_launch(Input.is_action_pressed("jump"))
		return
	if Input.is_action_pressed("jump"):
		_crouch = minf(_crouch + delta, crouch_time)
		velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
	else:
		_crouch_launch(false)


## 0..1 how deep the coil is (a tap reads as 0).
func crouch_amount() -> float:
	if _crouch < 0.0:
		return 0.0
	return clampf((_crouch - crouch_tap) / maxf(crouch_time - crouch_tap, 0.01), 0.0, 1.0)


func _crouch_launch(still_holding: bool) -> void:
	var depth := crouch_amount()
	_crouch = -1.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	# spring legs: launch speed grows linearly with crouch depth
	velocity.y = jump_velocity * lerpf(1.0, crouch_jump_mult, depth) * _slow_mult().y
	# the hold was spent coiling, so a release doesn't cut this jump short
	is_jumping = still_holding
	_squash = Vector2(0.75, 1.25).lerp(Vector2(0.62, 1.45), depth)
	if depth > 0.35:
		art.launch_burst(depth)
		_pop_text(global_position + Vector2(0, 30), "HUP!" if depth < 0.95 else "BOING!", Color(1.0, 0.95, 0.85))


func _start_dash(input_x: float) -> void:
	if _wall_dir != 0:
		facing = -_wall_dir  # off a wall, the dash always goes away from it
	elif input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	can_dash = false
	is_jumping = false
	_attack_timer = 0.0
	_recoil_timer = 0.0
	_cancel_charge()
	_crouch = -1.0
	_squash = Vector2(1.3, 0.75)


func _post_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var drop := global_position.y - _fall_top
		if drop >= hard_land_height and hard_land_height > 0.0:
			_hard_land(drop)
	if on_floor or velocity.y <= 0.0 or _wall_dir != 0:
		_fall_top = global_position.y  # a fall is measured from the top of the last rise (or a wall)
	if on_floor:
		_coyote_timer = coyote_time
		can_dash = true
		_air_jumps_left = air_jumps
		if velocity.y >= 0.0:
			is_jumping = false
		if not _was_on_floor:
			_squash = Vector2(1.25, 0.8)
	_was_on_floor = on_floor
	_check_hurtbox()
	_update_visuals(delta)


## Hollow Knight-style hard landing: freeze-frame, shake, ground burst and a
## kneel that locks control; past `fall_damage_height` it also hurts.
func _hard_land(drop: float) -> void:
	var hurts := fall_damage_height > 0.0 and drop >= fall_damage_height
	_land_length = hard_land_time * (1.6 if hurts else 1.0)
	_land_timer = _land_length
	_crouch = -1.0
	_cancel_charge()
	_attack_timer = 0.0
	velocity.x *= 0.3
	_squash = Vector2(1.5, 0.58)
	var fx := LandImpact.new()
	fx.power = 1.5 if hurts else 1.0
	fx.position = global_position + Vector2(0, BODY_HALF_HEIGHT)
	get_tree().current_scene.add_child(fx)
	if hurts:
		var dmg := minf(fall_damage + (drop - fall_damage_height) / 300.0 * fall_damage_step, max_fall_damage)
		health = maxf(health - dmg, 0.0)
		health_changed.emit(health, max_health)
		_invuln_timer = invuln_time
		_pop_text(global_position + Vector2(0, -50), "CRUNCH!", Color(1.0, 0.4, 0.35))
		_hitstop(0.12, 0.02)
		_shake(0.8)
		if health <= 0.0:
			_die()
	else:
		_pop_text(global_position + Vector2(0, -46), "THUD!", Color(0.97, 0.94, 0.86))
		_hitstop(0.06, 0.05)
		_shake(0.45)


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
		_air_jumps_left = air_jumps
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


func _check_hurtbox() -> void:
	for body in _hurtbox_overlaps():
		# Hazards always hurt, even during i-frames (Hollow Knight spikes).
		if body.is_in_group("hazard"):
			take_damage(HAZARD_DAMAGE, body.global_position, true)
			return
		if _invuln_timer > 0.0 or _dash_timer > 0.0:
			continue  # dash i-frames protect from enemies only
		if body.is_in_group("enemy") and not ("dead" in body and body.dead):
			var dmg := 15.0
			if body.has_method("get_damage"):
				dmg = body.get_damage()
			elif "contact_damage" in body:
				dmg = body.contact_damage
			take_damage(dmg, body.global_position)
			if body.has_method("on_hit_player"):
				body.on_hit_player()  # projectiles pop instead of flying on
			return


func take_damage(amount: float, source_pos: Vector2, from_hazard := false) -> void:
	if dead or (_invuln_timer > 0.0 and not from_hazard):
		return
	health = maxf(health - amount, 0.0)
	_cancel_charge()
	_crouch = -1.0
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

	if health <= 0.0:
		_die()
		return
	if from_hazard:
		velocity = Vector2.ZERO
		global_position = _respawn_point()
		_fall_top = global_position.y
		_hurt_timer = 0.4  # brief freeze after respawn
		var cam := get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_smoothing()  # cut straight there, no long camera swoop
	else:
		var dir := signf(global_position.x - source_pos.x)
		if dir == 0.0:
			dir = -facing
		velocity = Vector2(dir * hurt_knockback.x, hurt_knockback.y)


## Where spikes send you: the last checkpoint pen in this level, else the
## level's start. Never "the last ground you stood on": that could be right
## next to the spikes and loop you into them.
func _respawn_point() -> Vector2:
	var state := get_node_or_null("/root/GameState")
	if state:
		var spawn = state.spawn_point(get_tree())
		if spawn != null:
			return spawn
	return _level_start


func _die() -> void:
	dead = true
	died.emit()
	velocity = Vector2.ZERO
	var t := create_tween()
	t.tween_property(visual, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.75, true, false, true).timeout
	DeathScreen.open(get_tree())  # RESTART (last checkpoint pen) or MAIN MENU


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
	art.crouch = crouch_amount() if _crouch >= 0.0 else 0.0
	art.crouching = _crouch >= 0.0
	art.land = _land_timer / _land_length if _land_timer > 0.0 else 0.0
	art.wall = 1.0 if _wall_dir != 0 else 0.0
	_wall_fx.side = _wall_dir
	var drop := global_position.y - _fall_top if not is_on_floor() and velocity.y > 0.0 else 0.0
	_streaks.amount = clampf((drop - hard_land_height * 0.6) / (hard_land_height * 0.4), 0.0, 1.0) \
		if hard_land_height > 0.0 else 0.0
	_streaks.danger = fall_damage_height > 0.0 and drop >= fall_damage_height
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
