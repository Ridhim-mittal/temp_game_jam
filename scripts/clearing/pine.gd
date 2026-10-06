@tool
extends Node3D
## A dead tree: a bare, crooked trunk forking into leafless branches that
## reach up and out and end in thin twigs, dark against the void. Stands in
## rings round the rooms and rises out of the void below the cliffs (it was
## a pine, then a quill; the name and exports are kept so the rooms and
## their generator still work: `tiers` is how many levels of branches).

const Toon = preload("res://scripts/clearing/toon.gd")

@export var height := 6.0:
	set(v):
		height = v
		_rebuild()
@export var radius := 1.6:
	set(v):
		radius = v
		_rebuild()
@export var color := Color(0.1, 0.11, 0.17):
	set(v):
		color = v
		_rebuild()
@export var tiers := 3:
	set(v):
		tiers = v
		_rebuild()
@export var solid := true


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	Toon.merge_when_built(root)  # one mesh per material: far fewer draw calls
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector2i(roundi(position.x * 10.0), roundi(position.z * 10.0))))
	var bark := color.lightened(0.08)
	# the trunk: two crooked lengths, leaning a little
	var lean := Vector3(rng.randf_range(-6, 6), rng.randf() * 360.0, rng.randf_range(-6, 6))
	var trunk := Node3D.new()
	trunk.rotation_degrees = lean
	root.add_child(trunk)
	var r0 := radius * 0.16
	var mid := height * 0.55
	Toon.part(trunk, Toon.cylinder(r0 * 0.75, r0, mid, 7), bark, Vector3(0, mid * 0.5, 0), Vector3.ZERO,
		{"outline": 0.05, "bark": 0.8, "line": color.darkened(0.4)})
	var upper := Node3D.new()
	upper.position = Vector3(0, mid, 0)
	upper.rotation_degrees = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
	trunk.add_child(upper)
	Toon.part(upper, Toon.cylinder(r0 * 0.25, r0 * 0.75, height - mid, 6), bark, Vector3(0, (height - mid) * 0.5, 0), Vector3.ZERO,
		{"outline": 0.045})
	# roots clawing into the ground
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		_branch(root, Vector3(0, r0 * 0.5, 0), Vector3(cos(a), -0.25, sin(a)), r0 * 2.6, r0 * 0.5, bark, rng, 0)
	# bare branches, a level of them per tier, each forking into twigs
	for t in tiers:
		var y := mid * (0.55 + 0.45 * float(t) / maxf(tiers - 1, 1)) + rng.randf_range(-0.2, 0.2)
		for k in 2:
			var a := rng.randf() * TAU
			var dir := Vector3(cos(a), rng.randf_range(0.5, 1.1), sin(a))
			_branch(trunk, Vector3(0, y, 0), dir, radius * rng.randf_range(0.55, 0.95) * (1.0 - t * 0.15), r0 * 0.4, bark, rng, 2)
	for k in 2:  # the crown splits too
		var a := rng.randf() * TAU
		_branch(upper, Vector3(0, (height - mid) * 0.8, 0), Vector3(cos(a), 1.2, sin(a)), radius * 0.45, r0 * 0.22, bark, rng, 1)
	if solid and not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(radius * 0.3, 3.0), Vector3(0, 1.5, 0))


## A branch from `at` along `dir`, `length` long, tapering from `thick`;
## with `forks` left it splits into two thinner ones at its end.
func _branch(parent: Node3D, at: Vector3, dir: Vector3, length: float, thick: float, col: Color, rng: RandomNumberGenerator,
		forks: int) -> void:
	var d := dir.normalized()
	var b := Node3D.new()
	b.position = at + d * length * 0.5
	b.basis = Basis(Quaternion(Vector3.UP, d))
	parent.add_child(b)
	Toon.part(b, Toon.cylinder(thick * 0.45, thick, length, 5), col, Vector3.ZERO, Vector3.ZERO, {"outline": 0.03})
	if forks <= 0:
		return
	for k in 2:
		var twist := d.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2)) + Vector3(0, rng.randf_range(0.1, 0.6), 0)
		var side := d.cross(Vector3.UP).normalized() * (1.0 if k == 0 else -1.0) * rng.randf_range(0.3, 0.7)
		_branch(parent, at + d * length * 0.95, twist + side, length * rng.randf_range(0.45, 0.65), thick * 0.5, col, rng, forks - 1)
