extends Node3D
## THE CAPTURE: how Vesper leaves the Gutter. The Rubbing Room spawns it once
## the Eraser is beaten and its clear captions are done (room.gd
## `ending_on_clear`, scenes/world25/light_capture.tscn). About 10.5 s, all
## built in code; Enter / Esc skips.
##  1. LIGHTS OUT (0-2.3 s): bars come in, the HUD goes, the Haunting Lamp
##     blinks out and the braziers are snuffed one by one; only Vesper's Ember
##     is left in the dark. Shade: "ENOUGH HIDING IN MY MARGINS."
##  2. LIGHTS ON (2.3-4 s): KLAK. KLAK. KLAK-KLAK-KLAK. The Writer's lamps slam
##     down all round the arena, faster and faster, and Vesper turns to each.
##  3. THE HUNT (4-6.6 s): they sweep in, crossing and closing. He runs; one
##     swings at him and he dashes clear, and then they ring him, turning.
##  4. CAUGHT (6.6-7.5 s): a lamp brighter than the rest slams down on him
##     from straight above; the others pour into it and the dark burns off.
##     Shade: "FOUND YOU."
##  5. TAKEN (7.5-10.5 s): the beam lifts him off the floor, paper and ink
##     rising round him, and warms to gold; down it comes Shade's hand (the
##     drawing from the final fight, shade_hand.gd, flat in the 3D room) and
##     hooks him by the collar with its golden nib. "BACK TO MY PAGE." One
##     yank and he's gone up the light.
## Then page_climb.gd carries him up the comic page into Shade's City.

