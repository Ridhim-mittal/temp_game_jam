extends CanvasLayer
## THE DEDICATION (~30 s): the end of the finale, after Vesper asks Shade why.
## Shade answers: a memory of his brother, told as sepia comic panels.
##   0-4   the street: Shade's hand trembles over Vesper. "YOU WANT TO KNOW WHY?"
##   4-5   the frame tears open onto an old sepia page
##   5-10  two brothers at a desk at night; the little one holds up a hero in a
##         hat and red scarf: "DRAW ME AS THE HERO!"
##   10-14 the dedication page: VESPER. For my brother, the hero who never loses.
##   14-18 the empty chair, the red scarf on it, rain on the window
##   18-22 tears on the page, the hero's panels crossed out, the ink floods
##   22-30 back on the street: Vesper answers, the hand opens, the golden pen
##         falls at his feet. "...HE WOULD HAVE LIKED THAT."
## The brother is never named ("my brother"). Enter / Esc skips. `finished`
## fires at the end (or on the skip).
##
##   var cs := CsDedication.start(get_tree(), hand, vesper)
##   await cs.finished

signal finished

const CaptionStyle = preload("res://scripts/ui/caption_style.gd")
const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const HAND_FONT = preload("res://assets/fonts/Chewy-Regular.ttf")
const LENGTH := 30.0

# the memory's palette: old paper, brown ink; the scarf is the only colour
const PAPER := Color(0.93, 0.86, 0.71)
const PAPER_DARK := Color(0.82, 0.72, 0.55)
const SEPIA := Color(0.27, 0.18, 0.1)
const SEPIA_MID := Color(0.55, 0.42, 0.28)
const SEPIA_LIGHT := Color(0.74, 0.62, 0.45)
const SCARF := Color(0.82, 0.12, 0.12)
const GOLD := Color(0.95, 0.76, 0.32)
const INK := Color(0.05, 0.03, 0.1)

## Lines: [start, end, who, text]; "bubble" is the little brother's balloon.
const LINES := [
	[0.6, 4.0, "shade", "YOU WANT TO KNOW WHY?"],
	[6.0, 10.0, "bubble", "DRAW ME AS THE HERO!"],
	[6.6, 10.0, "shade", "MY BROTHER. IN OUR STORIES, HE NEVER LOST."],
	[14.6, 18.0, "shade", "BUT HE LOST. THE ONE FIGHT THAT MATTERED."],
	[18.6, 22.0, "shade", "AND IN EVERY PAGE, YOU KEPT WINNING. SO YOU HAD TO END TOO."],
	[23.0, 26.4, "vesper", "I'M NOT HIM. BUT I'M THE HERO HE ASKED YOU FOR."],
	[26.6, 30.0, "shade", "...HE WOULD HAVE LIKED THAT."],
]

var hand: Node2D
var vesper: Node2D
var _t := 0.0
var _view: Control
var _snap: Texture2D  # the street, torn open at 4 s
var _hand_nib := Vector2.ZERO  # the hand's nib when the scene began (world)
var _pen_from := Vector2.ZERO  # screen
var _pen_to := Vector2.ZERO
var _drops: Array = []  # tears {x, y, v}
var _sounds := {}
var _done := false


