extends Node
## Root of scenes/cutscenes/cs_book.tscn: hands over to the animated opening
## (cs_book.gd), which lives on the scene tree's root so it can carry on
## into the City level.

const CsBook = preload("res://scripts/cutscenes/cs_book.gd")


func _ready() -> void:
	CsBook.start(get_tree())
