extends CharacterBody3D
## Top-down (Cult of the Lamb style) controller for the 2.5D clearing.
## Moves on the ground plane with WASD / stick, jumps on Space, dashes on
## Shift / right click, attacks on left click / X: a three-hit combo (the
## third hit is a heavier finisher) aimed at the mouse cursor, or along the
## movement direction from the keyboard or a gamepad. Attacking in the air
## strikes from above: it gets past a Crossed-Out's shield and bounces you
## off what you hit. The character is the same procedural Vesper art as the
## platformer (player_visual.gd), drawn into a SubViewport on a billboard.
##
## Smoothness:
##  - the body moves on physics ticks, but the visuals ($Visual3D, top
##    level) are interpolated between the last two ticks every frame, so
##    motion stays fluid whatever the screen's refresh rate
##  - turning around squashes the art through zero instead of snapping
##  - constant speed on slopes and floor snapping keep stairs even

signal health_changed(current: int, maximum: int)
signal ember_changed(fuel: float, maximum: float)
signal died

const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const FlashScript = preload("res://scripts/world25/flash.gd")
const InkWave = preload("res://scripts/world25/ink_wave_3d.gd")
const ART_RUN_SPEED := 300.0  # player_visual.gd's full-run speed, px/s
const MASK_WORLD := 1
const MASK_ENEMY := 4  # physics layer 3
const HIT_WORDS := ["THWACK!", "SLASH!", "POW!", "WHAM!", "SHNK!"]

## How a swing looks: Vesper swings the platformer's nib-sword (sword.gd)
## and an ink crescent sweeps the ground (clearing_fx.gd). Either can be
## turned off per scene.
enum AttackStyle { INK_SLASH, NIB_SWORD, BOTH }

@export var max_speed := 5.5
@export var accel := 38.0
@export var decel := 42.0
## Extra acceleration when steering against the current motion, so quick
## turns feel responsive rather than slidey.
@export var turn_accel := 70.0
@export var dash_speed := 15.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.4
@export var gravity := 30.0
## How fast the art flips when changing direction (turns per second).
@export var flip_speed := 9.0
## Below this height the player fell off the map and is put back.
@export var kill_height := -12.0

@export_group("Jump")
@export var jump_velocity := 9.5
## Gravity is stronger on the way down, so jumps feel snappy, not floaty.
@export var fall_gravity_mult := 1.5
## Releasing jump early keeps this much of the upward speed (short hop).
@export var jump_cut := 0.45
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
## Upward bounce after an air attack connects.
@export var pogo_velocity := 8.5

@export_group("Health")
@export var max_health := 5
@export var invuln_time := 1.0
@export var hurt_knockback := 7.0
@export var hurt_hop := 4.0

@export_group("Ember")
## Vesper's own light (design doc 6.7). Its glow makes drawn things real
## around Vesper and shrinks as fuel runs low; hits refill it.
@export var max_fuel := 100.0
@export var start_fuel := 60.0
@export var fuel_per_hit := 8.0
@export var glow_radius_full := 3.4
@export var glow_radius_empty := 1.6
## Flash: right click / Q.
@export var flash_cost := 25.0
## Heal: hold F, standing still.
@export var heal_cost := 33.0
@export var heal_time := 1.0

@export_group("Attack")
@export var attack_style := AttackStyle.BOTH
@export var attack_damage := 1
@export var finisher_damage := 2
## Centre of the hit circle, in front of the player.
@export var attack_reach := 1.1
@export var attack_radius := 1.0
## Forward burst when swinging (the finisher lunges further).
@export var attack_lunge := 6.5
## Swing lockout; the finisher takes longer.
@export var attack_time := 0.24
@export var finisher_time := 0.38
## After a swing ends, the next press within this time continues the combo.
@export var combo_window := 0.35
@export var attack_buffer_time := 0.15

