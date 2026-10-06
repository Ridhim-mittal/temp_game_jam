extends SceneTree
## The Scribbled Beast at the bottom of the Long Drop (scribbled_beast.gd,
## beast_arena.gd): walking in starts the intro and takes the controls; Enter
## skips it into the fight (lanterns out, the wall up, the boss bar); the
## shield blocks a hit from the side it faces; a lit lantern turns the shield
## round, and a hit from the other side lands; it lobs a glob that snuffs the
## lantern, and a slashed glob doesn't; a rush into the wall dazes it (shield
## down); half health starts phase two; at 0 it dies slowly, the Writer's
## furious caption plays and the way on opens; a retry plays the short intro.
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
	check(arena.phase == arena.Phase.WAIT and not beast.visible and beast.collision_layer == 0,
		"before Vesper comes in: the Beast is down in the gutter, out of sight and not solid")
	player.global_position = Vector2(arena.trigger_x + 60, arena.global_position.y - 30)
	await pframes(30)
	check(arena.phase == arena.Phase.INTRO and player.cutscene, "walking in starts the intro and takes the controls")
	var hud: CanvasLayer = current_scene.get_node("UI")
	await seconds(1.0)
	check(not hud.visible, "the HUD hides behind the letterbox")
	await seconds(2.4)  # the shield is up out of the floor by now
	check(beast.visible and beast.shield_lift > 0.9, "the shield comes up out of the tear first, held over its head")
	press_enter()
	await pframes(6)
	check(arena.phase == arena.Phase.FIGHT and not player.cutscene, "Enter skips the rest: fight")
	check(beast.state == beast.State.IDLE and beast.collision_layer == 4, "the Beast is up and solid")
	check(not lw.lit and not le.lit, "its darkness put both lanterns out")
	await seconds(1.0)
	check(not arena._barrier_shape.disabled, "a wall of scribble seals the way back")
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
	beast._lamp_time = -99.0  # no snuffing yet
	await seconds(1.4)
	var to_lamp: float = (le.lamp_position() - beast._chest_world()).angle()
	check(absf(angle_difference(beast.guard, to_lamp)) < 0.5, "a lit lantern: the shield swings round to the light")
	beast.take_hit(1, Vector2.RIGHT, player.global_position)
	check(beast.health == hp - 1, "and a hit from Vesper's side lands (%d -> %d)" % [hp, beast.health])
	# it snuffs the lantern
	beast._lamp_time = 99.0
	await seconds(2.6)
	check(not le.lit, "a lantern left burning gets an ink glob: SPLUT, out")
	# a slashed glob doesn't snuff it
	le.lit = true
	var g = preload("res://scripts/enemies/beast_glob.gd").throw(self, beast._hand_world(), le)
	await pframes(3)
	g.take_hit(1, Vector2.RIGHT, g.global_position)
	await seconds(1.2)
	check(le.lit, "slash the glob out of the air and the light stays on")
	le.lit = false
	# a rush into the wall dazes it: shield down, hits land from anywhere
	beast.state = beast.State.RUSH
	beast._timer = 3.0
	beast.facing = 1
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
	beast.take_hit(1, Vector2.LEFT, beast._shield_world() + Vector2.from_angle(beast.guard + PI) * 400.0)
	check(beast.phase_two, "half health: phase two (faster, red eyes, leaps, Scribbles)")
	beast._summon()
	await pframes(2)
	check(beast._spawn_count() == 2, "it drags two Scribbles up out of the gutter (%d)" % beast._spawn_count())
	# death and the ending
	beast.state = beast.State.STAGGER
	beast._timer = 5.0
	beast.health = 1
	beast.take_hit(3, Vector2.LEFT, beast.global_position + Vector2(-80, 0))
	check(beast.state == beast.State.DYING and not beast.dead, "at 0 it doesn't tumble away: it dies slowly")
	await pframes(4)
	check(arena.phase == arena.Phase.OUTRO and player.cutscene, "the ending takes the controls")
	await seconds(4.0)
	check(beast.dead and gs.seen.has("beast_dead"), "the Beast unravels and is gone")
	check(get_nodes_in_group("beast_spawn").all(func(sc): return sc.dead), "its Scribbles die with it")
	await seconds(3.0)
	check(arena._caption_fury and arena._caption.begins_with("NO."), "the Writer, furious: \"%s\"" % arena._caption)
	await seconds(6.0)
	var exits := current_scene.find_children("*", "Area2D", true, false).filter(func(n): return n.get_script() == preload("res://scripts/world/level_exit.gd"))
	check(arena.phase == arena.Phase.DONE and not player.cutscene and exits.size() == 1, "then the way on opens and Vesper moves again")
	check(arena._barrier_shape.disabled, "and the wall is down")
	# a retry: the short intro
	gs.seen.erase("beast_dead")
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
