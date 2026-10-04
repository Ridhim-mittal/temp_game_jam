extends Node
## Autoload "World25": the 2.5D story's state and room-to-room travel.
##
##   World25.start_story()                  # new run, starting in the clearing
##   World25.go(scene_path, gate_id)        # ink-wipe into another room
##   World25.play_cutscene(path, next)      # ink-wipe into a comic cutscene
##   World25.is_cleared(room_id)            # gates in cleared rooms stay open
##   World25.fall_in_from_panel(health_frac)  # 2D trapdoor -> drop into the clearing
##
## Rooms (scripts/world25/room.gd) read `entry_gate` to place the player
## and `player_health` to carry health across. The minimap reads `visited`
## and `links`.

const START_SCENE := "res://scenes/clearing/clearing.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const WIPE_SHADER = preload("res://shaders/world25/ink_wipe.gdshader")

## Gate id the player arrives at in the next room ("" = the room's spawn).
var entry_gate := ""
## Carried between rooms; -1 = full health / starting fuel.
var player_health := -1
var player_fuel := -1.0
## room_id -> true once all its monsters are beaten.
var cleared := {}
## room_id -> {"cell": Vector2i, "color": Color, "name": String}
var visited := {}
## Pairs of map cells joined by a gate the player has walked through.
var links: Array = []
var current_room := ""
## Story beats already shown (captions that should play once).
var flags := {}
var transitioning := false
## > 0: the next room spawns the player this high up so they fall in from
## the sky (used when Vesper drops out of a 2D comic panel into the gutter).
var arrive_from_sky := 0.0

var _layer: CanvasLayer
var _wipe: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)
	_wipe = ColorRect.new()
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = WIPE_SHADER
	_wipe.material = _mat
	_wipe.visible = false
	_layer.add_child(_wipe)


func start_story() -> void:
	reset()
	go(START_SCENE, "")


## The 2D levels' trapdoor: start the 2.5D story with Vesper dropping out of
## the sky into the clearing. `health_frac` (0..1) carries the platformer's
## health over to the 2.5D hearts. The caller removes its 2D player from the
## "player" group first, so go() doesn't read platformer stats.
func fall_in_from_panel(health_frac: float) -> void:
	reset()
	var hearts := 5
	var scene: PackedScene = load("res://scenes/clearing/clearing_player.tscn")
	if scene:
		var probe := scene.instantiate()
		hearts = int(probe.max_health)
		probe.free()
	player_health = clampi(ceili(clampf(health_frac, 0.0, 1.0) * hearts), 1, hearts)
	arrive_from_sky = 9.0
	go(START_SCENE, "")


## Forget the current run (also happens whenever the main menu is shown).
func reset() -> void:
	entry_gate = ""
	player_health = -1
	player_fuel = -1.0
	cleared.clear()
	visited.clear()
	links.clear()
	flags.clear()
	current_room = ""


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == MENU_SCENE and current_room != "":
		reset()


func is_cleared(room_id: String) -> bool:
	return cleared.get(room_id, false)


func mark_cleared(room_id: String) -> void:
	cleared[room_id] = true


## Called by a room when it starts.
func enter_room(room_id: String, cell: Vector2i, color: Color, room_name: String) -> void:
	if current_room != "" and visited.has(current_room):
		var from: Vector2i = visited[current_room].cell
		if from != cell and not _linked(from, cell):
			links.append([from, cell])
	visited[room_id] = {"cell": cell, "color": color, "name": room_name}
	current_room = room_id


func _linked(a: Vector2i, b: Vector2i) -> bool:
	for l in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return true
	return false


## True the first time it's asked for `key` (for one-off captions).
func once(key: String) -> bool:
	if flags.has(key):
		return false
	flags[key] = true
	return true


func go(scene_path: String, gate_id: String) -> void:
	if transitioning or scene_path == "":
		return
	transitioning = true
	var player := get_tree().get_first_node_in_group("player")
	if player and "health" in player and not player.dead:
		player_health = player.health
		player_fuel = player.fuel
	entry_gate = gate_id
	await _cover()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	await _reveal()
	transitioning = false


## Ink-wipe into a cutscene (scenes/cutscenes/*.tscn); when it ends it
## loads `next_scene` (the menu by default).
func play_cutscene(path: String, next_scene := MENU_SCENE) -> void:
	if transitioning:
		return
	transitioning = true
	await _cover()
	Engine.time_scale = 1.0
	var cs: Node = load(path).instantiate()
	if "next_scene" in cs:
		cs.next_scene = next_scene
	var old := get_tree().current_scene
	get_tree().root.add_child(cs)
	get_tree().current_scene = cs
	if old:
		old.queue_free()
	await _reveal()
	transitioning = false


func _cover() -> void:
	_wipe.visible = true
	var t := create_tween()
	t.tween_method(func(v: float): _mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished


func _reveal() -> void:
	# let the new scene load and its camera warm up under the ink
	for i in 4:
		await get_tree().process_frame
	var t := create_tween()
	t.tween_method(func(v: float): _mat.set_shader_parameter("progress", v), 1.0, 0.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	_wipe.visible = false
