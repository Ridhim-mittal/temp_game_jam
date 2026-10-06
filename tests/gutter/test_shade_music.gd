extends SceneTree
## Shade's part: The Hunters (music.gd "hunters", low) through Shade's City, the
## Ink Cave and the finale, its tense cut ("hunt") in their boss fights, and
## the fights' sound effects (sfx_synth.gd). Run like test_phase1.gd.

const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const CITY := "res://scenes/levels/shades_city.tscn"
const CAVE := "res://scenes/levels/ink_cave.tscn"
const FINALE := "res://scenes/levels/shade_finale.tscn"
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


func music() -> Node:
	return root.get_node("Music")


## A synthesised sound is playing in the level right now.
func sounding(sound: String) -> bool:
	var want := SfxSynth.get_stream(sound)
	for c in current_scene.get_children():
		if c is AudioStreamPlayer and c.stream == want and c.playing:
			return true
	return false


func player() -> Node2D:
	return get_first_node_in_group("player") as Node2D


func level(path: String) -> void:
	change_scene_to_file(path)
	await frames(8)
	player().set("_invuln_timer", 9999.0)
	if "health" in player():
		player().health = 99


func kill(blot: Node) -> void:
	blot.take_hit(999, Vector2.RIGHT, blot.global_position - Vector2(40, 0))


func _run() -> void:
	var m := music()
	for track in ["hunters", "hunt", "hand", "duel"]:
		var stream = load(m.TRACKS[track])
		check(stream != null and stream.get_length() > 50.0, "%s.ogg loads (%.1f s)" % [track, stream.get_length() if stream else 0.0])
	check(m.TRIM["hunters"] < m.TRIM["repose"] and m.TRIM["hunters"] <= 0.0, "The Hunters sits lower than the other tracks")

	# Shade's City: The Hunters, then the tense cut while the Blot lives
	await level(CITY)
	check(m.current == "hunters", "Shade's City plays The Hunters (%s)" % m.current)
	var stream = m._player.stream
	check(stream.loop and is_equal_approx(stream.loop_offset, 7.006), "it loops from bar 4 (intro once)")
	var arena = current_scene.get_node("World/GateArena")
	var blot = current_scene.get_node("Enemies/InkBlot")
	player().global_position = Vector2(arena.trigger_x + 60.0, 560.0)
	var woke := await until(func(): return blot.state != blot.State.SLEEP, 60)
	check(woke and m.current == "hunt", "the Blot wakes: the music turns tense (%s)" % m.current)
	check(sounding("roar") and sounding("rumble"), "it roars, the ink walls rumble up")
	var slammed := await until(func(): return sounding("thud"), 200)
	check(slammed, "and slam home")
	blot._slam()
	check(sounding("thud") and sounding("rumble"), "its slam booms and its shockwaves rumble")
	blot._spit()
	check(sounding("splut"), "its globs splut")
	kill(blot)
	check(m.current == "hunters", "it melts: The Hunters comes back (%s)" % m.current)
	check(sounding("roar"), "with a dying groan")

	# the Ink Cave: same tune, the tense cut for the two Blots, quiet for the collapse
	await level(CAVE)
	check(m.current == "hunters", "the Ink Cave plays The Hunters (%s)" % m.current)
	var cave = current_scene.get_node("World/CaveArena")
	player().global_position = Vector2(cave.trigger_x + 60.0, 560.0)
	await until(func(): return cave.phase == cave.Phase.LOCKED, 60)
	check(m.current == "hunt", "two Blots wake: tense (%s)" % m.current)
	var a = current_scene.get_node("Enemies/InkBlotA")
	await frames(50)
	a.take_turn()
	check(sounding("roar"), "MY TURN! comes with a roar")
	kill(a)
	kill(current_scene.get_node("Enemies/InkBlotB"))
	check(m.current == "", "the last one melts: the music dies away before the collapse")
	var collapsed := await until(func(): return cave.phase == cave.Phase.COLLAPSE, 300)
	check(collapsed and sounding("rumble"), "the cave gives way with a rumble")

	# a retry goes straight to the light: silence, then the double and the tense cut again
	var gs := root.get_node("GameState")
	gs.seen["finale:waves"] = true
	await level(FINALE)
	var fin = current_scene.get_node("Finale")
	var quiet := await until(func(): return m.current == "", 1200)
	check(quiet, "the light falls in silence")
	var fight := await until(func(): return fin.boss != null and fin.boss.state != fin.boss.State.INTRO, 1200)
	check(fight and m.current == "duel", "the double steps out: its own song crashes in (%s)" % m.current)
	fin.boss._impact()
	check(sounding("thud") and sounding("rumble"), "its plunge booms")
	fin.boss._slash()
	check(sounding("clang"), "its blade rings before a cut")
	# the finale: the hand scratches as it writes, the waves turn tense
	# (last: leaving mid-wave would strand the finale's own coroutines)
	gs.seen.erase("finale:waves")
	await level(FINALE)
	check(m.current == "hunters", "the finale opens on The Hunters (%s)" % m.current)
	var scratched := await until(func(): return sounding("scritch"), 900)
	check(scratched, "the nib scratches as Shade writes his name")
	var waves := await until(func(): return m.current == "hand", 1200)
	check(waves, "the first wave: the hand's theme")

	gs.seen.erase("finale:waves")
	print("%d failure(s)" % fails)
	quit(fails)
