extends SceneTree
## The end of the Gutter: beating the Eraser in the Rubbing Room plays the
## capture (light_capture.gd: the lamps hunt Vesper down, one catches him,
## Shade's hand hooks him and hauls him up) and the climb up the comic page
## (page_climb.gd), which drops him into Shade's City, the live level, with
## everything handed back (controls, pause, the canvas transform, World25).
## Enter skips the lot. Run like test_phase1.gd.

const ARENA := "res://scenes/world25/rooms/arena.tscn"
const CITY := "res://scenes/levels/shades_city.tscn"
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


## Waits (up to `limit` frames) for `cond` to hold; returns whether it did.
func until(cond: Callable, limit: int) -> bool:
	for i in limit:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func capture() -> Node:
	return current_scene.get_node_or_null("LightCapture") if current_scene else null


func climb() -> Node:
	for n in root.get_children():
		if n is CanvasLayer and n.get_child_count() > 0 and n.get_child(0).get_script() \
				and str(n.get_child(0).get_script().resource_path).ends_with("page_climb.gd"):
			return n.get_child(0)
	return null


## Into the arena and clear it: the Eraser goes, the room notices.
func clear_arena() -> Node:
	change_scene_to_file(ARENA)
	await frames(8)
	var room := current_scene
	for e in room.get_node("Enemies").get_children():
		e.queue_free()
	return room


func _run() -> void:
	var room = await clear_arena()
	check(room.ending_on_clear.ends_with("light_capture.tscn") and room.cutscene_on_clear == "",
		"the Rubbing Room ends with the capture, not a cut to cs_reveal")
	var started := await until(func(): return capture() != null, 900)
	check(started, "the capture starts in the room once its clear captions are done")
	var cap := capture()
	var player = room.player
	var world := root.get_node("World25")
	check(player.cutscene and world.transitioning, "it takes the controls (and holds off pause and the shop)")
	var hp: int = player.health
	player.take_damage(1, player.global_position + Vector3(1, 0, 0))
	check(player.health == hp, "no damage while it plays")
	await until(func(): return cap._t > cap.T_ON - 0.4, 400)
	check(get_nodes_in_group("haunt_lamp").is_empty(), "the Haunting Lamps have blinked out")
	check(cap._braziers.all(func(b): return not b.lit), "the braziers are snuffed")
	await until(func(): return cap._t > cap.T_HUNT, 400)
	check(cap._lamps.all(func(b): return b.landed), "all %d of the Writer's lamps have slammed down" % cap.LAMPS)
	var p0: Vector3 = player.global_position
	await until(func(): return cap._t > cap.T_DASH + 0.2, 400)
	check(player.global_position.distance_to(p0) > 1.0, "he runs and dashes from them")
	await until(func(): return cap._t > cap.T_CATCH + 0.2, 400)
	check(cap._catch.landed and Vector2(cap._catch.pos.x - player.global_position.x, cap._catch.pos.z - player.global_position.z).length() < 0.5,
		"the catching beam lands right on him")
	await until(func(): return cap._t > cap.T_HOOK - 0.05, 400)
	check(player.cutscene_hold and player.global_position.y > p0.y + 1.5, "the light lifts him off the floor (%.2f)" % (player.global_position.y - p0.y))
	check(cap._hand_quad.visible and cap._nib.distance_to(player.global_position + Vector3(0, cap.COLLAR, 0)) < 1.5,
		"Shade's hand has come down the beam to his collar")
	await until(func(): return cap._t > cap.T_YANK + 0.3, 400)
	check(player.global_position.y > p0.y + 8.0, "one yank and he's gone up the light")
	var on_page := await until(func(): return climb() != null, 400)
	check(on_page and paused, "then the page: the climb runs over the paused room")
	var fx := climb()
	var swapped := await until(func(): return current_scene and current_scene.scene_file_path == CITY, 600)
	check(swapped, "Shade's City is swapped in behind the page during the climb")
	await until(func(): return fx._stage == 2, 100)
	var p2 := get_first_node_in_group("player") as Node2D
	check(fx._stage == 2 and paused and p2 and not p2.visible, "the city panel is a window onto the level, paused, its Vesper held back")
	check(not world.transitioning and world.current_room == "", "the Gutter's run is over (World25 reset)")
	var dropped := await until(func(): return fx._dropped, 600)
	check(dropped and not paused and p2.visible, "the hand drops him: the level runs, its Vesper is back")
	var gone := await until(func(): return climb() == null, 600)
	check(gone and root.get_viewport().global_canvas_transform == Transform2D.IDENTITY,
		"the page is gone and the canvas transform is back to normal")
	var landed := await until(func(): return p2.is_on_floor(), 300)
	check(landed and absf(p2.global_position.y - 574.0) < 4.0, "he lands on the street (%.0f)" % p2.global_position.y)

	# Enter skips it all
	room = await clear_arena()
	await until(func(): return capture() != null, 900)
	await frames(20)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventKey.new()
	up.keycode = KEY_ENTER
	Input.parse_input_event(up)
	var skipped := await until(func(): return current_scene and current_scene.scene_file_path == CITY and climb() == null, 400)
	p2 = get_first_node_in_group("player") as Node2D
	check(skipped and not paused and p2 and p2.visible, "Enter skips straight into Shade's City")
	check(root.get_viewport().global_canvas_transform == Transform2D.IDENTITY, "nothing left scaled after a skip")
	print("%d failure(s)" % fails)
	quit(fails)