const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const ShadeHand = preload("res://scripts/effects/shade_hand.gd")
const ClearingFX = preload("res://scripts/clearing/clearing_fx.gd")
const COLUMN_SHADER = preload("res://shaders/world25/haunt_column.gdshader")
const CIRCLE_SHADER = preload("res://shaders/world25/haunt_circle.gdshader")
const HAND_SHADER = preload("res://shaders/world25/capture_hand.gdshader")
const PageClimb = preload("res://scripts/effects/page_climb.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

const GOLD := Color(1.0, 0.78, 0.4)
const INK := Color(0.03, 0.02, 0.05)
const PAPER := Color(0.93, 0.89, 0.78)
## How many of the Writer's lamps come on round the arena, the order they
## come on in (hopping about the ring) and the gaps between them.
const LAMPS := 9
const ORDER := [0, 5, 2, 7, 4, 8, 1, 6, 3]
const GAPS := [0.0, 0.32, 0.27, 0.23, 0.19, 0.16, 0.14, 0.12, 0.11]
## The ring they come on round (the arena is an oval about 24 x 20).
const RIM := Vector2(8.6, 7.0)
const COLUMN := 34.0
## The hand's SubViewport, where its nib sits in it, and the quad's size.
const VIEW := 1024
const NIB_PX := Vector2(400.0, 900.0)
const QUAD := 15.0
## From Vesper's feet to where the nib takes him: the back of his collar.
const COLLAR := 1.62
## How high the beam floats him before the nib takes him.
const LIFT := 2.4
const BAR := 64.0
## The low shot up the beam: its camera's yaw and distance from him.
const UP_YAW := 0.2
const UP_DIST := 14.5
## biome_props.gd kinds that lie flat (RITUAL_CIRCLE, INK_POOL, PINS, CANDLES):
## never in the way of the camera.
const LOW_PROPS := [7, 11, 14, 19]

const T_DIM := 0.4
const T_SNUFF := 0.9
const T_ON := 2.3
const T_HUNT := 4.0
const T_STRIKE := 5.0
const T_DASH := 5.4
const T_RING := 5.75
const T_CATCH := 6.6
const T_LIFT := 7.5
const T_HAND := 7.9
const T_HOOK := 9.1
const T_YANK := 9.75
const T_GRAB := 10.15  # the last frame, the beam alone, for the page (he's long gone)
const T_END := 10.45


## One of the Writer's lamps: a column of white out of the dark with its
## circle of proofreading marks on the floor (the Haunting Lamp's look).
class Beam:
	var column: MeshInstance3D
	var col_mat: ShaderMaterial
	var circle: MeshInstance3D
	var circle_mat: ShaderMaterial
	var glow: Node3D  # group "glow": its pool in the room's darkness
	var light: OmniLight3D
	var motes: CPUParticles3D
	var pos := Vector3.ZERO
	var column_shift := Vector3.ZERO  # the column alone, moved off its circle
	var home := 0.0  # its angle round the arena
	var slot := 0.0  # its angle in the ring round Vesper
	var radius := 1.25
	var born := -1.0  # cutscene time it slams down (-1 = not yet)
	var landed := false
	var power := 1.0
	var flash := 0.0
	var phase := 0.0
	var spin := 1.0
	var tint := Color.WHITE
	var merging := -1.0  # pouring into the catching beam (cutscene time it started)


var _room: Node
var _player: CharacterBody3D
var _cam: Camera3D
var _dark: Node
var _hud: CanvasItem
var _t := 0.0
var _fired := {}
var _done := false
var _prewarm := 2
var _lamps: Array[Beam] = []
var _catch: Beam
var _striker: Beam
var _ring_center := Vector3.ZERO
var _run := Vector3.ZERO
var _cam0 := {}
var _trauma := 0.0
var _dark0 := 0.68
var _flash := 0.0
var _flash_color := Color.WHITE
var _line := ""
var _line_t := 0.0
var _line_end := 0.0
var _layer: CanvasLayer
var _screen: Control
var _hand: Node2D
var _hand_view: SubViewport
var _hand_quad: MeshInstance3D
var _hand_mat: ShaderMaterial
var _nib := Vector3.ZERO
var _caught_at := Vector3.ZERO
var _hold := Vector3.ZERO  # where Vesper hangs
var _updraft: Array[CPUParticles3D] = []
var _rings: Array = []  # shockwaves: {mi, mat, age, life, size}
var _braziers: Array = []
var _grab: Texture2D


func _ready() -> void:
	_room = get_parent()
	_player = _room.get("player")
	_cam = get_viewport().get_camera_3d()
	_dark = _room.get_node_or_null("UI/Darkness")
	if _dark and "darkness" in _dark:
		_dark0 = _dark.darkness
	var ui_layer := _room.get_node_or_null("UI")
	if ui_layer:
		for c in ui_layer.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("clearing_hud.gd"):
				_hud = c
	var world := get_node_or_null("/root/World25")
	if world:
		world.transitioning = true  # no pause or shop over it
	Engine.time_scale = 1.0
	if _player:
		_player.cutscene = true
		_player.cutscene_dir = Vector3.ZERO
		_player.erase = 0.0
		_caught_at = _player.global_position
	if _cam:
		_cam.set_process(false)  # the cutscene frames its own shots
		var pitch := -_cam.rotation.x
		var dist: float = _cam.get("distance") if "distance" in _cam else 19.0
		_cam0 = {"focus": _cam.global_position - Vector3(0.0, sin(pitch), cos(pitch)) * dist,
			"yaw": 0.0, "pitch": rad_to_deg(pitch), "dist": dist, "fov": _cam.fov}
	for b in get_tree().get_nodes_in_group("lantern"):
		if b.get("lit") and _room.is_ancestor_of(b):
			_braziers.append(b)
	var music := get_node_or_null("/root/Music")
	if music:
		music.stop(1.6)
	PageClimb.preload_level()  # Shade's City, ready by the climb
	_build_lamps()
	_build_hand()
	_build_updraft()
	_build_overlay()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := event.is_action_pressed("pause")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_finish(true)


# ------------------------------------------------------------------ build

func _build_lamps() -> void:
	for i in LAMPS:
		var b := _make_beam(1.25, i % 3 == 0)
		b.home = TAU * i / LAMPS + 0.35
		b.pos = _rim(b.home)
		b.phase = i * 1.7
		b.spin = 1.0 if i % 2 == 0 else -0.8
		_lamps.append(b)
	var at := 0.0
	for k in ORDER.size():
		at += GAPS[k]
		_lamps[ORDER[k]].born = T_ON + at
	_catch = _make_beam(1.75, true)
	_catch.born = T_CATCH - 0.12


func _make_beam(radius: float, with_light: bool) -> Beam:
	var b := Beam.new()
	b.radius = radius
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 24
	cyl.rings = 4
	cyl.cap_top = false
	cyl.cap_bottom = false
	b.col_mat = ShaderMaterial.new()
	b.col_mat.shader = COLUMN_SHADER
	b.column = MeshInstance3D.new()
	b.column.mesh = cyl
	b.column.material_override = b.col_mat
	b.column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b.column)
	b.circle_mat = ShaderMaterial.new()
	b.circle_mat.shader = CIRCLE_SHADER
	b.circle_mat.set_shader_parameter("pool", 0.22)
	b.circle_mat.set_shader_parameter("spin", 0.4 if randf() < 0.5 else -0.4)
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(radius * 2.4, radius * 2.4)
	b.circle = MeshInstance3D.new()
	b.circle.mesh = q
	b.circle.material_override = b.circle_mat
	b.circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b.circle)
	b.glow = Node3D.new()
	b.glow.add_to_group("glow")
	b.glow.set_meta("glow_radius", 0.0)
	add_child(b.glow)
	if with_light:
		b.light = OmniLight3D.new()
		b.light.omni_range = radius * 3.2
		b.light.light_energy = 0.0
		add_child(b.light)
	b.motes = _particles(18, 0.06, 2.4, Color(1, 1, 1, 0.8), true)
	b.motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	b.motes.emission_sphere_radius = radius * 0.7
	b.motes.initial_velocity_min = 0.6
	b.motes.initial_velocity_max = 1.8
	b.motes.emitting = false
	return b


