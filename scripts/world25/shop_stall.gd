@tool
extends Node3D
## Quire's Curios: the little shop in the Spine (where Patch used to sit).
## An old ornate counter in dark navy wood, pale vines carved in its front
## round a dark arch (shop_carving.gdshader), a rolled lip along the top, a
## domed lamp of a shop bell at one end and Quire on the other: a pale,
## long-tailed paper creature sitting on the counter with a quill behind
## his ear. Wares on show (a Corkscrew Nib, a Prism Saber, a lit lantern, a
## stack of hats), a hanging sign, and a warm pool of light in the dark
## (group "glow"). Interact (E) opens the shop (room.gd open_overlay("shop");
## B anywhere does too). Faces +Z.

const Toon = preload("res://scripts/clearing/toon.gd")
const Interactable = preload("res://scripts/world25/interactable.gd")
const CARVING = preload("res://shaders/world25/shop_carving.gdshader")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const NAVY := Color(0.16, 0.17, 0.3)
const NAVY_LIGHT := Color(0.26, 0.28, 0.44)
const PALE := Color(0.82, 0.82, 0.9)
const GOLD := Color(0.95, 0.75, 0.3)
const STEEL := Color(0.84, 0.86, 0.9)
const SIZE := Vector3(2.8, 1.05, 1.0)

## The pool it carves in the darkness (darkness.gd).
var glow_radius := 3.6

var _quire: Node3D
var _tail: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("glow")
	_build()


func _build() -> void:
	var root := Toon.fresh_root(self)
	# the counter: carved front, plain sides and back, a heavy top
	var front := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(SIZE.x, SIZE.y)
	front.mesh = q
	var m := ShaderMaterial.new()
	m.shader = CARVING
	m.set_shader_parameter("aspect", SIZE.x / SIZE.y)
	front.material_override = m
	front.position = Vector3(0, SIZE.y * 0.5, SIZE.z * 0.5 + 0.005)
	root.add_child(front)
	Toon.part(root, Toon.box(SIZE), NAVY.darkened(0.15), Vector3(0, SIZE.y * 0.5, 0), Vector3.ZERO, {"outline": 0.035})
	Toon.part(root, Toon.box(Vector3(SIZE.x + 0.3, 0.14, SIZE.z + 0.25)), NAVY_LIGHT, Vector3(0, SIZE.y + 0.07, 0.04), Vector3.ZERO,
		{"outline": 0.035})
	# the rolled lip along the front and the scroll ends
	Toon.part(root, Toon.cylinder(0.09, 0.09, SIZE.x + 0.2, 14), NAVY_LIGHT, Vector3(0, SIZE.y + 0.03, SIZE.z * 0.5 + 0.16),
		Vector3(0, 0, 90), {"outline": 0.03})
	for side in [-1.0, 1.0]:
		Toon.part(root, Toon.cylinder(0.13, 0.13, 0.08, 16), NAVY_LIGHT, Vector3(side * (SIZE.x * 0.5 + 0.12), SIZE.y + 0.03, SIZE.z * 0.5 + 0.16),
			Vector3(0, 0, 90), {"outline": 0.03})
		Toon.part(root, Toon.cylinder(0.05, 0.05, 0.09, 10), PALE, Vector3(side * (SIZE.x * 0.5 + 0.13), SIZE.y + 0.03, SIZE.z * 0.5 + 0.16),
			Vector3(0, 0, 90), {"outline": 0.0})
	var top := SIZE.y + 0.14
	_build_dome(root, Vector3(-SIZE.x * 0.5 + 0.45, top, -0.05))
	_build_wares(root, top)
	_build_sign(root)
	_quire = Node3D.new()
	_quire.position = Vector3(SIZE.x * 0.5 - 0.5, top, 0.05)
	root.add_child(_quire)
	_build_quire(_quire)
	if Engine.is_editor_hint():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 1.3
	light.omni_range = 4.5
	light.position = Vector3(0, 2.2, 1.2)
	root.add_child(light)
	Toon.collider(root, Toon.box_shape(Vector3(SIZE.x + 0.3, 2.0, SIZE.z + 0.3)), Vector3(0, 1.0, 0))
	var shop := Node3D.new()
	shop.set_script(Interactable)
	shop.action = "shop"
	shop.prompt = "SHOP"
	shop.radius = 3.2
	shop.prompt_height = 2.6
	shop.position = Vector3(0, 0, 0.8)
	root.add_child(shop)