static func start(tree: SceneTree, the_hand: Node2D, the_vesper: Node2D) -> Node:
	var cs: CanvasLayer = load("res://scripts/cutscenes/cs_dedication.gd").new()
	cs.hand = the_hand
	cs.vesper = the_vesper
	tree.current_scene.add_child(cs)
	return cs


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_paint)
	add_child(_view)
	if hand:
		# the hand comes back out of the light and hangs over Vesper, trembling
		_hand_nib = (vesper.global_position if vesper else hand._nib) + Vector2(170, -190)
		hand.puppet = true
		hand.puppet_nib = _hand_nib + Vector2(520, -560)
		create_tween().tween_property(hand, "self_modulate:a", 1.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _process(delta: float) -> void:
	if _done:
		return
	var before := _t
	_t += delta
	_beats(before)
	# the hand trembles while he talks, and opens when he lets go
	if hand and is_instance_valid(hand):
		var shake := Vector2(sin(_t * 23.0), cos(_t * 19.0)) * (3.0 if _t < 26.5 else 0.0)
		var reach := _hand_nib.lerp(_hand_nib + Vector2(520, -560), pow(1.0 - clampf(_t / 1.4, 0.0, 1.0), 3.0))
		hand.puppet_nib = reach + shake + Vector2(0, sin(_t * 1.3) * 6.0)
		hand.puppet_flex = 0.35 if _t < 26.5 else 0.0
	# tears fall in the ink panel
	if _t > 18.4 and _t < 22.0 and randf() < delta * 5.0:
		_drops.append({"x": randf_range(380, 900), "y": -20.0, "v": 0.0, "land": randf_range(260, 520)})
	for d in _drops:
		if d.y < d.land:
			d.v += 1400.0 * delta
			d.y = minf(d.y + d.v * delta, d.land)
	if _t >= LENGTH:
		_finish()
	_view.queue_redraw()


## One-off moments on the timeline: the tear, the sounds, the pen.
func _beats(before: float) -> void:
	if _crossed(before, 3.9):
		_snap = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		_snd("rip", 0.0, 0.8)
	if _crossed(before, 14.0):
		_snd("rumble", -10.0, 1.6)  # thunder, far off
	if _crossed(before, 18.2):
		_snd("splut", -8.0, 0.7)
	if _crossed(before, 21.8):
		_snd("whoosh", -4.0, 0.7)
	if _crossed(before, 26.5):
		# the hand lets go: the pen falls to Vesper's feet
		if hand and is_instance_valid(hand):
			_pen_from = hand.get_global_transform_with_canvas() * (_hand_nib - hand.global_position)
			create_tween().tween_property(hand, "self_modulate:a", 0.0, 0.8)
		else:
			_pen_from = Vector2(900, 160)
		_pen_to = vesper.get_global_transform_with_canvas().origin + Vector2(40, 22) if vesper else Vector2(640, 600)
		_snd("whoosh", -6.0, 1.3)
	if _crossed(before, 27.6):
		_snd("clang", -6.0, 1.6)  # the pen rings on the street


func _crossed(before: float, at: float) -> bool:
	return before < at and _t >= at


func _snd(name: String, db: float, pitch: float) -> void:
	if is_inside_tree():
		SfxSynth.play(get_tree(), name, db, pitch)


func _finish() -> void:
	if _done:
		return
	_done = true
	if hand and is_instance_valid(hand):
		hand.self_modulate.a = 0.0
	finished.emit()
	queue_free()


# --- drawing ------------------------------------------------------------------

func _paint() -> void:
	var s := _view.size
	var t := _t
	# the street: a dark vignette while Shade talks
	if t < 4.0 or t > 22.0:
		var v := clampf(t / 1.0, 0.0, 1.0) if t < 4.0 else clampf(1.0 - (t - 22.0) / 1.2, 0.35, 1.0)
		_view.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.0, 0.04, 0.35 * v))
	# the memory: an old page behind the torn street
	if t >= 3.9 and t < 22.8:
		var page_a := 1.0 if t < 21.8 else 1.0 - (t - 21.8)
		_paint_page(s, page_a)
		if t < 10.0:
			_panel_brothers(s, _local(t, 4.6), page_a)
		elif t < 14.0:
			_panel_dedication(s, _local(t, 10.0), page_a)
		elif t < 18.0:
			_panel_chair(s, _local(t, 14.0), page_a)
		else:
			_panel_ink(s, _local(t, 18.0), page_a)
		# the way back: the page burns white and fades onto the street
		if t > 21.6:
			var w := clampf((t - 21.6) / 0.3, 0.0, 1.0) * (1.0 - clampf((t - 22.0) / 0.8, 0.0, 1.0))
			_view.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.97, 0.88, w))
	# the tear: the street's frame rips down the middle and parts
	if _snap and t >= 3.9 and t < 5.2:
		_paint_tear(s, clampf((t - 3.9) / 1.2, 0.0, 1.0))
	# the falling pen and the light where it lands
	if t >= 26.5:
		_paint_pen(clampf((t - 26.5) / 1.1, 0.0, 1.0), t - 26.5)
	_paint_lines(s)


