@tool
extends Parallax2D
## Parallax2D whose children are authored in "screen space at the reference
## camera": when the camera is centred on `reference_camera_center`, a child
## at local (x, 450) is drawn at screen y = 450. Any other camera position
## shifts it by scroll_scale, which acts as 1 / distance (0 = at infinity,
## 1 = moves with the playfield, > 1 = foreground in front of the player).

## Camera centre while the player stands on the main ground
## (player y 574 + camera framing offset -60).
@export var reference_camera_center := Vector2(640, 514)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Parallax2D: position = screen_offset * (1 - scroll_scale) + scroll_offset
	# => on-screen = local - scroll_scale * screen_offset + scroll_offset.
	var reference_offset := reference_camera_center - get_viewport_rect().size * 0.5
	scroll_offset = scroll_scale * reference_offset
