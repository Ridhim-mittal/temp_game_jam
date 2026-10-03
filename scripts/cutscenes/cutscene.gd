extends Control
## Comic-page cutscene player for Vesper.
## Shows one page at a time; each key press reveals the next panel, then
## flips to the next page. Content lives in cutscene_data.gd.
##
##   Space / Enter / Z / X / J / left click : next panel (or finish the text)
##   Esc                                     : skip the whole cutscene

signal finished

const Data = preload("res://scripts/cutscenes/cutscene_data.gd")
const PanelScript = preload("res://scripts/cutscenes/cutscene_panel.gd")

const PAPER := {
	"cream": Color(0.93, 0.88, 0.78),
	"black": Color(0.04, 0.04, 0.06),
	"night": Color(0.07, 0.08, 0.13),
	"white": Color(0.98, 0.98, 0.96),
}

## Which entry of CUTSCENES in cutscene_data.gd to play.
@export var cutscene_id := "opening"
## Scene to load when the cutscene ends. Leave empty to just emit `finished`.
@export_file("*.tscn") var next_scene := ""
## Pause the rest of the game while the cutscene plays (for overlays).
@export var pause_game := true
@export var chars_per_second := 48.0

var _pages: Array = []
var _page := -1
var _next_panel := 0
var _panels: Array = []
var _bg := Color(0.93, 0.88, 0.78)
var _done := false
var _hint: Label
var _shake := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pause_game:
		get_tree().paused = true
	_pages = Data.CUTSCENES.get(cutscene_id, [])
	if _pages.is_empty():
		push_warning("Cutscene '%s' not found in cutscene_data.gd" % cutscene_id)
		_finish()
		return
	_hint = Label.new()
	_hint.text = "Space / click: next      Esc: skip"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
	_hint.position = Vector2(960, 690)
	_hint.z_index = 50
	add_child(_hint)
	_bg = PAPER.get(_pages[0].get("paper", "cream"), PAPER["cream"])
	_next_page()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 3.0, 0.0)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * _shake * _shake
	else:
		position = Vector2.ZERO


func _draw() -> void:
	# Oversized so screen shake never shows the game behind the page.
	draw_rect(Rect2(-100, -100, 1480, 920), _bg)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_finish()
			return
		go = key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_X, KEY_J]
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		advance()


## Finish the current text, reveal the next panel, flip the page, or end.
func advance() -> void:
	if _done:
		return
	if not _panels.is_empty() and _panels[-1].is_typing():
		_panels[-1].finish_typing()
		return
	var specs: Array = _pages[_page]["panels"]
	if _next_panel < specs.size():
		_show_panel(specs[_next_panel])
		_next_panel += 1
	elif _page + 1 < _pages.size():
		_next_page()
	else:
		_finish()


func _next_page() -> void:
	for p in _panels:
		p.queue_free()
	_panels.clear()
	_page += 1
	_next_panel = 0
	var target: Color = PAPER.get(_pages[_page].get("paper", "cream"), PAPER["cream"])
	create_tween().tween_method(_set_bg, _bg, target, 0.3)
	advance()


func _set_bg(c: Color) -> void:
	_bg = c
	queue_redraw()


func _show_panel(spec: Dictionary) -> void:
	var panel := Control.new()
	panel.set_script(PanelScript)
	add_child(panel)
	panel.setup(spec, chars_per_second)
	_panels.append(panel)
	var t := create_tween()
	match spec.get("enter", "pop"):
		"slam":
			panel.scale = Vector2(2.6, 2.6)
			panel.modulate.a = 0.0
			t.set_parallel()
			t.tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(panel, "modulate:a", 1.0, 0.08)
			t.chain().tween_callback(func(): _shake = 1.0)
		"fade":
			panel.modulate.a = 0.0
			t.tween_property(panel, "modulate:a", 1.0, 0.8)
		_:
			panel.scale = Vector2(0.88, 0.88)
			panel.modulate.a = 0.0
			t.set_parallel()
			t.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(panel, "modulate:a", 1.0, 0.15)


func _finish() -> void:
	if _done:
		return
	_done = true
	if pause_game:
		get_tree().paused = false
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	elif get_tree().current_scene != self:
		queue_free()
	elif _hint:
		_hint.text = "End of cutscene"
