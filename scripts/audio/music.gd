extends Node
## Background music player, registered as the autoload "Music".
##
##   Music.play("lit")      # cross-fades to a track; does nothing if already playing
##   Music.stop()           # fades out
##
## Tracks share one melody: "lit" is the warm version, "margins" the slow
## minor one, "boss" the fast minor one, "ending" the goodbye (plays once).

const TRACKS := {
	"lit": "res://audio/music/lit_pages.ogg",
	"margins": "res://audio/music/margins.ogg",
	"boss": "res://audio/music/shade_boss.ogg",
	"ending": "res://audio/music/ending.ogg",
}
const PLAY_ONCE := ["ending"]

@export var volume_db := -8.0

var current := ""
var _player: AudioStreamPlayer
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while cutscenes pause the game
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60.0
	add_child(_player)


func play(track: String, fade := 0.8) -> void:
	if track == current:
		return
	if not TRACKS.has(track):
		push_warning("Music: unknown track '%s'" % track)
		return
	var stream = load(TRACKS[track])
	if stream == null:
		push_warning("Music: could not load %s" % TRACKS[track])
		return
	if "loop" in stream:
		stream.loop = not (track in PLAY_ONCE)
	current = track
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if _player.playing:
		_fade.tween_property(_player, "volume_db", -60.0, fade)
	_fade.tween_callback(func():
		_player.stream = stream
		_player.play())
	_fade.tween_property(_player, "volume_db", volume_db, fade)


func stop(fade := 0.8) -> void:
	current = ""
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, fade)
	_fade.tween_callback(_player.stop)
