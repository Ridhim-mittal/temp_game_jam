extends Node
## Autoload "GameState": progress that must survive dying. Death and restart
## reload the whole level, so anything kept in the level itself is lost;
## the active checkpoint, banked coins and collected pickups live here.
##
##   GameState.set_checkpoint(pen)    # called by checkpoint_pen.gd
##   GameState.spawn_point()          # where the player should appear (or null)
##   GameState.reset()                # new run (the main menu calls this)
##
## It also keeps the run on disk (user://run.cfg) so the main menu can
## CONTINUE it, even after the game was closed: the story scene being played
## (a 2D level or a Gutter room), all of the above and World25's story state.
## Saved whenever a story scene starts, at every checkpoint, every
## `AUTOSAVE` seconds, on leaving for the main menu and on closing the game.
##
##   GameState.has_run()              # is there a run to continue?
##   GameState.continue_run()         # restore it; returns the scene to load
##   GameState.clear_run()            # the story is over (or a new game began)

const RUN_FILE := "user://run.cfg"
const AUTOSAVE := 20.0
## Where a run can be continued from: the 2D levels and the Gutter's rooms
## (not cutscenes or menus).
const STORY_DIRS := ["res://scenes/levels/", "res://scenes/world25/rooms/"]
const STORY_SCENES := ["res://scenes/clearing/clearing.tscn"]
## World25's state saved with the run.
const WORLD25_KEYS := ["entry_gate", "player_health", "player_fuel", "cleared", "visited", "links", "current_room", "flags"]

var checkpoint_scene := ""
var checkpoint_position := Vector2.ZERO
var checkpoint_id := ""
var passed := {}      # pen ids already passed (they stay green)
var coins := 0
var collected := {}   # coin ids already picked up (they stay gone)
var seen := {}        # one-off moments already played (narration captions)
## The story scene being played this run ("" = none).
var run_scene := ""

var _since_save := 0.0
var _closed := ""     # the scene the story ended in: never saved again


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	checkpoint_scene = ""
	checkpoint_id = ""
	passed.clear()
	coins = 0
	collected.clear()
	seen.clear()
	run_scene = ""


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	if path != _closed:
		_closed = ""
	if is_story_scene(path) and path != _closed:
		if path != run_scene:
			run_scene = path
			save_run()
	if run_scene != "":
		_since_save += delta
		if _since_save >= AUTOSAVE:
			save_run()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and run_scene != "":
		save_run()


static func is_story_scene(path: String) -> bool:
	if path in STORY_SCENES:
		return true
	for d: String in STORY_DIRS:
		if path.begins_with(d):
			return true
	return false


## Writes the run to disk (nothing if no story scene has been played).
func save_run() -> void:
	_since_save = 0.0
	if run_scene == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "scene", run_scene)
	cfg.set_value("run", "checkpoint_scene", checkpoint_scene)
	cfg.set_value("run", "checkpoint_position", checkpoint_position)
	cfg.set_value("run", "checkpoint_id", checkpoint_id)
	cfg.set_value("run", "passed", passed)
	cfg.set_value("run", "coins", coins)
	cfg.set_value("run", "collected", collected)
	cfg.set_value("run", "seen", seen)
	var w := get_node_or_null("/root/World25")
	if w:
		for k: String in WORLD25_KEYS:
			cfg.set_value("world25", k, w.get(k))
	cfg.save(RUN_FILE)


## The main menu, just before it starts afresh: keep the run that was going.
func leave_run() -> void:
	if run_scene != "":
		save_run()


func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	if cfg.load(RUN_FILE) != OK:
		return null
	var path: String = cfg.get_value("run", "scene", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return cfg


func has_run() -> bool:
	return _load() != null


## The scene the saved run was in ("" = none), for the menu to name it.
func saved_scene() -> String:
	var cfg := _load()
	return cfg.get_value("run", "scene", "") if cfg else ""


## Puts the saved run back (GameState and World25) and returns the scene to
## load, or "" if there is none. The level then spawns Vesper at its
## checkpoint, as after dying; a Gutter room at the gate he came in by.
func continue_run() -> String:
	var cfg := _load()
	if cfg == null:
		return ""
	reset()
	run_scene = cfg.get_value("run", "scene")
	checkpoint_scene = cfg.get_value("run", "checkpoint_scene", "")
	checkpoint_position = cfg.get_value("run", "checkpoint_position", Vector2.ZERO)
	checkpoint_id = cfg.get_value("run", "checkpoint_id", "")
	passed = cfg.get_value("run", "passed", {})
	coins = cfg.get_value("run", "coins", 0)
	collected = cfg.get_value("run", "collected", {})
	seen = cfg.get_value("run", "seen", {})
	var w := get_node_or_null("/root/World25")
	if w:
		w.reset()
		for k: String in WORLD25_KEYS:
			if cfg.has_section_key("world25", k):
				w.set(k, cfg.get_value("world25", k))
		w.hold_state = true  # don't let the menu wipe it before the room loads
	return run_scene


## Nothing to continue any more: the story was finished, or a new game began.
func clear_run() -> void:
	var scene := get_tree().current_scene
	_closed = scene.scene_file_path if scene else ""
	run_scene = ""
	if FileAccess.file_exists(RUN_FILE):
		DirAccess.remove_absolute(RUN_FILE)


## A stable id for a node in the current level ("scene::node/path").
func id_of(node: Node) -> String:
	var scene := node.get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	return "%s::%s" % [path, scene.get_path_to(node) if scene else node.get_path()]


func set_checkpoint(pen: Node2D, spawn: Vector2) -> void:
	checkpoint_scene = pen.get_tree().current_scene.scene_file_path
	checkpoint_position = spawn
	checkpoint_id = id_of(pen)
	passed[checkpoint_id] = true
	save_run()


## Respawn position in the current level, or null if no checkpoint here yet.
## Entering a different level drops the old level's checkpoint.
func spawn_point(tree: SceneTree) -> Variant:
	var path := tree.current_scene.scene_file_path if tree.current_scene else ""
	if checkpoint_scene == "" or checkpoint_scene != path:
		checkpoint_scene = ""
		checkpoint_id = ""
		return null
	return checkpoint_position
