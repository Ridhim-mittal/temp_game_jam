extends Control
## Health bars for the 2D bosses that are awake: every node in group "boss"
## with `health`, `hp` and `dead` that isn't asleep (state 0 / "SLEEP") gets a
## comic bar along the bottom of the screen (in the rock under the floor
## line), its `display_name` over it; two bosses sit side by side. Bars fade in when the fight starts and drain
## smoothly. Add one to a level's UI layer (shades_city.tscn, ink_cave.tscn).

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const PAPER := Color(0.98, 0.95, 0.87)
const FILL := Color(0.62, 0.34, 0.95)
const RAGE := Color(0.95, 0.2, 0.22)
const LAG := Color(1.0, 0.9, 0.5)

var _shown := {}  # boss -> {alpha, lag}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	for b in get_tree().get_nodes_in_group("boss"):
		if not (b is Node2D) or not ("health" in b) or not ("hp" in b):
			continue
		var awake: bool = not ("state" in b and b.state == 0)
		if awake and not _shown.has(b) and not b.dead:
			_shown[b] = {"alpha": 0.0, "lag": 1.0}
	for b in _shown.keys():
		var e: Dictionary = _shown[b]
		if not is_instance_valid(b):
			e.alpha = move_toward(e.alpha, 0.0, delta * 2.0)
			if e.alpha <= 0.0:
				_shown.erase(b)
			continue
		var frac := clampf(float(b.health) / maxf(b.hp, 1), 0.0, 1.0)
		e.alpha = move_toward(e.alpha, 0.0 if b.dead else 1.0, delta * (1.2 if b.dead else 3.0))
		e.lag = move_toward(e.lag, frac, delta * 0.6) if e.lag > frac else frac
		if b.dead and e.alpha <= 0.0:
			_shown.erase(b)
	queue_redraw()


func _draw() -> void:
	var i := 0
	var count := 0
	for b in _shown:
		if _shown[b].alpha > 0.0:
			count += 1
	for b in _shown:
		var e: Dictionary = _shown[b]
		if e.alpha <= 0.0:
			continue
		var a: float = e.alpha
		# down in the rock under the floor line; two bosses sit side by side
		var w := 520.0 if count < 2 else 380.0
		var left := size.x * 0.5 - w * 0.5 if count < 2 else size.x * 0.5 + (-w - 30.0 if i == 0 else 30.0)
		var r := Rect2(left, size.y - 44.0, w, 14)
		var frac := 0.0
		var name := "BOSS"
		var rage := false
		if is_instance_valid(b):
			frac = clampf(float(b.health) / maxf(b.hp, 1), 0.0, 1.0)
			name = b.display_name if "display_name" in b else String(b.name).to_upper()
			rage = "_enraged" in b and b._enraged
		draw_string_outline(FONT, r.position + Vector2(0, -6), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(INK, a))
		draw_string(FONT, r.position + Vector2(0, -6), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(RAGE if rage else PAPER, a))
		draw_rect(r.grow(4), Color(INK, a))
		draw_rect(r, Color(0.2, 0.16, 0.26, a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * e.lag, r.size.y)), Color(LAG, a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(RAGE if rage else FILL, a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, 4)), Color(1, 1, 1, 0.3 * a))
		for k in range(1, 4):  # quarter notches
			var x := r.position.x + r.size.x * k / 4.0
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(INK, 0.6 * a), 2.0)
		i += 1
