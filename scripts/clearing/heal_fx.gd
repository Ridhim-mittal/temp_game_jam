extends Node3D
## What a heal looks and sounds like in the Margins (clearing_player.gd's
## "light or life": hold F to pour a third of the Ember into half a bottle):
##  - a ring of light inks itself in round his feet as the heal fills, eight
##    marks lighting as it passes them (heal_ring.gdshader)
##  - gold motes rise off the ring and spiral up into the Ember at his chest
##  - a soft tone rising with it, a chime and a drip when it lands
## Broken off (moved, hit, attacked): the ring cracks apart, the motes scatter
## and the tone dies with a fizzle. (Vesper's kneel is vesper_3d.gd's `heal`.)
##
##   fx.update(progress, feet, ember, delta, heal_time)  # every frame; -1 = not healing
##   fx.complete()                                       # the heal landed

const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const RingShader = preload("res://shaders/clearing/heal_ring.gdshader")
const GOLD := Color(1.0, 0.74, 0.32)
const MOTES := 18
const RING_RADIUS := 1.2

var _ring: MeshInstance3D
var _mat: ShaderMaterial
var _motes: Array[MeshInstance3D] = []
var _mote_data: Array[Dictionary] = []
var _hum: AudioStreamPlayer
var _active := false
var _progress := 0.0
var _fade := 0.0  # the ring's alpha
var _flash := 0.0
var _crack := 0.0
var _scatter := 0.0  # > 0: the motes fly apart (a broken-off heal)
var _feet := Vector3.ZERO
var _ember := Vector3.ZERO


func _ready() -> void:
	top_level = true
	_mat = ShaderMaterial.new()
	_mat.shader = RingShader
	_mat.set_shader_parameter("color", GOLD)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RING_RADIUS * 2.0 / 0.86  # the shader's ring sits at 0.86
	_ring = MeshInstance3D.new()
	_ring.mesh = plane
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_color = GOLD.lightened(0.25)
	mm.albedo_texture = _dot_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.16
	for i in MOTES:
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = mm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_motes.append(m)
		_mote_data.append({})
	_hum = AudioStreamPlayer.new()
	_hum.stream = SfxSynth.get_stream("heal_rise")
	_hum.bus = "SFX"
	add_child(_hum)


## A soft round dot for the motes.
func _dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex


func update(progress: float, feet: Vector3, ember: Vector3, delta: float, heal_time := 1.0) -> void:
	_feet = feet
	_ember = ember
	if progress >= 0.0 and not _active:
		_begin(heal_time)
	elif progress < 0.0 and _active:
		_break_off()
	if _active:
		_progress = progress
	_fade = move_toward(_fade, 1.0 if _active else 0.0, delta * (6.0 if _active else 2.2))
	_flash = move_toward(_flash, 0.0, delta * 2.4)
	_scatter = maxf(_scatter - delta, 0.0)
	_ring.visible = _fade > 0.01 or _flash > 0.01
	_ring.global_position = feet + Vector3(0, 0.04, 0)
	_mat.set_shader_parameter("progress", _progress)
	_mat.set_shader_parameter("alpha", maxf(_fade, _flash))
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("crack", _crack)
	_update_motes(delta)


## The heal landed: the circle flares, the motes pour in, a chime.
func complete() -> void:
	_active = false
	_progress = 1.0
	_crack = 0.0
	_flash = 1.0
	_fade = 0.0
	_hum.stop()
	SfxSynth.play(get_tree(), "heal_chime", -8.0)
	for d in _mote_data:
		d["life"] = 0.0  # they've all gone in


func _begin(heal_time: float) -> void:
	_active = true
	_progress = 0.0
	_crack = 0.0
	_scatter = 0.0
	for i in MOTES:
		_spawn_mote(i, randf())  # staggered, so the spiral is full at once
	_hum.pitch_scale = clampf(1.0 / maxf(heal_time, 0.2), 0.6, 2.0)  # the rise lasts the heal
	_hum.volume_db = -12.0
	_hum.play()


## Broken off: nothing spent (the player's rule), but you see it go.
func _break_off() -> void:
	_active = false
	_crack = 0.0
	create_tween().tween_method(func(v: float): _crack = v, 0.0, 1.0, 0.35)
	_scatter = 0.6
	for d in _mote_data:
		if d.get("life", 0.0) > 0.0:
			d["vel"] = Vector3(cos(d["a"]), 0.6, sin(d["a"])) * randf_range(2.0, 3.5)
	create_tween().tween_property(_hum, "volume_db", -40.0, 0.15)
	SfxSynth.play(get_tree(), "heal_fizzle", -14.0)


func _spawn_mote(i: int, along := 0.0) -> void:
	_mote_data[i] = {"a": randf() * TAU, "t": along, "speed": randf_range(0.9, 1.3), "life": 1.0, "vel": Vector3.ZERO}


func _update_motes(delta: float) -> void:
	var up := _ember - _feet
	for i in MOTES:
		var d: Dictionary = _mote_data[i]
		var m := _motes[i]
		if d.is_empty() or d.get("life", 0.0) <= 0.0:
			m.visible = false
			continue
		if _scatter > 0.0 and not _active:
			# flung outwards, falling and fading
			d["vel"] = d["vel"] + Vector3(0, -6.0, 0) * delta
			m.global_position += d["vel"] * delta
			d["life"] = d["life"] - delta * 2.0
			m.scale = Vector3.ONE * maxf(d["life"], 0.0)
			continue
		if not _active:
			d["life"] = 0.0
			continue
		# up the spiral: wide at the ring, tight and fast at the Ember
		d["t"] = d["t"] + delta * d["speed"] * (0.8 + 1.4 * _progress)
		if d["t"] >= 1.0:
			_spawn_mote(i)  # it went in; another rises off the ring
			d = _mote_data[i]
		var t: float = d["t"]
		var ease_in := t * t
		var a: float = d["a"] + t * 5.0
		var r := RING_RADIUS * (1.0 - ease_in)
		m.global_position = _feet + Vector3(cos(a) * r, 0.0, sin(a) * r) + up * ease_in + Vector3(0, 0.08 + sin(t * PI) * 0.35, 0)
		m.scale = Vector3.ONE * (0.6 + 0.6 * _progress) * sin(t * PI) * clampf(_fade * 1.5, 0.0, 1.0)
		m.visible = true
