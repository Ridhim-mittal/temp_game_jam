extends Node3D
## Something Vesper can use with Interact (E / gamepad LB) when she's near:
## shows a prompt over it and asks the room to open an overlay
## (room.gd open_overlay: "shop", "skills", ...).

const ScreenAnchor = preload("res://scripts/clearing/screen_anchor.gd")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")

@export var action := "shop"
@export var prompt := "SHOP"
@export var radius := 2.4
@export var prompt_height := 2.2

var _anchor: Node2D
var _label: Label


func _ready() -> void:
	add_to_group("interactable")


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near: bool = player != null and not player.dead and get_tree().paused == false \
		and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < radius
	_show_prompt(near)
	if near and Input.is_action_just_pressed("interact"):
		var room := get_tree().current_scene
		if room and room.has_method("open_overlay"):
			room.open_overlay(action)


func _show_prompt(on: bool) -> void:
	if on and _anchor == null:
		var ui := get_tree().current_scene.get_node_or_null("UI")
		if ui == null:
			return
		_anchor = ScreenAnchor.new()
		_anchor.world_position = global_position + Vector3(0, prompt_height, 0)
		_label = Label.new()
		_label.text = "E  %s" % prompt
		_label.add_theme_font_override("font", TITLE_FONT)
		_label.add_theme_font_size_override("font_size", 26)
		_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
		_label.add_theme_constant_override("outline_size", 10)
		_anchor.add_child(_label)
		ui.add_child(_anchor)
		_label.position = -_label.get_minimum_size() * Vector2(0.5, 1.0)
	elif not on and _anchor != null:
		_anchor.queue_free()
		_anchor = null
