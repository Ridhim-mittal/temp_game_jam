@tool
extends Node3D
## Root of a 2.5D room. Put islands, props, gates (gate.gd) and an
## "Enemies" node with monsters under it; this script supplies the rest at
## runtime: environment, sun, drifting motes, player, camera, HUD, minimap,
## story text and music, all from `biome`.
##
## Gates stay sealed until every monster under "Enemies" is beaten; then
## they open and the room is remembered as cleared (World25).
##
## Two biomes: set `biome_b` and the blend line; the islands take B's look
## past the wavy seam, and the light and air shift as the player walks
## across.

const PLAYER_SCENE = preload("res://scenes/clearing/clearing_player.tscn")
const CameraScript = preload("res://scripts/clearing/clearing_camera.gd")
const HudScript = preload("res://scripts/clearing/clearing_hud.gd")
const MinimapScript = preload("res://scripts/world25/minimap.gd")
const StoryUI = preload("res://scripts/world25/story_ui.gd")
const ClearingFX = preload("res://scripts/clearing/clearing_fx.gd")
const OVERLAY_SHADER = preload("res://shaders/comic_overlay.gdshader")
const RectScript = preload("res://scripts/background/screen_shader_rect.gd")
const DEFAULT_BIOME = preload("res://data/biomes/darkwood.tres")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const SkillTree = preload("res://scripts/ui/skill_tree.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const HauntLamp = preload("res://scripts/world25/haunt_lamp.gd")

@export var room_id := "room"
@export var biome: Resource:
	set(v):
		biome = v
		_push_biomes()
## Position on the minimap (x right, y up the screen = away from camera).
@export var map_cell := Vector2i.ZERO
@export var camera_bounds := Rect2(-10, -8, 20, 16)
## Where the player starts when not arriving through a gate.
@export var default_spawn := Vector3(0, 0.05, 0)

@export_group("Story")
## Big title shown on entering (defaults to the biome's name).
@export var title := ""
@export var subtitle := ""
## Writer captions shown the first time the room is entered ("|" splits,
## a leading "~" makes a line shaky).
@export_multiline var enter_captions := ""
## Writer captions shown when the last monster falls ("|" splits).
@export_multiline var clear_captions := ""
## Played after the room is cleared (e.g. the ending); "" = nothing.
@export_file("*.tscn") var cutscene_on_clear := ""
## A monster under "Enemies" shown with a big health bar (boss fights).
@export var boss_path: NodePath
@export var boss_name := ""

@export_group("The Writer's lamp")
## Spawn the Haunting Lamp(s) from the biome's HauntProfile.
@export var haunt_enabled := true
## This room's lamp is a bit harder (> 1) or easier: scales how fast it
## moves and how often it strikes. Set per room by the generator.
@export var haunt_scale := 1.0

@export_group("Blend into another biome")
@export var biome_b: Resource:
	set(v):
		biome_b = v
		_push_biomes()
@export var blend_from := Vector2(0, 0):
	set(v):
		blend_from = v
		_push_biomes()
@export var blend_to := Vector2(10, 0):
	set(v):
		blend_to = v
		_push_biomes()

var player: CharacterBody3D
var ui: Control

var _env: Environment
var _sun: DirectionalLight3D
var _motes: CPUParticles3D
var _cleared := false
var _overlay: Control
var _check_timer := 0.0
var _music_b := false


func _ready() -> void:
	_push_biomes()
	if Engine.is_editor_hint():
		return
	var world := get_node_or_null("/root/World25")
	var b := _biome()
	if world:
		world.enter_room(room_id, map_cell, b.base, title if title != "" else b.display_name)
	_build_environment()
	_build_ui()
	_spawn_player(world)
	_build_camera()
	_spawn_haunt()
	_play_music(b.music)
	_prepare_enemies(world)
	ui.title_card((title if title != "" else b.display_name).to_upper(), subtitle)
	var boss := get_node_or_null(boss_path)
	if boss and not (world and world.is_cleared(room_id)):
		ui.set_boss(boss, boss_name)
	if enter_captions != "" and (world == null or world.once(room_id + ":enter")):
		_captions(enter_captions)
	Tutorial.start(self, player, "25d", ui)  # first run only; waits for the captions


## "|" separates captions; a leading "~" makes one shaky (the Writer
## losing their nerve).
func _captions(text: String) -> void:
	for line in text.split("|"):
		line = line.strip_edges()
		if line.begins_with("~"):
			ui.caption(line.substr(1).strip_edges(), "shaky")
		elif line != "":
			ui.caption(line)


func _biome() -> Resource:
	return biome if biome else DEFAULT_BIOME


## Gives every island and grass field in the room this room's biome(s),
## unless it set its own. Runs in the editor too, so rooms preview right.
func _push_biomes() -> void:
	if not is_inside_tree():
		return
	var targets := []
	for n in find_children("*", "Node3D", true, false):
		# island.gd (contains) and grass_field.gd (cut) take biomes
		if (n.has_method("contains") or n.has_method("cut")) and "biome" in n:
			targets.append(n)
	for n in targets:
		if is_instance_valid(n):
			_assign(n)


func _assign(n: Node) -> void:
	if n.get_meta("own_biome", false):
		return
	if n.biome != _biome():
		n.biome = _biome()
	if n.biome_b != biome_b:
		n.biome_b = biome_b
	if biome_b:
		n.blend_from = blend_from
		n.blend_to = blend_to


# ------------------------------------------------------------------ build

func _build_environment() -> void:
	var b := _biome()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 1.0
	_env.fog_enabled = true
	_env.fog_density = 0.0
	_env.fog_height = -1.5
	_env.fog_height_density = 0.35
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.transform = Transform3D(Basis(Vector3(0.866, 0, -0.5), Vector3(-0.354, 0.707, -0.612), Vector3(0.354, 0.707, 0.612)), Vector3(0, 12, 0))
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)
	_motes = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.vertex_color_use_as_albedo = true
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mm
	_motes.mesh = q
	_motes.amount = 70
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var c := camera_bounds.get_center()
	_motes.position = Vector3(c.x, 1.5, c.y)
	_motes.emission_box_extents = Vector3(camera_bounds.size.x * 0.5 + 4.0, 1.5, camera_bounds.size.y * 0.5 + 3.0)
	_motes.direction = Vector3(0.3, 1, 0)
	_motes.spread = 60.0
	_motes.gravity = Vector3(0, 0.02, 0)
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.25
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.2, 0.8, 1])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	_motes.color_ramp = g
	add_child(_motes)
	_apply_air(b, b, 0.0)