func _local(t: float, from: float) -> float:
	return t - from


func _paint_page(s: Vector2, a: float) -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, s), Color(PAPER.darkened(0.35), a))
	# halftone dots of an old print, foxing at the edges
	var y := 8.0
	while y < s.y:
		var x := fmod(y, 16.0)
		while x < s.x:
			_view.draw_circle(Vector2(x, y), 1.4, Color(SEPIA_MID, 0.18 * a))
			x += 16.0
		y += 14.0


## The panel frame: inks in (pencil -> ink) and settles.
func _frame(s: Vector2, lt: float, a: float) -> Rect2:
	var k := clampf(lt / 0.5, 0.0, 1.0)
	var r := Rect2(Vector2(110, 70), Vector2(s.x - 220, s.y - 140))
	var grow := (1.0 - k) * 18.0
	r = r.grow(grow)
	_view.draw_rect(Rect2(r.position + Vector2(10, 10), r.size), Color(0, 0, 0, 0.35 * a * k))
	_view.draw_rect(r, Color(PAPER, a * k))
	_view.draw_rect(r, Color(SEPIA, a * k), false, 6.0)
	return r


func _ink(lt: float, a: float, delay := 0.3) -> Color:
	# drawn in pencil first, then inked
	var k := clampf((lt - delay) / 0.6, 0.0, 1.0)
	return Color(SEPIA_LIGHT.lerp(SEPIA, k), a * clampf((lt - delay * 0.5) / 0.3, 0.0, 1.0))


