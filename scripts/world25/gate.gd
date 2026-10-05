@tool
extends Node3D
## Gate between the Gutter's rooms. While monsters remain the way on is an
## unfinished pencil sketch: the path beyond the gate is a grey, see-through
## ghost with dashed edges (drawn_ghost.gdshader, the drawn bridges' look),
## its lanterns are cold and an invisible wall blocks it. When the room is
## cleared (room.gd calls open()) a line of light draws itself along the
## path from the room outwards (~0.8 s), the path fills in with colour
## behind it, the lanterns ignite, a soft chime plays and the wall goes.
## The line keeps pulsing gently, so open exits are easy to spot. Walking
## out through an open gate ink-wipes to `target_scene`, arriving at the
## gate there whose gate_id is `target_gate`.
##
## The gate's local -Z points out of the room. Styles:
##   THRESHOLD  a carved stone step jutting out over the void at a room
##              edge, with lanterns (leave a gap in the island edge for it)
##   DOORWAY    a trigger for walking into an archway (the hub's cave door):
##              the sketch fills the doorway until it opens

const Toon = preload("res://scripts/clearing/toon.gd")
const MARKS_SHADER = preload("res://shaders/world25/gate_marks.gdshader")
const GHOST_SHADER = preload("res://shaders/world25/drawn_ghost.gdshader")
const LIGHT_SHADER = preload("res://shaders/world25/gate_light.gdshader")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")

enum Style { THRESHOLD, DOORWAY }

const STEP_DEPTH := 2.4
const SLABS := 4
## Seconds the line of light takes to draw itself along the path.
const DRAW_TIME := 0.8

@export var gate_id := "north"
@export_file("*.tscn") var target_scene := ""
@export var target_gate := "south"
@export var style := Style.THRESHOLD:
	set(v):
		style = v
		_rebuild()
@export var width := 3.6:
	set(v):
		width = v
		_rebuild()
@export var stone := Color(0.42, 0.4, 0.44):
	set(v):
		stone = v
		_rebuild()
## Lantern flames once the way is open: white or pale gold, never red.
@export var lantern_color := Color(1.0, 0.9, 0.62):
	set(v):
		lantern_color = v
		_rebuild()
## Open from the start (no seal).
@export var always_open := false
## The way Vesper came in. The Gutter only goes forward, so this gate never
## opens; a moment after he arrives its sketched path rubs itself out,
## slab by slab, from the far end in.
@export var entry_only := false

var is_open := false

var _wall_shape: CollisionShape3D
var _used := false
var _slabs: Array = []  # [{solid, ghost, at: 0..1 along the path}]
var _flames: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _line_mat: ShaderMaterial
var _line: MeshInstance3D
var _glow: OmniLight3D
var _runes: MeshInstance3D
var _sketch: MeshInstance3D  # DOORWAY: the ghost filling the arch
var _progress := 0.0
var _time := 0.0

static var _chime: AudioStreamWAV


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("gate")
	_rebuild()
	if Engine.is_editor_hint():
		return
	if entry_only:
		_rub_out()
	elif always_open:
		open(false)


## Where a player arriving through this gate appears (inside the room).
func arrival_point() -> Vector3:
	return global_transform * Vector3(0, 0.05, 2.0 if style == Style.THRESHOLD else 1.6)


func open(animate := true) -> void:
	if is_open or entry_only:
		return
	is_open = true
	if animate:
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("gate_unlock")
	if _wall_shape:
		_wall_shape.set_deferred("disabled", true)
	if not animate or not is_inside_tree():
		_set_progress(1.0)
		return
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, DRAW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play_chime()
	if target_scene != "":
		Fx.burst(get_tree(), global_transform * Vector3(0, 0.6, -0.4), lantern_color, 10, 2.0)


