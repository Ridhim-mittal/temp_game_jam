extends CharacterBody3D
## Top-down (Cult of the Lamb style) controller for the 2.5D clearing.
## Moves on the ground plane with WASD / stick, dashes on Shift / right
## click, attacks on left click / X: a three-hit combo (the third hit is a
## heavier finisher) aimed at the mouse cursor, or along the movement
## direction from the keyboard or a gamepad. The character is the same procedural Vesper art as the platformer
## (player_visual.gd), drawn into a SubViewport and shown on a billboard.
##
## Smoothness:
##  - the body moves on physics ticks, but the visuals ($Visual3D, top
##    level) are interpolated between the last two ticks every frame, so
##    motion stays fluid whatever the screen's refresh rate
##  - turning around squashes the art through zero instead of snapping
##  - constant speed on slopes and floor snapping keep stairs even

const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const ART_RUN_SPEED := 300.0  # player_visual.gd's full-run speed, px/s
const MASK_ENEMY := 4  # physics layer 3
const HIT_WORDS := ["THWACK!", "SLASH!", "POW!", "WHAM!", "SHNK!"]

## How a swing looks. Two versions exist while the team picks one:
##   INK_SLASH  ink crescent swept on the ground (clearing_fx.gd)
##   NIB_SWORD  the platformer's nib-sword swinging on Vesper (sword.gd)
##   BOTH       sword swing plus the ground crescent
## Press T in game to cycle through them.
enum AttackStyle { INK_SLASH, NIB_SWORD, BOTH }
const STYLE_NAMES := ["Ink slash (clearing)", "Nib-sword (platformer)", "Both"]

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

@export_group("Attack")
@export var attack_style := AttackStyle.INK_SLASH
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
## Interpolated position of the visuals; the camera follows this.
var smooth_position := Vector3.ZERO

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

@onready var visual_3d: Node3D = $Visual3D
@onready var sprite: Sprite3D = $Visual3D/Sprite
@onready var art_viewport: SubViewport = $ArtViewport
@onready var visual: Node2D = $ArtViewport/Visual
@onready var art = $ArtViewport/Visual/Art
@onready var sword = $ArtViewport/Visual/Sword
var _style_label: Label

## Size the art is drawn at inside the SubViewport (sharper billboard).
var _art_scale := 2.0


func _ready() -> void:
	Engine.time_scale = 1.0
	add_to_group("player")
	_spawn = global_position
	_art_scale = visual.scale.y
	sprite.texture = art_viewport.get_texture()
	floor_constant_speed = true
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	_snap_visuals()
	Fx.prewarm.call_deferred(get_tree(), global_position)
	_apply_attack_style()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		attack_style = (attack_style + 1) % AttackStyle.size() as AttackStyle
		_apply_attack_style()
		get_viewport().set_input_as_handled()


func _apply_attack_style() -> void:
	var has_sword := attack_style != AttackStyle.INK_SLASH
	sword.visible = has_sword
	sword.set_process(has_sword)
	if _style_label == null:
		var ui := get_tree().current_scene.get_node_or_null("UI")
		if ui == null:
			return
		_style_label = Label.new()
		_style_label.position = Vector2(24, 18)
		_style_label.add_theme_font_size_override("font_size", 18)
		_style_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
		_style_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.13))
		_style_label.add_theme_constant_override("outline_size", 6)
		ui.add_child.call_deferred(_style_label)
	_style_label.text = "Attack style: %s    (T to switch)" % STYLE_NAMES[attack_style]


func _physics_process(delta: float) -> void:
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	var input := Input.get_vector("move_left", "move_right", "up", "down")
	var dir := Vector3(input.x, 0.0, input.y)
	if absf(input.x) > 0.2 and _attack_timer <= 0.0:
		facing = 1 if input.x > 0.0 else -1

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	if Input.is_action_just_pressed("attack"):
		_attack_buffer = attack_buffer_time

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_dash_dir = dir.normalized() if dir != Vector3.ZERO else Vector3(facing, 0, 0)
		_dash_timer = dash_time
		_dash_cooldown_timer = dash_cooldown
		_attack_timer = 0.0  # a dash cancels a swing
		_squash = Vector2(1.3, 0.75)

	if _attack_buffer > 0.0 and _attack_timer <= 0.0 and _dash_timer <= 0.0:
		_start_attack(dir)

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if _attack_timer > 0.0:
		# rooted during a swing: the lunge slides out quickly
		planar = planar.move_toward(Vector3.ZERO, 32.0 * delta)
	elif _dash_timer > 0.0:
		# fast burst that eases out into a run
		var t := 1.0 - _dash_timer / dash_time
		planar = _dash_dir * lerpf(dash_speed, max_speed, t * t)
	elif dir != Vector3.ZERO:
		var target := dir * max_speed
		var rate := accel
		if planar.length() > 0.5 and planar.normalized().dot(dir.normalized()) < 0.3:
			rate = turn_accel
		planar = planar.move_toward(target, rate * delta)
	else:
		planar = planar.move_toward(Vector3.ZERO, decel * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	if is_on_floor() and not _was_on_floor and velocity.y < -3.0:
		_squash = Vector2(1.2, 0.85)
	_was_on_floor = is_on_floor()
	if global_position.y < kill_height:
		global_position = _spawn
		velocity = Vector3.ZERO
		_snap_visuals()
	_prev_tick_pos = _tick_pos
	_tick_pos = global_position


func _process(delta: float) -> void:
	smooth_position = _prev_tick_pos.lerp(_tick_pos, Engine.get_physics_interpolation_fraction())
	visual_3d.global_position = smooth_position
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
		Fx.slash(get_tree(), global_position, dir, _combo == 2, finisher)
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
	var center := global_position + dir * attack_reach
	var radius := attack_radius * (1.25 if finisher else 1.0)
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center + Vector3(0.0, 0.5, 0.0))
	params.collision_mask = MASK_ENEMY
	var hits := 0
	for result in get_world_3d().direct_space_state.intersect_shape(params, 16):
		var target: Object = result.collider
		if target and target.has_method("take_hit") and not ("dead" in target and target.dead):
			target.take_hit(finisher_damage if finisher else attack_damage, dir)
			hits += 1
			var word: String = "KA-POW!" if finisher else HIT_WORDS.pick_random()
			Fx.pop_text(get_tree(), target.global_position + Vector3(0, 1.3, 0), word)
	var cut := 0
	for grass in get_tree().get_nodes_in_group("grass"):
		cut += grass.cut(center, radius * 0.9)
	if cut > 0:
		Fx.burst(get_tree(), center + Vector3(0, 0.3, 0), Color(0.42, 0.62, 0.42), mini(cut * 3, 18), 3.0)
	if hits > 0:
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


## Jump the visuals straight to the body (spawn, respawn, teleports).
func _snap_visuals() -> void:
	_prev_tick_pos = global_position
	_tick_pos = global_position
	smooth_position = global_position
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
