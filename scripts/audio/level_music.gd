extends Node
## Drop this node into a level to choose its background track.

@export_enum("lit", "margins", "boss", "ending") var track := "lit"


func _ready() -> void:
	var music := get_node_or_null("/root/Music")
	if music:
		music.play(track)
