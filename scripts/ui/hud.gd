extends Control
## Draws health "masks" (top left) and the Lumen coin counter (top right).

const Coin = preload("res://scripts/world/coin.gd")
const INK := Color(0.05, 0.03, 0.1)

var current := 5
var maximum := 5
var coins := 0

var _time := 0.0
var _bump := 0.0  # 1 right after a pickup, decays: counter pops


func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)
		if player.has_signal("coins_changed"):
			player.coins_changed.connect(_on_coins_changed)
			coins = player.coins


func _process(delta: float) -> void:
	_time += delta
	_bump = maxf(_bump - delta * 4.0, 0.0)
	queue_redraw()  # the coin icon spins


func _on_health_changed(cur: int, max_hp: int) -> void:
	current = cur
	maximum = max_hp
	queue_redraw()


func _on_coins_changed(total: int) -> void:
	coins = total
	_bump = 1.0


func _draw() -> void:
	var ink := Color(0.08, 0.08, 0.1)
	for i in maximum:
		var c := Vector2(44 + i * 42, 44)
		if i < current:
			draw_circle(c, 15, Color(0.97, 0.95, 0.9))
			draw_arc(c, 15, 0, TAU, 24, ink, 3.0)
		else:
			draw_arc(c, 15, 0, TAU, 24, Color(ink, 0.35), 3.0)
	_draw_coin_counter()


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