## A dark domed lamp with a knob and a ring of little beads (the bell end).
func _build_dome(root: Node3D, at: Vector3) -> void:
	Toon.part(root, Toon.cylinder(0.36, 0.4, 0.1, 18), NAVY_LIGHT, at + Vector3(0, 0.05, 0), Vector3.ZERO, {"outline": 0.025})
	var dome := Toon.part(root, Toon.sphere(0.36, 16, 8, true), NAVY.darkened(0.1), at + Vector3(0, 0.1, 0), Vector3.ZERO, {"outline": 0.03})
	dome.scale = Vector3(1, 0.85, 1)
	for k in 5:  # ribs over the dome
		var a := k * PI / 5.0
		var rib := Toon.part(root, Toon.cylinder(0.37, 0.37, 0.03, 18), NAVY_LIGHT, at + Vector3(0, 0.1, 0), Vector3(90, rad_to_deg(a), 0),
			{"outline": 0.0})
		rib.scale = Vector3(1, 1, 0.85)
	Toon.part(root, Toon.sphere(0.08, 10, 6), NAVY_LIGHT, at + Vector3(0, 0.46, 0), Vector3.ZERO, {"outline": 0.02})
	for k in 3:
		Toon.part(root, Toon.sphere(0.045, 8, 5), PALE, at + Vector3(-0.1 + k * 0.1, 0.56 + (0.03 if k == 1 else 0.0), 0), Vector3.ZERO,
			{"outline": 0.012})


