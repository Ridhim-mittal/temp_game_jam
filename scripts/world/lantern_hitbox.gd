extends StaticBody2D
## Hit target for lantern.gd: forwards slashes and ink waves to the lantern.

var lantern: Node


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	lantern.take_hit(damage, hit_dir, from_pos)
