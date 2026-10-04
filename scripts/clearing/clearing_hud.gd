extends Control
## Clearing HUD (design doc section 10): health as ink drops in the
## top-left, and the Ember's fuel as a flame and bar beside them. A drop
## that is lost pops and empties; notches on the bar mark a Flash's cost.

const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)
const LOST := Color(1.0, 0.4, 0.35)

var current := 5
var maximum := 5
var fuel := 60.0
var max_fuel := 100.0
var flash_cost := 25.0

var _pops := {}  # drop index -> 1..0 pop animation
var _fuel_shown := 60.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)
		if player.has_signal("ember_changed"):
			player.ember_changed.connect(_on_ember_changed)
			flash_cost = player.flash_cost
			_on_ember_changed(player.fuel, player.max_fuel)
			_fuel_shown = fuel


func _on_health_changed(cur: int, max_hp: int) -> void:
	for i in range(mini(cur, current), maxi(cur, current)):
		_pops[i] = 1.0
	current = cur
	maximum = max_hp


func _on_ember_changed(f: float, max_f: float) -> void:
	fuel = f
	max_fuel = max_f


func _process(delta: float) -> void:
	_time += delta
	_fuel_shown = move_toward(_fuel_shown, fuel, delta * 80.0)
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
	_draw_ember(Vector2(36, 86))


## Flame icon and fuel bar (orange like the ember on Vesper's scarf).
func _draw_ember(at: Vector2) -> void:
	var ember := Color(1.0, 0.62, 0.22)
	var flick := 1.0 + 0.08 * sin(_time * 12.0)
	var flame := PackedVector2Array()
	for k in 13:
		var a := PI * 0.5 + (k / 12.0 - 0.5) * PI * 1.6
		flame.append(at + Vector2(cos(a) * 9.0, sin(a) * 8.1))
	flame.append(at + Vector2(0, -18.0 * flick))
	draw_colored_polygon(flame, ember)
	draw_polyline(flame + PackedVector2Array([flame[0]]), INK, 2.5)
	draw_circle(at + Vector2(0, 2), 3.5, Color(1.0, 0.92, 0.6))
	var bar := Rect2(at + Vector2(18, -7), Vector2(170, 14))
	draw_rect(bar.grow(3.0), INK)
	var w := bar.size.x * clampf(_fuel_shown / max_fuel, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), ember if fuel >= flash_cost else ember.darkened(0.45))
	var n := int(max_fuel / flash_cost)
	for i in range(1, n):
		var x := bar.position.x + bar.size.x * i * flash_cost / max_fuel
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), INK, 2.0)


## Ink drop: round bottom, pointed top. `c` is the centre of the round part.
static func _drop(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -r * 2.0))
	for k in 17:
		var a := -PI * 0.15 + (PI * 1.3) * k / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
