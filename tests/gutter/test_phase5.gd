extends SceneTree
## Gutter rework, Haunting Lamp checks: every room spawns the right number
## of lamps with its biome's profile; a strike always comes after its full
## telegraph; hiding behind a solid prop makes the lamp lose Vesper; the
## Spine's lamp never takes an ink drop; the circles glide without jumps.
## Run like test_phase1.gd.

## room -> [haunt profile, lamps]: the four levels set their own lamp count
## (room.gd haunt_lamps) where it differs from the profile's.
const ROOMS := {"res://scenes/clearing/clearing.tscn": ["spine", 1],
	"res://scenes/world25/rooms/darkwood_1.tscn": ["inkwood", 1],
	"res://scenes/world25/rooms/shallows_pen.tscn": ["drowned", 2],
	"res://scenes/world25/rooms/wastes_gap.tscn": ["wastes", 1],
	"res://scenes/world25/rooms/arena.tscn": ["rubbing", 2]}
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


func pframes(n: int) -> void:
	for i in n:
		await physics_frame


func lamps(room: Node) -> Array:
	return room.get_children().filter(func(n): return n.is_in_group("haunt_lamp"))


## Freezes the room's monsters far away, so only the lamp is in play.
func quiet(room: Node) -> void:
	room.player._invuln = 99999.0
	for m in room.get_node("Enemies").get_children():
		m.set_physics_process(false)
		m.global_position += Vector3(0, -60, 0)


func _run() -> void:
	for path in ROOMS:
		change_scene_to_file(path)
		await frames(6)
		var want: Resource = load("res://data/haunt/%s.tres" % ROOMS[path][0])
		var count: int = ROOMS[path][1]
		var got := lamps(current_scene)
		var ok: bool = got.size() == count and got.all(func(l): return l.profile.resource_path == want.resource_path)
		var far: bool = got.all(func(l): return Vector2(l.spot.x - current_scene.player.global_position.x, l.spot.z - current_scene.player.global_position.z).length() > l.spot_radius + 3.0)
		check(ok, "%s: %d lamp(s) with %s.tres (got %d)" % [path.get_file(), count, ROOMS[path][0], got.size()])
		check(far, "%s: no lamp starts on the arrival point" % path.get_file())
	await telegraph_test()
	await hide_test()
	await spine_test()
	Engine.time_scale = 1.0
	print("DONE fails=%d" % fails)
	quit(fails)


## Lets the Rubbing Room's two lamps hunt a moving Vesper for a long while
## and checks every strike in their history against its telegraph.
func telegraph_test() -> void:
	change_scene_to_file("res://scenes/world25/rooms/arena.tscn")
	await frames(6)
	var room := current_scene
	quiet(room)
	var player = room.player
	Engine.time_scale = 4.0
	var t := 0.0
	var all := lamps(room)
	var last: Array = all.map(func(l): return l.spot)
	var max_jump := 0.0
	while t < 90.0:  # game seconds
		await physics_frame
		t += 1.0 / 120.0 * 4.0
		for i in all.size():
			max_jump = maxf(max_jump, all[i].spot.distance_to(last[i]))
			last[i] = all[i].spot
		# wander round the middle so the lamps can find and lose him
		var a := t * 0.35
		player.global_position = Vector3(cos(a) * 5.0, player.global_position.y, sin(a * 1.3) * 3.0)
		player.velocity = Vector3.ZERO
	Engine.time_scale = 1.0
	var strikes := 0
	var bad := 0
	for lamp in lamps(room):
		var h: Array = lamp.history
		for i in h.size():
			if h[i][1] == lamp.Hunt.STRIKE:
				strikes += 1
				var marked: bool = i > 0 and h[i - 1][1] == lamp.Hunt.MARK and h[i][0] - h[i - 1][0] >= lamp._telegraph() - 0.01
				if not marked:
					bad += 1
	check(strikes > 0, "the Rubbing Room's lamps struck during 90 s of hunting (%d strikes)" % strikes)
	check(bad == 0, "every strike came after its full telegraph (%d without)" % bad)
	# a physics tick here is 4 x 1/120 s; even the fastest glide onto a mark
	# (the Rubbing Room's lamps, ~18 u/s) moves well under a unit in that
	# time, while a jump would be several
	check(max_jump < 1.0, "the circles glide: no jumps (largest step per tick %.2f u)" % max_jump)


## A solid wall between the lamp and Vesper hides him: it loses him.
func hide_test() -> void:
	change_scene_to_file("res://scenes/world25/rooms/darkwood_1.tscn")
	await frames(6)
	var room := current_scene
	quiet(room)
	var player = room.player
	var lamp = lamps(room)[0]
	lamp._t = 999.0
	await pframes(2)
	var here := Vector3(0, player.global_position.y, 2.0)
	player.global_position = here
	lamp.spot = Vector3(here.x, 0, here.z - 1.0)
	lamp._strike_t = 999.0
	await pframes(30)
	check(lamp.hunt == lamp.Hunt.SEEK and lamp.sees(player.global_position), "out in the open: the lamp sees Vesper")
	# a tall wall right behind him, between him and the light (which comes
	# from up and towards the back of the room)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 6.0, 0.6)
	cs.shape = box
	wall.add_child(cs)
	room.add_child(wall)
	wall.global_position = here + Vector3(0, 3.0, -0.8)
	await pframes(4)
	lamp.spot = Vector3(here.x, 0, here.z)
	var seen_behind: bool = lamp.sees(player.global_position)
	var t := 0.0
	while t < lamp.profile.lose_after + 0.6:
		await physics_frame
		t += 1.0 / 120.0
	check(not seen_behind and lamp.hunt == lamp.Hunt.LOST, "hidden behind a solid prop: the lamp loses him (state %s)" % lamp.Hunt.keys()[lamp.hunt])
	wall.queue_free()


## The Spine's lamp only searches: the meter fills but never costs a drop.
func spine_test() -> void:
	change_scene_to_file("res://scenes/clearing/clearing.tscn")
	await frames(6)
	var room := current_scene
	quiet(room)
	var player = room.player
	player._invuln = 0.0
	var lamp = lamps(room)[0]
	lamp._t = 999.0
	var start: int = player.health
	var t := 0.0
	var marked := false
	while t < 8.0:
		await physics_frame
		t += 1.0 / 120.0
		lamp.spot = Vector3(player.global_position.x, 0, player.global_position.z)
		marked = marked or lamp.hunt == lamp.Hunt.MARK
		player._invuln = 0.0
	check(player.health == start and player.erase > 0.5, "the Spine's lamp whitens Vesper (erase %.2f) but takes no ink drop" % player.erase)
	check(not marked, "the Spine's lamp never strikes")
