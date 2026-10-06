extends RefCounted
## Vesper's health, the same in 2D (hud.gd) and 2.5D (clearing_hud.gd): a
## row of little ink bottles. Health is counted in half bottles (2 = one
## full bottle; six bottles = 12), so small monsters can cost half a bottle.
## Each bottle has a face: happy and blushing when full, worried with a sweat
## drop at half, X eyes, popped cork and a crack when empty. A bottle shakes
## and splashes ink when it loses ink, pops and sparkles when it refills, and
## the last one trembles when you're low.
##
##   var bottles := InkBottles.new()
##   bottles.set_health(cur, max)   # on health_changed (half bottles)
##   bottles.update(delta)          # every frame
##   bottles.draw(self, origin)     # in _draw(): origin = centre of the first bottle

const INK := Color(0.05, 0.03, 0.1)
const GLASS := Color(0.84, 0.91, 1.0, 0.92)
const GLASS_EMPTY := Color(0.72, 0.76, 0.84, 0.85)
const INK_FILL := Color(0.17, 0.1, 0.45)
const INK_TOP := Color(0.36, 0.27, 0.78)
const CORK := Color(0.8, 0.58, 0.35)
const RIBBON := Color(0.92, 0.3, 0.2)
const FACE := Color(0.98, 0.96, 0.9)
const BLUSH := Color(1.0, 0.5, 0.6, 0.7)
const SWEAT := Color(0.55, 0.85, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)
## Distance between bottles (px at scale 1).
const STEP := 40.0

var health := 12.0
var max_health := 12.0
var _time := 0.0
var _shown: Array[float] = []   # each bottle's ink level, easing toward the real one
var _hurt: Array[float] = []    # 1 -> 0 after it lost ink
var _healed: Array[float] = []  # 1 -> 0 after it gained ink


func count() -> int:
	return int(ceil(max_health / 2.0))


func fill_of(i: int) -> float:
	return clampf((health - i * 2.0) / 2.0, 0.0, 1.0)


func set_health(cur: float, max_hp: float) -> void:
	var old := []
	for i in count():
		old.append(fill_of(i))
	var first := _shown.is_empty()
	health = cur
	max_health = max_hp
	var n := count()
	_shown.resize(n)
	_hurt.resize(n)
	_healed.resize(n)
	for i in n:
		var f := fill_of(i)
		if first or i >= old.size():
			_shown[i] = f
			continue
		if f < old[i]:
			_hurt[i] = 1.0
		elif f > old[i]:
			_healed[i] = 1.0


func update(delta: float) -> void:
	_time += delta
	for i in _shown.size():
		_shown[i] = move_toward(_shown[i], fill_of(i), delta * 3.0)
		_hurt[i] = maxf(_hurt[i] - delta * 1.6, 0.0)
		_healed[i] = maxf(_healed[i] - delta * 1.8, 0.0)


## The last bottle with ink in it trembles when there's a bottle or less left.
func _nervous(i: int) -> bool:
	return health > 0.0 and health <= 2.0 and i == int(ceil(health / 2.0)) - 1


func draw(ci: CanvasItem, origin: Vector2, scale := 1.0) -> void:
	for i in count():
		var c := origin + Vector2(STEP * scale * i, 0)
		_draw_bottle(ci, c, i, scale)


