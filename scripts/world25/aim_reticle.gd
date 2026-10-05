extends Control
## Mouse aim reticle for the Gutter. room.gd puts it on top of the UI layer;
## it stands in for the hidden OS cursor while Vesper aims with the mouse
## (clearing_player.gd `is_mouse_aiming()`), and hides in menus, overlays
## and when a gamepad takes over.
##
## An inked ring with four ticks turning slowly round it. The ticks close
## in and it warms to the Ember's orange when a swing would land on a
## monster, and it kicks out on every swing.

const INK := Color(0.04, 0.03, 0.06, 0.9)
const PAPER := Color(0.97, 0.95, 0.9)
const EMBER := Color(1.0, 0.58, 0.14)

## Ring radius, px.
@export var radius := 13.0
## Turning speed of the ticks, radians a second.
@export var spin := 0.7

var _time := 0.0
var _lock := 0.0  # 0..1, eased towards "a swing would hit"
var _kick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player")
	var room := get_tree().current_scene
	var on: bool = player != null and player.has_method("is_mouse_aiming") and player.is_mouse_aiming() \
		and not player.dead and not get_tree().paused \
		and room != null and room.has_method("in_gameplay") and room.in_gameplay()
	visible = on
	if not on:
		return
	_lock = move_toward(_lock, 1.0 if player.swing_would_hit() else 0.0, delta * 8.0)
	_kick = player.swing_flash()
	queue_redraw()


func _draw() -> void:
	var c := get_local_mouse_position()
	var r := radius * (1.0 + 0.35 * _kick)
	var col := PAPER.lerp(EMBER, _lock)
	col.a = 0.85
	# the ring, broken in four short gaps
	for i in 4:
		var a0 := i * TAU / 4.0 + 0.25
		var a1 := a0 + TAU / 4.0 - 0.5
		draw_arc(c, r, a0, a1, 10, INK, 5.0, true)
		draw_arc(c, r, a0, a1, 10, col, 2.2, true)
	# ticks: outside the ring, pulled in when a swing would land
	var inner := lerpf(r + 5.0, r + 1.0, _lock) + 6.0 * _kick
	var outer := inner + 7.0
	var turn := _time * spin
	for i in 4:
		var a := turn + i * TAU / 4.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * inner, c + d * outer, INK, 5.0, true)
		draw_line(c + d * inner, c + d * outer, col, 2.2, true)
	draw_circle(c, 3.0, INK)
	draw_circle(c, 1.6, col)
