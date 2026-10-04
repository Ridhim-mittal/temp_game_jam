@tool
extends Node3D
## Patch (design doc, characters): a scruffy paper dog cut from draft 2 for
## being "too cute for the tone". Runs the shop in the hub. Drawn in 2D like
## Vesper (patch_art.gd in a SubViewport on a camera-facing sprite), with a
## little stall of crates and a sign. Talk to him with Interact.

const Toon = preload("res://scripts/clearing/toon.gd")
const PatchArt = preload("res://scripts/world25/patch_art.gd")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const Interactable = preload("res://scripts/world25/interactable.gd")

const VIEW := 200


func _ready() -> void:
	var root := Toon.fresh_root(self)
	# the stall: crates, a little awning, a hand-painted sign
	var wood := Color(0.55, 0.38, 0.27)
	Toon.part(root, Toon.box(Vector3(0.8, 0.7, 0.8)), wood, Vector3(-1.2, 0.35, -0.4), Vector3(0, 12, 0), {"tile": 0.35, "line": wood.darkened(0.5)})
	Toon.part(root, Toon.box(Vector3(0.7, 0.6, 0.7)), wood.darkened(0.1), Vector3(-1.15, 1.0, -0.45), Vector3(0, -8, 0), {"tile": 0.35, "line": wood.darkened(0.5)})
	Toon.part(root, Toon.box(Vector3(0.8, 0.7, 0.8)), wood, Vector3(1.25, 0.35, -0.5), Vector3(0, -14, 0), {"tile": 0.35, "line": wood.darkened(0.5)})
	for x in [-1.6, 1.6]:
		Toon.part(root, Toon.box(Vector3(0.12, 2.4, 0.12)), wood.darkened(0.3), Vector3(x, 1.2, -0.9))
	var awning := Toon.part(root, Toon.box(Vector3(3.6, 0.12, 1.3)), Color(0.85, 0.25, 0.22), Vector3(0, 2.45, -0.5), Vector3(-18, 0, 0),
		{"tile": 0.6, "line": Color(0.95, 0.9, 0.85)})
	awning.scale = Vector3.ONE
	var sign := Label3D.new()
	sign.text = "PATCH'S\nPAPER GOODS"
	sign.font = load("res://assets/fonts/Bangers-Regular.ttf")
	sign.font_size = 64
	sign.outline_size = 14
	sign.modulate = Color(1.0, 0.9, 0.55)
	sign.outline_modulate = Color(0.06, 0.04, 0.09)
	sign.pixel_size = 0.006
	sign.position = Vector3(0, 2.95, -0.4)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(sign)
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
	Toon.collider(root, Toon.box_shape(Vector3(3.6, 2.0, 1.2)), Vector3(0, 1.0, -0.5))
	var talk := Node3D.new()
	talk.set_script(Interactable)
	talk.action = "shop"
	talk.prompt = "SHOP"
	talk.radius = 2.8
	talk.prompt_height = 1.9
	root.add_child(talk)
