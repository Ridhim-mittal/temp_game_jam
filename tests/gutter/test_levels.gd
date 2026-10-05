extends SceneTree
## The four-level Gutter: the gates chain hub -> Inkwood -> Red Pen ->
## Torn Page -> Rubbing Room and back, with nothing leading to a retired
## room; each level has its monsters and lamps; spawn protection holds for
## two seconds; the sketched bridge only forms when Vesper holds Q, and he
## can then walk across it; the Eraser gets furious at half health.
## Run like test_phase1.gd (prints PASS / FAIL; exit code = failures).

const R := "res://scenes/world25/rooms/"
const HUB := "res://scenes/clearing/clearing.tscn"
const LEVELS := [R + "darkwood_1.tscn", R + "shallows_pen.tscn", R + "wastes_gap.tscn", R + "arena.tscn"]
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


## Game seconds of physics ticks.
func seconds(t: float) -> void:
	await pframes(int(ceil(t * Engine.physics_ticks_per_second)))


func _run() -> void:
	chain_test()
	roster_test()
	await protection_test()
	await bridge_test()
	await eraser_test()
	print("DONE fails=%d" % fails)
	quit(fails)


## gate_id -> [target_scene, target_gate] for every gate in a scene file.
func gates_of(path: String) -> Dictionary:
	var out := {}
	var state := (load(path) as PackedScene).get_state()
	for i in state.get_node_count():
		var props := {}
		for k in state.get_node_property_count(i):
			props[state.get_node_property_name(i, k)] = state.get_node_property_value(i, k)
		if props.has("gate_id") and props.has("target_scene"):
			out[props.gate_id] = [props.target_scene, props.get("target_gate", "")]
	return out


func chain_test() -> void:
	var want := {
		HUB: {"cave": [LEVELS[0], "east"]},
		LEVELS[0]: {"east": [HUB, "cave"], "west": [LEVELS[1], "east"]},
		LEVELS[1]: {"east": [LEVELS[0], "west"], "west": [LEVELS[2], "east"]},
		LEVELS[2]: {"east": [LEVELS[1], "west"], "west": [LEVELS[3], "east"]},
		LEVELS[3]: {"east": [LEVELS[2], "west"]},
	}
	for path in want:
		var got := gates_of(path)
		check(got == want[path], "%s: gates %s" % [path.get_file(), got])


func enemy_kinds(path: String) -> Dictionary:
	var room: Node = (load(path) as PackedScene).instantiate()
	var kinds := {}
	for m in room.get_node("Enemies").get_children():
		var k: String = m.scene_file_path.get_file().get_basename()
		kinds[k] = kinds.get(k, 0) + 1
	room.free()
	return kinds


func roster_test() -> void:
	var l1 := enemy_kinds(LEVELS[0])
	var all_there: bool = ["scribble", "crumple", "smudge", "inkwell", "crossed_out", "scribble_diver"].all(func(k): return l1.has(k))
	check(all_there and l1.values().reduce(func(a, b): return a + b) <= 8, "level 1: every ordinary monster, a handful in all %s" % l1)
	var l2 := enemy_kinds(LEVELS[1])
	check(l2.keys() == ["red_pen"], "level 2: the Red Pen alone %s" % l2)
	var l3 := enemy_kinds(LEVELS[2])
	check(not l3.has("inkwell") and not l3.has("crumple") and not l3.has("scribble_diver"),
		"level 3: no Inkwells, Crumples or divers %s" % l3)
	var arena: Node = (load(LEVELS[3]) as PackedScene).instantiate()
	var eraser: Node = arena.get_node("Enemies/Eraser1")
	check(eraser.hp >= 24 and eraser.lunge_speed > 11.0, "level 4: a tougher Eraser (hp %d, lunge %.1f)" % [eraser.hp, eraser.lunge_speed])
	arena.free()


func protection_test() -> void:
	change_scene_to_file(LEVELS[0])
	await frames(4)
	var player = current_scene.player
	var hp: int = player.health
	check(player.is_protected(), "arriving in a room: spawn protection is on")
	player.take_damage(1, player.global_position + Vector3(1, 0, 0))
	check(player.health == hp, "a hit during spawn protection does nothing (%d -> %d)" % [hp, player.health])
	# a lamp's light on him doesn't fill the erase meter either
	var lamp = current_scene.get_children().filter(func(n): return n.is_in_group("haunt_lamp"))[0]
	lamp._update_erase(player, true, 0.5)
	check(lamp.erase == 0.0, "a lamp's light can't take hold during spawn protection (erase %.2f)" % lamp.erase)
	await seconds(2.1)
	check(not player.is_protected(), "spawn protection is over after 2 s")
	player._invuln = 0.0
	player.take_damage(1, player.global_position + Vector3(1, 0, 0))
	check(player.health == hp - 1, "after it, hits land again (%d -> %d)" % [hp, player.health])


