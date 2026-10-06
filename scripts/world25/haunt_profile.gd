class_name HauntProfile
extends Resource
## How hard the Writer's Haunting Lamp (haunt_lamp.gd) hunts Vesper in one
## part of the Gutter. A Biome points at one (`haunt`); room.gd spawns the
## lamps. Saved as .tres files in data/haunt/. Settings difficulty scales it
## (Relaxed: speeds x0.75, telegraphs x1.3; Hard: speeds x1.25, telegraphs
## x0.8) and each room can push it a little harder (room.gd haunt_scale).

## How many lamps hunt in a room.
@export var lamps := 1
## Seconds after entering a room before a lamp starts hunting.
@export var grace := 4.0
## How fast the circle of light drifts after Vesper (units / second).
@export var seek_speed := 2.2
@export var circle_radius := 2.4
## Seconds between strikes; 0 = it never strikes (only searches).
@export var strike_every := 9.0
## How long the marked circle fills before the column slams down.
@export var telegraph := 1.6
## Seconds standing in the light to fill the erase meter.
@export var erase_fill := 1.1
## Seconds Vesper must stay out of the light before it loses him.
@export var lose_after := 1.5
## Off: it fills the meter and whitens him, but never takes an ink bottle.
@export var can_damage := true
## How much one strike adds to the erase meter (1 = a whole drop).
@export var strike_erase := 0.65
## Seconds the column stays down after a strike, sweeping slowly.
@export var linger := 1.4

@export_group("The Writer's lines")
## Shown (shaky) once per room at most, each.
@export var say_on_spot := "I can see you."
@export var say_on_lost := "Where did you go?"
@export var say_on_strike := ""
