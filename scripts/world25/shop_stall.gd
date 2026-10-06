@tool
extends Node3D
## Quire's Curios: the shop in the Spine (where Patch used to sit), and the
## biggest, brightest thing in it. A giant book stands open on its end: its
## navy covers are the shop's two walls (7 m across, 4.6 m tall), the page
## blocks inside them have shelves cut into them, full of wares, its pages
## fan up out of the top like a crown under the sign, a red ribbon hangs down
## its gutter, and loose pages peel off and circle it and never land. In the
## gutter stands the old carved counter (shop_carving.gdshader) with its
## domed bell and more wares, and at the end of it, where a shopkeeper comes
## round to meet you, hovers Quire (quire_ghost.gd): a tall slim ghost, a character the Writer
## never finished, half of him inked and half only pencil guides, fading while he is alone and drawn in when Vesper
## comes near. His head follows Vesper while his quill scribbles in a ledger
## that floats beside him. It is an old shop in a dead
## place, and a little gloomy: dark boards, tarnished gilt, yellowed pages
## that ink has run down, two of the crown's pages hanging torn, lanterns
## burning low off the covers (one guttering), a dim pool of light in the
## dark (group "glow"). Interact (E) opens the shop (room.gd open_overlay("shop"); B
## anywhere does too). Faces +Z.

const Toon = preload("res://scripts/clearing/toon.gd")
const Interactable = preload("res://scripts/world25/interactable.gd")
const QuireGhost = preload("res://scripts/world25/quire_ghost.gd")
const CARVING = preload("res://shaders/world25/shop_carving.gdshader")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const NAVY := Color(0.1, 0.11, 0.2)
const NAVY_LIGHT := Color(0.18, 0.19, 0.31)
const PALE := Color(0.7, 0.7, 0.78)
const GOLD := Color(0.64, 0.5, 0.24)  # tarnished
const STEEL := Color(0.84, 0.86, 0.9)
const PAGE := Color(0.66, 0.62, 0.53)  # yellowed, grey with dust
const RIBBON := Color(0.52, 0.09, 0.1)
const STAIN := Color(0.07, 0.05, 0.1)
const SIZE := Vector3(3.4, 1.05, 1.0)
## The book: where its spine stands (behind the counter), how far its covers
## are swung open (degrees, each), and a cover's length, height and thickness.
const SPINE := Vector3(0, 0, -1.55)
const OPEN_DEG := 25.0
const COVER := Vector3(3.7, 4.6, 0.16)
## How big Quire is (1 = Vesper-sized).
const QUIRE_SCALE := 1.55

## The pool it carves in the darkness (darkness.gd).
var glow_radius := 5.0
## The camera frames the whole shop as Vesper comes up to it
## (clearing_camera.gd, group "camera_frame").
var frame_point := Vector3.ZERO
var frame_radius := 11.0
var frame_pull := 0.55
var frame_zoom := 6.5

var _quire: Node3D
var _ghost: Node3D   # Quire himself (quire_ghost.gd); not built in the editor
var _ledger: Node3D
var _quill: Node3D
var _fan: Array[Node3D] = []     # the pages standing up out of the book
var _loose: Array[Node3D] = []   # the ones that got away
var _ribbon: Node3D
var _lanterns: Array[Node3D] = []
var _flames: Array[Node3D] = []  # their lights (one is nearly out)
var _sign: Label3D
var _time := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("glow")
		add_to_group("camera_frame")
		frame_point = global_position + Vector3(0, 2.6, -0.6)
	_build()


