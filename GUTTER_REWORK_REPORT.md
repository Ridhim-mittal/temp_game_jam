# Gutter rework report

Branch `gutter-rework`, made from `main`. Almost everything here is the 2.5D part (the hub
and `scenes/world25/rooms/`). Section 14 (the shop, weapons and outfits) also changes the 2D
player, its sword and HUD, and gives the 2D monsters a `stun_for()`; the 2D levels themselves
are untouched.

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

10. **Four levels** (your story outline): after the hub, the Gutter is four rooms in a row.
    - **Level 1, The Inkwood** (`darkwood_1`): where Vesper lands after escaping the eraser.
      It has one of every ordinary monster: two Scribbles, a Crumple, a Smudge, an Inkwell, a
      Crossed-Out and a diving Scribble. They're spread out, and the lamp is slow (easy).
    - **Level 2, The Red Pen** (`shallows_pen`): the Red Pen fight with its wet-ink circles,
      as before, but two of the Writer's lamps hunt you through it.
    - **Level 3, The Torn Page** (`wastes_gap`, the room in your screenshot): the bridge is a
      pencil sketch that never forms on its own.
      - Stand at its edge and hold Q: ink runs out from Vesper's feet and inks the planks in
        for good, about 5 units per hold, for 3 Ember a plank. Hits refill the Ember.
      - A "HOLD Q INK THE BRIDGE" prompt shows at the edge.
      - Away from the bridge, Q is still the Flash.
      - Made gentler: a shorter bridge, one slow lamp, no searchlight, and no Inkwells,
        Crumples or divers (three Scribbles, a Smudge and a Crossed-Out).
    - **Level 4, The Rubbing Room** (`arena`): the Eraser, made hard.
      - More health (26), faster walking and charges, a shorter wind-up and shorter rests.
      - Below half health it turns FURIOUS: a charge that misses goes straight into a second
        one. Making it slam into a pillar still tires it at once.
      - The room's two fast lamps hunt as well.
    - **Retired rooms:** the other eight rooms are no longer linked, and their scenes stay on
      disk. `OLD_ROOMS = True` in `tools/rooms25/build_rooms.py` rebuilds them.
    - **Spawn protection:** for 2 seconds after arriving in any Gutter room, or coming back
      after dying, nothing can hurt Vesper: monsters, falls and the lamps' light all miss, and
      he blinks while it lasts.

11. **Level 1, reworked** (your notes on the hub and the room after it):
    - **Comic-book background:** the hub and its next room no longer float over a red
      occult abyss. Below the floor lies a printed comic page in the 2D levels' style, drifting
      slowly: panels with halftone sunbursts, a pop-art skyline, pencil cross-hatching, speed
      lines round a POW burst, Ben-Day dot skies and a halftone moon. Torn-out panels and
      sound-effect words ("KRAK!", "SKRITCH", "THE END?") float round the floor, two giant
      pencils lean over the page, and paper dust drifts up. Other levels keep their old
      background for now (`backdrop_style` in room.gd).
    - **Symbols from the game:** every symbol (the ritual rings, the rune stones and graves,
      the marks scratched in the floor) is now one of the Writer's marks, in every level. The
      marks are the Writer's eye, an ink drop, a pen nib, a quill, the Ember's flame, ¶, *, a
      speech bubble, a comic POW burst and a question mark. The pentagram in the rings is now
      a great pen nib.
    - **Fewer ink blobs in the hub:** 3 Scribbles instead of 7.
    - **Forward only:** the gate you came in through never opens again. A moment after you
      arrive, its sketched path rubs itself out, slab by slab. This applies to all four
      levels.
    - **The Half-Drawn** (new monster, from your sheet): the only monsters in the room after
      the hub, four of them.
      - **Look:** a tall hooded ghost. Its left half is inked (pale ghostly teal, a torn robe,
        a skull face with glowing eyes and a nib-blade in its hand). Its right half is raw
        pencil wireframe, ending in a stub arm. A torn patch of nothing shows through its
        chest.
      - **Fight:** it drifts after you and raises the blade high behind its head with its eyes
        flaring (a slow, clear tell), then slashes across an arc in front for one ink drop.
        Touching it doesn't hurt; only the blade does.
      - **Counterplay:** hit it during the windup and it staggers out of the swing. Three hits
        and it's gone ("UNWRITTEN").

