extends SceneTree
## Gutter rework, phase 1 checks: the cursor policy (World25), a swing hitting
## a monster in each of the 8 directions, and aim assist. Needs a display:
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/gutter/test_phase1.gd
## Prints PASS / FAIL per check; the exit code is the number of failures.
const Dummy = preload("res://tests/gutter/dummy_enemy.gd")
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

func mode_name() -> String:
	return ["VISIBLE", "HIDDEN", "CAPTURED", "CONFINED", "CONFINED_HIDDEN"][Input.mouse_mode]

func _run() -> void:
	await cursor_test()
	await direction_test()
	print("DONE fails=%d" % fails)
	quit(fails)

func cursor_test() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(20)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "main menu: cursor visible (%s)" % mode_name())
	change_scene_to_file("res://scenes/clearing/clearing.tscn")
	await frames(40)
	var room := current_scene
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "hub gameplay: cursor hidden (%s)" % mode_name())
	for action in ["pause", "skills", "settings"]:
		room.open_overlay(action)
		await frames(3)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "%s overlay: cursor visible (%s)" % [action, mode_name()])
		var ov = room._overlay
		if action == "pause":
			room._on_pause_choice("resume")
		else:
			room._on_overlay_closed()
			ov.queue_free()
		await frames(3)
		check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "%s closed: cursor hidden again (%s)" % [action, mode_name()])
	# pause -> skill tree straight from the pause menu
	room.open_overlay("pause")
	await frames(2)
	room._on_pause_choice("skills")
	await frames(3)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause -> skills: cursor visible (%s)" % mode_name())
	var ov2 = room._overlay
	room._on_overlay_closed()
	ov2.queue_free()
	await frames(3)
	var settings = root.get_node("Settings")
	var old: String = settings.get_value("show_cursor")
	settings.set_option("show_cursor", "on")
	await frames(3)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Settings show_cursor=on: visible in game (%s)" % mode_name())
	settings.set_option("show_cursor", old)
	await frames(3)
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "show_cursor back off: hidden (%s)" % mode_name())
	change_scene_to_file("res://scenes/cutscenes/cs_reveal.tscn")
	await frames(10)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "cutscene: cursor visible (%s)" % mode_name())
	# leave the cutscene the way the game does (World25.go unpauses)
	root.get_node("World25").go("res://scenes/world25/rooms/darkwood_1.tscn", "")
	await frames(60)
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "cutscene -> room darkwood_1 (World25.go): cursor hidden (%s)" % mode_name())
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(10)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "back to menu: cursor visible (%s)" % mode_name())

func release_all() -> void:
	for a in ["move_left", "move_right", "up", "down", "attack"]:
		Input.action_release(a)

func hold_dir(d: Vector3) -> void:
	if d.x > 0.1: Input.action_press("move_right", absf(d.x))
	if d.x < -0.1: Input.action_press("move_left", absf(d.x))
	if d.z > 0.1: Input.action_press("down", absf(d.z))
	if d.z < -0.1: Input.action_press("up", absf(d.z))

## Puts the player at the origin, still, facing `face`, with a dummy at `at`.
func setup(player: Node, dummy: Node3D, face: Vector3, at: Vector3) -> void:
	release_all()
	await pframes(2)
	player.global_position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	player._combo_timer = 0.0
	player._attack_timer = 0.0
	player._dash_timer = 0.0
	player.set_facing(face)
	player._snap_visuals()
	dummy.global_position = Vector3(at.x, 0.05, at.z)
	dummy.hits = 0
	await pframes(3)

## Presses attack right before the nodes' physics tick, so it counts as
## just pressed; optionally holds a direction in the same tick.
func swing(held := Vector3.ZERO) -> void:
	await physics_frame
	if held != Vector3.ZERO:
		hold_dir(held)
	Input.action_press("attack")
	await pframes(3)
	release_all()
	await pframes(30)

func direction_test() -> void:
	change_scene_to_file("res://scenes/world25/rooms/darkwood_1.tscn")
	await frames(30)
	var room := current_scene
	for m in room.get_node("Enemies").get_children():
		m.queue_free()  # only the dummy
	var player = room.player
	player._invuln = 999.0
	var dummy := Dummy.new()
	room.add_child(dummy)
	await frames(5)
	var dirs := []
	for i in 8:
		var a := i * TAU / 8.0
		dirs.append(Vector3(cos(a), 0, sin(a)))
	var names := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	# A: facing a direction, no input held: swing goes along facing_dir
	player.aim_assist_range = 0.0
	for i in 8:
		var d: Vector3 = dirs[i]
		await setup(player, dummy, d, d * 1.5)
		await swing()
		check(dummy.hits > 0, "facing %s, no input: swing hits the monster in front (hits=%d)" % [names[i], dummy.hits])
	# B: facing the opposite way, hold the direction and press attack in the same tick
	for i in 8:
		var d: Vector3 = dirs[i]
		await setup(player, dummy, -d, d * 1.5)
		await swing(d)
		var turned: bool = player.facing_dir.dot(d) > 0.99
		check(dummy.hits > 0 and turned, "facing away, hold %s + attack: turns and hits (hits=%d, facing %s)" % [names[i], dummy.hits, player.facing_dir])
	# C: aim assist
	player.aim_assist_range = 3.5
	var off := Vector3(cos(deg_to_rad(40)), 0, sin(deg_to_rad(40))) * 2.6
	await setup(player, dummy, Vector3.RIGHT, off)
	var target_dir := off.normalized()
	await swing()
	var ang := rad_to_deg(player.facing_dir.angle_to(target_dir))
	check(dummy.hits > 0 and ang < 3.0, "aim assist ON: monster 40deg off at 2.6u -> swing turns to it (%.1f deg off) and hits (hits=%d)" % [ang, dummy.hits])
	player.aim_assist_range = 0.0
	await setup(player, dummy, Vector3.RIGHT, off)
	await swing()
	check(dummy.hits == 0 and player.facing_dir.dot(Vector3.RIGHT) > 0.99, "aim assist OFF: same swing stays straight and misses (hits=%d)" % dummy.hits)
	player.aim_assist_range = 3.5
	var wide := Vector3(cos(deg_to_rad(70)), 0, sin(deg_to_rad(70))) * 2.6
	await setup(player, dummy, Vector3.RIGHT, wide)
	await swing()
	check(player.facing_dir.dot(Vector3.RIGHT) > 0.99, "aim assist ignores a monster outside the cone (70deg): facing %s" % player.facing_dir)
	var far := Vector3(4.2, 0, 0.6)
	await setup(player, dummy, Vector3.RIGHT, far)
	await swing()
	check(player.facing_dir.dot(Vector3.RIGHT) > 0.99, "aim assist ignores a monster beyond range (4.2u): facing %s" % player.facing_dir)
	var settings = root.get_node("Settings")
	settings.set_option("aim_assist", "off")
	await setup(player, dummy, Vector3.RIGHT, off)
	await swing()
	check(dummy.hits == 0, "Settings aim_assist=off disables the assist (hits=%d)" % dummy.hits)
	settings.set_option("aim_assist", "on")
