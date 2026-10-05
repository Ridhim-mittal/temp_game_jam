extends Control
## Quire's Curios: the shop overlay. Opens on B anywhere in the game (2D
## levels and the Gutter's rooms), from the 2.5D pause menu, and at Quire's
## stall in the Spine (shop_stall.gd). Paid in Lumen coins, the ones picked
## up in the 2D levels (Profile.lumens).
## Tabs: weapons, weapon upgrades, hats, scarves, cloaks and armor; a live
## preview of Vesper wearing what you're looking at (the 2D art, with the
## highlighted weapon). W/S pick, A/D switch tab, Enter / click buys (or
## equips what you own), Esc or B closes.
## Items live in scripts/core/catalog.gd; money and ownership in Profile.
##
##   Shop.open(tree)   # 2D levels (player.gd); the 2.5D rooms use
##                     # room.gd open_overlay("shop") instead

signal closed

const Catalog = preload("res://scripts/core/catalog.gd")
const PlayerVisual = preload("res://scripts/player/player_visual.gd")
const SwordScene = preload("res://scenes/player/sword.tscn")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const Coin = preload("res://scripts/world/coin.gd")
const TITLE_FONT = preload("res://assets/fonts/Bangers-Regular.ttf")
const INK := Color(0.05, 0.03, 0.08)
const PAPER := Color(0.97, 0.95, 0.9)
const RED := Color(0.9, 0.22, 0.16)
const NAVY := Color(0.16, 0.17, 0.3)
const DIM := Color(0.55, 0.53, 0.58)
const GOLD := Color(1.0, 0.82, 0.25)
const QUIPS := ["Quire's the name. Blades, hats, cloaks. All barely used.",
	"Coins from the bright pages spend just fine down here.",
	"That drill? Twisted it myself. Mind your fingers.",
	"The prism came off the Writer's own lamp. Shh.",
	"A new hat won't save you. It will help, though."]
const ROW_STEP := 52.0

var _tab := 0
var _row := 0
var _time := 0.0
var _rows: Array[Rect2] = []
var _tabs: Array[Rect2] = []
var _art: Node2D
var _sword: Node2D
var _message := ""
var _message_t := 0.0
var _quip := ""


## Opens the shop over a 2D level and pauses it; `on_closed` runs after.
static func open(tree: SceneTree, on_closed := Callable()) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 70
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var shop: Control = load("res://scripts/ui/shop.gd").new()
	layer.add_child(shop)
	tree.current_scene.add_child(layer)
	tree.paused = true
	shop.closed.connect(func():
		tree.paused = false
		layer.queue_free()
		if on_closed.is_valid():
			on_closed.call())
	return shop


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_quip = QUIPS.pick_random()
	# Vesper on a pedestal, wearing whatever is highlighted
	var group := CanvasGroup.new()
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	mat.set_shader_parameter("pop_color", PAPER)
	mat.set_shader_parameter("ink_width", 2.0)
	mat.set_shader_parameter("pop_width", 5.0)
	group.material = mat
	group.fit_margin = 16.0
	group.position = Vector2(960, 470)
	group.scale = Vector2(4.0, 4.0)
	add_child(group)
	_art = Node2D.new()
	_art.name = "Art"  # sword.gd looks for its sibling "Art"
	_art.set_script(PlayerVisual)
	group.add_child(_art)
	_sword = SwordScene.instantiate()
	group.add_child(_sword)
	_preview()


func _slot() -> String:
	return Catalog.SLOTS[_tab][0]


## The ids listed on the current tab (owned weapons on the upgrades tab).
func _items() -> Array:
	var profile := get_node_or_null("/root/Profile")
	var slot := _slot()
	var out := []
	for id in Catalog.ITEMS:
		var item: Dictionary = Catalog.ITEMS[id]
		if slot == "upgrade":
			if item.slot == "weapon" and profile and profile.owned.has(id):
				out.append(id)
		elif item.slot == slot and not (item.get("retired", false) and not (profile and profile.owned.has(id))):
			out.append(id)
	return out