func _build() -> void:
	var root := Toon.fresh_root(self)
	_build_book(root)
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
	_quire.position = Vector3(2.4, 0.12, 0.8)  # at the end of the counter, on the floor (well: just off it)
	_quire.rotation.y = -0.4  # turned to whoever comes up to it
	_quire.scale = Vector3.ONE * QUIRE_SCALE
	root.add_child(_quire)
	_build_quire(_quire)
	# one mesh per material for the still parts (far fewer draw calls); what
	# _process() moves stays as it is
	Toon.merge_when_built(root, [_quire, _ledger, _quill, _ribbon] + _fan + _loose + _lanterns + _flames)
	if Engine.is_editor_hint():
		return
	for at: Vector3 in [Vector3(0, 3.0, 1.8), Vector3(-2.6, 2.6, 0.6), Vector3(2.6, 2.6, 0.6)]:
		var light := OmniLight3D.new()
		light.light_color = Color(0.9, 0.68, 0.46)  # low and tired: the shop keeps to itself in the dark
		light.light_energy = 0.95 if at.x == 0.0 else 0.4
		light.omni_range = 6.5 if at.x == 0.0 else 3.8
		light.position = at
		root.add_child(light)
	Toon.collider(root, Toon.box_shape(Vector3(SIZE.x + 0.3, 2.0, SIZE.z + 0.3)), Vector3(0, 1.0, 0))
	for side: float in [-1.0, 1.0]:  # the covers are walls
		var mid := SPINE + Vector3(side * cos(deg_to_rad(OPEN_DEG)), 0, sin(deg_to_rad(OPEN_DEG))) * COVER.x * 0.5
		Toon.collider(root, Toon.box_shape(Vector3(COVER.x, COVER.y, 0.7)), mid + Vector3(0, COVER.y * 0.5, 0.12), Vector3(0, -side * OPEN_DEG, 0))
	var shop := Node3D.new()
	shop.set_script(Interactable)
	shop.action = "shop"
	shop.prompt = "SHOP"
	shop.radius = 3.6
	shop.prompt_height = 2.3
	shop.position = Vector3(-1.2, 0, 1.4)  # (the prompt hangs over the bell end, clear of Quire)
	root.add_child(shop)


