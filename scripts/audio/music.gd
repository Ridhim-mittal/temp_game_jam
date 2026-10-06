extends Node
## Background music player, registered as the autoload "Music".
##
##   Music.play("lit")      # cross-fades to a track; does nothing if already playing
##   Music.stop()           # fades out
##
## Tracks share one melody: "lit" is the warm version, "margins" the slow
## minor one, "boss" the fast minor one, "ending" the goodbye (plays once).
## The 2D story has the team's licensed tracks (tools/master_music.py cuts them
## into loops and masters them quiet): "city" (Cool Down: THE CITY and the
## Sketchbook), "deep" (A Flicker in the Deep: THE LONG DROP) and "beast"
## (Incisive Battle: the Scribbled Beast's fight and the Eraser's chase).
## The Margins (2.5D): "repose" (Repose: the Spine, the Torn Wastes), "silk"
## (Silksong: the Inkwood) and "dread" (the battle, lower, darker and far back in
## a cavern: the Red Pen and the Eraser; room.gd `boss_music`).
## Shade's part (Shade's City, the Ink Cave, the finale): "hunters" (The
## Hunters, kept low) and, in its boss fights, "hunt" (its driving middle,
## faster, with a heartbeat, ticking, a trembling string cluster and risers
## laid over it: gate_arena.gd, cave_arena.gd, shade_finale.gd); the last
## fight, Shade as Vesper's double, plays "duel".

const TRACKS := {
	"lit": "res://audio/music/lit_pages.ogg",
	"margins": "res://audio/music/margins.ogg",
	"boss": "res://audio/music/shade_boss.ogg",
	"ending": "res://audio/music/ending.ogg",
	"city": "res://audio/music/city.ogg",
	"deep": "res://audio/music/deep.ogg",
	"beast": "res://audio/music/beast.ogg",
	"repose": "res://audio/music/repose.ogg",
	"silk": "res://audio/music/silk.ogg",
	"dread": "res://audio/music/dread.ogg",
	"hunters": "res://audio/music/hunters.ogg",
	"hunt": "res://audio/music/hunt.ogg",
	"duel": "res://audio/music/duel.ogg",
}
## Where a track loops back to (seconds; master_music.py prints these): the part
## before it is an intro, heard once.
const LOOP_FROM := {
	"city": 34.78,
	"deep": 36.47,
	"beast": 11.89,
	"repose": 1.37,
	"silk": 2.71,
	"dread": 11.89,
	"hunters": 7.006,
	"hunt": 0.0,
	"duel": 9.69,
}
## Per-track level (dB on top of volume_db): the 2D loops are mastered quiet,
## and kept a little under the old tracks so they sit behind the sound effects.
const TRIM := {
	"city": 2.0,
	"deep": 3.0,
	"beast": 2.0,
	"repose": 3.0,
	"silk": 3.0,
	"dread": 2.5,
	"hunters": 0.0,  # low: it sits under everything
	"hunt": 1.5,
	"duel": 1.5,
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
	if "loop_offset" in stream:
		stream.loop_offset = float(LOOP_FROM.get(track, 0.0))
	current = track
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if _player.playing:
		_fade.tween_property(_player, "volume_db", -60.0, fade)
	_fade.tween_callback(func():
		_player.stream = stream
		_player.play())
	_fade.tween_property(_player, "volume_db", volume_db + float(TRIM.get(track, 0.0)), fade)


func stop(fade := 0.8) -> void:
	current = ""
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, fade)
	_fade.tween_callback(_player.stop)
