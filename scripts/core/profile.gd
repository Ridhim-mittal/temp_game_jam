extends Node
## Autoload "Profile": the player's lasting progress, saved to
## user://profile.cfg. Survives starting a new story run.
##
##   Profile.lumens / Profile.add_lumens(5)       # the shop's money: the Lumen
##                                                 # coins picked up in 2D levels
##   Profile.buy("quill") -> bool / Profile.equip("quill")
##   Profile.weapon() -> "nib"                     # the equipped weapon's id
##   Profile.upgrade_level("quill") -> 0..3 / Profile.buy_upgrade("quill")
##   Profile.effect("reach_mult", 1.0)             # combined from equipped gear
##   Profile.look() -> {...}                       # outfit + weapon look
##   Profile.record_clear("darkwood_1")            # remembers first clears
##   Profile.tutorial_seen("2d.jump") / Profile.mark_tutorial("2d.jump")
## Items are defined in scripts/core/catalog.gd. (The skill tree is retired:
## `skills` / `skill_points` are kept in the save but give nothing.)

signal changed

const Catalog = preload("res://scripts/core/catalog.gd")
const PATH := "user://profile.cfg"

var lumens := 0
var skill_points := 0
var skills := {}  # id -> true
var owned := {}  # item id -> true
var upgrades := {}  # weapon id -> upgrades bought (0..Catalog.UPGRADES.size())
var equipped := Catalog.STARTING.duplicate()
var first_clears := {}  # room id -> true
var tutorials := {}  # tutorial step id (scripts/ui/tutorial.gd) -> true once seen


func _ready() -> void:
	for id in Catalog.STARTING.values():
		owned[id] = true
	_load()


func add_lumens(amount: int) -> void:
	lumens = maxi(lumens + amount, 0)
	_changed()


## Remembers a room's first clear. (It used to pay Ink Points for the
## retired skill tree.) Returns true the first time.
func record_clear(room_id: String) -> bool:
	if first_clears.has(room_id):
		return false
	first_clears[room_id] = true
	_changed()
	return true


## Tutorial steps play once; these remember which ones have been seen.
func tutorial_seen(id: String) -> bool:
	return tutorials.has(id)


func mark_tutorial(id: String) -> void:
	if not tutorials.has(id):
		tutorials[id] = true
		_changed()


## Play tutorials again: all of them (Settings -> Tutorials), or those
## whose ids start with `prefix` ("25d." from the pause menu).
func reset_tutorials(prefix := "") -> void:
	for id in tutorials.keys():
		if id.begins_with(prefix):
			tutorials.erase(id)
	_changed()


func can_unlock(id: String) -> bool:
	var s: Dictionary = Catalog.SKILLS.get(id, {})
	if s.is_empty() or skills.has(id) or skill_points < s.cost:
		return false
	return s.tier == 0 or skills.has(_previous(s))


func unlock_skill(id: String) -> bool:
	if not can_unlock(id):
		return false
	skill_points -= Catalog.SKILLS[id].cost
	skills[id] = true
	_changed()
	return true


func _previous(s: Dictionary) -> String:
	for id in Catalog.SKILLS:
		var o: Dictionary = Catalog.SKILLS[id]
		if o.branch == s.branch and o.tier == s.tier - 1:
			return id
	return ""


func buy(id: String) -> bool:
	var item: Dictionary = Catalog.ITEMS.get(id, {})
	if item.is_empty() or item.get("retired", false) or owned.has(id) or lumens < item.price:
		return false
	lumens -= item.price
	owned[id] = true
	equipped[item.slot] = id
	_changed()
	return true


func equip(id: String) -> void:
	if owned.has(id):
		equipped[Catalog.ITEMS[id].slot] = id
		_changed()


## The equipped weapon's id, and its catalog entry.
func weapon() -> String:
	return equipped.get("weapon", "nib")


