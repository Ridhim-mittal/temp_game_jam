extends Control
## Draws the continuous health bar (top left) and the Lumen coin counter
## (top right). The bar has a trailing "damage ghost" that drains after a
## hit (shows how much it took), shakes on damage, flashes green on heals
## and pulses when health is low. Under it, the Ember meter (ember.gd):
## glows while raised, greys out and shakes when snuffed.

const Coin = preload("res://scripts/world/coin.gd")
const INK := Color(0.05, 0.03, 0.1)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const BAR := Rect2(84, 30, 280, 26)
const EMBER_BAR := Rect2(100, 66, 200, 13)

var current := 100.0
var maximum := 100.0
var coins := 0

var _ghost := 100.0   # lags behind `current` after damage
var _hit := 0.0       # 1 on damage, decays: shake + flash
var _healed := 0.0    # 1 on heal, decays: green flash

var _time := 0.0
var _bump := 0.0  # 1 right after a pickup, decays: counter pops
var _ember: Node


func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		_ember = player.get_node_or_null("Ember")
		_on_health_changed(player.health, player.max_health)
		if player.has_signal("coins_changed"):
			player.coins_changed.connect(_on_coins_changed)
			coins = player.coins


func _process(delta: float) -> void:
	_time += delta
	_bump = maxf(_bump - delta * 4.0, 0.0)
	_hit = maxf(_hit - delta * 2.5, 0.0)
	_healed = maxf(_healed - delta * 2.0, 0.0)
	# ghost waits a moment, then drains down to the real value
	if _ghost > current and _hit < 0.6:
		_ghost = move_toward(_ghost, current, delta * maximum * 0.6)
	elif _ghost < current:
		_ghost = current
	queue_redraw()  # the coin icon spins


func _on_health_changed(cur: float, max_hp: float) -> void:
	if cur < current:
		_hit = 1.0
	elif cur > current and current > 0.0:
		_healed = 1.0
	if current <= 0.0 or maximum <= 0.0:
		_ghost = cur  # first update
	current = cur
	maximum = max_hp
	queue_redraw()


func _on_coins_changed(total: int) -> void:
	coins = total
	_bump = 1.0


func _draw() -> void:
	_draw_health()
	_draw_ember()
	_draw_coin_counter()


