extends "res://scripts/world/goo_pool.gd"
## Temporary slowing puddle left by an Inkwell blob. Same behaviour as the
## goo pool, ink-coloured, and it dries up after `lifetime` seconds.

@export var lifetime := 4.0


func _ready() -> void:
	goo_color = Color(0.32, 0.3, 0.55)
	goo_dark = Color(0.07, 0.06, 0.14)
	speed_mult = 0.5
	jump_mult = 0.75
	super()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	modulate.a = clampf(lifetime / 0.5, 0.0, 1.0)
	if lifetime <= 0.0:
		# release anyone still standing in it, or they would stay slowed
		for body in get_overlapping_bodies():
			if body.has_method("set_slowed"):
				body.set_slowed(self, 1.0, 1.0)
		queue_free()
