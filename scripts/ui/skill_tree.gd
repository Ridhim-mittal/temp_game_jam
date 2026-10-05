extends Control
## Skill tree overlay (pause menu -> Skill Tree, or the shrine in the hub).
## Three branches (Blade, Ember, Ink), each a chain of four skills bought
## with Ink Points. A/D pick a branch, W/S a skill, Enter / click learns it,
## Esc closes. Skills are defined in scripts/core/catalog.gd and take effect
## the next time Vesper spawns (entering a room), or right away via
## `changed` -> room.gd refreshes the player.

signal closed

const Catalog = preload("res://scripts/core/catalog.gd")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.08)
const PAPER := Color(0.97, 0.95, 0.9)
const RED := Color(0.9, 0.22, 0.16)
const DIM := Color(0.45, 0.43, 0.48)
const GOLD := Color(1.0, 0.82, 0.25)

var _col := 0
var _tier := 0
var _time := 0.0
var _flash := {}  # skill id -> 1..0 burst after learning
var _hits := {}  # skill id -> Rect2 for the mouse


var _sfx_sel := Vector2i.ZERO


func _ready() -> void:
	Sfx.play("menu_open")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_time += delta
	if Vector2i(_col, _tier) != _sfx_sel:
		_sfx_sel = Vector2i(_col, _tier)
		Sfx.play("menu_hover")
	for k in _flash.keys():
		_flash[k] -= delta * 2.0
		if _flash[k] <= 0.0:
			_flash.erase(k)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_close()
			KEY_A, KEY_LEFT:
				_col = (_col + 2) % 3
			KEY_D, KEY_RIGHT:
				_col = (_col + 1) % 3
			KEY_W, KEY_UP:
				_tier = maxi(_tier - 1, 0)
			KEY_S, KEY_DOWN:
				_tier = mini(_tier + 1, 3)
			KEY_ENTER, KEY_SPACE, KEY_E:
				_learn(_selected())
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not ("position" in event):
		return
	for id in _hits:
		if _hits[id].has_point(event.position):
			var s: Dictionary = Catalog.SKILLS[id]
			_tier = s.tier
			_col = _branch_index(s.branch)
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_learn(id)


func _close() -> void:
	Sfx.play("menu_close")
	closed.emit()
	queue_free()


func _branch_index(branch: String) -> int:
	for i in Catalog.BRANCHES.size():
		if Catalog.BRANCHES[i][0] == branch:
			return i
	return 0


func _skill_at(col: int, tier: int) -> String:
	for id in Catalog.SKILLS:
		var s: Dictionary = Catalog.SKILLS[id]
		if s.branch == Catalog.BRANCHES[col][0] and s.tier == tier:
			return id
	return ""


func _selected() -> String:
	return _skill_at(_col, _tier)


func _learn(id: String) -> void:
	Sfx.play("menu_select")
	var profile := get_node_or_null("/root/Profile")
	if profile and profile.unlock_skill(id):
		_flash[id] = 1.0


