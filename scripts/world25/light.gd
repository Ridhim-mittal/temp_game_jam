extends RefCounted
## The design doc's three rules of light, for the 2.5D world.
##  1. Light makes the drawn world real: drawn bridges (drawn_bridge.gd) are
##     only solid where some light reaches them, the Ember included.
##  2. The Writer's light erases crossed-out things: monsters react to
##     "monster light" (braziers, the searchlight, a Flash), not to the
##     Ember's steady glow.
##  3. Shadows count as darkness: lights with `casts_shadows` are blocked by
##     solid props between them and the point.
##
## A light source is any node in the group "light_3d" with
##   lights(point: Vector3) -> bool
## and optionally `monster_light := true/false` (default true).

const GROUP := "light_3d"


## The first light reaching `point`, or null. `for_monsters` skips lights
## that only make things real (the Ember's glow).
static func light_at(tree: SceneTree, point: Vector3, for_monsters := false) -> Node:
	for l in tree.get_nodes_in_group(GROUP):
		if for_monsters and "monster_light" in l and not l.monster_light:
			continue
		if l.lights(point):
			return l
	return null


static func is_lit(tree: SceneTree, point: Vector3, for_monsters := false) -> bool:
	return light_at(tree, point, for_monsters) != null


## Rule 3: is the straight line from `from` to `to` blocked by something
## solid (pillars, graves, walls)? Ignores bodies listed in `exclude`.
static func blocked(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	return not world.direct_space_state.intersect_ray(q).is_empty()