## Things for sale laid out on the counter.
func _build_wares(root: Node3D, top: float) -> void:
	# the Prism Saber, leaning on a little stand, glowing
	var prism := Node3D.new()
	prism.position = Vector3(0.05, top + 0.05, -0.15)
	prism.rotation_degrees = Vector3(0, 0, -62)
	root.add_child(prism)
	Toon.part(prism, Toon.cylinder(0.03, 0.03, 0.22, 8), Color(0.2, 0.22, 0.3), Vector3(0, 0.11, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(prism, Toon.box(Vector3(0.16, 0.035, 0.06)), GOLD, Vector3(0, 0.24, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(prism, Toon.cylinder(0.045, 0.045, 0.6, 6), Color(0.7, 1.0, 0.97), Vector3(0, 0.56, 0), Vector3.ZERO,
		{"outline": 0.012, "emission": 0.8})
	Toon.part(prism, Toon.cylinder(0.0, 0.045, 0.16, 6), Color(0.7, 1.0, 0.97), Vector3(0, 0.94, 0), Vector3.ZERO,
		{"outline": 0.012, "emission": 0.8})
	# the Corkscrew Nib, lying flat
	var cork := Node3D.new()
	cork.position = Vector3(-0.55, top + 0.06, 0.2)
	cork.rotation_degrees = Vector3(0, 20, 90)
	root.add_child(cork)
	Toon.part(cork, Toon.cylinder(0.04, 0.045, 0.3, 10), Color(0.62, 0.4, 0.22), Vector3(0, 0.15, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(cork, Toon.cylinder(0.006, 0.06, 0.5, 10), STEEL, Vector3(0, -0.25, 0), Vector3.ZERO, {"outline": 0.012, "emission": 0.1})
	for k in 8:
		var t := float(k) / 8.0
		var a := t * TAU * 2.5
		var r := lerpf(0.055, 0.01, t)
		Toon.part(cork, Toon.box(Vector3(0.045, 0.018, 0.018)), STEEL.darkened(0.35), Vector3(cos(a) * r, -0.02 - t * 0.46, sin(a) * r),
			Vector3(0, -rad_to_deg(a), 30), {"outline": 0.0})
	# a stack of hats, each with its band
	var hats := [[Color(0.12, 0.1, 0.13), Color(0.85, 0.22, 0.16)], [Color(0.55, 0.09, 0.11), Color(0.08, 0.06, 0.08)],
		[Color(0.12, 0.16, 0.38), Color(0.95, 0.75, 0.25)]]
	for k in hats.size():
		var at := Vector3(0.62, top + k * 0.13, -0.2)
		Toon.part(root, Toon.cylinder(0.24, 0.23, 0.025, 18), hats[k][0], at + Vector3(0, 0.012, 0), Vector3(0, k * 25.0, 0), {"outline": 0.015})
		Toon.part(root, Toon.cylinder(0.13, 0.15, 0.1, 14), hats[k][0], at + Vector3(0, 0.07, 0), Vector3.ZERO, {"outline": 0.015})
		Toon.part(root, Toon.cylinder(0.152, 0.155, 0.03, 14), hats[k][1], at + Vector3(0, 0.04, 0), Vector3.ZERO, {"outline": 0.0})
	# a little lit lantern, like the Flail's
	var lamp := Vector3(-0.15, top, 0.3)
	Toon.part(root, Toon.box(Vector3(0.2, 0.03, 0.2)), Color(0.22, 0.2, 0.24), lamp + Vector3(0, 0.015, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(root, Toon.box(Vector3(0.2, 0.03, 0.2)), Color(0.22, 0.2, 0.24), lamp + Vector3(0, 0.3, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(root, Toon.sphere(0.07, 10, 6), Color(1.0, 0.82, 0.42), lamp + Vector3(0, 0.16, 0), Vector3.ZERO, {"outline": 0.0, "emission": 2.0})
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		Toon.part(root, Toon.box(Vector3(0.025, 0.28, 0.025)), Color(0.22, 0.2, 0.24), lamp + Vector3(cos(a) * 0.09, 0.16, sin(a) * 0.09),
			Vector3.ZERO, {"outline": 0.006})


## A board hung from a bracket over the counter: QUIRE'S CURIOS.
func _build_sign(root: Node3D) -> void:
	var wood := Color(0.28, 0.2, 0.16)
	var post := Vector3(SIZE.x * 0.5 + 0.35, 0, -0.35)
	Toon.part(root, Toon.box(Vector3(0.12, 2.9, 0.12)), wood, post + Vector3(0, 1.45, 0), Vector3.ZERO, {"bark": 0.5, "line": wood.darkened(0.5)})
	Toon.part(root, Toon.box(Vector3(1.6, 0.08, 0.08)), wood, post + Vector3(-0.75, 2.8, 0), Vector3.ZERO, {"outline": 0.02})
	var board := Vector3(post.x - 0.95, 2.35, post.z + 0.05)
	for x in [-0.55, 0.55]:
		Toon.part(root, Toon.box(Vector3(0.02, 0.4, 0.02)), Color(0.3, 0.3, 0.34), board + Vector3(x, 0.25, 0), Vector3.ZERO, {"outline": 0.0})
	Toon.part(root, Toon.box(Vector3(1.4, 0.42, 0.06)), Color(0.86, 0.82, 0.72), board, Vector3(0, 0, 2), {"outline": 0.03})
	var label := Label3D.new()
	label.text = "QUIRE'S CURIOS"
	label.font = TITLE_FONT
	label.font_size = 64
	label.pixel_size = 0.0042
	label.modulate = NAVY.darkened(0.2)
	label.outline_size = 0
	label.position = board + Vector3(0, 0.02, 0.035)
	label.rotation_degrees = Vector3(0, 0, 2)
	root.add_child(label)


## Quire: a pale paper creature sitting on the counter, legs dangling over
## the front, a long tail curling down the side, a quill behind his ear.
func _build_quire(q: Node3D) -> void:
	var skin := Color(0.84, 0.84, 0.9)
	var body := Toon.part(q, Toon.sphere(0.24, 14, 8), skin, Vector3(0, 0.3, 0), Vector3.ZERO, {"outline": 0.03})
	body.scale = Vector3(0.9, 1.25, 0.85)
	for side in [-1.0, 1.0]:  # legs over the edge
		var leg := Toon.part(q, Toon.cylinder(0.05, 0.04, 0.4, 8), skin.darkened(0.08), Vector3(side * 0.1, 0.02, 0.35), Vector3(-75, 0, 0),
			{"outline": 0.02})
		leg.scale = Vector3.ONE
		Toon.part(q, Toon.sphere(0.06, 8, 5), skin.darkened(0.15), Vector3(side * 0.1, -0.12, 0.52), Vector3.ZERO, {"outline": 0.015})
	var head := Toon.part(q, Toon.sphere(0.2, 14, 8), skin, Vector3(0, 0.72, 0.02), Vector3.ZERO, {"outline": 0.03})
	head.scale = Vector3(1.0, 1.15, 0.95)
	# a long pointed snout, two black eyes, a little mouth
	Toon.part(q, Toon.cylinder(0.0, 0.07, 0.22, 10), skin.darkened(0.05), Vector3(0, 0.66, 0.24), Vector3(90, 0, 0), {"outline": 0.02})
	for side in [-1.0, 1.0]:
		var eye := Toon.part(q, Toon.sphere(0.04, 8, 5), Color(0.05, 0.04, 0.08), Vector3(side * 0.08, 0.78, 0.16), Vector3.ZERO, {"outline": 0.0})
		eye.scale = Vector3(0.8, 1.3, 0.6)
	# the quill behind his ear
	Toon.part(q, Toon.cylinder(0.01, 0.012, 0.42, 6), Color(0.95, 0.93, 0.86), Vector3(0.14, 0.95, -0.02), Vector3(0, 0, -30), {"outline": 0.01})
	Toon.part(q, Toon.box(Vector3(0.07, 0.28, 0.012)), Color(0.55, 0.85, 1.0), Vector3(0.2, 1.05, -0.02), Vector3(0, 0, -30), {"outline": 0.01})
	# arms resting on his knees
	for side in [-1.0, 1.0]:
		Toon.part(q, Toon.cylinder(0.035, 0.03, 0.3, 8), skin.darkened(0.06), Vector3(side * 0.2, 0.3, 0.18), Vector3(-50, 0, side * 20.0),
			{"outline": 0.015})
	# the tail: a chain of shrinking beads curling down the counter's side
	_tail.clear()
	for k in 12:
		var t := float(k) / 11.0
		var bead := Toon.part(q, Toon.sphere(lerpf(0.09, 0.03, t), 8, 5), skin.darkened(0.06 * (k % 2)), Vector3.ZERO, Vector3.ZERO,
			{"outline": 0.015})
		_tail.append(bead)
	_pose_tail(0.0)


func _pose_tail(sway: float) -> void:
	for k in _tail.size():
		var t := float(k) / (_tail.size() - 1)
		var a := t * 4.2 + sway * t
		var r := lerpf(0.22, 0.08, t)
		_tail[k].position = Vector3(0.25 + t * 0.35 + cos(a) * r * 0.4, 0.2 - t * 0.75 + sin(a) * r, -0.1 + sin(a) * 0.05)


func _process(delta: float) -> void:
	if _quire == null or Engine.is_editor_hint():
		return
	_time += delta
	_quire.rotation.z = sin(_time * 1.3) * 0.04
	_pose_tail(sin(_time * 1.7) * 0.6)
