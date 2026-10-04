extends "res://scripts/clearing/monster_3d.gd"
## Dive-bomber Scribble: the platformer's flying Scribble
## (scripts/enemies/scribble.gd) in the 2.5D world, drawn with its own art.
## Hovers above its spot, shakes, then dives at where the player was;
## climbs back up after a dive or a hit. Light makes it shriek and flee.
## Only the dive hurts. Weak (2 hits); attack it as it dives, or jump.
## Chosen over the hopping Scribble in Settings (scribble.gd swaps itself).

enum State { HOVER, AIM, DIVE, RISE, FLEE }  # same order as the 2D art

@export var hover_height := 1.3
@export var dive_speed := 9.0
@export var dive_cooldown := 1.6
@export var aim_time := 0.45

var state := State.HOVER
var _timer := 0.0
var _cooldown := 0.8
var _dir := Vector3.DOWN
var _ground_y := 0.0
var _shadow: MeshInstance3D


func _ready() -> void:
	hp = 2
	flying = true
	knockback = 5.0
	_ground_y = global_position.y
	global_position.y += hover_height
	setup_monster("res://scenes/enemies/scribble.tscn", 160, 30)
	_home = global_position
	_cooldown = randf_range(0.3, 1.5)
	_add_shadow()


func _add_shadow() -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(0.9, 0.9)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/clearing/blob_shadow.gdshader")
	mat.set_shader_parameter("strength", 0.35)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = q
	_shadow.material_override = mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	var light := light_at(global_position)
	if light and state != State.FLEE:
		_dir = global_position - light.global_position
		_dir.y = 0.0
		_dir = _dir.normalized() if _dir.length() > 0.01 else Vector3.RIGHT
		state = State.FLEE
		_timer = 1.2
		pop("SKREE!", PALE, 1.2, 22)
	match state:
		State.HOVER:
			var target := _home + Vector3(sin(time * 1.3) * 1.2, sin(time * 2.1) * 0.25, cos(time * 0.9) * 0.6)
			velocity = (target - global_position) * 3.0
			if sees_player() and _cooldown <= 0.0:
				face_dir(to_player())
				state = State.AIM
				_timer = aim_time
		State.AIM:
			velocity *= 0.85
			face_dir(to_player())
			if _timer <= 0.0:
				var aim := (_player.global_position + Vector3(0, 0.5, 0)) if _player else global_position + Vector3.DOWN
				_dir = (aim - global_position).normalized()
				state = State.DIVE
				_timer = 0.6
		State.DIVE:
			velocity = _dir * dive_speed
			if _timer <= 0.0 or global_position.y < _ground_y + 0.35 or get_slide_collision_count() > 0:
				state = State.RISE
				_cooldown = dive_cooldown
		State.RISE:
			var back := _home - global_position
			velocity = velocity.move_toward(back.limit_length(1.0) * 4.0, 18.0 * delta)
			if back.length() < 0.4:
				state = State.HOVER
		State.FLEE:
			velocity = _dir * 5.0
			if _timer <= 0.0:
				_home = Vector3(global_position.x, _ground_y + hover_height, global_position.z)
				state = State.HOVER
				_cooldown = 1.0


func _process(delta: float) -> void:
	super(delta)
	if _shadow:
		_shadow.visible = not dead
		_shadow.global_position = Vector3(global_position.x, _ground_y + 0.03, global_position.z)


func on_flash(from: Vector3) -> void:
	if dead:
		return
	_dir = global_position - from
	_dir.y = 0.0
	_dir = _dir.normalized() if _dir.length() > 0.01 else Vector3.RIGHT
	state = State.FLEE
	_timer = 1.4
	pop("SKREE!", PALE, 1.2, 22)


func is_harmful() -> bool:
	return super() and state == State.DIVE


func _on_hurt() -> void:
	state = State.RISE
	_cooldown = dive_cooldown


func _on_respawn() -> void:
	state = State.HOVER
	global_position = _home


func _sync_puppet() -> void:
	puppet.figure.state = state
