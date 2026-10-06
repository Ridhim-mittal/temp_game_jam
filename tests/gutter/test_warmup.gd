extends SceneTree
## The browser's room warm-up (room_warmup.gd), forced on here: a room's
## meshes are hidden and shown back a few materials at a time while the cover
## stays up and the room waits, then everything is as it was: layers, light
## and camera masks, the room's own camera, the pause. Through World25's ink
## wipe, down the gutter, and loaded straight (its own cover). Also the
## cutscenes' background loading (scene_prefetch.gd). Run like test_phase1.gd.

const RoomWarmup = preload("res://scripts/world25/room_warmup.gd")
const ScenePrefetch = preload("res://scripts/core/scene_prefetch.gd")
const HUB := "res://scenes/clearing/clearing.tscn"
const ROOM := "res://scenes/world25/rooms/darkwood_1.tscn"
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


func until(cond: Callable, limit: int) -> bool:
	for i in limit:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func geometry() -> Array:
	return current_scene.find_children("*", "GeometryInstance3D", true, false) if current_scene else []


func hidden_count() -> int:
	return geometry().filter(func(g): return g.layers & RoomWarmup.HIDE).size()


func room_camera_current() -> bool:
	var cam := root.get_viewport().get_camera_3d()
	return cam != null and cam.is_in_group("camera")


func masks_clean() -> bool:
	for l in current_scene.find_children("*", "Light3D", true, false):
		if not (l.light_cull_mask & RoomWarmup.HIDE):
			return false
	for c in current_scene.find_children("*", "Camera3D", true, false):
		if not (c.cull_mask & RoomWarmup.HIDE):
			return false
	return true


## After a warm-up: nothing hidden, everything put back.
func after(how: String) -> void:
	check(hidden_count() == 0, how + ": every mesh is back on its own layers")
	check(masks_clean(), how + ": lights and cameras see every layer again")
	check(room_camera_current() and current_scene.get_node_or_null("Warmup") == null,
		how + ": the room's own camera, the warm-up gone")
	check(not paused, how + ": the room runs")


func _run() -> void:
	var world := root.get_node("World25")
	RoomWarmup.force = true

	# 1. the ink wipe (the fall into the Margins lands this way)
	ScenePrefetch.start(HUB)
	check(ResourceLoader.load_threaded_get_status(HUB) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"a cutscene can start loading the next scene in the background")
	world.go(HUB, "")
	var warming := await until(func(): return current_scene and current_scene.scene_file_path == HUB and current_scene.warming, 600)
	check(warming, "the hub warms up behind the ink")
	await frames(6)
	check(paused and world._wipe.visible and world._wait.visible, "meanwhile the room waits, under the cover, \"INKING\" on it")
	check(hidden_count() > 0 and root.get_viewport().get_camera_3d().name == "WarmupCamera",
		"the meshes come back a few at a time under a camera over the whole room (%d still hidden)" % hidden_count())
	var warmed := await until(func(): return not current_scene.warming, 3000)
	check(warmed, "and it finishes")
	await until(func(): return not world.transitioning, 300)
	after("ink wipe")
	check(not world._wipe.visible and not world._wait.visible, "ink wipe: the cover lifts")

	# 2. down the gutter, into the next room
	world.go(ROOM, "", true)
	warming = await until(func(): return current_scene and current_scene.scene_file_path == ROOM and current_scene.warming, 900)
	check(warming, "a room reached down the gutter warms up too")
	var held := await until(func():
		for n in root.find_children("*", "Control", true, false):
			if n.get_script() and str(n.get_script().resource_path).ends_with("gutter_transition.gd"):
				return n._held
		return false, 300)
	check(held, "the gutter's dark holds while it does")
	await until(func(): return not world.transitioning, 3000)
	after("gutter")

	# 3. loaded straight (CONTINUE, a retry): its own cover
	change_scene_to_file(ROOM)
	await frames(3)
	var cover := current_scene.get_node_or_null("Warmup")
	check(cover != null and cover._cover != null and paused, "loaded straight: it covers the room itself and pauses it")
	await until(func(): return not current_scene.warming, 3000)
	await frames(2)
	after("straight")

	RoomWarmup.force = false
	print("%d failure(s)" % fails)
	quit(fails)
