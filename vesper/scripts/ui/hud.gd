extends Control
## Draws health "masks" and shows a controls hint.

var current := 5
var maximum := 5


func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)


func _on_health_changed(cur: int, max_hp: int) -> void:
	current = cur
	maximum = max_hp
	queue_redraw()


func _draw() -> void:
	var ink := Color(0.08, 0.08, 0.1)
	for i in maximum:
		var c := Vector2(44 + i * 42, 44)
		if i < current:
			draw_circle(c, 15, Color(0.97, 0.95, 0.9))
			draw_arc(c, 15, 0, TAU, 24, ink, 3.0)
		else:
			draw_arc(c, 15, 0, TAU, 24, Color(ink, 0.35), 3.0)
