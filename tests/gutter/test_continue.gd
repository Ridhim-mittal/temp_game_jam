extends SceneTree
## The main menu's CONTINUE / NEW GAME: a run left for the main menu (from a
## 2D level or a Gutter room) is saved (GameState, user://run.cfg) and
## CONTINUE puts it back: the same level, its checkpoint, its coins and story
## moments, World25's state; with no run it's greyed out; finishing the story
## or a NEW GAME forgets the run. Needs a display:
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/gutter/test_continue.gd
## Prints PASS / FAIL per check; the exit code is the number of failures.
## The player's own saved run is put back when it's done.

const MENU := "res://scenes/ui/main_menu.tscn"
const LEVEL := "res://scenes/levels/long_drop.tscn"
const ROOM := "res://scenes/world25/rooms/darkwood_1.tscn"
const RUN_FILE := "user://run.cfg"

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


func item(menu: Node, label: String) -> Dictionary:
	for it in menu._items:
		if it.label == label:
			return it
	return {}


func focused(menu: Node) -> String:
	var f := root.gui_get_focus_owner()
	for it in menu._items:
		if it.button == f:
			return it.label
	return ""


func _run() -> void:
	var backup := FileAccess.get_file_as_bytes(RUN_FILE) if FileAccess.file_exists(RUN_FILE) else PackedByteArray()
	var gs = root.get_node("GameState")
	var w25 = root.get_node("World25")

	# no run: CONTINUE is there but greyed, NEW GAME has the focus
	gs.clear_run()
	change_scene_to_file(MENU)
	await frames(30)
	var menu = current_scene
	check(item(menu, "CONTINUE") != {} and item(menu, "NEW GAME") != {} and item(menu, "PLAY") == {},
		"the main menu has CONTINUE and NEW GAME instead of PLAY")
	check(menu._why_not(item(menu, "CONTINUE")) != "" and focused(menu) == "NEW GAME",
		"with no run to continue, CONTINUE is greyed out and NEW GAME is picked (%s)" % focused(menu))

	# a 2D run: the Long Drop, a checkpoint, some coins and a story moment
	change_scene_to_file(LEVEL)
	await frames(30)
	check(gs.run_scene == LEVEL and FileAccess.file_exists(RUN_FILE), "starting a level saves the run")
	var pen = current_scene.get_node("World/Checkpoint2")
	gs.set_checkpoint(pen, pen.global_position + Vector2(0, -27))  # as checkpoint_pen.gd does
	gs.coins = 7
	gs.seen["beast_intro"] = true
	var spawn: Vector2 = gs.checkpoint_position
	change_scene_to_file(MENU)  # Pause -> Main Menu
	await frames(30)
	menu = current_scene
	check(gs.run_scene == "" and gs.coins == 0, "the menu starts afresh in memory")
	check(menu._place == "THE LONG DROP" and menu._why_not(item(menu, "CONTINUE")) == "" and focused(menu) == "CONTINUE",
		"back on the menu: CONTINUE is lit, picked, and says where (%s)" % menu._place)
	menu._choose(item(menu, "CONTINUE"))
	await frames(60)
	var p = current_scene.get_node_or_null("Player")
	check(current_scene.scene_file_path == LEVEL and p != null, "CONTINUE loads the level he left")
	check(p != null and p.global_position.distance_to(spawn) < 40.0,
		"at his checkpoint (%s, %s)" % [p.global_position if p else Vector2.ZERO, spawn])
	check(gs.coins == 7 and gs.seen.has("beast_intro") and gs.checkpoint_scene == LEVEL,
		"with the run's coins and story moments")

	# a Gutter run: World25's state comes back too
	change_scene_to_file(ROOM)
	await frames(40)
	w25.cleared["test_room"] = true
	w25.flags["test_flag"] = true
	change_scene_to_file(MENU)
	await frames(30)
	menu = current_scene
	check(w25.cleared.is_empty() and menu._place == "THE MARGINS", "from the Gutter: forgotten in memory, saved as THE MARGINS")
	menu._choose(item(menu, "CONTINUE"))
	await frames(60)
	check(current_scene.scene_file_path == ROOM and w25.cleared.has("test_room") and w25.flags.has("test_flag"),
		"CONTINUE drops him back in the room, the Gutter's story as it was")

	# finishing the story (shade_finale.gd) forgets the run
	gs.clear_run()
	change_scene_to_file(MENU)
	await frames(30)
	menu = current_scene
	check(not FileAccess.file_exists(RUN_FILE) and menu._why_not(item(menu, "CONTINUE")) != "",
		"once the story is over there is nothing to continue")

	# NEW GAME forgets a saved run
	change_scene_to_file(LEVEL)
	await frames(30)
	change_scene_to_file(MENU)
	await frames(30)
	menu = current_scene
	menu._choose(item(menu, "NEW GAME"))
	await frames(40)
	check(not FileAccess.file_exists(RUN_FILE) or gs.saved_scene() != LEVEL, "NEW GAME replaces the saved run (the opening plays)")

	# put the player's own run back
	gs.run_scene = ""
	change_scene_to_file(MENU)
	await frames(10)
	if backup.is_empty():
		if FileAccess.file_exists(RUN_FILE):
			DirAccess.remove_absolute(RUN_FILE)
	else:
		var f := FileAccess.open(RUN_FILE, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	print("DONE fails=%d" % fails)
	quit(fails)