func _process(delta: float) -> void:
	_time += delta
	_message_t = maxf(_message_t - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n := maxi(_items().size(), 1)
		match event.physical_keycode:
			KEY_ESCAPE, KEY_B:
				_close()
			KEY_W, KEY_UP:
				_row = (_row - 1 + n) % n
				_preview()
			KEY_S, KEY_DOWN:
				_row = (_row + 1) % n
				_preview()
			KEY_A, KEY_LEFT, KEY_Q:
				_set_tab((_tab + Catalog.SLOTS.size() - 1) % Catalog.SLOTS.size())
			KEY_D, KEY_RIGHT, KEY_E:
				_set_tab((_tab + 1) % Catalog.SLOTS.size())
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
				var items := _items()
				if _row < items.size():
					_use(items[_row])
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not ("position" in event):
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for i in _tabs.size():
		if _tabs[i].has_point(event.position) and click:
			_set_tab(i)
	var items := _items()
	for i in mini(_rows.size(), items.size()):
		if _rows[i].has_point(event.position):
			if _row != i:
				_row = i
				_preview()
			if click:
				_use(items[i])


func _set_tab(t: int) -> void:
	_tab = t
	_row = 0
	_preview()


func _close() -> void:
	closed.emit()
	queue_free()


func _use(id: String) -> void:
	var profile := get_node_or_null("/root/Profile")
	if profile == null:
		return
	var item: Dictionary = Catalog.ITEMS[id]
	if _slot() == "upgrade":
		var lvl: int = profile.upgrade_level(id)
		if lvl >= Catalog.UPGRADES.size():
			_say("%s is as good as it gets." % item.name)
		elif profile.buy_upgrade(id):
			_say("%s: %s!" % [item.name, Catalog.UPGRADES[lvl].name])
		else:
			_say("Not enough coins. The bright pages are full of them.")
	elif profile.owned.has(id):
		profile.equip(id)
		_say("Equipped %s." % item.name)
	elif profile.buy(id):
		_say("Bought %s! Pleasure doing business." % item.name)
	else:
		_say("Not enough coins. The bright pages are full of them.")
	_preview()


func _say(text: String) -> void:
	_message = text
	_message_t = 2.5


## Shows the highlighted item on Vesper, over what's equipped.
func _preview() -> void:
	var profile := get_node_or_null("/root/Profile")
	var look: Dictionary = profile.look() if profile else {}
	var items := _items()
	if _row < items.size():
		look.merge(Catalog.ITEMS[items[_row]].look, true)
	_art.scarf_color = look.get("scarf", _art.scarf_color)
	_art.mask_color = look.get("mask", _art.mask_color)
	_art.cloak_color = look.get("cloak", _art.cloak_color)
	_art.cloak_rim = look.get("cloak_rim", _art.cloak_rim)
	_art.hat_color = look.get("hat", _art.hat_color)
	_art.band_color = look.get("band", _art.band_color)
	_sword.cloak_color = look.get("cloak", _sword.cloak_color)
	_sword.blade_length = look.get("blade_length", _sword.blade_length)
	_sword.grip_color = look.get("grip", _sword.grip_color)
	_sword.style = look.get("weapon", "nib")
	# a little swing when looking at weapons
	if _slot() in ["weapon", "upgrade"] and _sword.has_method("swing"):
		_sword.swing(Vector2.RIGHT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.95))
	var profile := get_node_or_null("/root/Profile")
	# header: the shop's sign and Quire's line
	draw_string_outline(TITLE_FONT, Vector2(66, 82), "QUIRE'S CURIOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 12, Color(NAVY, 0.95))
	draw_string(TITLE_FONT, Vector2(60, 76), "QUIRE'S CURIOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(64, 108), "Quire: \"%s\"" % _quip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.7))
	# money
	var money := "%d" % (profile.lumens if profile else 0)
	var mw := TITLE_FONT.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	Coin.draw_coin(self, Vector2(size.x - mw - 92, 64), 17.0, _time * 2.0)
	draw_string(TITLE_FONT, Vector2(size.x - mw - 60, 78), money, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, GOLD)
	# tabs
	_tabs.clear()
	for i in Catalog.SLOTS.size():
		var r := Rect2(60 + i * 160, 132, 150, 42)
		_tabs.append(r)
		var on := i == _tab
		draw_rect(r, Color(RED, 0.9) if on else Color(0.12, 0.1, 0.14))
		draw_rect(r, RED, false, 2.0)
		var t: String = Catalog.SLOTS[i][1]
		var tw := TITLE_FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(TITLE_FONT, r.position + Vector2((r.size.x - tw) * 0.5, 30), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PAPER if on else DIM)
	# item list
	_rows.clear()
	var items := _items()
	if items.is_empty():
		draw_string(TITLE_FONT, Vector2(80, 230), "NOTHING HERE YET", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, DIM)
	for i in items.size():
		_draw_row(i, items[i], profile)
	# a flat pedestal under Vesper's feet
	var ped := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		ped.append(Vector2(960, 474) + Vector2(cos(a) * 130.0, sin(a) * 30.0))
	draw_colored_polygon(ped, Color(0.14, 0.11, 0.16))
	draw_polyline(ped + PackedVector2Array([ped[0]]), RED, 3.0)
	if _row < items.size():
		_draw_details(items[_row], profile)
	if _message_t > 0.0:
		var a := clampf(_message_t / 0.4, 0.0, 1.0)
		draw_string(TITLE_FONT, Vector2(680, 200), _message, HORIZONTAL_ALIGNMENT_LEFT, 560, 26, Color(GOLD, a))
	draw_string(TITLE_FONT, Vector2(60, size.y - 22), "W/S  CHOOSE     A/D  TAB     ENTER  BUY / EQUIP     ESC / B  LEAVE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)


func _draw_row(i: int, id: String, profile: Node) -> void:
	var item: Dictionary = Catalog.ITEMS[id]
	var r := Rect2(60, 190 + i * ROW_STEP, 560, ROW_STEP - 6)
	_rows.append(r)
	var focused := i == _row
	var bar := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end - Vector2(18, 0), r.position + Vector2(0, r.size.y)])
	draw_colored_polygon(bar, Color(RED, 0.85) if focused else Color(0.12, 0.1, 0.14))
	draw_polyline(bar + PackedVector2Array([bar[0]]), RED, 2.0)
	var swatch := _swatch(item)
	var x := 18.0
	if swatch.size() > 0:
		# the colours the outfit piece brings, in little ink-ringed dots
		for k in swatch.size():
			var c := r.position + Vector2(24 + k * 20, r.size.y * 0.5)
			draw_circle(c, 8.0, swatch[k])
			draw_arc(c, 8.0, 0, TAU, 16, INK, 2.0)
		x = 30.0 + swatch.size() * 20.0
	draw_string(TITLE_FONT, r.position + Vector2(x, 33), item.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, PAPER if focused else Color(PAPER, 0.75))
	var tag := ""
	var col := GOLD
	if _slot() == "upgrade":
		var lvl: int = profile.upgrade_level(id) if profile else 0
		for k in Catalog.UPGRADES.size():
			_star(r.position + Vector2(r.size.x - 190 + k * 24, r.size.y * 0.5), k < lvl)
		var price: int = profile.next_upgrade_price(id) if profile else -1
		if price < 0:
			tag = "MAX"
			col = Color(0.55, 1.0, 0.65)
		else:
			tag = "%d" % price
			col = GOLD if profile.lumens >= price else Color(0.8, 0.4, 0.35)
			Coin.draw_coin(self, r.position + Vector2(r.size.x - 92, r.size.y * 0.5), 10.0, _time * 2.0 + i)
	else:
		var owned: bool = profile != null and profile.owned.has(id)
		var equipped: bool = profile != null and profile.equipped.get(item.slot, "") == id
		if equipped:
			tag = "EQUIPPED"
			col = Color(0.55, 1.0, 0.65)
		elif owned:
			tag = "OWNED"
			col = PAPER
		else:
			tag = "%d" % item.price
			col = GOLD if profile != null and profile.lumens >= item.price else Color(0.8, 0.4, 0.35)
			Coin.draw_coin(self, r.position + Vector2(r.size.x - 92, r.size.y * 0.5), 10.0, _time * 2.0 + i)
	var tw := TITLE_FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(TITLE_FONT, r.position + Vector2(r.size.x - tw - 28, 32), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)