## Puts Vesper at `at` (on the floor), still.
func place(player: Node, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player._snap_visuals()
	await pframes(4)


func bridge_test() -> void:
	change_scene_to_file(LEVELS[2])
	await frames(4)
	var room := current_scene
	for m in room.get_node("Enemies").get_children():
		m.set_physics_process(false)
		m.global_position += Vector3(0, -60, 0)
	for l in get_nodes_in_group("haunt_lamp"):
		l.queue_free()
	var player = room.player
	var bridge = get_first_node_in_group("drawn_bridge")
	var gap: float = bridge.length * 0.5
	player.fuel = player.max_fuel
	# stand at the east end, Ember glowing, for a few seconds: nothing forms
	await place(player, Vector3(gap + 0.9, 0.05, 0))
	await seconds(2.0)
	check(bridge.solid_count() == 0, "the sketch doesn't form on its own, even in the Ember's glow (%d planks)" % bridge.solid_count())
	# hold Q at the edge: ink runs out along the bridge, for Ember, not a Flash
	var fuel0: float = player.fuel
	await physics_frame
	Input.action_press("flash")
	await seconds(1.6)
	Input.action_release("flash")
	await pframes(2)
	var n: int = bridge.solid_count()
	var spent: float = fuel0 - player.fuel
	check(n > 0 and n < bridge._planks.size(), "holding Q inks part of the bridge (%d of %d planks)" % [n, bridge._planks.size()])
	check(absf(spent - n * bridge.ink_cost) < 0.01, "it costs %.0f Ember a plank, no Flash (spent %.0f)" % [bridge.ink_cost, spent])
	await seconds(1.0)
	check(bridge.solid_count() == n, "inked planks stay after letting go (%d)" % bridge.solid_count())
	# walk out to the end of the ink and hold Q again until it's done
	Input.action_press("move_left")
	await seconds(0.25)
	Input.action_release("move_left")
	await seconds(0.3)
	var tries := 0
	while not bridge.finished() and tries < 6:
		tries += 1
		# step to the last inked plank, then ink on from there
		var inked: Array = bridge._planks.filter(func(p): return p.inked)
		var last: Dictionary = inked.reduce(func(a, b): return a if a.t > b.t else b)
		await place(player, bridge.to_global(last.center) + Vector3(0, 0.2, 0))
		await physics_frame
		Input.action_press("flash")
		await seconds(1.6)
		Input.action_release("flash")
		await pframes(2)
	check(bridge.finished(), "a few holds of Q ink the whole bridge (%d more after the first)" % tries)
	# and he can walk across to the far island
	await place(player, Vector3(gap + 0.9, 0.05, 0))
	var hp: int = player.health
	Input.action_press("move_left")
	await seconds(2.4)
	Input.action_release("move_left")
	await seconds(0.3)
	check(player.global_position.x < -gap - 0.5 and player.health == hp and player.global_position.y > -0.5,
		"Vesper walks across the inked bridge (x %.1f, y %.2f, hp %d -> %d)" % [player.global_position.x, player.global_position.y, hp, player.health])
	# out of Ember: nothing inks
	change_scene_to_file(LEVELS[2])
	await frames(4)
	player = current_scene.player
	bridge = get_first_node_in_group("drawn_bridge")
	await place(player, Vector3(gap + 0.9, 0.05, 0))
	player.fuel = 2.0
	await physics_frame
	Input.action_press("flash")
	await seconds(0.8)
	Input.action_release("flash")
	await pframes(2)
	check(bridge.solid_count() == 0, "with no Ember left, Q inks nothing (%d planks)" % bridge.solid_count())
	# away from the bridge, Q is still a Flash
	await place(player, Vector3(gap + 6.0, 0.05, -3.0))
	player.fuel = player.max_fuel
	await physics_frame
	Input.action_press("flash")
	await pframes(3)
	Input.action_release("flash")
	await pframes(2)
	check(absf(player.max_fuel - player.fuel - player.flash_cost) < 0.01, "away from the bridge, Q still Flashes (spent %.0f)" % (player.max_fuel - player.fuel))


func eraser_test() -> void:
	change_scene_to_file(LEVELS[3])
	await frames(4)
	var eraser = current_scene.get_node("Enemies/Eraser1")
	check(not eraser.furious, "the Eraser starts calm")
	eraser.health = int(eraser.hp * 0.5)
	await pframes(3)
	check(eraser.furious, "at half health it turns furious (charges twice)")
