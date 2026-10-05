extends StaticBody3D
## Test target for tests/gutter: counts hits, sits on the enemy layer
## (layer 3), in group "enemy" so aim assist sees it.
var dead := false
var hits := 0

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)

func take_hit(_damage: int, _dir: Vector3, _aerial := false) -> bool:
	hits += 1
	return true
