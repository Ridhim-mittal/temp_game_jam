extends Node
## Autoload "Settings": player options, saved to user://settings.cfg.
##
##   Settings.scribble_style      # "hopper" (2.5D, hops and pounces) or
##                                # "diver" (the platformer's flying dive-bomber)
##   Settings.set_option("scribble_style", "diver")

signal changed(key: String)

const PATH := "user://settings.cfg"
## Every option: key -> [default, allowed values].
const OPTIONS := {
	"scribble_style": ["hopper", ["hopper", "diver"]],
}

var scribble_style := "hopper"


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in OPTIONS:
		var v = cfg.get_value("options", key, OPTIONS[key][0])
		if v in OPTIONS[key][1]:
			set(key, v)


func set_option(key: String, value) -> void:
	if not OPTIONS.has(key) or not value in OPTIONS[key][1]:
		return
	set(key, value)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("options", key, value)
	cfg.save(PATH)
	changed.emit(key)


## The next allowed value after the current one (for left/right toggles).
func cycle(key: String, step := 1) -> void:
	var values: Array = OPTIONS[key][1]
	var i := values.find(get(key))
	set_option(key, values[(i + step + values.size()) % values.size()])