## The hand: shade_hand.gd as a puppet in a SubViewport, shown on a quad
## that always faces the camera.
func _build_hand() -> void:
	_hand_view = SubViewport.new()
	_hand_view.size = Vector2i(VIEW, VIEW)
	_hand_view.transparent_bg = true
	_hand_view.disable_3d = true
	_hand_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_hand_view)
	_hand = ShadeHand.new()
	_hand.puppet = true
	_hand.puppet_nib = NIB_PX
	_hand.puppet_turn = -0.85
	_hand.puppet_flex = -0.3
	_hand_view.add_child(_hand)
	_hand_mat = ShaderMaterial.new()
	_hand_mat.shader = HAND_SHADER
	_hand_mat.set_shader_parameter("art", _hand_view.get_texture())
	_hand_mat.set_shader_parameter("glow_color", GOLD)
	var q := QuadMesh.new()
	q.size = Vector2(QUAD, QUAD)
	_hand_quad = MeshInstance3D.new()
	_hand_quad.mesh = q
	_hand_quad.material_override = _hand_mat
	_hand_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hand_quad)


## What the catching beam pulls up round him: motes of light, torn paper and
## flakes of ink, all rising.
func _build_updraft() -> void:
	var motes := _particles(70, 0.08, 1.8, Color(1.0, 0.95, 0.8, 0.9), true)
	var paper := _particles(26, 0.32, 2.2, PAPER, false)
	var ink := _particles(40, 0.13, 1.9, INK, false)
	for p in [motes, paper, ink]:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 2.2
		p.emission_ring_inner_radius = 0.4
		p.emission_ring_height = 0.2
		p.direction = Vector3.UP
		p.spread = 12.0
		p.gravity = Vector3(0, 3.5, 0)
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.emitting = false
		_updraft.append(p)
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 6.0
	paper.initial_velocity_min = 1.0
	paper.initial_velocity_max = 3.5
	paper.angular_velocity_min = -260.0
	paper.angular_velocity_max = 260.0
	paper.scale_amount_min = 0.5
	paper.scale_amount_max = 1.2
	ink.initial_velocity_min = 1.5
	ink.initial_velocity_max = 4.5
	ink.angular_velocity_min = -400.0
	ink.angular_velocity_max = 400.0


func _particles(amount: int, size: float, life: float, color: Color, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (0.7 if not additive else 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), color, Color(color, color.a * 0.6), Color(color, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.draw.connect(_draw_screen)
	_layer.add_child(_screen)


# ------------------------------------------------------------------ timing

func _k(a: float, b: float) -> float:
	var x := clampf((_t - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _at(t: float) -> bool:
	if _t >= t and not _fired.has(t):
		_fired[t] = true
		return true
	return false


func _rim(a: float) -> Vector3:
	return Vector3(cos(a) * RIM.x, 0.0, sin(a) * RIM.y)


func _vesper() -> Vector3:
	if _player == null:
		return _caught_at
	return _player.smooth_position if "smooth_position" in _player else _player.global_position


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ------------------------------------------------------------------- live

func _process(delta: float) -> void:
	if _done:
		return
	delta = minf(delta, 1.0 / 20.0)
	_t += delta
	if _prewarm > 0:
		_prewarm -= 1
		_warm_shaders(_prewarm > 0)
	_events()
	_steer_vesper(delta)
	for b in _lamps:
		_move_lamp(b, delta)
		_update_beam(b, delta)
	_update_catch(delta)
	_update_hand()
	_update_rings(delta)
	_update_room(delta)
	if _cam:
		_update_camera(delta)
	_flash = maxf(_flash - delta * 2.2, 0.0)
	_screen.queue_redraw()
	if _t >= T_GRAB and not _fired.has("grab"):
		_fired["grab"] = true
		_grab_frame()
	if _t >= T_END:
		_finish(false)


## Draws every new material once, out of sight behind the bars, so nothing
## hitches mid-shot while its shader compiles.
func _warm_shaders(on: bool) -> void:
	if _cam == null:
		return
	# (a speck in the middle of the screen: drawn, but too small to see)
	var at := _cam.global_position - _cam.global_basis.z * 3.0
	for b: Beam in _lamps + [_catch]:
		for mi: MeshInstance3D in [b.column, b.circle]:
			mi.visible = on
			mi.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), at)
	_hand_quad.visible = on
	_hand_quad.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), at)
	# the particles under the floor where the camera looks (their first frame
	# draws every quad at the emitter, so they mustn't be in sight)
	var ray := -_cam.global_basis.z
	var under := _cam.global_position + ray * (-_cam.global_position.y / minf(ray.y, -0.1)) + Vector3(0, -1.5, 0)
	for p in _updraft:
		p.global_position = under
		if not on:
			p.restart()  # (clears what it let out)
		p.emitting = on


