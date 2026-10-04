extends RefCounted
## The rules of light for the 2D platformer (2D twin of scripts/world25/light.gd).
##  1. Light makes the drawn world real: sketch platforms (sketch_platform.gd)
##     are only solid where some light reaches them. Vesper's Ember, held
##     still, inks them in for good.
##  2. Monsters react to light (group "light", `lights(point)`): the X on a
##     Crossed-Out burns, Crumples unfold, Smudges surface, Scribbles flee.
##  3. Shadows count as darkness: lanterns with `casts_shadows` are blocked
##     by solid world (layer 1) between them and the point. A lit shadow
##     caster (shadow_caster.gd) throws a beam of solid shadow ink.
##
## Sources join the group DRAWN and implement `reaches(point) -> bool`;
## ones monsters react to also join "light" with `lights(point) -> bool`.
## Sources that can ink set `inks := true` and implement `inks_at(point)`.

const DRAWN := "drawn_light"
const MONSTER := "light"
const MASK_WORLD := 1
## Physics layer 5: sketch platforms and shadow ink. Bodies that should walk
## on them add this to their collision mask; light rays ignore it.
const LAYER_SKETCH := 16


static func reaches(tree: SceneTree, point: Vector2) -> bool:
	for l in tree.get_nodes_in_group(DRAWN):
		if l.reaches(point):
			return true
	return false


static func inks(tree: SceneTree, point: Vector2) -> bool:
	for l in tree.get_nodes_in_group(DRAWN):
		if "inks" in l and l.inks and l.inks_at(point):
			return true
	return false


## Rule 3: is the straight line from `from` to `to` blocked by solid world?
static func blocked(world: World2D, from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, MASK_WORLD, exclude)
	q.hit_from_inside = false
	return not world.direct_space_state.intersect_ray(q).is_empty()


## Soft additive glow disc: bright core fading to nothing at `radius`.
## Draw it on a CanvasItem whose material blends ADD.
static func draw_glow(c: CanvasItem, at: Vector2, radius: float, col: Color, n := 40) -> void:
	var pts := PackedVector2Array([at])
	var cols := PackedColorArray([col])
	var idx := PackedInt32Array()
	for i in n:
		pts.append(at + Vector2.from_angle(TAU * i / n) * radius)
		cols.append(Color(col, 0.0))
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), idx, pts, cols)
