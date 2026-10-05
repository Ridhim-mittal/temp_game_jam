extends Control
## Gutter HUD (design doc section 10), top-left:
##  - a health bar in an inked frame: one notch per ink drop, a pale trail
##    that eases down after a hit, and a pulse when only one drop is left
##  - the healing counter: an ink flask with how many heals the Ember's fuel
##    covers right now (hold F), glowing when at least one is ready
##  - the Ember's fuel as a flame and bar, notches marking a Flash's cost
## (There is no money in the Gutter: the Lumen counter is gone.)

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)
const BLOOD := Color(0.86, 0.17, 0.2)
const BLOOD_DARK := Color(0.42, 0.06, 0.1)
const TRAIL := Color(1.0, 0.86, 0.78)
const HEAL := Color(0.55, 0.95, 0.75)

const BAR := Rect2(30, 24, 280, 24)

var current := 5
var maximum := 5
var fuel := 60.0
var max_fuel := 100.0
var flash_cost := 25.0
var heal_cost := 33.0

var _fuel_shown := 60.0
var _hp_shown := 5.0  # the pale trail behind the bar
var _hit_flash := 0.0
var _heal_flash := 0.0
var _heals := 0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)
		_hp_shown = current
		if player.has_signal("ember_changed"):
			player.ember_changed.connect(_on_ember_changed)
			flash_cost = player.flash_cost
			if "heal_cost" in player:
				heal_cost = player.heal_cost
			_on_ember_changed(player.fuel, player.max_fuel)
			_fuel_shown = fuel


func _on_health_changed(cur: int, max_hp: int) -> void:
	if cur < current:
		_hit_flash = 1.0
	elif cur > current:
		_heal_flash = 1.0
		_hp_shown = cur
	current = cur
	maximum = max_hp


func _on_ember_changed(f: float, max_f: float) -> void:
	fuel = f
	max_fuel = max_f
	var player := get_tree().get_first_node_in_group("player")
	if player and "heal_cost" in player:
		heal_cost = player.heal_cost
	var heals := int(fuel / maxf(heal_cost, 1.0))
	if heals > _heals:
		_heal_flash = maxf(_heal_flash, 0.6)
	_heals = heals


func _process(delta: float) -> void:
	_time += delta
	_fuel_shown = move_toward(_fuel_shown, fuel, delta * 80.0)
	# the trail waits a beat, then drains down to the real value
	if _hit_flash < 0.6:
		_hp_shown = move_toward(_hp_shown, current, delta * 2.5)
	_hit_flash = maxf(_hit_flash - delta * 2.0, 0.0)
	_heal_flash = maxf(_heal_flash - delta * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	_draw_health()
	_draw_heals(Vector2(48, 124))
	_draw_ember(Vector2(38, 78))


func _draw_health() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * _hit_flash
	var bar := Rect2(BAR.position + shake, BAR.size)
	# inked, slightly slanted frame with a drop shadow
	var frame := _slant(bar.grow(5.0), 6.0)
	draw_colored_polygon(_offset(frame, Vector2(4, 4)), Color(0, 0, 0, 0.45))
	draw_colored_polygon(frame, INK)
	draw_colored_polygon(_slant(bar, 4.0), BLOOD_DARK.darkened(0.55))
	var k := clampf(float(current) / maxi(maximum, 1), 0.0, 1.0)
	var trail := clampf(_hp_shown / maxi(maximum, 1), 0.0, 1.0)
	if trail > k:
		draw_colored_polygon(_slant(Rect2(bar.position, Vector2(bar.size.x * trail, bar.size.y)), 4.0), TRAIL)
	var low := current <= 1 and current > 0
	var pulse := 0.5 + 0.5 * sin(_time * 9.0) if low else 0.0
	var fill := BLOOD.lerp(Color(1.0, 0.45, 0.4), pulse * 0.6).lerp(Color.WHITE, _hit_flash * 0.5).lerp(HEAL, _heal_flash * 0.5)
	if k > 0.0:
		var r := Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y))
		draw_colored_polygon(_slant(r, 4.0), fill)
		# a lighter band along the top: wet ink catching the light
		draw_colored_polygon(_slant(Rect2(r.position + Vector2(2, 3), Vector2(maxf(r.size.x - 6.0, 0.0), 4.0)), 2.0), Color(1, 1, 1, 0.22))
	# a notch for every ink drop
	for i in range(1, maximum):
		var x := bar.position.x + bar.size.x * i / maximum
		draw_line(Vector2(x + 3.0, bar.position.y + 1), Vector2(x - 1.0, bar.end.y - 1), INK, 3.0)
	draw_polyline(_close(frame), PAPER.darkened(0.35), 1.5)
	# "3 / 5" over the right end
	var text := "%d / %d" % [current, maximum]
	var tp := Vector2(bar.end.x - 8.0 - TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, bar.end.y - 4.0)
	draw_string_outline(TITLE_FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, INK)
	draw_string(TITLE_FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, PAPER)


