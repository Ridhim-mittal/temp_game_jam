@tool
extends "res://scripts/world/solid_block.gd"
## Solid terrain drawn as cave stone: a dark mass with a row of segmented
## stone tiles along the top (and optionally the bottom, for ceilings).
## Behaves exactly like SolidBlock.

const TriBatch = preload("res://scripts/background/tri_batch.gd")
const INK := Color(0.02, 0.02, 0.03)

@export var rock := Color(0.07, 0.07, 0.085)
@export var tile := Color(0.3, 0.3, 0.33)
## Also tile the underside (ceilings, floating ledges) with drips.
@export var tiles_below := false


var _b: TriBatch


func _draw() -> void:
	_b = TriBatch.new()  # hundreds of tiles/windows -> one draw call
	var r := Rect2(-size * 0.5, size)
	_b.rect(r, rock)
	_tile_row(r.position.y, 1.0)
	if tiles_below:
		_tile_row(r.end.y, -1.0)
	_b.rect_outline(r, INK, 3.0)
	_b.flush(self)


func _tile_row(edge_y: float, dir: float) -> void:
	var r := Rect2(-size * 0.5, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 13 + int(position.y) + int(dir * 7.0)
	var h := minf(18.0, size.y * 0.45)
	var x := r.position.x
	while x < r.end.x - 4.0:
		var w := minf(rng.randf_range(34.0, 56.0), r.end.x - x)
		var y0 := edge_y if dir > 0.0 else edge_y - h
		var slab := Rect2(x + 1.5, y0 + rng.randf_range(-1.5, 1.5), w - 3.0, h)
		_b.rect(slab.grow(1.5), INK)
		_b.rect(slab, tile.darkened(rng.randf_range(0.0, 0.25)))
		_b.rect(Rect2(slab.position, Vector2(slab.size.x, 3)), tile.lightened(0.18))
		if dir < 0.0 and rng.randf() < 0.35:  # stalactite drip under ceilings
			var dx := x + w * 0.5
			_b.convex(PackedVector2Array([Vector2(dx - 6, edge_y), Vector2(dx + 6, edge_y),
				Vector2(dx, edge_y + rng.randf_range(14.0, 34.0))]), INK)
		x += w
