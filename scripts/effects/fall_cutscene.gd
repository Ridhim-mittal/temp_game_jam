extends Area2D
## A drop the player can't steer turned into a short cutscene (the Long
## Drop: shaft 2 into the Shadow Gallery, ~1200 px, past the fall-damage
## height). Falling into this area: the HUD fades out, black letterbox bars
## slide in, the camera leans in a little and Vesper is out of the player's
## hands (player.gd `cinematic`: no input, and the hard landing kneels but
## never hurts). A beat after he lands it all comes back. Origin = centre of
## the trigger, `size` its extent.

## The trigger: where the fall starts, under the shaft's last ledge.
@export var size := Vector2(450, 120)
## The camera's zoom is multiplied by this while it plays.
@export var zoom_in := 1.25
## How long Vesper stays down after landing before the player has him back.
@export var hold_after_land := 0.75

const BAR := 74.0  # letterbox bar height, px
const FADE := 0.45

var _player: CharacterBody2D
var _cam: Camera2D
var _base_zoom := Vector2.ONE
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _playing := false
var _t := 0.0
var _landed := -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _playing or not body.is_in_group("player") or not ("cinematic" in body):
		return
	var p := body as CharacterBody2D
	if p.dead or p.velocity.y <= 0.0:
		return  # only on the way down
	_start(p)


func _start(p: CharacterBody2D) -> void:
	_player = p
	_playing = true
	_t = 0.0
	_landed = -1.0
	p.cinematic = true
	_set_hud(0.0)
	_cam = p.get_node_or_null("Camera2D") as Camera2D
	if _cam:
		_base_zoom = _cam.zoom
		create_tween().tween_property(_cam, "zoom", _base_zoom * zoom_in, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_show_bars(true)


func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	if not is_instance_valid(_player) or _player.dead:
		_finish()
		return
	if _landed < 0.0 and _player.is_on_floor():
		_landed = _t
	# back to the player a beat after landing (or if something went wrong)
	if (_landed >= 0.0 and _t - _landed >= hold_after_land) or _t > 6.0:
		_finish()


func _finish() -> void:
	_playing = false
	if is_instance_valid(_player):
		_player.cinematic = false
	if is_instance_valid(_cam):
		create_tween().tween_property(_cam, "zoom", _base_zoom, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_set_hud(1.0)
	_show_bars(false)


## Fades everything on the level's UI layer (the HUD) to `alpha`.
func _set_hud(alpha: float) -> void:
	var ui := get_tree().current_scene.get_node_or_null("UI")
	if ui == null:
		return
	for c in ui.get_children():
		if c is CanvasItem:
			create_tween().tween_property(c, "modulate:a", alpha, FADE)


## Black bars top and bottom, sliding in (or out).
func _show_bars(on: bool) -> void:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 40  # over the level and its overlay, under the pause screen
		add_child(_layer)
		for i in 2:
			var bar := ColorRect.new()
			bar.color = Color(0.01, 0.005, 0.02)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_layer.add_child(bar)
			_bars.append(bar)
	var screen := get_viewport().get_visible_rect().size
	for i in 2:
		var bar := _bars[i]
		bar.size = Vector2(screen.x, BAR)
		var hidden_y := -BAR if i == 0 else screen.y
		var shown_y := 0.0 if i == 0 else screen.y - BAR
		if on:
			bar.position = Vector2(0, hidden_y)
		var t := create_tween()
		t.tween_property(bar, "position:y", shown_y if on else hidden_y, FADE) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
