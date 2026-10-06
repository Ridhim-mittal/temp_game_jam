@tool
extends Node3D
## A drawn bridge: a pencil sketch of a walkway (pale dashed ghost planks you
## fall through) that Vesper inks in, as in the 2D Sketchbook. Standing at
## its end or on it, he holds the Ember up (Flash / right click, see
## clearing_player.gd) and ink runs out from his feet along the planks, up
## to `ink_reach` per hold, each plank costing `ink_cost` Ember fuel. Inked
## planks stay for good. Nothing forms on its own.
## With `ink_only` off it follows the old light rule instead: each plank is
## solid only while some light reaches it, flickers for `warn_time` before
## vanishing, and never re-solidifies inside the player.
## The bridge runs from this node along local -Z for `length`; its side
## rails are always solid, so you only fall through missing planks.
## Inked, each plank is a piece of old gutter (gutter_strip.gd: dark,
## cracked, ragged, between broken ink kerbs); the rails are leaning iron
## posts with spear tips and a sagging iron bar (`wood` tints the iron).

const Toon = preload("res://scripts/clearing/toon.gd")
const Light = preload("res://scripts/world25/light.gd")
const Fx = preload("res://scripts/clearing/clearing_fx.gd")
const ScreenAnchor = preload("res://scripts/clearing/screen_anchor.gd")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const GHOST_SHADER = preload("res://shaders/world25/drawn_ghost.gdshader")
const GutterStrip = preload("res://scripts/world25/gutter_strip.gd")
const INK := Color(0.07, 0.04, 0.11)
const IRON := Color(0.17, 0.16, 0.19)

@export var length := 8.0:
	set(v):
		length = v
		_rebuild()
@export var width := 3.0:
	set(v):
		width = v
		_rebuild()
@export var plank := 1.0:
	set(v):
		plank = v
		_rebuild()
@export var wood := Color(0.62, 0.42, 0.3):
	set(v):
		wood = v
		_rebuild()
## Seconds a plank flickers after losing light before it vanishes.
@export var warn_time := 0.3
## Show every plank solid in the editor (to place the bridge).
@export var preview_solid := false:
	set(v):
		preview_solid = v
		_rebuild()
## Planks are made only by inking (hold right click by the bridge). Off: the old
## light rule (solid wherever light reaches, gone when it leaves).
@export var ink_only := true
## How far along the bridge one hold of right click can ink, from Vesper's feet.
@export var ink_reach := 5.0
## How fast the ink runs out along the planks, units a second.
@export var ink_speed := 6.0
## Ember fuel each inked plank costs.
@export var ink_cost := 3.0

enum { SOLID, WARN, GHOST }

