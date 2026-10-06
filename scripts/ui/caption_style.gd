extends RefCounted
## Who is talking, at a glance: the comic's caption panels, one look for every
## story line in the game (narration.gd in the 2D levels, story_ui.gd in the
## Margins, beast_arena.gd, margins_fall.gd, shade_trap.gd, shade_finale.gd).
##   "narrator"  the comic's yellow caption box (the opening narration)
##   "vesper"    Vesper: the same yellow box with a "VESPER" tab
##   "shade"     Shade, the Writer: a blood-red box, pale text, a "SHADE" tab
##
##   CaptionStyle.panel(ci, box, "shade", alpha)
##   ci.draw_string(..., CaptionStyle.text_color("shade", alpha))

const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.1)
const YELLOW := Color(1.0, 0.9, 0.45)
const RED := Color(0.76, 0.08, 0.12)
const RED_TEXT := Color(1.0, 0.93, 0.88)


## Panel fill for a speaker.
static func fill(who: String) -> Color:
	return RED if who == "shade" else YELLOW


static func text_color(who: String, a := 1.0) -> Color:
	return Color(RED_TEXT if who == "shade" else INK, a)


## The box: drop shadow, ink border, fill, and the speaker's name tab on top.
static func panel(ci: CanvasItem, box: Rect2, who: String, a := 1.0) -> void:
	ci.draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(INK, 0.4 * a))
	ci.draw_rect(box.grow(3.0), Color(INK, a))
	ci.draw_rect(box, Color(fill(who), a))
	if who == "shade" or who == "vesper":
		var name := who.to_upper()
		var w := FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var tag := Rect2(box.position + Vector2(14, -24), Vector2(w + 20, 26))
		ci.draw_rect(tag.grow(2.0), Color(INK, a))
		ci.draw_rect(tag, Color(fill(who), a))
		ci.draw_string(FONT, tag.position + Vector2(10, 21), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text_color(who, a))
