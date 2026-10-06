extends Control
## Root of scenes/cutscenes/cs_last_page.tscn: THE ENDING, as a chapter on the
## main menu. The ending (cs_last_page.gd) climbs out of the finale's last
## frame, so this stands one up first: the street in Shade's City (its
## painting, the dark of the street), Vesper on it, his question to Shade for a
## moment. Then it takes that frame and hands over; the ending goes back to
## the main menu when it is done.

const CsLastPage = preload("res://scripts/cutscenes/cs_last_page.gd")
const CaptionStyle = preload("res://scripts/ui/caption_style.gd")
const PlayerVisual = preload("res://scripts/player/player_visual.gd")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const CITY = preload("res://assets/backgrounds/shades_city.webp")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const QUESTION := "WHY, SHADE? WHY DID YOU WANT ME DEAD?"
## Seconds his question stays up before the ending begins.
const HOLD := 3.2

var _t := 0.0
var _asked := true
var _begun := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Vesper on the street, in his sticker outline (as in the levels)
	var group := CanvasGroup.new()
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	group.material = mat
	group.fit_margin = 16.0
	group.position = Vector2(560, 618)
	group.scale = Vector2(2.0, 2.0)
	add_child(group)
	var art := Node2D.new()
	art.set_script(PlayerVisual)
	group.add_child(art)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= HOLD and not _begun:
		_begun = true
		_asked = false  # (his words are not part of the frame)
		queue_redraw()
		await get_tree().process_frame  # (two frames on: the one without his words has been drawn)
		await get_tree().process_frame
		CsLastPage.play(get_tree(), get_viewport().get_texture().get_image())


func _draw() -> void:
	draw_texture_rect(CITY, Rect2(0, 0, 1280, 620), false)
	draw_rect(Rect2(0, 0, 1280, 620), Color(0.1, 0.06, 0.2, 0.25))
	draw_rect(Rect2(0, 618, 1280, 102), Color(0.08, 0.06, 0.12))
	draw_line(Vector2(0, 618), Vector2(1280, 618), Color(0.95, 0.4, 0.6), 3.0)
	if _asked:
		var a := clampf(_t / 0.4, 0.0, 1.0)
		var w := FONT.get_string_size(QUESTION, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var box := Rect2(640 - w * 0.5 - 26, 80, w + 52, 62)
		CaptionStyle.panel(self, box, "vesper", a)
		draw_string(FONT, box.position + Vector2(26, 44), QUESTION.substr(0, int(_t * 30.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
			CaptionStyle.text_color("vesper", a))
