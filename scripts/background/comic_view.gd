extends RefCounted
## Shared perspective math for the comic background layers.
##
## The backdrop is built like a real 3D street seen through a 2D camera:
##  - every layer sits inside a Parallax2D whose scroll_scale = 1 / distance,
##  - boxes (buildings, props) are drawn in one-point perspective toward a
##    single vanishing point on the horizon.
## The vanishing point is at infinity, so it never moves when the camera
## translates: it is a fixed spot on screen, shared with the sky shader.

## Vanishing point / horizon position on screen, in 0..1 UV.
const VANISHING_POINT := Vector2(0.5, 0.6)


## Visible screen rectangle and the vanishing point, both expressed in
## `item`'s local coordinates (accounts for Parallax2D offsets and zoom).
static func local_view(item: CanvasItem) -> Dictionary:
	var screen := item.get_viewport_rect().size
	var inv := item.get_global_transform_with_canvas().affine_inverse()
	var a := inv * Vector2.ZERO
	var b := inv * screen
	return {
		"rect": Rect2(a, b - a).abs(),
		"vp": inv * (screen * VANISHING_POINT),
	}


## Projects `p` (on a box's front plane) onto its back plane. `depth` is the
## box depth relative to its distance, D / (z + D): 0 = flat, 1 = infinite.
static func recede(p: Vector2, vp: Vector2, depth: float) -> Vector2:
	return vp + (p - vp) * (1.0 - depth)


## Tags a colour for comic_halftone.gdshader: alpha 1 = flat colour,
## alpha 0.5 = full-strength halftone dots. The shader outputs it opaque.
static func halftone(c: Color, amount: float) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - 0.5 * clampf(amount, 0.0, 1.0))
