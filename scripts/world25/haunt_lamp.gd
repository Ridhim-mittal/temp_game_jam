extends "res://scripts/world25/searchlight.gd"
## The Writer's Haunting Lamp: in every Gutter room (room.gd spawns it from
## the biome's HauntProfile), hunting Vesper. A pure white column of light
## comes down out of the dark onto a circle of the Writer's proofreading
## marks. Built on searchlight.gd, so it shares its erase meter (standing in
## the light whitens Vesper; a full meter costs an ink drop), its shadow
## rays (solid props between the lamp and a point block it: hide behind
## them), the Flash investigation (`hear`), erasing monsters it catches and
## lighting drawn bridges. The light comes down at a slant from the back of
## the room (SOURCE_DIR), so props throw their shadows towards the camera.
##
## States:
##   DORMANT  grace on entering a room; the column glows far away
##   SEEK     the circle drifts to where it last saw Vesper
##   MARK     it locks a target circle on him; the outline fills clockwise
##   STRIKE   the column slams down there (screen shake): Vesper inside gets
##            a big jump on his erase meter, monsters inside are erased
##   LINGER   the column stays a moment, sweeping slowly, then SEEK
##   LOST     he stayed out of its light long enough: it wanders until it
##            sees him again (or hears a Flash)
## Fairness: no strikes during transitions, pauses or boss intros
## (room.haunt_hold()); one telegraph per lamp; a strike never lands
## without its full telegraph (MARK always lasts `telegraph` seconds).

signal hunt_changed(state: int)

const COLUMN_SHADER = preload("res://shaders/world25/haunt_column.gdshader")
const CIRCLE_SHADER = preload("res://shaders/world25/haunt_circle.gdshader")
## Where the light comes from, seen from the circle: up, a little towards
## the back of the room.
const SOURCE_DIR := Vector3(0.12, 1.0, -0.42)
const SOURCE_DIST := 18.0
const WHITE := Color(1, 1, 1)

enum Hunt { DORMANT, SEEK, MARK, STRIKE, LINGER, LOST }

## The profile (haunt_profile.gd) and the scaling room.gd works out from the
## difficulty setting and the room's haunt_scale.
var profile: Resource
var speed_scale := 1.0
var telegraph_scale := 1.0
var strike_scale := 1.0
## Which of the room's lamps this is (staggers their strikes).
var index := 0
## Ground rectangle (x, z) the circle stays inside.
var roam := Rect2(-10, -8, 20, 16)

var hunt := Hunt.DORMANT
var last_known := Vector3.ZERO
var mark := Vector3.ZERO
## [seconds since spawn, state] for every change (tests read this).
var history: Array = []

var _t := 0.0
var _age := 0.0
var _strike_t := 0.0
var _unseen := 0.0
var _wander := Vector3.ZERO
var _flash := 0.0
var _column: MeshInstance3D
var _column_mat: ShaderMaterial
var _circle_mat: ShaderMaterial
var _circle: MeshInstance3D
var _mark_mat: ShaderMaterial
var _mark_circle: MeshInstance3D
var _base_light: OmniLight3D
var _motes: CPUParticles3D


func _ready() -> void:
	add_to_group("light_3d")
	add_to_group("searchlight")
	add_to_group("haunt_lamp")
	if profile == null:
		profile = load("res://data/haunt/inkwood.tres")
	spot_radius = profile.circle_radius
	erase_fill = profile.erase_fill
	erase_drain = maxf(profile.erase_fill * 1.4, 1.0)
	spot.y = ground_y
	last_known = spot
	_strike_t = _strike_every() * (1.0 + 0.5 * index)
	_wander = spot
	_build()
	_set_hunt(Hunt.DORMANT)
	global_position = spot + SOURCE_DIR.normalized() * SOURCE_DIST


func _strike_every() -> float:
	return profile.strike_every / maxf(strike_scale, 0.1)


func _speed() -> float:
	return profile.seek_speed * speed_scale


func _telegraph() -> float:
	return profile.telegraph * telegraph_scale


