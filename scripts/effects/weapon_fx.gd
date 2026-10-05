extends RefCounted
## The 2D effects of the weapons' specials (player.gd; catalog.gd "special").
## Each is a Node2D spawned into the level:
##   Tornado      - the Corkscrew Nib's PEN-DRILL: an ink twister round Vesper
##   PrismArc     - the Prism Saber's BLINDING SWEEP: rainbow bands, fading
##   SlamRing     - the Brush Maul's INK SLAM: a ring of ink running out
##   QuillDart    - the Quill Rapier's QUILL VOLLEY: one flying quill (pierces)
##   LanternLight - the Lantern Flail's WHIRL: its light while it whirls
##                  (scripts/world/lights.gd: makes sketches solid, monsters
##                  react to it)

const INK := Color(0.05, 0.03, 0.1)
const RAINBOW := [Color(1.0, 0.35, 0.45), Color(1.0, 0.7, 0.3), Color(1.0, 0.95, 0.45), Color(0.5, 1.0, 0.6),
	Color(0.45, 0.75, 1.0), Color(0.7, 0.5, 1.0)]


## An ink twister spinning round its parent while `active`; fades after.
class Tornado extends Node2D:
	var radius := 150.0
	var active := true
	var _t := 0.0
	var _a := 1.0

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		_t += delta
		_a = move_toward(_a, 1.0 if active else 0.0, delta * (6.0 if active else 4.0))
		if not active and _a <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# spiral strokes wound round the centre, turning fast; faint far out
		for k in 7:
			var r := lerpf(26.0, radius, float(k) / 6.0)
			var start := -_t * (16.0 - k) + k * 1.3
			var pts := PackedVector2Array()
			for i in 13:
				var a := start + i * 0.3
				pts.append(Vector2(cos(a) * r, sin(a) * r * 0.42 - 20.0))
			var alpha := _a * lerpf(0.9, 0.25, float(k) / 6.0)
			draw_polyline(pts, Color(INK, alpha), lerpf(5.0, 2.0, float(k) / 6.0))
			draw_polyline(pts, Color(0.85, 0.88, 0.95, alpha * 0.6), 1.0)


## Rainbow bands sweeping out in front (facing `direction`), then fading.
class PrismArc extends Node2D:
	var radius := 200.0
	var direction := 1.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 11
		scale = Vector2(direction, 1.0)

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.45:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var grow := 1.0 - pow(1.0 - clampf(_t / 0.12, 0.0, 1.0), 3.0)
		var fade := 1.0 - clampf((_t - 0.15) / 0.3, 0.0, 1.0)
		var base := radius * grow
		# an ink backing so the colours pop on any page, then the bands
		draw_arc(Vector2.ZERO, base * 0.77, -1.8, 1.8, 32, Color(INK, 0.8 * fade), base * 0.5 + 8.0)
		for k in RAINBOW.size():
			var r := base * (0.55 + 0.08 * k)
			draw_arc(Vector2.ZERO, r, -1.75, 1.75, 32, Color(RAINBOW[k], fade), base * 0.075)
		draw_arc(Vector2.ZERO, base * 1.02, -1.75, 1.75, 32, Color(1, 1, 1, fade), 4.0)


## A ring of ink running out along the ground from the slam.
class SlamRing extends Node2D:
	var radius := 170.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / 0.25, 0.0, 1.0)
		var r := radius * (1.0 - pow(1.0 - k, 3.0))
		var fade := 1.0 - clampf((_t - 0.2) / 0.2, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.22))
		draw_polyline(pts, Color(INK, fade), 14.0 * (1.0 - k) + 6.0)
		draw_polyline(pts, Color(1.0, 0.95, 0.8, fade), 7.0 * (1.0 - k) + 2.0)
		draw_polyline(pts, Color(1.0, 0.35, 0.35, fade), 2.0)
		# ink thrown up either side of the ring
		for side in [-1.0, 1.0]:
			for j in 4:
				var x: float = side * r * (0.45 + j * 0.17)
				var c := Vector2(x, -12.0 - 46.0 * k * (1.0 - j * 0.2))
				draw_circle(c, 8.0 - j * 1.5, Color(INK, fade))
				draw_circle(c + Vector2(-2, -2), 2.5, Color(1.0, 0.95, 0.8, fade))


## One quill of the volley: flies along `velocity`, hits each monster once
## (pierces), stops at walls.
class QuillDart extends Node2D:
	var velocity := Vector2(900, 0)
	var max_range := 620.0
	var damage := 1
	var color := Color(0.55, 0.85, 1.0)
	var _travelled := 0.0
	var _hit: Array = []

	func _ready() -> void:
		z_index = 10
		rotation = velocity.angle()

	func _physics_process(delta: float) -> void:
		var step := velocity * delta
		var space := get_world_2d().direct_space_state
		var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
		if not space.intersect_ray(ray).is_empty():
			queue_free()
			return
		global_position += step
		_travelled += step.length()
		var shape := CircleShape2D.new()
		shape.radius = 14.0
		var params := PhysicsShapeQueryParameters2D.new()
		params.shape = shape
		params.transform = Transform2D(0.0, global_position)
		params.collision_mask = 4
		params.collide_with_areas = true
		for r in space.intersect_shape(params, 8):
			var t: Object = r.collider
			if t == null or t in _hit or not t.has_method("take_hit") or ("dead" in t and t.dead):
				continue
			_hit.append(t)
			t.take_hit(damage, Vector2(signf(velocity.x), 0.0), global_position - velocity.normalized() * 20.0)
		if _travelled >= max_range:
			queue_free()

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(-6, -5), Vector2(10, -3), Vector2(14, 0),
			Vector2(10, 2), Vector2(-6, 4)]), color.lerp(Color.WHITE, 0.6))
		draw_line(Vector2(-20, 0), Vector2(16, 0), Color(0.97, 0.95, 0.88), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(14, -2), Vector2(22, 0), Vector2(14, 2)]), Color(0.9, 0.92, 0.98))
		draw_line(Vector2(-30, 0), Vector2(-20, 0), Color(color, 0.5), 2.0)


## The whirling lantern's light, centred on `follow` (Vesper): sketches in
## it are solid and monsters see it as light.
class LanternLight extends Node2D:
	var follow: Node2D
	var radius := 160.0

	func _ready() -> void:
		z_index = -1
		add_to_group("drawn_light")
		add_to_group("light")

	func _process(_delta: float) -> void:
		if is_instance_valid(follow):
			global_position = follow.global_position + Vector2(0, -20)
		queue_redraw()

	func reaches(point: Vector2) -> bool:
		return global_position.distance_to(point) <= radius

	func lights(point: Vector2) -> bool:
		return reaches(point)

	func _draw() -> void:
		for k in 4:
			draw_circle(Vector2.ZERO, radius * (1.0 - k * 0.2), Color(1.0, 0.82, 0.4, 0.05))
