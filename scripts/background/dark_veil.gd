extends Node2D
## Covers the whole backdrop (sky and city, not the playfield in front) and
## darkens it according to Mood.darkness: a flat multiply tint plus scratchy
## ink hatching, and pale chalk scratches once it is really dark.
## Lives at the end of comic_background.tscn, behind the level.

const ComicView = preload("res://scripts/background/comic_view.gd")
const VeilShader = preload("res://shaders/dark_veil.gdshader")
const PaleShader = preload("res://shaders/pale_scratches.gdshader")

## Backdrop colour multiplier at full darkness.
@export var tint := Color(0.26, 0.2, 0.4)

var _veil_mat := ShaderMaterial.new()
var _pale_mat := ShaderMaterial.new()
var _pale: Node2D


func _ready() -> void:
	_veil_mat.shader = VeilShader
	_veil_mat.set_shader_parameter("tint", tint)
	material = _veil_mat
	_pale_mat.shader = PaleShader
	_pale = Node2D.new()
	_pale.material = _pale_mat
	_pale.draw.connect(_draw_rect_on.bind(_pale))
	add_child(_pale)


func _process(_delta: float) -> void:
	var mood := get_node_or_null("/root/Mood")
	var d: float = mood.darkness if mood else 0.0
	_veil_mat.set_shader_parameter("darkness", d)
	_pale_mat.set_shader_parameter("darkness", d)
	visible = d > 0.005
	queue_redraw()
	_pale.queue_redraw()


func _draw() -> void:
	_draw_rect_on(self)


## A rectangle exactly covering the screen, with UV 0..1 across it.
func _draw_rect_on(item: CanvasItem) -> void:
	var r: Rect2 = ComicView.local_view(item).rect.grow(4.0)
	item.draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color.WHITE]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
