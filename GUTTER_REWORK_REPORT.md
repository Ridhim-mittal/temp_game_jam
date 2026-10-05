# Gutter rework report

Branch `gutter-rework`, made from `main`. Everything here is the 2.5D part (the hub and
`scenes/world25/rooms/`). The 2D levels are untouched.

## What changed

1. **Controls and combat** (`scripts/clearing/clearing_player.gd`)
   - **Cursor:** hidden while you play a room, shown in every menu, overlay and cutscene.
     World25 `_update_cursor()` is the only place that sets it.
   - **Aiming:** swings and dashes follow `facing_dir`, snapped to 8 directions, or the
     direction held as you press. The mouse position is ignored.
   - **Aim assist:** turns swings toward a nearby monster. The hit radius is +15%.
   - **Facing chevron:** sits on the ground in front of Vesper.
2. **3D Vesper** (`scripts/clearing/vesper_3d.gd`)
   - **Model:** a procedural model with scarf physics and poses for idle, run, jump, dash,
     three combo swings, hurt, heal and death.
   - **Effects:** keeps the erase whitening and the hurt blink.
   - **Status:** the character is due for another pass.
3. **No Cult of the Lamb tells**
   - **Hub and rooms:** grass, reeds, farm, mushrooms, red leaves, canopies, coral, tube
     plants, nests and the round doors are gone.
   - **No shop or coins:** Patch is a guide who gives hints and lore on E. There are no coin
     drops and no coin counter.
   - **Minimap:** redrawn as a torn notebook scrap.
   - **Altar:** replaced by the Broken Nib.
4. **Darker, in the original art style.**
   - **Revert:** the first, grey "Blightbound" restyle (old phase 3) was reverted at your
     request.
   - **Mood:** the original art is kept and made dark instead: darker palettes, low
     ambient light, moonlight tinted per zone, and a heavy vignette whose corners sink to
     black.
   - **Floor:** a stone-tile floor instead of painted lawn.
   - **Edges:** rubble piled along room edges.
   - **Ember:** Vesper's Ember lights a bigger pool.
   - **Hub:** has its own violet "Spine" biome, broken pillars and braziers along the walk
     to the shrine, and a small lit graveyard where the farm was.
5. **Gates**
   - **Sealed:** no red X. The path beyond is a grey pencil sketch with cold lanterns.
   - **Opening:** a line of light draws itself outward, the path fills in, pale-gold
     lanterns ignite, a chime plays, and the exit keeps pulsing.
   - **Hub:** the cave door works the same way.
6. **The Writer's Haunting Lamp** (`scripts/world25/haunt_lamp.gd`), in every room.
   - **Look:** a white column of light and a turning circle of proofreading marks.
   - **Hunting:** it seeks Vesper, marks a target circle (the outline fills clockwise),
     then strikes.
   - **Damage:** standing in its light fills the erase meter; a full meter costs a drop.
   - **Hiding:** stay behind solid props or out of its light long enough and it loses him.
   - **Monsters:** monsters caught under it are erased, so luring them in works.
   - **Fairness:** no strikes during transitions or boss intros, never a strike without
     the full telegraph, and it never starts on the arrival point.
   - **Hub:** the hub lamp only searches.
   - **Writer's lines:** escalate by zone, each once per room.
7. **Third round (your feedback on the map):**
   - **The Spine (hub):**
     - Near the original layout again, on bare dirt (new ground mode).
     - The original altar is back, standing in a glowing ritual circle with red candles and
       skulls.
     - My walkway pillars and braziers are gone.
     - Rune stones flank the cave, there's a second glowing circle in the east, and the
       graveyard has candles and a skull heap.
   - **Cryptic symbols everywhere:**
     - Glowing sigils are scratched into every zone's floor.
     - Rune stones, red candles and skull heaps appear in the rooms.
     - Graves now have a dirt mound, skulls and bones, and sometimes a candle.
   - **Darkness:** the screen is dark around Vesper except where there's light (his Ember,
     braziers, candles, open gates, the lamp). Glowing things still shine through.
   - **HUD:** a health bar and a healing counter replace the hearts.
   - **Living background:**
     - A huge sigil circle turns slowly in the abyss below each room.
     - Mist drifts over it and embers rise.
     - Skull heaps and ink statues stand in the void, lit red from below.
   - **The Writer's lamp:**
     - It moves with weight: it accelerates, eases in, and never jumps or snaps.
     - It's drawn smoothly between physics ticks and only wanders over the floor.
     - When there are two, they flank Vesper instead of stacking.
     - Both always look the same: a straight pillar with a slight lean as it moves.
