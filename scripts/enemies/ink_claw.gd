extends Area2D
## The Ink Blot's swipe: switched onto the enemy layer (and into the "enemy"
## group) only while the claw is sweeping; the player's hurtbox reads damage.

var damage := 20.0
var dead := false


func get_damage() -> float:
	return damage
