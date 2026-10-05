extends Resource
## A 2.5D biome: everything that gives a region of the Margins its look.
## Rooms (room.gd) apply it to the environment, light and fog; islands
## (island.gd) and grass (grass_field.gd) read its palette. A BlendZone
## morphs one biome into another across a room.
## Saved as .tres files in data/biomes/.

enum Ground { GRASS, WATER_STONE, CRACKED }

@export var display_name := "The Margins"
@export var ground := Ground.GRASS

@export_group("Ground palette")
@export var base := Color(0.37, 0.54, 0.41)
@export var light := Color(0.5, 0.64, 0.45)
@export var dark := Color(0.25, 0.4, 0.34)
## Second ground colour: sand patches (grass), caustic light (water),
## pale grit (cracked).
@export var accent := Color(0.84, 0.66, 0.44)
@export var accent_dark := Color(0.66, 0.47, 0.3)
@export var stain := Color(0.34, 0.16, 0.26)
@export var cliff := Color(0.14, 0.11, 0.17)
@export var cliff_line := Color(0.25, 0.2, 0.28)
@export var lip := Color(0.36, 0.28, 0.26)

@export_group("Plants")
@export var tuft_base := Color(0.18, 0.33, 0.27)
@export var tuft_tip := Color(0.5, 0.68, 0.45)

@export_group("Light and air")
@export var background := Color(0.035, 0.03, 0.06)
@export var ambient := Color(0.47, 0.42, 0.66)
@export var ambient_energy := 0.6
@export var sun := Color(1, 0.92, 0.84)
@export var sun_energy := 0.85
@export var fog := Color(0.05, 0.04, 0.09)
## Colour of the drifting motes.
@export var motes := Color(1, 0.88, 0.55)

@export_group("Mood")
## Music track for the Music autoload ("lit", "margins", "boss", "ending").
@export var music := "margins"
## Comic overlay vignette strength.
@export var vignette := 0.35


## The nine ground colours in the order ground.gdshader expects.
func ground_palette() -> Array[Color]:
	return [base, light, dark, accent, accent_dark, stain, cliff, lip, cliff_line]
