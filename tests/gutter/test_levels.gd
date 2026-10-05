extends SceneTree
## The four-level Gutter: the gates chain hub -> Inkwood -> Red Pen ->
## Torn Page -> Rubbing Room, with nothing leading to a retired room, and
## every way in is one-way (entry_only: it never opens, even once the room
## is cleared); the hub's way on stands at the back of the terrace and
## walking out through it travels down the gutter into the Inkwood
## (gutter_transition.gd); each level has its monsters and lamps; the Half-Drawn swing
## a blade that hurts, stagger when hit mid-windup and fall in five hits;
## spawn protection holds for two seconds; the sketched bridge only forms
## when Vesper holds right click, and he can then walk across it; the Eraser gets
## furious at half health.
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
	await one_way_test()
	await half_drawn_test()
	await scribble_test()
	await hub_test()
	await gutter_test()
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
	var hub := enemy_kinds(HUB)
	check(hub.keys() == ["scribble"] and hub.scribble >= 6, "level 1, the hub: Scribbles all over it %s" % hub)
	var l1 := enemy_kinds(LEVELS[0])
	check(l1.size() == 2 and l1.get("half_drawn", 0) >= 3 and l1.get("half_drawn", 0) <= 5 and l1.get("scribble", 0) >= 3,
		"level 1, second room: a few Half-Drawn and a pack of Scribbles %s" % l1)
	var l2 := enemy_kinds(LEVELS[1])
	check(l2.keys() == ["red_pen"], "level 2: the Red Pen alone %s" % l2)
	var l3 := enemy_kinds(LEVELS[2])
	check(not l3.has("inkwell") and not l3.has("crumple") and not l3.has("scribble_diver"),
		"level 3: no Inkwells, Crumples or divers %s" % l3)
	var arena: Node = (load(LEVELS[3]) as PackedScene).instantiate()
	var eraser: Node = arena.get_node("Enemies/Eraser1")
	check(eraser.hp >= 24 and eraser.lunge_speed > 11.0, "level 4: a tougher Eraser (hp %d, lunge %.1f)" % [eraser.hp, eraser.lunge_speed])
	arena.free()


## Every way in is entry_only and stays shut, even once the room is cleared;
## the way on opens.
func one_way_test() -> void:
	for path in LEVELS:
		var state := (load(path) as PackedScene).get_state()
		var entries := []
		for i in state.get_node_count():
			for k in state.get_node_property_count(i):
				if state.get_node_property_name(i, k) == "entry_only" and state.get_node_property_value(i, k):
					entries.append(str(state.get_node_name(i)))
		check(entries == ["GateEast"], "%s: the way in (east) is one-way %s" % [path.get_file(), entries])
	change_scene_to_file(LEVELS[0])
	await frames(4)
	var room := current_scene
	for m in room.get_node("Enemies").get_children():
		m.queue_free()
	await frames(2)
	room._on_cleared()
	await seconds(1.5)
	var east = room.get_node("GateEast")
	var west = room.get_node("GateWest")
	check(west.is_open and not east.is_open and not east._wall_shape.disabled,
		"cleared: the way on opens, the way back stays shut (west %s, east %s)" % [west.is_open, east.is_open])
	root.get_node("World25").cleared.clear()  # its monsters come back for the next test


