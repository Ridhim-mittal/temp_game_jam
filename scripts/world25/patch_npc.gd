@tool
extends Node3D
## Patch (design doc, characters): a scruffy paper dog cut from draft 2 for
## being "too cute for the tone". In the Spine he is a guide: he sits by a
## crooked signpost on a heap of thrown-away pages and, when Vesper talks to
## him (Interact), gives a hint or a short line of lore, one per press, in
## his own caption box (story_ui.gd "patch"). Drawn in 2D like the old
## billboard Vesper (patch_art.gd in a SubViewport on a camera-facing sprite).

const Toon = preload("res://scripts/clearing/toon.gd")
const PatchArt = preload("res://scripts/world25/patch_art.gd")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const Interactable = preload("res://scripts/world25/interactable.gd")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")

const VIEW := 200
## What Patch says, in order; the first press after the last line starts
## over. A list per visit would be nice; the Spine is small.
const LINES := [
	"Woof. Er. Hello. Patch. Cut from draft two for being too cute for the tone. You'd be the hero, then.",
	"This is the Spine: the fold between the pages. Everything the Writer throws away slides down here.",
	"That lamp up there used to keep you safe. Not any more. When the light finds you, it burns. Keep moving.",
	"Shadows hide you. Stand behind something solid and the lamp loses you.",
	"Monsters hate the lamp too. Lead them under it and let it do the work for you.",
	"Your Ember is the only warm light left down here. Every hit feeds it. Hold F to turn it into ink.",
	"The cave in the north wall goes down into the Inkwood. Dead sketches. Graves of the ones that got cut.",
	"Past the Inkwood the ink spilled and drowned the page. Then the Torn Wastes. I never went further.",
	"Nobody comes back from the Rubbing Room. That's where the Eraser works.",
	"The shrine up the stairs teaches you tricks, if you've cleared enough rooms to pay in ink.",
]

var _line := 0


func _ready() -> void:
	var root := Toon.fresh_root(self)
	_build_spot(root)
	# Patch himself
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(VIEW, VIEW)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_ALWAYS  # keep drawing while paused
	root.add_child(vp)
	var group := CanvasGroup.new()
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	mat.set_shader_parameter("pop_color", Color(1, 0.98, 0.9))
	mat.set_shader_parameter("ink_width", 2.0)
	mat.set_shader_parameter("pop_width", 5.0)
	group.material = mat
	group.fit_margin = 12.0
	group.position = Vector2(VIEW * 0.5, VIEW - 30)
	group.scale = Vector2(2, 2)
	vp.add_child(group)
	var art := Node2D.new()
	art.set_script(PatchArt)
	group.add_child(art)
	var sprite := Sprite3D.new()
	sprite.texture = vp.get_texture()
	sprite.pixel_size = 0.0145
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset = Vector2(0, VIEW * 0.5 - 30)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sprite)
	if Engine.is_editor_hint():
		return
	Toon.collider(root, Toon.cylinder_shape(0.7, 2.0), Vector3(-1.2, 1.0, -0.5))
	var talk := Node3D.new()
	talk.set_script(Interactable)
	talk.prompt = "TALK"
	talk.radius = 2.8
	talk.prompt_height = 1.9
	talk.used.connect(_talk)
	root.add_child(talk)


## A crooked signpost pointing three ways, a heap of torn pages to sit on
## and a stub of candle in a jar: no stall, nothing for sale.
func _build_spot(root: Node3D) -> void:
	var wood := Color(0.2, 0.17, 0.16)
	var post := Node3D.new()
	post.position = Vector3(-1.2, 0, -0.5)
	post.rotation_degrees = Vector3(0, 0, 6)
	root.add_child(post)
	Toon.part(post, Toon.box(Vector3(0.14, 2.5, 0.14)), wood, Vector3(0, 1.25, 0), Vector3.ZERO, {"bark": 0.6, "line": wood.darkened(0.5)})
	var boards := [[1.95, 18.0, 1], [1.55, -24.0, -1], [1.15, 64.0, 1]]
	for b in boards:
		var arm := Node3D.new()
		arm.position = Vector3(0, b[0], 0)
		arm.rotation_degrees = Vector3(0, b[1], (_jitter(b[0]) - 0.5) * 8.0)
		post.add_child(arm)
		Toon.part(arm, Toon.box(Vector3(0.95, 0.24, 0.05)), Color(0.62, 0.58, 0.5), Vector3(b[2] * 0.45, 0, 0), Vector3.ZERO,
			{"tile": 0.0, "outline": 0.03})
		Toon.part(arm, Toon.prism(Vector3(0.24, 0.2, 0.05)), Color(0.62, 0.58, 0.5), Vector3(b[2] * 1.02, 0, 0), Vector3(0, 0, -b[2] * 90.0),
			{"outline": 0.03})
		# an ink scrawl where the name used to be
		Toon.part(arm, Toon.box(Vector3(0.6, 0.035, 0.06)), Color(0.08, 0.06, 0.1), Vector3(b[2] * 0.45, 0.02, 0), Vector3(0, 0, 3), {"outline": 0.0})
	# pages heaped where he sits
	var page := Color(0.72, 0.69, 0.62)
	for i in 6:
		var a := i * 1.1
		var p := Toon.part(root, Toon.box(Vector3(0.55, 0.03, 0.42)), page.darkened(0.08 * (i % 3)),
			Vector3(cos(a) * 0.35 + 0.1, 0.03 + i * 0.025, sin(a) * 0.25 + 0.05), Vector3(i * 3.0 - 6.0, i * 47.0, (i % 2) * 6.0 - 3.0), {"outline": 0.02})
		p.scale = Vector3.ONE
	# a candle stub in a jar: dim, cold-white (the only light he trusts)
	var jar := Vector3(0.9, 0, 0.35)
	Toon.part(root, Toon.cylinder(0.13, 0.15, 0.26, 10), Color(0.32, 0.36, 0.38), jar + Vector3(0, 0.13, 0), Vector3.ZERO, {"outline": 0.025})
	Toon.billboard(root, FLAME_SHADER, Vector2(0.22, 0.32), jar + Vector3(0, 0.38, 0),
		{"outer_color": Color(0.75, 0.8, 0.85), "core_color": Color(1, 1, 1)})
	if not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.light_color = Color(0.8, 0.85, 0.9)
		l.light_energy = 0.5
		l.omni_range = 2.2
		l.position = jar + Vector3(0, 0.5, 0)
		root.add_child(l)


func _jitter(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)


func _talk() -> void:
	var room := get_tree().current_scene
	var ui = room.get("ui") if room else null
	if ui == null or not ui.has_method("caption"):
		return
	if ui.busy() and _line > 0:
		return  # let him finish
	ui.caption(LINES[_line % LINES.size()], "patch")
	_line += 1
