@tool
extends "res://scripts/world/coin.gd"
## The big Lumen (the "gem"): the same coin as coin.gd, twice the size and
## worth 15 at once, with its own glow behind it (a pale aura, slowly turning
## rays and sparkles winking round it) so it reads from far away. Placed off
## the usual path, as a reward for looking. Pops "x15" when picked up.

const AURA := Color(0.62, 0.95, 1.0)
const RAYS := Color(1.0, 0.92, 0.6)

var _glow: Node2D


func _init() -> void:
	value = 15
	radius = 26.0
	spin_speed = 2.2
	pop_text = "x15"
	pop_size = 38


func _ready() -> void:
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.show_behind_parent = true
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_glow) and OnScreen.near(self, 160.0):
		_glow.queue_redraw()


func _draw_glow() -> void:
	var bob := sin(_time * 2.6) * 3.0
	var c := Vector2(0, bob)
	var pulse := 0.85 + 0.15 * sin(_time * 3.1)
	# soft aura
	for k in 5:
		_glow.draw_circle(c, (radius + 8.0 + k * 11.0) * pulse, Color(AURA, 0.12 - k * 0.02))
	# slowly turning rays
	for k in 10:
		var a := _time * 0.5 + TAU * k / 10.0
		var d := Vector2.from_angle(a)
		var n := Vector2(-d.y, d.x)
		var reach := radius + 26.0 + 10.0 * sin(_time * 2.0 + k * 1.3)
		_glow.draw_colored_polygon(PackedVector2Array([c + d * (radius + 2.0) + n * 4.0, c + d * reach, c + d * (radius + 2.0) - n * 4.0]),
			Color(RAYS, 0.32))
	# sparkles winking round it
	for k in 4:
		var t := fposmod(_time * 0.8 + k * 0.25, 1.0)
		var a := TAU * k / 4.0 + 0.6 + floorf(_time * 0.8 + k * 0.25) * 1.9
		var p := c + Vector2.from_angle(a) * (radius + 16.0)
		var s := sin(t * PI) * 7.0
		_glow.draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), Color(1, 1, 1, 0.9), 2.0)
		_glow.draw_line(p + Vector2(0, -s), p + Vector2(0, s), Color(1, 1, 1, 0.9), 2.0)