## Light, air and motes, mixed between two biomes (t = 0 -> a, 1 -> b).
func _apply_air(a: Resource, b: Resource, t: float) -> void:
	_env.background_color = a.background.lerp(b.background, t)
	_env.ambient_light_color = a.ambient.lerp(b.ambient, t)
	_env.ambient_light_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	_env.fog_light_color = a.fog.lerp(b.fog, t)
	_sun.light_color = a.sun.lerp(b.sun, t)
	_sun.light_energy = lerpf(a.sun_energy, b.sun_energy, t)
	_motes.color = a.motes.lerp(b.motes, t)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = OVERLAY_SHADER
	mat.set_shader_parameter("vignette_start", 0.78)
	mat.set_shader_parameter("vignette_strength", _biome().vignette)
	mat.set_shader_parameter("edge_darkness", _biome().edge_darkness)
	overlay.material = mat
	overlay.set_script(RectScript)
	layer.add_child(overlay)
	var hud := Control.new()
	hud.set_script(HudScript)
	layer.add_child(hud)
	var minimap := Control.new()
	minimap.set_script(MinimapScript)
	layer.add_child(minimap)
	ui = Control.new()
	ui.set_script(StoryUI)
	layer.add_child(ui)


func _spawn_player(world: Node) -> void:
	var at := default_spawn
	var face := Vector3(0, 0, 1)  # towards the camera
	if world and world.entry_gate != "":
		for g in get_tree().get_nodes_in_group("gate"):
			if is_ancestor_of(g) and g.gate_id == world.entry_gate:
				at = g.arrival_point()
				face = g.global_basis.z  # walked in through it: face into the room
				break
	player = PLAYER_SCENE.instantiate()
	player.position = at
	face.y = 0.0
	if face.length() > 0.01:
		player.facing_dir = face.normalized()
	add_child(player)
	if world and world.player_health > 0:
		player.health = world.player_health
		player.health_changed.emit(player.health, player.max_health)
	if world and world.player_fuel >= 0.0:
		player.fuel = world.player_fuel
		player.ember_changed.emit(player.fuel, player.max_fuel)
	player._invuln = 1.2  # a moment of grace while the ink wipe clears
	if world and "arrive_from_sky" in world and world.arrive_from_sky > 0.0:
		# fell out of a 2D panel: drop in from above, land with a thud
		player.position.y += world.arrive_from_sky
		player._invuln = 2.5
		world.arrive_from_sky = 0.0
		_land_from_sky()