## The healing counter: an ink flask, "x2", and the F key to drink it.
func _draw_heals(c: Vector2) -> void:
	var has_heal := _heals > 0
	var glass := HEAL if has_heal else Color(0.5, 0.5, 0.55)
	var glow := 0.5 + 0.5 * sin(_time * 3.0)
	if has_heal:
		draw_circle(c, 22.0 + glow * 2.0 + _heal_flash * 6.0, Color(HEAL, 0.12 + 0.08 * glow))
	# flask: round body, neck, cork
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(c + Vector2(cos(a) * 12.0, sin(a) * 11.0 + 4.0))
	draw_colored_polygon(body, INK)
	var fill_h := clampf(fuel / maxf(heal_cost, 1.0) - _heals, 0.0, 1.0) if not has_heal else 1.0
	var inner := PackedVector2Array()
	for p in body:
		inner.append(c + (p - c) * 0.72 + Vector2(0, 1.0))
	draw_colored_polygon(inner, Color(glass, 0.35))
	var level := c.y + 4.0 + 8.0 - 16.0 * fill_h
	var liquid := PackedVector2Array()
	for p in inner:
		liquid.append(Vector2(p.x, maxf(p.y, level)))
	draw_colored_polygon(liquid, glass)
	draw_rect(Rect2(c + Vector2(-4, -15), Vector2(8, 9)), INK)
	draw_rect(Rect2(c + Vector2(-3, -12), Vector2(6, 6)), Color(glass, 0.5))
	draw_rect(Rect2(c + Vector2(-5, -19), Vector2(10, 5)), Color(0.55, 0.38, 0.25))
	draw_circle(c + Vector2(-4, 0), 2.5, Color(1, 1, 1, 0.6 if has_heal else 0.25))
	var count := "x%d" % _heals
	var tp := c + Vector2(18, 10)
	draw_string_outline(TITLE_FONT, tp, count, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, INK)
	draw_string(TITLE_FONT, tp, count, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PAPER if has_heal else PAPER.darkened(0.45))
	# key cap
	var key := Rect2(c + Vector2(50, -8), Vector2(20, 20))
	draw_rect(key, Color(PAPER, 0.85 if has_heal else 0.35))
	draw_rect(key, INK, false, 2.0)
	draw_string(TITLE_FONT, key.position + Vector2(5, 17), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)


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
	var bar := Rect2(at + Vector2(18, -6), Vector2(200, 12))
	draw_rect(bar.grow(3.0), INK)
	var w := bar.size.x * clampf(_fuel_shown / max_fuel, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), ember if fuel >= flash_cost else ember.darkened(0.45))
	var n := int(max_fuel / flash_cost)
	for i in range(1, n):
		var x := bar.position.x + bar.size.x * i * flash_cost / max_fuel
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), INK, 2.0)


## A rectangle as a polygon whose right side leans by `lean` pixels.
static func _slant(r: Rect2, lean: float) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x + lean, r.position.y), Vector2(r.end.x - lean, r.end.y),
		Vector2(r.position.x, r.end.y)])


static func _offset(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + by)
	return out


static func _close(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out
