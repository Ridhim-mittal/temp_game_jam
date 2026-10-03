extends Node2D
## Keeps a 2D overlay (like the comic hit text) pinned over a 3D point while
## the camera moves. Frees itself once its children are gone.

var world_position := Vector3.ZERO


func _ready() -> void:
	_update()


func _process(_delta: float) -> void:
	if get_child_count() == 0:
		queue_free()
		return
	_update()


func _update() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		visible = not cam.is_position_behind(world_position)
		position = cam.unproject_position(world_position)