func _panel_brothers(s: Vector2, lt: float, a: float) -> void:
	var r := _frame(s, lt, a)
	var o := r.position
	var ink := _ink(lt, a)
	var fill := Color(SEPIA_LIGHT, ink.a * 0.55)
	var w := r.size.x
	var h := r.size.y
	var floor_y := o.y + h * 0.82
	# the room: window with the moon, the floor
	_view.draw_line(Vector2(o.x, floor_y), Vector2(o.x + w, floor_y), ink, 3.0)
	var win := Rect2(o + Vector2(w * 0.72, h * 0.1), Vector2(w * 0.2, h * 0.32))
	_view.draw_rect(win, Color(SEPIA_MID, ink.a * 0.35))
	_view.draw_rect(win, ink, false, 4.0)
	_view.draw_line(win.position + Vector2(win.size.x * 0.5, 0), win.position + Vector2(win.size.x * 0.5, win.size.y), ink, 3.0)
	_view.draw_circle(win.position + Vector2(win.size.x * 0.72, win.size.y * 0.3), 18.0, Color(PAPER, ink.a))
	# their heroes pinned up on the wall, page after page
	for k in 3:
		var pin := Rect2(o + Vector2(w * (0.28 + k * 0.09), h * 0.18 + (k % 2) * 14.0), Vector2(64, 52))
		_view.draw_rect(pin, Color(1.0, 0.97, 0.88, ink.a))
		_view.draw_rect(pin, ink, false, 2.0)
		_hero(pin.get_center() + Vector2(-2, -8), 0.6, ink)
		_view.draw_circle(pin.position + Vector2(32, 4), 3.5, Color(SCARF, ink.a))
	# the desk and its lamp, a cone of warm light
	var desk_y := o.y + h * 0.56
	var desk := Rect2(Vector2(o.x + w * 0.16, desk_y), Vector2(w * 0.5, 16))
	var lamp := Vector2(o.x + w * 0.22, desk_y - 110)
	_view.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-10, 8), lamp + Vector2(26, 8),
		Vector2(desk.position.x + desk.size.x * 0.75, desk_y), Vector2(desk.position.x + 20, desk_y)]), Color(1.0, 0.93, 0.7, 0.35 * ink.a))
	_view.draw_line(Vector2(lamp.x - 20, desk_y), lamp + Vector2(-10, 60), ink, 4.0)
	_view.draw_line(lamp + Vector2(-10, 60), lamp, ink, 4.0)
	_view.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-16, 10), lamp + Vector2(-4, -16), lamp + Vector2(30, -4), lamp + Vector2(30, 10)]), ink)
	_view.draw_rect(desk, fill)
	_view.draw_rect(desk, ink, false, 3.0)
	for lx in [desk.position.x + 14, desk.end.x - 14]:
		_view.draw_line(Vector2(lx, desk_y + 16), Vector2(lx, floor_y), ink, 4.0)
	# the older brother, hunched over his page, drawing
	var head := Vector2(o.x + w * 0.36, desk_y - 78)
	_view.draw_colored_polygon(_ell(head + Vector2(6, 62), 44, 52), fill)
	_view.draw_polyline(_ell(head + Vector2(6, 62), 44, 52) + PackedVector2Array([head + Vector2(50, 62)]), ink, 3.0)
	_view.draw_circle(head, 30.0, Color(PAPER, ink.a))
	_view.draw_arc(head, 30.0, 0, TAU, 24, ink, 3.0)
	for k in 5:  # messy hair
		var ang := -PI * 0.9 + k * 0.35
		_view.draw_line(head + Vector2.from_angle(ang) * 26, head + Vector2.from_angle(ang) * 40, ink, 3.0)
	var pen_hand := Vector2(o.x + w * 0.44, desk_y - 6)
	var scratch := sin(lt * 18.0) * 4.0
	_view.draw_line(head + Vector2(20, 40), pen_hand + Vector2(scratch, 0), ink, 5.0)
	_view.draw_line(pen_hand + Vector2(scratch, 0), pen_hand + Vector2(scratch + 10, -22), ink, 3.0)
	_view.draw_rect(Rect2(Vector2(o.x + w * 0.38, desk_y - 4), Vector2(70, 4)), Color(PAPER, ink.a))
	# the little brother on a chair, holding up his hero
	var chair_x := o.x + w * 0.58
	_view.draw_line(Vector2(chair_x, desk_y + 30), Vector2(chair_x + 70, desk_y + 30), ink, 5.0)
	_view.draw_line(Vector2(chair_x + 6, desk_y + 30), Vector2(chair_x + 6, floor_y), ink, 4.0)
	_view.draw_line(Vector2(chair_x + 64, desk_y + 30), Vector2(chair_x + 64, floor_y), ink, 4.0)
	var hop := absf(sin(lt * 5.0)) * 6.0  # bouncing, excited
	var kid := Vector2(chair_x + 35, desk_y - 40 - hop)
	_view.draw_colored_polygon(_ell(kid + Vector2(0, 38), 26, 36), fill)
	_view.draw_polyline(_ell(kid + Vector2(0, 38), 26, 36), ink, 3.0)
	_view.draw_line(kid + Vector2(-10, 70), Vector2(kid.x - 12, desk_y + 30), ink, 4.0)
	_view.draw_line(kid + Vector2(10, 70), Vector2(kid.x + 12, desk_y + 30), ink, 4.0)
	var khead := kid + Vector2(0, -10)
	_view.draw_circle(khead, 22.0, Color(PAPER, ink.a))
	_view.draw_arc(khead, 22.0, 0, TAU, 20, ink, 3.0)
	_view.draw_arc(khead + Vector2(4, 4), 9.0, 0.3, PI - 0.3, 8, ink, 2.5)  # a big grin
	# his drawing, held up high: a hero in a wide hat and a red scarf
	var paper := Rect2(kid + Vector2(-58, -150), Vector2(116, 92))
	_view.draw_line(kid + Vector2(-16, 20), paper.position + Vector2(20, paper.size.y), ink, 4.0)
	_view.draw_line(kid + Vector2(16, 20), paper.position + Vector2(96, paper.size.y), ink, 4.0)
	_view.draw_rect(paper, Color(1.0, 0.98, 0.92, ink.a))
	_view.draw_rect(paper, ink, false, 3.0)
	_hero(paper.get_center() + Vector2(0, 10), 0.9, ink)