func _events() -> void:
	var tree := get_tree()
	if _at(0.0):
		SfxSynth.play(tree, "rumble", -14.0, 0.5)
	if _at(T_DIM):
		SfxSynth.play(tree, "clang", -12.0, 0.45)
		for lamp in tree.get_nodes_in_group("haunt_lamp"):
			_blink_out(lamp)
	for i in _braziers.size():
		if _at(T_SNUFF + i * 0.45):
			_snuff(_braziers[i])
	if _at(1.15):
		_say("ENOUGH HIDING IN MY MARGINS.", 2.1)
	for b in _lamps:
		if b.born >= 0.0 and not b.landed and _t >= b.born + 0.12:
			_land(b)
	if _at(T_HUNT):
		SfxSynth.play(tree, "rumble", -6.0, 0.62)
	if _at(T_HUNT + 1.6):
		SfxSynth.play(tree, "rumble", -8.0, 0.7)
	if _at(T_STRIKE):
		# the nearest lamp swings at him
		var best := INF
		for b in _lamps:
			var d := _flat(b.pos - _vesper()).length()
			if d < best:
				best = d
				_striker = b
		SfxSynth.play(tree, "whoosh", -4.0, 0.7)
	if _at(T_DASH) and _player:
		var away := _flat(_vesper() - _striker.pos).normalized() if _striker else Vector3.RIGHT
		var side := Vector3(-away.z, 0.0, away.x)
		if side.dot(-_flat(_vesper())) < 0.0:
			side = -side  # dash towards the middle, never off the edge
		_player.cutscene_dash((side * 0.8 + away * 0.6).normalized())
	if _at(T_RING):
		_ring_up()
	if _at(T_CATCH):
		_caught()
	if _at(T_CATCH + 0.45):
		_say("FOUND YOU.", 1.0)
	for i in _lamps.size():
		if _at(T_CATCH + 0.3 + i * 0.07):
			_lamps[i].merging = _t
	if _at(T_LIFT - 0.5):
		_clear_foreground()
	if _at(T_LIFT):
		SfxSynth.play(tree, "roar", -12.0, 0.42)
		SfxSynth.play(tree, "rumble", -6.0, 0.45)
		if _player:
			_hold = _player.global_position
			_player.cutscene_point = _hold
			_player.cutscene_hold = true
	if _at(T_HAND):
		SfxSynth.play(tree, "screech", -16.0, 0.45)
		SfxSynth.play(tree, "whoosh", -6.0, 0.4)
	if _at(T_HOOK):
		_hooked()
	if _at(T_HOOK - 0.3):
		_say("BACK TO MY PAGE.", 0.45)
	if _at(T_YANK):
		SfxSynth.play(tree, "whoosh", 0.0, 0.42)
		SfxSynth.play(tree, "thud", -4.0, 0.7)
		Sfx.play("teleport", -2.0, 0.7)
		_trauma = maxf(_trauma, 0.55)
		_catch.flash = 1.0


## The Haunting Lamp sputters and dies: the Writer has other plans.
func _blink_out(lamp: Node) -> void:
	lamp.set_process(false)
	lamp.set_physics_process(false)
	var t := create_tween()
	for k in 5:
		t.tween_callback(func(): lamp.visible = not lamp.visible).set_delay(0.05 + 0.04 * k)
	t.tween_callback(lamp.queue_free)
	if _player:
		_player.erase = 0.0
		_player.erase_source = null


func _snuff(b: Node) -> void:
	var at: Vector3 = b.global_position + Vector3(0, 1.6, 0)
	b.lit = false
	ClearingFX.burst(get_tree(), at, Color(0.08, 0.06, 0.1), 14, 2.5)
	SfxSynth.play(get_tree(), "whoosh", -5.0, 0.5)
	if _player:
		_player.set_facing(_flat(b.global_position - _player.global_position))


func _land(b: Beam) -> void:
	b.landed = true
	b.flash = 1.0
	_ring(b.pos, b.radius * 2.6, b.tint, 0.55)
	_trauma = maxf(_trauma, 0.32)
	var n := _lamps.filter(func(x): return x.landed).size()
	SfxSynth.play(get_tree(), "clang", -7.0, 1.55 + randf() * 0.25)
	SfxSynth.play(get_tree(), "thud", -9.0, 1.5)
	if n <= 3:
		ClearingFX.pop_text(get_tree(), b.pos + Vector3(0, 2.2, 0), "KLAK!", Color(0.96, 0.95, 1.0), 40)
	if _player and _t < T_HUNT:
		_player.set_facing(_flat(b.pos - _player.global_position))


## After his dash: the lamps make a ring round him and turn it, closing.
func _ring_up() -> void:
	_ring_center = _flat(_vesper())
	# each keeps its side of him, so none cross on the way in
	var order := _lamps.duplicate()
	order.sort_custom(func(a: Beam, b: Beam): return _angle_round(a.pos) < _angle_round(b.pos))
	var a0 := _angle_round(order[0].pos)
	for i in order.size():
		order[i].slot = a0 + TAU * i / order.size()


func _angle_round(p: Vector3) -> float:
	return atan2(p.z - _ring_center.z, p.x - _ring_center.x)