var facing := 1
var health := 0
var dead := false
## Interpolated position of the visuals; the camera follows this.
var smooth_position := Vector3.ZERO
## Height of the ground under the player (the shadow and camera use it, so
## jumping doesn't bob the view).
var ground_height := 0.0
var fuel := 60.0
## The Ember only makes drawn things real; it doesn't burn monsters.
var monster_light := false
## 0..1: how close a searchlight is to erasing Vesper (searchlight.gd fills
## it; she whitens as it rises).
var erase := 0.0
var erase_source: Node

var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := Vector3.FORWARD
var _squash := Vector2.ONE
var _flip := 1.0  # -1..1, eases towards `facing`
var _spawn := Vector3.ZERO
var _was_on_floor := true
var _prev_tick_pos := Vector3.ZERO
var _tick_pos := Vector3.ZERO
var _attack_timer := 0.0
var _attack_buffer := 0.0
var _combo := 0
var _combo_timer := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _jumping := false
var _invuln := 0.0
var _hurt_timer := 0.0
var _slow_sources := {}  # source -> Vector2(speed_mult, jump_mult)
var _channel := -1.0  # seconds spent channelling a heal; -1 = not healing
var _safe_pos := Vector3.ZERO
var _safe_timer := 0.0
# loadout (skills, gear, difficulty), set by _apply_loadout()
var _flash_radius_mult := 1.0
var _aerial_bonus := 0
var _ink_wave := false
var _seal_ready := false
var _last_drop_ready := false
var _slash_rim := Color(1.0, 0.58, 0.14)

@onready var visual_3d: Node3D = $Visual3D
@onready var sprite: Sprite3D = $Visual3D/Sprite
@onready var shadow: MeshInstance3D = $Visual3D/BlobShadow
@onready var art_viewport: SubViewport = $ArtViewport
@onready var visual: Node2D = $ArtViewport/Visual
@onready var art = $ArtViewport/Visual/Art
@onready var sword = $ArtViewport/Visual/Sword
@onready var ember_light: OmniLight3D = $Visual3D/Ember

## Size the art is drawn at inside the SubViewport (sharper billboard).
var _art_scale := 2.0


func _ready() -> void:
	Engine.time_scale = 1.0
	add_to_group("player")
	_spawn = global_position
	ground_height = global_position.y
	_apply_loadout()
	health = max_health
	fuel = minf(start_fuel, max_fuel)
	_safe_pos = global_position
	add_to_group("light_3d")
	_art_scale = visual.scale.y
	sprite.texture = art_viewport.get_texture()
	floor_constant_speed = true
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	_snap_visuals()
	Fx.prewarm.call_deferred(get_tree(), global_position)
	_apply_attack_style()
	health_changed.emit.call_deferred(health, max_health)
	ember_changed.emit.call_deferred(fuel, max_fuel)


func _apply_attack_style() -> void:
	var has_sword := attack_style != AttackStyle.INK_SLASH
	sword.visible = has_sword
	sword.set_process(has_sword)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if dead:
		velocity = Vector3.ZERO
		_prev_tick_pos = _tick_pos
		return
	var input := Input.get_vector("move_left", "move_right", "up", "down")
	var dir := Vector3(input.x, 0.0, input.y)
	var in_control := _hurt_timer <= 0.0
	if not in_control:
		dir = Vector3.ZERO
	if absf(input.x) > 0.2 and _attack_timer <= 0.0 and in_control:
		facing = 1 if input.x > 0.0 else -1

	if in_control:
		if Input.is_action_just_pressed("attack"):
			_attack_buffer = attack_buffer_time
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = jump_buffer_time
		if Input.is_action_just_pressed("flash"):
			_flash()
		# right click is Flash here; Shift / C dash
		var dash_pressed := Input.is_action_just_pressed("dash") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if dash_pressed and _dash_cooldown_timer <= 0.0:
			_dash_dir = dir.normalized() if dir != Vector3.ZERO else Vector3(facing, 0, 0)
			_dash_timer = dash_time
			_dash_cooldown_timer = dash_cooldown
			_attack_timer = 0.0  # a dash cancels a swing
			_squash = Vector2(1.3, 0.75)
		_update_heal(delta)
		if _channel >= 0.0:
			dir = Vector3.ZERO  # rooted while healing
		elif _attack_buffer > 0.0 and _attack_timer <= 0.0 and _dash_timer <= 0.0:
			_start_attack(dir)

	_update_planar(dir, delta)
	_update_vertical(delta)
	move_and_slide()
	_post_move()