## The Writer's Haunting Lamp(s) (haunt_lamp.gd), scaled by the difficulty
## setting and this room's haunt_scale, starting far from the player.
func _spawn_haunt() -> void:
	var prof: Resource = _biome().haunt
	if not haunt_enabled or prof == null or prof.lamps <= 0:
		return
	var settings := get_node_or_null("/root/Settings")
	var diff: String = settings.get_value("difficulty") if settings else "normal"
	var speed: float = {"relaxed": 0.75, "normal": 1.0, "hard": 1.25}.get(diff, 1.0)
	var tele: float = {"relaxed": 1.3, "normal": 1.0, "hard": 0.8}.get(diff, 1.0)
	var roam := camera_bounds.grow_individual(3.5, 2.5, 3.5, 2.5)
	var taken: Array[Vector3] = [player.global_position]
	for i in prof.lamps:
		var lamp := HauntLamp.new()
		lamp.name = "HauntLamp%d" % (i + 1)
		lamp.profile = prof
		lamp.index = i
		lamp.roam = roam
		lamp.speed_scale = speed * haunt_scale
		lamp.strike_scale = haunt_scale
		lamp.telegraph_scale = tele
		lamp.spot = _far_point(roam, taken)
		taken.append(lamp.spot)
		add_child(lamp)


## The point of `r` (corners and edge middles) farthest from all of `from`:
## a lamp never starts on the player's arrival point.
func _far_point(r: Rect2, from: Array[Vector3]) -> Vector3:
	var best := Vector3(r.get_center().x, 0.0, r.get_center().y)
	var best_d := -1.0
	for fx in [0.0, 0.5, 1.0]:
		for fz in [0.0, 0.5, 1.0]:
			var p := Vector3(r.position.x + r.size.x * fx, 0.0, r.position.y + r.size.y * fz)
			var d := INF
			for f in from:
				d = minf(d, Vector2(p.x - f.x, p.z - f.z).length())
			if d > best_d:
				best_d = d
				best = p
	return best


## True while the lamps must hold their strikes: an ink-wipe transition, a
## paused game, a dead Vesper, or a boss room's intro captions.
func haunt_hold() -> bool:
	var world := get_node_or_null("/root/World25")
	if world and world.transitioning:
		return true
	if get_tree().paused or player == null or player.dead:
		return true
	return not boss_path.is_empty() and not _cleared and ui != null and ui.busy()


func _land_from_sky() -> void:
	await get_tree().physics_frame
	while is_instance_valid(player) and not player.is_on_floor():
		await get_tree().physics_frame
	if not is_instance_valid(player):
		return
	player._squash = Vector2(1.45, 0.6)
	player._shake(0.8)
	ClearingFX.pop_text(get_tree(), player.global_position + Vector3(0, 1.4, 0), "THUD!", Color(0.98, 0.95, 0.85), 40)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.set_script(CameraScript)
	cam.fov = 38.0
	cam.bounds = camera_bounds
	var c := camera_bounds.get_center()
	cam.warmup_focus = Vector3(c.x, 0.0, c.y)
	cam.warmup_distance = maxf(camera_bounds.size.x, camera_bounds.size.y) * 1.6 + 14.0
	cam.current = true
	cam.target_path = NodePath("../" + player.name)
	add_child(cam)


