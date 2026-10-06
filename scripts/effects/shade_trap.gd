extends CanvasLayer
## Shade's trap (end of Shade's City): walking through the gate looks like
## the way out, then the light curdles: the screen glitches, ink floods down
## over everything and Shade speaks, then on to `next_scene` (the Ink Cave);
## with no next scene, "TO BE CONTINUED..." and the main menu.
##
##   ShadeTrap.start(get_tree(), player, "res://scenes/levels/ink_cave.tscn")

const ScenePrefetch = preload("res://scripts/core/scene_prefetch.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const MENU := "res://scenes/ui/main_menu.tscn"
const LINE := "DID YOU REALLY THINK I'D LET YOU LEAVE?"
const CaptionStyle = preload("res://scripts/ui/caption_style.gd")

var next_scene := ""
var _t := 0.0
var _view: Control


static func start(tree: SceneTree, player: Node, next: String) -> void:
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	var t := CanvasLayer.new()
	t.set_script(load("res://scripts/effects/shade_trap.gd"))
	t.next_scene = next
	tree.current_scene.add_child(t)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	ScenePrefetch.start(next_scene if next_scene != "" else MENU)  # read while the ink floods
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_paint)
	get_tree().create_timer(0.8).timeout.connect(func(): Sfx.play("ink_splat", 6.0, 0.55))
	get_tree().create_timer(2.1).timeout.connect(func(): Sfx.play("boss_intro", 0.0, 0.8))
	add_child(_view)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and _t > 0.8 and _t < 1.8:
		cam.add_trauma(0.08)
	var done := 8.5 if next_scene == "" else 5.6  # with a next scene: no "to be continued"
	if _t > done or (next_scene == "" and _t > 6.0 and Input.is_anything_pressed()):
		set_process(false)
		ScenePrefetch.change(get_tree(), next_scene if next_scene != "" else MENU)
	_view.queue_redraw()


func _paint() -> void:
	var s := _view.size
	# 1. the light swells: it looks like the way out
	var glow := clampf(_t / 0.8, 0.0, 1.0)
	if _t < 1.2:
		_view.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.95, 0.78, glow * 0.85 * (1.0 - clampf((_t - 0.8) / 0.4, 0.0, 1.0))))
	# 2. it glitches and ink floods down over everything
	if _t > 0.7:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 20.0)
		if _t < 1.8:
			for k in 10:
				var y := rng.randf() * s.y
				var h := rng.randf_range(6, 30)
				var off := rng.randf_range(-40, 40)
				_view.draw_rect(Rect2(off, y, s.x, h), Color(0.1, 0.85, 0.95, 0.35))
				_view.draw_rect(Rect2(-off, y + 3, s.x, h), Color(0.95, 0.2, 0.6, 0.35))
		var flood := clampf((_t - 0.8) / 1.0, 0.0, 1.0)
		var front := flood * (s.y + 160.0)
		var ink := Color(0.03, 0.02, 0.05)
		_view.draw_rect(Rect2(0, 0, s.x, maxf(front - 160.0, 0.0)), ink)
		for i in 33:
			var x := i * s.x / 32.0
			var drip := 40.0 + 60.0 * absf(sin(i * 2.3)) + 20.0 * sin(_t * 3.0 + i)
			_view.draw_rect(Rect2(x - 22, front - 162.0, 44, drip), ink)
			_view.draw_circle(Vector2(x, front - 162.0 + drip), 22.0, ink)
	# 3. Shade speaks
	if _t > 2.1:
		var shown := clampi(int((_t - 2.1) * 26.0), 0, LINE.length())
		var text := LINE.substr(0, shown)
		var w := FONT.get_string_size(LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var box := Rect2(s.x * 0.5 - w * 0.5 - 30, s.y * 0.38 - 40, w + 60, 80)
		CaptionStyle.panel(_view, box, "shade")  # Shade's red caption panel
		_view.draw_string(FONT, box.position + Vector2(30, 54), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, CaptionStyle.text_color("shade"))
	# 4. to be continued (only when there's nowhere to go yet)
	if _t > 5.0 and next_scene == "":
		var a := clampf((_t - 5.0) / 0.6, 0.0, 1.0)
		var cap := "TO BE CONTINUED..."
		var cw := FONT.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var r := Rect2(s.x - cw - 90, s.y - 130, cw + 40, 56)
		_view.draw_rect(r.grow(3), Color(0.05, 0.03, 0.1, a))
		_view.draw_rect(r, Color(1.0, 0.9, 0.45, a))
		_view.draw_string(FONT, r.position + Vector2(20, 40), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.05, 0.03, 0.1, a))
