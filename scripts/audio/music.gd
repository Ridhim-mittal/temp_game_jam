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
## fight, Shade as Vesper's double, plays "duel"; the waves Shade's hand draws
## before it, "hand".
## Shade's City walks to "ruin" and the Ink Cave to "inkcave" (both cut from
## the Orsted theme), their Blot fights still "hunt".
## The ending's credits roll to "credits" (Last Page Stomp: our own hard-rock
## stomp, tools/make_credits_song.py; plays once).

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
	"ruin": "res://audio/music/ruin.ogg",
	"inkcave": "res://audio/music/inkcave.ogg",
	"hand": "res://audio/music/hand.ogg",
	"duel": "res://audio/music/duel.ogg",
	"credits": "res://audio/music/credits.ogg",
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
	"ruin": 0.0,
	"inkcave": 0.0,
	"hand": 0.0,
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
	"ruin": 3.5,  # +2 dB: up out from under the effects
	"inkcave": 4.0,  # +2.5 dB (it sits further back, in the cavern reverb)
	"hand": 1.5,
	"duel": 1.5,
}
const PLAY_ONCE := ["ending", "credits"]

## 4 dB over the SFX bus (sfx.gd LEVEL_DB -8), so the effects don't bury the music.
@export var volume_db := -4.0

var current := ""
var _player: AudioStreamPlayer  # the track playing (or fading in)
var _old: AudioStreamPlayer  # the one it replaced, fading out under it
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while cutscenes pause the game
	_player = AudioStreamPlayer.new()
	_old = AudioStreamPlayer.new()
	for p: AudioStreamPlayer in [_player, _old]:
		p.volume_db = -80.0
		add_child(p)


## A true crossfade: the old track fades out while the new one fades in, both
## on an equal-power curve (in amplitude, not dB), so there's no dip or bump.
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
	# the playing track becomes the one fading out under the new one
	var swap := _old
	_old = _player
	_player = swap
	_player.stop()
	_player.stream = stream
	_player.volume_db = -80.0
	_player.play()
	var from := db_to_linear(_old.volume_db) if _old.playing else 0.0
	var to := db_to_linear(volume_db + float(TRIM.get(track, 0.0)))
	_fade = create_tween()
	_fade.tween_method(func(k: float) -> void:
		_player.volume_db = linear_to_db(maxf(to * sin(k * PI * 0.5), 1e-4))
		_old.volume_db = linear_to_db(maxf(from * cos(k * PI * 0.5), 1e-4)),
		0.0, 1.0, maxf(fade, 0.01))
	_fade.tween_callback(_old.stop)


func stop(fade := 0.8) -> void:
	current = ""
	if _fade:
		_fade.kill()
	var from := db_to_linear(_player.volume_db) if _player.playing else 0.0
	var from_old := db_to_linear(_old.volume_db) if _old.playing else 0.0
	_fade = create_tween()
	_fade.tween_method(func(k: float) -> void:
		_player.volume_db = linear_to_db(maxf(from * (1.0 - k), 1e-4))
		_old.volume_db = linear_to_db(maxf(from_old * (1.0 - k), 1e-4)),
		0.0, 1.0, maxf(fade, 0.01))
	_fade.tween_callback(func() -> void:
		_player.stop()
		_old.stop())