func _play_music(track: String) -> void:
	var music := get_node_or_null("/root/Music")
	if music and track != "":
		music.play(track)


func _prepare_enemies(world: Node) -> void:
	var enemies := get_node_or_null("Enemies")
	var done: bool = world != null and world.is_cleared(room_id)
	if enemies:
		for m in enemies.get_children():
			if done:
				m.queue_free()
			elif "respawn_time" in m:
				m.respawn_time = 0.0  # beaten monsters stay down in story rooms
	if done or enemies == null or enemies.get_child_count() == 0:
		_cleared = true
		for g in _gates():
			g.open(false)


func _gates() -> Array:
	var out := []
	for g in get_tree().get_nodes_in_group("gate"):
		if is_ancestor_of(g):
			out.append(g)
	return out


# --------------------------------------------------------------- overlays

## True while the room is being played: no menu open over it. World25
## hides the mouse cursor while this holds (and the tree isn't paused).
func in_gameplay() -> bool:
	return not Engine.is_editor_hint() and _overlay == null and is_inside_tree()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()  # pause here instead of leaving
		open_overlay("pause")


## Opens a full-screen menu over the room and pauses the game:
## "pause", "skills" or "settings". (The Gutter has no shop: shop.gd and
## catalog.gd stay in the project, unused.)
func open_overlay(action: String) -> void:
	if _overlay != null or player == null or player.dead:
		return
	var layer := get_node("UI")
	match action:
		"pause":
			_overlay = Control.new()
			_overlay.set_script(PauseMenu)
			_overlay.chosen.connect(_on_pause_choice)
		"skills":
			_overlay = Control.new()
			_overlay.set_script(SkillTree)
			_overlay.closed.connect(_on_overlay_closed)
		"settings":
			_overlay = Control.new()
			_overlay.set_script(SettingsMenu)
			_overlay.overlay = true
			_overlay.closed.connect(_on_overlay_closed)
		_:
			return
	layer.add_child(_overlay)
	get_tree().paused = true


func _on_overlay_closed() -> void:
	_overlay = null
	get_tree().paused = false
	if player:
		player.refresh_loadout()


func _on_pause_choice(action: String) -> void:
	var menu := _overlay
	_overlay = null
	menu.queue_free()
	match action:
		"resume":
			_on_overlay_closed()
		"skills", "settings":
			get_tree().paused = false
			open_overlay(action)
		"menu":
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ------------------------------------------------------------------- live

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	if biome_b:
		var d := blend_to - blend_from
		var p := Vector2(player.global_position.x, player.global_position.z)
		var t := clampf((p - blend_from).dot(d) / d.length_squared(), 0.0, 1.0)
		t = smoothstep(0.3, 0.7, t)
		_apply_air(_biome(), biome_b, t)
		if (t > 0.5) != _music_b:
			_music_b = t > 0.5
			_play_music(biome_b.music if _music_b else _biome().music)
	if _cleared:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.25
	var enemies := get_node_or_null("Enemies")
	if enemies:
		for m in enemies.get_children():
			if not ("dead" in m and m.dead):
				return
	_on_cleared()


func _on_cleared() -> void:
	_cleared = true
	var world := get_node_or_null("/root/World25")
	if world:
		world.mark_cleared(room_id)
	var profile := get_node_or_null("/root/Profile")
	if profile:
		var pts: int = profile.record_clear(room_id)
		if pts > 0:
			ui.toast("+%d INK POINT%s   ESC: SKILL TREE" % [pts, "" if pts == 1 else "S"])
	var i := 0
	for g in _gates():
		get_tree().create_timer(0.25 * i).timeout.connect(g.open)
		i += 1
	if clear_captions != "":
		_captions(clear_captions)
	if cutscene_on_clear != "" and world:
		await get_tree().create_timer(4.5).timeout
		world.play_cutscene(cutscene_on_clear)