## The Half-Drawn: only the blade hurts, a swing lands on a Vesper standing
## in front, a hit mid-windup staggers it, five hits finish it.
func half_drawn_test() -> void:
	change_scene_to_file(LEVELS[0])
	await frames(4)
	var room := current_scene
	for l in get_nodes_in_group("haunt_lamp"):
		l.queue_free()
	var ghosts: Array = room.get_node("Enemies").get_children()
	var g = ghosts[0]
	for other in ghosts.slice(1):
		other.queue_free()
	var player = room.player
	await seconds(2.1)  # past spawn protection
	g.global_position = Vector3(0, 0.05, 0)
	g.state = g.State.DRIFT  # a fresh start: not already mid-swing at its old spot
	g._cd = 0.0
	player.global_position = Vector3(1.5, 0.05, 0)
	player.velocity = Vector3.ZERO
	player._snap_visuals()
	player._invuln = 0.0
	var hp: int = player.health
	check(not g.is_harmful(), "touching a Half-Drawn doesn't hurt (only its blade does)")
	check(player._q_prompt != null and not g.revealed, "an unseen Half-Drawn near: \"HOLD RIGHT CLICK TO SEE THEM\" over Vesper")
	var swung := false
	for i in 240:  # up to 4 s
		await physics_frame
		player.global_position = Vector3(1.5, 0.05, 0)
		if g.state == g.State.WINDUP:
			swung = true
		if player.health < hp:
			break
	check(swung and player.health == hp - 2, "it winds up, swings and its blade takes an ink bottle (%d -> %d half bottles)" % [hp, player.health])
	player._invuln = 999.0
	g.set_physics_process(false)
	g.global_position = Vector3(0, 0.05, 0)
	var landed: bool = g.take_hit(1, Vector3(-1, 0, 0))
	check(not landed and g.health == g.hp, "out of the Ember's light the sword goes through it (landed %s)" % landed)
	g.set_physics_process(true)
	player.fuel = player.max_fuel
	await seconds(0.3)  # out of the stagger from the blade
	Input.action_press("flash")
	await pframes(6)
	check(g.revealed and player._q_prompt == null, "holding right click, it inks in (revealed %s) and the prompt goes" % g.revealed)
	g.state = g.State.WINDUP
	g._timer = g.windup_time
	g.take_hit(1, Vector3(-1, 0, 0))
	check(g.state == g.State.RECOVER, "in the light, a hit mid-windup staggers it out of the swing")
	for i in g.hp - 1:
		g.take_hit(1, Vector3(-1, 0, 0))
	Input.action_release("flash")
	check(g.dead and g.hp == 5, "five hits in the light and it's unwritten (hp %d)" % g.hp)


## Six hearts, and the hub's shrine is Vesper's.
## The Scribbles (scribble.gd): touching one is safe, only the claw hurts;
## a windup shows the red tell on the floor; the claw hits Vesper along its
## line, not beside it and not mid-dash; raising the Ember on one winding up
## curls it up (stunned); at most two wind up at once; three hits finish one
## and it stays down in a story room.
func scribble_test() -> void:
	change_scene_to_file(HUB)
	await frames(4)
	var room := current_scene
	for l in get_nodes_in_group("haunt_lamp"):
		l.queue_free()
	var all: Array = room.get_node("Enemies").get_children()
	var s = all[0]
	for o in all.slice(1):
		o.set_physics_process(false)
		o.global_position += Vector3(0, -60, 0)
	var player = room.player
	await seconds(2.1)  # past spawn protection
	s.global_position = Vector3(0, 0.05, 3)
	s.velocity = Vector3.ZERO
	s.state = s.State.CHASE
	s._claw_cd = 0.0
	await place(player, Vector3(2.0, 0.05, 3))
	player._invuln = 0.0
	var hp: int = player.health
	check(not s.is_harmful(), "touching a Scribble doesn't hurt (only its claw does)")
	var told := false
	var hit := false
	for i in 360:  # up to 3 s
		await physics_frame
		if s.state == s.State.WINDUP and s._aim.visible:
			told = true
		if player.health < hp:
			hit = true
			break
	check(told, "a Scribble winding up draws its red tell on the floor")
	check(hit and player.health == hp - 1, "its claw lands (%d -> %d)" % [hp, player.health])
	await seconds(1.2)
	s.set_physics_process(false)
	s.global_position = Vector3(0, 0.05, 3)
	await place(player, Vector3(2.0, 0.05, 3))
	s._claw_dir = Vector3(1, 0, 0)
	player._invuln = 0.0
	hp = player.health
	player._dash_timer = 0.3
	s._claw_hits()
	player._dash_timer = 0.0
	check(player.health == hp, "dashing through the claw dodges it")
	s._claw_dir = Vector3(0, 0, 1)
	s._claw_hits()
	check(player.health == hp, "the claw misses Vesper beside its line")
	# light parry: raise the Ember on a windup
	s.set_physics_process(true)
	s.state = s.State.CHASE
	s._in_light = false
	s._start_windup(Vector3(1, 0, 0))
	player.fuel = player.max_fuel
	Input.action_press("flash")
	await pframes(8)
	check(s.state == s.State.STUNNED and not s._aim.visible, "raising the Ember on a windup curls it up (state %d)" % s.state)
	Input.action_release("flash")
	await pframes(4)
	# they take turns
	await seconds(0.4)
	all[1].add_to_group("scribble_claw")
	all[2].add_to_group("scribble_claw")
	check(not s._may_claw(), "two Scribbles winding up already: a third waits its turn")
	all[1].remove_from_group("scribble_claw")
	all[2].remove_from_group("scribble_claw")
	check(s._may_claw(), "...and goes when one is done")
	for i in 3:
		s.take_hit(1, Vector3(1, 0, 0))
	check(s.dead and not s.is_in_group("enemy"), "three hits finish a Scribble")
	await seconds(0.6)
	check(s.dead, "a beaten Scribble stays down in a story room")