func _node_pos(col: int, tier: int) -> Vector2:
	return Vector2(size.x * (0.22 + 0.28 * col), 250.0 + tier * 102.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.95))
	var profile := get_node_or_null("/root/Profile")
	var points: int = profile.skill_points if profile else 0
	draw_string_outline(TITLE_FONT, Vector2(66, 92), "SKILL TREE", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 12, Color(RED, 0.9))
	draw_string(TITLE_FONT, Vector2(60, 86), "SKILL TREE", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, PAPER)
	var pts := "INK POINTS  %d" % points
	var pw := TITLE_FONT.get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(TITLE_FONT, Vector2(size.x - pw - 60, 86), pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 330, 112), "Earned by clearing rooms for the first time.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(PAPER, 0.6))
	_hits.clear()
	for col in 3:
		var b: Array = Catalog.BRANCHES[col]
		var head := _node_pos(col, 0) + Vector2(0, -78)
		var hw := TITLE_FONT.get_string_size(b[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		draw_string(TITLE_FONT, head - Vector2(hw * 0.5, 0), b[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, b[2])
		for tier in 4:
			var id := _skill_at(col, tier)
			if id == "":
				continue
			var p := _node_pos(col, tier)
			if tier > 0:
				var prev_learned: bool = profile != null and profile.skills.has(_skill_at(col, tier - 1))
				draw_line(_node_pos(col, tier - 1) + Vector2(0, 36), p - Vector2(0, 36), b[2] if prev_learned else DIM, 4.0)
			_draw_node(id, p, b[2], profile, col == _col and tier == _tier)
			_hits[id] = Rect2(p - Vector2(40, 40), Vector2(80, 80))
	_draw_info(profile)


func _draw_node(id: String, p: Vector2, color: Color, profile: Node, selected: bool) -> void:
	var s: Dictionary = Catalog.SKILLS[id]
	var learned: bool = profile != null and profile.skills.has(id)
	var can: bool = profile != null and profile.can_unlock(id)
	var r := 32.0
	if selected:
		draw_arc(p, r + 9.0, 0, TAU, 32, PAPER, 3.0)
	if can and not learned:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		draw_arc(p, r + 4.0 + pulse * 3.0, 0, TAU, 32, Color(GOLD, 0.6 + 0.4 * pulse), 3.0)
	draw_circle(p, r + 3.0, INK)
	draw_circle(p, r, color if learned else Color(0.14, 0.12, 0.17))
	draw_arc(p, r, 0, TAU, 32, color if (learned or can) else DIM, 3.0)
	_draw_icon(s.branch, p, INK if learned else (color if can else DIM))
	var burst: float = _flash.get(id, 0.0)
	if burst > 0.0:
		draw_arc(p, r + (1.0 - burst) * 40.0, 0, TAU, 32, Color(GOLD, burst), 4.0)
	var nw := TITLE_FONT.get_string_size(s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(TITLE_FONT, p + Vector2(r + 14, 8), s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		PAPER if (learned or selected) else Color(PAPER, 0.55))
	if not learned:
		draw_string(TITLE_FONT, p + Vector2(r + 14, 30), "%d PT" % s.cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(GOLD, 0.8))


func _draw_icon(branch: String, c: Vector2, col: Color) -> void:
	match branch:
		"blade":
			draw_line(c + Vector2(-12, 12), c + Vector2(12, -12), col, 5.0)
			draw_line(c + Vector2(-8, 2), c + Vector2(-2, 8), col, 4.0)
		"ember":
			var flame := PackedVector2Array()
			for k in 9:
				var a := PI * 0.5 + (k / 8.0 - 0.5) * PI * 1.6
				flame.append(c + Vector2(cos(a), sin(a)) * 10.0 + Vector2(0, 4))
			flame.append(c + Vector2(0, -16))
			draw_colored_polygon(flame, col)
		_:
			var drop := PackedVector2Array([c + Vector2(0, -16)])
			for k in 13:
				var a := -PI * 0.15 + PI * 1.3 * k / 12.0
				drop.append(c + Vector2(cos(a), sin(a)) * 10.0 + Vector2(0, 3))
			draw_colored_polygon(drop, col)


func _draw_info(profile: Node) -> void:
	var id := _selected()
	if id == "":
		return
	var s: Dictionary = Catalog.SKILLS[id]
	var box := Rect2(60, size.y - 112, size.x - 120, 76)
	draw_rect(box, Color(0.1, 0.08, 0.12))
	draw_rect(box, RED, false, 2.0)
	draw_string(TITLE_FONT, box.position + Vector2(18, 32), s.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, PAPER)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(18, 60), s.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.85))
	var status := ""
	var col := GOLD
	if profile and profile.skills.has(id):
		status = "LEARNED"
		col = Color(0.55, 1.0, 0.65)
	elif profile and profile.can_unlock(id):
		status = "ENTER: LEARN (%d)" % s.cost
	elif s.tier > 0 and profile and not profile.skills.has(_skill_at(_col, s.tier - 1)):
		status = "LEARN THE ONE ABOVE FIRST"
		col = DIM
	else:
		status = "NEEDS %d INK POINT%s" % [s.cost, "" if s.cost == 1 else "S"]
		col = DIM
	var sw := TITLE_FONT.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(TITLE_FONT, Vector2(box.end.x - sw - 18, box.position.y + 32), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
