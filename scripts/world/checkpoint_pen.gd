@tool
extends Area2D
## Checkpoint: a cute little fountain pen standing on its nib in a drop of
## ink. Asleep (grey-blue, closed eyes, floating "z") until Vesper walks
## past; then it wakes up, turns green, bounces and pops "SAVED!". Dying
## afterwards respawns you here (state lives in the GameState autoload, so
## it survives the level reload). Pens already passed stay green; the most
## recent one also wears a little sparkle.
## Origin = floor contact point.

const INK := Color(0.05, 0.03, 0.1)
const ComicText = preload("res://scripts/effects/comic_text.gd")
const OnScreen = preload("res://scripts/core/on_screen.gd")

@export var sleep_color := Color(0.42, 0.46, 0.66)
@export var awake_color := Color(0.36, 0.86, 0.46)
@export var cap_color := Color(0.98, 0.84, 0.3)

var _active := false   # passed (green)
var _current := false  # the one you respawn at
var _time := 0.0
var _bounce := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	_time = position.x * 0.01
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 140)
	cs.shape = rect
	cs.position = Vector2(0, -70)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	var state := get_node_or_null("/root/GameState")
	if state:
		var id: String = state.id_of(self)
		_active = state.passed.has(id)
		_current = state.checkpoint_id == id


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var state := get_node_or_null("/root/GameState")
	if state == null or state.checkpoint_id == state.id_of(self):
		return
	state.set_checkpoint(self, global_position + Vector2(0, -27))  # player origin above the floor
	for pen in get_tree().get_nodes_in_group("checkpoint"):
		pen._current = false
	_active = true
	_current = true
	_bounce = 1.0
	var pop := ComicText.new()
	pop.text = "SAVED!"
	pop.color = awake_color
	pop.position = global_position + Vector2(0, -150)
	get_tree().current_scene.add_child(pop)


func _enter_tree() -> void:
	add_to_group("checkpoint")


func _process(delta: float) -> void:
	_time += delta
	_bounce = move_toward(_bounce, 0.0, delta * 2.2)
	if OnScreen.near(self, 160.0):
		queue_redraw()


func _draw() -> void:
	var body_col := awake_color if _active else sleep_color
	# ink puddle the nib stands in
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 30.0, INK)
	draw_circle(Vector2.ZERO, 24.0, body_col.darkened(0.45) if _active else Color(0.12, 0.1, 0.2))
	draw_set_transform(Vector2.ZERO)

	# sway while asleep, springy bounce when it wakes
	var sway := sin(_time * 1.6) * (0.06 if not _active else 0.03)
	var hop := -absf(sin(_bounce * PI * 3.0)) * 18.0 * _bounce
	var squash := 1.0 + 0.15 * sin(_bounce * PI * 6.0) * _bounce
	draw_set_transform(Vector2(0, hop), sway, Vector2(1.0 / squash, squash))

	# nib (steel, with slit and breather hole)
	var nib := PackedVector2Array([Vector2(-10, -22), Vector2(10, -22), Vector2(0, 0)])
	draw_colored_polygon(_grow(nib, 2.5), INK)
	draw_colored_polygon(nib, Color(0.86, 0.88, 0.95))
	draw_line(Vector2(0, -14), Vector2(0, -2), INK, 1.5)
	draw_circle(Vector2(0, -15), 2.0, INK)
	# barrel: rounded capsule
	var barrel := Rect2(-15, -96, 30, 74)
	draw_rect(barrel.grow(2.5), INK)
	draw_circle(Vector2(0, -96), 17.5, INK)
	draw_rect(barrel, body_col)
	draw_circle(Vector2(0, -96), 15.0, body_col)
	draw_rect(Rect2(-11, -100, 5, 70), body_col.lightened(0.3))  # shine
	# grip ring + cap clip
	draw_rect(Rect2(-15, -30, 30, 7), cap_color)
	draw_rect(Rect2(-15, -30, 30, 7), INK, false, 1.5)
	draw_rect(Rect2(10, -104, 5, 34), cap_color)
	draw_rect(Rect2(10, -104, 5, 34), INK, false, 1.5)
	# face
	var eye_y := -72.0
	if _active:
		# happy ^ ^ eyes, open smile, blush
		for ex in [-7.0, 7.0]:
			draw_polyline(PackedVector2Array([Vector2(ex - 4, eye_y + 2), Vector2(ex, eye_y - 3), Vector2(ex + 4, eye_y + 2)]), INK, 2.5)
		draw_arc(Vector2(0, -61), 5.0, 0.15, PI - 0.15, 10, INK, 2.5)
		for bx in [-11.0, 11.0]:
			draw_circle(Vector2(bx, -63), 3.2, Color(1.0, 0.5, 0.55, 0.85))
	else:
		# sleepy closed eyes and a tiny mouth
		for ex in [-7.0, 7.0]:
			draw_arc(Vector2(ex, eye_y - 2), 3.5, 0.3, PI - 0.3, 8, INK, 2.0)
		draw_circle(Vector2(0, -62), 1.6, INK)
		for bx in [-11.0, 11.0]:
			draw_circle(Vector2(bx, -64), 2.6, Color(1.0, 0.6, 0.65, 0.45))
	draw_set_transform(Vector2.ZERO)

	if not _active:
		# drifting "z"s
		var font := ThemeDB.fallback_font
		for k in 2:
			var t := fmod(_time * 0.5 + k * 0.5, 1.0)
			var p := Vector2(16 + t * 14.0, -110 - t * 34.0)
			draw_string(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 + t * 8), Color(0.85, 0.88, 1.0, 1.0 - t))
	elif _current:
		# sparkle above the pen you will respawn at
		var c := Vector2(0, -132 + sin(_time * 3.0) * 4.0)
		var r := 7.0 + 2.0 * sin(_time * 5.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.3, -r * 0.3), c + Vector2(r, 0),
			c + Vector2(r * 0.3, r * 0.3), c + Vector2(0, r), c + Vector2(-r * 0.3, r * 0.3), c + Vector2(-r, 0),
			c + Vector2(-r * 0.3, -r * 0.3)]), Color(1.0, 0.95, 0.6))


func _grow(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := Geometry2D.offset_polygon(poly, d, Geometry2D.JOIN_MITER)
	return out[0] if not out.is_empty() else poly
