@tool
extends Area2D
## Doorway to another scene: a torn-open page glowing with light. Walk into
## it to go to `target_scene` (ink-wipe flash first).
## Origin = floor contact point.

const INK := Color(0.02, 0.02, 0.03)

@export_file("*.tscn") var target_scene := ""
@export var label := "ONWARD"
@export var glow := Color(1.0, 0.9, 0.6)

var _time := 0.0
var _leaving := -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 110)
	cs.shape = rect
	cs.position = Vector2(0, -55)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _leaving < 0.0 and target_scene != "":
		_leaving = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _leaving >= 0.0:
		_leaving += delta
		if _leaving > 0.35:
			get_tree().change_scene_to_file(target_scene)
			_leaving = -100.0
	queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.5)
	for k in 4:
		draw_circle(Vector2(0, -60), (60.0 + k * 22.0) * pulse, Color(glow, 0.08 - k * 0.018))
	# torn page opening: jagged edged doorway
	var pts := PackedVector2Array()
	for j in 13:
		var t := j / 12.0
		pts.append(Vector2(-34 + (j % 2) * 6.0, -t * 120.0))
	for j in 13:
		var t := 1.0 - j / 12.0
		pts.append(Vector2(34 - (j % 2) * 6.0, -t * 120.0))
	draw_colored_polygon(pts, Color(glow, pulse))
	pts.append(pts[0])
	draw_polyline(pts, INK, 3.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string_outline(font, Vector2(-w * 0.5, -132), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, INK)
	draw_string(font, Vector2(-w * 0.5, -132), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, glow)
	if _leaving >= 0.0:
		var k := clampf(_leaving / 0.35, 0.0, 1.0)
		draw_circle(Vector2(0, -60), 40.0 + k * 1600.0, Color(INK, k))