func _caught() -> void:
	var tree := get_tree()
	_caught_at = _flat(_vesper())
	_catch.pos = _caught_at
	_flash = 1.0
	_flash_color = Color(1.0, 0.98, 0.9)
	_trauma = 0.9
	_ring(_caught_at, 9.0, Color.WHITE, 0.9)
	_ring(_caught_at, 5.0, Color.WHITE, 0.6)
	SfxSynth.play(tree, "thud", 0.0, 0.5)
	SfxSynth.play(tree, "clang", -3.0, 0.62)
	SfxSynth.play(tree, "shatter", -10.0, 1.5)
	ClearingFX.pop_text(tree, _caught_at + Vector3(0, 2.2, 0), "KA-CHUNK!", Color(1.0, 0.96, 0.85), 54)
	if _player:
		_player.cutscene_dir = Vector3.ZERO
		_player._squash = Vector2(1.35, 0.7)
		_player.set_facing(_flat(_cam.global_position - _player.global_position) if _cam else Vector3.BACK)
	for p in _updraft:
		p.global_position = _caught_at + Vector3(0, 0.1, 0)
		p.emitting = true


func _hooked() -> void:
	var tree := get_tree()
	_hand.puppet_flex = 1.0
	_trauma = maxf(_trauma, 0.6)
	_catch.flash = 0.8
	SfxSynth.play(tree, "clang", -2.0, 1.25)
	SfxSynth.play(tree, "splut", -4.0, 0.8)
	SfxSynth.play(tree, "scritch", -6.0, 0.7)
	ClearingFX.pop_text(tree, _nib + _cam.global_basis.x * 1.6 + Vector3(0, 0.3, 0), "SHNK!", GOLD.lightened(0.3), 46)
	ClearingFX.burst(tree, _nib, INK, 16, 3.0)


## Tall props between the low camera and him go while it swings down, and the
## void's heaps and ink statues round the camera (out past the floor's edge),
## so nothing big and dark fills half the frame. Flat props stay.
func _clear_foreground() -> void:
	var p := _flat(_vesper())
	var lens := p + Basis(Vector3.UP, UP_YAW) * Vector3(0.0, 0.0, UP_DIST)
	var props := _room.get_node_or_null("Props")
	if props:
		for n in props.get_children():
			if not n is Node3D or n.get("kind") in LOW_PROPS:
				continue
			var q := _flat(n.global_position)
			if Geometry3D.get_closest_point_to_segment(q, lens, p).distance_to(q) < 3.4 and q.distance_to(p) > 2.0:
				n.visible = false
	for group in ["Backdrop", "Deep"]:
		var back := _room.get_node_or_null(group)
		if back == null:
			continue
		for n in back.get_children():
			if n is Node3D:
				var q := _flat(n.global_position)
				if q.distance_to(lens) < 9.0 or Geometry3D.get_closest_point_to_segment(q, lens, p).distance_to(q) < 4.0:
					n.visible = false


func _say(text: String, hold: float) -> void:
	_line = text
	_line_t = _t
	_line_end = _t + text.length() / 30.0 + hold