func _tick_timers(delta: float) -> void:
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)


func _update_planar(dir: Vector3, delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if _hurt_timer > 0.0:
		planar = planar.move_toward(Vector3.ZERO, 12.0 * delta)  # knocked back
	elif _attack_timer > 0.0:
		# rooted during a swing: the lunge slides out quickly
		planar = planar.move_toward(Vector3.ZERO, 32.0 * delta)
	elif _dash_timer > 0.0:
		# fast burst that eases out into a run
		var t := 1.0 - _dash_timer / dash_time
		planar = _dash_dir * lerpf(dash_speed, max_speed, t * t)
	elif dir != Vector3.ZERO:
		var target := dir * max_speed * _slow_mult().x
		var rate := accel
		if planar.length() > 0.5 and planar.normalized().dot(dir.normalized()) < 0.3:
			rate = turn_accel
		planar = planar.move_toward(target, rate * delta)
	else:
		planar = planar.move_toward(Vector3.ZERO, decel * delta)
	velocity.x = planar.x
	velocity.z = planar.z


func _update_vertical(delta: float) -> void:
	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0 and _attack_timer <= 0.0:
		velocity.y = jump_velocity * _slow_mult().y
		_jumping = true
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.75, 1.25)
	elif is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
		_jumping = false
	else:
		var g := gravity * (fall_gravity_mult if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta
		# variable height: letting go of jump on the way up cuts it short
		if _jumping and velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut
			_jumping = false


func _post_move() -> void:
	if is_on_floor() and not _was_on_floor:
		_squash = Vector2(1.25, 0.8)
	_was_on_floor = is_on_floor()
	_probe_ground()
	_check_contact_damage()
	_track_safe_ground(get_physics_process_delta_time())
	if global_position.y < ground_height - 4.0 or global_position.y < kill_height:
		_fell()
	_prev_tick_pos = _tick_pos
	_tick_pos = global_position


func _probe_ground() -> void:
	if is_on_floor():
		ground_height = global_position.y
		return
	var from := global_position + Vector3(0, 0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30, 0), MASK_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		ground_height = hit.position.y


func _process(delta: float) -> void:
	smooth_position = _prev_tick_pos.lerp(_tick_pos, Engine.get_physics_interpolation_fraction())
	visual_3d.global_position = smooth_position
	# the shadow stays on the ground and shrinks as you rise
	var height := maxf(smooth_position.y - ground_height, 0.0)
	shadow.position.y = -height + 0.03
	shadow.scale = Vector3.ONE * clampf(1.0 - height * 0.25, 0.45, 1.0)
	_update_art(delta)


# ------------------------------------------------------------------ attack

func _start_attack(move_dir: Vector3) -> void:
	_attack_buffer = 0.0
	_combo = _combo % 3 + 1 if _combo_timer > 0.0 else 1
	var finisher := _combo == 3
	var dir := _aim_direction(move_dir)
	if absf(dir.x) > 0.15:
		facing = 1 if dir.x > 0.0 else -1
	var lunge := attack_lunge * (1.4 if finisher else 1.0)
	velocity.x = dir.x * lunge
	velocity.z = dir.z * lunge
	_attack_timer = finisher_time if finisher else attack_time
	_combo_timer = _attack_timer + combo_window
	_squash = Vector2(1.25, 0.8) if finisher else Vector2(1.15, 0.88)
	if attack_style != AttackStyle.NIB_SWORD:
		Fx.slash(get_tree(), global_position, dir, _combo == 2, finisher, _slash_rim)
	if finisher and _ink_wave:
		var wave := InkWave.new()
		wave.direction = dir
		wave.rim = _slash_rim
		wave.damage = finisher_damage
		get_tree().current_scene.add_child(wave)
		wave.global_position = Vector3(global_position.x, ground_height, global_position.z) + dir * 0.6
	if attack_style != AttackStyle.INK_SLASH:
		sword.swing(_sword_direction(dir))
	_hit_in_front(dir, finisher)


## The 2D sword knows side, up and down swings: map the ground direction
## onto those (away from the camera = up, towards it = down).
func _sword_direction(dir: Vector3) -> Vector2:
	if dir.z < -0.6:
		return Vector2.UP
	if dir.z > 0.6:
		return Vector2.DOWN
	return Vector2(signf(dir.x), 0.0)


## Mouse attacks aim at the cursor; keyboard / gamepad attacks follow the
## movement direction, or the way the character faces.
func _aim_direction(move_dir: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mp := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mp)
		var n := cam.project_ray_normal(mp)
		if absf(n.y) > 0.01:
			var hit := from + n * ((global_position.y + 0.5 - from.y) / n.y)
			var d := Vector3(hit.x - global_position.x, 0.0, hit.z - global_position.z)
			if d.length() > 0.2:
				return d.normalized()
	if move_dir != Vector3.ZERO:
		return move_dir.normalized()
	return Vector3(facing, 0.0, 0.0)


func _hit_in_front(dir: Vector3, finisher: bool) -> void:
	var aerial := not is_on_floor()
	var center := global_position + dir * attack_reach
	var radius := attack_radius * (1.25 if finisher else 1.0)
	# airborne swings reach a bit lower, to catch things you jumped over
	var probe_y := -0.3 if aerial else 0.5
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center + Vector3(0.0, probe_y, 0.0))
	params.collision_mask = MASK_ENEMY
	var hits := 0
	for result in get_world_3d().direct_space_state.intersect_shape(params, 16):
		var target: Object = result.collider
		if target and target.has_method("take_hit") and not ("dead" in target and target.dead):
			var dmg: int = (finisher_damage if finisher else attack_damage) + (_aerial_bonus if aerial else 0)
			var landed = target.take_hit(dmg, dir, aerial)
			if landed == false:
				continue  # blocked: the monster shows its own reaction
			hits += 1
			var word: String = "KA-POW!" if finisher else HIT_WORDS.pick_random()
			Fx.pop_text(get_tree(), target.global_position + Vector3(0, 1.3, 0), word)
	# unlit lanterns catch when struck
	for l in get_tree().get_nodes_in_group("lantern"):
		if not l.lit and Vector2(l.global_position.x - center.x, l.global_position.z - center.z).length() < radius + 0.6:
			l.ignite()
			hits += 1
	# ink blobs can be cut out of the air
	for blob in get_tree().get_nodes_in_group("ink_blob"):
		if blob.global_position.distance_to(center + Vector3(0, 0.6, 0)) < radius + 0.4:
			blob.slash()
			hits += 1
	var cut := 0
	for grass in get_tree().get_nodes_in_group("grass"):
		cut += grass.cut(center, radius * 0.9)
	if cut > 0:
		Fx.burst(get_tree(), center + Vector3(0, 0.3, 0), Color(0.42, 0.62, 0.42), mini(cut * 3, 18), 3.0)
	if hits > 0:
		add_fuel(fuel_per_hit * hits)
		if aerial:
			# pogo: bounce off what you hit, ready to strike again
			velocity.y = pogo_velocity
			_jumping = false
			_squash = Vector2(0.8, 1.2)
		_hitstop(0.09 if finisher else 0.05)
		_shake(0.45 if finisher else 0.28)
	elif finisher:
		_shake(0.12)


