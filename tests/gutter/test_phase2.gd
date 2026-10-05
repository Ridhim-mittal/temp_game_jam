extends SceneTree
## Gutter rework, phase 2 checks: no grass, farm or cosy props or round
## doors in the hub and the story rooms, and beaten monsters drop coins;
## Quire's shop opens at his stall, from the pause menu and on B; the skill
## tree is gone; the HUD shows the purse and no map. Run like test_phase1.gd
## (prints PASS / FAIL). It puts the player's coins back afterwards.

const ROOMS := ["res://scenes/clearing/clearing.tscn", "res://scenes/world25/rooms/darkwood_1.tscn",
	"res://scenes/world25/rooms/shallows_pen.tscn", "res://scenes/world25/rooms/wastes_gap.tscn",
	"res://scenes/world25/rooms/arena.tscn"]
## biome_props.gd kinds that must not be placed any more.
const RETIRED := {0: "CANOPY", 3: "GARDEN_PLOT", 4: "BARN", 5: "SCARECROW", 9: "CORAL", 10: "TUBE_PLANT", 15: "NEST"}
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func get_tree_paused() -> bool:
	return paused


func script_name(n: Node) -> String:
	var s: Script = n.get_script()
	return s.resource_path.get_file() if s else ""


func _run() -> void:
	var saved_purse: int = root.get_node("Profile").lumens
	for path in ROOMS:
		change_scene_to_file(path)
		await frames(8)
		var bad := []
		for n in current_scene.find_children("*", "", true, false):
			var sn := script_name(n)
			if sn == "grass_field.gd" or sn == "scatter_props.gd" and n.kind in [0, 1]:
				bad.append(n.name)  # grass, reeds, mushrooms, red leaves
			elif sn == "biome_props.gd" and RETIRED.has(int(n.kind)):
				bad.append("%s (%s)" % [n.name, RETIRED[int(n.kind)]])
			elif sn == "archway.gd" and n.door != 0:
				bad.append("%s (round door)" % n.name)
			elif sn == "interactable.gd" and n.action == "shop" and not path.ends_with("clearing.tscn"):
				bad.append("%s (shop)" % n.name)  # the only stall is Quire's, in the hub
		check(bad.is_empty(), "%s: no grass / farm / cosy props / stray shops / round doors %s" % [path.get_file(), bad])
		# coins: beat every monster; each spills its dark-silver coins
		var enemies := current_scene.get_node_or_null("Enemies")
		var worth := 0
		var purse_before: int = root.get_node("Profile").lumens
		if enemies:
			for m in enemies.get_children():
				if m.has_method("_die") and not m.dead:
					worth += int(m.lumens) if "lumens" in m else 0
					m._die()
		await frames(10)
		var value: int = root.get_node("Profile").lumens - purse_before  # any already picked up
		for n in get_nodes_in_group("margin_coin"):
			value += n.value
		check(worth > 0 and value == worth, "%s: beaten monsters drop their coins (%d of %d)" % [path.get_file(), value, worth])
	# the hub: Quire's stall opens the shop; so do B and the pause menu; no
	# skill tree any more
	change_scene_to_file("res://scenes/clearing/clearing.tscn")
	await frames(30)
	var room := current_scene
	var player = room.player
	player._invuln = 999.0
	for m in room.get_node("Enemies").get_children():
		m.queue_free()
	check(room.get_node_or_null("Props/Patch") == null, "Patch the dog is gone from the hub")
	var stall := room.get_node("Props/QuireShop")
	player.global_position = stall.global_position + Vector3(0.0, 0.05, 1.8)
	player._snap_visuals()
	await frames(5)
	await physics_frame
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(3)
	check(room._overlay != null and script_name(room._overlay) == "shop.gd", "E at Quire's stall opens the shop (%s)" % (script_name(room._overlay) if room._overlay else "none"))
	check(get_tree_paused(), "the game is paused while shopping")
	if room._overlay:
		room._overlay._close()
	await frames(3)
	check(room._overlay == null and not get_tree_paused(), "Esc / B in the shop closes it and unpauses")
	var b := InputEventKey.new()
	b.physical_keycode = KEY_B
	b.keycode = KEY_B
	b.pressed = true
	Input.parse_input_event(b)
	await frames(3)
	var b_up := b.duplicate()
	b_up.pressed = false
	Input.parse_input_event(b_up)
	await frames(2)
	check(room._overlay != null and script_name(room._overlay) == "shop.gd", "B opens the shop anywhere in a room")
	if room._overlay:
		room._overlay._close()
	await frames(3)
	room.open_overlay("pause")
	await frames(2)
	room._on_pause_choice("shop")
	await frames(2)
	check(room._overlay != null and script_name(room._overlay) == "shop.gd", "the pause menu has the shop")
	if room._overlay:
		room._overlay._close()
	await frames(2)
	room.open_overlay("skills")
	check(room._overlay == null, "the skill tree is gone (open_overlay(\"skills\") opens nothing)")
	check(room.get_node_or_null("Props/Shrine/SkillShrine") == null, "the shrine no longer opens a skill tree")
	var hud: Node = null
	var minimap := false
	for n in room.find_children("*", "Control", true, false):
		if script_name(n) == "clearing_hud.gd":
			hud = n
		elif script_name(n) == "minimap.gd":
			minimap = true
	check(hud != null and "coins" in hud and hud.coins == root.get_node("Profile").lumens, "the HUD shows the coin purse")
	check(not minimap, "no map placeholder in the corner any more")
	var profile := root.get_node("Profile")
	profile.lumens = saved_purse
	profile._changed()
	print("DONE fails=%d" % fails)
	quit(fails)
