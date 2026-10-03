extends "res://scripts/clearing/monster_3d.gd"
## Inkwell (clearing version of scripts/enemies/inkwell.gd): a living ink
## bottle that never moves and lobs ink blobs at the player in an arc.
## Blobs can be slashed out of the air; ones that land leave a sticky
## puddle that slows you. Keep moving, or close in and smash the bottle.

const InkBlob = preload("res://scripts/clearing/ink_blob_3d.gd")

@export var fire_interval := 2.4
@export var aim_time := 0.4
@export var flight_time := 0.9
## Leads the shot by this many seconds of the player's movement.
@export var lead := 0.35

var _cooldown := 1.2
var _aim := 0.0


func _ready() -> void:
	hp = 4
	sight = 11.0
	knockback = 0.0
	setup_monster("res://scenes/enemies/inkwell.tscn", 224, 40)


func _tick(delta: float) -> void:
	_slow_to_stop(30.0, delta)
	_cooldown -= delta
	if not sees_player():
		return
	face_dir(to_player())
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_fire()
	elif _cooldown <= 0.0:
		_aim = aim_time
		_cooldown = fire_interval


func _fire() -> void:
	if _player == null:
		return
	var target := _player.global_position
	if "velocity" in _player:
		var v: Vector3 = _player.velocity
		target += Vector3(v.x, 0.0, v.z) * lead
	var blob := InkBlob.new()
	get_tree().current_scene.add_child(blob)
	blob.launch(global_position + Vector3(0, 1.2, 0), target, flight_time)
	pop("PLOP!", Color(0.6, 0.6, 0.9), 1.6, 22)


func _on_respawn() -> void:
	_cooldown = 1.5
	_aim = 0.0


func _sync_puppet() -> void:
	puppet.figure._aim = _aim