func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)


# ----------------------------------------------------------------- loadout

## Applies skills (Ink Points), shop gear and the difficulty setting on top
## of the exported base values. Runs once per spawn (each room).
const LOADOUT_STATS := ["max_health", "invuln_time", "max_speed", "dash_speed", "dash_cooldown", "attack_reach",
	"attack_radius", "attack_damage", "finisher_damage", "attack_time", "finisher_time", "pogo_velocity", "max_fuel",
	"glow_radius_full", "fuel_per_hit", "flash_cost", "heal_time", "heal_cost"]
var _base_stats := {}


func _apply_loadout() -> void:
	# start from the exported values every time, so re-applying never stacks
	if _base_stats.is_empty():
		for k in LOADOUT_STATS:
			_base_stats[k] = get(k)
	else:
		for k in LOADOUT_STATS:
			set(k, _base_stats[k])
	var profile := get_node_or_null("/root/Profile")
	var settings := get_node_or_null("/root/Settings")
	var diff: String = settings.get_value("difficulty") if settings else "normal"
	if diff == "relaxed":
		max_health += 2
		invuln_time *= 1.5
	if profile == null:
		return
	max_health += int(profile.effect("health_bonus", 0))
	max_speed *= profile.effect("speed_mult", 1.0)
	dash_speed *= profile.effect("dash_mult", 1.0)
	dash_cooldown *= profile.effect("dash_cd_mult", 1.0)
	attack_reach *= profile.effect("reach_mult", 1.0)
	attack_radius *= profile.effect("radius_mult", 1.0)
	var dmg := int(profile.effect("damage_bonus", 0))
	attack_damage += dmg
	finisher_damage += dmg + int(profile.effect("finisher_bonus", 0))
	attack_time *= profile.effect("swing_mult", 1.0)
	finisher_time *= profile.effect("swing_mult", 1.0)
	pogo_velocity *= profile.effect("pogo_mult", 1.0)
	_aerial_bonus = int(profile.effect("aerial_bonus", 0))
	_ink_wave = profile.effect("ink_wave", false)
	var extra_fuel: float = profile.effect("fuel_bonus", 0.0)
	max_fuel += extra_fuel
	glow_radius_full += extra_fuel * 0.024
	fuel_per_hit *= profile.effect("fuel_hit_mult", 1.0)
	_flash_radius_mult = profile.effect("flash_radius_mult", 1.0)
	flash_cost += profile.effect("flash_cost_delta", 0.0)
	heal_time *= profile.effect("heal_time_mult", 1.0)
	heal_cost += profile.effect("heal_cost_delta", 0.0)
	invuln_time *= profile.effect("invuln_mult", 1.0)
	_seal_ready = profile.effect("seal", false)
	_last_drop_ready = profile.effect("last_drop", false)
	_apply_look(profile.look())