## Six ink bottles (12 half bottles, ink_bottles.gd), and the hub's shrine is Vesper's.
func hub_test() -> void:
	change_scene_to_file(HUB)
	await frames(6)
	var player = current_scene.player
	var hud: Node = current_scene.find_children("*", "Control", true, false).filter(func(n): return n.has_method("_draw_heals"))[0]
	check(player.max_health == 12 and hud.maximum == 12 and hud._bottles.count() == 6, "six ink bottles (max %d half bottles, HUD %d, %d bottles)" % [player.max_health, hud.maximum, hud._bottles.count()])
	var altar: Node = current_scene.get_node("Props/Altar")
	check(altar.find_child("Statue", true, false) != null, "the hub's shrine holds a statue of Vesper")


## The hub's way on stands at the back of the terrace (where the skill tree
## was), a gutter between two upright panels; walking out through it plays
## the trip down the gutter (gutter_transition.gd) and arrives in the
## Inkwood at its way in.
func gutter_test() -> void:
	change_scene_to_file(HUB)
	await frames(6)
	var room := current_scene
	var gate = room.get_node("Props/CaveGate")
	check(gate.global_position.distance_to(Vector3(0, 2.88, -30.2)) < 0.1, "the hub's way on is at the back of the terrace %s" % gate.global_position)
	check(room.find_child("CaveDoor", true, false) == null, "no archway portal by the stairs any more")
	gate.open(false)
	var world = root.get_node("World25")
	var player = room.player
	player.global_position = gate.global_transform * Vector3(0, 0.1, -1.8)
	player.velocity = Vector3.ZERO
	await pframes(3)
	var fx: Node = null
	for n in world._layer.get_children():
		if n.has_signal("finished"):
			fx = n
	check(world.transitioning and fx != null, "walking out through the open gutter starts the trip down the gutter")
	check(paused, "the game holds still while the page covers the screen")
	var waited := 0
	while world.transitioning and waited < 2400:
		await process_frame
		waited += 1
	check(not world.transitioning and current_scene.scene_file_path == LEVELS[0], "... and comes out in the Inkwood (%s)" % current_scene.scene_file_path)
	check(not paused and not is_instance_valid(fx), "then the room runs again and the page is gone")
	var east = current_scene.get_node("GateEast")
	var at: Vector3 = current_scene.player.global_position
	check(at.distance_to(east.arrival_point()) < 1.5, "Vesper arrives at the Inkwood's way in (%s)" % at)
	check(current_scene.player.is_protected(), "spawn protection still holds after the page opens")


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
	# hold right click at the edge: ink runs out along the bridge for a little Ember a
	# plank (once it has inked all it can reach, the raised Ember drains as usual)
	var fuel0: float = player.fuel
	var spent := -1.0
	var was_inking := false
	await physics_frame
	Input.action_press("flash")
	for i in int(1.6 * Engine.physics_ticks_per_second):
		await physics_frame
		if player._inking != null:
			was_inking = true
		elif was_inking and spent < 0.0:
			spent = fuel0 - player.fuel
	Input.action_release("flash")
	await pframes(2)
	var n: int = bridge.solid_count()
	check(n > 0 and n < bridge._planks.size(), "holding right click inks part of the bridge (%d of %d planks)" % [n, bridge._planks.size()])
	check(absf(spent - n * bridge.ink_cost) < 0.5, "it costs %.0f Ember a plank (spent %.1f inking)" % [bridge.ink_cost, spent])
	await seconds(1.0)
	check(bridge.solid_count() == n, "inked planks stay after letting go (%d)" % bridge.solid_count())
	# walk out to the end of the ink and hold right click again until it's done
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
	check(bridge.finished(), "a few holds of right click ink the whole bridge (%d more after the first)" % tries)
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
	check(bridge.solid_count() == 0, "with no Ember left, right click inks nothing (%d planks)" % bridge.solid_count())
	# away from the bridge, Q raises the Ember: it drains, and comes back once lowered
	for m in current_scene.get_node("Enemies").get_children():
		m.queue_free()
	for l in get_nodes_in_group("haunt_lamp"):
		l.queue_free()
	player._invuln = 999.0
	await place(player, Vector3(gap + 6.0, 0.05, -3.0))
	await ember_test(player)