## The colours an outfit piece brings (hat + band, scarf, cloak + lining).
func _swatch(item: Dictionary) -> Array:
	var look: Dictionary = item.get("look", {})
	var out := []
	for k in ["hat", "band", "scarf", "cloak", "cloak_rim"]:
		if look.has(k):
			out.append(look[k])
	return out


func _star(c: Vector2, on: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + PI * k / 5.0
		pts.append(c + Vector2.from_angle(a) * (9.0 if k % 2 == 0 else 4.0))
	draw_colored_polygon(pts, GOLD if on else Color(0.2, 0.18, 0.22))
	draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 1.5)


## The box along the bottom: what the highlighted thing does.
func _draw_details(id: String, profile: Node) -> void:
	var item: Dictionary = Catalog.ITEMS[id]
	var box := Rect2(60, size.y - 168, 1160, 120)
	draw_rect(box, Color(0.1, 0.08, 0.12))
	draw_rect(box, RED, false, 2.0)
	var font := ThemeDB.fallback_font
	var title: String = item.name.to_upper()
	var lines: Array[String] = []
	var action := ""
	if _slot() == "upgrade":
		var lvl: int = profile.upgrade_level(id) if profile else 0
		if lvl >= Catalog.UPGRADES.size():
			lines.append("Fully upgraded: %s" % ", ".join(Catalog.UPGRADES.map(func(u): return u.name)))
			lines.append("Masterwork %s: %s" % [item.get("special_name", ""), item.get("master", "")])
		else:
			var up: Dictionary = Catalog.UPGRADES[lvl]
			title += "  -  %s (%d/%d)" % [up.name, lvl + 1, Catalog.UPGRADES.size()]
			lines.append(up.desc if up.desc != "" else "Masterwork %s: %s" % [item.get("special_name", ""), item.get("master", "")])
			lines.append("Upgrades: +1 damage, a quicker special, then a masterwork special.")
			action = "ENTER: UPGRADE"
	else:
		lines.append(item.desc)
		if item.slot == "weapon":
			lines.append("HOLD ATTACK - %s: %s" % [item.get("special_name", ""), item.get("special_desc", "")])
		var owned: bool = profile != null and profile.owned.has(id)
		action = "ENTER: EQUIP" if owned else "ENTER: BUY"
	draw_string(TITLE_FONT, box.position + Vector2(18, 32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PAPER)
	var y := box.position.y + 58
	for line in lines:
		draw_multiline_string(font, Vector2(box.position.x + 18, y), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 220, 17, 2, Color(PAPER, 0.85))
		y += 24 * ceilf(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x / (box.size.x - 220))
	if action != "":
		var aw := TITLE_FONT.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(TITLE_FONT, Vector2(box.end.x - aw - 18, box.position.y + 32), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
