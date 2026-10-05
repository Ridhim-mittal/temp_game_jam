extends SceneTree
## Quire's shop, weapons and outfits, in both modes:
##  - coins picked up in a 2D level go to the shop's purse (Profile.lumens);
##    once there is enough for something, the 2D HUD says "PRESS B"
##  - B opens the shop in a 2D level (pausing it) and Esc closes it
##  - buying, equipping and upgrading (prices, order, the retired item)
##  - each weapon's special in the 2D levels: the ink wave, the quill volley
##    (end to end: hold attack, let go), the slam, the drill (pulls, then
##    bursts), the blinding sweep (stuns), the whirl (its light makes
##    sketches solid)
##  - the same in the Gutter: the drill pulls, the sweep blinds and dazzles a
##    Haunting Lamp, the whirl shows a Half-Drawn without raising the Ember, the Prism Saber
##    cuts one unseen, the slam (end to end) and the volley hit
##  - outfits: the hat and band reach the 2D art and the 3D model
## The player's real progress is put back afterwards.
## Run like test_phase1.gd (prints PASS / FAIL; exit code = failures).

const LEVEL_2D := "res://scenes/levels/test_level.tscn"
const ROOM := "res://scenes/world25/rooms/darkwood_1.tscn"
const CRAWLER := "res://scenes/enemies/crawler.tscn"
const Lights = preload("res://scripts/world/lights.gd")
const WeaponFx = preload("res://scripts/effects/weapon_fx.gd")
var fails := 0
var _saved := {}


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func pframes(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(t: float) -> void:
	await pframes(int(ceil(t * Engine.physics_ticks_per_second)))


func profile() -> Node:
	return root.get_node("Profile")


func _run() -> void:
	var p := profile()
	_saved = {"lumens": p.lumens, "owned": p.owned.duplicate(), "equipped": p.equipped.duplicate(), "upgrades": p.upgrades.duplicate()}
	p.reset()
	await profile_test()
	await coins_2d_test()
	await specials_2d_test()
	await specials_25d_test()
	await outfit_test()
	p.lumens = _saved.lumens
	p.owned = _saved.owned
	p.equipped = _saved.equipped
	p.upgrades = _saved.upgrades
	p._changed()
	print("DONE fails=%d" % fails)
	quit(fails)


## Buying, equipping, upgrading.
func profile_test() -> void:
	var p := profile()
	check(p.weapon() == "nib" and p.owned.has("nib") and p.owned.has("topper"), "a fresh profile has the Nib-Sword and the black topper")
	check(not p.buy("corkscrew"), "no coins, no Corkscrew Nib")
	p.lumens = 200
	check(p.buy("corkscrew") and p.weapon() == "corkscrew" and p.lumens == 145, "buying the Corkscrew Nib (55) equips it (%d left)" % p.lumens)
	check(not p.buy("compass"), "the retired Compass Edge isn't sold")
	check(p.next_upgrade_price("corkscrew") == 15 and p.buy_upgrade("corkscrew") and p.upgrade_level("corkscrew") == 1,
		"its first upgrade (SHARPENED) costs 15")
	p.buy_upgrade("corkscrew")
	p.buy_upgrade("corkscrew")
	check(p.upgrade_level("corkscrew") == 3 and p.next_upgrade_price("corkscrew") == -1 and not p.buy_upgrade("corkscrew"),
		"three upgrades and it's a masterwork (no more to buy)")
	check(p.next_upgrade_price("prism") == -1, "no upgrades for a weapon you don't own")
	p.equip("nib")
	check(p.weapon() == "nib", "equipping an owned weapon")
	p.reset()


## 2D: coins fill the purse, the HUD says PRESS B, B opens the shop.
func coins_2d_test() -> void:
	var p := profile()
	var state := root.get_node("GameState")
	state.reset()
	change_scene_to_file(LEVEL_2D)
	await frames(10)
	var player = current_scene.get_node("Player")
	player._invuln_timer = 999.0
	var hud: Node = null
	for n in current_scene.find_children("*", "Control", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("ui/hud.gd"):
			hud = n
	player.add_coins(4)
	await frames(3)
	check(p.lumens == 4 and player.coins == 4, "a 2D coin goes into the shop's purse (%d)" % p.lumens)
	check(hud != null and not hud._can_shop and hud._hint <= 0.0, "4 coins: nothing affordable yet, no shop prompt")
	player.add_coins(6)
	await frames(3)
	check(hud != null and hud._can_shop and hud._hint > 0.0 and state.seen.has("shop_hint"),
		"10 coins: \"PRESS B TO OPEN THE SHOP\" shows (and the B SHOP tag)")
	await pframes(2)
	Input.action_press("shop")
	await pframes(2)
	Input.action_release("shop")
	await frames(3)
	var shop: Node = null
	for n in current_scene.find_children("*", "Control", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("ui/shop.gd"):
			shop = n
	check(shop != null and paused, "B opens the shop in a 2D level, and it pauses")
	if shop:
		shop._set_tab(2)  # hats
		var items: Array = shop._items()
		shop._row = items.find("crimson_hat")
		shop._use("crimson_hat")
		check(p.owned.has("crimson_hat") and p.equipped.hat == "crimson_hat" and p.lumens == 0, "buying the Crimson Topper in the shop")
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)
		await frames(4)
	check(not paused and current_scene.scene_file_path == LEVEL_2D, "Esc closes the shop and play goes on (not to the main menu)")
	check(player.art.hat_color.is_equal_approx(Color(0.55, 0.09, 0.11)), "the 2D Vesper wears the new hat at once")
	# the pause screen (Esc, 2D and 2.5D) has SHOP in place of the skill tree
	load("res://scripts/ui/pause_menu.gd").open_2d(player)
	await frames(4)
	var menu: Node = null
	for n in current_scene.find_children("*", "Control", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("ui/pause_menu.gd"):
			menu = n
	var labels: Array = menu._items.map(func(it): return it[1]) if menu else []
	check(labels.has("shop") and not labels.has("skills"), "the 2D pause screen lists SHOP, no skill tree (%s)" % [labels])
	if menu:
		menu._t = 1.0
		menu._choose(labels.find("shop"))
		await frames(3)
		check(menu._sub != null and menu._sub.get_script().resource_path.ends_with("ui/shop.gd"), "pause -> SHOP opens the shop on top")
		menu._sub._close()
		await frames(3)
		check(menu._sub == null and menu.visible and paused, "closing it comes back to the pause screen")
		menu._act("resume")
		await frames(3)
	check(not paused, "resume: play goes on")


func _crawler(at: Vector2) -> Node2D:
	var e: Node2D = load(CRAWLER).instantiate()
	current_scene.add_child(e)
	e.global_position = at
	e.health = 99
	return e


func _equip(id: String) -> void:
	var p := profile()
	p.owned[id] = true
	p.equipped.weapon = id
	p._changed()


## Each weapon's special in a 2D level.
func specials_2d_test() -> void:
	change_scene_to_file(LEVEL_2D)
	await frames(10)
	var player = current_scene.get_node("Player")
	player._invuln_timer = 999.0
	await pframes(20)  # settle on the ground
	var at: Vector2 = player.global_position
	# the quill volley, end to end: hold attack past the charge, let go
	_equip("quill")
	player.refresh_loadout()
	check(player.sword.style == "quill" and player.attack_cooldown < player._base_stats.attack_cooldown,
		"the Quill Rapier: its look, and quicker swings (%.2f s)" % player.attack_cooldown)
	player.facing = 1
	var e := _crawler(at + Vector2(240, -10))
	await pframes(10)
	var hp: int = e.health
	Input.action_press("attack")
	await seconds(player.charge_time + 0.15)
	Input.action_release("attack")
	await pframes(2)
	var darts := 0
	for n in current_scene.get_children():
		if n is WeaponFx.QuillDart:
			darts += 1
	check(darts == 3, "QUILL VOLLEY: hold attack, let go - three quills fly (%d)" % darts)
	await seconds(0.5)
	check(e.health < hp, "the quills hit the monster in front (%d -> %d)" % [hp, e.health])
	e.queue_free()
	# the slam
	_equip("brush")
	player.refresh_loadout()
	e = _crawler(at + Vector2(-120, -10))
	await pframes(10)
	hp = e.health
	player._ink_slam()
	check(e.health < hp, "INK SLAM: the ring hits a monster beside Vesper (%d -> %d)" % [hp, e.health])
	e.queue_free()
	# the drill: drags a monster in, then bursts
	_equip("corkscrew")
	player.refresh_loadout()
	e = _crawler(at + Vector2(150, -10))
	await pframes(10)
	var d0: float = absf(e.global_position.x - player.global_position.x)
	player._start_drill()
	for i in 30:
		await physics_frame
		player._update_drill(1.0 / Engine.physics_ticks_per_second)
	var d1: float = absf(e.global_position.x - player.global_position.x)
	check(d1 < d0 - 30.0, "PEN-DRILL: the spin drags the monster in (%.0f -> %.0f px)" % [d0, d1])
	hp = e.health
	player._drill_burst()
	check(e.health < hp and player._drill < 0.0, "letting go bursts it outward (%d -> %d)" % [hp, e.health])
	e.queue_free()
	# the sweep: stuns
	_equip("prism")
	player.refresh_loadout()
	e = _crawler(at + Vector2(110, -10))
	await pframes(10)
	player.facing = 1
	player._blinding_sweep()
	check(e.stunned_for() > 1.0, "BLINDING SWEEP: the monster in front is blinded (stun %.1f s)" % e.stunned_for())
	e.queue_free()
	# the whirl: a light that makes sketches solid while it burns Ember
	_equip("lantern")
	player.refresh_loadout()
	player.ember.meter = player.ember.max_meter
	var probe: Vector2 = player.global_position + Vector2(100, 0)
	var before := Lights.reaches(self, probe)
	player._start_whirl()
	for i in 20:
		await physics_frame
		player._update_whirl(1.0 / Engine.physics_ticks_per_second)
	check(not before and Lights.reaches(self, probe), "LANTERN WHIRL: its light reaches round Vesper (sketches go solid)")
	check(player.ember.meter < player.ember.max_meter, "the whirl burns the Ember (%.0f)" % player.ember.meter)
	player._cancel_charge()
	check(not Lights.reaches(self, probe), "and the light goes when it stops")
	# the ink wave (the Nib-Sword)
	_equip("nib")
	player.refresh_loadout()
	player._release_special()
	var waves := 0
	for n in current_scene.get_children():
		if n.get_script() and n.get_script().resource_path.ends_with("ink_wave.gd"):
			waves += 1
	check(waves == 1, "INK WAVE: the Nib-Sword's special is the ink wave")
	# an upgrade: SHARPENED adds damage
	var dmg: int = player.attack_damage
	profile().upgrades["nib"] = 1
	player.refresh_loadout()
	check(player.attack_damage == dmg + 1, "SHARPENED: +1 damage in the 2D levels (%d -> %d)" % [dmg, player.attack_damage])
	profile().upgrades.clear()


## Each weapon's special in the Gutter.
func specials_25d_test() -> void:
	var world := root.get_node("World25")
	world.cleared.clear()
	change_scene_to_file(ROOM)
	await frames(6)
	var room := current_scene
	var player = room.player
	player._invuln = 999.0
	player._spawn_guard = 0.0
	var ghosts: Array = room.get_node("Enemies").get_children()
	var g = ghosts[0]
	for other in ghosts.slice(1):
		other.queue_free()
	var lamps := get_nodes_in_group("haunt_lamp")
	g.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 0)
	player._snap_visuals()
	player.facing_dir = Vector3(1, 0, 0)
	await pframes(4)
	# the Prism Saber cuts an unseen Half-Drawn
	_equip("prism")
	player.refresh_loadout()
	g.global_position = Vector3(1.2, 0.05, 0)
	g.set_physics_process(true)
	await pframes(2)
	check(not g.revealed, "a Half-Drawn out of the Ember's light is unseen")
	var landed: bool = g.take_hit(1, Vector3(1, 0, 0))
	check(landed, "the Prism Saber's light cuts it anyway")
	g.set_physics_process(false)
	g.health = 99
	# the sweep blinds and dazzles a hunting lamp
	if lamps.size() > 0:
		var lamp = lamps[0]
		lamp._set_hunt(lamp.Hunt.SEEK)
		lamp.spot = Vector3(player.global_position.x, lamp.spot.y, player.global_position.z)
		g.global_position = Vector3(1.5, 0.05, 0)
		g.stun = 0.0
		player._blinding_sweep()
		check(g.stun > 1.0, "BLINDING SWEEP: the monster in front is blinded (stun %.1f s)" % g.stun)
		check(lamp.hunt == lamp.Hunt.LOST and lamp.erase == 0.0, "and the Haunting Lamp's light is turned away (LOST)")
	for l in get_nodes_in_group("haunt_lamp"):
		l.queue_free()
	# the drill pulls
	_equip("corkscrew")
	player.refresh_loadout()
	g.global_position = Vector3(2.6, 0.05, 0)
	g.set_physics_process(true)
	g.stun = 0.0
	var d0: float = g.global_position.distance_to(player.global_position)
	player._start_drill()
	for i in 30:
		await physics_frame
		player._update_drill(1.0 / Engine.physics_ticks_per_second)
	var d1: float = g.global_position.distance_to(player.global_position)
	check(d1 < d0 - 0.5, "PEN-DRILL: the spin drags the monster in (%.1f -> %.1f)" % [d0, d1])
	check(player._model.spin != 0.0, "Vesper spins like a drill")
	player._drill_burst()
	check(player._model.spin == 0.0, "the burst ends the spin")
	g.set_physics_process(false)
	# the whirl's light shows a Half-Drawn without raising the Ember
	_equip("lantern")
	player.refresh_loadout()
	player.fuel = player.max_fuel
	g.global_position = Vector3(1.5, 0.05, 0)
	player._start_whirl()
	await pframes(2)
	check(player.ember_reveals(g.global_position + Vector3(0, 1, 0)) and player.monster_light, "LANTERN WHIRL: its light shows the Half-Drawn without raising the Ember")
	var f0: float = player.fuel
	for i in 20:
		await physics_frame
		player._update_whirl(1.0 / Engine.physics_ticks_per_second)
	check(player.fuel < f0, "the whirl burns the Ember (%.0f -> %.0f)" % [f0, player.fuel])
	player._cancel_charge()
	check(not player.ember_reveals(g.global_position + Vector3(0, 1, 0)), "and stops showing it once it stops")
	# the slam, end to end: hold attack, let go
	_equip("brush")
	player.refresh_loadout()
	g.queue_free()
	var dummy = load("res://scenes/clearing/monsters/half_drawn.tscn").instantiate()
	room.get_node("Enemies").add_child(dummy)
	dummy.global_position = Vector3(-1.4, 0.05, 0.8)
	dummy.set_physics_process(false)
	dummy.health = 99
	dummy.revealed = true  # as if in the Ember's light, so the brush can cut it
	var hp: int = dummy.health
	Input.action_press("attack")
	await seconds(player.charge_time + 0.12)
	dummy.revealed = true
	Input.action_release("attack")
	await pframes(2)
	check(dummy.health < hp - 1, "INK SLAM: hold attack, let go - the ring hits all round (%d -> %d)" % [hp, dummy.health])
	# the volley
	_equip("quill")
	player.refresh_loadout()
	player.facing_dir = Vector3(1, 0, 0)
	dummy.global_position = Vector3(4.0, 0.05, 0)
	dummy.revealed = true
	hp = dummy.health
	player._quill_volley()
	for i in 40:
		await physics_frame
		dummy.revealed = true
	check(dummy.health < hp, "QUILL VOLLEY: the quills fly and hit (%d -> %d)" % [hp, dummy.health])
	_equip("nib")


## The hat and its band reach both Vespers.
func outfit_test() -> void:
	var p := profile()
	p.owned["navy_hat"] = true
	p.owned["red_cloak"] = true
	p.equip("navy_hat")
	p.equip("red_cloak")
	change_scene_to_file(ROOM)
	await frames(6)
	var player = current_scene.player
	var model = player._model
	check(model.hat_color.is_equal_approx(Color(0.12, 0.16, 0.38)) and model.band_color.is_equal_approx(Color(0.95, 0.75, 0.25)),
		"the 3D Vesper wears the Midnight Topper (blue, gold band)")
	check(model.cloak_color.is_equal_approx(Color(0.5, 0.1, 0.12)), "and the Red Pen Cloak")
	check(player.art.hat_color.is_equal_approx(Color(0.12, 0.16, 0.38)), "the billboard art gets the hat too")
	_equip("corkscrew")
	player.refresh_loadout()
	check(model.weapon_style == "corkscrew", "the 3D model carries the equipped weapon")
