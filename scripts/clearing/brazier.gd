@tool
extends Node3D
## One of the Writer's desk lamps (desk_lamp.gd), giant down in the Gutter:
## a white base, a jointed wooden arm and a white dome shade tipped over it,
## throwing a warm (or spirit-blue) pool of light round its base. The light
## counts for monsters and drawn things (world25/light.gd).
## Set `lit` off for a lamp that's switched off: the player turns it on by
## hitting it (or with a Flash), and it stays on for good.
## (Was a stone brazier with a flame; the name and exports are kept so the
## rooms and their generator still work.)

const Toon = preload("res://scripts/clearing/toon.gd")
const DeskLamp = preload("res://scripts/clearing/desk_lamp.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")

## The bulb's colour (the pool of light leans to it).
@export var flame_color := Color(1.0, 0.34, 0.12):
	set(v):
		flame_color = v
		_rebuild()
@export var core_color := Color(1.0, 0.82, 0.38):
	set(v):
		core_color = v
		_rebuild()
## The lamp's size (1 = about two units tall).
@export var pedestal_height := 1.0:
	set(v):
		pedestal_height = v
		_rebuild()
@export var lit := true:
	set(v):
		lit = v
		_rebuild()
@export var light_energy := 1.9
@export var light_range := 6.0
## Radius of the pool that counts as light for the monsters (the design
## doc's light rules: Crumples unfold, Crossed-Out X's burn, Smudges show).
@export var light_radius := 3.2

var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	_time = randf() * 10.0
	if not Engine.is_editor_hint():
		add_to_group("light_3d")
		add_to_group("lantern")
	_rebuild()


## Light an unlit lantern (player hits and Flashes call this).
func ignite() -> void:
	if lit:
		return
	lit = true
	Fx.burst(get_tree(), global_position + Vector3(0, 1.8 * _size(), 0), core_color, 14, 3.0)
	Fx.pop_text(get_tree(), global_position + Vector3(0, 2.6 * _size(), 0), "CLICK!", core_color.lightened(0.3), 28)


func on_flash(_from: Vector3) -> void:
	ignite()


func lights(point: Vector3) -> bool:
	if not lit:
		return false
	var d := point - global_position
	return Vector2(d.x, d.z).length() < light_radius and absf(d.y) < 2.0


func _size() -> float:
	return clampf(pedestal_height, 0.5, 1.6)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var lamp := DeskLamp.build(root, Vector3.ZERO, _size(), 0.0, flame_color, core_color)
	_light = lamp.light
	(lamp.on as Node3D).visible = lit
	if _light:
		_light.visible = lit
		_light.light_energy = light_energy
		_light.omni_range = light_range
		if not lit:
			_light = null
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(0.45 * _size(), 1.2 * _size()), Vector3(0, 0.6 * _size(), 0))


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	# a bulb, not a flame: only the faintest hum
	_light.light_energy = light_energy * (0.97 + 0.03 * sin(_time * 7.0))
