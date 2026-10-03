# Vesper cutscenes

Four comic-page cutscenes for Godot 4, drawn entirely in code (no assets).

| Scene | Story beat |
|---|---|
| `scenes/cutscenes/cs_opening.tscn` | The Lit Pages: the Writer, the lamp, the gutters |
| `scenes/cutscenes/cs_page3.tscn` | Page 3: the Shade, "THE END", Vesper is crossed out |
| `scenes/cutscenes/cs_reveal.tscn` | The Margins: the Shade was saving him; the monsters are old drafts |
| `scenes/cutscenes/cs_ending.tscn` | The Desk: the Writer's loss, the goodbye |

## Install
The files live in `scripts/cutscenes` and `scenes/cutscenes`.
No existing file is changed and no autoload is needed.

## Play one
- As a full scene: run the `.tscn`, or `get_tree().change_scene_to_file(...)`.
  Set `next_scene` in the inspector to choose where it goes afterwards
  (the opening already points at `res://scenes/levels/test_level.tscn`).
- Over gameplay: add it under a CanvasLayer. It pauses the game while it
  plays, then removes itself and emits `finished`:

```gdscript
var cs = preload("res://scenes/cutscenes/cs_page3.tscn").instantiate()
$UI.add_child(cs)          # any CanvasLayer
await cs.finished
```

To start the game with the opening, set Project Settings > Run > Main Scene
to `cs_opening.tscn`.

## Controls
Space / Enter / Z / X / J / left click / gamepad A: next panel. Esc: skip.

## Edit
All text and art is in `scripts/cutscenes/cutscene_data.gd`. Each panel is a
rectangle, a list of draw ops and a list of captions. The draw ops are listed
in `cutscene_panel.gd` (`_op`). To use Ridhim's art later, add a `"sprite"`
op there that draws a texture, and swap it into the panels.
