extends Node
## Autoload "Settings": player options, saved to user://settings.cfg and
## applied as soon as they change.
##
##   Settings.get_value("difficulty")      # "relaxed" / "normal" / "hard"
##   Settings.cycle("volume", 1)           # next allowed value
##   Settings.shake_mult()                 # 0, 0.5 or 1 for camera shake
## Read by: cameras (shake), clearing_fx.gd (hit words), room.gd (controls
## hint), clearing_player.gd and monster_3d.gd (difficulty), scribble.gd.

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
}

var _values := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in OPTIONS:
		_values[key] = OPTIONS[key][0]
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in OPTIONS:
			var v = cfg.get_value("options", key, OPTIONS[key][0])
			if v in OPTIONS[key][1]:
				_values[key] = v
	for key in OPTIONS:
		_apply(key)


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
