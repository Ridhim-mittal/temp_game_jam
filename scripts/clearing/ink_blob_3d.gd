extends Node3D
## Ink blob lobbed by an Inkwell in the clearing: flies in an arc, hurts the
## player on contact, can be slashed out of the air, and leaves a sticky
## puddle (ink_puddle_3d.gd) where it lands.

const Toon = preload("res://scripts/clearing/toon.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const Puddle = preload("res://scripts/clearing/ink_puddle_3d.gd")
const INK := Color(0.1, 0.08, 0.18)

var velocity := Vector3.ZERO
var gravity := 18.0
var damage := 1  # half ink bottles: a blob is half a bottle

var _life := 4.0


## Launches from `from` so that it lands on `to` after `flight_time` s.
func launch(from: Vector3, to: Vector3, flight_time: float) -> void:
	global_position = from
	velocity = (to - from) / flight_time + Vector3(0, 0.5 * gravity * flight_time, 0)


func _ready() -> void:
	add_to_group("ink_blob")
	Toon.part(self, Toon.sphere(0.22, 10, 6), INK, Vector3.ZERO, Vector3.ZERO, {"outline": 0.035})


func _physics_process(delta: float) -> void:
	_life -= delta
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not hit.is_empty():
		_land(hit.position)
		return
	global_position = to
	scale = Vector3(1.0, 1.0 + clampf(absf(velocity.y) * 0.03, 0.0, 0.5), 1.0)  # stretch in flight
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position + Vector3(0, 0.6, 0)) < 0.55:
			player.take_damage(damage, global_position)
			Fx.burst(get_tree(), global_position, INK, 10, 3.0)
			queue_free()
			return
	if _life <= 0.0:
		queue_free()


## Cut out of the air by the player's attack.
func slash() -> void:
	Fx.burst(get_tree(), global_position, INK, 12, 3.5)
	Fx.pop_text(get_tree(), global_position + Vector3(0, 0.6, 0), "SPLAT!", Color(0.6, 0.6, 0.9), 26)
	queue_free()


func _land(at: Vector3) -> void:
	var puddle := Puddle.new()
	get_tree().current_scene.add_child(puddle)
	puddle.global_position = at
	Fx.burst(get_tree(), at + Vector3(0, 0.1, 0), INK, 8, 2.5)
	queue_free()