12. **Light, hearts and a scribble you can't see** (your next notes on Level 1):
    - **Q works like the 2D Ember.** Hold Q to raise it:
      - **Light:** its light swells to a bigger pool and becomes the Writer's kind of light.
        It shows the unfinished monsters, dries the Red Pen's wet ink and melts its letters.
      - **Meter:** it drains while held. Let go and it comes back after a moment, faster
        beside a lit lantern. Run it dry and it gutters out until a fifth of the bar is back.
      - **HUD:** the Ember bar shows its Q key.
      - **The bridge:** pressing Q at the sketched bridge, or holding the Ember still beside
        it, inks it as before.
    - **Right click dashes** (Shift still works). The old Flash is gone from the controls;
      the raised Ember does its job.
    - **Six hearts** replace the health bar. A lost heart flashes and empties, the last one
      pulses, and a healed one glows green.
    - **The monster, redrawn as an unfinished scribble:**
      - **Look:** drawn entirely in pencil and ink strokes that jitter like hand-drawn
        animation. A tangled scribble body, half an inked outline, a head that's still only
        construction lines with an angry brow and a jagged mouth, a nib-blade for one arm,
        a dashed half-arm for the other, and a scribble tail.
      - **Unseen:** out of your Ember's light it's a faint pale ghost (only its eyes catch
        the light), and your sword goes straight through it ("NOT DRAWN YET").
      - **Seen:** hold Q and the ones inside the light ink in, solid enough to cut.
      - **Faster:** a much quicker windup and slash (0.38 s, then 0.14 s) and faster
        movement. Still 3 hits, and still staggered if hit during the windup.
      - **Prompt and lore:** "HOLD Q TO SEE THEM" floats over Vesper while one is near and
        unseen, and the Writer explains it on entering the room.
    - **Vesper's shrine** replaces the bleeding-eye altar in the hub.
      - **Statue:** a pale plaster statue of Vesper, sword raised, the Ember burning above
        it, with a gold "VESPER" plaque.
      - **Offerings:** his red scarf draped over the steps, ink pots, quills, stacks of
        comic pages and cream candles with golden flames, in an Ember-gold ring of the
        Writer's marks. The skulls are gone.

