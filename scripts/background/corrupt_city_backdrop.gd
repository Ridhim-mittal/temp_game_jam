extends Node2D
## Backdrop of Shade's corrupted comic city: the City's pop-art skyline
## (scenes/background/comic_background.tscn) raised and stretched so the
## street sits in the bottom ~15% of the screen, under a night sky
## (night_sky.gd) with the author's light pouring from the moon
## (moon_beam.gd), the deletion painted over the buildings
## (corruption_layer.gd) and rubble banked along the street (junk_heaps.gd).
##
## Pair it with a player camera whose framing_offset puts the street at
## `street_screen_y` (player.gd's Camera2D, see shades_city.tscn).

const ComicBackground = preload("res://scenes/background/comic_background.tscn")
const ParallaxScript = preload("res://scripts/background/comic_parallax.gd")
const NightSky = preload("res://scripts/background/night_sky.gd")
const MoonBeam = preload("res://scripts/background/moon_beam.gd")
const Corruption = preload("res://scripts/background/corruption_layer.gd")
const JunkHeaps = preload("res://scripts/background/junk_heaps.gd")

## Camera centre while the player stands on the street.
@export var camera_center := Vector2(640, 348)
## Screen y of the street top at that camera.
@export var street_screen_y := 612.0
## How much taller the skyline gets than in the City.
@export var building_scale := 1.45


func _ready() -> void:
	var bg := ComicBackground.instantiate()
	for c in bg.get_children():
		if c.name in ["Foreground", "Hills", "Sky", "DepthFog", "Rooftops"]:
			c.free()
			continue
		if "reference_camera_center" in c:
			c.reference_camera_center = camera_center
		var d := c.get_node_or_null("Drawer")
		if d and "street_y" in d:
			d.street_y = street_screen_y
			d.height_range *= building_scale
	add_child(bg)
	var sky := CanvasLayer.new()
	sky.layer = -100
	var sky_c := Control.new()
	sky_c.set_script(NightSky)
	sky.add_child(sky_c)
	add_child(sky)
	_parallax(Corruption, 0.45, -6)
	var beam := Node2D.new()
	beam.set_script(MoonBeam)
	beam.street_y = street_screen_y
	beam.z_index = -6
	add_child(beam)
	_parallax(JunkHeaps, 0.85, -5).base = street_screen_y


func _parallax(script: Script, scroll: float, z: int) -> Node2D:
	var p := Parallax2D.new()
	p.set_script(ParallaxScript)
	p.reference_camera_center = camera_center
	p.scroll_scale = Vector2(scroll, scroll)
	p.z_index = z
	var d := Node2D.new()
	d.set_script(script)
	p.add_child(d)
	add_child(p)
	return d
