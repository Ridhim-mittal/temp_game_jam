extends Node3D
## The Writer's Lamp as a searchlight (design doc 6.6), for 2.5D rooms.
## The lamp hangs at this node (place it high above the room's far edge);
## its beam lands on a pool of light that:
##  - PATROL       sweeps along `patrol` (x, z points, looping)
##  - INVESTIGATE  goes to where it last saw Vesper, or to a Flash it heard
##  - LOCK_ON      follows Vesper for `lock_time` after spotting her
## Standing in the beam fills the erase meter (Vesper whitens); full = one
## ink drop lost and a shove out of the light. Solid props between the
## lamp and a point cast shadows (light rule 3): hide behind them.
## Monsters caught in the beam react like any Writer's light, and
## crossed-out things are slowly erased (on_searchlight). It also makes
## drawn bridges real.

const Light = preload("res://scripts/world25/light.gd")
const Toon = preload("res://scripts/clearing/toon.gd")
const BEAM_SHADER = preload("res://shaders/world25/beam.gdshader")

enum State { PATROL, INVESTIGATE, LOCK_ON }

## Ground points (x, z) the pool of light loops through.
@export var patrol := PackedVector2Array([Vector2(-6, 0), Vector2(6, 0)])
@export var speed := 3.2
@export var spot_radius := 2.6
@export var lock_time := 3.0
@export var investigate_time := 4.0
## Seconds in the beam to fill / empty the erase meter.
@export var erase_fill := 0.9
@export var erase_drain := 1.5
@export var ground_y := 0.0
## Seconds between erase ticks on monsters in the beam.
@export var monster_tick := 0.6

var state := State.PATROL
## The Writer's light: monsters react to it.
var monster_light := true
var spot := Vector3.ZERO
var erase := 0.0

var _target_i := 0
var _timer := 0.0
var _last_seen := Vector3.ZERO
var _monster_timer := 0.0
var _caption_cd := 0.0
var _spot_mesh: MeshInstance3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _spot_mat: ShaderMaterial
var _light: SpotLight3D


func _ready() -> void:
	add_to_group("light_3d")
	add_to_group("searchlight")
	if patrol.size() > 0:
		spot = Vector3(patrol[0].x, ground_y, patrol[0].y)
	_build()


func _build() -> void:
	# the lamp: green metal shade on an arm, a warm bulb
	var lamp := Node3D.new()
	add_child(lamp)
	Toon.part(lamp, Toon.cylinder(0.25, 1.1, 0.9, 16), Color(0.25, 0.49, 0.41), Vector3.ZERO, Vector3.ZERO, {"outline": 0.06})
	Toon.part(lamp, Toon.cylinder(0.12, 0.12, 6.0, 8), Color(0.18, 0.2, 0.2), Vector3(0, 3.4, 0))
	Toon.part(lamp, Toon.sphere(0.35, 10, 6), Color(1.0, 0.95, 0.75), Vector3(0, -0.45, 0), Vector3.ZERO, {"outline": 0.0, "emission": 2.0})
	_light = SpotLight3D.new()
	_light.light_color = Color(1.0, 0.94, 0.78)
	_light.light_energy = 9.0
	_light.shadow_enabled = true
	_light.spot_attenuation = 0.4
	add_child(_light)
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM_SHADER
	_beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 24
	cone.cap_top = false
	cone.cap_bottom = false
	_beam.mesh = cone
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)
	_spot_mat = ShaderMaterial.new()
	_spot_mat.shader = BEAM_SHADER
	_spot_mat.set_shader_parameter("mode", 1)
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(spot_radius * 2.0, spot_radius * 2.0)
	_spot_mesh = MeshInstance3D.new()
	_spot_mesh.mesh = q
	_spot_mesh.material_override = _spot_mat
	_spot_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spot_mesh.top_level = true
	add_child(_spot_mesh)


## Light rule: inside the pool and not in a shadow.
func lights(point: Vector3) -> bool:
	var d := Vector2(point.x - spot.x, point.z - spot.z)
	if d.length() > spot_radius:
		return false
	return not Light.blocked(get_world_3d(), global_position + Vector3(0, -0.6, 0), point + Vector3(0, 0.4, 0))


