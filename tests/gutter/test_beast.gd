extends SceneTree
## The end of the Long Drop: the Scribbled Beast (scribbled_beast.gd,
## beast_arena.gd), the Eraser's chase (eraser_chase.gd) and the fall into
## the Margins (margins_fall.gd). Walking in starts the intro (it comes out of
## the gutter between the columns) and takes the controls; Enter skips it into
## the fight; the shield blocks a hit from the side it faces; a lit lantern
## turns the shield round and pins it for a moment, a hit from the other side
## lands, then it lobs a glob that snuffs the lantern (a slashed glob
## doesn't); touching it only hurts mid-charge; a rush into the wall dazes it;
## half health starts phase two; at 0 it dies slowly; Shade's lines (Vesper
## was meant to die here), the Eraser slams down, the border rips: RUN; a
## plain run reaches the gutter, he leaps, falls and lands in the 2.5D hub.
## Retries: the chase restarts from its checkpoint, the fight gets the short
## intro.
## Run like test_phase1.gd (prints PASS / FAIL; exit code = failures).

const LEVEL := "res://scenes/levels/long_drop.tscn"
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		fails += 1


func pframes(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(t: float) -> void:
	await pframes(int(ceil(t * Engine.physics_ticks_per_second)))


func press_enter() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	root.push_input(ev)


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.reset()
	change_scene_to_file(LEVEL)
	await pframes(10)
	var arena = current_scene.get_node("World/BeastArena")
	var beast = current_scene.get_node("Enemies/ScribbledBeast")
	var player = current_scene.get_node("Player")
	var lw = current_scene.get_node("World/ArenaLanternW")
	var le = current_scene.get_node("World/ArenaLanternE")
	var music = root.get_node("Music")
	check(music.current == "deep", "the Long Drop plays its own quiet tune (%s)" % music.current)
	check(arena.phase == arena.Phase.WAIT and not beast.visible and beast.collision_layer == 0,
		"before Vesper comes in: the Beast is down in the gutter, out of sight and not solid")
	player.global_position = Vector2(arena.trigger_x + 60, arena.global_position.y - 30)
	await pframes(30)
	check(arena.phase == arena.Phase.INTRO and player.cutscene, "walking in starts the intro and takes the controls")
	var hud: CanvasLayer = current_scene.get_node("UI")
	await seconds(1.0)
	check(not hud.visible, "the HUD hides behind the letterbox")
	await seconds(2.6)  # 3.6 s in: it's coming up out of the gutter between the columns
	check(arena.gap_open > 0.9 and beast.visible and beast.shield_lift > 0.9 and beast.outline.scale.x < 0.8,
		"the panel splits on the gutter and the Beast comes up out of it, small and far, shield over its head")
	press_enter()
	await pframes(6)
	check(arena.phase == arena.Phase.FIGHT and not player.cutscene, "Enter skips the rest: fight")
	check(music.current == "beast", "and the fight has its music")
	check(beast.state == beast.State.IDLE and beast.collision_layer == 4 and beast.outline.scale.x == 1.0, "the Beast is out, full size and solid")
	check(not lw.lit and not le.lit and arena.gap_open == 0.0, "its darkness put both lanterns out, and the gutter shut behind it")
	await seconds(1.0)
	check(not arena._barrier_shape.disabled and not arena._east_shape.disabled, "walls of scribble and ink seal the arena")
	check(hud.visible, "the HUD is back")
	# keep it still for the checks
	beast._cd = 99.0
	player._invuln_timer = 999.0
	player.global_position = beast.global_position + Vector2(-260, 70)
	await seconds(1.2)
	var hp: int = beast.health
	beast.take_hit(1, Vector2.RIGHT, player.global_position)
	check(beast.health == hp, "a hit from the side its shield faces is blocked")
	# light a lantern on the far side: the shield turns to it
	le.lit = true
	beast._lamp_time = -99.0  # held off from throwing, for the checks
	await seconds(1.4)
	check(beast.guard > -PI * 0.5 and beast.guard < PI * 0.5, "a lit lantern: the shield swings round to the light (%.2f)" % beast.guard)
	beast.take_hit(1, Vector2.RIGHT, player.global_position)
	check(beast.health == hp - 1, "and a hit from Vesper's side lands (%d -> %d)" % [hp, beast.health])
	beast.state = beast.State.IDLE
	beast._cd = 0.0
	await seconds(0.8)
	check(beast.state == beast.State.IDLE and absf(beast.velocity.x) < 5.0, "while the lantern burns it cowers where it stands: no walking, no attacks")
	check(beast.max_hp >= 14 and beast.max_hp <= 18 and beast.get_damage() == 1.0, "%d health; its rush costs half a bottle" % beast.max_hp)
	# ...but only for a moment: then it throws ink at the light
	beast._lamp_time = 0.0
	await seconds(beast.snuff_delay + 1.8)
	check(not le.lit, "after a moment it lobs an ink glob at the lantern: SPLUT, out")
	# a slashed glob doesn't snuff it
	beast.state = beast.State.IDLE
	beast._cd = 99.0
	await seconds(1.0)  # its own glob has landed
	le.lit = true
	beast._lamp_time = -99.0
	var g = preload("res://scripts/enemies/beast_glob.gd").throw(self, beast._hand_world(), le)
	await pframes(3)
	g.take_hit(1, Vector2.RIGHT, g.global_position)
	await seconds(1.2)
	check(le.lit, "slash the glob out of the air and the light stays on")
	le.lit = false
	# walking into it is safe; only its charge hurts to touch
	beast.state = beast.State.IDLE
	beast._cd = 99.0
	await pframes(4)
	player._invuln_timer = 0.0
	var php: float = player.health
	player.global_position = beast.global_position + Vector2(0, 70)
	await seconds(0.5)
	check(player.health == php and not beast.is_in_group("enemy"), "brushing past it, or standing in it, doesn't hurt")
	player._invuln_timer = 999.0
	player.global_position = beast.global_position + Vector2(-260, 70)
	# a rush into the wall dazes it: shield down, hits land from anywhere
	beast.state = beast.State.RUSH
	beast._timer = 3.0
	beast.facing = 1
	await pframes(2)
	check(beast.is_in_group("enemy"), "but its charge does")
	var dazed := false
	for i in 600:
		await physics_frame
		if beast.state == beast.State.DAZED:
			dazed = true
			break
	check(dazed, "rushing into the wall leaves it DAZED")
	hp = beast.health
	beast.take_hit(1, Vector2.LEFT, beast._shield_world() + Vector2.from_angle(beast.guard) * 50.0)
	check(beast.health == hp - 1, "dazed, the shield is down: even a hit from its face lands")
	# phase two
	beast.state = beast.State.IDLE
	beast._cd = 99.0
	beast.health = beast.max_hp / 2 + 1
	beast.take_hit(1, Vector2.LEFT, beast._chest_world() - Vector2.from_angle(beast.guard) * 300.0)
	check(beast.phase_two, "half health: phase two (faster, red eyes, leaps, Scribbles)")
	beast._summon()
	await pframes(2)
	check(beast._spawn_count() == 2 and arena._crack_t > 0.0, "the gutter cracks open and two Scribbles fly out of it (%d)" % beast._spawn_count())
	# death and the ending
	beast.state = beast.State.STAGGER
	beast._timer = 5.0
	beast.health = 1
	beast.take_hit(3, Vector2.LEFT, beast.global_position + Vector2(-80, 0))
	check(beast.state == beast.State.DYING and not beast.dead, "at 0 it doesn't tumble away: it dies slowly")
	for i in 4:
		await process_frame  # the arena notices on its own (render) frame
	check(arena.phase == arena.Phase.OUTRO and player.cutscene and music.current == "", "the ending takes the controls (and the music dies with it)")
	await seconds(4.0)
	check(beast.dead and gs.seen.has("beast_dead"), "the Beast unravels and is gone")
	check(get_nodes_in_group("beast_spawn").all(func(sc): return sc.dead), "its Scribbles die with it")
	while arena._t < 5.6:
		await process_frame
	check(arena._who == "shade" and arena._line == "NO.", "Shade breaks out of the narration: \"%s\"" % arena._line)
	while arena._t < 7.6:
		await process_frame
	check(arena._line.contains("TEARS VESPER APART"), "his script said Vesper dies here: \"%s\"" % arena._line)
	while arena._t < 11.2:
		await process_frame
	check(arena._who == "vesper", "Vesper answers: \"%s\"" % arena._line)
	press_enter()  # skip the rest of the talk, not the Eraser
	for i in 4:
		await process_frame
	check(arena._t >= arena.T_ERASER - 0.5 and arena.phase == arena.Phase.OUTRO, "Enter skips the talk to the Eraser")
	while arena._t < arena.T_ERASER + 0.6:
		await process_frame
	var eraser = arena._eraser
	check(eraser != null and absf(eraser.global_position.y - arena.global_position.y) < 2.0, "SHADE'S ERASER slams down into the panel")
	while arena.phase == arena.Phase.OUTRO:
		await process_frame
	var chase = current_scene.get_node("World/EraserChase")
	check(arena._east_shape.disabled and not player.cutscene and chase.phase == chase.Phase.CHASE and chase.eraser == eraser,
		"the panel's border rips open: RUN! (the chase starts, Vesper has the controls)")
	check(music.current == "beast", "the fight's music comes back under the chase")
	# the Eraser is a wall: running, dashing or jumping back at it, he never gets
	# behind it into the rubbed-out paper, and it bounces him off forward
	var hp_before: float = player.health
	var worst := 1.0e9
	var thrown := false
	for attempt in ["run", "dash", "jump"]:
		player._invuln_timer = 99.0  # the wall alone, not the hit's knockback
		Input.action_press("move_left")
		for i in 150:
			if attempt == "dash" and i % 40 == 5:
				Input.action_press("dash")
			elif attempt == "dash" and i % 40 == 7:
				Input.action_release("dash")
			if attempt == "jump" and i % 40 == 5:
				Input.action_press("jump")
			elif attempt == "jump" and i % 40 == 25:
				Input.action_release("jump")
			await physics_frame
			worst = minf(worst, player.global_position.x - (eraser.global_position.x + eraser.block.x * 0.4))
			thrown = thrown or player.velocity.x > 300.0
		Input.action_release("move_left")
		Input.action_release("dash")
		Input.action_release("jump")
	check(worst > -4.0 and thrown and player.health == hp_before,
		"the Eraser is a wall: run, dash or jump back at it and it bounces him off, never behind it (closest %.0f px)" % worst)
	await seconds(0.5)
	# the chase: keep running, hop the bumps
	player._invuln_timer = 0.0
	Input.action_press("move_right")
	var k := 0
	while chase.phase == chase.Phase.CHASE and k < 120 * 40:
		await physics_frame
		k += 1
		if k % 60 == 0:
			Input.action_press("jump")
		elif k % 60 == 30:
			Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("jump")
	check(chase.phase == chase.Phase.FINALE and not player.dead, "a plain run gets him to the end of the page (hp %.0f)" % player.health)
	check(player.cutscene and player.cutscene_run > 0.0, "at the edge the controls go: he sprints for the gap")
	var t := 0
	while chase.phase != chase.Phase.DONE and t < 600:
		await process_frame
		t += 1
	check(chase.phase == chase.Phase.DONE and gs.seen.has("chase_done") and paused, "he leaps into the gutter: the fall into the Margins begins")
	t = 0
	while (current_scene == null or not current_scene.scene_file_path.ends_with("clearing.tscn")) and t < 2400:
		await process_frame
		t += 1
	check(current_scene != null and current_scene.scene_file_path.ends_with("clearing.tscn"), "and he lands in the Margins (the 2.5D hub)")
	paused = false
	await seconds(1.0)  # let the hub settle before leaving it
	# a retry in the chase: it starts again from the corridor's checkpoint
	gs.reset()
	gs.seen["beast_intro"] = true
	gs.seen["beast_dead"] = true
	change_scene_to_file(LEVEL)
	await pframes(10)
	chase = current_scene.get_node("World/EraserChase")
	player = current_scene.get_node("Player")
	check(current_scene.get_node("World/BeastArena").phase == 5, "beast beaten this run: the arena stays open")
	player.global_position = Vector2(chase.global_position.x + 140, chase.global_position.y - 30)
	await seconds(0.5)
	check(chase.phase == chase.Phase.CHASE and chase.eraser != null, "dying in the chase: it starts again as soon as he moves on")
	# a retry of the fight: the short intro
	gs.reset()
	gs.seen["beast_intro"] = true
	change_scene_to_file(LEVEL)
	await pframes(10)
	arena = current_scene.get_node("World/BeastArena")
	player = current_scene.get_node("Player")
	check(arena._short and not current_scene.get_node("World/ArenaLanternW").lit, "after dying, a retry plays the short intro (lanterns already out)")
	player.global_position = Vector2(arena.trigger_x + 60, arena.global_position.y - 30)
	await seconds(3.6)
	check(arena.phase == arena.Phase.FIGHT, "and the fight starts within a few seconds")
	print("DONE fails=%d" % fails)
	quit(fails)
