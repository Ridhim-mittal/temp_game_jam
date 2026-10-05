extends Node3D
## A red-pen mark on the ground: the Red Pen's telegraph (red_pen_3d.gd).
##  - circle: a dashed red ring with a stab point in the middle; the ring
##    fills in as the stab comes. It's WET ink: any Writer's light (a
##    Flash, a lit lantern, the searchlight) reaching its centre DRIES it,
##    and a dried mark can't hold the stab.
##  - line: a dashed strike-through with an arrowhead; it fills in along
##    its length before the pen slashes down it.

const Light = preload("res://scripts/world25/light.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const WET := Color(0.95, 0.12, 0.16)
const DRY := Color(0.55, 0.38, 0.3)

enum Kind { CIRCLE, LINE }

var kind := Kind.CIRCLE
var radius := 1.6
var a := Vector3.ZERO  # line start (world)
var b := Vector3.ZERO  # line end (world)
var width := 0.9
var progress := 0.0   # 0..1, set by the pen
var wet := true
var can_dry := true

var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()
var _time := 0.0
var _fade := -1.0


func _ready() -> void:
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Move the circle (while it is still tracking the player).
func place(center: Vector3) -> void:
	global_position = Vector3(center.x, global_position.y, center.z)


func dry() -> void:
	if not wet:
		return
	wet = false
	Fx.pop_text(get_tree(), global_position + Vector3(0, 0.8, 0), "DRIED!", Color(1.0, 0.85, 0.5), 28)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.3, 0), DRY, 12, 2.5)


func fade_out() -> void:
	_fade = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _fade >= 0.0:
		_fade += delta
		if _fade > 0.35:
			queue_free()
			return
	if wet and can_dry and kind == Kind.CIRCLE and Light.is_lit(get_tree(), global_position + Vector3(0, 0.3, 0), true):
		dry()
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var alpha := 1.0 if _fade < 0.0 else 1.0 - _fade / 0.35
	var col := WET if wet else DRY
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == Kind.CIRCLE:
		_circle(col, alpha)
	else:
		_line(col, alpha)
	_mesh.surface_end()


func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	for p in [p0, p1, p2, p0, p2, p3]:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(p)


func _circle(col: Color, alpha: float) -> void:
	var n := 28
	var spin := _time * 0.8
	var r0 := radius - 0.09
	var r1 := radius + 0.09
	for i in n:
		if i % 2 == 1 and wet:
			continue  # dashed while wet; a dried ring is solid
		var t0 := spin + TAU * i / n
		var t1 := spin + TAU * (i + 1) / n
		_quad(Vector3(cos(t0) * r0, 0, sin(t0) * r0), Vector3(cos(t1) * r0, 0, sin(t1) * r0),
			Vector3(cos(t1) * r1, 0, sin(t1) * r1), Vector3(cos(t0) * r1, 0, sin(t0) * r1), Color(col, alpha))
	# fill grows towards the rim as the stab comes
	var fr := radius * clampf(progress, 0.0, 1.0)
	var fill := Color(col, alpha * (0.18 + 0.2 * progress))
	for i in n:
		var t0 := TAU * i / n
		var t1 := TAU * (i + 1) / n
		_mesh.surface_set_color(fill)
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_set_color(fill)
		_mesh.surface_add_vertex(Vector3(cos(t0) * fr, 0, sin(t0) * fr))
		_mesh.surface_set_color(fill)
		_mesh.surface_add_vertex(Vector3(cos(t1) * fr, 0, sin(t1) * fr))
	# the stab point: a little starburst cross
	var s := 0.35 + 0.08 * sin(_time * 12.0)
	for k in 4:
		var d := Vector3(cos(PI * 0.25 + k * PI * 0.5), 0, sin(PI * 0.25 + k * PI * 0.5))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		_quad(side, d * s + side, d * s - side, -side, Color(col.darkened(0.3), alpha))


func _line(col: Color, alpha: float) -> void:
	var la := to_local(a)
	var lb := to_local(b)
	var d := lb - la
	var length := d.length()
	if length < 0.01:
		return
	var dir := d / length
	var side := Vector3(-dir.z, 0, dir.x)
	var hw := 0.1
	# dashes along the line
	var k := 0.0
	var dash := 0.45
	while k < length - 0.5:
		var p0 := la + dir * k
		var p1 := la + dir * minf(k + dash, length - 0.5)
		_quad(p0 + side * hw, p1 + side * hw, p1 - side * hw, p0 - side * hw, Color(col, alpha))
		k += dash * 2.0
	# arrowhead at the end
	var tip := lb
	var back := lb - dir * 0.6
	_quad(back + side * 0.35, tip, tip, back - side * 0.35, Color(col, alpha))
	# the danger strip fills in from the start
	var f := clampf(progress, 0.0, 1.0)
	var e := la + dir * length * f
	var fw := width * 0.5
	_quad(la + side * fw, e + side * fw, e - side * fw, la - side * fw, Color(col, alpha * (0.15 + 0.15 * f)))
