extends Node
## Autoload "Mood": how dark the game world is right now, 0 (the Lit Pages)
## to 1 (deep in the Margins). The backdrop's dark veil reads `darkness`.
##
##   Mood.set_darkness(0.8)        # snap in a few steps (default 0.5 s)
##   Mood.set_darkness(0.8, 0.0)   # instantly
##
## Levels set it with a LevelMood node (scripts/world/level_mood.gd).
##
## Shortcuts, available everywhere:
##   Esc   open the main menu
##   [ ]   darker / lighter by hand, for testing (holds until the level reloads)

const MENU := "res://scenes/ui/main_menu.tscn"

var darkness := 0.0
## True after [ or ] was used: LevelMood stops driving the value.
var manual := false

var _target := 0.0
var _speed := 2.0
var _toast: Label
var _toast_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_toast = Label.new()
	_toast.position = Vector2(24, 84)
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	_toast.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.13))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.visible = false
	layer.add_child(_toast)


func set_darkness(value: float, seconds := 0.5) -> void:
	_target = clampf(value, 0.0, 1.0)
	if seconds <= 0.0:
		darkness = _target
	else:
		_speed = 1.0 / seconds


func _process(delta: float) -> void:
	darkness = move_toward(darkness, _target, _speed * delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.visible = _toast_time > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path != MENU:
				get_viewport().set_input_as_handled()
				manual = false
				set_darkness(0.0, 0.0)
				get_tree().paused = false
				Engine.time_scale = 1.0
				get_tree().change_scene_to_file(MENU)
		KEY_BRACKETRIGHT:
			_nudge(0.1)
		KEY_BRACKETLEFT:
			_nudge(-0.1)


func _nudge(amount: float) -> void:
	manual = true
	set_darkness(snappedf(_target + amount, 0.1), 0.15)
	_toast.text = "Darkness %.1f   ( [ lighter   ] darker )" % _target
	_toast.visible = true
	_toast_time = 2.0
