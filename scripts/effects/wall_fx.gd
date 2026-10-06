extends Node2D
## Wall-slide scrape on the wall beside Vesper (player.gd sets `side`):
## friction streaks along the wall face and paper dust left hanging in the
## air as he slides down past it.

const DUST := Color(0.97, 0.94, 0.86)
const INK := Color(0.05, 0.03, 0.1)

var side := 0  # wall on the right (1) / left (-1); 0 = not sliding
var edge := 13.0  # px from the player's origin to the wall face

var _time := 0.0
var _emit := 0.0
var _puffs: Array = []  # {p (world), age, drift}
var _on := 0.0  # streaks fade in / out


func _ready() -> void:
	z_index = 4
	top_level = true  # puffs live in world space; streaks follow the player


func _process(delta: float) -> void:
	_time += delta
	var parent := get_parent() as Node2D
	global_position = parent.global_position
	_on = move_toward(_on, 1.0 if side != 0 else 0.0, delta * 8.0)
	if side != 0:
		_emit -= delta
		if _emit <= 0.0:
			_emit = 0.05
			_puffs.append({"p": global_position + Vector2(side * edge, randf_range(-6.0, 8.0)), "age": 0.0,
				"drift": Vector2(-side * randf_range(15.0, 45.0), randf_range(-30.0, -5.0))})
	for d in _puffs:
		d.age += delta
	_puffs = _puffs.filter(func(d): return d.age < 0.45)
	if _on > 0.0 or not _puffs.is_empty():
		queue_redraw()


func _draw() -> void:
	for d in _puffs:
		var t: float = d.age / 0.45
		var p: Vector2 = d.p + d.drift * d.age - global_position
		draw_circle(p, 2.0 + t * 5.0, Color(DUST, 0.5 * (1.0 - t)))
	if _on <= 0.0:
		return
	var s := side if side != 0 else 1
	var x := s * (edge + 1.0)
	for i in 3:
		var loop := 70.0
		var phase := fmod(_time * 260.0 + i * 23.0, loop)
		var y0 := 14.0 - phase  # streaks rise up the wall as he slides down
		var a := _on * minf(phase / 12.0, 1.0) * (1.0 - phase / loop)
		var from := Vector2(x + s * i * 2.0, y0)
		var to := from + Vector2(0, -16.0 - i * 6.0)
		draw_line(from, to, Color(INK, a * 0.8), 5.0)
		draw_line(from, to, Color(DUST, a), 2.0)
