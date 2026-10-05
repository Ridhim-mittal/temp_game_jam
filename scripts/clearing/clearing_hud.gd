extends Control
## Gutter HUD (design doc section 10), top-left:
##  - hearts, one per ink drop (six to start), inked like a comic: a lost
##    heart flashes white and empties, the last one pulses, a healed one
##    glows green
##  - the healing counter: an ink flask with how many heals the Ember's fuel
##    covers right now (hold F), glowing when at least one is ready
##  - the Ember's fuel as a flame and bar with its button, a mouse with the right button lit (hold to raise it);
##    it greys while the Ember is guttered out
## (There is no money in the Gutter: the Lumen counter is gone.)

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)
const BLOOD := Color(0.86, 0.17, 0.2)
const BLOOD_DARK := Color(0.42, 0.06, 0.1)
const TRAIL := Color(1.0, 0.86, 0.78)
const HEAL := Color(0.55, 0.95, 0.75)

## Centre of the first heart, and the step to the next.
const HEARTS_AT := Vector2(46, 38)
const HEART_STEP := 40.0

var current := 6
var maximum := 6
var fuel := 60.0
var max_fuel := 100.0
var flash_cost := 25.0
var heal_cost := 33.0

var _fuel_shown := 60.0
var _hp_shown := 6.0  # hearts above this are still flashing out after a hit
var _relight := 20.0
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
			if "relight_at" in player:
				_relight = player.relight_at
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
	var low := current <= 1 and current > 0
	var pulse := 0.5 + 0.5 * sin(_time * 9.0) if low else 0.0
	for i in maximum:
		var c := HEARTS_AT + Vector2(HEART_STEP * i, 0) + shake
		var tilt := sin(i * 2.3) * 0.08  # hand-inked: no two quite level
		var full := i < current
		var losing := not full and i < ceili(_hp_shown)  # just lost, still flashing
		var s := 1.0 + (0.18 * pulse if full and i == current - 1 else 0.0)
		var outline := _heart(c + Vector2(3, 3), 17.0 * s, tilt)
		draw_colored_polygon(outline, Color(0, 0, 0, 0.45))
		draw_colored_polygon(_heart(c, 17.0 * s, tilt), INK)
		var fill := BLOOD_DARK.darkened(0.55)
		if full:
			fill = BLOOD.lerp(Color(1.0, 0.45, 0.4), pulse * 0.6).lerp(HEAL, _heal_flash * 0.5)
		elif losing:
			fill = TRAIL.lerp(Color.WHITE, _hit_flash)
		draw_colored_polygon(_heart(c + Vector2(0, -0.5), 12.5 * s, tilt), fill)
		if full:
			# wet ink catching the light
			draw_circle(c + Vector2(-5.5, -5.0).rotated(tilt) * s, 3.0 * s, Color(1, 1, 1, 0.45))


## A heart polygon centred on `c`, about 2 * `r` wide, turned by `tilt`.
func _heart(c: Vector2, r: float, tilt: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 28:
		var t := TAU * k / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + (Vector2(x, y + 1.5) / 16.0 * r).rotated(tilt))
	return pts


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
	var player := get_tree().get_first_node_in_group("player")
	var snuffed: bool = player != null and player.get("_snuffed") == true
	var raised: bool = player != null and player.get("ember_raised") == true
	draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), ember.darkened(0.5) if snuffed else ember.lightened(0.25 if raised else 0.0))
	# where a guttered Ember lights again
	var rx := bar.position.x + bar.size.x * _relight / max_fuel
	draw_line(Vector2(rx, bar.position.y), Vector2(rx, bar.end.y), Color(INK, 0.6), 2.0)
	# the button: hold right click to raise it (a mouse, its right button lit)
	var mc := bar.end + Vector2(22, -9)  # centre of the mouse
	draw_colored_polygon(_capsule(mc, 10.0, 13.0), INK)
	draw_colored_polygon(_capsule(mc, 8.0, 11.0), Color(PAPER, 0.85 if not snuffed else 0.35))
	var split := mc.y - 2.0
	var btn := PackedVector2Array([Vector2(mc.x, split)])  # the right button: top-right of the body
	for i in 9:
		btn.append(Vector2(mc.x, mc.y - 3.0) + Vector2.from_angle(-PI * 0.5 + PI * 0.5 * i / 8.0) * Vector2(8.0, 8.0))
	btn.append(Vector2(mc.x + 8.0, split))
	draw_colored_polygon(btn, ember.lightened(0.25) if not snuffed else Color(ember, 0.35))
	draw_line(Vector2(mc.x, mc.y - 11.0), Vector2(mc.x, split), INK, 2.0)
	draw_line(Vector2(mc.x - 8.0, split), Vector2(mc.x + 8.0, split), INK, 2.0)


## A mouse-shaped capsule: half-width `hw`, half-height `hh`, round at both ends.
static func _capsule(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:  # top cap, then bottom cap
		pts.append(c + Vector2(0, -(hh - hw)) + Vector2.from_angle(PI + PI * i / 12.0) * hw)
	for i in 13:
		pts.append(c + Vector2(0, hh - hw) + Vector2.from_angle(PI * i / 12.0) * hw)
	return pts


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
