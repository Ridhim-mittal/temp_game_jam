extends Node
## Autoload "Settings": player options, saved to user://settings.cfg and
## applied as soon as they change.
##
##   Settings.get_value("difficulty")      # "relaxed" / "normal" / "hard"
##   Settings.cycle("volume", 1)           # next allowed value
##   Settings.shake_mult()                 # 0, 0.5 or 1 for camera shake
## Read by: cameras (shake), clearing_fx.gd (hit words), room.gd (controls
## hint), clearing_player.gd and monster_3d.gd (difficulty), scribble.gd,
## clearing_player.gd (aim assist) and World25 (cursor in the Gutter).
## "resolution" is applied here: SHARP draws at the screen's own size, FAST at
## 1280x720 scaled up (blurrier, far lighter on a weak graphics chip), AUTO is
## sharp until the game keeps running slowly (`_watch_speed()`).

signal changed(key: String)

const PATH := "user://settings.cfg"
## key -> [default, allowed values]
const OPTIONS := {
	"volume": [8, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]],
	"fullscreen": ["off", ["off", "on"]],
	"screen_shake": ["full", ["off", "low", "full"]],
	"hit_text": ["on", ["on", "off"]],
	"difficulty": ["normal", ["relaxed", "normal", "hard"]],
	"scribble_style": ["hopper", ["hopper", "diver"]],
	"show_cursor": ["off", ["off", "on"]],
	"aim_assist": ["on", ["on", "off"]],
	"resolution": ["auto", ["auto", "sharp", "fast"]],
}

## AUTO drops to 1280x720 after this many seconds in a row under SLOW_FPS...
const SLOW_SECONDS := 4
const SLOW_FPS := 40.0

## Not in the settings menu any more: always the default (an old save can't
## leave a player stuck on a value they can no longer change).
const FIXED := ["difficulty", "scribble_style", "aim_assist"]

var _values := {}
var _auto_fast := false  # AUTO has dropped to 1280x720 this session
var _auto_done := false  # ...and made up its mind (it stays as it is)
var _slow := 0  # seconds in a row under SLOW_FPS
var _fps_at_drop := 0.0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in OPTIONS:
		_values[key] = OPTIONS[key][0]
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in OPTIONS:
			if key in FIXED:
				continue
			var v = cfg.get_value("options", key, OPTIONS[key][0])
			if v in OPTIONS[key][1]:
				_values[key] = v
	for key in OPTIONS:
		_apply(key)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_watch_speed()


## AUTO resolution: when the game keeps running under SLOW_FPS (not while
## paused or loading), draw at 1280x720 instead; if that doesn't speed it up
## (the computer, not the drawing, is the slow part) go back to sharp for good.
func _watch_speed() -> void:
	if get_value("resolution") != "auto" or _auto_done or get_tree().paused:
		_slow = 0
		return
	var fps := Engine.get_frames_per_second()
	_slow = _slow + 1 if fps < SLOW_FPS else 0
	if _slow < SLOW_SECONDS:
		if _auto_fast and _slow == 0:
			_auto_done = true  # fast enough now: keep 1280x720
		return
	_slow = 0
	if not _auto_fast:
		var screen := get_tree().root.size
		if screen.x * screen.y <= 1280 * 720 * 1.2:
			_auto_done = true  # already about that small: nothing to gain
			return
		_auto_fast = true
		_fps_at_drop = fps
		print("Settings: running at %.0f fps, drawing at 1280x720 (resolution AUTO)" % fps)
	else:
		_auto_done = true
		if fps < _fps_at_drop * 1.15:
			_auto_fast = false  # no faster at 1280x720: sharp it is
			print("Settings: no faster at 1280x720, back to sharp")
	_apply("resolution")


func get_value(key: String):
	return _values.get(key, OPTIONS.get(key, [null])[0])


## Kept for older callers: Settings.scribble_style
var scribble_style: String:
	get:
		return get_value("scribble_style")
	set(v):
		set_option("scribble_style", v)


func set_option(key: String, value) -> void:
	if not OPTIONS.has(key) or not value in OPTIONS[key][1]:
		return
	_values[key] = value
	_apply(key)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("options", key, value)
	cfg.save(PATH)
	changed.emit(key)


func cycle(key: String, step := 1) -> void:
	var values: Array = OPTIONS[key][1]
	var i := values.find(get_value(key))
	set_option(key, values[clampi(i + step, 0, values.size() - 1)] if key == "volume" \
		else values[(i + step + values.size()) % values.size()])


func shake_mult() -> float:
	return {"off": 0.0, "low": 0.5, "full": 1.0}[get_value("screen_shake")]


func _apply(key: String) -> void:
	match key:
		"volume":
			var v: int = get_value("volume")
			AudioServer.set_bus_volume_db(0, -80.0 if v == 0 else linear_to_db(v / 10.0))
		"fullscreen":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if get_value("fullscreen") == "on" \
					else DisplayServer.WINDOW_MODE_WINDOWED)
		"resolution":
			var v: String = get_value("resolution")
			if v != "auto":
				_auto_fast = false
				_auto_done = false
				_slow = 0
			var fast := v == "fast" or (v == "auto" and _auto_fast)
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if fast \
				else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