func _build() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 24
	cyl.rings = 4
	cyl.cap_top = false
	cyl.cap_bottom = false
	_column_mat = ShaderMaterial.new()
	_column_mat.shader = COLUMN_SHADER
	_column = MeshInstance3D.new()
	_column.mesh = cyl
	_column.material_override = _column_mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.top_level = true
	add_child(_column)
	_circle_mat = _circle_material()
	_circle = _flat_circle(_circle_mat)
	_mark_mat = _circle_material()
	_mark_mat.set_shader_parameter("pool", 0.08)
	_mark_mat.set_shader_parameter("spin", -0.3)
	_mark_circle = _flat_circle(_mark_mat)
	_mark_circle.visible = false
	_base_light = OmniLight3D.new()
	_base_light.light_color = WHITE
	_base_light.omni_range = spot_radius * 2.4
	_base_light.top_level = true
	add_child(_base_light)
	# dust rising inside the column
	_motes = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.vertex_color_use_as_albedo = true
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mm
	_motes.mesh = q
	_motes.amount = 28
	_motes.lifetime = 2.6
	_motes.preprocess = 2.6
	_motes.local_coords = false
	_motes.top_level = true
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = spot_radius * 0.7
	_motes.direction = SOURCE_DIR.normalized()
	_motes.spread = 8.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 0.6
	_motes.initial_velocity_max = 1.6
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.2, 0.7, 1])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	_motes.color_ramp = g
	add_child(_motes)


func _circle_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CIRCLE_SHADER
	return m


func _flat_circle(mat: ShaderMaterial) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(spot_radius * 2.4, spot_radius * 2.4)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	return mi


func _set_hunt(state: int) -> void:
	hunt = state
	_t = 0.0
	history.append([_age, state])
	hunt_changed.emit(state)


## A Flash makes noise: the lamp comes to look, even if it had lost him.
func hear(at: Vector3) -> void:
	if hunt in [Hunt.DORMANT, Hunt.MARK, Hunt.STRIKE, Hunt.LINGER]:
		return
	last_known = Vector3(at.x, ground_y, at.z)
	_unseen = 0.0
	_set_hunt(Hunt.SEEK)


## In its light, or close enough to it (the halo round the circle) and not
## hidden behind something solid.
func sees(point: Vector3) -> bool:
	var d := Vector2(point.x - spot.x, point.z - spot.z)
	if d.length() > spot_radius * 2.2:
		return false
	return not Light.blocked(get_world_3d(), global_position + Vector3(0, -0.6, 0), point + Vector3(0, 0.6, 0))


func _held() -> bool:
	var room := get_tree().current_scene
	return room != null and room.has_method("haunt_hold") and room.haunt_hold()


func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_y, p.z)


func _clamp_roam(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, roam.position.x, roam.end.x), ground_y, clampf(p.z, roam.position.y, roam.end.y))


func _physics_process(delta: float) -> void:
	_caption_cd -= delta
	_age += delta
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var alive: bool = player != null and not player.dead
	var hold := _held()
	match hunt:
		Hunt.DORMANT:
			if _t >= profile.grace and not hold:
				if alive:
					last_known = _flat(player.global_position)
				_set_hunt(Hunt.SEEK)
		Hunt.SEEK:
			if alive and sees(player.global_position):
				last_known = _flat(player.global_position)
				_unseen = 0.0
			else:
				_unseen += delta
			spot = spot.move_toward(_clamp_roam(last_known), _speed() * delta)
			if _unseen >= profile.lose_after:
				_set_hunt(Hunt.LOST)
				_wander = spot
				_line(profile.say_on_lost)
			elif profile.strike_every > 0.0 and alive and not hold:
				_strike_t -= delta
				if _strike_t <= 0.0 and _unseen < 0.3 and Vector2(spot.x - player.global_position.x, spot.z - player.global_position.z).length() < spot_radius * 3.0:
					mark = _clamp_roam(player.global_position)
					_set_hunt(Hunt.MARK)
					_line(profile.say_on_spot)
		Hunt.MARK:
			# the pool slides onto the marked circle while its outline fills
			spot = spot.move_toward(mark, _speed() * 2.5 * delta)
			if hold:
				_strike_t = _strike_every() * 0.5  # never strike out of a cutscene
				_set_hunt(Hunt.SEEK)
			elif _t >= _telegraph():
				_strike()
		Hunt.LINGER:
			if alive:
				spot = spot.move_toward(_clamp_roam(player.global_position), _speed() * 0.3 * delta)
			if _t >= profile.linger:
				_strike_t = _strike_every()
				_unseen = 0.0
				_set_hunt(Hunt.SEEK)
		Hunt.LOST:
			if spot.distance_to(_wander) < 0.3:
				_wander = Vector3(randf_range(roam.position.x, roam.end.x), ground_y, randf_range(roam.position.y, roam.end.y))
			spot = spot.move_toward(_wander, _speed() * 0.6 * delta)
			if alive and sees(player.global_position):
				last_known = _flat(player.global_position)
				_unseen = 0.0
				_set_hunt(Hunt.SEEK)
				_line(profile.say_on_spot)
	global_position = spot + SOURCE_DIR.normalized() * SOURCE_DIST
	var in_light: bool = alive and hunt != Hunt.DORMANT and lights(player.global_position)
	_update_erase(player, in_light, delta)
	if hunt != Hunt.DORMANT:
		_erase_monsters(delta)


