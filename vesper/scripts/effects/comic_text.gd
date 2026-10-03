extends Node2D
## Comic-book sound-effect popup ("THWACK!") - ties into the Comic theme.

var text := "THWACK!"
var color := Color(1.0, 0.82, 0.15)
var font_size := 30


func _ready() -> void:
	z_index = 100
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 10
	settings.outline_color = Color(0.05, 0.05, 0.05)
	label.label_settings = settings
	label.text = text
	add_child(label)
	label.position = -label.get_minimum_size() * 0.5

	rotation = randf_range(-0.25, 0.25)
	scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.08)
	t.parallel().tween_property(self, "position:y", position.y - 30.0, 0.5)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)
