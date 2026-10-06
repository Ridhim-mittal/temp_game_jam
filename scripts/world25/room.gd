@tool
extends Node3D
## Root of a 2.5D room. Put islands, props, gates (gate.gd) and an
## "Enemies" node with monsters under it; this script supplies the rest at
## runtime: environment, sun, drifting motes, player, camera, HUD (with the
## coin purse; the old minimap.gd is unhooked), story text and music, all
## from `biome`.
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
const StoryUI = preload("res://scripts/world25/story_ui.gd")
const ClearingFX = preload("res://scripts/clearing/clearing_fx.gd")
const OVERLAY_SHADER = preload("res://shaders/comic_overlay.gdshader")
const RectScript = preload("res://scripts/background/screen_shader_rect.gd")
const DEFAULT_BIOME = preload("res://data/biomes/darkwood.tres")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const Shop = preload("res://scripts/ui/shop.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const HauntLamp = preload("res://scripts/world25/haunt_lamp.gd")
const DarknessScript = preload("res://scripts/world25/darkness.gd")
const RING_SHADER = preload("res://shaders/world25/sigil_ring.gdshader")
const MIST_SHADER = preload("res://shaders/world25/void_mist.gdshader")
const BiomeProps = preload("res://scripts/world25/biome_props.gd")
const PAGE_SHADER = preload("res://shaders/world25/comic_page.gdshader")
const COMIC_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
## Sound-effect words floating in a COMIC backdrop.
const SOUND_WORDS := ["KRAK!", "WHUMP", "SKRITCH", "?!", "BLAM!", "SHHH...", "SCRIBBLE", "FWOOSH", "THE END?", "...!"]
const WORD_COLORS := [Color(1.0, 0.85, 0.25), Color(0.95, 0.3, 0.25), Color(0.98, 0.96, 0.9), Color(0.45, 0.85, 0.95)]

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
## The living background round the floor: a great sigil turning far
## below, mist, rising embers, heaps of crumpled drafts and ink statues in the void
## (SIGIL, _build_backdrop), or a comic book in the 2D levels' look (COMIC,
## _build_comic_backdrop): a page of panels far below, torn-out panels and
## sound-effect words floating round the floor, giant broken nibs, paper dust.
@export var backdrop := true
enum BackdropStyle { SIGIL, COMIC }
@export var backdrop_style := BackdropStyle.SIGIL

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
## Spawned in the room once it's cleared and its clear captions are done,
## instead of cutting to `cutscene_on_clear`: the Gutter's ending
## (scenes/world25/light_capture.tscn, played out in the room itself).
@export_file("*.tscn") var ending_on_clear := ""
## A monster under "Enemies" shown with a big health bar (boss fights).
@export var boss_path: NodePath
@export var boss_name := ""
## Music while the boss lives (tense, dark: the Margins' boss track); the room's
## biome music comes back, slowly, once the room is cleared.
@export var boss_music := "dread"

@export_group("The Writer's lamp")
## Spawn the Haunting Lamp(s) from the biome's HauntProfile.
@export var haunt_enabled := true
## This room's lamp is a bit harder (> 1) or easier: scales how fast it
## moves and how often it strikes. Set per room by the generator.
@export var haunt_scale := 1.0
## How many lamps hunt here; -1 = the biome profile's `lamps`. Set per room
## by the generator (the Red Pen's room has two).
@export var haunt_lamps := -1

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
	_prepare_enemies(world)
	ui.title_card((title if title != "" else b.display_name).to_upper(), subtitle)
	var boss := get_node_or_null(boss_path)
	if boss and not (world and world.is_cleared(room_id)):
		ui.set_boss(boss, boss_name)
		_play_music(boss_music if boss_music != "" else b.music)
	else:
		_play_music(b.music)
	if enter_captions != "" and (world == null or world.once(room_id + ":enter")):
		_captions(enter_captions)
	# no controls tutorial here: the keys are the same as in 2D, where it plays
	# (Pause -> Controls still shows them on request, replay_tutorial())


## "|" separates captions; a leading "~" is Shade, the Writer, talking (his
## red panel), a leading "^" is Vesper (yellow, VESPER tab), the rest are the
## comic's narration / tips.
func _captions(text: String) -> void:
	for line in text.split("|"):
		line = line.strip_edges()
		if line.begins_with("~"):
			ui.caption(line.substr(1).strip_edges(), "shaky")
		elif line.begins_with("^"):
			ui.caption(line.substr(1).strip_edges(), "vesper")
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
	if backdrop:
		if backdrop_style == BackdropStyle.COMIC:
			_build_comic_backdrop()
		else:
			_build_backdrop(b)


## The void round the room, so the floor floats in something: a huge
## ritual circle turning slowly far below (the zone's sigil colour), two
## sheets of mist drifting over it, embers rising out of the dark, and
## heaps of crumpled drafts (biome_props SKULL_PILE) and black ink statues
## standing in the fog round the edges, kept clear of the gates.
## Deterministic per room.
func _build_backdrop(b: Resource) -> void:
	var c := camera_bounds.get_center()
	var span := maxf(camera_bounds.size.x, camera_bounds.size.y) + 40.0
	var glow: Color = b.rune_color if "rune_color" in b else Color(1.0, 0.26, 0.16)
	var holder := Node3D.new()
	holder.name = "Backdrop"
	add_child(holder)
	# the sigil in the abyss
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(span, span)
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("color", glow)
	rm.set_shader_parameter("glow", 1.5)
	rm.set_shader_parameter("alpha", 0.6)
	rm.set_shader_parameter("spin", 0.015)
	var ring := MeshInstance3D.new()
	ring.mesh = q
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(c.x, -16.0, c.y - 4.0)
	holder.add_child(ring)
	# mist over it
	for layer in [[-6.0, 0.4, 12.0], [-11.0, 0.3, 18.0]]:
		var mq := QuadMesh.new()
		mq.orientation = PlaneMesh.FACE_Y
		mq.size = Vector2(span * 1.2, span * 1.2)
		var mm := ShaderMaterial.new()
		mm.shader = MIST_SHADER
		mm.set_shader_parameter("color", b.background.lerp(glow, 0.12).lightened(0.05))
		mm.set_shader_parameter("alpha", layer[1])
		mm.set_shader_parameter("scale", layer[2])
		var mist := MeshInstance3D.new()
		mist.mesh = mq
		mist.material_override = mm
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.position = Vector3(c.x, layer[0], c.y - 4.0)
		holder.add_child(mist)
	# embers rising out of the abyss
	var embers := CPUParticles3D.new()
	var eq := QuadMesh.new()
	eq.size = Vector2(0.09, 0.09)
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.vertex_color_use_as_albedo = true
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	em.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	eq.material = em
	embers.mesh = eq
	embers.amount = 90
	embers.lifetime = 11.0
	embers.preprocess = 11.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(span * 0.45, 1.0, span * 0.4)
	embers.position = Vector3(c.x, -9.0, c.y - 4.0)
	embers.direction = Vector3(0.1, 1, 0)
	embers.spread = 25.0
	embers.gravity = Vector3(0.15, 0.25, 0)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.6
	embers.scale_amount_min = 0.6
	embers.scale_amount_max = 1.6
	var eg := Gradient.new()
	eg.offsets = PackedFloat32Array([0, 0.15, 0.7, 1])
	eg.colors = PackedColorArray([Color(glow, 0), Color(glow.lightened(0.3), 0.9), Color(glow, 0.5), Color(glow, 0)])
	embers.color_ramp = eg
	holder.add_child(embers)
	# heaps of crumpled drafts and ink statues in the fog round the floor
	var rng := RandomNumberGenerator.new()
	rng.seed = room_id.hash()
	var half := camera_bounds.size * 0.5 + Vector2(9.0, 7.0)
	var placed := 0
	var spots := 14
	for i in spots:
		var a := TAU * (i + rng.randf_range(-0.25, 0.25)) / spots
		var p := Vector3(c.x + cos(a) * half.x * rng.randf_range(1.0, 1.25), 0.0, c.y + sin(a) * half.y * rng.randf_range(1.0, 1.2))
		if on_floor(p) or _near_gate(p, 9.0):
			continue
		var prop := Node3D.new()
		prop.set_script(BiomeProps)
		prop.position = p
		prop.rotation_degrees.y = rng.randf_range(-40, 40) + (180.0 if sin(a) > 0.0 else 0.0)
		holder.add_child(prop)
		prop.seed = rng.randi_range(1, 999)
		if placed % 3 == 1:
			prop.size = rng.randf_range(2.2, 2.8)
			prop.position.y = rng.randf_range(-6.0, -4.0)
			prop.kind = BiomeProps.Kind.SHADE_STATUE
		else:
			prop.size = rng.randf_range(2.0, 2.8)
			prop.count = 8
			prop.radius = 1.6
			prop.position.y = rng.randf_range(-3.5, -1.5)
			prop.kind = BiomeProps.Kind.SKULL_PILE
		# lit red from the abyss, and visible through the darkness
		var up := OmniLight3D.new()
		up.light_color = glow
		up.light_energy = 2.2
		up.omni_range = 7.0
		up.position = Vector3(0, -1.0, 1.5)
		prop.add_child(up)
		prop.set_meta("glow_radius", 3.2 * prop.size)
		prop.add_to_group("glow")
		placed += 1
		if placed >= 7:
			break


## The COMIC backdrop: the Gutter seen as what it is, the margin of a comic
## book. A printed page of panels far below (comic_page.gdshader), torn-out
## panels and sound-effect words drifting round the floor, two giant broken
## nibs (biome_props PENCIL_TOTEM) sunk in the dark over the page, and paper
## dust rising.
func _build_comic_backdrop() -> void:
	var c := camera_bounds.get_center()
	var span := maxf(camera_bounds.size.x, camera_bounds.size.y) + 40.0
	var holder := Node3D.new()
	holder.name = "Backdrop"
	add_child(holder)
	var page_q := QuadMesh.new()
	page_q.orientation = PlaneMesh.FACE_Y
	page_q.size = Vector2(span * 1.8, span * 1.8)
	var pm := ShaderMaterial.new()
	pm.shader = PAGE_SHADER
	var page := MeshInstance3D.new()
	page.name = "Page"
	page.mesh = page_q
	page.material_override = pm
	page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	page.position = Vector3(c.x, -22.0, c.y - 6.0)
	holder.add_child(page)
	# torn-out panels, sound words and broken nibs in the void round the floor
	var rng := RandomNumberGenerator.new()
	rng.seed = room_id.hash()
	var half := camera_bounds.size * 0.5 + Vector2(8.0, 6.5)
	var spots := 16
	var placed := 0
	for i in spots:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / spots
		var p := Vector3(c.x + cos(a) * half.x * rng.randf_range(0.95, 1.25), 0.0, c.y + sin(a) * half.y * rng.randf_range(0.95, 1.2))
		if on_floor(p) or _near_gate(p, 7.0):
			continue
		var node: Node3D
		match placed % 3:
			0:
				node = _comic_scrap(rng)
				p.y = rng.randf_range(-7.0, -3.0)
			1:
				node = _sound_word(rng)
				p.y = rng.randf_range(-4.0, -1.0)
			_:
				node = _comic_scrap(rng)
				p.y = rng.randf_range(-11.0, -6.0)
		node.position = p
		holder.add_child(node)
		_drift(node, rng)
		placed += 1
		if placed >= 9:
			break
	for k in 2:  # giant broken nibs
		var pencil := Node3D.new()
		pencil.set_script(BiomeProps)
		var side := -1.0 if k == 0 else 1.0
		pencil.position = Vector3(c.x + side * (half.x + 4.0), -14.0, c.y - half.y * 0.6 + k * 6.0)
		pencil.rotation_degrees = Vector3(0, rng.randf_range(-30, 30), side * -32.0)
		holder.add_child(pencil)
		pencil.size = 4.0
		pencil.seed = 70 + k
		pencil.kind = BiomeProps.Kind.PENCIL_TOTEM
	# paper dust and flecks of ink rising out of the page
	var dust := CPUParticles3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.12, 0.12)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dq.material = dm
	dust.mesh = dq
	dust.amount = 70
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(span * 0.45, 1.0, span * 0.4)
	dust.position = Vector3(c.x, -12.0, c.y - 4.0)
	dust.direction = Vector3(0.1, 1, 0)
	dust.spread = 30.0
	dust.gravity = Vector3(0.1, 0.2, 0)
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.2
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.5
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0, 0.2, 0.75, 1])
	var paper := Color(0.95, 0.92, 0.82)
	dg.colors = PackedColorArray([Color(paper, 0), Color(paper, 0.7), Color(paper, 0.35), Color(paper, 0)])
	dust.color_ramp = dg
	holder.add_child(dust)