var _planks: Array = []  # [{shape, solid, ghost, state, timer, center, half, t, inked}]
var _player: Node3D
var _front := 0.0  # how far the ink has run from Vesper during this hold
var _hold := 0.0  # > 0 while Vesper keeps inking (ink() refreshes it)
var _anchor: Node2D  # the "HOLD RIGHT CLICK" prompt


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("drawn_bridge")  # clearing_player.gd finds bridges to ink here
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var root := Toon.fresh_root(self)
	_planks.clear()
	var n := maxi(int(round(length / plank)), 1)
	var step := length / n
	var size := Vector3(width, 0.3, step * 0.94)
	var ghost_mat := ShaderMaterial.new()
	ghost_mat.shader = GHOST_SHADER
	ghost_mat.set_shader_parameter("half_size", size * 0.5)
	for i in n:
		var center := Vector3(0, -0.15, -(i + 0.5) * step)
		# a piece of gutter, centred on the plank so it can pop in round it
		var solid := Node3D.new()
		solid.position = Vector3(0, 0, center.z)
		root.add_child(solid)
		GutterStrip.section(solid, step * 0.48, -step * 0.48, width, i * 3 + int(length))
		var ghost := MeshInstance3D.new()
		ghost.mesh = Toon.box(size)
		ghost.material_override = ghost_mat
		ghost.position = center
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ghost)
		var body: StaticBody3D = null
		var shape: CollisionShape3D = null
		if not Engine.is_editor_hint():
			body = Toon.collider(root, Toon.box_shape(Vector3(width, 0.3, step)), center)
			body.add_to_group("drawn")
			shape = body.get_child(0)
		var show_solid := preview_solid and Engine.is_editor_hint()
		solid.visible = show_solid
		ghost.visible = not show_solid
		if shape:
			shape.disabled = true
		_planks.append({"shape": shape, "solid": solid, "ghost": ghost, "state": GHOST, "timer": 0.0,
			"center": center, "half": Vector3(width * 0.5, 0.6, step * 0.5), "t": (i + 0.5) * step, "inked": false})
	# rails on both sides, always solid: leaning iron posts with spear tips,
	# an iron bar sagging between them
	var iron := IRON.lerp(wood, 0.12)
	for side in [-1, 1]:
		var x: float = side * (width * 0.5 + 0.12)
		for k in n + 1:
			var at := Vector3(x, -0.25, -k * step)
			var lean := Vector3(4.0 * sin(k * 2.1), 0, side * (3.0 + 4.0 * absf(sin(k * 1.3))))
			Toon.part(root, Toon.box(Vector3(0.07, 1.0, 0.07)), iron, at + Vector3(0, 0.5, 0), lean, {"outline": 0.015})
			Toon.part(root, Toon.prism(Vector3(0.14, 0.2, 0.07)), iron.darkened(0.2), at + Vector3(0, 1.08, 0), lean, {"outline": 0.01})
		for k in n:
			var a := Vector3(x, 0.5, -k * step)
			var b := Vector3(x, 0.5 - (0.08 if k % 2 == 0 else 0.15), -(k + 1) * step)
			Toon.part(root, Toon.box(Vector3(0.04, 0.04, step * 1.01)), iron.darkened(0.1), (a + b) * 0.5,
				Vector3(rad_to_deg(atan2(b.y - a.y, step)), 0, 0), {"outline": 0.0})
		if not Engine.is_editor_hint():
			Toon.collider(root, Toon.box_shape(Vector3(0.3, 3.0, length)), Vector3(x, 1.5, -length * 0.5))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_player = get_tree().get_first_node_in_group("player")
	if ink_only:
		_hold -= delta
		if _hold <= 0.0:
			_front = 0.0  # each hold starts again from Vesper's feet
		_update_prompt()
		return
	for p in _planks:
		var lit := Light.is_lit(get_tree(), to_global(p.center))
		match p.state:
			GHOST:
				if lit and not _player_inside(p):
					_set_state(p, SOLID)
			SOLID:
				if not lit:
					_set_state(p, WARN)
					p.timer = warn_time
			WARN:
				if lit:
					_set_state(p, SOLID)
				else:
					p.timer -= delta
					# flicker between solid and ghost as a warning
					var on := fmod(p.timer, 0.08) < 0.04
					p.solid.visible = on
					p.ghost.visible = not on
					if p.timer <= 0.0:
						_set_state(p, GHOST)


func _set_state(p: Dictionary, state: int) -> void:
	p.state = state
	var solid := state != GHOST
	p.solid.visible = solid
	p.ghost.visible = not solid
	p.shape.set_deferred("disabled", not solid)


## Safe re-solidify: never close a plank around the player's feet.
func _player_inside(p: Dictionary) -> bool:
	if _player == null:
		return false
	var local: Vector3 = to_local(_player.global_position) - p.center
	return absf(local.x) < p.half.x and absf(local.z) < p.half.z and local.y < 0.0 and local.y > -p.half.y * 3.0


# ------------------------------------------------------------------ inking

## Distance along the bridge of `pos` (0 at this node, `length` at the far
## end), clamped to the bridge.
func _along(pos: Vector3) -> float:
	return clampf(-to_local(pos).z, 0.0, length)


