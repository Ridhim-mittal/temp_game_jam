extends "res://scripts/depth/ink_batch.gd"
## An InkBatch for drawing code that also writes text, draws textures or
## talks to the RenderingServer itself: shapes go into the batch (one draw
## call), and anything the batch can't do first hands over what's batched so
## far, then is drawn straight onto `target`, so the order on screen stays the
## same. draw_set_transform keeps working for both. Same method names as
## CanvasItem, so a painter written for a CanvasItem takes one as it is:
##
##   var p := InkProxy.new(self)
##   _paint(p)        # draw_rect, draw_string, draw_polygon(..., texture) ...
##   p.done()
##
## (cs_book.gd's live painters: the desk drew ~1000 draw calls a frame.)

var target: CanvasItem
var _direct := false  # target holds our transform for direct calls


func _init(ci: CanvasItem) -> void:
	target = ci


## Hands everything batched over; call it at the end of the painter.
func done() -> void:
	_emit()
	if _direct:
		target.draw_set_transform_matrix(Transform2D.IDENTITY)
		_direct = false


## The batch (its points are already transformed) onto an untransformed target.
func _emit() -> void:
	var xf := _xf
	if _direct:
		target.draw_set_transform_matrix(Transform2D.IDENTITY)
		_direct = false
	flush(target)
	_xf = xf


## Before a direct call: what's batched first, then the target under our transform.
func _go_direct() -> void:
	if not is_empty():
		_emit()
	if not _direct:
		target.draw_set_transform_matrix(_xf)
		_direct = true


func draw_set_transform(pos: Vector2, rot := 0.0, scale := Vector2.ONE) -> void:
	super.draw_set_transform(pos, rot, scale)
	if _direct:
		target.draw_set_transform_matrix(_xf)


func draw_set_transform_matrix(xf: Transform2D) -> void:
	super.draw_set_transform_matrix(xf)
	if _direct:
		target.draw_set_transform_matrix(_xf)


func get_canvas_item() -> RID:
	_go_direct()
	return target.get_canvas_item()


func draw_polygon(poly: PackedVector2Array, colors: PackedColorArray, uvs := PackedVector2Array(), texture: Texture2D = null) -> void:
	if texture == null:
		super.draw_polygon(poly, colors)
		return
	_go_direct()
	target.draw_polygon(poly, colors, uvs, texture)


func draw_colored_polygon(poly: PackedVector2Array, color: Color, uvs := PackedVector2Array(), texture: Texture2D = null) -> void:
	if texture == null:
		super.draw_colored_polygon(poly, color)
		return
	_go_direct()
	target.draw_colored_polygon(poly, color, uvs, texture)


func draw_texture_rect(texture: Texture2D, rect: Rect2, tile: bool, modulate := Color.WHITE, transpose := false) -> void:
	_go_direct()
	target.draw_texture_rect(texture, rect, tile, modulate, transpose)


func draw_texture_rect_region(texture: Texture2D, rect: Rect2, src_rect: Rect2, modulate := Color.WHITE, transpose := false, clip_uv := true) -> void:
	_go_direct()
	target.draw_texture_rect_region(texture, rect, src_rect, modulate, transpose, clip_uv)


func draw_texture(texture: Texture2D, pos: Vector2, modulate := Color.WHITE) -> void:
	_go_direct()
	target.draw_texture(texture, pos, modulate)


func draw_string(font: Font, pos: Vector2, text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font_size := 16,
		modulate := Color.WHITE, justification_flags := 3, direction := 0, orientation := 0) -> void:
	_go_direct()
	target.draw_string(font, pos, text, alignment, width, font_size, modulate, justification_flags, direction, orientation)


func draw_string_outline(font: Font, pos: Vector2, text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font_size := 16,
		size := 1, modulate := Color.WHITE, justification_flags := 3, direction := 0, orientation := 0) -> void:
	_go_direct()
	target.draw_string_outline(font, pos, text, alignment, width, font_size, size, modulate, justification_flags, direction, orientation)


func draw_multiline_string(font: Font, pos: Vector2, text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font_size := 16,
		max_lines := -1, modulate := Color.WHITE, brk_flags := 3, justification_flags := 3, direction := 0, orientation := 0) -> void:
	_go_direct()
	target.draw_multiline_string(font, pos, text, alignment, width, font_size, max_lines, modulate, brk_flags, justification_flags, direction, orientation)


func draw_dashed_line(from: Vector2, to: Vector2, color: Color, width := -1.0, dash := 2.0, aligned := true, antialiased := false) -> void:
	_go_direct()
	target.draw_dashed_line(from, to, color, width, dash, aligned, antialiased)