func _draw_ember() -> void:
	if not is_instance_valid(_ember):
		return
	var frac: float = clampf(_ember.meter / maxf(_ember.max_meter, 1.0), 0.0, 1.0)
	var snuffed: bool = _ember.snuffed
	var raised: bool = _ember.raised
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (2.0 if snuffed else 0.0)
	var r := Rect2(EMBER_BAR.position + shake, EMBER_BAR.size)
	_slanted(r.grow(3.0), INK)
	_slanted(r, Color(0.14, 0.1, 0.12))
	if frac > 0.0:
		var fill := Color(1.0, 0.62, 0.18) if not snuffed else Color(0.55, 0.55, 0.6)
		if raised:
			fill = fill.lerp(Color(1.0, 0.92, 0.6), 0.35 + 0.15 * sin(_time * 14.0))
		if _ember.in_lantern:
			fill = fill.lerp(Color(1.0, 0.95, 0.75), 0.4)
		_slanted(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), fill)
		_slanted(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x * frac, 3)), fill.lightened(0.4))
	# relight mark: below it a snuffed Ember stays out
	var rx: float = r.position.x + r.size.x * _ember.relight_at / _ember.max_meter
	draw_line(Vector2(rx + 2, r.position.y), Vector2(rx - 2, r.end.y), Color(INK, 0.6), 2.0)
	# flame icon
	var c := Vector2(r.position.x - 14, r.position.y + 6)
	var s := 1.0 + (0.25 if raised else 0.0) + 0.08 * sin(_time * 10.0)
	var flame := PackedVector2Array([c + Vector2(0, -11) * s, c + Vector2(6, -2) * s, c + Vector2(5, 5) * s,
		c + Vector2(0, 8) * s, c + Vector2(-5, 5) * s, c + Vector2(-6, -2) * s])
	for poly in Geometry2D.offset_polygon(flame, 2.5, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(flame, Color(1.0, 0.62, 0.18) if not snuffed else Color(0.55, 0.55, 0.6))
	draw_circle(c + Vector2(0, 3) * s, 2.5 * s, Color(1.0, 0.95, 0.7))


func _draw_health() -> void:
	var frac := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	var ghost := clampf(_ghost / maxf(maximum, 1.0), 0.0, 1.0)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * _hit * _hit
	var low := frac < 0.3 and frac > 0.0
	var pulse := (0.5 + 0.5 * sin(_time * 8.0)) if low else 0.0
	var r := Rect2(BAR.position + shake, BAR.size)
	# slanted comic bar: back plate, ghost, fill
	_slanted(r.grow(4.0), INK)
	_slanted(r, Color(0.16, 0.08, 0.12))
	if ghost > frac:
		_slanted(Rect2(r.position + Vector2(r.size.x * frac, 0), Vector2(r.size.x * (ghost - frac), r.size.y)), Color(1.0, 0.95, 0.85))
	if frac > 0.0:
		var fill := Color(0.92, 0.2, 0.22).lerp(Color(1.0, 0.45, 0.35), pulse * 0.6)
		fill = fill.lerp(Color(0.45, 1.0, 0.55), _healed * 0.8)
		var fr := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
		_slanted(fr, fill)
		_slanted(Rect2(fr.position + Vector2(0, 3), Vector2(fr.size.x, 5)), fill.lightened(0.35))  # gloss
		# halftone dots on the lower half
		var x := fr.position.x + 6.0
		while x < fr.end.x - 4.0:
			draw_circle(Vector2(x, fr.end.y - 6.0), 1.6, fill.darkened(0.3))
			x += 7.0
	# tick marks every 20 HP
	for k in range(1, 5):
		var tx := r.position.x + r.size.x * k / 5.0
		draw_line(Vector2(tx + 3, r.position.y + 2), Vector2(tx - 3, r.end.y - 2), Color(INK, 0.55), 2.0)
	# portrait: Vesper's mask in a diamond
	var c := Vector2(48, 43) + shake
	var d := 30.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d - 4), c + Vector2(d + 4, 0), c + Vector2(0, d + 4), c + Vector2(-d - 4, 0)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]),
		Color(0.92, 0.22, 0.2).lerp(Color(1.0, 1.0, 1.0), _hit * 0.6))
	draw_circle(c + Vector2(0, 2), 15.0, Color(0.98, 0.96, 0.9))
	draw_circle(c + Vector2(5, 0), 3.5, INK)
	draw_rect(Rect2(c + Vector2(-17, -15), Vector2(34, 6)), INK)  # hat brim
	draw_rect(Rect2(c + Vector2(-10, -24), Vector2(20, 10)), INK)
	# number
	var text := "%d" % ceili(current)
	var pos := Vector2(r.end.x + 14.0, r.end.y - 2.0)
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 7, INK)
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.95, 0.85))


## Parallelogram (slanted 8 px) filling `r`.
func _slanted(r: Rect2, col: Color) -> void:
	if r.size.x < 2.0:
		return
	var k := minf(8.0, r.size.x * 0.5)
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(k, 0), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - k, r.end.y), Vector2(r.position.x, r.end.y)]), col)


func _draw_coin_counter() -> void:
	var font := ThemeDB.fallback_font
	var text := "x %d" % coins
	var font_size := 30 + int(10.0 * _bump)
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var right := size.x - 36.0
	var baseline := Vector2(right - text_w, 56.0)
	# spins slowly, whips round after a pickup
	Coin.draw_coin(self, Vector2(baseline.x - 30.0, 44.0), 15.0 * (1.0 + 0.25 * _bump), _time * 2.0 + _bump * 6.0)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, INK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.3))
