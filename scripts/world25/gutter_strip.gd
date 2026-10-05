extends RefCounted
## The Margins are the gutters of a comic book: the blank strips of paper
## between the panels. So the ways across the void are gutters too: a
## walkway of cream paper between two thick ink panel borders, with the
## printed panels' edges lying either side of it (comic_page.gdshader in
## single-panel mode) and a pencilled ruling line down the middle.
## Used by bridge.gd (the hub's way in) and gate.gd (each way on, built in
## sections so the sealed sketch can fill in one at a time).
##
##   GutterStrip.section(root, z0, z1, width, seed)  # one piece, z0 -> z1
##   GutterStrip.slit(root, z, width, seed)           # two upright panels with
##                                                    # a gap: the way through

const Toon = preload("res://scripts/clearing/toon.gd")
const PAGE_SHADER = preload("res://shaders/world25/comic_page.gdshader")
const PAPER := Color(0.93, 0.9, 0.82)
const INK := Color(0.07, 0.05, 0.11)
## Thickness of the paper (the walkway's depth under its surface).
const THICK := 0.5
## Width of the printed panels lying either side.
const PANEL := 2.4
## Size of each upright panel board in a slit (stood on its bottom edge).
const BOARD := Vector3(2.3, 4.0, 0.16)


## One section of gutter from z0 to z1 along the local Z axis, `width`
## across, centred on x = 0, its surface at y = 0. Returns the Node3D
## holding it (so a caller can show / hide sections).
static func section(root: Node3D, z0: float, z1: float, width: float, seed := 0, panels := true) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	var length := absf(z1 - z0)
	var mid := (z0 + z1) * 0.5
	Toon.part(n, Toon.box(Vector3(width, THICK, length)), PAPER, Vector3(0, -THICK * 0.5, mid), Vector3.ZERO, {"outline": 0.02})
	# a faint pencilled ruling line down the middle, dashed
	var dashes := maxi(int(length / 0.9), 1)
	for i in dashes:
		var z := lerpf(z0, z1, (i + 0.3) / dashes)
		Toon.part(n, Toon.box(Vector3(0.05, 0.01, length / dashes * 0.45)), PAPER.darkened(0.25), Vector3(0, 0.006, z), Vector3.ZERO,
			{"outline": 0.0})
	for side in [-1.0, 1.0]:
		# the panel border: a thick ink line standing a little proud
		Toon.part(n, Toon.box(Vector3(0.18, THICK + 0.16, length)), INK, Vector3(side * (width * 0.5 + 0.09), -THICK * 0.5 + 0.08, mid),
			Vector3.ZERO, {"outline": 0.0})
		if panels:
			_panel(n, Vector3(side * (width * 0.5 + 0.18 + PANEL * 0.5), -0.02, mid), Vector2(PANEL, length), seed * 7 + int(side + 1.0) * 3 + int(mid))
	return n


## The way through at the end of a gutter: two tall printed panels stood
## upright either side, their ink borders framing a bright slit of paper.
static func slit(root: Node3D, z: float, width: float, seed := 0) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	for side in [-1.0, 1.0]:
		var board := Node3D.new()
		board.position = Vector3(side * (width * 0.5 + BOARD.x * 0.5 + 0.05), 0, z)
		board.rotation_degrees = Vector3(0, -side * 12.0, side * 3.0)
		n.add_child(board)
		Toon.part(board, Toon.box(BOARD), PAPER.darkened(0.08), Vector3(0, BOARD.y * 0.5, 0), Vector3.ZERO, {"outline": 0.03})
		var face := Vector2(BOARD.x - 0.3, BOARD.y - 0.3)
		var mid := BOARD.y * 0.5
		_panel(board, Vector3(0, mid, 0.085), face, seed * 5 + int(side + 1.0), false)  # a QuadMesh faces +Z
		# the thick ink border round the face
		for e in [[Vector3(0, mid + face.y * 0.5, 0.09), Vector3(face.x + 0.12, 0.14, 0.04)],
				[Vector3(0, mid - face.y * 0.5, 0.09), Vector3(face.x + 0.12, 0.14, 0.04)],
				[Vector3(-face.x * 0.5, mid, 0.09), Vector3(0.12, face.y, 0.04)], [Vector3(face.x * 0.5, mid, 0.09), Vector3(0.12, face.y, 0.04)]]:
			Toon.part(board, Toon.box(e[1]), INK, e[0], Vector3.ZERO, {"outline": 0.0})
	return n


## A printed comic panel, `size` across, lying flat (or standing, rotated
## by the caller), its picture picked by `seed`.
static func _panel(parent: Node3D, at: Vector3, size: Vector2, seed: int, flat := true) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	m.shader = PAGE_SHADER
	m.set_shader_parameter("single", true)
	m.set_shader_parameter("seed", float(absi(seed) % 60))
	m.set_shader_parameter("brightness", 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
