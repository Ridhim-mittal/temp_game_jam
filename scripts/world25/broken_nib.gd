extends RefCounted
## A giant fountain-pen nib, long dead: worn grey steel gone patchy with
## rust, curved across like a real nib (a shell, convex at the front),
## leaning back a little along its length, its point snapped off in a
## jagged break. The breather hole and the slit running up from it to the
## break, ink still bleeding out of the break and down its face, and an
## epitaph scratched into it if one is given. Its foot is at the origin,
## its face towards +Z. The Gutter's graves (biome_props.gd TOMBSTONE), its
## nib totems and the nibs drifting in the comic backdrop are these.
##
##   BrokenNib.build(parent, 1.0, seed, "REST\nIN INK")

const Toon = preload("res://scripts/clearing/toon.gd")
const STEEL := Color(0.37, 0.36, 0.38)
const RUST := Color(0.36, 0.25, 0.2)
const INK := Color(0.03, 0.025, 0.04)
const ROWS := 14
const COLS := 12


## Builds a nib `s` times the size of a person-tall one (about 2.4 units
## to the break) under `parent`; returns its node.
static func build(parent: Node3D, s: float, seed: int, epitaph := "") -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51 + seed * 7
	var nib := Node3D.new()
	parent.add_child(nib)
	var h := 2.8 * s
	var w := 0.7 * s
	var bend := 0.18 * s
	var mesh := _shell(rng, h, w, 0.85 * s, 0.07 * s, bend, rng.randf_range(0.8, 0.9))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(STEEL.darkened(rng.randf() * 0.12),
		{"outline": 0.035, "moss": 0.5, "moss_color": RUST, "line": INK})
	nib.add_child(mi)
	# the breather hole and the slit up to the break
	var hole_t := 0.42
	var hole := Toon.part(nib, Toon.cylinder(0.11 * s, 0.11 * s, 0.03, 12), INK, _front(hole_t, h, bend) + Vector3(0, 0, 0.01),
		Vector3(90 - _lean(hole_t, h, bend), 0, 0), {"outline": 0.0})
	hole.scale = Vector3(1.0, 1.0, 1.25)
	var slit_from := hole_t + 0.04
	var slit_to := 0.8
	var a := _front(slit_from, h, bend)
	var b := _front(slit_to, h, bend)
	Toon.part(nib, Toon.box(Vector3(0.028 * s, a.distance_to(b), 0.02)), INK, (a + b) * 0.5 + Vector3(0, 0, 0.012),
		Vector3(-_lean((slit_from + slit_to) * 0.5, h, bend), 0, rng.randf_range(-1.5, 1.5)), {"outline": 0.0})
	# two scratched scroll marks either side of the hole
	for side in [-1.0, 1.0]:
		var p := _front(0.36, h, bend) + Vector3(side * 0.24 * s, 0, -0.04 * s)
		var curl := Toon.part(nib, Toon.cylinder(0.09 * s, 0.09 * s, 0.015, 10), STEEL.darkened(0.35), p,
			Vector3(90 - _lean(0.36, h, bend), side * 18.0, 0), {"outline": 0.0})
		curl.scale = Vector3(1.0, 1.0, 0.6)
	# ink bleeding out of the break and down the face
	for k in 2 + rng.randi() % 3:
		var x := rng.randf_range(-0.22, 0.22) * s
		var t0 := rng.randf_range(0.66, 0.76)
		var t1 := t0 - rng.randf_range(0.12, 0.4)
		var p0 := _front(t0, h, bend) + Vector3(x, 0, -x * x * 0.6 / s + 0.014)
		var p1 := _front(t1, h, bend) + Vector3(x, 0, -x * x * 0.6 / s + 0.014)
		var thick := rng.randf_range(0.03, 0.06) * s
		Toon.part(nib, Toon.box(Vector3(thick, p0.distance_to(p1), 0.015)), INK, (p0 + p1) * 0.5,
			Vector3(-_lean((t0 + t1) * 0.5, h, bend), 0, 0), {"outline": 0.0})
		Toon.part(nib, Toon.sphere(thick * 0.8, 8, 4), INK, p1, Vector3.ZERO, {"outline": 0.0})
	if epitaph != "":
		var label := Label3D.new()
		label.text = epitaph
		label.font_size = 64
		label.pixel_size = 0.0026 * s
		label.modulate = Color(0.1, 0.09, 0.1, 0.8)
		label.outline_size = 0
		label.shaded = true
		label.double_sided = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = _front(0.24, h, bend) + Vector3(0, 0, 0.03)
		label.rotation_degrees = Vector3(-_lean(0.24, h, bend), 0, rng.randf_range(-4, 4))
		nib.add_child(label)
	return nib


## The middle of the nib's face at height fraction `t`.
static func _front(t: float, h: float, bend: float) -> Vector3:
	return Vector3(0, t * h, -bend * t * t)


## How far back (degrees) the face leans at height fraction `t`.
static func _lean(t: float, h: float, bend: float) -> float:
	return rad_to_deg(atan2(2.0 * bend * t, h))


## Half the nib's width at height fraction `t`: broad shoulders near the
## foot, then a long taper to where the point was.
static func _half_width(t: float, w: float) -> float:
	if t < 0.22:
		return w * lerpf(0.82, 1.0, sin(t / 0.22 * PI * 0.5))
	return w * pow(1.0 - (t - 0.22) / 0.78, 0.85)


## The nib's curved shell, front and back with its edges closed, broken off
## at about height fraction `top` along a jagged line.
static func _shell(rng: RandomNumberGenerator, h: float, w: float, curve: float, thick: float, bend: float, top: float) -> ArrayMesh:
	var tops := PackedFloat32Array()
	for c in COLS + 1:
		tops.append(top - rng.randf_range(0.0, 0.14) * (1.0 - absf(float(c) / COLS * 2.0 - 1.0) * 0.4))
	var front := []
	var back := []
	for r in ROWS + 1:
		var fr := PackedVector3Array()
		var bk := PackedVector3Array()
		for c in COLS + 1:
			var t := tops[c] * float(r) / ROWS
			var u := float(c) / COLS * 2.0 - 1.0
			var theta := u * _half_width(t, w) / curve
			var n := Vector3(sin(theta), 0, cos(theta))
			var p := Vector3(curve * sin(theta), t * h, curve * (cos(theta) - 1.0) - bend * t * t)
			fr.append(p)
			bk.append(p - n * thick)
		front.append(fr)
		back.append(bk)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in ROWS:
		for c in COLS:
			_quad(st, front[r][c], front[r][c + 1], front[r + 1][c + 1], front[r + 1][c])
			_quad(st, back[r][c + 1], back[r][c], back[r + 1][c], back[r + 1][c + 1])
	for r in ROWS:  # the two long edges
		_quad(st, back[r][0], front[r][0], front[r + 1][0], back[r + 1][0])
		_quad(st, front[r][COLS], back[r][COLS], back[r + 1][COLS], front[r + 1][COLS])
	for c in COLS:  # the foot and the break
		_quad(st, back[0][c], back[0][c + 1], front[0][c + 1], front[0][c])
		_quad(st, front[ROWS][c], front[ROWS][c + 1], back[ROWS][c + 1], back[ROWS][c])
	st.index()  # shared points: the face shades smooth
	st.generate_normals()
	return st.commit()


## Two triangles, a b c d going round the quad (clockwise seen from outside).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, c, b, a, d, c]:
		st.add_vertex(p)