## True if Vesper at `pos` can ink here: he's at an end of the bridge or on
## it, and a plank within ink_reach is still a sketch.
func can_ink(pos: Vector3) -> bool:
	if not ink_only or Engine.is_editor_hint():
		return false
	var l := to_local(pos)
	if absf(l.x) > width * 0.5 + 1.5 or absf(l.y) > 2.0 or -l.z < -2.5 or -l.z > length + 2.5:
		return false
	return _sketch_within(_along(pos)) != null


## The nearest sketched (uninked) plank within ink_reach of `t`, or null.
func _sketch_within(t: float) -> Variant:
	var best: Variant = null
	var best_d := ink_reach
	for p in _planks:
		var d: float = absf(p.t - t) - p.half.z
		if not p.inked and d <= best_d:
			best = p
			best_d = d
	return best


## One physics tick of Vesper (at `pos`) holding the Ember up: the ink runs
## out from his feet both ways along the bridge, inking each plank it
## reaches for `ink_cost` of `player`'s fuel. Returns false when there's
## nothing left to ink within reach, or no fuel for the next plank.
func ink(pos: Vector3, delta: float, player: Node) -> bool:
	var t := _along(pos)
	_hold = 0.15
	_front = minf(_front + ink_speed * delta, ink_reach)
	for p in _planks:
		if p.inked or absf(p.t - t) - p.half.z > _front:
			continue
		if player.fuel < ink_cost:
			return false
		player.add_fuel(-ink_cost)
		_ink_plank(p)
	return _sketch_within(t) != null and player.fuel >= ink_cost


func _ink_plank(p: Dictionary) -> void:
	p.inked = true
	_set_state(p, SOLID)
	# the plank inks in from a flat line, with a splash of ink and sparks
	p.solid.scale = Vector3(1.0, 0.15, 0.6)
	create_tween().tween_property(p.solid, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var at := to_global(p.center) + Vector3(0, 0.2, 0)
	Fx.burst(get_tree(), at, INK, 8, 2.6)
	Fx.burst(get_tree(), at, Color(1.0, 0.7, 0.3), 4, 2.0)


## True once every plank is inked.
func finished() -> bool:
	for p in _planks:
		if not p.inked:
			return false
	return true


## "HOLD RIGHT CLICK  INK" over the next sketched plank while Vesper could ink it.
func _update_prompt() -> void:
	var on := false
	var at := Vector3.ZERO
	if _player and not _player.dead and _player.is_on_floor() and not ("_inking" in _player and _player._inking != null) \
			and can_ink(_player.global_position):
		var p = _sketch_within(_along(_player.global_position))
		if p:
			on = true
			at = to_global(p.center) + Vector3(0, 1.3, 0)
	if on and _anchor == null:
		var ui := get_tree().current_scene.get_node_or_null("UI")
		if ui == null:
			return
		_anchor = ScreenAnchor.new()
		var label := Label.new()
		label.text = _prompt_text()
		label.add_theme_font_override("font", TITLE_FONT)
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
		label.add_theme_constant_override("outline_size", 10)
		_anchor.add_child(label)
		ui.add_child(_anchor)
		label.position = -label.get_minimum_size() * Vector2(0.5, 1.0)
	elif on and _anchor != null and _anchor.get_child_count() > 0 and _anchor.get_child(0).text != _prompt_text():
		var label: Label = _anchor.get_child(0)
		label.text = _prompt_text()  # switched to / from a pad
		label.position = -label.get_minimum_size() * Vector2(0.5, 1.0)
	elif not on and _anchor != null:
		_anchor.queue_free()
		_anchor = null
	if _anchor:
		_anchor.world_position = at


## Number of planks solid right now (tests and puzzles).
func solid_count() -> int:
	var c := 0
	for p in _planks:
		if p.state != GHOST:
			c += 1
	return c


## The prompt in the player's own buttons (InputSetup isn't loaded in the editor).
func _prompt_text() -> String:
	var ins := get_node_or_null("/root/InputSetup")
	var text := "HOLD RIGHT CLICK  INK THE BRIDGE"
	return ins.words(text) if ins else text
