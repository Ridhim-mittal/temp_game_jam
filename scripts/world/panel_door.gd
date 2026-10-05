@tool
extends "res://scripts/world/level_exit.gd"
## The way to the next level: a doorway shaped like a blank comic panel,
## pouring warm light onto the floor, with a yellow caption over it
## ("MOVE TO THE NEXT PANEL") and a bouncing arrow. Walk in and the page
## transition (panel_turn.gd) carries you across the gutter to `target_scene`.
## Origin = floor contact point.

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const PanelTurn = preload("res://scripts/effects/panel_turn.gd")
const CAPTION := Color(1.0, 0.9, 0.45)
const W := 96.0
const H := 156.0

## Pencilled into the next panel during the transition.
@export var next_title := ""
## The next level is a vertical one: its panel on the page is tall.
@export var tall_panel := false

var _glow_node: Node2D


func _init() -> void:
	label = "MOVE TO THE NEXT PANEL"
	glow = Color(1.0, 0.88, 0.55)


func _ready() -> void:
	super()
	_glow_node = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_node.material = mat
	_glow_node.show_behind_parent = true
	_glow_node.draw.connect(_draw_light)
	add_child(_glow_node)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _leaving == -1.0 and target_scene != "":
		_leaving = -50.0  # gone for good (never the base class's ink wipe)
		PanelTurn.start(self, target_scene, next_title, tall_panel)


func _process(delta: float) -> void:
	super(delta)
	if _glow_node:
		_glow_node.queue_redraw()


func _draw_light() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.2)
	var c := Vector2(0, -H * 0.5)
	# soft halo, then rays fanning out of the panel
	for k in 5:
		_glow_node.draw_circle(c, (70.0 + k * 34.0) * pulse, Color(glow, 0.07))
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.34 + sin(_time * 0.6 + k) * 0.05
		var d := Vector2.from_angle(a)
		var side := d.orthogonal() * 22.0
		var tip := c + d * (230.0 + 40.0 * sin(_time * 1.3 + k * 1.7))
		_glow_node.draw_colored_polygon(PackedVector2Array([c + side * 0.3, tip + side, tip - side, c - side * 0.3]), Color(glow, 0.05 * pulse))
	# light spilling across the floor
	_glow_node.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.18))
	for k in 3:
		_glow_node.draw_circle(Vector2.ZERO, (120.0 + k * 60.0) * pulse, Color(glow, 0.12))
	_glow_node.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.2)
	var r := Rect2(-W * 0.5, -H, W, H)
	# the panel: thick ink border round a blank, glowing page
	draw_rect(Rect2(r.position + Vector2(7, 7), r.size), Color(INK, 0.45))
	draw_rect(r.grow(7.0), INK)
	draw_rect(r, Color(1.0, 0.97, 0.86))
	for k in 6:  # warm gradient from the middle out
		var g := r.grow(-k * 7.0)
		draw_rect(g, Color(glow.lerp(Color(1, 1, 1), k / 6.0), 0.25 * pulse))
	# sparkles drifting up out of the page
	for k in 9:
		var t := fmod(_time * (0.35 + 0.05 * k) + k * 0.37, 1.0)
		var p := Vector2(-W * 0.4 + fmod(k * 37.0, W * 0.8), -t * H * 1.3)
		var s := 3.0 * sin(t * PI)
		draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), Color(1, 1, 1, 0.9), 1.5)
		draw_line(p + Vector2(0, -s), p + Vector2(0, s), Color(1, 1, 1, 0.9), 1.5)
	# caption box with the sign, bobbing a little
	var bob := sin(_time * 2.0) * 3.0
	var tw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var box := Rect2(-tw * 0.5 - 14, -H - 74 + bob, tw + 28, 38)
	draw_set_transform(Vector2.ZERO, -0.03)
	draw_rect(Rect2(box.position + Vector2(5, 5), box.size), Color(INK, 0.4))
	draw_rect(box.grow(3.0), INK)
	draw_rect(box, CAPTION)
	draw_string(FONT, Vector2(-tw * 0.5, box.end.y - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
	draw_set_transform(Vector2.ZERO)
	# arrow bouncing down at the door
	var ay := -H - 24 + absf(sin(_time * 4.0)) * 10.0
	var arrow := PackedVector2Array([Vector2(-13, ay), Vector2(13, ay), Vector2(0, ay + 16)])
	for poly in Geometry2D.offset_polygon(arrow, 3.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(arrow, CAPTION)
	if _leaving >= 0.0:
		var k := clampf(_leaving / 0.35, 0.0, 1.0)
		draw_circle(Vector2(0, -H * 0.5), 40.0 + k * 1600.0, Color(INK, k))
