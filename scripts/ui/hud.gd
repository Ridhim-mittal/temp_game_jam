extends Control
## Draws Vesper's health as ink bottles (top left, ink_bottles.gd, the same as
## in the Gutter) and the Lumen coin counter
## (top right: the shop's purse, Profile.lumens). Once there are enough
## coins to buy something in Quire's shop, a "B  SHOP" tag shows under the
## counter; once SHOP_HINT_AT (10) coins have been collected in this run
## (GameState.coins, not what was already in the purse), a caption says
## "PRESS B TO OPEN THE SHOP", once a run (GameState.seen "shop_hint"). The
## portrait shakes and flashes on damage. Under it, the Ember meter (ember.gd):
## glows while raised, greys out and shakes when snuffed.

const Coin = preload("res://scripts/world/coin.gd")
const InkBottles = preload("res://scripts/ui/ink_bottles.gd")
const INK := Color(0.05, 0.03, 0.1)
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const BOTTLES_AT := Vector2(104, 40)  # centre of the first ink bottle
const EMBER_BAR := Rect2(100, 66, 200, 13)
## Coins collected in a run that bring up the "PRESS B" caption.
const SHOP_HINT_AT := 10

var current := 12.0   # half ink bottles (ink_bottles.gd)
var maximum := 12.0
var coins := 0

var _hit := 0.0       # 1 on damage, decays: shake + flash
var _healed := 0.0    # 1 on heal, decays: green flash

var _time := 0.0
var _bump := 0.0  # 1 right after a pickup, decays: counter pops
var _ember: Node
var _bottles := InkBottles.new()
var _can_shop := false  # enough coins for something in the shop
var _hint := 0.0  # seconds the "PRESS B" caption has left


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
	_bottles.update(delta)
	_bump = maxf(_bump - delta * 4.0, 0.0)
	_hit = maxf(_hit - delta * 2.5, 0.0)
	_healed = maxf(_healed - delta * 2.0, 0.0)
	_update_shop_hint(delta)
	queue_redraw()  # the coin icon spins


func _update_shop_hint(delta: float) -> void:
	_hint = maxf(_hint - delta, 0.0)
	var profile := get_node_or_null("/root/Profile")
	if profile == null:
		return
	var price: int = profile.cheapest_price()
	_can_shop = price >= 0 and profile.lumens >= price
	var state := get_node_or_null("/root/GameState")
	if state and state.coins >= SHOP_HINT_AT and not state.seen.has("shop_hint"):
		state.seen["shop_hint"] = true
		_hint = 5.0


func _on_health_changed(cur: float, max_hp: float) -> void:
	if cur < current:
		_hit = 1.0
	elif cur > current and current > 0.0:
		_healed = 1.0
	current = cur
	maximum = max_hp
	_bottles.set_health(cur, max_hp)
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
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * _hit * _hit
	# portrait: Vesper's mask in a diamond, then his ink bottles (the same as in the Gutter)
	var c := Vector2(48, 43) + shake
	var d := 30.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d - 4), c + Vector2(d + 4, 0), c + Vector2(0, d + 4), c + Vector2(-d - 4, 0)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]),
		Color(0.92, 0.22, 0.2).lerp(Color(1.0, 1.0, 1.0), _hit * 0.6))
	draw_circle(c + Vector2(0, 2), 15.0, Color(0.98, 0.96, 0.9))
	draw_circle(c + Vector2(5, 0), 3.5, INK)
	draw_rect(Rect2(c + Vector2(-17, -15), Vector2(34, 6)), INK)  # hat brim
	draw_rect(Rect2(c + Vector2(-10, -24), Vector2(20, 10)), INK)
	_bottles.draw(self, BOTTLES_AT, 0.95)


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
	if _can_shop:
		# a key cap and SHOP under the counter
		var pulse := 0.75 + 0.25 * sin(_time * 4.0)
		var at := Vector2(right - 92.0, 74.0)
		draw_rect(Rect2(at, Vector2(26, 26)), Color(0.98, 0.96, 0.9, pulse))
		draw_rect(Rect2(at, Vector2(26, 26)), INK, false, 2.0)
		draw_string(FONT, at + Vector2(7, 21), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
		draw_string_outline(FONT, at + Vector2(34, 21), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, INK)
		draw_string(FONT, at + Vector2(34, 21), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3, pulse))
	if _hint > 0.0:
		_draw_shop_caption()


## "PRESS B TO OPEN THE SHOP": a comic caption box under the coin counter
## (clear of the Writer's narration on the left), the first time 10 coins
## have been collected in a run.
func _draw_shop_caption() -> void:
	var a := clampf(_hint / 0.5, 0.0, 1.0) * clampf((5.0 - _hint) / 0.25, 0.0, 1.0)
	var lines := ["ENOUGH COINS!", "PRESS  B  TO OPEN THE SHOP"]
	var w := 0.0
	for l in lines:
		w = maxf(w, FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x)
	var right := size.x - 36.0
	var box := Rect2(Vector2(right - w - 36.0, 112.0 + sin(_time * 3.0) * 2.0), Vector2(w + 36.0, 76.0))
	draw_rect(Rect2(box.position + Vector2(5, 5), box.size), Color(INK, 0.6 * a))
	draw_rect(box, Color(1.0, 0.95, 0.75, a))
	draw_rect(box, Color(INK, a), false, 3.0)
	# a little tail up to the counter
	var tip := Vector2(right - 40.0, box.position.y - 14.0)
	draw_colored_polygon(PackedVector2Array([tip, Vector2(tip.x - 14, box.position.y + 2), Vector2(tip.x + 6, box.position.y + 2)]),
		Color(1.0, 0.95, 0.75, a))
	draw_polyline(PackedVector2Array([Vector2(tip.x - 14, box.position.y), tip, Vector2(tip.x + 6, box.position.y)]), Color(INK, a), 3.0)
	for i in lines.size():
		var lw := FONT.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(FONT, Vector2(box.end.x - 18.0 - lw, box.position.y + 32.0 + i * 30.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(INK if i == 1 else Color(0.8, 0.3, 0.1), a))