func _ring(at: Vector3, size: float, tint: Color, life: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_SHADER
	mat.set_shader_parameter("pool", 0.0)
	mat.set_shader_parameter("spin", 1.6)
	mat.set_shader_parameter("tint", tint)
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(2.4, 2.4)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3(0, 0.08, 0)
	_rings.append({"mi": mi, "mat": mat, "age": 0.0, "life": life, "size": size})


# ----------------------------------------------------------------- motion

func _steer_vesper(delta: float) -> void:
	if _player == null or _player.cutscene_hold:
		return
	var p := _flat(_vesper())
	if _t >= T_HUNT + 0.35 and _t < T_DASH:
		# run from the lamps, keep to the middle of the floor
		var push := Vector3.ZERO
		for b in _lamps:
			var d := p - _flat(b.pos)
			push += d.normalized() / maxf(d.length_squared(), 1.0)
		push = push.normalized() - p / 7.0 * smoothstep(3.5, 7.0, p.length())
		_run = _run.lerp(push.normalized(), 1.0 - exp(-4.0 * delta))
		_player.cutscene_dir = _run.normalized() * 0.85
	else:
		_player.cutscene_dir = Vector3.ZERO
	if _t >= T_RING + 0.15 and _t < T_CATCH:
		# trapped: he turns from lamp to lamp
		var i := int((_t - T_RING) / 0.3) % _lamps.size()
		var face := _flat(_lamps[(i * 4) % _lamps.size()].pos) - p
		if face.length() > 0.3:
			_player.set_facing(face)


func _move_lamp(b: Beam, delta: float) -> void:
	if b.born < 0.0 or _t < b.born:
		return
	var p := _flat(_vesper())
	var goal := b.pos
	var rate := 2.4
	if b.merging >= 0.0:
		goal = _caught_at
		rate = 5.0
		var gone := clampf((_t - b.merging) / 0.45, 0.0, 1.0)
		b.power = 1.0 - gone
		if gone >= 1.0 and b.column.visible:
			_catch.flash = maxf(_catch.flash, 0.55)
			SfxSynth.play(get_tree(), "whoosh", -14.0, 1.6)
	elif _t < T_HUNT:
		goal = _rim(b.home) + Vector3(sin(_t * 1.3 + b.phase), 0.0, cos(_t * 1.1 + b.phase)) * 0.5
	elif _t < T_RING:
		var k := _k(T_HUNT, T_CATCH)
		var a := b.home + b.spin * (_t - T_HUNT) * 0.5
		var r := lerpf(1.0, 0.55, k) + sin(_t * 1.4 + b.phase) * 0.12
		goal = Vector3(cos(a) * RIM.x * r, 0.0, sin(a) * RIM.y * r).lerp(p, 0.3 * k)
		if b == _striker and _t >= T_STRIKE:
			goal = p + _player.velocity * 0.25 if _t < T_DASH else _flat(b.pos)
			rate = 6.5 if _t < T_DASH else 2.0
	else:
		var a := b.slot + (_t - T_RING) * 0.55
		goal = _ring_center + Vector3(cos(a), 0.0, sin(a)) * lerpf(4.2, 3.0, _k(T_RING, T_CATCH))
		rate = 3.0
	# keep the lamps over the floor
	var e := Vector2(goal.x / 10.5, goal.z / 8.6)
	if e.length() > 1.0:
		goal = Vector3(goal.x, 0.0, goal.z) / e.length()
	b.pos = b.pos.lerp(goal, 1.0 - exp(-rate * delta))


func _update_beam(b: Beam, delta: float) -> void:
	if _prewarm > 0:
		return
	var live := b.born >= 0.0 and _t >= b.born and b.power > 0.01
	b.column.visible = live
	b.circle.visible = live and b.landed
	b.glow.visible = live and b.landed
	b.motes.emitting = live and b.landed
	if b.light:
		b.light.visible = live and b.landed
	if not live:
		return
	b.flash = maxf(b.flash - delta * 2.4, 0.0)
	var drop := clampf((_t - b.born) / 0.12, 0.0, 1.0)
	drop *= drop  # it comes down faster and faster
	var r := b.radius * (1.0 + b.flash * 0.12)
	var basis := Basis.from_scale(Vector3(r * 0.82, COLUMN, r * 0.82))
	b.column.global_transform = Transform3D(basis, b.pos + b.column_shift + Vector3(0.0, COLUMN * 0.5 + (1.0 - drop) * COLUMN, 0.0))
	b.col_mat.set_shader_parameter("intensity", (0.5 + b.flash * 1.3) * b.power)
	b.col_mat.set_shader_parameter("tint", b.tint)
	b.circle.global_position = b.pos + Vector3(0.0, 0.05, 0.0)
	b.circle.scale = Vector3.ONE * (1.0 + b.flash * 0.3)
	b.circle_mat.set_shader_parameter("intensity", (0.75 + b.flash) * b.power)
	b.circle_mat.set_shader_parameter("tint", b.tint)
	b.glow.global_position = b.pos
	b.glow.set_meta("glow_radius", b.radius * 1.8 * b.power * (1.0 + b.flash * 0.4))
	b.motes.global_position = b.pos + Vector3(0.0, 1.0, 0.0)
	if b.light:
		b.light.global_position = b.pos + Vector3(0.0, 1.8, 0.0)
		b.light.light_color = b.tint
		b.light.light_energy = (1.5 + b.flash * 4.0) * b.power


## The catching beam: slams down on him, swallows the others, warms to gold
## as the hand comes down it, and flares as it takes him.
func _update_catch(delta: float) -> void:
	var b := _catch
	if b.born >= 0.0 and _t >= b.born and not b.landed and _t >= b.born + 0.12:
		b.landed = true
	var merged := _lamps.filter(func(x): return x.merging >= 0.0 and _t - x.merging > 0.45).size()
	b.power = 1.25 + 0.06 * merged + 0.4 * _k(T_YANK, T_GRAB)
	b.radius = lerpf(1.75, 2.1, _k(T_CATCH, T_LIFT))
	b.tint = Color.WHITE.lerp(GOLD, _k(T_LIFT, T_HOOK) * 0.85)
	b.circle_mat.set_shader_parameter("fill", _k(T_CATCH, T_CATCH + 0.4))
	if _cam:
		# down low, the column slides back behind him (along the view, so it
		# still looks centred on him): he stays dark against the light
		# instead of washed out inside it, and the hand stays crisp
		var back := _flat(-_cam.global_basis.z).normalized()
		b.column_shift = back * (b.radius + 0.6) * _k(T_LIFT - 0.6, T_LIFT + 0.2)
	_update_beam(b, delta)
	if b.light:
		b.light.omni_range = 9.0
	b.glow.set_meta("glow_radius", b.radius * (2.2 + 2.5 * _k(T_CATCH, T_LIFT)) * (1.0 + b.flash * 0.4))


func _update_hand() -> void:
	if _prewarm > 0 or _cam == null:
		return
	if _player and _player.cutscene_hold:
		# lifted: the beam floats him up, then the nib has him
		var rise := LIFT * _k(T_LIFT, T_HOOK) + 0.07 * sin(_t * 3.1) * _k(T_LIFT, T_HAND)
		var sway := _k(T_LIFT, T_HOOK)
		var hold := _hold + Vector3(0.0, rise, 0.0)
		if _t >= T_HOOK:
			hold = _nib - Vector3(0.0, COLLAR, 0.0) + _cam.global_basis.z * 0.25
		_player.cutscene_point = hold
		_player.erase = 0.22 * _k(T_LIFT, T_HOOK) + 0.6 * _k(T_YANK, T_GRAB)
		var vis: Node3D = _player.visual_3d
		vis.rotation = Vector3(sin(_t * 1.7) * 0.07 * sway, 0.0, sin(_t * 2.3) * 0.11 * sway)
	var showing := _t >= T_HAND - 0.05
	_hand_quad.visible = showing
	if not showing:
		return
	var collar := _hold + Vector3(0.0, LIFT + COLLAR, 0.0) - _cam.global_basis.z * 0.25
	if _t < T_HOOK:
		var k := clampf((_t - T_HAND) / (T_HOOK - T_HAND), 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)  # rushes down, slows to take him
		_nib = collar + Vector3(sin(_t * 2.0) * 0.15 * (1.0 - k), 15.0 * (1.0 - k), 0.0)
	elif _t < T_YANK:
		# a heave up, then it dips to wind up the yank
		var k := clampf((_t - T_HOOK) / (T_YANK - T_HOOK), 0.0, 1.0)
		_nib = collar + Vector3(0.0, 0.5 * sin(k * PI * 0.5) - 0.45 * smoothstep(0.65, 1.0, k), 0.0)
	else:
		var k := clampf((_t - T_YANK) / 0.35, 0.0, 1.0)
		_nib = collar + Vector3(0.0, 0.05 + 30.0 * k * k, 0.0)
	_hand.puppet_flex = -0.3 if _t < T_HOOK - 0.15 else 1.0
	_hand_mat.set_shader_parameter("alpha", clampf((_t - T_HAND) / 0.3, 0.0, 1.0))
	_hand_mat.set_shader_parameter("glow", 0.4 + _catch.flash)
	var right := _cam.global_basis.x
	var up := _cam.global_basis.y
	var u := NIB_PX.x / VIEW - 0.5
	var v := 0.5 - NIB_PX.y / VIEW
	_hand_quad.global_transform = Transform3D(_cam.global_basis, _nib - right * u * QUAD - up * v * QUAD - _cam.global_basis.z * 0.3)
	for p in _updraft:
		p.global_position = _caught_at + Vector3(0, 0.1, 0)


func _update_rings(delta: float) -> void:
	for r in _rings:
		r.age += delta
		var k: float = clampf(r.age / r.life, 0.0, 1.0)
		r.mi.scale = Vector3.ONE * lerpf(0.4, r.size, 1.0 - pow(1.0 - k, 3.0))
		r.mat.set_shader_parameter("intensity", (1.0 - k) * 1.4)
		if k >= 1.0:
			r.mi.queue_free()
	_rings = _rings.filter(func(r): return r.age < r.life)


func _update_room(_delta: float) -> void:
	if _dark and "darkness" in _dark:
		var d := lerpf(_dark0, 0.95, _k(T_SNUFF, T_SNUFF + 1.0))
		d = lerpf(d, 0.42, _k(T_CATCH + 0.1, T_LIFT + 0.3))
		_dark.darkness = d
	for c: CanvasItem in [_hud, _room.get("ui")]:
		if c:
			c.modulate.a = 1.0 - _k(0.0, 0.5)


# ----------------------------------------------------------------- camera

func _update_camera(delta: float) -> void:
	var s := _shot()
	var pitch := deg_to_rad(s.pitch)
	_cam.global_position = s.focus + Basis(Vector3.UP, s.yaw) * Vector3(0.0, sin(pitch), cos(pitch)) * s.dist
	_cam.rotation = Vector3(-pitch, s.yaw, 0.0)
	_cam.fov = s.fov
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var shake := _trauma * _trauma * 0.5
	_cam.h_offset = randf_range(-1.0, 1.0) * shake
	_cam.v_offset = randf_range(-1.0, 1.0) * shake


## The shot at the current time: from where the game's camera was, out wide
## for the lights, down low on the hunt, in close on the catch, then under
## him looking up the beam.
func _shot() -> Dictionary:
	var p := _vesper()
	var ground := Vector3(p.x, _caught_at.y, p.z)
	var wide := {"focus": ground.lerp(Vector3.ZERO, 0.5) + Vector3(0, 0.5, 0), "yaw": 0.0, "pitch": 52.0, "dist": 29.0, "fov": 40.0}
	var hunt := {"focus": ground + Vector3(0, 0.9, 0), "yaw": lerpf(-0.32, 0.1, _k(T_HUNT, T_CATCH)), "pitch": 40.0,
		"dist": lerpf(19.0, 16.0, _k(T_HUNT, T_CATCH)), "fov": 40.0}
	var caught := {"focus": ground + Vector3(0, 1.1, 0), "yaw": 0.12, "pitch": 33.0, "dist": 14.0, "fov": 42.0}
	var hold := _hold if _player and _player.cutscene_hold else ground
	# down by the floor looking up: he rises off it into the dark, the hand comes down
	var punch := sin(clampf((_t - T_HOOK) / 0.5, 0.0, 1.0) * PI) * 1.2  # in on the hook
	var up := {"focus": Vector3(hold.x, hold.y + 2.6 + (LIFT + 1.3) * _k(T_LIFT, T_HOOK), hold.z), "yaw": UP_YAW, "pitch": -8.0,
		"dist": UP_DIST - punch * 1.4, "fov": 54.0}
	var shot := _blend(_cam0, wide, _k(0.0, 2.6))
	shot = _blend(shot, hunt, _k(T_HUNT - 0.5, T_HUNT + 0.9))
	shot = _blend(shot, caught, _k(T_CATCH - 0.05, T_CATCH + 0.3))
	shot = _blend(shot, up, _k(T_LIFT - 0.4, T_HAND + 0.5))
	if _t > T_YANK:
		# whip up after him, too late
		var k := _k(T_YANK, T_GRAB)
		shot.focus += Vector3(0, 2.0 * k, 0)
		shot.pitch -= 7.0 * k
	return shot


func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if a.is_empty():
		return b
	return {"focus": (a.focus as Vector3).lerp(b.focus, k), "yaw": lerp_angle(a.yaw, b.yaw, k),
		"pitch": lerpf(a.pitch, b.pitch, k), "dist": lerpf(a.dist, b.dist, k), "fov": lerpf(a.fov, b.fov, k)}


# ----------------------------------------------------------------- screen

func _draw_screen() -> void:
	var s := _screen.size
	var bars := BAR * _k(0.0, 0.6)
	_screen.draw_rect(Rect2(0, 0, s.x, bars), Color.BLACK)
	_screen.draw_rect(Rect2(0, s.y - bars, s.x, bars), Color.BLACK)
	if _line != "" and _t < _line_end:
		_draw_balloon(s)
	if _flash > 0.0:
		_screen.draw_rect(Rect2(Vector2.ZERO, s), Color(_flash_color, minf(_flash, 1.0) * 0.85))
	if _t > T_GRAB and _cam:
		# the beam flares once he's gone, then whites out the screen
		var k := _k(T_GRAB, T_GRAB + 0.2)
		var x := _cam.unproject_position(_catch.pos + Vector3(0, 3.0, 0)).x
		var w := 90.0 + 170.0 * k
		var clear := Color(1.0, 0.93, 0.75, 0.0)
		var hot := Color(1.0, 0.95, 0.82, 0.75 * k)
		for side in [-1.0, 1.0]:
			_screen.draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + side * w, 0), Vector2(x + side * w, s.y), Vector2(x, s.y)]),
				PackedColorArray([hot, clear, clear, hot]))
		var white := _k(T_GRAB + 0.02, T_END)
		_screen.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.98, 0.93, white))