func _draw_bottle(ci: CanvasItem, c: Vector2, i: int, s: float) -> void:
	var fill := fill_of(i)
	var level: float = _shown[i] if i < _shown.size() else fill
	var hurt: float = _hurt[i] if i < _hurt.size() else 0.0
	var healed: float = _healed[i] if i < _healed.size() else 0.0
	var nervous := _nervous(i)
	var shake := Vector2(sin(_time * 63.0 + i), cos(_time * 51.0 + i * 2.0)) * 4.0 * hurt
	var rot := sin(i * 2.3) * 0.06 + sin(_time * 2.0 + i) * 0.025  # hand-inked, never quite level
	if nervous:
		rot += sin(_time * 17.0) * 0.1
		shake += Vector2(sin(_time * 29.0), 0) * 1.2
	var pop := sin(clampf(healed, 0.0, 1.0) * PI) * 0.28
	var squash := Vector2(1.0 + pop * 0.6 - hurt * 0.1, 1.0 + pop - hurt * 0.08 * sin(_time * 40.0))
	var bob := sin(_time * 2.4 + i * 0.9) * 1.2
	var xf := Transform2D(rot, squash * s, 0.0, c + shake + Vector2(0, bob))
	# shapes, in the bottle's own space (about 30 x 44, the middle of the body at 0,0)
	var body := _round_rect(Rect2(-15, -10, 30, 28), 10.0)
	var neck := PackedVector2Array([Vector2(-6.5, -17), Vector2(6.5, -17), Vector2(6.5, -8), Vector2(-6.5, -8)])
	var merged := Geometry2D.merge_polygons(body, neck)
	var glass: PackedVector2Array = merged[0] if not merged.is_empty() else body
	# shadow, ink outline, glass
	var shadow := Transform2D(rot, squash * s, 0.0, c + shake + Vector2(3, 4 + bob))
	ci.draw_colored_polygon(shadow * _offset(glass, 2.5), Color(0, 0, 0, 0.4))
	ci.draw_colored_polygon(xf * _offset(glass, 2.5), INK)
	ci.draw_colored_polygon(xf * glass, GLASS if fill > 0.0 else GLASS_EMPTY)
	# the ink inside, its surface sloshing
	if level > 0.01:
		var top := lerpf(18.0, -9.0, level)
		var wave := PackedVector2Array()
		var amp := 1.2 + 2.5 * hurt + (0.8 if nervous else 0.0)
		for k in 13:
			var x := lerpf(-17.0, 17.0, k / 12.0)
			wave.append(Vector2(x, top + sin(x * 0.35 + _time * 5.0 + i) * amp))
		wave.append(Vector2(17, 20))
		wave.append(Vector2(-17, 20))
		for poly in Geometry2D.intersect_polygons(_offset(body, -1.5), wave):
			ci.draw_colored_polygon(xf * poly, INK_FILL.lerp(Color(0.5, 0.4, 0.95), healed * 0.5))
		var surf := PackedVector2Array()
		for k in 13:
			var x2 := lerpf(-12.0, 12.0, k / 12.0)
			surf.append(xf * Vector2(x2, top + 1.0 + sin(x2 * 0.35 + _time * 5.0 + i) * amp))
		ci.draw_polyline(surf, INK_TOP, 2.0 * s, true)
		if level > 0.9:  # bubbles rising in a full bottle
			for b in 2:
				var ph := fmod(_time * 0.6 + b * 0.5 + i * 0.37, 1.0)
				ci.draw_circle(xf * Vector2(-6.0 + b * 11.0, lerpf(15.0, top + 3.0, ph)), 1.6 * s, Color(INK_TOP, 0.9 * (1.0 - ph)))
	# cork (popped off and lying crooked when empty), red ribbon round the neck
	var cork_xf := xf
	if fill <= 0.0:
		cork_xf = xf * Transform2D(0.7, Vector2(9, -6))
	var cork := _round_rect(Rect2(-7.5, -25, 15, 10), 3.0)
	ci.draw_colored_polygon(cork_xf * _offset(cork, 2.0), INK)
	ci.draw_colored_polygon(cork_xf * cork, CORK)
	ci.draw_line(cork_xf * Vector2(-4, -22), cork_xf * Vector2(4, -22), CORK.darkened(0.25), 1.5 * s)
	ci.draw_colored_polygon(xf * PackedVector2Array([Vector2(-7, -13), Vector2(7, -13), Vector2(7, -10), Vector2(-7, -10)]), RIBBON)
	ci.draw_colored_polygon(xf * PackedVector2Array([Vector2(7, -11.5), Vector2(12, -15), Vector2(12, -8)]), RIBBON)  # the bow
	ci.draw_colored_polygon(xf * PackedVector2Array([Vector2(7, -11.5), Vector2(11, -6), Vector2(5, -7)]), RIBBON.darkened(0.15))
	# the face
	var on_ink := level > 0.55  # white face on the ink, ink face on bare glass
	var fc := FACE if on_ink else INK
	if fill >= 1.0:
		# happy: closed smiling eyes, a grin, blush
		ci.draw_arc(xf * Vector2(-6, 4), 3.2 * s, PI + 0.3, TAU - 0.3, 8, fc, 2.0 * s)
		ci.draw_arc(xf * Vector2(6, 4), 3.2 * s, PI + 0.3, TAU - 0.3, 8, fc, 2.0 * s)
		ci.draw_arc(xf * Vector2(0, 8), 4.0 * s, 0.35, PI - 0.35, 10, fc, 2.0 * s)
		ci.draw_circle(xf * Vector2(-10, 9), 2.4 * s, BLUSH)
		ci.draw_circle(xf * Vector2(10, 9), 2.4 * s, BLUSH)
	elif fill > 0.0:
		# worried: big round eyes, a wobbly mouth, a sweat drop
		for ex in [-6.0, 6.0]:
			ci.draw_circle(xf * Vector2(ex, 3), 2.8 * s, fc)
			ci.draw_circle(xf * Vector2(ex + 0.8, 2.2), 0.9 * s, INK if on_ink else FACE)
		var mouth := PackedVector2Array()
		for k in 7:
			mouth.append(xf * Vector2(-4.0 + k * 1.33, 10.0 + (1.0 if k % 2 == 0 else -1.0)))
		ci.draw_polyline(mouth, fc, 1.6 * s)
		var drop_y := -8.0 + fmod(_time * 6.0 + i, 6.0)
		var d := xf * Vector2(14, drop_y)
		ci.draw_circle(d, 2.4 * s, SWEAT)
		ci.draw_colored_polygon(PackedVector2Array([d + Vector2(-2.2, 0) * s, d + Vector2(0, -4.5) * s, d + Vector2(2.2, 0) * s]), SWEAT)
	else:
		# empty: X eyes, a frown, a crack in the glass
		for ex in [-6.0, 6.0]:
			ci.draw_line(xf * Vector2(ex - 2.5, 1.5), xf * Vector2(ex + 2.5, 6.5), INK, 2.0 * s)
			ci.draw_line(xf * Vector2(ex + 2.5, 1.5), xf * Vector2(ex - 2.5, 6.5), INK, 2.0 * s)
		ci.draw_arc(xf * Vector2(0, 14), 4.0 * s, PI + 0.4, TAU - 0.4, 10, INK, 2.0 * s)
		ci.draw_polyline(PackedVector2Array([xf * Vector2(9, -7), xf * Vector2(6, -2), xf * Vector2(10, 2), xf * Vector2(7, 7)]), Color(INK, 0.55), 1.4 * s)
	# glass shine
	ci.draw_line(xf * Vector2(-10, -4), xf * Vector2(-10, 9), Color(1, 1, 1, 0.65), 2.6 * s)
	ci.draw_circle(xf * Vector2(-10, 12.5), 1.4 * s, Color(1, 1, 1, 0.55))
	# lost ink splashing out of the neck; sparkles on a refill
	if hurt > 0.0:
		var k := 1.0 - hurt
		for m in 5:
			var dir := Vector2.from_angle(-PI * 0.5 + (m - 2) * 0.45)
			var p := Vector2(0, -18) + dir * (6.0 + 26.0 * k) + Vector2(0, 30.0 * k * k)
			ci.draw_circle(xf * p, (3.0 - 1.5 * k) * s, Color(INK_FILL, hurt))
	if healed > 0.0:
		for m in 4:
			var a := TAU * m / 4.0 + _time * 3.0
			var p2 := xf * (Vector2.from_angle(a) * (22.0 + 10.0 * (1.0 - healed)))
			ci.draw_line(p2 - Vector2(4, 0) * s, p2 + Vector2(4, 0) * s, Color(GOLD, healed), 2.0 * s)
			ci.draw_line(p2 - Vector2(0, 4) * s, p2 + Vector2(0, 4) * s, Color(GOLD, healed), 2.0 * s)


func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		for j in 7:
			pts.append(corners[k] + Vector2.from_angle(-PI * 0.5 + PI * 0.5 * k + PI * 0.5 * j / 6.0) * rad)
	return pts


func _offset(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := Geometry2D.offset_polygon(poly, by, Geometry2D.JOIN_ROUND)
	return out[0] if not out.is_empty() else poly