## The giant book the shop lives in, standing open on its end: two covers
## for walls, a page block inside each with shelves cut into it, the spine
## behind the counter, its pages fanned up out of the top, a ribbon down the
## gutter, a lantern hanging off each cover, and the pages that got away.
func _build_book(root: Node3D) -> void:
	_lanterns.clear()
	_flames.clear()
	# the page it stands on: one great sheet laid on the ground (no step up)
	Toon.part(root, Toon.box(Vector3(8.4, 0.04, 4.4)), PAGE.darkened(0.62), Vector3(0, 0.02, 0.0), Vector3(0, 3, 0), {"outline": 0.0})
	for k in 7:
		Toon.part(root, Toon.box(Vector3(7.4, 0.005, 0.03)), PAGE.darkened(0.76), Vector3(0, 0.045, -1.7 + k * 0.6), Vector3(0, 3, 0), {"outline": 0.0})
	# the spine: dark boards, raised gilt bands
	Toon.part(root, Toon.box(Vector3(0.62, COVER.y + 0.1, 0.34)), NAVY.darkened(0.3), SPINE + Vector3(0, COVER.y * 0.5 + 0.05, -0.12), Vector3.ZERO,
		{"outline": 0.04})
	for k in 5:
		Toon.part(root, Toon.box(Vector3(0.68, 0.09, 0.4)), GOLD.darkened(0.15), SPINE + Vector3(0, 0.5 + k * 0.95, -0.12), Vector3.ZERO, {"outline": 0.02})
	# the gutter, seen from the front: sewn signatures
	Toon.part(root, Toon.box(Vector3(0.5, COVER.y - 0.3, 0.3)), PAGE.darkened(0.12), SPINE + Vector3(0, COVER.y * 0.5, 0.14), Vector3.ZERO,
		{"outline": 0.03, "pages": 1.0})
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = SPINE
		wing.rotation_degrees.y = -side * OPEN_DEG
		root.add_child(wing)
		_build_wing(wing, side)
	# the ribbon bookmark, hanging down the gutter
	_ribbon = Node3D.new()
	_ribbon.position = SPINE + Vector3(0.05, COVER.y + 0.05, 0.32)
	root.add_child(_ribbon)
	Toon.part(_ribbon, Toon.box(Vector3(0.26, 2.3, 0.03)), RIBBON, Vector3(0, -1.15, 0), Vector3.ZERO, {"outline": 0.02})
	for half: float in [-1.0, 1.0]:  # its swallow-tail end
		Toon.part(_ribbon, Toon.prism(Vector3(0.13, 0.24, 0.03)), RIBBON, Vector3(half * 0.065, -2.42, 0), Vector3(0, 0, 180), {"outline": 0.02})
	# its pages, fanned up out of the top like a crown
	_fan.clear()
	for k in 9:
		var leaf := Node3D.new()
		leaf.position = SPINE + Vector3(0, COVER.y - 0.25, 0.1)
		leaf.rotation_degrees = Vector3(0, 0, (k - 4) * 15.0)
		root.add_child(leaf)
		var torn := k == 1 or k == 6  # two hang forward, torn short and stained
		Toon.part(leaf, Toon.box(Vector3(1.5, 1.5 if torn else 2.3, 0.025)), PAGE.darkened(0.3) if torn else (PAGE.lightened(0.04) if k % 2 == 0 else PAGE.darkened(0.1)),
			Vector3(0, 0.75 if torn else 1.15, 0.12 if torn else 0.0), Vector3(-34 if torn else -14, 0, 0), {"outline": 0.025})
		for line in (0 if torn else 5):  # a few ruled lines of writing on each whole one
			Toon.part(leaf, Toon.box(Vector3(1.0 - (line % 3) * 0.2, 0.03, 0.01)), PAGE.darkened(0.45), Vector3(-0.1 * (line % 2), 0.75 + line * 0.3, 0.04 - (0.75 + line * 0.3 - 1.15) * 0.25),
				Vector3(-14, 0, 0), {"outline": 0.0})
		_fan.append(leaf)
	# the ones that got away: they circle the shop and never land
	_loose.clear()
	for k in 8:
		var sheet := Toon.part(root, Toon.box(Vector3(0.42, 0.012, 0.56)), PAGE.darkened(0.12 + (k % 3) * 0.1), Vector3.ZERO, Vector3.ZERO, {"outline": 0.018})
		_loose.append(sheet)
	_fly_pages()


