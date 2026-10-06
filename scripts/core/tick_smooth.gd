class_name TickSmooth
extends Node
## Smooth motion on fast screens. A 2D body moves on physics ticks (60 a second
## in a browser) but a 144 Hz laptop screen draws more often than that, so the
## body (and a camera following it) would judder. This draws its parent, and
## everything under it, between its last two ticks, and slides `camera` along
## so the view glides too. Only the drawing moves: the body's position,
## collisions and hits stay the ticks' own.
##
##   TickSmooth.attach(body)            # a monster
##   TickSmooth.attach(self, $Camera2D) # the player and his camera

## A jump bigger than this in one tick is a teleport (a respawn, a checkpoint):
## shown at once, not slid across the screen.
const SNAP := 96.0

## Camera2D under the body that follows the drawn (smoothed) body.
var camera: Camera2D

var _body: Node2D
var _prev := Vector2.ZERO
var _last := Vector2.ZERO
var _seen_tick := -1


static func attach(body: Node2D, cam: Camera2D = null) -> TickSmooth:
	var s := TickSmooth.new()
	s.name = "TickSmooth"
	s.camera = cam
	body.add_child(s)
	return s


func _ready() -> void:
	_body = get_parent() as Node2D
	_prev = _body.position
	_last = _prev
	process_physics_priority = -1000  # before the body moves in the tick
	process_priority = 1000  # after everything else has moved things this frame


func _physics_process(_delta: float) -> void:
	_prev = _body.position


func _process(_delta: float) -> void:
	var pos := _body.position
	var tick := Engine.get_physics_frames()
	if tick == _seen_tick and pos != _last:
		_prev = pos  # moved between ticks (a cutscene, a tween): show it as it is
	_seen_tick = tick
	_last = pos
	var step := pos - _prev
	var off := Vector2.ZERO
	if step.length() < SNAP:
		off = step * (Engine.get_physics_interpolation_fraction() - 1.0)
	var xf := _body.transform
	xf.origin += off
	RenderingServer.canvas_item_set_transform(_body.get_canvas_item(), xf)
	if camera:
		camera.position = _body.transform.basis_xform_inv(off)