## After the shop or skill tree: re-apply everything, keeping health and
## fuel (topped up by any new maximum).
func refresh_loadout() -> void:
	var old_max := max_health
	var old_fuel_max := max_fuel
	_apply_loadout()
	health = clampi(health + maxi(max_health - old_max, 0), 1, max_health)
	fuel = clampf(fuel + maxf(max_fuel - old_fuel_max, 0.0), 0.0, max_fuel)
	health_changed.emit(health, max_health)
	ember_changed.emit(fuel, max_fuel)


## Restyles Vesper and her sword from the equipped gear.
func _apply_look(look: Dictionary) -> void:
	if look.has("scarf"):
		art.scarf_color = look.scarf
	if look.has("mask"):
		art.mask_color = look.mask
	if look.has("cloak"):
		art.cloak_color = look.cloak
		sword.cloak_color = look.cloak
	if look.has("cloak_rim"):
		art.cloak_rim = look.cloak_rim
	if look.has("blade_length"):
		sword.blade_length = look.blade_length
	if look.has("grip"):
		sword.grip_color = look.grip
	if look.has("slash_rim"):
		_slash_rim = look.slash_rim


# ------------------------------------------------------------------- ember

func add_fuel(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, max_fuel)
	ember_changed.emit(fuel, max_fuel)