## A Flash makes noise: come and look.
func hear(at: Vector3) -> void:
	if state == State.LOCK_ON:
		return
	_last_seen = Vector3(at.x, ground_y, at.z)
	state = State.INVESTIGATE
	_timer = investigate_time
	_say("Where did you go?")


func _physics_process(delta: float) -> void:
	_caption_cd -= delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var seen: bool = player != null and not player.dead and lights(player.global_position)
	match state:
		State.PATROL:
			if patrol.size() > 0:
				_target_i %= patrol.size()  # the route may have been edited
				var goal := Vector3(patrol[_target_i].x, ground_y, patrol[_target_i].y)
				spot = spot.move_toward(goal, speed * delta)
				if spot.distance_to(goal) < 0.1:
					_target_i = (_target_i + 1) % patrol.size()
		State.INVESTIGATE:
			spot = spot.move_toward(_last_seen, speed * 1.2 * delta)
			_timer -= delta
			if _timer <= 0.0:
				state = State.PATROL
		State.LOCK_ON:
			if player and not player.dead:
				var goal := Vector3(player.global_position.x, ground_y, player.global_position.z)
				spot = spot.move_toward(goal, speed * 1.35 * delta)
			_timer -= delta
			if seen:
				_timer = lock_time
				_last_seen = Vector3(player.global_position.x, ground_y, player.global_position.z)
			elif _timer <= 0.0:
				state = State.INVESTIGATE
				_timer = investigate_time
	if seen and state != State.LOCK_ON:
		state = State.LOCK_ON
		_timer = lock_time
		_say("There.")
	_update_erase(player, seen, delta)
	_erase_monsters(delta)


func _update_erase(player: Node3D, seen: bool, delta: float) -> void:
	if player == null:
		return
	if seen:
		erase = minf(erase + delta / erase_fill, 1.0)
	else:
		erase = maxf(erase - delta / erase_drain, 0.0)
	if "erase" in player:
		player.erase = maxf(player.erase if player.erase_source != self else 0.0, erase)
		if erase > 0.0:
			player.erase_source = self
	if erase >= 1.0 and player.has_method("take_damage"):
		erase = 0.0
		player._invuln = 0.0
		player.take_damage(1, Vector3(spot.x, player.global_position.y, spot.z))
		_say("Out. OUT.")


func _erase_monsters(delta: float) -> void:
	_monster_timer -= delta
	if _monster_timer > 0.0:
		return
	_monster_timer = monster_tick
	for m in get_tree().get_nodes_in_group("enemy"):
		if m is Node3D and m.has_method("on_searchlight") and not m.dead and lights(m.global_position):
			m.on_searchlight(1)


func _say(text: String) -> void:
	if _caption_cd > 0.0:
		return
	_caption_cd = 6.0
	var ui = get_tree().current_scene.get("ui") if get_tree().current_scene else null
	if ui and ui.has_method("caption"):
		ui.caption(text, "shaky")


func _process(_delta: float) -> void:
	var from := global_position + Vector3(0, -0.5, 0)
	var to := spot + Vector3(0, 0.05, 0)
	var dist := from.distance_to(to)
	# cone from the lamp to the pool
	var mid := (from + to) * 0.5
	var up := (from - to).normalized()
	var side := up.cross(Vector3.FORWARD).normalized() if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var basis := Basis(side, up, side.cross(up)).orthonormalized()
	_beam.global_transform = Transform3D(basis.scaled(Vector3(spot_radius, dist, spot_radius)), mid)
	_spot_mesh.global_position = Vector3(spot.x, ground_y + 0.04, spot.z)
	_light.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	_light.spot_range = dist + 3.0
	_light.spot_angle = rad_to_deg(atan2(spot_radius * 1.15, dist))
	var alarm := 1.0 if state == State.LOCK_ON else (0.4 if state == State.INVESTIGATE else 0.0)
	_beam_mat.set_shader_parameter("alarm", alarm)
	_spot_mat.set_shader_parameter("alarm", alarm)