## One half of the book (`side` -1 left, 1 right; local +x * side runs out
## along the cover from the spine, local +z faces the customers): the cover
## with its gilt corners, the block of pages on it, the shelves cut into the
## pages and what stands on them, and the lantern hung off its end.
func _build_wing(wing: Node3D, side: float) -> void:
	var half := COVER.x * 0.5
	Toon.part(wing, Toon.box(COVER), NAVY, Vector3(side * half, COVER.y * 0.5, 0), Vector3.ZERO, {"outline": 0.05})
	for corner: Vector2 in [Vector2(COVER.x - 0.22, 0.24), Vector2(COVER.x - 0.22, COVER.y - 0.24)]:  # gilt corner pieces
		Toon.part(wing, Toon.box(Vector3(0.5, 0.5, COVER.z + 0.05)), GOLD, Vector3(side * corner.x, corner.y, 0), Vector3.ZERO, {"outline": 0.02})
	Toon.part(wing, Toon.box(Vector3(COVER.x - 0.5, COVER.y - 0.5, 0.02)), NAVY_LIGHT, Vector3(side * half, COVER.y * 0.5, -COVER.z * 0.5 - 0.01), Vector3.ZERO,
		{"outline": 0.0})  # a tooled panel on the outside
	# the block of pages
	var block := Vector3(COVER.x - 0.4, COVER.y - 0.36, 0.5)
	var face := COVER.z * 0.5 + block.z
	Toon.part(wing, Toon.box(block), PAGE, Vector3(side * (half - 0.08), COVER.y * 0.5, COVER.z * 0.5 + block.z * 0.5), Vector3.ZERO,
		{"outline": 0.04, "pages": 1.0})
	# shelves cut into it: a dark niche, a plank, a gilt label under it
	var niches := [Vector2(1.05, 3.25), Vector2(2.55, 3.25), Vector2(1.05, 2.05), Vector2(2.55, 2.05)]
	for i in niches.size():
		var n: Vector2 = niches[i]
		var at := Vector3(side * n.x, n.y, face)
		Toon.part(wing, Toon.box(Vector3(1.2, 0.95, 0.04)), NAVY.darkened(0.55), at + Vector3(0, 0, -0.005), Vector3.ZERO, {"outline": 0.0})
		Toon.part(wing, Toon.box(Vector3(1.3, 0.07, 0.34)), Color(0.34, 0.24, 0.18), at + Vector3(0, -0.5, 0.12), Vector3.ZERO, {"outline": 0.025})
		Toon.part(wing, Toon.box(Vector3(0.5, 0.11, 0.02)), GOLD, at + Vector3(0, -0.62, 0.02), Vector3.ZERO, {"outline": 0.0})
		_build_shelf(wing, at + Vector3(0, -0.46, 0.14), int(i + (4 if side > 0.0 else 0)))
	# ink has run down the pages, and dried
	for k in 5:
		var run := 0.5 + (k * 37 % 5) * 0.22
		var x := side * (0.45 + k * 0.72)
		Toon.part(wing, Toon.box(Vector3(0.05 + (k % 2) * 0.03, run, 0.012)), STAIN, Vector3(x, COVER.y - 0.2 - run * 0.5, face + 0.008), Vector3.ZERO, {"outline": 0.0})
		Toon.part(wing, Toon.sphere(0.06 + (k % 2) * 0.02, 8, 5), STAIN, Vector3(x, COVER.y - 0.2 - run, face + 0.005), Vector3.ZERO, {"outline": 0.0})
	# lines of writing down the rest of the page
	for k in 5:
		Toon.part(wing, Toon.box(Vector3(2.6 - (k % 2) * 0.5, 0.045, 0.01)), PAGE.darkened(0.4), Vector3(side * (1.75 - (k % 2) * 0.25), 1.2 - k * 0.2, face + 0.005),
			Vector3.ZERO, {"outline": 0.0})
	# a lantern on a bracket off the cover's end
	var hook := Vector3(side * (COVER.x - 0.1), COVER.y - 0.5, 0.5)
	Toon.part(wing, Toon.box(Vector3(0.07, 0.07, 0.9)), Color(0.2, 0.19, 0.24), hook + Vector3(0, 0.1, -0.25), Vector3.ZERO, {"outline": 0.02})
	var lamp := Node3D.new()
	lamp.position = hook + Vector3(0, 0.08, 0.15)
	wing.add_child(lamp)
	Toon.part(lamp, Toon.cylinder(0.008, 0.008, 0.5, 5), Color(0.2, 0.19, 0.24), Vector3(0, -0.25, 0), Vector3.ZERO, {"outline": 0.0})
	Toon.part(lamp, Toon.cylinder(0.05, 0.19, 0.12, 8), Color(0.2, 0.19, 0.24), Vector3(0, -0.52, 0), Vector3.ZERO, {"outline": 0.02})
	_flames.append(Toon.part(lamp, Toon.sphere(0.15, 12, 8), Color(0.95, 0.7, 0.36), Vector3(0, -0.72, 0), Vector3.ZERO, {"outline": 0.0, "emission": 1.3}))
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		Toon.part(lamp, Toon.box(Vector3(0.025, 0.36, 0.025)), Color(0.2, 0.19, 0.24), Vector3(cos(a) * 0.17, -0.74, sin(a) * 0.17), Vector3.ZERO, {"outline": 0.0})
	Toon.part(lamp, Toon.cylinder(0.19, 0.19, 0.04, 8), Color(0.2, 0.19, 0.24), Vector3(0, -0.93, 0), Vector3.ZERO, {"outline": 0.02})
	_lanterns.append(lamp)


