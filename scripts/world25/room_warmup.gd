extends Node
## In a browser a 2.5D room's first frame used to stop the game for seconds
## (in the hub ~7 s, worse on some machines): WebGL compiles every shader the
## room draws the first time it's drawn, 170 programs in the hub (most
## materials need a shadow copy, an instanced copy and lit / unlit ones). This
## spreads that over many frames while the transition still covers the
## screen: every mesh is moved onto a layer nothing sees (`HIDE`), a camera
## above the whole room looks straight down, and the meshes come back a few
## materials at a time, more per frame while frames stay quick; then the
## room's own camera has a look and everything is put back as it was.
##
## room.gd begins it at the end of its _ready (`warming`, `warmed`), before
## the first frame; World25.go() and gutter_transition.gd keep their cover up
## (and the tree paused) until it's done, with `paint_wait()` on it. Entered
## any other way (CONTINUE, a retry) it pauses the room under a cover of its own.
## Only in a browser: desktop drivers compile fast (`force` for tests).

signal done

## Layer 20: nothing in the game uses it.
const HIDE := 1 << 19
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
## Give up and show everything after this long (seconds).
const MAX_TIME := 25.0

static var force := false

var _room: Node3D
var _groups: Array = []
var _cam: Camera3D
var _lights := {}  # Light3D -> its cull mask
var _sun_dist := {}  # DirectionalLight3D -> its shadow max distance
var _cams := {}  # the room's Camera3Ds -> their cull masks
var _step := 2
var _last := 0
var _stage := -1
var _frames := 0
var _t := 0.0
var _cover: CanvasLayer  # its own, when no transition covers the room
var _wait: Control


static func wanted() -> bool:
	return force or OS.has_feature("web")


## Hide everything now (room._ready, before anything is drawn).
func begin(room: Node3D) -> void:
	_room = room
	name = "Warmup"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in room.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.layers & HIDE:
			continue
		g.set_meta(&"warm_layers", g.layers)
		g.layers = HIDE
	for n in room.find_children("*", "Light3D", true, false):
		_lights[n] = n.light_cull_mask
		n.light_cull_mask &= ~HIDE
	for n in room.find_children("*", "Camera3D", true, false):
		_cams[n] = n.cull_mask
		n.cull_mask &= ~HIDE
	_cam = Camera3D.new()
	_cam.name = "WarmupCamera"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.cull_mask = 0xFFFFF & ~HIDE
	add_child(_cam)
	room.add_child(self)
	_cam.make_current()
	var world := room.get_node_or_null("/root/World25")
	if world == null or not world.transitioning:
		_own_cover()
	_last = Time.get_ticks_msec()


func _own_cover() -> void:
	_cover = CanvasLayer.new()
	_cover.layer = 96
	var black := ColorRect.new()
	black.color = Color(0.03, 0.02, 0.05)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(black)
	_wait = Control.new()
	_wait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wait.draw.connect(func(): paint_wait(_wait, _wait.size, _t, clampf(_t * 3.0, 0.0, 1.0)))
	_cover.add_child(_wait)
	add_child(_cover)
	get_tree().paused = true


func _process(delta: float) -> void:
	_t += delta
	if _wait:
		_wait.queue_redraw()
	var now := Time.get_ticks_msec()
	var ms := now - _last
	_last = now
	match _stage:
		-1:  # after the props' deferred merges: what's hidden, grouped by material
			_gather()
			_stage = 0
		0:
			if ms < 70:
				_step = mini(_step * 2, 64)
			elif ms > 200:
				_step = maxi(1, _step / 2)
			for i in _step:
				if _groups.is_empty():
					break
				for g in _groups.pop_back():
					_show(g)
			if _groups.is_empty() or _t > MAX_TIME:
				_stage = 1
				_frames = 0
		1:  # the room's own view, for anything only it sees
			_frames += 1
			if _frames == 2:
				_restore_view()
			if _frames >= 4:
				_finish()