## A tiny hero in a kid's drawing: wide hat, round face, red scarf, a sword.
func _hero(at: Vector2, k: float, ink: Color) -> void:
	_view.draw_line(at + Vector2(-26, 0) * k, at + Vector2(26, 0) * k, ink, 4.0)  # hat brim
	_view.draw_rect(Rect2(at + Vector2(-13, -16) * k, Vector2(26, 16) * k), ink)
	_view.draw_circle(at + Vector2(0, 14) * k, 12.0 * k, Color(1, 1, 1, ink.a))
	_view.draw_arc(at + Vector2(0, 14) * k, 12.0 * k, 0, TAU, 16, ink, 2.0)
	_view.draw_circle(at + Vector2(-4, 12) * k, 1.8, ink)
	_view.draw_circle(at + Vector2(4, 12) * k, 1.8, ink)
	_view.draw_line(at + Vector2(-12, 28) * k, at + Vector2(14, 28) * k, Color(SCARF, ink.a), 6.0 * k)
	_view.draw_line(at + Vector2(10, 28) * k, at + Vector2(24, 40) * k, Color(SCARF, ink.a), 5.0 * k)
	_view.draw_line(at + Vector2(16, 18) * k, at + Vector2(34, -6) * k, ink, 3.0)


func _panel_dedication(s: Vector2, lt: float, a: float) -> void:
	var r := _frame(s, lt, a)
	var ink := _ink(lt, a, 0.2)
	# a single page, close up, a little crooked on the desk
	var c := r.get_center() + Vector2(0, 6)
	var xf := Transform2D(-0.04 + sin(lt * 0.6) * 0.004, c)
	_view.draw_set_transform_matrix(xf)
	var page := Rect2(Vector2(-250, -215), Vector2(500, 430))
	_view.draw_rect(Rect2(page.position + Vector2(10, 12), page.size), Color(0, 0, 0, 0.25 * ink.a))
	_view.draw_rect(page, Color(1.0, 0.97, 0.88, ink.a))
	_view.draw_rect(page, ink, false, 3.0)
	_view.draw_arc(Vector2(150, 120), 46.0, 0.4, 5.6, 24, Color(SEPIA_MID, 0.4 * ink.a), 5.0)  # a cup ring
	# the title, brushed in, letter by letter
	var title := "VESPER"
	var shown := clampi(int((lt - 0.4) * 9.0), 0, title.length())
	var tw := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
	_view.draw_string(FONT, Vector2(-tw * 0.5, -100), title.substr(0, shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 92, ink)
	_hero(Vector2(0, -20), 1.3, ink)
	# the dedication, in his own handwriting, writing itself
	var lines := ["for my brother,", "the hero who never loses."]
	var chars := int(clampf((lt - 1.2) * 18.0, 0.0, 999.0))
	var y := 90.0
	for line in lines:
		var part: String = line.substr(0, clampi(chars, 0, line.length()))
		chars -= line.length()
		var lw := HAND_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		_view.draw_string(HAND_FONT, Vector2(-lw * 0.5, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, ink)
		y += 50.0
	if chars > 0:
		_view.draw_line(Vector2(-90, y - 18), Vector2(90, y - 24), Color(SCARF, ink.a), 3.0)  # underlined in red
	_view.draw_set_transform(Vector2.ZERO)


func _panel_chair(s: Vector2, lt: float, a: float) -> void:
	var r := _frame(s, lt, a)
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	var ink := _ink(lt, a, 0.15)
	# the same room, cold now: night blue over the sepia, the lamp guttering
	_view.draw_rect(r.grow(-3), Color(0.12, 0.14, 0.24, 0.45 * ink.a))
	var floor_y := o.y + h * 0.82
	_view.draw_line(Vector2(o.x, floor_y), Vector2(o.x + w, floor_y), ink, 3.0)
	var win := Rect2(o + Vector2(w * 0.72, h * 0.1), Vector2(w * 0.2, h * 0.32))
	_view.draw_rect(win, Color(0.2, 0.22, 0.32, ink.a))
	_view.draw_rect(win, ink, false, 4.0)
	_view.draw_line(win.position + Vector2(win.size.x * 0.5, 0), win.position + Vector2(win.size.x * 0.5, win.size.y), ink, 3.0)
	for k in 9:  # rain running down the glass
		var rx := win.position.x + 8 + fmod(k * 37.0, win.size.x - 16)
		var ry := win.position.y + fmod(lt * 260.0 + k * 53.0, win.size.y)
		_view.draw_line(Vector2(rx, ry), Vector2(rx - 3, minf(ry + 22, win.end.y)), Color(0.75, 0.82, 0.95, 0.7 * ink.a), 2.0)
	var desk_y := o.y + h * 0.56
	var desk := Rect2(Vector2(o.x + w * 0.16, desk_y), Vector2(w * 0.5, 16))
	var lamp := Vector2(o.x + w * 0.22, desk_y - 110)
	var flicker := 0.15 + 0.2 * absf(sin(lt * 31.0) * sin(lt * 7.0))
	_view.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-10, 8), lamp + Vector2(26, 8),
		Vector2(desk.position.x + desk.size.x * 0.75, desk_y), Vector2(desk.position.x + 20, desk_y)]), Color(1.0, 0.93, 0.7, flicker * ink.a))
	_view.draw_line(Vector2(lamp.x - 20, desk_y), lamp + Vector2(-10, 60), ink, 4.0)
	_view.draw_line(lamp + Vector2(-10, 60), lamp, ink, 4.0)
	_view.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-16, 10), lamp + Vector2(-4, -16), lamp + Vector2(30, -4), lamp + Vector2(30, 10)]), ink)
	_view.draw_rect(desk, Color(SEPIA_LIGHT, 0.5 * ink.a))
	_view.draw_rect(desk, ink, false, 3.0)
	for lx in [desk.position.x + 14, desk.end.x - 14]:
		_view.draw_line(Vector2(lx, desk_y + 16), Vector2(lx, floor_y), ink, 4.0)
	# the wall is bare now: only the pins are left
	for k in 3:
		_view.draw_circle(o + Vector2(w * (0.28 + k * 0.09) + 32, h * 0.18 + (k % 2) * 14.0 + 4), 3.5, Color(SCARF, ink.a))
	# his drawing left on the desk, the hero face down
	_view.draw_rect(Rect2(Vector2(o.x + w * 0.4, desk_y - 4), Vector2(90, 4)), Color(PAPER, ink.a))
	# the empty chair, the red scarf over its back
	var chair_x := o.x + w * 0.58
	_view.draw_line(Vector2(chair_x, desk_y + 30), Vector2(chair_x + 70, desk_y + 30), ink, 5.0)
	_view.draw_line(Vector2(chair_x + 6, desk_y + 30), Vector2(chair_x + 6, floor_y), ink, 4.0)
	_view.draw_line(Vector2(chair_x + 64, desk_y + 30), Vector2(chair_x + 64, floor_y), ink, 4.0)
	_view.draw_line(Vector2(chair_x + 64, desk_y + 30), Vector2(chair_x + 64, desk_y - 70), ink, 5.0)
	var sway := sin(lt * 1.4) * 2.0
	var scarf := PackedVector2Array([Vector2(chair_x + 56, desk_y - 64), Vector2(chair_x + 74, desk_y - 66),
		Vector2(chair_x + 78 + sway, desk_y + 4), Vector2(chair_x + 66 + sway, desk_y + 10), Vector2(chair_x + 60, desk_y - 30)])
	_view.draw_colored_polygon(scarf, Color(SCARF, ink.a))
	_view.draw_polyline(scarf + PackedVector2Array([scarf[0]]), Color(SEPIA, ink.a), 2.0)


