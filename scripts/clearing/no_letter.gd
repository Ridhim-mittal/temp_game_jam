extends StaticBody3D
## One fat red letter of the Red Pen's "NO." (red_pen_3d.gd): it rises out
## of the ground as a solid wall of wet ink to box Vesper in. It runs
## (melts) after `life` seconds, when struck twice, or at once when the
## Writer's kind of light touches it (a Flash).

const Light = preload("res://scripts/world25/light.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const RED := Color(0.9, 0.12, 0.16)
const INK := Color(0.05, 0.03, 0.1)

var letter := "N"
var life := 7.0
var hits := 2

var _label: Label3D
var _shadow: Label3D
var _age := 0.0
var _gone := false


func _ready() -> void:
	collision_layer = 1 | 4  # solid world, and the enemy layer so swings find it
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.7, 0.8)
	cs.shape = box
	cs.position.y = 0.85
	add_child(cs)
	_shadow = _make_label(Color(0.35, 0.02, 0.06), 0)
	_shadow.position = Vector3(0.09, 0.85, -0.06)
	_label = _make_label(RED, 36)
	_label.position = Vector3(0, 0.9, 0)
	scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.4, 0), RED, 10, 3.0)


func _make_label(col: Color, outline: int) -> Label3D:
	var l := Label3D.new()
	l.text = letter
	l.font = FONT
	l.font_size = 220
	l.pixel_size = 0.009
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = INK
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.shaded = false
	l.double_sided = true
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _gone:
		return
	_age += delta
	_label.position.y = 0.9 + sin(_age * 3.0) * 0.03
	if _age > life - 1.0:
		_label.modulate.a = 0.5 + 0.5 * absf(sin(_age * 12.0))  # about to run
	if _age >= life:
		melt("")
	elif Light.is_lit(get_tree(), global_position + Vector3(0, 0.6, 0), true):
		melt("HSSS!")


func is_harmful() -> bool:
	return false


func take_hit(_damage: int, _dir: Vector3, _aerial := false) -> bool:
	if _gone:
		return false
	hits -= 1
	_label.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(_label, "modulate", RED, 0.15)
	if hits <= 0:
		melt("SPLUT!")
	return true


func melt(word: String) -> void:
	if _gone:
		return
	_gone = true
	collision_layer = 0
	if word != "":
		Fx.pop_text(get_tree(), global_position + Vector3(0, 1.6, 0), word, Color(1.0, 0.7, 0.6), 26)
	Fx.splat(get_tree(), global_position, 1.2)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4), 0.25)
	t.tween_callback(queue_free)
