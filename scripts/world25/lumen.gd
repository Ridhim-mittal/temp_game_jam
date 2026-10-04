extends Node3D
## Lumen coin dropped by a beaten monster: pops out, settles on the ground,
## spins, and flies to Vesper when she comes near. Adds to Profile.lumens
## (the shop's money). Spawn several with Lumen.spill().

const Toon = preload("res://scripts/clearing/toon.gd")
const GOLD := Color(1.0, 0.8, 0.22)

var value := 1
var velocity := Vector3.ZERO

var _ground := 0.0
var _age := 0.0
var _coin: Node3D


## Scatter `total` Lumens as a few coins around `at`.
static func spill(tree: SceneTree, at: Vector3, total: int) -> void:
	var script: Script = load("res://scripts/world25/lumen.gd")
	var coins := clampi(total, 1, 6)
	for i in coins:
		var c: Node3D = script.new()
		c.value = total / coins + (1 if i < total % coins else 0)
		var a := randf() * TAU
		c.velocity = Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.5) + Vector3(0, randf_range(4.0, 6.0), 0)
		tree.current_scene.add_child(c)
		c.global_position = at + Vector3(0, 0.6, 0)
		c._ground = at.y


func _ready() -> void:
	_coin = Node3D.new()
	add_child(_coin)
	var size := 0.2 + 0.04 * minf(value, 5)
	Toon.part(_coin, Toon.cylinder(size, size, 0.07, 16), GOLD, Vector3.ZERO, Vector3(90, 0, 0), {"outline": 0.03, "emission": 0.4})
	Toon.part(_coin, Toon.cylinder(size * 0.6, size * 0.6, 0.08, 12), GOLD.lightened(0.35), Vector3(0, 0, 0.01), Vector3(90, 0, 0),
		{"outline": 0.0, "emission": 0.6})


func _physics_process(delta: float) -> void:
	_age += delta
	_coin.rotation.y += delta * 4.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and _age > 0.45 and not player.dead:
		var to := player.global_position + Vector3(0, 0.6, 0) - global_position
		if to.length() < 0.7:
			_collect()
			return
		if to.length() < 3.5:
			velocity = velocity.lerp(to.normalized() * 12.0, 1.0 - exp(-8.0 * delta))
			global_position += velocity * delta
			return
	velocity.y -= 18.0 * delta
	global_position += velocity * delta
	if global_position.y < _ground + 0.3:
		global_position.y = _ground + 0.3
		velocity = Vector3(velocity.x * 0.5, absf(velocity.y) * 0.3, velocity.z * 0.5)
		if velocity.length() < 0.5:
			velocity = Vector3.ZERO
	_coin.position.y = sin(_age * 3.0) * 0.06


func _collect() -> void:
	var profile := get_node_or_null("/root/Profile")
	if profile:
		profile.add_lumens(value)
	queue_free()
