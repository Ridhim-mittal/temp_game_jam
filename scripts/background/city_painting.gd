extends Node2D
## Backdrop of Shade's corrupted comic city, redrawn from the concept painting:
## night sky (night_sky.gd) and the moon's beam (moon_beam.gd), the buildings
## and their graffiti (city_panorama.gd "city", slow parallax) and the junk
## along the street (city_panorama.gd "junk", near parallax). Both repeat
## every 1280 px so the street can run on. At `camera_center` the screen
## matches the painting.

const ParallaxScript = preload("res://scripts/background/comic_parallax.gd")
const NightSky = preload("res://scripts/background/night_sky.gd")
const MoonBeam = preload("res://scripts/background/moon_beam.gd")
const Panorama = preload("res://scripts/background/city_panorama.gd")

@export var camera_center := Vector2(640, 348)
@export var street_screen_y := 612.0


func _ready() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -100
	var sky_c := Control.new()
	sky_c.set_script(NightSky)
	sky_c.moon = Vector2(0.51, 0.08)
	sky.add_child(sky_c)
	add_child(sky)
	_layer("city", 0.3, -10)
	var beam := Node2D.new()
	beam.set_script(MoonBeam)
	beam.street_y = street_screen_y
	beam.moon = Vector2(0.51, 0.08)
	beam.strength = 1.8
	beam.z_index = -8
	add_child(beam)
	_layer("junk", 0.85, -6)


func _layer(part: String, scroll: float, z: int) -> void:
	var p := Parallax2D.new()
	p.set_script(ParallaxScript)
	p.reference_camera_center = camera_center
	p.scroll_scale = Vector2(scroll, scroll)
	p.repeat_size = Vector2(1280, 0)
	p.repeat_times = 3
	p.z_index = z
	var d := Node2D.new()
	d.set_script(Panorama)
	d.part = part
	p.add_child(d)
	add_child(p)
