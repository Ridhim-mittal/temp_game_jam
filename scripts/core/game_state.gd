extends Node
## Autoload "GameState": progress that must survive dying. Death and restart
## reload the whole level, so anything kept in the level itself is lost;
## the active checkpoint, banked coins and collected pickups live here.
##
##   GameState.set_checkpoint(pen)    # called by checkpoint_pen.gd
##   GameState.spawn_point()          # where the player should appear (or null)
##   GameState.reset()                # new run (the main menu calls this)

var checkpoint_scene := ""
var checkpoint_position := Vector2.ZERO
var checkpoint_id := ""
var passed := {}      # pen ids already passed (they stay green)
var coins := 0
var collected := {}   # coin ids already picked up (they stay gone)


func reset() -> void:
	checkpoint_scene = ""
	checkpoint_id = ""
	passed.clear()
	coins = 0
	collected.clear()


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


## Respawn position in the current level, or null if no checkpoint here yet.
## Entering a different level drops the old level's checkpoint.
func spawn_point(tree: SceneTree) -> Variant:
	var path := tree.current_scene.scene_file_path if tree.current_scene else ""
	if checkpoint_scene == "" or checkpoint_scene != path:
		checkpoint_scene = ""
		checkpoint_id = ""
		return null
	return checkpoint_position