## Shade's black speech balloon (the final fight's), from above the frame.
func _draw_balloon(s: Vector2) -> void:
	var shown := _line.substr(0, int((_t - _line_t) * 30.0))
	var a := clampf((_line_end - _t) / 0.25, 0.0, 1.0)
	var size := 34
	var w := FONT.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# off to the left of the beam, where nothing is happening
	var box := Rect2(s.x * 0.3 - w * 0.5 - 30.0, BAR + 34.0, w + 60.0, 66.0)
	var jitter := Vector2(sin(_t * 41.0), cos(_t * 37.0)) * 1.2
	box.position += jitter
	# the tail runs up out of the frame: Shade is above all this
	var tail := PackedVector2Array([Vector2(box.position.x + box.size.x * 0.62, box.position.y + 2),
		Vector2(box.position.x + box.size.x * 0.62 + 34, box.position.y + 2), Vector2(box.position.x + box.size.x * 0.62 + 52, BAR - 4)])
	var rim := Color(0.85, 0.2, 0.25, a)
	_screen.draw_rect(box.grow(4), rim)
	_screen.draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(-5, 0), tail[1] + Vector2(5, 0), tail[2] + Vector2(3, -3)]), rim)
	_screen.draw_rect(box, Color(0.02, 0.01, 0.04, a))
	_screen.draw_colored_polygon(tail, Color(0.02, 0.01, 0.04, a))
	_screen.draw_string(FONT, box.position + Vector2(30, 47), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.86, 0.88, a))
	_screen.draw_string(FONT, box.position + Vector2(box.size.x - 88, box.size.y + 26), "- SHADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.35, 0.4, a))


# ----------------------------------------------------------------- finish

## The frame for the page, read once it's finished drawing (read straight
## from _process it can come back half-copied).
func _grab_frame() -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree():
		_grab = ImageTexture.create_from_image(get_viewport().get_texture().get_image())


## Hands over to the page on white: page_climb.gd gets the last frame (the
## beam alone, between the bars) and takes him up the comic page.
func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	PageClimb.start(get_tree(), null if skipped else _grab, BAR, skipped)
