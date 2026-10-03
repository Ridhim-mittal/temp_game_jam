extends Camera3D
## Tilted top-down follow camera (Cult of the Lamb framing): looks down at
## `pitch_deg`, trails the target smoothly and leans a little ahead of it.
## Follows the target's interpolated `smooth_position` when it has one, and
## eases height changes (stairs) more gently than ground movement.

@export var target_path: NodePath
@export var pitch_deg := 48.0
@export var distance := 19.0
## Follow speed on the ground plane (higher = tighter).
@export var smoothing := 4.0
## Follow speed for height changes, so stairs don't bob the view.
@export var height_smoothing := 2.5
## Seconds of the target's velocity to lead by.
@export var look_ahead := 0.3
## How quickly the lead builds up and settles back.
@export var look_ahead_smoothing := 2.0
## Keeps the focus point inside this x/z rectangle.
@export var bounds := Rect2(-12, -12, 24, 22)
@export_group("Warm-up")
## For the first frames the camera looks at the whole map, hidden behind a
## fade from black, so every material / light combination compiles while
## loading instead of hitching the first time the player walks somewhere.
@export var warmup_frames := 2
@export var warmup_distance := 44.0
@export var warmup_focus := Vector3(0.0, 0.0, -2.0)
@export var fade_in_time := 0.35
@export_group("Shake")
## Largest shake offset, in world units, at full trauma.
@export var max_shake := 0.35
@export var shake_decay := 3.0

var _target: Node3D
var _lead := Vector3.ZERO
var _focus := Vector3.ZERO
var _trauma := 0.0
var _warmup := 0
var _fade: ColorRect


func _ready() -> void:
	add_to_group("camera")
	_target = get_node_or_null(target_path)
	rotation = Vector3(deg_to_rad(-pitch_deg), 0.0, 0.0)
	if _target:
		_focus = _target_focus()
		global_position = _from_focus(_focus)
	if warmup_frames > 0:
		_warmup = warmup_frames
		_add_fade()
		global_position = _from_focus(warmup_focus, warmup_distance)


func _process(delta: float) -> void:
	if _warmup > 0:
		_warmup -= 1
		if _warmup == 0:
			_end_warmup()
		return
	if _target == null:
		return
	if "velocity" in _target:
		var v: Vector3 = _target.velocity
		_lead = _lead.lerp(Vector3(v.x, 0.0, v.z) * look_ahead, 1.0 - exp(-look_ahead_smoothing * delta))
	var goal := _target_focus() + _lead
	goal.x = clampf(goal.x, bounds.position.x, bounds.end.x)
	goal.z = clampf(goal.z, bounds.position.y, bounds.end.y)
	var k := 1.0 - exp(-smoothing * delta)
	_focus.x = lerpf(_focus.x, goal.x, k)
	_focus.z = lerpf(_focus.z, goal.z, k)
	_focus.y = lerpf(_focus.y, goal.y, 1.0 - exp(-height_smoothing * delta))
	global_position = _from_focus(_focus)
	_update_shake(delta)


## Trauma-based shake (same idea as the platformer's game_camera.gd),
## applied through the lens offset so it never disturbs the follow.
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var s := _trauma * _trauma * max_shake
	h_offset = randf_range(-1.0, 1.0) * s
	v_offset = randf_range(-1.0, 1.0) * s


func _target_focus() -> Vector3:
	var p: Vector3 = _target.smooth_position if "smooth_position" in _target else _target.global_position
	return p + Vector3(0.0, 0.8, 0.0)


func _from_focus(focus: Vector3, dist := distance) -> Vector3:
	var p := deg_to_rad(pitch_deg)
	return focus + Vector3(0.0, sin(p), cos(p)) * dist


func _add_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.015, 0.03)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	add_child(layer)


func _end_warmup() -> void:
	if _target:
		_focus = _target_focus()
		global_position = _from_focus(_focus)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, fade_in_time)
	t.tween_callback(_fade.get_parent().queue_free)
