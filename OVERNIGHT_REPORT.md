# Overnight build: the 2.5D Margins

Everything is on the branch **`overnight-2.5d-biomes`** (nothing pushed, `main` untouched).

## Play it

Main menu → **Begin in the Margins**, or:

```bash
godot --path . res://scenes/clearing/clearing.tscn
```

| Action | Keys |
|---|---|
| Move / jump | WASD · Space |
| Attack | Left click (aims at the mouse) or X · tap 3× for a combo · attack in the air to strike down |
| Dash | Shift (or C) |
| Flash (Ember burst: stuns, reveals, lights drawn things) | Right click or Q |
| Heal (fuel into an ink drop, stand still) | Hold F |
| Back to the menu | Esc |

## The story path

```
The Clearing (hub, now ~2x bigger)
  └─ cave ─► Darkwood Margins 1 ─► 2 ─► The Unlit Bridge* ─► 3 "Where the Ink Pools"
                 └─► Inkwell Shallows 1 ─► 2 "The Drowned Circle" ─► The Lamplit Field*
                       └─► Crumple Wastes 1 ─► 2 "The Pinboard" ─► The Torn Page*
                             └─► The Rubbing Room (THE ERASER, boss) ─► reveal cutscene ─► menu
```
\* light puzzle rooms (added in the light phase, see below)

- **Gates** are sealed with a red X until every monster in the room is beaten, then they open.
- **Two kinds of transition**: rune gates between rooms (with an ink-wipe), and a biome blend
  inside *Where the Ink Pools*, where grass, light, fog and music shift from forest to water as you
  walk across an inked seam.
- Each room has a title card, the Writer's captions (yellow, or shaky white when the Writer starts
  losing it), a minimap (top right) and health carried over from the last room.
- The hub's new areas: a sketch garden (pumpkin plots, red barn, crossed-out scarecrow), the
  Darkwood canopy edge, and a shrine terrace at the top of the stairs (correction circle, broken
  pillars, a statue of the Shade).

## What was checked

- Scripted playthrough of the whole chain (hub → 8 rooms → boss → cutscene), including walking
  back into the hub: right arrival gate every time, gates open only after the room is cleared,
  cleared rooms stay open, minimap fills in.
- Frame rate in a real window: 72–90 fps with no slow frames in the busiest rooms.
- Screenshots of every room.

## Not checked / known rough edges

- **Feel and difficulty**: nobody has played it with hands yet. Monster counts and health are
  first guesses; tune them in each room's `Enemies` node.
- Art is drawn in code (shapes and shaders), matching the clearing. Cult of the Lamb's look is
  hand-painted, so these are placeholders an artist can replace prop by prop.
- Attack: Vesper swings the nib-sword **and** sweeps the ink slash (decided after the night).
- Scribbles: **Settings** on the main menu picks the 2.5D Hopper (hops and pounces) or the
  platformer's Dive-bomber (flies, dives, flees light). Saved between sessions.
- Copyright: `2.5d_map_ref_ideas/` (renamed: `>` breaks Windows checkouts) holds Cult of the
  Lamb screenshots. Fine as private reference; think twice before keeping them in a public repo.

## Where things live

- `scripts/world25/` — framework: `room.gd`, `gate.gd`, `world25.gd` (autoload), `biome.gd`,
  `biome_props.gd`, `minimap.gd`, `story_ui.gd`
- `data/biomes/*.tres` — biome looks (edit colours, light, music in the inspector)
- `scenes/world25/rooms/*.tscn` — the rooms (editable in Godot)
- `tools/rooms25/build_rooms.py` — regenerates the rooms (overwrites hand edits)
- `CLAUDE.md` — project brief for future Claude sessions

## Merging into main

```bash
git checkout main
git merge overnight-2.5d-biomes
git push origin main
```

## Light phase (added after the first night)

The design doc's rules of light now work in 2.5D (`scripts/world25/light.gd`):

- **The Ember**: Vesper's own glow (fuel bar under the ink drops). Hits refill it; low fuel shrinks
  the glow. **Flash** (right click / Q, 25 fuel) stuns monsters, unfolds Crumples, drags Smudges
  up, scatters Dive-bombers, scorches Crossed-Out shields, lights lanterns, and its afterglow keeps
  drawn things solid. **Heal** (hold F, 33 fuel) turns fuel into an ink drop.
- **Drawn bridges** (`drawn_bridge.gd`): planks solid only while lit (Ember, lanterns, braziers,
  Flash, searchlight); unlit planks are dashed ghosts. They flicker before vanishing. Falling
  returns you to the last safe ground for one drop.
- **Lanterns**: unlit braziers you light by hitting them or with a Flash; they stay lit.
- **The searchlight** (`searchlight.gd`): the Writer's green lamp. Patrols, investigates Flashes
  ("Where did you go?"), locks on ("There."). Standing in it fills the erase meter (Vesper whitens)
  and costs a drop. Solid props cast shadows you can hide in. It erases monsters it catches, and
  makes drawn bridges real.
- **New rooms**: The Unlit Bridge (Darkwood), The Lamplit Field (Shallows), The Torn Page
  (Wastes, a bridge the searchlight sweeps along).

Fixed on the way: rooms' east/west gates were mirrored by the room generator (you could arrive over
the void). Every gate is now checked to face out with its arrival point on solid ground.
