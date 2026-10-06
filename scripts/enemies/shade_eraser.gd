extends Node2D
## SHADE'S ERASER: the Writer's eraser, come down to rub Vesper out of the
## book (from the "Animated SCARY ERASER Boss" sheet; the art is shared with
## every Eraser: eraser_art.gd). A tall block eraser:
## a worn pink rubber top with a chipped crown, a torn tan cardboard sleeve
## with a blue band down one side ("SHADE'S ERASER"), a skull of a face
## printed on the sleeve (angry white eyes, a nose hole, a gaping maw of
## jagged teeth), pink rubber underneath, and thin black scribbled arms with
## clawed hands. Simple, low-colour, thick outlines. It never keeps still: it
## vibrates at a high frame rate (`jitter`), and when it RUBS it tilts and
## scrubs from side to side throwing pink eraser shavings and grey dust.
## Drawn in code (eraser_art.gd, one draw call); origin = the middle of its base.
##
## eraser_chase.gd drives it (where it is, `rubbing`, `lunge`); touching it
## costs half a bottle (a hurt area on the enemy layer, group "enemy").

const Art = preload("res://scripts/enemies/eraser_art.gd")
const InkBits = preload("res://scripts/effects/ink_bits.gd")

## Size of the block, px (Vesper is about 52 px tall).
@export var block := Vector2(210, 330)
## 0..1: scrubbing from side to side (the rub).
@export var rubbing := 0.0
## How hard it shakes all the time.
@export var jitter := 1.0
## Which way it's going (1 right, -1 left): it leans into it.
var heading := 1.0
## 0..1: the maw opening (a roar).
var roar := 0.0
## Lean forward into a lunge (0..1).
var lunge := 0.0
## 0..1: its eyes burn red.
var rage := 0.0

var _time := 0.0
var _hurt: Area2D
var _crumbs := 0.0


func _ready() -> void:
	z_index = 5
	_hurt = Area2D.new()
	_hurt.collision_layer = 4  # the enemy layer: Vesper's hurtbox finds it
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	_hurt.add_to_group("enemy")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(block.x * 0.8, block.y * 0.9)
	cs.shape = r
	cs.position = Vector2(0, -block.y * 0.45)
	_hurt.add_child(cs)
	add_child(_hurt)


## Turns the hurt area on or off (off during cutscenes).
func set_harmful(on: bool) -> void:
	if on and not _hurt.is_in_group("enemy"):
		_hurt.add_to_group("enemy")
	elif not on and _hurt.is_in_group("enemy"):
		_hurt.remove_from_group("enemy")


func _process(delta: float) -> void:
	_time += delta
	# shavings and dust while it rubs
	if rubbing > 0.05:
		_crumbs += delta * (10.0 * rubbing)
		while _crumbs >= 1.0:
			_crumbs -= 1.0
			_shavings()
	queue_redraw()


func _shavings() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var at := global_position + Vector2(randf_range(-block.x * 0.5, block.x * 0.5), -6.0)
	var fx := InkBits.burst(tree, at, 3, 260.0, Vector2(-heading, -0.6), 0.0)
	if fx:
		fx.modulate = Color(1.6, 0.75, 0.8)  # pink rubber crumbs, not ink
	if randf() < 0.5:
		var dust := InkBits.burst(tree, at, 2, 120.0, Vector2(-heading, -0.3), 1.0)
		if dust:
			dust.modulate = Color(0.75, 0.75, 0.78, 0.7)


func _draw() -> void:
	var k := Vector2(block.x / Art.W, block.y / Art.H)
	Art.draw(self, Transform2D(0.0, k, 0.0, Vector2.ZERO), {"time": _time, "rubbing": rubbing, "roar": roar,
		"lunge": lunge, "heading": heading, "jitter": jitter, "rage": rage})