8. **Vesper, the Traveler's Ghost** (from your reference model): a tall white egg head with
   two black dash eyes under a wide black hat with a red band, a chunky red scarf with a
   trailing tail, a purple cloak open over a cream tunic with a pointed hem, grey legs and
   brown boots, and a gold-hilted broadsword strapped across his back. During a combo an arm
   comes out of the cloak with the sword; it goes back on his back a moment later.
   - **Dash animation:** a hard forward lunge with his body stretched, the cloak and scarf
     streaming back and the hat pressed back. A puff of dust marks the launch, and pale ghost
     afterimages fade along the path (`afterimage_every`, `afterimage_life` in
     `vesper_3d.gd`).
9. **Names:** title cards, captions and biome names use The Spine, The Inkwood, The Drowned
   Margin, The Torn Wastes and The Rubbing Room.

## Tuning knobs

| What | Where |
|---|---|
| Facing snap, deadzone | `clearing_player.gd`: `snap_directions` (8; 0 = analog), `facing_deadzone` |
| Aim assist | `clearing_player.gd`: `aim_assist_angle` (50°, either side), `aim_assist_range` (3.5); Settings → Aim Assist |
| Hit size | `clearing_player.gd`: `attack_radius` (1.15) |
| Cursor | Settings → Cursor in game (off) |
| 3D model on/off | `clearing_player.gd`: `use_3d_model`; model look in `vesper_3d.gd` exports (`model_scale`, `turn_speed`, scarf, colours) |
| Ember pool | `clearing_player.gd` `_update_ember_light()` (range 3.4–6, energy 0.9–1.9) |
| Darkness per zone | `data/biomes/*.tres`: `ambient_energy`, `sun_energy`, `sun`, `vignette`, `edge_darkness`, palette |
| Edge rubble | `island.gd`: `rubble` (0 = none, 1 = default) |
| Darkness round Vesper | `data/biomes/*.tres` `darkness` (0 = off); `darkness.gd` `ember_scale`; shader `glow_through` |
| Floor sigils | `data/biomes/*.tres` `runes` (density), `rune_color` |
| Background | `room.gd` `backdrop` (on/off) and `_build_backdrop()` |
| Lamp spacing / feel | `haunt_lamp.gd` `_steer()` (accel), `_separation()` |
| Gate timing / colour | `gate.gd`: `DRAW_TIME` (0.8 s), `lantern_color` |
| Lamp per zone | `data/haunt/*.tres` (`haunt_profile.gd`): lamps, grace, seek_speed, circle_radius, strike_every, telegraph, erase_fill, lose_after, can_damage, strike_erase, linger, the Writer's lines |
| Lamp per room | `room.gd` `haunt_scale` / `haunt_enabled`; set in `tools/rooms25/build_rooms.py` (`r.haunt_scale`) |
| Lamp difficulty | room.gd `_spawn_haunt()`: Relaxed speed ×0.75 / telegraph ×1.3, Hard ×1.25 / ×0.8 |
| Lamp light direction | `haunt_lamp.gd`: `SOURCE_DIR` (from up and towards the back: props throw shadows towards the camera) |

## Checks run

These ran with Godot 4.7-stable under Xvfb with software OpenGL.

- **Headless runs:** the hub and the rooms load and run without script errors. The only
  messages are the leak warnings at exit, which `main` already has.
- **`tests/gutter/test_phase1.gd`: 35/35 checks.**
  - Cursor in every menu.
  - A swing hits a monster in each of the 8 directions, both by facing and by
    hold-and-swing.
  - Aim assist on, off, out of the cone and out of range.
- **`tests/gutter/test_phase2.gd`: 33/33 checks.**
  - No grass, farm or cosy props, shop or round doors in any room.
  - No coin drops.
  - Patch talks.
  - The skill tree opens at the shrine and from pause.
- **`tests/gutter/test_phase5.gd`: 32/32 checks.**
  - Every room spawns the right lamps with its profile, never on the arrival point.
  - 90 s of the Wastes' lamps hunting: every strike came after its full telegraph.
  - Hiding behind a wall makes the lamp lose Vesper.
  - The Spine's lamp never damages or strikes.
  - The circles glide, with no jumps between physics ticks.

## Not verified

- **Frame rate:** 60 fps on real hardware. This machine renders on the CPU, so frame rate
  means nothing here.
- **Audio:** the gate chime. It is synthesised in code, and this machine has no audio
  device.
- **Gamepad:** stick feel. Only keyboard-style input was simulated.
- **Full playthrough:** I didn't play the whole story start to finish. Each room was loaded
  and tested on its own.
