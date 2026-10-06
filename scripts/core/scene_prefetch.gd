extends RefCounted
## Loads the scene a cutscene or transition leads to while it plays, so its
## end can switch at once. Every cutscene and transition that changes the
## scene goes through here (cs_book, panel_turn, page_climb, margins_fall,
## shade_trap, cave_arena, World25, gutter_transition).
##
## On desktop it loads in a background thread. In a browser it loads on the
## main thread, there and then (a short hitch as the cutscene starts): there,
## a loading thread can't read the game's files itself, every read is handed
## to the main thread and waits for it to come round between frames, so the
## City took the whole opening to load and the game sat on the opening's last
## frame for 10-20 s (more on a busy page) until it was in.
##
##   ScenePrefetch.start(path)              # as the cutscene begins
##   ScenePrefetch.change(get_tree(), path) # at its end (waits for the rest, if any)

## In a browser: scenes loaded at start(), waiting for take().
static var _held := {}


static func threaded() -> bool:
	return not OS.has_feature("web")


static func start(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	if not threaded():
		if not _held.has(path):
			_held[path] = load(path)
		return
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## Not still loading (loaded, failed, or never asked for).
static func done(path: String) -> bool:
	return not threaded() or ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS


## The scene once it's in (null while it's still loading).
static func ready_scene(path: String) -> PackedScene:
	return take(path) if done(path) else null


static func take(path: String) -> PackedScene:
	if _held.has(path):
		var held: PackedScene = _held[path]
		_held.erase(path)
		if held:
			return held
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var packed := ResourceLoader.load_threaded_get(path) as PackedScene  # (finishes it here if need be)
		if packed:
			return packed
	return load(path) as PackedScene


static func change(tree: SceneTree, path: String) -> void:
	var packed := take(path)
	if packed:
		tree.change_scene_to_packed(packed)
	else:
		tree.change_scene_to_file(path)
