@tool
extends "res://scripts/world/solid_block.gd"
## Solid terrain drawn as a comic skyscraper: dark facade, a lit window
## grid, cornice along the roof line. Behaves exactly like SolidBlock.

const TriBatch = preload("res://scripts/background/tri_batch.gd")
const INK := Color(0.05, 0.03, 0.1)

@export var facade := Color(0.2, 0.14, 0.3)
@export var window_lit := Color(1.0, 0.85, 0.45)
@export var window_dark := Color(0.12, 0.08, 0.2)


var _b: TriBatch


func _draw() -> void:
	_b = TriBatch.new()  # hundreds of tiles/windows -> one draw call
	var r := Rect2(-size * 0.5, size)
	_b.rect(r, facade)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 31 + int(position.y)
	var y := r.position.y + 34.0
	while y < r.end.y - 30.0:
		var x := r.position.x + 26.0
		while x < r.end.x - 34.0:
			_b.rect(Rect2(x, y, 18, 26), window_lit if rng.randf() < 0.28 else window_dark)
			x += 46.0
		y += 58.0
	# vertical pilasters for depth
	var px := r.position.x + 12.0
	while px < r.end.x:
		_b.rect(Rect2(px, r.position.y + 14, 4, size.y - 14), facade.darkened(0.3))
		px += 184.0
	# cornice
	_b.rect(Rect2(r.position.x - 6, r.position.y, size.x + 12, 14), facade.lightened(0.18))
	_b.rect(Rect2(r.position.x - 6, r.position.y, size.x + 12, 4), facade.lightened(0.4))
	_b.rect_outline(r, INK, 3.0)
	_b.flush(self)