## Hold right click: the Ember rises (a bigger light, the Writer's kind), drains, and
## comes back after letting go; run dry, it gutters out until it has
## `relight_at` again. Right click is the light, Shift dashes.
func ember_test(player: Node) -> void:
	var shift_dash := InputMap.action_get_events("dash").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SHIFT)
	var rmb_dash := InputMap.action_get_events("dash").any(func(e): return e is InputEventMouseButton)
	var rmb_light := InputMap.action_get_events("flash").any(func(e): return e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT)
	check(shift_dash and not rmb_dash and rmb_light, "Shift dashes and right click is the light (dash %s, light %s)" % [shift_dash, rmb_light])
	player.fuel = 80.0
	var r0: float = player.glow_radius()
	await physics_frame
	Input.action_press("flash")
	await seconds(1.0)
	var raised: bool = player.ember_raised and player.monster_light
	var r1: float = player.glow_radius()
	var drained: float = 80.0 - player.fuel
	Input.action_release("flash")
	check(raised and r1 > r0 + 1.0, "holding right click raises the Ember: a bigger light, the Writer's kind (radius %.1f -> %.1f)" % [r0, r1])
	check(drained > 12.0 and drained < 20.0, "it drains while raised (%.1f in 1 s), with no Flash" % drained)
	var low: float = player.fuel
	await seconds(1.6)
	check(not player.ember_raised and player.fuel > low + 10.0, "let go, it comes back on its own (%.1f -> %.1f)" % [low, player.fuel])
	player.fuel = 3.0
	await physics_frame
	Input.action_press("flash")
	await seconds(0.5)
	var guttered: bool = player._snuffed and not player.ember_raised
	Input.action_release("flash")
	await physics_frame
	Input.action_press("flash")
	await seconds(0.3)
	var stays_down: bool = not player.ember_raised
	Input.action_release("flash")
	await seconds(2.5)
	check(guttered and stays_down and not player._snuffed and player.fuel >= player.relight_at,
		"run dry, it gutters out and won't rise until it has come back (fuel %.0f)" % player.fuel)


func eraser_test() -> void:
	change_scene_to_file(LEVELS[3])
	await frames(4)
	var eraser = current_scene.get_node("Enemies/Eraser1")
	check(not eraser.furious, "the Eraser starts calm")
	eraser.health = int(eraser.hp * 0.5)
	await pframes(3)
	check(eraser.furious, "at half health it turns furious (charges twice)")
