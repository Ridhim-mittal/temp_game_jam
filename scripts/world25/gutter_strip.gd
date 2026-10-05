extends RefCounted
## The Margins are the gutters of a comic book, and down here they are dead:
## so the ways across the void are old gutters too, worn and torn apart. A
## walkway of dark, weathered paper-stone between two broken ink borders
## (kerbs with gaps knocked out of them), its edges chipped and ragged,
## cracked across, scraps of torn paper hanging off it into the dark; at
## its far end a broken portal: two cracked dark pillars snapped off at
## different heights, a broken lintel, a faint seam of light in each.
## Used by bridge.gd (the hub's way in), gate.gd (each way on, built in
## sections so the sealed sketch can fill in one at a time) and
## drawn_bridge.gd (its inked planks).
##
##   GutterStrip.section(root, z0, z1, width, seed)  # one piece, z0 -> z1
##   GutterStrip.slit(root, z, width, seed, glow)     # the broken portal

const Toon = preload("res://scripts/clearing/toon.gd")
## The walkway: dark, weathered.
const STONE := Color(0.27, 0.26, 0.29)
const INK := Color(0.06, 0.05, 0.08)
const SCRAP := Color(0.55, 0.52, 0.46)
## Thickness of the walkway (its depth under its surface).
const THICK := 0.5
## Size of each portal pillar (stood on its bottom edge).
const PILLAR := Vector3(0.9, 3.3, 0.7)


## One section of gutter from z0 to z1 along the local Z axis, `width`
## across, centred on x = 0, its surface at y = 0. Returns the Node3D
## holding it (so a caller can show / hide sections).
static func section(root: Node3D, z0: float, z1: float, width: float, seed := 0) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111 + seed * 37
	var length := absf(z1 - z0)
	var mid := (z0 + z1) * 0.5
	var dir := signf(z1 - z0)
	# the walkway in short strips, each a little narrower or sunk, so the
	# edges come out ragged and the surface uneven
	var strips := maxi(int(length / 0.35), 1)
	for i in strips:
		var a := z0 + dir * length * i / strips
		var b := z0 + dir * length * (i + 1) / strips
		var bite_l := rng.randf_range(0.0, 0.22) if rng.randf() < 0.5 else 0.0
		var bite_r := rng.randf_range(0.0, 0.22) if rng.randf() < 0.5 else 0.0
		var w := width - bite_l - bite_r
		var drop := rng.randf_range(0.0, 0.03)
		Toon.part(n, Toon.box(Vector3(w, THICK, absf(b - a) + 0.002)), STONE.darkened(rng.randf() * 0.12),
			Vector3((bite_l - bite_r) * 0.5, -THICK * 0.5 - drop, (a + b) * 0.5), Vector3.ZERO, {"outline": 0.02})
	# cracks across the surface
	for i in 1 + rng.randi() % 3:
		var at := Vector3(rng.randf_range(-width * 0.3, width * 0.3), 0.004, mid + rng.randf_range(-length * 0.4, length * 0.4))
		Toon.part(n, Toon.box(Vector3(rng.randf_range(0.5, width * 0.7), 0.01, 0.035)), INK, at,
			Vector3(0, rng.randf_range(-40, 40), 0), {"outline": 0.0})
	for side in [-1.0, 1.0]:
		# the old panel border: an ink kerb, broken, pieces knocked askew
		var pieces := maxi(int(length / 0.5), 1)
		for i in pieces:
			if rng.randf() < 0.25:
				continue  # a gap knocked out of it
			var a := z0 + dir * length * i / pieces
			var b := z0 + dir * length * (i + 1) / pieces
			var h := rng.randf_range(0.08, 0.2)
			Toon.part(n, Toon.box(Vector3(0.16, THICK + h, absf(b - a) * rng.randf_range(0.7, 0.98))), INK,
				Vector3(side * (width * 0.5 + 0.06), -THICK * 0.5 + h * 0.5, (a + b) * 0.5),
				Vector3(rng.randf_range(-6, 6), rng.randf_range(-5, 5), rng.randf_range(-6, 6)), {"outline": 0.0})
		# a scrap of torn paper hanging off the edge into the dark
		if rng.randf() < 0.6:
			var s := rng.randf_range(0.35, 0.7)
			Toon.part(n, Toon.box(Vector3(0.03, s, s * 0.8)), SCRAP.darkened(rng.randf() * 0.35),
				Vector3(side * (width * 0.5 + 0.14), -s * 0.35, mid + rng.randf_range(-length * 0.3, length * 0.3)),
				Vector3(rng.randf_range(-15, 15), 0, side * rng.randf_range(10, 35)), {"outline": 0.015})
	return n


