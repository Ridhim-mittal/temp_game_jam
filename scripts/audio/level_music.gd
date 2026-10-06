extends Node
## Drop this node into a level to choose its background track.

@export_enum("lit", "margins", "boss", "ending", "city", "deep", "beast", "repose", "silk", "dread", "hunters", "hunt", "ruin", "inkcave", "hand", "duel") var track := "lit"
## How long it crossfades in over whatever was playing (music.gd).
@export var fade := 0.8


func _ready() -> void:
	var music := get_node_or_null("/root/Music")
	if music:
		music.play(track, fade)
