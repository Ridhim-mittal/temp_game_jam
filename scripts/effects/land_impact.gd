extends Node2D
## Ground burst under Vesper's feet after a hard landing (player.gd): a
## flattened shockwave, comic impact lines, rolling dust and rock chips.
## `power` 1 = hard landing; above 1 = a fall that hurt (bigger, ground cracks).

const DUST := Color(0.97, 0.94, 0.86)
const INK := Color(0.05, 0.03, 0.1)
const LIFE := 0.55

var power := 1.0

var _age := 0.0
var _chips: Array = []  # [velocity, spin, size]


func _ready() -> void:
	z_index = 5
	for i in int(6 + 4 * power):
		var side := -1.0 if i % 2 == 0 else 1.0
		_chips.append([Vector2(side * randf_range(90.0, 260.0), -randf_range(220.0, 420.0)) * sqrt(power),
			randf_range(-12.0, 12.0), randf_range(2.5, 4.5)])


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFE
	var fade := 1.0 - t
	var reach := 1.0 - pow(1.0 - minf(t * 1.6, 1.0), 3.0)  # fast out, then settles
	# ground cracks (painful landings only)
	if power > 1.0:
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array([Vector2.ZERO])
			for k in range(1, 5):
				pts.append(Vector2(side * k * 11.0 * power, (2.0 if k % 2 == 0 else -1.0)))
			draw_polyline(pts, Color(INK, minf(fade * 2.0, 1.0)), 3.0)
	# rolling dust clouds hugging the ground
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		var d := (14.0 + k * 9.0) * reach * power
		draw_circle(Vector2(side * d, -6.0 - k * 1.5 * reach), (6.0 + k * 1.6) * (0.6 + 0.6 * t),
			Color(DUST, 0.45 * fade))
	# shockwave ring, squashed flat onto the floor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, 12.0 + 80.0 * reach * power, 0, TAU, 32, Color(DUST, 0.9 * fade), 6.0 * fade + 1.0)
	draw_set_transform(Vector2.ZERO)
	# comic impact lines fanning up from the feet
	for k in 7:
		var a := -PI + PI * (k + 0.5) / 7.0
		var dir := Vector2(cos(a), sin(a) * 0.8)
		var from := dir * (20.0 + 46.0 * reach)
		var to := from + dir * 26.0 * fade * power
		draw_line(from, to, Color(INK, fade), 6.0)
		draw_line(from, to, Color(DUST, fade), 3.0)
	# rock chips arcing out under gravity
	for c in _chips:
		var p: Vector2 = c[0] * _age + Vector2(0, 0.5 * 1400.0 * _age * _age)
		draw_set_transform(p + Vector2(0, -4), c[1] * _age, Vector2.ONE)
		var s: float = c[2]
		draw_rect(Rect2(-s - 1.0, -s - 1.0, s * 2.0 + 2.0, s * 2.0 + 2.0), Color(DUST, fade))
		draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), Color(INK, fade))
	draw_set_transform(Vector2.ZERO)
