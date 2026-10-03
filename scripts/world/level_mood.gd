extends Node
## Drop into a level to control how dark its backdrop is.
## With `darker_as_you_go` on, darkness rises from `darkness` at `start_x`
## to `end_darkness` at `end_x` as the player walks, so a level can start
## in the light and end in the dark.

@export_range(0.0, 1.0) var darkness := 0.0
@export var darker_as_you_go := false
@export_range(0.0, 1.0) var end_darkness := 1.0
@export var start_x := 0.0
@export var end_x := 2400.0


func _ready() -> void:
	var mood := get_node_or_null("/root/Mood")
	if mood:
		mood.manual = false
		mood.set_darkness(darkness, 0.0)


func _process(_delta: float) -> void:
	var mood := get_node_or_null("/root/Mood")
	if mood == null or mood.manual or not darker_as_you_go:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var t := clampf((player.global_position.x - start_x) / maxf(end_x - start_x, 1.0), 0.0, 1.0)
	mood.set_darkness(lerpf(darkness, end_darkness, t), 0.3)
