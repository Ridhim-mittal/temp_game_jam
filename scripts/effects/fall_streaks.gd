extends Node2D
## Comic speed lines streaming up past Vesper during a long fall (player.gd
## sets `amount`): they fade in as a fall gets long enough for a hard
## landing and turn red once it's long enough to hurt.

const DUST := Color(0.97, 0.94, 0.86)
const INK := Color(0.05, 0.03, 0.1)
const DANGER := Color(1.0, 0.42, 0.32)

var amount := 0.0  # 0..1
var danger := false

var _time := 0.0


func _ready() -> void:
	z_index = 4  # over the level art (the player sits at 0); lines stay above her head


func _process(delta: float) -> void:
	_time += delta
	if amount > 0.0 or visible:
		visible = amount > 0.0
		queue_redraw()


func _draw() -> void:
	var col := DANGER if danger else DUST
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (26.0 + (i / 2) * 10.0) + sin(i * 7.3) * 3.0  # framing the body, clear of the hat
		var loop := 170.0
		var phase := fmod(_time * 1200.0 + i * 53.0, loop)
		var top := 10.0 - phase
		var length := 40.0 + 22.0 * absf(sin(i * 3.1))
		var a := amount * minf(phase / 25.0, 1.0) * minf((loop - phase) / 60.0, 1.0)
		draw_line(Vector2(x, top), Vector2(x, top - length), Color(INK, a * 0.85), 7.0)
		draw_line(Vector2(x, top), Vector2(x, top - length), Color(col, a), 3.5)