func _panel_ink(s: Vector2, lt: float, a: float) -> void:
	var r := _frame(s, lt, a)
	var ink := _ink(lt, a, 0.1)
	# the pages of the hero's story, panel after panel
	var cols := 3
	var rows := 2
	var cell := Vector2((r.size.x - 120) / cols, (r.size.y - 140) / rows)
	for i in cols * rows:
		var p := r.position + Vector2(60, 90) + Vector2(i % cols * cell.x, i / cols * cell.y)
		var box := Rect2(p + Vector2(10, 10), cell - Vector2(20, 20))
		_view.draw_rect(box, Color(1.0, 0.97, 0.88, ink.a))
		_view.draw_rect(box, ink, false, 3.0)
		_hero(box.get_center() + Vector2(0, -6), 1.0, ink)
		# crossed out, one by one, in red
		var x_at := 0.4 + i * 0.35
		var k := clampf((lt - x_at) / 0.25, 0.0, 1.0)
		if k > 0.0:
			var red := Color(SCARF, ink.a)
			_view.draw_line(box.position + Vector2(12, 12), (box.position + Vector2(12, 12)).lerp(box.end - Vector2(12, 12), k), red, 7.0)
			if k >= 1.0:
				var k2 := clampf((lt - x_at - 0.2) / 0.2, 0.0, 1.0)
				var tr := Vector2(box.end.x - 12, box.position.y + 12)
				var bl := Vector2(box.position.x + 12, box.end.y - 12)
				_view.draw_line(tr, tr.lerp(bl, k2), red, 7.0)
	# tears hitting the page, each one blooming into a dark blot
	for d in _drops:
		var at := Vector2(d.x, d.y)
		if d.y < d.land:
			_view.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(5, 0), at + Vector2(0, 5),
				at + Vector2(-5, 0)]), Color(0.7, 0.82, 0.95, 0.8 * a))
		else:
			_view.draw_circle(at, 14.0, Color(INK, 0.55 * a))
	# the ink floods up from the bottom of the panel and swallows it all
	var flood := clampf((lt - 1.8) / 2.0, 0.0, 1.0)
	if flood > 0.0:
		var inner := r.grow(-3)
		var top := inner.end.y - inner.size.y * 1.08 * flood * flood * (3.0 - 2.0 * flood)
		var pool := PackedVector2Array([inner.end, Vector2(inner.position.x, inner.end.y)])
		for k in 33:
			var x := inner.position.x + inner.size.x * k / 32.0
			var wave := sin(x * 0.03 + lt * 5.0) * 9.0 + sin(x * 0.011 - lt * 3.0) * 14.0
			pool.append(Vector2(x, clampf(top + wave, inner.position.y, inner.end.y)))
		_view.draw_colored_polygon(pool, Color(INK, 0.95 * a))
		# drips running down off the ink's edge
		for k in 7:
			var x := inner.position.x + inner.size.x * (k + 0.5) / 7.0
			var y := clampf(top - 10.0, inner.position.y, inner.end.y)
			_view.draw_circle(Vector2(x, y - fmod(lt * 40.0 + k * 13.0, 30.0)), 5.0, Color(INK, 0.9 * a * (1.0 - flood)))