## What stands on shelf `which` (`at` = the middle of its plank): the things
## Quire sells, one kind to a shelf.
func _build_shelf(wing: Node3D, at: Vector3, which: int) -> void:
	match which:
		0:  # hats
			var hats := [[Color(0.55, 0.09, 0.11), Color(0.08, 0.06, 0.08)], [Color(0.92, 0.9, 0.82), Color(0.2, 0.2, 0.26)], [Color(0.12, 0.16, 0.38), GOLD]]
			for k in hats.size():
				var h := at + Vector3(-0.38 + k * 0.38, 0, 0)
				Toon.part(wing, Toon.cylinder(0.17, 0.165, 0.02, 14), hats[k][0], h + Vector3(0, 0.01, 0), Vector3.ZERO, {"outline": 0.015})
				Toon.part(wing, Toon.cylinder(0.09, 0.105, 0.2, 12), hats[k][0], h + Vector3(0, 0.12, 0), Vector3.ZERO, {"outline": 0.015})
				Toon.part(wing, Toon.cylinder(0.108, 0.11, 0.045, 12), hats[k][1], h + Vector3(0, 0.05, 0), Vector3.ZERO, {"outline": 0.0})
		1:  # scarves, rolled
			var reds := [RIBBON, Color(0.2, 0.42, 0.75), GOLD, Color(0.45, 0.2, 0.55)]
			for k in reds.size():
				Toon.part(wing, Toon.cylinder(0.1, 0.1, 0.24, 12), reds[k], at + Vector3(-0.42 + k * 0.28, 0.1 + (k % 2) * 0.01, 0), Vector3(90, 0, 0), {"outline": 0.015})
				Toon.part(wing, Toon.box(Vector3(0.1, 0.02, 0.22)), reds[k].darkened(0.2), at + Vector3(-0.42 + k * 0.28, 0.01, 0.16), Vector3.ZERO, {"outline": 0.01})
		2:  # ink, bottled: it glows a little
			for k in 4:
				var b := at + Vector3(-0.42 + k * 0.28, 0, 0)
				var ink: Color = [Color(0.3, 0.9, 0.85), Color(0.85, 0.3, 0.9), Color(1.0, 0.8, 0.3), Color(0.4, 0.6, 1.0)][k]
				Toon.part(wing, Toon.cylinder(0.08, 0.1, 0.22 + (k % 2) * 0.06, 10), ink, b + Vector3(0, 0.11 + (k % 2) * 0.03, 0), Vector3.ZERO,
					{"outline": 0.015, "emission": 0.3})
				Toon.part(wing, Toon.cylinder(0.035, 0.035, 0.08, 8), Color(0.34, 0.24, 0.18), b + Vector3(0, 0.27 + (k % 2) * 0.06, 0), Vector3.ZERO, {"outline": 0.01})
		3:  # cloaks, folded
			var cloaks := [Color(0.14, 0.11, 0.16), Color(0.5, 0.1, 0.14), Color(0.16, 0.3, 0.26)]
			for k in cloaks.size():
				Toon.part(wing, Toon.box(Vector3(0.7 - k * 0.08, 0.1, 0.26)), cloaks[k], at + Vector3(-0.1 + k * 0.05, 0.05 + k * 0.1, 0), Vector3(0, k * 6.0, 0), {"outline": 0.015})
		4:  # the Quill Rapier and the Brush Maul, leaning
			Toon.part(wing, Toon.cylinder(0.0, 0.03, 0.75, 6), STEEL, at + Vector3(-0.3, 0.4, 0), Vector3(0, 0, 14), {"outline": 0.012, "emission": 0.15})
			Toon.part(wing, Toon.box(Vector3(0.09, 0.3, 0.012)), Color(0.55, 0.85, 1.0), at + Vector3(-0.21, 0.12, 0), Vector3(0, 0, 14), {"outline": 0.01})
			Toon.part(wing, Toon.cylinder(0.03, 0.03, 0.6, 8), Color(0.62, 0.4, 0.22), at + Vector3(0.25, 0.3, 0), Vector3(0, 0, -12), {"outline": 0.012})
			Toon.part(wing, Toon.box(Vector3(0.24, 0.22, 0.16)), Color(0.12, 0.1, 0.13), at + Vector3(0.33, 0.66, 0), Vector3(0, 0, -12), {"outline": 0.015})
		5:  # a Lantern Flail, lit
			Toon.part(wing, Toon.cylinder(0.025, 0.025, 0.5, 8), Color(0.34, 0.24, 0.18), at + Vector3(-0.3, 0.25, 0), Vector3(0, 0, 20), {"outline": 0.012})
			Toon.part(wing, Toon.box(Vector3(0.24, 0.3, 0.2)), Color(0.22, 0.2, 0.24), at + Vector3(0.15, 0.17, 0), Vector3.ZERO, {"outline": 0.015})
			Toon.part(wing, Toon.sphere(0.09, 10, 6), Color(1.0, 0.82, 0.42), at + Vector3(0.15, 0.17, 0.04), Vector3.ZERO, {"outline": 0.0, "emission": 2.2})
		6:  # armour: a Cardboard Vest, a Wax-Seal Mantle
			Toon.part(wing, Toon.box(Vector3(0.36, 0.42, 0.18)), Color(0.72, 0.56, 0.36), at + Vector3(-0.28, 0.21, 0), Vector3.ZERO, {"outline": 0.015})
			Toon.part(wing, Toon.box(Vector3(0.4, 0.38, 0.16)), Color(0.5, 0.1, 0.14), at + Vector3(0.25, 0.19, 0), Vector3.ZERO, {"outline": 0.015})
			Toon.part(wing, Toon.cylinder(0.08, 0.08, 0.03, 12), GOLD, at + Vector3(0.25, 0.24, 0.09), Vector3(90, 0, 0), {"outline": 0.01, "emission": 0.4})
		_:  # books, of course
			for k in 5:
				var tall := 0.3 + (k * 7 % 4) * 0.05
				Toon.part(wing, Toon.box(Vector3(0.11, tall, 0.22)), [NAVY_LIGHT, RIBBON.darkened(0.2), Color(0.2, 0.4, 0.3), GOLD.darkened(0.3), NAVY][k],
					at + Vector3(-0.4 + k * 0.13, tall * 0.5, 0), Vector3(0, 0, -8.0 if k == 4 else 0.0), {"outline": 0.012})


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
	# a little lit lantern, like the Flail's
	var lamp := Vector3(-0.15, top, 0.3)
	Toon.part(root, Toon.box(Vector3(0.2, 0.03, 0.2)), Color(0.22, 0.2, 0.24), lamp + Vector3(0, 0.015, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(root, Toon.box(Vector3(0.2, 0.03, 0.2)), Color(0.22, 0.2, 0.24), lamp + Vector3(0, 0.3, 0), Vector3.ZERO, {"outline": 0.012})
	Toon.part(root, Toon.sphere(0.07, 10, 6), Color(1.0, 0.82, 0.42), lamp + Vector3(0, 0.16, 0), Vector3.ZERO, {"outline": 0.0, "emission": 2.0})
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		Toon.part(root, Toon.box(Vector3(0.025, 0.28, 0.025)), Color(0.22, 0.2, 0.24), lamp + Vector3(cos(a) * 0.09, 0.16, sin(a) * 0.09),
			Vector3.ZERO, {"outline": 0.006})


## The sign: a long board across the foot of the crown of pages, tipped up
## to the camera, its letters gold and bright in the dark.
func _build_sign(root: Node3D) -> void:
	var board := SPINE + Vector3(0, COVER.y + 0.25, 0.75)
	Toon.part(root, Toon.box(Vector3(4.6, 0.95, 0.1)), NAVY.darkened(0.25), board, Vector3(-24, 0, 0), {"outline": 0.045})
	Toon.part(root, Toon.box(Vector3(4.35, 0.72, 0.03)), NAVY_LIGHT.darkened(0.2), board + Vector3(0, 0.02, 0.06), Vector3(-24, 0, 0), {"outline": 0.0})
	for x: float in [-2.38, 2.38]:  # gilt ends
		Toon.part(root, Toon.cylinder(0.16, 0.16, 0.14, 14), GOLD, board + Vector3(x, 0, 0.02), Vector3(66, 0, 0), {"outline": 0.02})
	var label := Label3D.new()
	label.text = "QUIRE'S CURIOS"
	label.font = TITLE_FONT
	label.font_size = 150
	label.pixel_size = 0.0045
	label.modulate = Color(0.82, 0.63, 0.3)
	_sign = label
	label.outline_size = 20
	label.outline_modulate = Color(0.1, 0.06, 0.04)
	label.shaded = false
	label.position = board + Vector3(0, 0.03, 0.1)
	label.rotation_degrees = Vector3(-24, 0, 0)
	root.add_child(label)


## Quire (quire_ghost.gd: half drawn, a ghost) hovering over the counter,
## and the two real things he has: a ledger open in the air at his side and
## the quill that never stops scribbling in it.
func _build_quire(q: Node3D) -> void:
	_ghost = null
	if not Engine.is_editor_hint():
		_ghost = QuireGhost.new()
		q.add_child(_ghost)
	else:  # (a stand-in: his script only runs in the game)
		Toon.part(q, Toon.sphere(0.24, 12, 8), PALE, Vector3(0, 0.5, 0), Vector3.ZERO, {"outline": 0.03})
	# the ledger, open in the air at his side
	_ledger = Node3D.new()
	_ledger.position = Vector3(-0.5, 1.04, 0.42)
	_ledger.rotation_degrees = Vector3(35, 22, 0)
	q.add_child(_ledger)
	Toon.part(_ledger, Toon.box(Vector3(0.52, 0.03, 0.36)), NAVY.darkened(0.2), Vector3(0, -0.02, 0), Vector3.ZERO, {"outline": 0.015})
	for side in [-1.0, 1.0]:
		Toon.part(_ledger, Toon.box(Vector3(0.23, 0.02, 0.32)), Color(0.8, 0.77, 0.68), Vector3(side * 0.12, 0.01, 0), Vector3(0, 0, side * 9.0), {"outline": 0.01})
		for k in 4:  # what he has written so far
			Toon.part(_ledger, Toon.box(Vector3(0.16 - (k % 2) * 0.04, 0.004, 0.012)), Color(0.15, 0.12, 0.2), Vector3(side * 0.12, 0.03 + absf(side) * 0.005, -0.1 + k * 0.065),
				Vector3(0, 0, side * 9.0), {"outline": 0.0})
	Toon.part(_ledger, Toon.box(Vector3(0.04, 0.012, 0.5)), RIBBON, Vector3(0, 0.02, 0.1), Vector3.ZERO, {"outline": 0.0})  # its ribbon
	# the quill in his hand (its nib is the node's origin)
	_quill = Node3D.new()
	q.add_child(_quill)
	Toon.part(_quill, Toon.cylinder(0.008, 0.012, 0.4, 6), Color(0.95, 0.93, 0.86), Vector3(0, 0.2, 0), Vector3.ZERO, {"outline": 0.01})
	Toon.part(_quill, Toon.box(Vector3(0.09, 0.26, 0.012)), Color(0.55, 0.85, 1.0), Vector3(0.03, 0.32, 0), Vector3.ZERO, {"outline": 0.01})
	Toon.part(_quill, Toon.sphere(0.02, 6, 4), Color(0.7, 1.0, 0.95), Vector3.ZERO, Vector3.ZERO, {"outline": 0.0, "emission": 1.6})  # wet ink, glowing
	_write(0.0)


## The quill's nib runs over the ledger (which bobs), and his arm follows it.
func _write(busy: float) -> void:
	_ledger.position = Vector3(-0.5, 1.04 + sin(_time * 1.6) * 0.025, 0.42)
	var nib := _ledger.position + _ledger.basis * Vector3(0.12 + sin(_time * 9.0 * busy + 1.0) * 0.07 - fmod(_time * 0.11, 0.24),
		0.04 + maxf(sin(_time * 4.5 * busy), 0.0) * 0.02, -0.09 + fmod(_time * 0.045, 0.2) + sin(_time * 13.0 * busy) * 0.012)
	_quill.position = nib
	_quill.rotation = Vector3(-0.5 + sin(_time * 9.0 * busy) * 0.12, 0.3, -0.55 + cos(_time * 7.0 * busy) * 0.1)
	if _ghost:
		_ghost.aim_arm(Vector3(-0.14, 1.04, 0.05), nib + _quill.basis * Vector3(0, 0.13, 0))


## The loose pages, wheeling round the shop.
func _fly_pages() -> void:
	for k in _loose.size():
		var a := _time * (0.3 + (k % 4) * 0.05) + k * TAU / _loose.size()
		var r := 3.4 + 1.5 * sin(_time * 0.21 + k * 1.3)
		_loose[k].position = Vector3(cos(a) * r, 3.9 + 1.5 * sin(_time * 0.4 + k * 2.1) + (k % 3) * 0.5, -0.5 + sin(a) * r * 0.62)
		_loose[k].rotation = Vector3(sin(_time * 1.3 + k) * 0.7, a + k, cos(_time * 1.1 + k * 0.7) * 0.6)


func _process(delta: float) -> void:
	if _quire == null or Engine.is_editor_hint():
		return
	_time += delta
	_quire.rotation.z = sin(_time * 1.3) * 0.03
	# his head: down at the ledger while he is alone, up at Vesper when he comes near
	var want := Vector2(-0.75, 0.42)  # (yaw, pitch)
	var busy := 1.0
	var drawn := 0.6  # (alone he fades, his lines coming and going)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and global_position.distance_to(player.global_position) < 8.5:
		var at := _quire.to_local(player.global_position + Vector3(0, 1.0, 0)) - Vector3(0, 1.33, 0)
		want = Vector2(clampf(atan2(at.x, at.z), -1.2, 1.2), clampf(-atan2(at.y, Vector2(at.x, at.z).length()), -0.35, 0.5))
		busy = 0.45  # (the quill slows: he is listening)
		drawn = 1.0  # (and he is all there, as far as he was ever drawn)
	var k := 1.0 - exp(-delta * 5.0)
	_ghost.head.rotation.y = lerpf(_ghost.head.rotation.y, want.x, k)
	_ghost.head.rotation.x = lerpf(_ghost.head.rotation.x, want.y, k)
	_ghost.shown = drawn
	_write(busy)
	# the book: its pages stir, its ribbon and lanterns sway, the loose ones wheel
	for i in _fan.size():
		_fan[i].rotation.z = deg_to_rad((i - 4) * 15.0 + sin(_time * 0.9 + i * 0.6) * 2.2)
	_ribbon.rotation.z = sin(_time * 1.1) * 0.05
	for i in _lanterns.size():
		_lanterns[i].rotation.z = sin(_time * 1.4 + i * 2.0) * 0.07
		# the lanterns burn low; the second gutters, nearly out
		var burn := 0.9 + 0.1 * sin(_time * 9.0 + i * 3.0) if i == 0 else 0.45 + 0.35 * maxf(sin(_time * 3.1) * sin(_time * 7.7 + 1.0), -0.6)
		_flames[i].scale = Vector3.ONE * maxf(burn, 0.2)
	# the sign's gilt catches the light and loses it
	_sign.modulate = Color(0.82, 0.63, 0.3) * (0.82 + 0.18 * sin(_time * 0.7) + (0.0 if fmod(_time, 6.3) > 0.12 else -0.35))
	_sign.modulate.a = 1.0
	_fly_pages()
