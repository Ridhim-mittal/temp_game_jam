@tool
extends Node3D
## Stone pedestal with an iron bowl and a flickering comic flame. Lights
## the area around it with a warm (or spirit-blue) cel-shaded pool, and
## counts as light for monsters and drawn things (world25/light.gd).
## Set `lit` off for a lantern the player lights by hitting it or with a
## Flash; it then stays lit for good.

const Toon = preload("res://scripts/clearing/toon.gd")
const FLAME_SHADER = preload("res://shaders/clearing/flame.gdshader")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")

@export var flame_color := Color(1.0, 0.34, 0.12):
	set(v):
		flame_color = v
		_rebuild()
@export var core_color := Color(1.0, 0.82, 0.38):
	set(v):
		core_color = v
		_rebuild()
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
	Fx.burst(get_tree(), global_position + Vector3(0, pedestal_height + 0.6, 0), flame_color, 14, 3.0)
	Fx.pop_text(get_tree(), global_position + Vector3(0, pedestal_height + 1.6, 0), "WHOOSH!", flame_color.lightened(0.3), 28)


func on_flash(_from: Vector3) -> void:
	ignite()


func lights(point: Vector3) -> bool:
	if not lit:
		return false
	var d := point - global_position
	return Vector2(d.x, d.z).length() < light_radius and absf(d.y) < 2.0


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	var h := pedestal_height
	Toon.part(root, Toon.cylinder(0.32, 0.42, h, 8), Toon.STONE, Vector3(0, h * 0.5, 0), Vector3.ZERO, {"moss": 0.4})
	Toon.part(root, Toon.cylinder(0.5, 0.25, 0.32, 10), Color(0.18, 0.15, 0.2), Vector3(0, h + 0.16, 0))
	_light = null
	if not lit:
		# cold wick and ash: hit it or Flash near it to light it
		Toon.part(root, Toon.cylinder(0.05, 0.07, 0.3, 6), Color(0.12, 0.1, 0.12), Vector3(0, h + 0.3, 0))
		Toon.part(root, Toon.sphere(0.18, 8, 4, true), Color(0.35, 0.32, 0.34), Vector3(0, h + 0.2, 0), Vector3.ZERO, {"outline": 0.02})
		if not Engine.is_editor_hint():
			Toon.collider(root, Toon.cylinder_shape(0.45, h + 0.3), Vector3(0, (h + 0.3) * 0.5, 0))
		return
	Toon.billboard(root, FLAME_SHADER, Vector2(0.95, 1.25), Vector3(0, h + 0.75, 0),
		{"outer_color": flame_color, "core_color": core_color})
	_light = OmniLight3D.new()
	_light.light_color = flame_color.lerp(core_color, 0.4)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 0.8
	_light.position = Vector3(0, h + 0.9, 0)
	root.add_child(_light)
	if not Engine.is_editor_hint():
		Toon.collider(root, Toon.cylinder_shape(0.45, h + 0.3), Vector3(0, (h + 0.3) * 0.5, 0))


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	var flicker := 0.88 + 0.08 * sin(_time * 11.0) + 0.06 * sin(_time * 23.0 + 1.3)
	_light.light_energy = light_energy * flicker
