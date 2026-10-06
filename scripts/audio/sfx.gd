extends Node
## Autoload "Sfx": one-shot sound effects from assets/sfx (the team's SFX pack).
##
##   Sfx.play("jump")                 # a sound by name
##   Sfx.play("sword_swing")          # names with numbered variants pick one at random
##   Sfx.play("hurt", -4.0)           # volume offset in dB
##
## A small pool of players is reused so many sounds can overlap; every play
## gets a slight random pitch so repeats don't sound mechanical. Plays through
## the "SFX" bus (BUS, made here, LEVEL_DB quieter than the music, sending to
## Master so Settings' volume still applies); every other sound effect in the
## game (sfx_synth.gd, the Scribbles, the gates, the opening book, the page
## climb) plays through it too. Keeps playing while paused (menus).

const DIR := "res://assets/sfx/"
## The bus every sound effect plays through, and how far below the music it sits.
const BUS := "SFX"
const LEVEL_DB := -8.0
const POOL := 16
## Per-sound level trims (dB), so the pack sits evenly in the mix.
const TRIM := {"menu_hover": -10.0, "coin_collect": -4.0, "fall_land": -3.0, "sword_swing": -3.0,
	"ink_splat": -4.0, "boss_intro": 2.0}
## Sounds that must not stack up (min seconds between two plays).
const GAP := {"menu_hover": 0.05, "coin_collect": 0.04, "ink_enemy_hit": 0.05, "sword_hit": 0.05, "fall_land": 0.1}

var _streams := {}  # name -> Array[AudioStream] (variants)
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}


func _enter_tree() -> void:
	# the SFX bus, before anything plays (autoloads enter the tree first)
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), LEVEL_DB)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for f in DirAccess.get_files_at(DIR):
		f = f.trim_suffix(".import")
		if not f.ends_with(".wav"):
			continue
		var stream := load(DIR + f) as AudioStream
		if stream == null:
			continue
		var name := f.get_basename()
		var base := name
		var tail := name.get_slice("_", name.get_slice_count("_") - 1)
		if tail.is_valid_int():
			base = name.substr(0, name.length() - tail.length() - 1)
		for key in ([name, base] if base != name else [name]):
			if not _streams.has(key):
				_streams[key] = []
			if not stream in _streams[key]:
				_streams[key].append(stream)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var list: Array = _streams.get(sound, [])
	if list.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := sound.rstrip("0123456789_")
	if GAP.has(key) and now - float(_last.get(key, -10.0)) < GAP[key]:
		return
	_last[key] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db + float(TRIM.get(key, 0.0))
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()