## The broken portal at the end of a way on: two cracked dark pillars
## either side of the path (the first two children, each standing at its
## foot, so callers can sketch them), snapped off at different heights, a
## broken lintel, a seam of `glow` light down each inner face.
static func slit(root: Node3D, z: float, width: float, seed := 0, glow := Color(1.0, 0.9, 0.62)) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 977 + seed * 13
	var tops := [rng.randf_range(0.85, 1.0), rng.randf_range(0.5, 0.72)]
	if rng.randf() < 0.5:
		tops.reverse()
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var pillar := Node3D.new()
		pillar.position = Vector3(side * (width * 0.5 + PILLAR.x * 0.5 + 0.05), 0, z)
		pillar.rotation_degrees = Vector3(rng.randf_range(-3, 3), rng.randf_range(-6, 6), side * rng.randf_range(1, 4))
		n.add_child(pillar)
		var h: float = PILLAR.y * tops[k]
		Toon.part(pillar, Toon.box(Vector3(PILLAR.x, h, PILLAR.z)), STONE.darkened(0.15), Vector3(0, h * 0.5, 0), Vector3.ZERO,
			{"outline": 0.035, "tile": 0.9, "line": INK})
		# the snapped top: jagged chunks
		for j in 3:
			var c := Vector3(rng.randf_range(-0.3, 0.3), h + rng.randf_range(-0.05, 0.12), rng.randf_range(-0.2, 0.2))
			Toon.part(pillar, Toon.box(Vector3(rng.randf_range(0.2, 0.45), rng.randf_range(0.15, 0.35), rng.randf_range(0.25, 0.5))),
				STONE.darkened(0.2), c, Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 90), rng.randf_range(-30, 30)),
				{"outline": 0.025})
		# a crack running down the front, and a seam of light on the inner face
		Toon.part(pillar, Toon.box(Vector3(0.04, h * 0.6, 0.02)), INK, Vector3(side * 0.12, h * 0.55, PILLAR.z * 0.5 + 0.005),
			Vector3(0, 0, rng.randf_range(-12, 12)), {"outline": 0.0})
		Toon.part(pillar, Toon.box(Vector3(0.02, h * 0.7, 0.05)), glow, Vector3(-side * (PILLAR.x * 0.5 + 0.005), h * 0.45, 0),
			Vector3(rng.randf_range(-8, 8), 0, 0), {"outline": 0.0, "emission": 1.4})
	# the lintel, broken: a stub reaching from the taller pillar, its other
	# half lying on the ground by the shorter one
	var tall := 0 if tops[0] > tops[1] else 1
	var tside := -1.0 if tall == 0 else 1.0
	var top_y: float = PILLAR.y * tops[tall]
	Toon.part(n, Toon.box(Vector3(width * 0.55, 0.42, PILLAR.z * 0.8)), STONE.darkened(0.18),
		Vector3(tside * (width * 0.5 - width * 0.12), top_y - 0.1, z), Vector3(0, 0, tside * -9.0), {"outline": 0.03})
	Toon.part(n, Toon.box(Vector3(width * 0.5, 0.4, PILLAR.z * 0.75)), STONE.darkened(0.25),
		Vector3(-tside * (width * 0.5 + 0.9), 0.15, z + 0.6), Vector3(rng.randf_range(-8, 8), -tside * 55.0, 6), {"outline": 0.03})
	return n