func _strike() -> void:
	spot = mark
	global_position = spot + SOURCE_DIR.normalized() * SOURCE_DIST
	_set_hunt(Hunt.STRIKE)
	_flash = 1.0
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.55)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and not player.dead and lights(player.global_position):
		erase = minf(erase + profile.strike_erase, 1.0)
	for m in get_tree().get_nodes_in_group("enemy"):
		if m is Node3D and not ("dead" in m and m.dead) and lights(m.global_position):
			if m.has_method("on_searchlight"):
				m.on_searchlight(2)
			elif m.has_method("take_hit"):
				var away: Vector3 = m.global_position - spot
				m.take_hit(2, away.normalized() if away.length() > 0.01 else Vector3.RIGHT, false)
	_line(profile.say_on_strike)
	_set_hunt(Hunt.LINGER)


## The searchlight's meter, but a profile that can't damage only whitens.
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
	if erase >= 1.0:
		if profile.can_damage and player.has_method("take_damage") and not player.dead:
			erase = 0.0
			player._invuln = 0.0
			player.take_damage(1, Vector3(spot.x, player.global_position.y, spot.z))
			_line("Out. OUT.")
		else:
			erase = 0.92


## Each of the Writer's lines plays once per room at most.
func _line(text: String) -> void:
	if text == "":
		return
	var world := get_node_or_null("/root/World25")
	var room := get_tree().current_scene
	var key := "%s:haunt:%s" % [room.get("room_id") if room else "", text]
	if world and not world.once(key):
		return
	var ui = room.get("ui") if room else null
	if ui and ui.has_method("caption"):
		ui.caption(text, "shaky")


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 1.6, 0.0)
	var dir := SOURCE_DIR.normalized()
	var length := 22.0
	var basis := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(spot_radius * 0.82, length, spot_radius * 0.82))
	_column.global_transform = Transform3D(basis, spot + dir * length * 0.5)
	var level: float = {Hunt.DORMANT: 0.22, Hunt.SEEK: 0.42, Hunt.MARK: 0.5, Hunt.STRIKE: 1.0, Hunt.LINGER: 0.75, Hunt.LOST: 0.3}[hunt]
	var telegraph: float = clampf(_t / maxf(_telegraph(), 0.01), 0.0, 1.0) if hunt == Hunt.MARK else 0.0
	_column_mat.set_shader_parameter("intensity", level + _flash * 1.2 + telegraph * 0.2)
	_circle.global_position = spot + Vector3(0, 0.05, 0)
	_circle_mat.set_shader_parameter("intensity", 0.45 + level * 0.5 + _flash)
	_mark_circle.visible = hunt == Hunt.MARK
	_mark_circle.global_position = mark + Vector3(0, 0.06, 0)
	_mark_mat.set_shader_parameter("fill", telegraph)
	_mark_mat.set_shader_parameter("intensity", 0.5 + telegraph * 0.5)
	_base_light.global_position = spot + Vector3(0, 1.8, 0)
	_base_light.light_energy = 0.8 + level * 1.4 + _flash * 5.0
	_motes.global_position = spot + dir * 1.5
