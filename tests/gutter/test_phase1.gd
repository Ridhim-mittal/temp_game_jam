extends SceneTree
## Gutter rework, phase 1 checks: the cursor policy (World25), a swing hitting
## a monster in each of the 8 directions, aim assist, the swing's arc and
## lunge, and mouse aim (swings towards the pointer). Needs a display:
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/gutter/test_phase1.gd
## Prints PASS / FAIL per check; the exit code is the number of failures.
const Dummy = preload("res://tests/gutter/dummy_enemy.gd")
const PlayerScript = preload("res://scripts/clearing/clearing_player.gd")
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
	await arc_test()
	await mouse_test()
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
	var settings = root.get_node("Settings")
	settings.set_option("aim", "movement")
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
	check(player.facing_dir.dot(Vector3.RIGHT) > 0.99 and dummy.hits > 0, "aim assist OFF: same swing stays straight; the arc still catches it (hits=%d, facing %s)" % [dummy.hits, player.facing_dir])
	player.aim_assist_range = 3.5
	var wide := Vector3(cos(deg_to_rad(70)), 0, sin(deg_to_rad(70))) * 2.6
	await setup(player, dummy, Vector3.RIGHT, wide)
	await swing()
	check(player.facing_dir.dot(Vector3.RIGHT) > 0.99, "aim assist ignores a monster outside the cone (70deg): facing %s" % player.facing_dir)
	var far := Vector3(4.2, 0, 0.6)
	await setup(player, dummy, Vector3.RIGHT, far)
	await swing()
	check(player.facing_dir.dot(Vector3.RIGHT) > 0.99, "aim assist ignores a monster beyond range (4.2u): facing %s" % player.facing_dir)
	settings.set_option("aim_assist", "off")
	await setup(player, dummy, Vector3.RIGHT, off)
	await swing()
	check(player.facing_dir.dot(Vector3.RIGHT) > 0.99, "Settings aim_assist=off disables the assist: facing %s" % player.facing_dir)
	settings.set_option("aim_assist", "on")

## A monster at angle `deg` from the swing (Vector3.RIGHT), `dist` away.
func at_angle(deg: float, dist: float) -> Vector3:
	return Vector3(cos(deg_to_rad(deg)), 0, sin(deg_to_rad(deg))) * dist

func room_with_dummy() -> Array:
	change_scene_to_file("res://scenes/world25/rooms/darkwood_1.tscn")
	await frames(30)
	var room := current_scene
	for m in room.get_node("Enemies").get_children():
		m.queue_free()
	for l in get_nodes_in_group("haunt_lamp"):
		l.queue_free()  # long checks: keep the Writer's lamp out of them
	var player = room.player
	player._invuln = 999.0
	var dummy := Dummy.new()
	room.add_child(dummy)
	await frames(5)
	return [room, player, dummy]

## The swing's arc and reach (aim assist off, so nothing turns), and the
## lunge stopping short of a close monster.
func arc_test() -> void:
	var settings = root.get_node("Settings")
	settings.set_option("aim", "movement")
	var got := await room_with_dummy()
	var player = got[1]
	var dummy: Node3D = got[2]
	player.aim_assist_range = 0.0
	for c in [[55.0, 1.8, true, "55deg off at 1.8u: inside the arc, hit"],
			[-55.0, 1.8, true, "-55deg off at 1.8u: inside the arc, hit"],
			[0.0, 2.5, true, "straight ahead at 2.5u: within reach, hit"],
			[90.0, 1.6, false, "beside (90deg) at 1.6u: outside the arc, miss"],
			[180.0, 1.5, false, "behind at 1.5u: miss"],
			[0.0, 3.0, false, "straight ahead at 3.0u: out of reach, miss"]]:
		await setup(player, dummy, Vector3.RIGHT, at_angle(c[0], c[1]))
		await swing()
		check((dummy.hits > 0) == c[2], "arc: %s (hits=%d)" % [c[3], dummy.hits])
	# the finisher sweeps wider: 80deg is outside a normal swing, inside the finisher
	await setup(player, dummy, Vector3.RIGHT, at_angle(80.0, 1.6))
	player._hit_in_front(Vector3.RIGHT, false)
	var normal_hits: int = dummy.hits
	player._hit_in_front(Vector3.RIGHT, true)
	check(normal_hits == 0 and dummy.hits == 1, "arc: 80deg off -> normal swing misses, finisher hits (%d, %d)" % [normal_hits, dummy.hits - normal_hits])
	# lunge: a close monster stops it short; with nothing there it steps in
	await setup(player, dummy, Vector3.RIGHT, Vector3(1.3, 0, 0))
	await swing()
	var x_close: float = player.global_position.x
	await setup(player, dummy, Vector3.RIGHT, Vector3(0, 0, -6))
	await swing()
	var x_free: float = player.global_position.x
	check(x_close < 0.45 and x_free > 0.5, "lunge stops short of a monster 1.3u away (moved %.2fu; %.2fu with nothing there)" % [x_close, x_free])
	player.aim_assist_range = 3.5