## An entry gate's sketch rubbed away behind Vesper: no going back.
func _rub_out() -> void:
	await get_tree().create_timer(1.0, false).timeout
	if not is_inside_tree():
		return
	var order := _slabs.duplicate()
	order.sort_custom(func(a, b): return a.at > b.at)
	var delay := 0.0
	for s in order:
		var ghost: MeshInstance3D = s.ghost
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_callback(func(): Fx.burst(get_tree(), ghost.global_position + Vector3(0, 0.2, 0), Color(0.78, 0.78, 0.8), 5, 1.4))
		t.tween_property(ghost, "scale", Vector3(1.0, 0.05, 0.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(ghost.hide)
		delay += 0.12
	if _sketch:
		create_tween().tween_property(_sketch, "scale", Vector3(1.0, 0.02, 1.0), 0.4)
	if _line:
		_line.hide()


## 0 = sealed sketch .. 1 = drawn in, lit and glowing.
func _set_progress(v: float) -> void:
	_progress = v
	if _line_mat:
		_line_mat.set_shader_parameter("progress", v)
	for s in _slabs:
		var filled: bool = v >= s.at
		s.solid.visible = filled
		s.ghost.visible = not filled
	for i in _flames.size():
		# one lantern catches as the light passes, the other as it arrives
		var lit := v >= 0.35 + 0.5 * (i % 2)
		if lit and not _flames[i].visible and v < 1.0:
			Fx.burst(get_tree(), _flames[i].global_position, lantern_color, 6, 1.5)
		_flames[i].visible = lit
		_lights[i].visible = lit
	if _runes:
		_runes.visible = v >= 1.0
	if _sketch:
		_sketch.visible = v < 0.5
	if _glow:
		_glow.visible = v > 0.0


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	_slabs.clear()
	_flames.clear()
	_lights.clear()
	_runes = null
	_sketch = null
	var half := width * 0.5
	var ghost_mat := _ghost_material()
	if style == Style.THRESHOLD:
		# carved step jutting out of the room in slabs, a darker lip at the end;
		# each slab has a sketch twin shown until the light reaches it
		var d := STEP_DEPTH / SLABS
		for i in SLABS:
			var size := Vector3(width, 0.5, d * 0.97)
			var c := Vector3(0, -0.25, -d * (i + 0.5))
			var solid := Toon.part(root, Toon.box(size), stone.darkened(0.04 * (i % 2)), c, Vector3.ZERO, {"tile": 1.2, "moss": 0.15})
			_add_slab(root, solid, size, c, ghost_mat, (i + 0.5) / SLABS * 0.85)
		var lip_size := Vector3(width + 0.3, 0.6, 0.35)
		var lip_c := Vector3(0, -0.28, -STEP_DEPTH + 0.1)
		var lip := Toon.part(root, Toon.box(lip_size), stone.darkened(0.25), lip_c)
		_add_slab(root, lip, lip_size, lip_c, ghost_mat, 0.92)
		_runes = _marks(root, 0, Vector2(width * 0.85, 0.6), Vector3(0, 0.012, -0.9), Vector3(-90, 0, 0), lantern_color.lightened(0.3))
		for side in [-1, 1]:
			_lantern(root, Vector3(side * (half + 0.35), 0, -0.2))
		_build_line(root, STEP_DEPTH + 0.8, Vector3(0, 0.03, -STEP_DEPTH * 0.5 + 0.2))
	else:
		# the doorway: a sketch of a door standing in the arch until it opens
		var size := Vector3(width * 0.9, 2.4, 0.2)
		_sketch = MeshInstance3D.new()
		_sketch.mesh = Toon.box(size)
		var m: ShaderMaterial = ghost_mat.duplicate()
		m.set_shader_parameter("half_size", size * 0.5)
		_sketch.material_override = m
		_sketch.position = Vector3(0, 1.2, 0.3)
		_sketch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(_sketch)
		for side in [-1, 1]:
			_lantern(root, Vector3(side * (half + 0.9), 0, 0.9))
		_build_line(root, 3.2, Vector3(0, 0.03, 0.6))
	_set_progress(1.0 if is_open else 0.0)
	if Engine.is_editor_hint():
		return
	if style == Style.THRESHOLD:
		var floor_body := Toon.collider(root, Toon.box_shape(Vector3(width, 0.5, STEP_DEPTH)), Vector3(0, -0.25, -STEP_DEPTH * 0.5))
		floor_body.name = "Step"
		for side in [-1, 1]:
			Toon.collider(root, Toon.box_shape(Vector3(0.4, 3.0, STEP_DEPTH)), Vector3(side * (half + 0.2), 1.5, -STEP_DEPTH * 0.5))
	var wall := Toon.collider(root, Toon.box_shape(Vector3(width, 3.0, 0.4)), Vector3(0, 1.5, 0.1 if style == Style.THRESHOLD else 0.5))
	_wall_shape = wall.get_child(0)
	_wall_shape.disabled = is_open


## Grey pencil sketch: the drawn bridges' ghost, drained of colour.
func _ghost_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	m.set_shader_parameter("fill", Color(0.55, 0.55, 0.58))
	m.set_shader_parameter("line", Color(0.82, 0.82, 0.85))
	m.set_shader_parameter("fill_alpha", 0.16)
	return m


func _add_slab(root: Node3D, solid: MeshInstance3D, size: Vector3, center: Vector3, ghost_mat: ShaderMaterial, at: float) -> void:
	var ghost := MeshInstance3D.new()
	ghost.mesh = Toon.box(size)
	var m: ShaderMaterial = ghost_mat.duplicate()
	m.set_shader_parameter("half_size", size * 0.5)
	ghost.material_override = m
	ghost.position = center
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ghost)
	_slabs.append({"solid": solid, "ghost": ghost, "at": at})


## The line of light along the path (gate_light.gdshader) and a soft glow.
func _build_line(root: Node3D, length: float, center: Vector3) -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(1.1, length)
	_line_mat = ShaderMaterial.new()
	_line_mat.shader = LIGHT_SHADER
	_line_mat.set_shader_parameter("color", lantern_color.lightened(0.25))
	_line = MeshInstance3D.new()
	_line.mesh = q
	_line.material_override = _line_mat
	_line.position = center
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_line)
	if not Engine.is_editor_hint():
		_glow = OmniLight3D.new()
		_glow.light_color = lantern_color
		_glow.light_energy = 0.0
		_glow.omni_range = 3.5
		_glow.position = center + Vector3(0, 0.8, 0)
		root.add_child(_glow)


