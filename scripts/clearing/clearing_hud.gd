extends Control
## Clearing HUD: health as ink drops in the top-left, as in the design
## document (section 10). A drop that is lost pops and empties; a full refill
## (respawn) bounces all of them.

const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)
const LOST := Color(1.0, 0.4, 0.35)

var current := 5
var maximum := 5

var _pops := {}  # drop index -> 1..0 pop animation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)


func _on_health_changed(cur: int, max_hp: int) -> void:
	for i in range(mini(cur, current), maxi(cur, current)):
		_pops[i] = 1.0
	current = cur
	maximum = max_hp


func _process(delta: float) -> void:
	for i in _pops.keys():
		_pops[i] -= delta * 3.0
		if _pops[i] <= 0.0:
			_pops.erase(i)
	queue_redraw()


func _draw() -> void:
	for i in maximum:
		var pop: float = _pops.get(i, 0.0)
		var c := Vector2(40 + i * 40, 42)
		var s := 1.0 + 0.35 * sin(pop * PI)
		var drop := _drop(c, 13.0 * s)
		if i < current:
			draw_colored_polygon(drop, PAPER)
			draw_polyline(drop + PackedVector2Array([drop[0]]), INK, 3.0)
			draw_circle(c + Vector2(-4, -2) * s, 2.5 * s, Color(1, 1, 1, 0.9))  # shine
		else:
			var col := LOST if pop > 0.0 else Color(PAPER, 0.55)
			draw_polyline(drop + PackedVector2Array([drop[0]]), INK, 5.0)
			draw_polyline(drop + PackedVector2Array([drop[0]]), col, 2.0)


## Ink drop: round bottom, pointed top. `c` is the centre of the round part.
static func _drop(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -r * 2.0))
	for k in 17:
		var a := -PI * 0.15 + (PI * 1.3) * k / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
