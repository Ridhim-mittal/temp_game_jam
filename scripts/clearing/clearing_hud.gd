extends Control
## Gutter HUD (design doc section 10), top-left:
##  - ink bottles (ink_bottles.gd, the same as in 2D): six to start, counted
##    in half bottles; they shake and splash on hits, sparkle on heals
##  - the Ember's fuel as a flame and bar with its button, a mouse with the right button lit (hold to raise it);
##    it greys while the Ember is guttered out. Light or life, as in 2D (hud.gd):
##    the bar is marked in thirds, each third one heal, and an "F HEAL" tag shows
##    under it whenever holding F would heal right now (player can_heal())
## Top-right, the coin purse (Profile.lumens, the shop's money, carried over
## from the 2D levels; the Margins' monsters drop the same gold Lumens,
## lumen.gd): a dark ink tag with the 2D HUD's spinning gold coin (coin.gd
## draw_coin) and the count in gold, which pops when coins come in.

const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const InkBottles = preload("res://scripts/ui/ink_bottles.gd")
const Coin = preload("res://scripts/world/coin.gd")
const GOLD_TEXT := Color(1.0, 0.85, 0.3)
const INK := Color(0.06, 0.04, 0.09)
const PAPER := Color(0.97, 0.95, 0.9)

## Centre of the first heart, and the step to the next.
const HEARTS_AT := Vector2(46, 40)  # centre of the first ink bottle

var current := 12  # half ink bottles
var maximum := 12
var fuel := 60.0
var max_fuel := 100.0
var flash_cost := 25.0
var heal_cost := 33.0  # a third of the Ember: one heal

var _fuel_shown := 60.0
var _bottles := InkBottles.new()
var _relight := 20.0
var _hit_flash := 0.0
var _time := 0.0
var coins := 0
var _coin_bump := 0.0  # 1 when coins come in, decays


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # sized to the screen: the purse sits on its right edge
	var profile := get_node_or_null("/root/Profile")
	if profile:
		coins = profile.lumens
		profile.changed.connect(_on_profile_changed)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)
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
	current = cur
	maximum = max_hp
	_bottles.set_health(cur, max_hp)


func _on_profile_changed() -> void:
	var profile := get_node_or_null("/root/Profile")
	if profile == null:
		return
	if profile.lumens > coins:
		_coin_bump = 1.0
	coins = profile.lumens


func _on_ember_changed(f: float, max_f: float) -> void:
	fuel = f
	max_fuel = max_f
	var player := get_tree().get_first_node_in_group("player")
	if player and "heal_cost" in player:
		heal_cost = player.heal_cost


func _process(delta: float) -> void:
	_time += delta
	_bottles.update(delta)
	_fuel_shown = move_toward(_fuel_shown, fuel, delta * 80.0)
	_hit_flash = maxf(_hit_flash - delta * 2.0, 0.0)
	_coin_bump = maxf(_coin_bump - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	_draw_health()
	_draw_ember(Vector2(38, 78))
	_draw_coins()


## The coin purse, top right: a dark slanted ink tag, the spinning gold Lumen
## and "x N" in gold, as in 2D; it pops when coins come in.
func _draw_coins() -> void:
	var text := "x %d" % coins
	var fs := 30 + int(8.0 * _coin_bump)
	var tw := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var right := size.x - 30.0
	var tag := Rect2(Vector2(right - tw - 74.0, 22.0), Vector2(tw + 74.0, 48.0))
	draw_colored_polygon(_slant(Rect2(tag.position + Vector2(4, 4), tag.size), 12.0), Color(0, 0, 0, 0.45))
	draw_colored_polygon(_slant(tag, 12.0), Color(INK, 0.88))
	draw_polyline(_close(_slant(tag, 12.0)), Color(Coin.GOLD_DARK, 0.9), 2.0)
	Coin.draw_coin(self, Vector2(tag.position.x + 32.0, tag.position.y + 24.0), 13.0 * (1.0 + 0.25 * _coin_bump), _time * 2.0 + _coin_bump * 6.0)
	var base := Vector2(tag.position.x + 54.0, tag.position.y + 35.0)
	draw_string_outline(TITLE_FONT, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, INK)
	draw_string(TITLE_FONT, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_TEXT.lerp(Color.WHITE, _coin_bump * 0.6))


func _draw_health() -> void:
	_bottles.draw(self, HEARTS_AT)  # ink bottles, the same as in 2D (ink_bottles.gd)


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
	# light or life: the bar in thirds, each third one heal (F), as in 2D
	var third := heal_cost / maxf(max_fuel, 1.0)
	var tk := third
	while third > 0.0 and tk < 0.999:
		var hx := bar.position.x + bar.size.x * tk
		draw_line(Vector2(hx + 2, bar.position.y), Vector2(hx - 2, bar.end.y), Color(INK, 0.85), 2.5)
		tk += third
	if player != null and player.has_method("can_heal") and player.can_heal():
		# F would heal right now: a key cap under the bar
		var pulse := 0.6 + 0.4 * sin(_time * 6.0)
		var kc := Rect2(Vector2(bar.position.x, bar.end.y + 10), Vector2(22, 22))
		draw_rect(kc.grow(2.0), Color(INK, pulse))
		draw_rect(kc, Color(PAPER, pulse))
		draw_string(TITLE_FONT, kc.position + Vector2(6, 18), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, pulse))
		draw_string_outline(TITLE_FONT, kc.position + Vector2(30, 18), "HEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(INK, pulse))
		draw_string(TITLE_FONT, kc.position + Vector2(30, 18), "HEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.85, 0.45, pulse))
	# where a guttered Ember lights again: shown only while it is out (as in 2D)
	if snuffed:
		var rx := bar.position.x + bar.size.x * _relight / max_fuel
		var a := 0.6 + 0.4 * sin(_time * 8.0)
		for k in 3:
			var y0 := bar.position.y - 4.0 + k * 8.0
			draw_line(Vector2(rx, y0), Vector2(rx, y0 + 4.0), Color(1.0, 1.0, 1.0, a), 2.0)
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
