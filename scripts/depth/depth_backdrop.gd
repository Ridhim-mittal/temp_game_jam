extends Node2D
## Layered, atmospheric backdrop for a level (Hollow Knight-style depth):
##   sky gradient + fog light  ->  pale far layer  ->  mid layer  ->  darker
##   near layer  ->  [the level]  ->  screen-edge fringe, motes and vignette.
## The layers are drawn procedurally around the camera, so the backdrop works
## for levels of any size, including very tall ones.
##
## A level can stack several zones: `themes` lists them top to bottom and
## `zone_bottoms` gives the world y where each one ends. Colours blend across
## `blend` px at each border.

const Style = preload("res://scripts/depth/depth_style.gd")
const LayerScript = preload("res://scripts/depth/depth_layer.gd")
const OverlayScript = preload("res://scripts/depth/depth_overlay.gd")
const SkyShader = preload("res://shaders/depth_sky.gdshader")

## 0 = Cavern (teal), 1 = Archive (indigo), 2 = Works (violet); top to bottom.
@export var themes := PackedInt32Array([0])
## World y where each zone ends (one entry fewer than `themes`).
@export var zone_bottoms := PackedFloat32Array()
@export var blend := 500.0
## Screen-edge silhouettes, drifting motes and vignette.
@export var overlay := true

var glow_texture: GradientTexture2D
## Style of the zone the camera is in; the parallax layers draw in it.
var current_theme := 0
var _sky: ShaderMaterial
var _layers: Array = []
var _overlay: Control


func _ready() -> void:
	current_theme = themes[0]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.35))
	glow_texture = GradientTexture2D.new()
	glow_texture.gradient = grad
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.width = 128
	glow_texture.height = 128

	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -100
	add_child(sky_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = ShaderMaterial.new()
	_sky.shader = SkyShader
	rect.material = _sky
	sky_layer.add_child(rect)

	# [scroll, depth]: how far the layer moves with the camera, how dark it is
	for cfg in [[0.12, 0.2], [0.3, 0.4], [0.55, 0.58]]:
		var layer := Node2D.new()
		layer.set_script(LayerScript)
		layer.backdrop = self
		layer.scroll = cfg[0]
		layer.depth_k = cfg[1]
		layer.kind = _layers.size()
		layer.z_index = -10
		add_child(layer)
		_layers.append(layer)

	if overlay:
		var top := CanvasLayer.new()
		top.layer = 1  # above the level, below the HUD (layer 2)
		add_child(top)
		_overlay = Control.new()
		_overlay.set_script(OverlayScript)
		_overlay.backdrop = self
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(_overlay)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var c := cam.get_screen_center_position() if cam else get_viewport_rect().size * 0.5
	var pal := palette_at(c.y)
	_sky.set_shader_parameter("top_color", pal.top)
	_sky.set_shader_parameter("bottom_color", pal.bottom)
	_sky.set_shader_parameter("fog_color", pal.fog)
	_sky.set_shader_parameter("drift", c * 0.0002)
	var theme := theme_at(c.y)
	if theme != current_theme:
		current_theme = theme
		for layer in _layers:
			layer.retheme()
	for layer in _layers:
		layer.follow(c)
	if _overlay:
		_overlay.camera_center = c


## Which zone a world height is in.
func theme_at(world_y: float) -> int:
	for i in zone_bottoms.size():
		if world_y < zone_bottoms[i]:
			return themes[mini(i, themes.size() - 1)]
	return themes[themes.size() - 1]


## The colours at a world height, blended across zone borders.
func palette_at(world_y: float) -> Dictionary:
	var out: Dictionary = Style.PALETTES[themes[0]].duplicate()
	for i in zone_bottoms.size():
		if i + 1 >= themes.size():
			break
		var t := smoothstep(zone_bottoms[i] - blend * 0.5, zone_bottoms[i] + blend * 0.5, world_y)
		if t <= 0.0:
			break
		var next: Dictionary = Style.PALETTES[themes[i + 1]]
		for key in out:
			out[key] = (out[key] as Color).lerp(next[key], t)
	return out