## Everything still hidden, in groups that share a material: one group's
## first draw compiles that material's shaders.
func _gather() -> void:
	var groups := {}
	var box := AABB()
	var first := true
	for n in _room.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.layers != HIDE:
			continue
		var k := _key(g)
		if not groups.has(k):
			groups[k] = []
		groups[k].append(g)
		var bb := g.global_transform * g.get_aabb()
		if bb.size.length() < 2000.0:
			box = bb if first else box.merge(bb)
			first = false
	_groups = groups.values()
	# straight down onto all of it
	var c := box.get_center()
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp:
		var s := vp.get_visible_rect().size
		aspect = s.x / maxf(s.y, 1.0)
	_cam.size = maxf(box.size.z, box.size.x / aspect) * 1.1 + 2.0
	_cam.near = 0.05
	_cam.far = box.size.y + 40.0
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(c.x, box.end.y + 20.0, c.z))
	for l in _lights:
		if l is DirectionalLight3D and is_instance_valid(l):
			_sun_dist[l] = l.directional_shadow_max_distance
			l.directional_shadow_max_distance = maxf(l.directional_shadow_max_distance, _cam.far + box.size.length())


func _key(g: GeometryInstance3D) -> String:
	if g is SpriteBase3D or g is Label3D:
		return "%s %d %d %d %d %d" % [g.get_class(), g.billboard, int(g.shaded), int(g.double_sided), g.alpha_cut, int(g.no_depth_test)]
	var m: Material = g.material_override
	if m == null and g is MeshInstance3D and g.mesh and g.mesh.get_surface_count() > 0:
		m = (g as MeshInstance3D).get_active_material(0)
	var key := "%s %d" % [g.get_class(), g.cast_shadow]
	while m:
		key += " %d" % (m.shader.get_instance_id() if m is ShaderMaterial and m.shader else m.get_instance_id())
		m = m.next_pass
	return key


func _show(g: GeometryInstance3D) -> void:
	if is_instance_valid(g) and g.layers == HIDE:
		g.layers = g.get_meta(&"warm_layers", 1)


func _restore_view() -> void:
	for l in _sun_dist:
		if is_instance_valid(l):
			l.directional_shadow_max_distance = _sun_dist[l]
	_sun_dist.clear()
	for c in _cams:
		if is_instance_valid(c):
			c.cull_mask = _cams[c]
	var cam: Camera3D = null
	for c in get_tree().get_nodes_in_group("camera"):
		if c is Camera3D:
			cam = c
	if cam == null:
		for c in _cams:
			if is_instance_valid(c):
				cam = c
	if cam:
		cam.make_current()


func _finish() -> void:
	for n in _room.find_children("*", "GeometryInstance3D", true, false):
		if n.layers & HIDE:  # anything left (made while hiding, or out of time)
			n.layers = n.get_meta(&"warm_layers", 1) if n.layers == HIDE else n.layers & ~HIDE
	for l in _lights:
		if is_instance_valid(l):
			l.light_cull_mask = _lights[l]
	_restore_view()
	set_process(false)
	if _cover:
		get_tree().paused = false
	done.emit()
	queue_free()


## Three ink drops filling and spilling in turn, and "INKING...", bottom right:
## the cover is waiting, not stuck.
static func paint_wait(ci: CanvasItem, size: Vector2, t: float, alpha := 1.0) -> void:
	var paper := Color(0.97, 0.94, 0.86, 0.9 * alpha)
	var base := size - Vector2(64, 46)
	ci.draw_string(FONT, base + Vector2(-150, 9), "INKING", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, paper)
	for i in 3:
		var k := fmod(t * 1.6 - i * 0.28, 1.0)
		var r := 3.0 + 5.0 * sin(clampf(k, 0.0, 1.0) * PI)
		ci.draw_circle(base + Vector2(-58 + i * 22, -2.0 * sin(k * PI)), r, paper)
