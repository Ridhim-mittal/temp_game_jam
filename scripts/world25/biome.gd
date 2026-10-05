extends Resource
## A 2.5D biome: everything that gives a region of the Gutter its look.
## Rooms (room.gd) apply it to the environment, moonlight and fog; islands
## (island.gd) read its ground palette. A room's biome_b morphs one biome
## into another across it. Saved as .tres files in data/biomes/.
## Colours are authored as sRGB, like everywhere else.

## How the ground is painted (ground.gdshader). The names are historical:
##   GRASS        packed earth and broken flagstones (the Spine, the Inkwood)
##   WATER_STONE  black wet flagstones and standing ink (the Drowned Margin)
##   CRACKED      ash-grey cracked ground, flakes of torn paper (the Wastes)
enum Ground { GRASS, WATER_STONE, CRACKED }

@export var display_name := "The Gutter"
@export var ground := Ground.GRASS

@export_group("Ground palette")
@export var base := Color(0.165, 0.184, 0.212)
@export var light := Color(0.2, 0.22, 0.25)
@export var dark := Color(0.11, 0.12, 0.14)
## Second ground colour: packed-earth patches (earth), the cold sheen on
## standing ink (water), pale grit and paper flakes (cracked).
@export var accent := Color(0.3, 0.3, 0.3)
## Cracks and stone joints.
@export var accent_dark := Color(0.06, 0.06, 0.08)
## Ink stains and puddles.
@export var stain := Color(0.03, 0.03, 0.05)
@export var cliff := Color(0.05, 0.05, 0.07)
@export var cliff_line := Color(0.09, 0.09, 0.11)
@export var lip := Color(0.12, 0.12, 0.14)
## The palette above is what the floor should look like on screen; the
## cel lighting in the dark only passes a fraction of that, so the ground's
## albedo is lifted by this much (linear).
@export var ground_brightness := 3.0

@export_group("Plants")
## Unused since the Gutter rework (no grass); kept so .tres files load.
@export var tuft_base := Color(0.18, 0.33, 0.27)
@export var tuft_tip := Color(0.5, 0.68, 0.45)

@export_group("Light and air")
@export var background := Color(0.043, 0.055, 0.078)
@export var ambient := Color(0.42, 0.5, 0.62)
@export var ambient_energy := 0.35
## The moon: cool and weak.
@export var sun := Color(0.62, 0.72, 0.9)
@export var sun_energy := 0.4
## Distance / height fog colour (Environment).
@export var fog := Color(0.06, 0.07, 0.1)
## Environment depth-fog density.
@export var fog_density := 0.012
## The drifting fog banks (room.gd): lighter than the background, so dead
## trees and railings read as black silhouettes against them.
@export var fog_bank := Color(0.32, 0.37, 0.42)
@export var fog_bank_alpha := 0.32
## Colour of the drifting motes; also the biome's accent (lit lanterns).
@export var motes := Color(0.79, 0.77, 0.71)

@export_group("Mood")
## Music track for the Music autoload ("lit", "margins", "boss", "ending").
@export var music := "margins"
## Comic overlay vignette strength.
@export var vignette := 0.6


## The nine ground colours in the order ground.gdshader expects, converted
## to linear (the shader's palette uniforms take linear values) and lifted
## by ground_brightness.
func ground_palette() -> Array[Color]:
	var out: Array[Color] = []
	for c in [base, light, dark, accent, accent_dark, stain, cliff, lip, cliff_line]:
		var l: Color = c.srgb_to_linear() * ground_brightness
		l.a = 1.0
		out.append(l)
	return out