func _paint_tear(s: Vector2, k: float) -> void:
	var part := pow(k, 1.8) * s.x * 0.6
	var mid := s.x * 0.5
	var jag := PackedVector2Array()
	for i in 13:
		jag.append(Vector2(mid + (18.0 if i % 2 == 0 else -18.0) * (1.0 if i % 3 else 0.5), s.y * i / 12.0))
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var edge := 0.0 if side < 0.0 else s.x
		pts.append(Vector2(edge, 0))
		for p in jag:
			pts.append(p)
		pts.append(Vector2(edge, s.y))
		if side > 0.0:
			pts.reverse()
		for p in pts:
			uvs.append(p / s)
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + Vector2(side * part, 0))
		var cols := PackedColorArray()
		cols.resize(moved.size())
		cols.fill(Color(1, 1, 1, 1.0 - k * 0.3))
		_view.draw_polygon(moved, cols, uvs, _snap)
		var lip := PackedVector2Array()
		for p in jag:
			lip.append(p + Vector2(side * part, 0))
		_view.draw_polyline(lip, Color(1.0, 0.97, 0.88), 5.0)


func _paint_pen(k: float, since: float) -> void:
	# falls, tumbling, then lies at his feet in a pool of light
	var e := k * k
	var at := _pen_from.lerp(_pen_to, e)
	var spin := k * 7.0 + 0.6
	if k >= 1.0:
		spin = PI * 0.5 + 0.12
		var glow := clampf((since - 1.1) / 1.2, 0.0, 1.0)
		_view.draw_set_transform(_pen_to, 0.0, Vector2(1.0, 0.3))
		_view.draw_circle(Vector2.ZERO, 40.0 + 120.0 * glow, Color(1.0, 0.95, 0.75, 0.3 * glow))
		_view.draw_circle(Vector2.ZERO, 20.0 + 50.0 * glow, Color(1.0, 0.98, 0.88, 0.45 * glow))
		_view.draw_set_transform(Vector2.ZERO)
	_view.draw_set_transform(at, spin)
	var body := PackedVector2Array([Vector2(-6, -60), Vector2(6, -60), Vector2(7, 10), Vector2(-7, 10)])
	_view.draw_colored_polygon(body, Color(0.55, 0.38, 0.2))
	_view.draw_polyline(body + PackedVector2Array([body[0]]), INK, 2.5)
	_view.draw_line(Vector2(-6, -48), Vector2(6, -48), GOLD, 3.0)
	_view.draw_colored_polygon(PackedVector2Array([Vector2(-7, 10), Vector2(7, 10), Vector2(0, 34)]), GOLD)
	_view.draw_polyline(PackedVector2Array([Vector2(-7, 10), Vector2(0, 34), Vector2(7, 10)]), INK, 2.0)
	_view.draw_set_transform(Vector2.ZERO)


