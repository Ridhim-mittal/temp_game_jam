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

## Music
Four tracks in `audio/music/`, all built on one melody: `lit` (warm),
`margins` (slow, minor), `boss` (fast, minor), `ending` (plays once).
The `Music` autoload plays them: `Music.play("boss")`, `Music.stop()`.
Each cutscene scene has a `music` property, and a level picks its track
with a `LevelMusic` node (`scripts/audio/level_music.gd`).
`tools/make_music.py` regenerates the tracks (needs Python, numpy, scipy, ffmpeg).

## Monsters
Run `scenes/levels/monster_test.tscn` (F6) to try them: one per station.
All extend `scripts/enemies/enemy_base.gd`; each is one script plus a scene
in `scenes/enemies/`, so drop the scene into any level.

| Scene | Behaviour |
|---|---|
| `scribble.tscn` | Flies, dive-bombs; light scatters it |
| `crumple.tscn` | Armoured rolling ball; dazed by walls, unfolded by light |
| `crossed_out.tscn` | Red X blocks the front; hit from behind or pogo; light burns the X |
| `smudge.tscn` | Invisible until it lunges; light reveals it |
| `inkwell.tscn` | Turret that lobs ink blobs, which leave slowing puddles |
| `eraser.tscn` | Mini-boss; only hurt while tired; erases blocks in the group `erasable` |

Light is a stand-in for now: `scripts/world/light_zone.gd`. Anything in the
group `light` with a `lights(point) -> bool` method counts as light.
