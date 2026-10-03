extends ColorRect
## Full-screen shader rect (sky / overlay): keeps the shader's `rect_size`
## and `vanishing_point` uniforms in sync with the layout.

const ComicView = preload("res://scripts/background/comic_view.gd")


func _ready() -> void:
	resized.connect(_sync)
	_sync()


func _sync() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("vanishing_point", ComicView.VANISHING_POINT)