func _paint_lines(s: Vector2) -> void:
	for l in LINES:
		var from: float = l[0]
		var to: float = l[1]
		if _t < from or _t > to:
			continue
		var who: String = l[2]
		var text: String = l[3]
		var shown := text.substr(0, int((_t - from) * 34.0))
		var a := clampf((to - _t) / 0.3, 0.0, 1.0) * clampf((_t - from) / 0.15, 0.0, 1.0)
		if who == "bubble":
			_bubble(Vector2(s.x * 0.66, 150), text, shown, a)
			continue
		var size := 28
		var w := minf(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, s.x - 300)
		# in the memory the caption sits in the panel's corner; on the street, up top
		var box := Rect2(Vector2(140, 100) if _t > 4.0 and _t < 22.0 else Vector2(60, 230), Vector2(w + 40, 52))
		CaptionStyle.panel(_view, box, who, a)
		_view.draw_string(FONT, box.position + Vector2(20, 37), shown, HORIZONTAL_ALIGNMENT_LEFT, w + 4, size,
			CaptionStyle.text_color(who, a))


## The little brother's speech balloon.
func _bubble(at: Vector2, text: String, shown: String, a: float) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var box := Rect2(at - Vector2(w * 0.5 + 24, 30), Vector2(w + 48, 56))
	var tail := PackedVector2Array([Vector2(at.x - 30, box.end.y - 4), Vector2(at.x - 6, box.end.y - 4), Vector2(at.x - 60, box.end.y + 46)])
	_view.draw_colored_polygon(_ell(box.get_center(), box.size.x * 0.56 + 3, box.size.y * 0.62 + 3), Color(SEPIA, a))
	_view.draw_colored_polygon(tail, Color(SEPIA, a))
	_view.draw_colored_polygon(_ell(box.get_center(), box.size.x * 0.56, box.size.y * 0.62), Color(1.0, 0.98, 0.92, a))
	_view.draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(3, -2), tail[1] + Vector2(-3, -2), tail[2] + Vector2(4, -8)]), Color(1.0, 0.98, 0.92, a))
	_view.draw_string(FONT, box.position + Vector2(24, 39), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(SEPIA, a))


static func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		out.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return out
