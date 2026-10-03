extends RefCounted
## Cheap "is this near the visible screen?" test, so animated props can skip
## redrawing while off-screen (Godot still runs _draw for off-screen items
## when asked to, and that GDScript work adds up with dozens of props).


static func near(item: CanvasItem, margin := 160.0) -> bool:
	if Engine.is_editor_hint():
		return true
	var p := item.get_global_transform_with_canvas().origin
	return item.get_viewport_rect().grow(margin).has_point(p)