func weapon_item() -> Dictionary:
	return Catalog.ITEMS.get(weapon(), Catalog.ITEMS.nib)


## How many of the weapon's upgrades (Catalog.UPGRADES, in order) are bought.
func upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)


## Price of the weapon's next upgrade, or -1 when it has them all (or isn't
## owned).
func next_upgrade_price(id: String) -> int:
	var lvl := upgrade_level(id)
	if not owned.has(id) or lvl >= Catalog.UPGRADES.size():
		return -1
	return Catalog.UPGRADES[lvl].price


func buy_upgrade(id: String) -> bool:
	var price := next_upgrade_price(id)
	if price < 0 or lumens < price:
		return false
	lumens -= price
	upgrades[id] = upgrade_level(id) + 1
	_changed()
	return true


## The cheapest thing in the shop not bought yet (an item or an upgrade of
## a weapon you own), or -1 when there's nothing left to buy.
func cheapest_price() -> int:
	var best := -1
	for id in Catalog.ITEMS:
		var item: Dictionary = Catalog.ITEMS[id]
		var price := -1
		if not owned.has(id) and not item.get("retired", false):
			price = item.price
		elif item.slot == "weapon":
			price = next_upgrade_price(id)
		if price >= 0 and (best < 0 or price < best):
			best = price
	return best


## A combined effect value of the equipped gear: multipliers multiply,
## numbers add, flags OR.
func effect(key: String, default = 0.0):
	var v = default
	var sources: Array = []
	for slot in equipped:
		sources.append(Catalog.ITEMS[equipped[slot]].effect)
	for e in sources:
		if not e.has(key):
			continue
		if key.ends_with("_mult"):
			v *= e[key]
		elif e[key] is bool:
			v = v or e[key]
		else:
			v += e[key]
	return v


## Look values of everything equipped (weapon, hat, scarf, cloak), merged.
func look() -> Dictionary:
	var out := {}
	for slot in equipped:
		out.merge(Catalog.ITEMS[equipped[slot]].look, true)
	return out


## Wipe all progress (Settings -> Reset progress). Seen tutorials stay seen.
func reset() -> void:
	lumens = 0
	skill_points = 0
	skills.clear()
	owned.clear()
	upgrades.clear()
	first_clears.clear()
	equipped = Catalog.STARTING.duplicate()
	for id in Catalog.STARTING.values():
		owned[id] = true
	_changed()


func _changed() -> void:
	_save()
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "lumens", lumens)
	cfg.set_value("profile", "skill_points", skill_points)
	cfg.set_value("profile", "skills", skills.keys())
	cfg.set_value("profile", "owned", owned.keys())
	cfg.set_value("profile", "upgrades", upgrades)
	cfg.set_value("profile", "equipped", equipped)
	cfg.set_value("profile", "first_clears", first_clears.keys())
	cfg.set_value("profile", "tutorials", tutorials.keys())
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	lumens = cfg.get_value("profile", "lumens", 0)
	skill_points = cfg.get_value("profile", "skill_points", 0)
	for id in cfg.get_value("profile", "skills", []):
		if Catalog.SKILLS.has(id):
			skills[id] = true
	for id in cfg.get_value("profile", "owned", []):
		if Catalog.ITEMS.has(id):
			owned[id] = true
	var ups: Dictionary = cfg.get_value("profile", "upgrades", {})
	for id in ups:
		if owned.has(id):
			upgrades[id] = clampi(int(ups[id]), 0, Catalog.UPGRADES.size())
	var eq: Dictionary = cfg.get_value("profile", "equipped", {})
	for slot in eq:
		if owned.has(eq[slot]) and Catalog.ITEMS[eq[slot]].slot == slot:
			equipped[slot] = eq[slot]
	for id in cfg.get_value("profile", "first_clears", []):
		first_clears[id] = true
	for id in cfg.get_value("profile", "tutorials", []):
		tutorials[id] = true
