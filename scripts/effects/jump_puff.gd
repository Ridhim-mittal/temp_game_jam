extends Node2D
## Little ring of ink dust kicked out under Vesper's feet by a double jump.

const DUST := Color(0.97, 0.94, 0.86)

var _age := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.28:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / 0.28
	var r := 8.0 + t * 26.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(DUST, 0.9 * (1.0 - t)), 4.0 * (1.0 - t) + 1.0)
	draw_set_transform(Vector2.ZERO)
	for k in 5:
		var a := PI + PI * (k + 0.5) / 5.0  # puffs fan out and down
		draw_circle(Vector2(cos(a) * r * 0.9, -sin(a) * 6.0 * t), 3.0 * (1.0 - t), Color(DUST, 0.8 * (1.0 - t)))
