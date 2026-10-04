extends Control
## Patch's Paper Goods: the shop overlay (talk to Patch in the hub).
## Tabs for weapons, armor and looks; a live preview of Vesper wearing the
## item you're looking at. W/S pick an item, A/D (or Q/E) switch tab,
## Enter / click buys it, or equips it if you own it. Esc closes.
## Items live in scripts/core/catalog.gd; money and ownership in Profile.

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
const DIM := Color(0.55, 0.53, 0.58)
const GOLD := Color(1.0, 0.82, 0.25)
const QUIPS := ["Bark! Buy something! Anything!", "I was cut for being too cute. Their loss!",
	"Fresh from the bin, barely crumpled!", "No refunds. I ate the receipts."]

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
	group.position = Vector2(960, 520)
	group.scale = Vector2(4.2, 4.2)
	add_child(group)
	_art = Node2D.new()
	_art.name = "Art"  # sword.gd looks for its sibling "Art"
	_art.set_script(PlayerVisual)
	group.add_child(_art)
	_sword = SwordScene.instantiate()
	group.add_child(_sword)
	_preview()


func _items() -> Array:
	var slot: String = Catalog.SLOTS[_tab][0]
	var out := []
	for id in Catalog.ITEMS:
		if Catalog.ITEMS[id].slot == slot:
			out.append(id)
	return out


func _process(delta: float) -> void:
	_time += delta
	_message_t = maxf(_message_t - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n := _items().size()
		match event.physical_keycode:
			KEY_ESCAPE:
				_close()
			KEY_W, KEY_UP:
				_row = (_row - 1 + n) % n
				_preview()
			KEY_S, KEY_DOWN:
				_row = (_row + 1) % n
				_preview()
			KEY_A, KEY_LEFT, KEY_Q:
				_set_tab((_tab + 2) % 3)
			KEY_D, KEY_RIGHT:
				_set_tab((_tab + 1) % 3)
			KEY_ENTER, KEY_SPACE, KEY_E:
				_use(_items()[_row])
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not ("position" in event):
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for i in _tabs.size():
		if _tabs[i].has_point(event.position) and click:
			_set_tab(i)
	for i in _rows.size():
		if _rows[i].has_point(event.position):
			if _row != i:
				_row = i
				_preview()
			if click:
				_use(_items()[i])


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
	if profile.owned.has(id):
		profile.equip(id)
		_say("Equipped %s." % item.name)
	elif profile.buy(id):
		_say("Bought %s! Pleasure doing business. Woof." % item.name)
	else:
		_say("Not enough Lumens. Go hit some scribbles!")
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
	_sword.cloak_color = look.get("cloak", _sword.cloak_color)
	_sword.blade_length = look.get("blade_length", _sword.blade_length)
	_sword.grip_color = look.get("grip", _sword.grip_color)
	# a little swing when looking at weapons
	if Catalog.SLOTS[_tab][0] == "weapon" and _sword.has_method("swing"):
		_sword.swing(Vector2.RIGHT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.95))
	var profile := get_node_or_null("/root/Profile")
	# header: shop sign and Patch's line
	draw_string_outline(TITLE_FONT, Vector2(66, 82), "PATCH'S PAPER GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 12, Color(RED, 0.9))
	draw_string(TITLE_FONT, Vector2(60, 76), "PATCH'S PAPER GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(64, 108), "Patch: \"%s\"" % _quip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.7))
	# money
	var money := "%d" % (profile.lumens if profile else 0)
	var mw := TITLE_FONT.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	Coin.draw_coin(self, Vector2(size.x - mw - 92, 64), 17.0, _time * 2.0)
	draw_string(TITLE_FONT, Vector2(size.x - mw - 60, 78), money, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, GOLD)
	# tabs
	_tabs.clear()
	for i in Catalog.SLOTS.size():
		var r := Rect2(60 + i * 190, 136, 176, 44)
		_tabs.append(r)
		var on := i == _tab
		draw_rect(r, Color(RED, 0.9) if on else Color(0.12, 0.1, 0.14))
		draw_rect(r, RED, false, 2.0)
		var t: String = Catalog.SLOTS[i][1]
		var tw := TITLE_FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(TITLE_FONT, r.position + Vector2((r.size.x - tw) * 0.5, 32), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, PAPER if on else DIM)
	# item list
	_rows.clear()
	var items := _items()
	for i in items.size():
		var id: String = items[i]
		var item: Dictionary = Catalog.ITEMS[id]
		var r := Rect2(60, 200 + i * 64, 560, 54)
		_rows.append(r)
		var focused := i == _row
		var owned: bool = profile != null and profile.owned.has(id)
		var equipped: bool = profile != null and profile.equipped.get(item.slot, "") == id
		var bar := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end - Vector2(18, 0), r.position + Vector2(0, r.size.y)])
		draw_colored_polygon(bar, Color(RED, 0.85) if focused else Color(0.12, 0.1, 0.14))
		draw_polyline(bar + PackedVector2Array([bar[0]]), RED, 2.0)
		draw_string(TITLE_FONT, r.position + Vector2(20, 37), item.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PAPER if focused else Color(PAPER, 0.75))
		var tag := ""
		var col := GOLD
		if equipped:
			tag = "EQUIPPED"
			col = Color(0.55, 1.0, 0.65)
		elif owned:
			tag = "OWNED"
			col = PAPER
		else:
			tag = "%d" % item.price
			var afford: bool = profile != null and profile.lumens >= item.price
			col = GOLD if afford else Color(0.8, 0.4, 0.35)
			Coin.draw_coin(self, r.position + Vector2(r.size.x - 120, 27), 11.0, _time * 2.0 + i)
		var tw := TITLE_FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(TITLE_FONT, r.position + Vector2(r.size.x - tw - 30, 36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	# preview pedestal and description
	# a flat pedestal under Vesper's feet
	var ped := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		ped.append(Vector2(960, 524) + Vector2(cos(a) * 130.0, sin(a) * 30.0))
	draw_colored_polygon(ped, Color(0.14, 0.11, 0.16))
	draw_polyline(ped + PackedVector2Array([ped[0]]), RED, 3.0)
	if _row < items.size():
		var item: Dictionary = Catalog.ITEMS[items[_row]]
		var box := Rect2(60, size.y - 132, 1160, 70)
		draw_rect(box, Color(0.1, 0.08, 0.12))
		draw_rect(box, RED, false, 2.0)
		draw_string(TITLE_FONT, box.position + Vector2(18, 30), item.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PAPER)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(18, 56), item.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.85))
		var owned: bool = profile != null and profile.owned.has(items[_row])
		var action := "ENTER: EQUIP" if owned else "ENTER: BUY"
		var aw := TITLE_FONT.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(TITLE_FONT, Vector2(box.end.x - aw - 18, box.position.y + 30), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
	if _message_t > 0.0:
		var a := clampf(_message_t / 0.4, 0.0, 1.0)
		draw_string(TITLE_FONT, Vector2(700, 200), _message, HORIZONTAL_ALIGNMENT_LEFT, 520, 26, Color(GOLD, a))
	draw_string(TITLE_FONT, Vector2(60, size.y - 26), "W/S  CHOOSE     A/D  TAB     ENTER  BUY / EQUIP     ESC  LEAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