## One torn-out comic panel (comic_page.gdshader, `single`), tilted up
## towards the camera.
func _comic_scrap(rng: RandomNumberGenerator) -> Node3D:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(rng.randf_range(3.6, 5.6), rng.randf_range(2.8, 4.2))
	var m := ShaderMaterial.new()
	m.shader = PAGE_SHADER
	m.set_shader_parameter("single", true)
	m.set_shader_parameter("seed", float(rng.randi_range(0, 59)))
	m.set_shader_parameter("brightness", 0.75)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(rng.randf_range(15, 40), rng.randf_range(-40, 40), rng.randf_range(-15, 15))
	# it carves its own pool in the darkness (darkness.gd), so it reads
	mi.set_meta("glow_radius", q.size.x * 0.55)
	mi.add_to_group("glow")
	return mi


## A sound-effect word in the comic's lettering, hanging in the void.
func _sound_word(rng: RandomNumberGenerator) -> Node3D:
	var l := Label3D.new()
	l.text = SOUND_WORDS[rng.randi() % SOUND_WORDS.size()]
	l.font = COMIC_FONT
	l.font_size = 150
	l.pixel_size = 0.012
	l.outline_size = 36
	l.outline_modulate = Color(0.06, 0.04, 0.09)
	l.modulate = WORD_COLORS[rng.randi() % WORD_COLORS.size()]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.rotation_degrees.z = rng.randf_range(-12, 12)
	l.set_meta("glow_radius", 2.2)
	l.add_to_group("glow")
	return l


