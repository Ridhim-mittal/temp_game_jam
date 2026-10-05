extends SceneTree
## Gutter rework, phase 2 checks: no grass, farm or cosy props, shops, coins
## or round doors in the hub and the story rooms; Patch talks; the skill
## tree still opens. Run like test_phase1.gd (prints PASS / FAIL).

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


func script_name(n: Node) -> String:
	var s: Script = n.get_script()
	return s.resource_path.get_file() if s else ""


func _run() -> void:
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
			elif sn == "interactable.gd" and n.action == "shop":
				bad.append("%s (shop)" % n.name)
		check(bad.is_empty(), "%s: no grass / farm / cosy props / shop / round doors %s" % [path.get_file(), bad])
		# coins: beat every monster and look for Lumen pickups
		var enemies := current_scene.get_node_or_null("Enemies")
		if enemies:
			for m in enemies.get_children():
				if m.has_method("_die") and not m.dead:
					m._die()
		await frames(10)
		var coins := 0
		for n in current_scene.find_children("*", "", true, false):
			if script_name(n) == "lumen.gd":
				coins += 1
		check(coins == 0, "%s: beaten monsters drop no coins (%d)" % [path.get_file(), coins])
	# the hub: Patch talks, the skill tree opens, no Lumen counter, no shop overlay
	change_scene_to_file("res://scenes/clearing/clearing.tscn")
	await frames(30)
	var room := current_scene
	var player = room.player
	player._invuln = 999.0
	for m in room.get_node("Enemies").get_children():
		m.queue_free()
	var patch := room.get_node("Props/Patch")
	player.global_position = patch.global_position + Vector3(0.0, 0.05, 1.6)
	player._snap_visuals()
	await frames(5)
	room.ui._queue.clear()
	room.ui._text = ""
	room.ui._title_t = -1.0
	await physics_frame
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(3)
	var said: String = room.ui._text
	check(room.ui._who == "patch" and said != "", "Patch talks on E: \"%s\"" % said)
	check(room._overlay == null, "talking to Patch opens no shop")
	room.open_overlay("shop")
	check(room._overlay == null, "room.open_overlay(\"shop\") is gone")
	var shrine := room.get_node("Props/Shrine/SkillShrine")
	player.global_position = Vector3(shrine.global_position.x, shrine.global_position.y + 0.05, shrine.global_position.z + 1.5)
	player._snap_visuals()
	await frames(5)
	await physics_frame
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(3)
	check(room._overlay != null and script_name(room._overlay) == "skill_tree.gd", "skill tree opens at the shrine (%s)" % (script_name(room._overlay) if room._overlay else "none"))
	if room._overlay:
		room._overlay.queue_free()
		room._on_overlay_closed()
	await frames(3)
	room.open_overlay("pause")
	await frames(2)
	room._on_pause_choice("skills")
	await frames(2)
	check(room._overlay != null and script_name(room._overlay) == "skill_tree.gd", "skill tree opens from the pause menu")
	var hud_lumens := false
	for n in room.find_children("*", "Control", true, false):
		if script_name(n) == "clearing_hud.gd" and "_lumens" in n:
			hud_lumens = true
	check(not hud_lumens, "HUD has no Lumen counter")
	print("DONE fails=%d" % fails)
	quit(fails)
