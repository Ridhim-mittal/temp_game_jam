extends Node
## Autoload "Profile": the player's lasting progress, saved to
## user://profile.cfg. Survives starting a new story run.
##
##   Profile.lumens / Profile.add_lumens(5)       # shop money
##   Profile.skill_points                          # Ink Points to spend
##   Profile.unlock_skill("keen_nib") -> bool
##   Profile.buy("quill") -> bool / Profile.equip("quill")
##   Profile.effect("reach_mult", 1.0)             # combined from skills + gear
##   Profile.record_clear("darkwood_1")            # first clear -> Ink Points
##   Profile.tutorial_seen("2d.jump") / Profile.mark_tutorial("2d.jump")
## Items and skills are defined in scripts/core/catalog.gd.

signal changed

const Catalog = preload("res://scripts/core/catalog.gd")
const PATH := "user://profile.cfg"

var lumens := 0
var skill_points := 0
var skills := {}  # id -> true
var owned := {}  # item id -> true
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


## Ink Points the first time a room is cleared. Returns the points given.
func record_clear(room_id: String) -> int:
	if first_clears.has(room_id):
		return 0
	first_clears[room_id] = true
	var pts: int = Catalog.ROOM_POINTS.get(room_id, 1)
	skill_points += pts
	_changed()
	return pts


## Tutorial steps play once; these remember which ones have been seen.
func tutorial_seen(id: String) -> bool:
	return tutorials.has(id)


func mark_tutorial(id: String) -> void:
	if not tutorials.has(id):
		tutorials[id] = true
		_changed()


## Settings -> Tutorials: play every tutorial again.
func reset_tutorials() -> void:
	tutorials.clear()
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
	if item.is_empty() or owned.has(id) or lumens < item.price:
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


## A combined effect value: multipliers multiply, numbers add, flags OR.
func effect(key: String, default = 0.0):
	var v = default
	var sources: Array = []
	for id in skills:
		sources.append(Catalog.SKILLS[id].effect)
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


## Look values of the equipped weapon / armor / cosmetic, merged.
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
	var eq: Dictionary = cfg.get_value("profile", "equipped", {})
	for slot in eq:
		if owned.has(eq[slot]):
			equipped[slot] = eq[slot]
	for id in cfg.get_value("profile", "first_clears", []):
		first_clears[id] = true
	for id in cfg.get_value("profile", "tutorials", []):
		tutorials[id] = true