## A slow bob and turn, so the scraps and words drift.
func _drift(node: Node3D, rng: RandomNumberGenerator) -> void:
	var bob := create_tween().set_loops()
	var up := rng.randf_range(0.4, 0.9)
	var t := rng.randf_range(2.8, 4.6)
	bob.tween_property(node, "position:y", node.position.y + up, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(node, "position:y", node.position.y, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if node is MeshInstance3D:
		var spin := create_tween().set_loops()
		var y0 := node.rotation_degrees.y
		spin.tween_property(node, "rotation_degrees:y", y0 + rng.randf_range(8, 18), t * 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		spin.tween_property(node, "rotation_degrees:y", y0, t * 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _near_gate(p: Vector3, dist: float) -> bool:
	for g in find_children("*", "Node3D", true, false):
		if g.get_script() == preload("res://scripts/world25/gate.gd") and Vector2(g.global_position.x - p.x, g.global_position.z - p.z).length() < dist:
			return true
	return false


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
	if _biome().get("darkness") and _biome().darkness > 0.0:
		var dark := ColorRect.new()
		dark.name = "Darkness"
		dark.set_script(DarknessScript)
		dark.darkness = _biome().darkness
		dark.tint = _biome().background.darkened(0.3)
		layer.add_child(dark)
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
	if not haunt_enabled or prof == null:
		return
	var lamps: int = prof.lamps if haunt_lamps < 0 else haunt_lamps
	if lamps <= 0:
		return
	var settings := get_node_or_null("/root/Settings")
	var diff: String = settings.get_value("difficulty") if settings else "normal"
	var speed: float = {"relaxed": 0.75, "normal": 1.0, "hard": 1.25}.get(diff, 1.0)
	var tele: float = {"relaxed": 1.3, "normal": 1.0, "hard": 0.8}.get(diff, 1.0)
	var roam := camera_bounds.grow_individual(3.5, 2.5, 3.5, 2.5)
	var taken: Array[Vector3] = [player.global_position]
	for i in lamps:
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


## True if (x, z) of `p` is on one of the room's islands (the floor, not
## the void round it). The Haunting Lamp only wanders over the floor.
func on_floor(p: Vector3) -> bool:
	for n in find_children("*", "Node3D", true, false):
		if n.has_method("contains") and n.contains(Vector2(p.x, p.z)):
			return true
	return false


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


func _play_music(track: String, fade := 0.8) -> void:
	var music := get_node_or_null("/root/Music")
	if music and track != "":
		music.play(track, fade)


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
	var world := get_node_or_null("/root/World25")
	if world and world.transitioning:
		return  # no menus over a room change
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()  # pause here instead of leaving
		open_overlay("pause")
	elif event.is_action_pressed("shop") and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_overlay.call_deferred("shop")  # B: Quire's shop, anywhere


## Opens a full-screen menu over the room and pauses the game:
## "pause", "shop" (Quire's Curios: B, the pause menu, Quire's stall) or
## "settings". (The skill tree is retired; skill_tree.gd is unhooked.)
func open_overlay(action: String) -> void:
	if _overlay != null or player == null or player.dead:
		return
	var layer := get_node("UI")
	match action:
		"pause":
			_overlay = Control.new()
			_overlay.set_script(PauseMenu)
			_overlay.chosen.connect(_on_pause_choice)
		"shop":
			_overlay = Control.new()
			_overlay.set_script(Shop)
			_overlay.closed.connect(_on_overlay_closed)
		"settings":
			_overlay = Control.new()
			_overlay.set_script(SettingsMenu)
			_overlay.overlay = true
			_overlay.closed.connect(_on_overlay_closed)
		_:
			return
	if action == "pause":  # its own layer above everything (HUD, captions, tutorial), as in 2D
		layer = get_node_or_null("PauseLayer")
		if layer == null:
			layer = CanvasLayer.new()
			layer.name = "PauseLayer"
			layer.layer = 85
			layer.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(layer)
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
		"controls":
			_on_overlay_closed()
			replay_tutorial()
		"retry":
			get_tree().paused = false
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		"shop", "settings":
			get_tree().paused = false
			open_overlay(action)
		"menu":
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## Pause -> Controls: forget the 2.5D tutorial and play it from the start.
func replay_tutorial() -> void:
	var old := get_node_or_null("Tutorial")
	if old:
		remove_child(old)  # gives the hint line back right away
		old.queue_free()
	var profile := get_node_or_null("/root/Profile")
	if profile:
		profile.reset_tutorials("25d.")
	Tutorial.start(self, player, "25d", ui)


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
		profile.record_clear(room_id)
	var i := 0
	for g in _gates():
		get_tree().create_timer(0.25 * i).timeout.connect(g.open)
		i += 1
	if not boss_path.is_empty():
		_play_music(_biome().music, 3.0)  # the fight's over: the room's own tune creeps back
	if clear_captions != "":
		_captions(clear_captions)
	if ending_on_clear != "":
		await get_tree().create_timer(1.2).timeout
		var wait := 0.0
		while is_inside_tree() and ui and ui.busy() and wait < 8.0:  # let the captions finish
			await get_tree().process_frame
			wait += get_process_delta_time()
		if is_inside_tree() and player and not player.dead:
			add_child(load(ending_on_clear).instantiate())
	elif cutscene_on_clear != "" and world:
		await get_tree().create_timer(4.5).timeout
		world.play_cutscene(cutscene_on_clear)