func glow_radius() -> float:
	return lerpf(glow_radius_empty, glow_radius_full, fuel / max_fuel)


## Light source for drawn things (world25/light.gd): the Ember's glow.
func lights(point: Vector3) -> bool:
	if dead:
		return false
	var d := point - global_position
	return Vector2(d.x, d.z).length() < glow_radius() and absf(d.y) < 3.0


func _flash() -> void:
	if fuel < flash_cost:
		Fx.pop_text(get_tree(), global_position + Vector3(0, 1.8, 0), "fzzt...", Color(0.7, 0.6, 0.5), 24)
		return
	add_fuel(-flash_cost)
	var f := FlashScript.new()
	f.radius *= _flash_radius_mult
	get_tree().current_scene.add_child(f)
	f.global_position = Vector3(global_position.x, ground_height, global_position.z)
	Fx.pop_text(get_tree(), global_position + Vector3(0, 1.9, 0), "FLASH!", Color(1.0, 0.85, 0.45), 34)
	_squash = Vector2(1.2, 0.85)


## Hold heal, standing on the ground, to turn fuel into one ink drop.
func _update_heal(delta: float) -> void:
	var can := Input.is_action_pressed("heal") and is_on_floor() and health < max_health \
		and fuel >= heal_cost and _attack_timer <= 0.0 and _dash_timer <= 0.0
	if not can:
		_channel = -1.0
		return
	_channel = maxf(_channel, 0.0) + delta
	if _channel >= heal_time:
		_channel = -1.0
		add_fuel(-heal_cost)
		health = mini(health + 1, max_health)
		health_changed.emit(health, max_health)
		Fx.pop_text(get_tree(), global_position + Vector3(0, 1.8, 0), "+1", Color(0.6, 1.0, 0.7), 32)
		Fx.burst(get_tree(), global_position + Vector3(0, 0.8, 0), Color(1.0, 0.75, 0.35), 14, 2.5)
		_squash = Vector2(0.85, 1.2)


# ------------------------------------------------------------------ damage

## Touching a harmful monster hurts (jumping over it, or dashing through it,
## avoids that).
func _check_contact_damage() -> void:
	if _invuln > 0.0 or _dash_timer > 0.0:
		return
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.6, 0))
	params.collision_mask = MASK_ENEMY
	for result in get_world_3d().direct_space_state.intersect_shape(params, 8):
		var body: Object = result.collider
		if body and body.has_method("is_harmful") and body.is_harmful():
			take_damage(body.contact_damage, body.global_position)
			return


func take_damage(amount: int, from_pos: Vector3) -> void:
	if dead or _invuln > 0.0 or _dash_timer > 0.0:
		return
	if _seal_ready:
		# Wax-Seal Mantle: the first hit in a room cracks the seal instead
		_seal_ready = false
		_invuln = invuln_time
		Fx.pop_text(get_tree(), global_position + Vector3(0, 1.8, 0), "SEAL CRACKED!", Color(0.95, 0.35, 0.3), 30)
		Fx.burst(get_tree(), global_position + Vector3(0, 0.9, 0), Color(0.8, 0.15, 0.15), 14, 3.0)
		return
	if health - amount <= 0 and _last_drop_ready:
		_last_drop_ready = false
		amount = health - 1
		Fx.pop_text(get_tree(), global_position + Vector3(0, 2.2, 0), "LAST DROP!", Color(0.55, 0.65, 1.0), 34)
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_invuln = invuln_time
	_hurt_timer = 0.2
	_attack_timer = 0.0
	_jumping = false
	var away := global_position - from_pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3(-facing, 0, 0)
	velocity = away * hurt_knockback + Vector3(0, hurt_hop, 0)
	_squash = Vector2(1.3, 0.7)
	Fx.pop_text(get_tree(), global_position + Vector3(0, 1.6, 0), "OOF!", Color(1.0, 0.4, 0.35))
	_hitstop(0.08)
	_shake(0.55)
	if health <= 0:
		_die()