func _marks(root: Node3D, mode: int, size: Vector2, pos: Vector3, rot: Vector3, color: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mat := ShaderMaterial.new()
	mat.shader = MARKS_SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("color", color)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## A stone post with an iron cup: cold while sealed, a pale flame once open.
func _lantern(root: Node3D, pos: Vector3) -> void:
	Toon.part(root, Toon.box(Vector3(0.3, 1.1, 0.3)), stone.darkened(0.15), pos + Vector3(0, 0.55, 0), Vector3.ZERO, {"moss": 0.3})
	Toon.part(root, Toon.cylinder(0.24, 0.14, 0.2, 8), Color(0.16, 0.13, 0.18), pos + Vector3(0, 1.2, 0))
	var flame := Toon.billboard(root, FLAME_SHADER, Vector2(0.6, 0.8), pos + Vector3(0, 1.6, 0),
		{"outer_color": lantern_color, "core_color": lantern_color.lightened(0.6)})
	_flames.append(flame)
	var l := OmniLight3D.new()
	l.light_color = lantern_color
	l.light_energy = 1.3
	l.omni_range = 3.8
	l.position = pos + Vector3(0, 1.6, 0)
	l.visible = false
	root.add_child(l)
	_lights.append(l)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _glow == null:
		return
	_time += delta
	# the opened way keeps breathing
	_glow.light_energy = _progress * (0.9 + 0.35 * sin(_time * 2.4))


## A soft two-note chime, synthesised once and shared by every gate.
func _play_chime() -> void:
	if _chime == null:
		var rate := 22050
		var length := int(rate * 1.6)
		var data := PackedByteArray()
		data.resize(length * 2)
		for i in length:
			var t := float(i) / rate
			var second := maxf(t - 0.12, 0.0)
			var v := sin(TAU * 1046.5 * t) * exp(-t * 3.2) * 0.5 + sin(TAU * 2093.0 * t) * exp(-t * 5.0) * 0.12
			v += (sin(TAU * 1568.0 * second) * exp(-second * 2.8) * 0.45) if t > 0.12 else 0.0
			var s := int(clampf(v * 0.6 * minf(t / 0.004, 1.0), -1.0, 1.0) * 32767.0)
			data.encode_s16(i * 2, s)
		_chime = AudioStreamWAV.new()
		_chime.format = AudioStreamWAV.FORMAT_16_BITS
		_chime.mix_rate = rate
		_chime.stereo = false
		_chime.data = data
	var p := AudioStreamPlayer3D.new()
	p.stream = _chime
	p.volume_db = -6.0
	p.unit_size = 12.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_open or _used or target_scene == "":
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or ("dead" in player and player.dead):
		return
	var local := to_local(player.global_position)
	var through := -1.3 if style == Style.THRESHOLD else -0.2
	if absf(local.x) < width * 0.5 + 0.2 and local.z < through and local.z > -STEP_DEPTH - 1.0:
		_used = true
		var world := get_node_or_null("/root/World25")
		if world:
			world.go(target_scene, target_gate)