## Moves the (hidden) pointer onto the screen point over `world`, and waits
## for the motion to arrive.
func point_at(world: Vector3) -> void:
	var cam := root.get_camera_3d()
	Input.warp_mouse(cam.unproject_position(world))
	await frames(4)

## Mouse aim: swings go towards the pointer at any angle, whatever is held,
## and a gamepad takes over (and gives back) the aim.
func mouse_test() -> void:
	var settings = root.get_node("Settings")
	settings.set_option("aim", "mouse")
	var got := await room_with_dummy()
	var room = got[0]
	var player = got[1]
	var dummy: Node3D = got[2]
	PlayerScript.pad_aim = false
	player.aim_assist_range = 0.0  # the pointer alone decides
	var reticle: Control = room.get_node("UI/AimReticle")
	await setup(player, dummy, Vector3.RIGHT, Vector3(0, 0, -8))
	await frames(40)  # let the camera settle on the player
	var h := Vector3(0, player.mouse_aim_height, 0)
	await point_at(player.global_position + h + Vector3(2, 0, 0))
	var vp_err: float = root.get_mouse_position().distance_to(root.get_camera_3d().unproject_position(player.global_position + h + Vector3(2, 0, 0)))
	check(player.is_mouse_aiming() and reticle.visible, "mouse aim on: reticle shown (pointer within %.1f px of the target)" % vp_err)
	var names := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	for i in 8:
		var d := at_angle(i * 45.0, 1.0)
		# face the other way: only the pointer should decide
		await setup(player, dummy, -d, d * 1.6)
		await frames(20)
		await point_at(player.global_position + h + d * 3.0)
		await swing()
		var ang := rad_to_deg(player.facing_dir.angle_to(d))
		check(dummy.hits > 0 and ang < 4.0, "mouse aim %s (facing away): swing goes to the pointer (%.1f deg off) and hits (hits=%d)" % [names[i], ang, dummy.hits])
	# analog: 30deg isn't one of the 8 directions
	var d30 := at_angle(30.0, 1.0)
	await setup(player, dummy, Vector3.RIGHT, d30 * 1.6)
	await frames(20)
	await point_at(player.global_position + h + d30 * 3.0)
	await swing()
	var a30 := rad_to_deg(player.facing_dir.angle_to(d30))
	check(a30 < 4.0 and dummy.hits > 0, "mouse aim is analog: pointer at 30deg -> swing at 30deg (%.1f deg off), hits" % a30)
	# holding a direction doesn't override the pointer
	await setup(player, dummy, Vector3.RIGHT, Vector3(1.6, 0, 0))
	await frames(20)
	await point_at(player.global_position + h + Vector3(3, 0, 0))
	await swing(Vector3.LEFT)
	check(dummy.hits > 0 and player.facing_dir.dot(Vector3.RIGHT) > 0.99, "mouse aim: holding LEFT while pointing right still swings right (hits=%d)" % dummy.hits)
	# a gamepad stick takes over the aim; the mouse takes it back when it moves
	# (separate events: parse_input_event buffers the object until the next flush)
	for v in [0.9, 0.0]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_X
		stick.axis_value = v
		Input.parse_input_event(stick)
	await frames(4)
	check(not player.is_mouse_aiming() and not reticle.visible, "gamepad used: aims with the stick, reticle hidden")
	await setup(player, dummy, Vector3.RIGHT, Vector3(1.6, 0, 0))
	await point_at(player.global_position + h + Vector3(-3, 0, 0))
	PlayerScript.pad_aim = true  # warping counts as mouse motion; the pad is still in hand
	await swing()
	check(dummy.hits > 0 and player.facing_dir.dot(Vector3.RIGHT) > 0.99, "gamepad aim: swing follows facing, not the pointer behind (hits=%d)" % dummy.hits)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_mouse_position()
	motion.relative = Vector2(6, 0)
	Input.parse_input_event(motion)
	await frames(4)
	check(player.is_mouse_aiming() and reticle.visible, "mouse moved: mouse aim back, reticle shown")
	settings.set_option("aim", "movement")
	await frames(2)
	check(not player.is_mouse_aiming() and not reticle.visible, "Settings aim=movement: no mouse aim, no reticle")
	settings.set_option("aim", "mouse")