13. **The Half-Drawn, redrawn as a figure again** (your note: "too much like random
    squiggles"):
    - **Look:** back to the hooded ghost from your sheet, now drawn like an unfinished ink
      drawing. The left half is drawn in: a pale ghostly-teal fill with comic hatching in
      its shadows, inked outlines that jitter like hand-drawn animation, a tattered robe, a
      pointed hood round a skull face, a nib-blade in its hand and a torn hole in its chest.
      The right half is only dashed pencil construction lines, and that arm stops in a stub.
    - **Unseen:** much harder to see. Out of the Ember's light only hints of it show:
      - its two glowing eyes, which flare orange when it raises the blade
      - a few motes of ink and pencil dust drifting off it
      - now and then a short piece of one of its lines, flickering in and out
    - **Seen:** hold Q and the ones in the light ink in, as before.

14. **A shop, weapons and outfits; a broken shrine** (your next notes):
    - **Half-Drawn:** 5 hits instead of 3.
    - **The shrine:** now a forgotten, worn shrine in grey stone. Only the lower half of
      Vesper's statue still stands, broken off at the chest. His head, his hat, an arm and the
      snapped blade lie in the rubble around the steps. The plaque is worn, the offerings are
      old (a faded scarf, tipped ink pots, yellowed pages, a few candles), and the ring of
      marks is dim.
    - **The skill tree is gone,** from the shrine and from the pause menu. Clearing rooms no
      longer gives Ink Points.
    - **Quire's Curios,** where Patch the dog used to sit: a little shop counter like your
      screenshot. It's dark navy wood with pale curls carved round an arch, a domed lamp at
      one end, and Quire (a pale, long-tailed paper creature with a quill behind his ear)
      sitting on the other. Wares are on show and a hanging sign reads QUIRE'S CURIOS.
    - **Opening the shop:** press E at the stall, pick SHOP on the pause screen (Esc, now
      the same in 2D and the Gutter; SHOP takes the skill tree's place), or press **B
      anywhere**. The game pauses while it's open.
    - **Money:** the Lumen coins you pick up in the 2D levels. They are kept between runs.
    - **The 2D prompt:** once you have enough coins for something, a caption says "ENOUGH
      COINS! PRESS B TO OPEN THE SHOP" (once a run), and a "B SHOP" tag stays under the coin
      counter while you can afford something.
    - **Shop tabs:** weapons, upgrades, hats, scarves, cloaks and armor. A preview of Vesper
      shows what you're looking at.
    - **Weapons, in both modes.** Each one changes the normal swing, and holding attack
      then letting go does its special:
      - **Nib-Sword** (you start with it): the ink wave.
      - **Quill Rapier** (30): faster swings. QUILL VOLLEY throws a fan of 3 quills that
        pierce.
      - **Brush Maul** (40): +1 damage and a wider, slower swing. INK SLAM throws a ring of
        ink out all round you.
      - **Corkscrew Nib** (55, from your sheet): quick, short thrusts. PEN-DRILL spins
        Vesper like a drill while held, dragging monsters in and grinding them; letting go
        bursts them outward.
      - **Prism Saber** (65, from your sheet): its hits stun longer and it can cut a
        Half-Drawn without raising the Ember. BLINDING SWEEP is a rainbow arc that blinds everything in
        front and turns a Haunting Lamp's light away from you (the lamp loses you).
      - **Lantern Flail** (50, a "light and twist" weapon of my own): long reach. LANTERN
        WHIRL swings the lantern round you while held, hitting everything it passes. Its
        light makes 2D sketches solid and shows Half-Drawn without raising the Ember. It
        burns Ember.
    - **Upgrades** (per weapon, bought in order):
      - SHARPENED (15): +1 damage
      - QUICK HAND (30): the special charges 40% faster
      - MASTERWORK (50): a stronger special (bigger drill pull and burst, 5 quills, a wider
        slam or sweep, a brighter whirl, a longer wave)
    - **Outfits:**
      - 7 hats (each with its own band colour)
      - 6 scarves
      - 6 cloaks

      They show on both the 2D and the 3D Vesper.
    - **Armor** still works and now counts in the 2D levels too (+20 health a drop, longer
      safety, the wax seal).

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
| Lamp per room | `room.gd` `haunt_scale`, `haunt_lamps` (-1 = profile), `haunt_enabled`; set in `tools/rooms25/build_rooms.py` (`r.haunt_scale`, `r.haunt_lamps`) |
| Spawn protection | `clearing_player.gd`: `spawn_protection` (2 s) |
| Inking the bridge | `drawn_bridge.gd`: `ink_reach` (5), `ink_speed` (6), `ink_cost` (3 Ember a plank); `ink_only` off = old light rule |
| Eraser difficulty | `build_rooms.py` arena block (hp, walk_speed, lunge_speed, windup_time, tired_time, cooldown); `eraser_3d.gd` `double_charge_below` (0.5) |
| Which monsters where | `build_rooms.py`, one block per level (`r.enemy(...)`) |
| Half-Drawn | `half_drawn_3d.gd`: `drift_speed` (3.2), `strike_range`, `reach`, `arc`, `windup_time` (0.38), `strike_time` (0.14), `recover_time`, `cooldown`, `blade_damage`; `hp` (5) in `half_drawn.tscn`; look in `unfinished_model.gd` (`model_scale`, `hover`, eye glow, motes), `scribble_stroke.gdshader` (`width`, `boil`, `ghost_alpha`, `glimpse`, `glimpse_size`) and `ink_fill.gdshader` (`fill`, `fill_alpha`, `hatch_px`) |
| Raised Ember (Q) | `clearing_player.gd`: `raised_radius` (5), `raise_drain` (16/s), `regen` (14/s), `regen_delay` (0.6 s), `lantern_regen` (40/s), `relight_at` (20) |
| Hearts | `clearing_player.gd` `max_health` (6); look in `clearing_hud.gd` (`HEARTS_AT`, `HEART_STEP`) |
| Vesper's shrine | `altar.gd`: `stone`, `statue_scale`, `ring_color`; the broken statue in `_build_statue()`, the fallen pieces in `_fallen_head()` / `_fallen_hat()` |
| Shop prices, items | `scripts/core/catalog.gd` `ITEMS` (price, effect, look, special) and `UPGRADES` |
| Weapon specials | "Weapon Specials" exports on `scripts/player/player.gd` (2D, px) and `clearing_player.gd` (2.5D, units): drill radius / pull / tick / burst, sweep radius / stun, whirl reach / drain, dart count / speed, slam radius / damage, `charge_time` (2.5D) |
| Quire's stall | `scripts/world25/shop_stall.gd`; the carving in `shop_carving.gdshader` |
| Background style | room.gd `backdrop_style` (SIGIL / COMIC); the page in `comic_page.gdshader` (`brightness`, `panel_size`, `drift`), words in room.gd `SOUND_WORDS` |
| Symbols | `shaders/world25/writers_marks.gdshaderinc` (add a mark, raise `WM_COUNT`) |
| Lamp difficulty | room.gd `_spawn_haunt()`: Relaxed speed ×0.75 / telegraph ×1.3, Hard ×1.25 / ×0.8 |
| Lamp light direction | `haunt_lamp.gd`: `SOURCE_DIR` (from up and towards the back: props throw shadows towards the camera) |

## Checks run

These ran with Godot 4.7-stable under Xvfb with software OpenGL.

- **Headless runs:** the hub, the rooms, the 2D levels (City, Sketchbook, Long Drop, Ink
  Cavern) and the main menu load and run without script errors. The only messages are the
  leak warnings at exit, which `main` already has.
- **`tests/gutter/test_phase1.gd`: 35/35 checks.**
  - Cursor in every menu.
  - A swing hits a monster in each of the 8 directions, both by facing and by
    hold-and-swing.
  - Aim assist on, off, out of the cone and out of range.
- **`tests/gutter/test_phase2.gd`: 19/19 checks** over the hub and the four levels.
  - No grass, farm or cosy props or round doors in any room, and no shop but Quire's in
    the hub.
  - No coin drops.
  - Patch is gone. The shop opens with E at Quire's stall, with B in a room, and from the
    pause menu; it pauses the game and closes again.
  - The skill tree is gone (from the shrine and from pause).
- **`tests/gutter/test_phase5.gd`: 17/17 checks.**
  - Each room has the right number of lamps (1, 2, 1 and 2 in the four levels), never on
    the arrival point.
  - 90 s of the Rubbing Room's two lamps hunting: every strike came after its full
    telegraph.
  - Hiding behind a wall makes the lamp lose Vesper.
  - The Spine's lamp never damages or strikes.
  - The circles glide, with no jumps between physics ticks. The limit is 1 unit per test
    tick: the Rubbing Room's lamps glide onto their marks at up to 0.6.
- **`tests/gutter/test_levels.gd`: 43/43 checks.**
  - The gates chain hub → 1 → 2 → 3 → 4, and none leads to a retired room.
  - Every level's way in is one-way. In a cleared room the way on opens and the way back
    stays shut.
  - The hub has 3 Scribbles and the next room has only Half-Drawn (4). Level 3 has no
    Inkwells, Crumples or divers. The Eraser is tougher and turns furious at half health.
  - The Half-Drawn:
    - Touching it is safe, and "HOLD Q TO SEE THEM" shows while it's unseen.
    - Its blade takes a heart.
    - Out of the light a hit passes through it.
    - Holding Q reveals it and the prompt goes; in the light a hit mid-windup staggers it,
      and five hits finish it.
  - Six hearts, and the hub's shrine holds a statue of Vesper.
  - Spawn protection: a hit and a lamp's light do nothing for 2 s, then hits land again.
  - The bridge:
    - It stays a sketch while Vesper stands by it.
    - Holding Q inks 6 of 8 planks for 3 Ember each, and they stay.
    - One more hold finishes it, and Vesper walks across without falling.
    - With no Ember, Q inks nothing.
  - The Ember:
    - Right click is dash, not the light.
    - Holding Q raises a bigger light (radius 3 → 5) of the Writer's kind and drains about
      15 a second.
    - Let go and it comes back.
    - Run dry, it gutters out and won't rise until it has refilled.

- **`tests/gutter/test_shop.gd` (new): 47/47 checks.** It puts your saved progress back
  afterwards.
  - The purse:
    - Buying, equipping and the three upgrades in order, with their prices.
    - The retired Compass Edge isn't sold.
    - No upgrades for a weapon you don't own.
  - 2D, the shop:
    - A coin goes into the purse.
    - The pause screen lists SHOP (no skill tree). Picking it opens the shop on top, and
      closing it comes back to the pause screen.
    - At 10 coins "PRESS B" and the B SHOP tag show.
    - B opens the shop and pauses the level. Buying a hat in it puts the hat on Vesper at
      once.
    - Esc closes the shop and play goes on.
  - 2D, each special against a real monster:
    - The quill volley, end to end (hold attack, let go): three quills fly and hit.
    - The slam hits.
    - The drill drags a monster from 150 px to 57 px, then bursts.
    - The sweep stuns for 1.6 s.
    - The whirl's light reaches round Vesper, burns Ember and goes when it stops.
    - The Nib-Sword fires the ink wave.
    - SHARPENED adds 1 damage.
  - The Gutter:
    - The Prism Saber cuts an unseen Half-Drawn.
    - The sweep stuns, and sends a hunting lamp to LOST with its meter emptied.
    - The drill drags a monster from 2.6 to 1.3 units and spins Vesper.
    - The whirl shows a Half-Drawn without Q and burns Ember.
    - The slam, end to end, hits all round.
    - The quills hit.
  - Outfits: the hat, band and cloak reach the 3D model and the billboard art; the 3D model
    carries the equipped weapon.

## Not verified

- **Frame rate:** 60 fps on real hardware. This machine renders on the CPU, so frame rate
  means nothing here.
- **Audio:** the gate chime. It is synthesised in code, and this machine has no audio
  device.
- **Gamepad:** stick feel. Only keyboard-style input was simulated.
- **Full playthrough:** I didn't play the whole story start to finish. Each room was loaded
  and tested on its own.
- **Feel of the weapons:** each special was checked to work, not tuned by playing. The
  numbers are in the tuning table.
- **Controls on `main`:** while this round was in progress, `main` moved the light to
  right click (Q is no longer used) and dash to Shift, and added one pause screen for 2D and
  2.5D. I merged that in and kept it. Earlier sections of this report still say Q.