## Remembers solid, permanent ground to come back to after a fall.
func _track_safe_ground(delta: float) -> void:
	_safe_timer -= delta
	if _safe_timer > 0.0 or not is_on_floor():
		return
	_safe_timer = 0.25
	var below := get_last_slide_collision()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.6:
			below = c
	if below and below.get_collider() and below.get_collider().is_in_group("drawn"):
		return  # never respawn on something that can vanish
	_safe_pos = global_position


## Fell through a vanished bridge (or off the world): back to safe ground,
## one ink drop poorer.
func _fell() -> void:
	velocity = Vector3.ZERO
	global_position = _safe_pos
	_snap_visuals()
	if not dead:
		_invuln = 0.0
		take_damage(1, global_position + Vector3(facing, 0, 0))
		velocity = Vector3.ZERO


## Pushed back without damage (a hit bounced off something rubbery).
func bounce_back(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	velocity.x = d.x * 6.0
	velocity.z = d.z * 6.0
	_hurt_timer = 0.12
	_attack_timer = 0.0


func _die() -> void:
	dead = true
	died.emit()
	Fx.splat(get_tree(), global_position, 2.0)
	Fx.pop_text(get_tree(), global_position + Vector3(0, 1.8, 0), "THE END?", Color(0.98, 0.96, 0.9), 40)
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.5)
	await get_tree().create_timer(1.6).timeout
	global_position = _spawn
	velocity = Vector3.ZERO
	health = max_health
	health_changed.emit(health, max_health)
	_invuln = 1.5
	_slow_sources.clear()
	dead = false
	_snap_visuals()
	sprite.modulate.a = 1.0


## Called by slowing things (ink puddles). Multipliers of 1 remove the
## source; overlapping sources use the strongest slow.
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


# ------------------------------------------------------------------ visuals

## Jump the visuals straight to the body (spawn, respawn, teleports).
func _snap_visuals() -> void:
	_prev_tick_pos = global_position
	_tick_pos = global_position
	smooth_position = global_position
	ground_height = global_position.y
	if visual_3d:
		visual_3d.global_position = global_position


func _update_art(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	_flip = move_toward(_flip, facing, flip_speed * 2.0 * delta)
	# ease the flip so it whips through the middle instead of crawling
	var flip_x := signf(_flip) * sqrt(absf(_flip)) if _flip != 0.0 else 0.0
	visual.scale = Vector2(flip_x * _squash.x, _squash.y) * _art_scale
	# The art animates in 2D pixels: map our speed onto the platformer's
	# 300 px/s run so the run cycle and scarf move at the same pace.
	var px_per_unit := ART_RUN_SPEED / max_speed
	var speed := Vector2(velocity.x, velocity.z).length()
	art.velocity = Vector2(speed * facing, 0.0 if is_on_floor() else -velocity.y) * px_per_unit
	art.facing = facing
	art.on_floor = is_on_floor()
	art.dashing = _dash_timer > 0.0
	art.max_speed = ART_RUN_SPEED
	art.stuck = _slow_mult().x < 1.0
	art.charge = clampf(_channel / heal_time, 0.0, 1.0) if _channel >= 0.0 else 0.0
	art.charge_ready = false
	var k := fuel / max_fuel
	ember_light.omni_range = lerpf(2.4, 4.6, k)
	ember_light.light_energy = lerpf(0.55, 1.35, k)
	# whiten as a searchlight erases her; blink while invulnerable
	if not dead:
		# (a dark flicker rather than fading out: the sprite is alpha-cut, so a
		# faded frame would vanish entirely, e.g. if the game pauses on it)
		var w := 1.0 + erase * 1.6
		if _invuln > 0.0 and fmod(_invuln, 0.16) < 0.08:
			w *= 0.45
		sprite.modulate = Color(w, w, w * 1.1, 1.0)
