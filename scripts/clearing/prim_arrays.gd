extends RefCounted
## Positions, normals and indices of Godot's primitive meshes, built on the
## CPU. Asking a primitive (or the RenderingServer) for its arrays reads them
## back from the GPU in the Compatibility renderer, and in a browser every one
## of those reads stalls the frame: merging the hub's props (Toon.merge) made
## ~5000 of them. Cylinders and spheres are built point for point as Godot
## builds them (scene/resources/3d/primitive_meshes.cpp); boxes and prisms have
## the same faces, normals and winding. Only what the toon shaders read
## (VERTEX, NORMAL) is made.
##
##   var a := PrimArrays.of(mesh)  # [PackedVector3Array, PackedVector3Array, PackedInt32Array] or []


## The arrays of `mesh`, or [] when it isn't a kind made here (then read it
## the old way).
static func of(mesh: Mesh) -> Array:
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		return cylinder(c.top_radius, c.bottom_radius, c.height, c.radial_segments, c.rings, c.cap_top, c.cap_bottom)
	if mesh is SphereMesh:
		var s := mesh as SphereMesh
		return sphere(s.radius, s.height, s.radial_segments, s.rings, s.is_hemisphere)
	if mesh is BoxMesh:
		var b := mesh as BoxMesh
		if b.subdivide_width == 0 and b.subdivide_height == 0 and b.subdivide_depth == 0:
			return box(b.size)
	if mesh is PrismMesh:
		var p := mesh as PrismMesh
		if p.subdivide_width == 0 and p.subdivide_height == 0 and p.subdivide_depth == 0:
			return prism(p.size, p.left_to_right)
	return []


static func cylinder(top_r: float, bottom_r: float, height: float, segments: int, rings: int,
		cap_top: bool, cap_bottom: bool) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var point := 0
	var thisrow := 0
	var prevrow := 0
	for j in rings + 2:
		var t := float(j) / (rings + 1)
		var r := top_r + (bottom_r - top_r) * t
		var y := height * 0.5 - height * t
		for i in segments + 1:
			var u := float(i) / segments
			var x := sin(u * TAU)
			var z := cos(u * TAU)
			v.append(Vector3(x * r, y, z * r))
			n.append(Vector3(x, (bottom_r - top_r) / height, z).normalized())
			point += 1
			if i > 0 and j > 0:
				idx.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1,
					prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	if cap_top and top_r > 0.0:
		var y := height * 0.5
		thisrow = point
		v.append(Vector3(0, y, 0)); n.append(Vector3.UP); point += 1
		for i in segments + 1:
			var u := float(i) / segments
			v.append(Vector3(sin(u * TAU) * top_r, y, cos(u * TAU) * top_r)); n.append(Vector3.UP); point += 1
			if i > 0:
				idx.append_array([thisrow, point - 1, point - 2])
	if cap_bottom and bottom_r > 0.0:
		var y := -height * 0.5
		thisrow = point
		v.append(Vector3(0, y, 0)); n.append(Vector3.DOWN); point += 1
		for i in segments + 1:
			var u := float(i) / segments
			v.append(Vector3(sin(u * TAU) * bottom_r, y, cos(u * TAU) * bottom_r)); n.append(Vector3.DOWN); point += 1
			if i > 0:
				idx.append_array([thisrow, point - 2, point - 1])
	return [v, n, idx]


static func sphere(radius: float, height: float, segments: int, rings: int, hemisphere: bool) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var scale := height * (1.0 if hemisphere else 0.5)
	var point := 0
	var thisrow := 0
	var prevrow := 0
	for j in rings + 2:
		var t := float(j) / (rings + 1)
		var w := sin(PI * t)
		var y := scale * cos(PI * t)
		for i in segments + 1:
			var u := float(i) / segments
			var x := sin(u * TAU)
			var z := cos(u * TAU)
			if hemisphere and y < 0.0:
				v.append(Vector3(x * radius * w, 0.0, z * radius * w))
				n.append(Vector3.DOWN)
			else:
				v.append(Vector3(x * radius * w, y, z * radius * w))
				n.append(Vector3(x * w * scale, radius * (y / scale), z * w * scale).normalized())
			point += 1
			if i > 0 and j > 0:
				idx.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1,
					prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	return [v, n, idx]


## One flat face: corners a b c d going round it, `nrm` its normal.
static func _quad(v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3) -> void:
	var k := v.size()
	v.append_array([a, b, c, d])
	n.append_array([nrm, nrm, nrm, nrm])
	_wind(idx, v, nrm, k, k + 1, k + 2)
	_wind(idx, v, nrm, k, k + 2, k + 3)


## A triangle wound the way Godot's are (clockwise seen from its front).
static func _wind(idx: PackedInt32Array, v: PackedVector3Array, nrm: Vector3, i0: int, i1: int, i2: int) -> void:
	if (v[i1] - v[i0]).cross(v[i2] - v[i0]).dot(nrm) < 0.0:
		idx.append_array([i0, i1, i2])
	else:
		idx.append_array([i0, i2, i1])


static func box(size: Vector3) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var h := size * 0.5
	_quad(v, n, idx, Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3.BACK)
	_quad(v, n, idx, Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3.FORWARD)
	_quad(v, n, idx, Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3.RIGHT)
	_quad(v, n, idx, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3.LEFT)
	_quad(v, n, idx, Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3.UP)
	_quad(v, n, idx, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3.DOWN)
	return [v, n, idx]


static func prism(size: Vector3, left_to_right: float) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var h := size * 0.5
	var top := -h.x + left_to_right * size.x
	for side in [1.0, -1.0]:  # the two triangular ends
		var nrm := Vector3(0, 0, side)
		var k := v.size()
		v.append_array([Vector3(top, h.y, h.z * side), Vector3(-h.x, -h.y, h.z * side), Vector3(h.x, -h.y, h.z * side)])
		n.append_array([nrm, nrm, nrm])
		_wind(idx, v, nrm, k, k + 1, k + 2)
	var right := Vector3(size.y, h.x - top, 0).normalized()
	var left := Vector3(-size.y, top + h.x, 0).normalized()
	_quad(v, n, idx, Vector3(top, h.y, h.z), Vector3(top, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), right)
	_quad(v, n, idx, Vector3(top, h.y, -h.z), Vector3(top, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), left)
	_quad(v, n, idx, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3.DOWN)
	return [v, n, idx]
