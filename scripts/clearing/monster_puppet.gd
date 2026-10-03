extends Node3D
## Shows one of the platformer's 2D monsters (scenes/enemies/*.tscn) in the
## 2.5D clearing, so both modes share the same art. The 2D monster runs
## inside a SubViewport as a "puppet": its own behaviour is switched off and
## the 3D monster drives the fields its paint() reads (state, time, facing,
## velocity...). The SubViewport texture is shown on a camera-facing sprite.
##
##   puppet.setup("res://scenes/enemies/crumple.tscn")
##   puppet.figure.state = 2         # whatever the 2D script's paint() reads
##   puppet.facing = -1
##   puppet.look_at_point(player_pos)

## 2D pixels are drawn at this scale inside the viewport (sharper sprite).
const ART_SCALE := 2.0
## World units per 2D pixel at ART_SCALE: matches Vesper in the clearing.
const PIXEL_SIZE := 0.0145

## The 2D monster node (its script's variables are set by the 3D monster).
var figure: Node2D
var facing := 1

var _viewport: SubViewport
var _sprite: Sprite3D
var _look: Node2D
var _holder: Node2D


## size: viewport size in px; feet_margin: px below the feet (for effects
## drawn under the body); blend: soft alpha instead of a hard cut-out (for
## see-through monsters like the Smudge).
func setup(scene_path: String, size := 256, feet_margin := 40, blend := false) -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(size, size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_holder = Node2D.new()
	_holder.position = Vector2(size * 0.5, size - feet_margin)
	_holder.scale = Vector2.ONE * ART_SCALE
	_viewport.add_child(_holder)
	figure = load(scene_path).instantiate()
	_holder.add_child(figure)
	# behaviour off: the 3D monster is in charge
	figure.set_physics_process(false)
	figure.collision_layer = 0
	figure.collision_mask = 0
	if figure.is_in_group("enemy"):
		figure.remove_from_group("enemy")
	# body origin is its centre; put its feet on the holder origin
	figure.position = Vector2(0, -figure.body_size.y * 0.5)
	# a stand-in "player" for the eyes to follow (to_player() reads it)
	_look = Node2D.new()
	_holder.add_child(_look)
	figure._player = _look

	_sprite = Sprite3D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if blend else SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_sprite.offset = Vector2(0, size * 0.5 - feet_margin)
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)


func _process(delta: float) -> void:
	if figure == null:
		return
	figure.time += delta
	figure.facing = facing
	if figure.art:
		figure.art.scale.x = facing


## Points the eyes at a world position (right = +X, up = away from camera).
func look_at_point(world_pos: Vector3) -> void:
	if _look == null:
		return
	var d := world_pos - global_position
	_look.position = figure.position + Vector2(d.x, -d.z - d.y) * 30.0


## White hit flash, like the platformer's.
func flash() -> void:
	if figure and figure.art:
		figure.art.modulate = Color(4, 4, 4)
		create_tween().tween_property(figure.art, "modulate", Color.WHITE, 0.15)


func set_alpha(a: float) -> void:
	if _sprite:
		_sprite.modulate.a = a
