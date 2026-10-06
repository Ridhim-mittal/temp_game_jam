# The Gutter / Vesper — Godot 4.7 game jam project

Comic-book game about light and ink (design doc: `The-Gutter-Game-Design-Document.pdf`,
written for Unity — we build everything in Godot 4.7, GDScript, `gl_compatibility` renderer).
All art is drawn in code (`_draw()`, shaders, primitive meshes); the two textures are the backdrop
paintings of Shade's City and the Ink Cave (`assets/backgrounds/shades_city.webp`, `ink_cave.webp`).

## Two modes
- **2D platformer** (`scenes/levels/`, `scripts/player/`, `scripts/enemies/`): Hollow Knight-style
  movement/combat. Monsters extend `scripts/enemies/enemy_base.gd` and draw via `paint()`.
- **2.5D top-down** ("the Gutter": dark, moody rooms; `scenes/clearing/`, `scenes/world25/`,
  `scripts/clearing/`, `scripts/world25/`, `shaders/clearing/`): 3D scenes, tilted camera.
  Vesper is a procedural 3D model, "the Traveler's Ghost" (`scripts/clearing/vesper_3d.gd`: black
  hat with a red band, white egg head, red scarf, open purple cloak, broadsword on his back that
  comes out on swings; dash = lunge + ghost afterimages; `use_3d_model = false` on the player
  brings back the 2D art on a billboard). Monsters reuse the 2D art drawn into a
  SubViewport (`monster_puppet.gd`), except the Half-Drawn (`half_drawn_3d.gd`), which has its own
  3D model (set up with monster_3d.gd `setup_monster_model()`): `unfinished_model.gd`, the hooded
  ghost as an unfinished ink drawing: a pale teal fill with comic hatching (`ink_fill.gdshader`)
  under camera-facing ink strokes (`scribble_stroke.gdshader`, the lines "boil"); left half drawn in
  (tattered robe, pointed hood round a skull face, nib-blade arm, a torn chest hole), right half only
  dashed pencil guides and a stub arm. Out of the raised Ember's light only hints show (glowing eyes
  that flare orange on a windup, ink motes, short flickering pieces of line: `glimpse`) and a sword
  passes through ("NOT DRAWN YET"); hold right click and inside the light it inks in and can be cut
  (`revealed`, player `ember_reveals()`; group "needs_ember" drives a "HOLD RIGHT CLICK TO SEE THEM"
  prompt over Vesper; only the raised Ember counts: no weapon, not even the Prism Saber or the
  Lantern Flail's whirl, cuts one unseen; `_blocks()` re-checks the light at the moment of the hit).
  Quick windup, arc slash, only the blade hurts, hp 5 (half_drawn.tscn). (The earlier toon-shaded
  model, `half_drawn_model.gd` + `half_drawn.gdshader`, is kept but unused.)
  The 2.5D Scribble (`scripts/clearing/scribble.gd`, `scenes/clearing/scribble.tscn`; not a
  monster_3d.gd) is the scary "vibrating swarm" from the sketch sheet: a camera-facing quad
  (`scribble.gdshader`: pen and pencil scratch loops on a 4-drawing loop round a hatched black core,
  bristling wisps, slanted white eyes that burn red on a windup, a toothed mouth, `mouth` / `rage` /
  `fray`; the quad jitters every frame). LURK → SHRIEK ("SKRITCH!") → STALK (circles at
  `keep_distance`, just out of sword reach, in jerky bursts, stays on its island) → WINDUP (a red
  pencil scratch races along the floor where the claw lands: `scribble_aim.gdshader`) → CLAW (a
  shape-shifting reach, `claw_reach`, `scribble_claw.gdshader` on a quad turned about its axis;
  only the claw hurts, a dash dodges it) → TANGLED (the arm reels back, it can't move: hit it).
  It never steps into a monster light and backs out of one; raising the Ember on a windup stuns it
  (`light_stun`, the parry). At most `max_attackers` (2) wind up at once (group "scribble_claw").
  Pen-scratch sounds are synthesised in the script.

## 2D story start (main menu PLAY)
`cs_book` (scripts/cutscenes/cs_book.gd: ~20 s animated opening, a comic book on a desk opens,
page one says "I JUST HAD THE CRAZIEST ADVENTURE...", the page turns and the camera dives into the
first panel, which becomes the live City; all drawn in code, sounds synthesised; Esc/Enter skips;
the old click-through cs_opening is unused) → THE CITY (`scenes/levels/test_level.tscn`, a ~1 min controls tutorial) → glowing
`panel_door.gd` ("MOVE TO THE NEXT PANEL") → THE SKETCHBOOK (`sketchbook.tscn`, light tutorial) →
door into THE LONG DROP. Doors play `scripts/effects/panel_turn.gd` (the frame shrinks into a panel on
a comic page, pan across the gutter while the next level loads in the background, the next panel inks in
and opens out; the live level inside it is scaled via the root's `global_canvas_transform`; a door's
`tall_panel` gives a vertical level a tall panel that inks top-down). Both levels sit inside a
comic page (`scripts/ui/comic_frame.gd`; outside its `live_areas` the world is redrawn as a pencil
sketch by `shaders/pencil_outside.gdshader`, the HUD stays as is); the City opens with the Writer's typed caption
(`scripts/ui/narration.gd`, once per run via GameState.seen; the controls tutorial waits for it).
Both levels come from `tools/level2d/build_test_level.py`. Their ground, rooftops and walls are `city_block.gd`
(futuristic building tops: neon edge, cap band with indicator lights, lit window slits) and the
planks are `city_ledge.gd` hover decks with thrusters (one-way); both draw through InkBatch. The City's
trim is cyan, the Sketchbook's warm gold (generator `trim_props`) so solid ground never reads as blue pencil.
Text is kept light: two story captions a level, and the only signs in the world (`caption.gd`) are
"HIT THE LANTERN" at the shadow-ink ramps (the Sketchbook and the Long Drop's Shadow Gallery); every
other rule is taught by the tutorial's keys. The trapdoor
(`trapdoor.gd` + `gutter_fall.gd`) is kept for a later level but no longer placed.

## 2D light mechanic (the Sketchbook level)
Rules in `scripts/world/lights.gd`: sources in group `drawn_light` (`reaches(point)`) make
`sketch_platform.gd` cells solid; group `light` (`lights(point)`) is what monsters react to.
Vesper's Ember (`scripts/player/ember.gd`, hold right click) drains a meter and inks sketches in for good
when held still; `lantern.gd` (hit to toggle, refills the Ember, shadows via rays on layer 1);
`shadow_caster.gd` throws solid shadow ink.
Healing is "light or life", the same in 2D and 2.5D: hold F (heal) standing on the ground with the
Ember lowered for `heal_time` (1 s) to pour `heal_cost` (a third of the Ember) into half a bottle;
moving, jumping, attacking or a hit stops it (nothing spent). The Ember refills on its own and fast in
lantern light. 2D: player.gd `_update_heal()`, `can_heal()`; ember.gd draws the sparks going in; the
HUD marks the Ember bar in thirds and shows "F HEAL" when it would work. 2.5D: clearing_player.gd
`_update_heal()`. Taught by the tutorial's "heal" step (City and Sketchbook, the first time you're hurt
with no monster near). The level is generated by
`tools/level2d/build_test_level.py` (re-running overwrites hand edits to sketchbook.tscn).

## 2D "depth" scenery and the vertical level (`scripts/depth/`, `scenes/levels/long_drop.tscn`)
Hollow Knight-style atmosphere: one colour family per zone, far layers pale, playfield near-black
with lit edges. `depth_style.gd` holds the three palettes (0 Cavern teal, 1 Archive indigo, 2 Works
violet) and the trim drawing. `depth_backdrop.gd` (a Node2D in the level; exports `themes` +
`zone_bottoms`) builds the sky, three procedural parallax layers (`depth_layer.gd`, drawn per cell
around the camera) and a screen overlay (`depth_overlay.gd`: fringe, motes, vignette). Terrain is
`rock_block.gd` (plain collision) + `depth_trim.gd` (edge decoration, no collision); `depth_ledge.gd`
is a one-way ledge. "The Long Drop" is generated by `tools/level2d/build_long_drop.py` from a list of
room rectangles (everything else is rock); re-running overwrites hand edits to long_drop.tscn.
It has two light-puzzle rooms: the Shadow Gallery (hit lantern B, ride the shadow-ink ramp, light the
far lantern A with an ink wave, cross the blue sketch, second ramp to the ledge) and the Pendulum (a
blue sketch bridge under a swinging lantern; no spikes, since spikes can be pogoed across).
It also replays every tutorial challenge on the main path (spike pits are CUTS 200 px into the
rock, so the level's size is unchanged): a spike strip in hall 1, a 450 px dash pit in hall 2
(needs a double jump plus a dash), and in the bottom room the Sketchbook's Blue Gap and its
lantern bridge with a sign shadowing the far end. The ~1200 px drop from shaft 2's last ledge into the Shadow Gallery
can't be steered, so it is a short cutscene (`scripts/effects/fall_cutscene.gd`, an Area2D under the
ledge): the HUD (the level's UI layer) fades out, letterbox bars slide in, the camera zooms in
(`zoom_in`), player.gd `cutscene` takes the controls and the hard landing kneels without fall damage;
`hold_after_land` later it all comes back. Checkpoints sit only on the path (hall 2 landing,
gallery, tower floor, cavern, bottom x3, the last just before the boss); the nook and the side rooms have none.
It ends in the boss arena (room "arena", east of the bottom room): THE SCRIBBLED BEAST
(`scripts/enemies/scribbled_beast.gd`, run by `scripts/world/beast_arena.gd` on the arena floor at the
tear it climbs out of). A hulking two-headed scribble (heads with staring white eyes and toothed maws,
a third eye in its chest, long clawed arms, spindly legs), all frantic pen + pencil strokes redrawn at
12 fps (InkBatch, one draw call), pale rim from the enemy outline; it carries a SHIELD torn out of the
gutter (black, the white panel lines down both edges, crossed out) that always faces what it fears
most: a lit arena lantern, else the raised Ember, else Vesper; hits from that side are blocked
(`guard_arc`), so light a lantern (`ArenaLanternW/E`, the only lanterns it watches: `arena_lanterns`)
and hit its open side, or dash through it. Lantern lit for `snuff_delay` -> it lobs an ink glob
(`beast_glob.gd`, slash it to keep the light). CLAW up close, RUSH across the arena (jump it: it hits
the wall and is DAZED, shield down), STAGGER every `stagger_every` damage; phase two (half hp): faster,
red eyes, LEAP slams with floor shockwaves (`beast_shockwave.gd`) and Scribbles dragged up out of the
tear (group "beast_spawn"). Dying: light breaks out through its cracking shield, it unravels into
strokes and paper, `defeated`. The arena: intro once a run (~15 s, Enter skips; letterbox, the floor
rumbles, the tear rips open onto the gutter's dark, the shield comes up first deflecting the lanterns'
light, claws on the lip, it hauls itself out snuffing both lanterns, three eyes open, ROAR, title card
"THE SCRIBBLED BEAST", the Writer: "That wasn't supposed to get out." / "...Fine. You were never meant
to leave this page anyway, Vesper."); after a death a ~3 s short intro (GameState.seen "beast_intro");
a wall of scribble seals the way back; boss bar; a one-time "LIGHT IT!" tag after 4 blocked hits.
Ending: the camera frames its death, the Writer furious (red shaking caption, red pulse, pen scratches
across the panel: "No. No, no, no." / "That is NOT how this page ends."), then the way on opens over
the tear (level_exit.gd, for now to the main menu: the Eraser chase goes here next). The 2D player's
`cutscene` flag takes the controls (no input, no damage, the Ember can't rise). Shared:
`scripts/effects/ink_bits.gd` (paper + ink-splat particles) and `scripts/effects/sfx_synth.gd`
(synthesised roar, rumble, rip, clang, scritch, splut, thud, screech, whoosh, shatter).
Drawing cost: in gl_compatibility every draw_colored_polygon / polyline / arc / circle is its own
draw call, so the depth scenery, trims, ledges, overlay and lanterns draw through
`scripts/depth/ink_batch.gd` (same draw_* method names, `flush(self)` at the end of `_draw()` =
one triangle-array draw call). Use it for any new procedural art that draws many shapes.
The 2D player has a double jump (`air_jumps`, `air_jump_velocity` in player.gd; set 0 to turn off).
Falls of `hard_land_height` (400 px) or more end in a Hollow Knight-style hard landing (kneel that
locks control, `land_impact.gd` burst, speed lines from `fall_streaks.gd` while falling); falls of
`fall_damage_height` (750 px) or more also hurt (1..2 ink bottles). All in player.gd's "Hard Landing" exports.
Wall cling (player.gd "Wall" exports, `wall_cling = false` turns it off): pushing into a wall while
falling slides down it slowly (pose in player_visual.gd, scrape in `wall_fx.gd`); jump kicks off.
The wall just kicked off can't be re-grabbed until landing or touching the other wall, so single
walls can't be climbed (keeps the light puzzles intact); a slide also resets the fall height.
Spikes (group `hazard`) cost health and put the 2D player back on the last safe ground
(`_hazard_respawn_point()` in player.gd: stood on for 0.15 s, solid for good, no hazard within 64 px).
No loops: if that spot fails a hazard/floor check, or spikes hit again within 1.5 s before new safe
ground, it falls back to the last checkpoint pen / level start (`_respawn_point()`).

## Shade's City (`scenes/levels/shades_city.tscn`, Act 3: back in 2D after the light catches Vesper)
Chapters -> SHADE'S CITY. Generated by `tools/level2d/build_shades_city.py` (re-running overwrites hand
edits). Backdrop: the team's concept painting (`assets/backgrounds/shades_city.webp`,
`city_painting.gd`), fixed on screen; the player's Camera2D `framing_offset` (0, -226) puts the street
(`street_ground.gd`) in the bottom ~15%. Platforms: `paper_stack.gd` (CMYK bales) and
`light_cover.gd` (redaction-bar awnings / bars, a scaffold, the collapsed billboard; one-way tops).
Flow: Vesper falls in (hard landing) -> paper spiders (`paper_spider.gd`: hang on a thread and drop,
chase, rear up (0.28 s tell, hits don't stop it) then nib-stab 2 (one bottle), sometimes twice; 5 hp; wander their patch
until Vesper is near; light makes them flinch) -> the author's light (`author_light.gd`: a beam
from the painting's moon roams round Vesper between `zone_from`/`zone_to`; in it an erase meter fills,
full = 3 half bottles; nodes in group `light_cover` block it and cast a visible shadow) -> hideout + checkpoint
-> the gate (`gate_arena.gd`: ink walls rise, the sleeping Ink Blot `ink_blot.gd` wakes: claw swipe
`ink_claw.gd`, slam + floor shockwaves `ink_shockwave.gd`, ink globs `ink_glob.gd` that leave slowing
puddles `ink_puddle.gd`; 15 hp, never staggered by hits, swipe 2 / slam 3, globs 1 (half bottles); below half health it
enrages (red eye, 1.3x speed, double slams, 5 globs); light doubles damage to it; on death it melts and always drops a big heart (+6 half bottles = three ink bottles) that flies to Vesper (`drop_heal`, health_heart.gd `seek`),
the tape burns off) -> through the gate Shade's trap (`scripts/effects/shade_trap.gd`: glitch, ink
flood, "DID YOU REALLY THINK I'D LET YOU LEAVE?"; `next_scene` = the Ink Cave; with none, TO BE CONTINUED).
Awake 2D bosses (group "boss", `display_name`) get bars at the bottom of the screen: `scripts/ui/boss_bar.gd`
on the level's UI layer (two bosses side by side).

## The Ink Cave (`scenes/levels/ink_cave.tscn`, Shade's trap; chapter THE INK CAVE)
Generated by `tools/level2d/build_ink_cave.py` (re-running overwrites hand edits). A short cave: the backdrop
(`cave_backdrop.gd`) is the team's painting `ink_cave.webp` fixed on screen and made "live": the shader
`shaders/ink_cave_live.gdshader` makes the ink-fire lick upwards and flicker and the ink river ripple (masks
come from the painting's bright, saturated colours), plus embers, ink drips off the stalactites (InkBatch).
Rock: `cave_rock.gd` (`ground` = floor, `one_way` ledges, fire-lit pink lip). Flow: Vesper falls in ->
ink bats under the overhangs (`ink_bat.gd`: roost, wake together, orbit, flare wings (tell) and swoop 1 (half a bottle),
pull up at his feet, 2 hp, light scatters them; fly through rock) -> 3 paper spiders -> checkpoint + heart
-> the pit (`cave_arena.gd`): walls rise, two Ink Blots (hp 12 each) wake; each drops its big heart, and when both melt the
cave collapses (shake, cracks, falling rocks, white flash, "THE CAVE GIVES WAY..."); `next_scene` = the
finale below (with none: SHADE AWAITS / TO BE CONTINUED and the main menu).

## The finale: Shade (`scenes/levels/shade_finale.tscn`, chapter SHADE; the end of the game)
Generated by `tools/level2d/build_shade_finale.py` (re-running overwrites hand edits): a walled stretch of
Shade's City street (x 0..1600, camera limits) with three one-way bars. All of it is run by
`scripts/world/shade_finale.gd` (`_run()`, a chain of awaits; its own captions: the Writer's yellow box and
Shade's black speech balloon):
1. Vesper lands; Shade's hand (`scripts/effects/shade_hand.gd`: a gnarled skeletal hand with hooked claws,
   sinews and ink-skin rags round a golden engraved fountain pen, the forearm lost in a torrent of black ink
   with curling tendrils and torn pages, ink dripping off the claws) reaches in and `write_name()`s SHADE
   across the sky in dripping dry-brush ink (it stays, behind everything).
2. `WAVES`: the hand `draw_monster()`s one at a time (the nib traces the outline in ink, the sketch flares
   with light, `drawn` fires and the monster pops out: `materialize()`): paper spiders, ink bats, diving
   pens (`pen_diver.gd`: the Red Pen's art, hovers, shakes to aim, dives nib-first and sticks in the street),
   erasers (hp 6) and now and then one weakened Ink Blot (`blot_hp` 10; never two Blots at once). Only the
   Blot keeps a boss bar. Kills drop half a bottle at `drop_chance`; a cleared wave always drops a bottle.
3. The light: a pillar of light falls on the street, Vesper is healed to full, the hand plunges into it and
   steps out as Vesper's double (`scripts/enemies/shade_double.gd`, "SHADE", hp 30): Vesper's own
   player_visual.gd + sword inked black, blood-red scarf, burning red eyes (player_visual `eye_color`). It
   slashes in lunging combos (the blade glints first), dashes through him with afterimages, leaps and
   plunges (shockwaves both ways), sends ink waves along the street, sidesteps swings ("TOO SLOW."); below
   half health it rages (faster, 3-hit combos, double waves, dash back). Light doubles the damage it takes;
   it's only staggered when not attacking. All its hits cost a bottle.
4. The end: the double cracks apart with light, the name in the sky fades, the city brightens, captions,
   THE END card, then the main menu. Dying restarts the level; once the waves are beaten in a run
   (GameState.seen "finale:waves") a retry skips straight to the light.

## 2.5D framework
- Rooms are scenes whose root uses `scripts/world25/room.gd`; it builds environment, light,
  player, camera, HUD, music from a `Biome` resource (`data/biomes/*.tres`); `minimap.gd` is
  unhooked (the top-right corner holds the coin purse).
- `Gate` nodes (`scripts/world25/gate.gd`) seal until every monster in the room is dead, then
  load the target room. The Margins are a comic's dead gutters, so a way on is an old one
  (`scripts/world25/gutter_strip.gd`): a dark, cracked, ragged walkway between two broken ink
  kerbs, torn scraps hanging off it, ending in a broken portal (two cracked pillars snapped at
  different heights, a broken lintel, a seam of light in each); stone-post lanterns with flames
  either side. Sealed = a grey dashed pencil sketch (`drawn_ghost.gdshader`, one twin per section
  and per pillar) with cold lanterns; `open()` draws a line of light outwards
  (`gate_light.gdshader`), fills the path in, lights the lanterns and chimes. Walking out goes
  `World25.go(target, gate, true)`: gutter to gutter (`gutter_transition.gd`, never leaving the
  dark: the frozen frame tears down the middle and its halves part and grey; the view runs down
  the black slit between greyed, torn dead panels, dust drifting, a tiny ink Vesper ahead and the
  line of light behind him; then the slit clears onto the live new room and the two walls part;
  the tree is paused meanwhile, and the room camera's fade from black is skipped with
  `skip_fade()`). The ink wipe is kept for start_story and cutscenes. The Gutter only goes forward: each room's way in
  is `entry_only` (never opens; its sketch rubs itself out a moment after Vesper arrives). A room's `biome_b` + blend line morphs one biome
  into another inside it.
- Look: biomes (`data/biomes/`) are dark versions of the original palettes. Ground modes
  (ground.gdshader): 0 stone tiles (Inkwood), 1 wet flagstones, 2 cracked, 3 DIRT (the hub);
  `Biome.runes` / `rune_color` scatter glowing marks on any floor. Every symbol in the Gutter is
  one of the Writer's marks (`shaders/world25/writers_marks.gdshaderinc`, cryptic and scary: the
  watching eye with a slit pupil, an ink drop, a stitched mouth, claw marks, the Ember's flame,
  the death rune, a broken seal, a screaming face, a handprint, a ring of thorns), shared by
  ground.gdshader, sigil_mark (rune stones) and sigil_ring (ritual circles, `writers_seal()` in the
  middle: an eye in an inverted triangle of thorns). The Gutter is the dead zone, everything worn
  out and torn apart: islands are thick stacks of paper (cliffs = ground.gdshader `side_color`:
  ruled page edges, ink run over the lip), `island.gd` piles crumpled paper and torn scraps along
  closed edges, pine.gd = bare dead trees, trunk.gd = dead trunks with snapped branches, fence.gd =
  a broken wrought-iron fence, stairs.gd = stone, bridge.gd = an old gutter, scatter_props =
  rusty push pins / crumpled drafts / grimy rocks (old enum names), the DIRT floor has dropped
  staples, the COMIC backdrop's print is faded (comic_page.gdshader `faded`). Toon option `pages`
  rules page edges on side faces; Toon `moss` with `moss_color` is used for rust and grime.
  (`scripts/clearing/desk_lamp.gd` is unhooked; the lights are braziers again.) Darkness round Vesper: `darkness.gd` (+ darkness.gdshader) on the
  room's UI layer, strength `Biome.darkness`; pools of light at the Ember, lit lanterns, open
  gates, the lamp and anything in group "glow" (`glow_radius` property or meta); bright pixels
  shine through. room.gd fills the void per `backdrop_style`: SIGIL `_build_backdrop()` (a huge
  turning sigil far below, mist, rising embers, uplit heaps of crumpled drafts and ink statues) or COMIC
  `_build_comic_backdrop()` (level 1: a printed comic page of panels far below,
  `comic_page.gdshader`; torn-out panels and sound-effect words drifting round the floor, giant
  broken nibs, paper dust). No grass or farms, and no shop but Quire's stall in the hub; retired
  `biome_props.gd` kinds (CANOPY, GARDEN_PLOT, BARN, SCARECROW, CORAL, TUBE_PLANT, NEST) stay
  in the enum but are placed nowhere. The names are old: TOMBSTONE = a broken nib grave
  (`scripts/world25/broken_nib.gd`: a giant fountain-pen nib, greyed and rust-patched, curved, its
  point snapped off, breather hole and slit, ink bleeding from the break, an epitaph scratched in
  from `EPITAPHS`; in a dirt mound wrapped in thorny brambles, an ink puddle at its foot), STUMP =
  a split dead stump, PILLAR = a broken stone pillar, SKULL_PILE = a heap of crumpled, yellowed
  pages, RUNE_STONE = a cracked standing stone with a glowing mark, CRYSTAL = torn ruled pages,
  PENCIL_TOTEM = a giant broken nib driven in, PINS = rusty pins; CANDLES; RITUAL_CIRCLE uses
  sigil_ring.gdshader. Helper `Toon.candle()` (`Toon.skull()` / `Toon.bones()` are unused). The hub's altar.gd is Vesper's forgotten shrine in weathered
  grey stone: only the lower half of his statue stands (broken off at the chest, built from
  primitives, not vesper_3d), his head, hat, an arm and the snapped blade lie in the rubble; a worn
  "VESPER" plaque, old offerings (faded scarf, tipped ink pots, quills, yellowed pages, a few
  candles) and a dim ring of the Writer's marks. Quire's shop stall (`shop_stall.gd`, where Patch
  the dog used to sit; `patch_npc.gd` is unhooked): a carved navy counter
  (`shop_carving.gdshader`), Quire on it; E opens the shop. The hub's way on (CaveGate) stands
  at the back of the terrace, where the skill tree was (the archway by the stairs is gone).
- HUD (clearing_hud.gd, sized to the screen with set_anchors_and_offsets_preset): ink bottles
  (ink_bottles.gd, as in 2D), the Ember bar with its button (a mouse, right button lit), marked in
  thirds like 2D (one heal each) with an "F HEAL" tag under it only when clearing_player.gd
  `can_heal()` (no flask counter; F when it can't heal pops why: INK FULL / NOT ENOUGH EMBER) and, top right, the coin purse on a dark ink tag with
  the 2D HUD's spinning gold Lumen (coin.gd `draw_coin()`; Profile.lumens; pops when coins come in).
- The Writer's Haunting Lamp (`scripts/world25/haunt_lamp.gd`, built on `searchlight.gd`):
  room.gd spawns it in every room from the biome's `haunt` profile (`data/haunt/*.tres`,
  `haunt_profile.gd`), scaled by Settings difficulty and the room's `haunt_scale`; a room's
  `haunt_lamps` (-1 = the profile's count) overrides how many hunt (both set in the generator). States DORMANT/SEEK/MARK/STRIKE/LINGER/LOST; standing in its light fills the erase
  meter (a full meter = an ink drop); hide behind solid props. `room.haunt_hold()` stops strikes
  during transitions and boss intros. The hub's lamp only searches. The circle steers with
  inertia (`_steer`), is interpolated between ticks, keeps to the floor (`room.on_floor()`) and
  keeps apart from other lamps (`_separation`).
- Controls (clearing_player.gd): Shift dashes; holding attack charges the weapon's special
  (`charge_time`, see Progression below); B opens Quire's shop; hold right click (the "flash" action) to raise the
  Ember as in the 2D levels (`raised_radius`; it is then the Writer's kind of light, `monster_light`;
  drains `raise_drain`, comes back at `regen` after `regen_delay`, faster by lit lanterns, gutters
  out at 0 until `relight_at`); the old Flash is retired from the controls. `facing_dir` (8-way snap)
  is what swings, dashes and the facing chevron follow; the mouse position is ignored (buttons only). Aim assist (`aim_assist_angle`,
  `aim_assist_range`; always on, no longer in the Settings menu). World25 owns `Input.mouse_mode`: hidden while a room is
  in play (room.gd `in_gameplay()`), visible in menus; Settings "Cursor in game" keeps it shown.
- Spawn protection: `spawn_protection` (2 s) on clearing_player.gd, on arriving in a room and after
  dying: no damage, and lamps can't fill the erase meter (`is_protected()`); Vesper blinks.
- Autoload `World25` (`scripts/world25/world25.gd`): story state, cleared rooms, transitions
  (ink wipe, or down the gutter with `through_gutter`; `transitioning` blocks the pause / shop keys
  and keeps the cursor hidden), player health between rooms.
- Props are `@tool` scripts that build meshes under a "Generated" child (never saved); edit
  their exports in the inspector. Shared helpers: `scripts/clearing/toon.gd`.

## 2.5D story (main menu → "Begin in the Margins")
Zones (display names; code names stay): hub = The Spine, darkwood_* = The Inkwood, shallows_* =
The Drowned Margin, wastes_* = The Torn Wastes, arena = The Rubbing Room.
Hub `scenes/clearing/clearing.tscn` (hand-made, not generated) → its terrace's way on → four levels in
`scenes/world25/rooms/`, a row running west: 1 the hub (9 Scribbles, two up on the shrine terrace) + darkwood_1 (a few Half-Drawn and 2 Scribbles;
both with the COMIC backdrop) →
2 shallows_pen (Red Pen boss, `scripts/clearing/red_pen_3d.gd`: wet-ink circles dry in light; two
lamps) → 3 wastes_gap (a sketched bridge inked with right click; one slow lamp) → 4 arena (the Eraser, hard:
`eraser_3d.gd` charges twice in a row below `double_charge_below` health) → `cs_reveal` cutscene.
The other rooms there (darkwood_2/3/bridge, shallows_1/2/field, wastes_1/2) are retired: no gate
leads to them and the generator only rebuilds them with `OLD_ROOMS = True`.
Light: `scripts/world25/light.gd` (rules), Ember/Heal on `clearing_player.gd`, `searchlight.gd`
(`flash.gd` is unhooked); braziers with `lit = false` are lanterns. `drawn_bridge.gd` is a pencil
sketch that never forms on its own: pressing right click by it, or holding the raised Ember still next to it,
inks it, and while held, ink runs from Vesper's feet along the planks for good (`ink_reach`, `ink_speed`, `ink_cost` Ember fuel
a plank; an inked plank is a piece of old gutter, the rails leaning iron posts and a sagging bar);
`ink_only = false` brings back the old rule (solid only where light reaches).
Rooms are generated by `tools/rooms25/build_rooms.py` (deterministic; re-running overwrites hand
edits). Monsters stay dead in story rooms (room.gd sets `respawn_time = 0`).

## Progression: Quire's shop, weapons, outfits
Autoloads `Profile` (the coin purse `lumens`, owned / equipped items, weapon `upgrades`;
user://profile.cfg) and `Settings` (options; user://settings.cfg). The purse is filled by the Lumen
coins picked up in the 2D levels (player.gd `add_coins()`; GameState.coins counts the run) and the
Margins' coins (a new run, PLAY or a 2D chapter on the main menu, empties the purse: `Profile.new_run()`,
as GameState.reset() puts the levels' coins back; bought items stay; THE MARGINS chapter keeps it, and the
Long Drop's exit leads into the hub, so the 2D coins carry over): monsters drop small gold Lumens (the 2D coin:
gold disc, ring, embossed V) in a tight cluster (`scripts/world25/lumen.gd`
`Lumen.spill()` from monster_3d.gd / scribble.gd `_die()`, `lumens` per monster by difficulty:
Scribble / diver 1, Smudge 2, Crumple / Inkwell / Crossed-Out 3, Half-Drawn 4, Red Pen 30, Eraser
45; none when it fell into the void); they glint through the darkness and fly to Vesper within
`magnet` or after `home_after`. Big Lumens ("gems": the same coin, much bigger, own glow, 15 at once with
an "x15" pop, taken for the run via GameState.collected) sit off the usual path: 2D `scripts/world/big_coin.gd`
(extends coin.gd; the City's hover-deck stack above the door, the Long Drop's nook and side_b), 2.5D
`scripts/world25/big_lumen.gd` (aura + ray billboards, group "glow"; darkwood_1's far north-east corner,
wastes_gap's west island on the chasm lip). The skill tree is retired (`skill_tree.gd`
unhooked, Catalog.SKILLS unread, no Ink Points).
- Catalog (`scripts/core/catalog.gd`): weapons, armor, hats (hat + band colour), scarves (slot
  "cosmetic"), cloaks; `UPGRADES` (3 per weapon, in order: SHARPENED +1 damage, QUICK HAND special
  charges 40% faster, MASTERWORK the weapon's `master`). `retired` items (Compass Edge) aren't sold.
- Shop overlay `scripts/ui/shop.gd` ("Quire's Curios"; tabs WEAPONS / UPGRADES / HATS / SCARVES /
  CLOAKS / ARMOR, 2D-art preview): B anywhere ("shop" action; 2D: player.gd `Shop.open(tree)`;
  2.5D: room.gd `open_overlay("shop")`), the pause screen (pause_menu.gd, 2D and 2.5D: SHOP
  is its fifth button), Quire's stall. In 2D, B is read in player.gd `_unhandled_input()` (not
  polled, so the B that closes the shop can't reopen it). Quire's replies show under the sign (red
  with how many coins are missing). 2D HUD (hud.gd) shows "B SHOP" when something is affordable and,
  once 10 coins have been collected in a run (`SHOP_HINT_AT`, GameState.coins), a "PRESS B TO OPEN
  THE SHOP" caption under the counter.
- Weapons, both modes (2D player.gd, 2.5D clearing_player.gd; `_apply_loadout()` reads the effect
  stats, look and upgrade tier): every one has a hold-attack special (`special`): nib Nib-Sword =
  ink wave; quill Quill Rapier = QUILL VOLLEY (piercing quills); brush Brush Maul = INK SLAM (a ring);
  corkscrew Corkscrew Nib = PEN-DRILL (spin while held, drags monsters in and grinds them, bursts on
  release); prism Prism Saber = BLINDING SWEEP (rainbow arc, long stun, `dazzle()`s a Haunting Lamp
  to LOST; its normal hits stun); lantern Lantern Flail = LANTERN WHIRL
  (orbits while held, burns Ember, is light: 2D drawn_light / light, 2.5D monster_light).
  Tunables in each player's "Weapon Specials" export group. Effects: `scripts/effects/weapon_fx.gd`
  (2D) and `scripts/clearing/weapon_fx_3d.gd` (+ `prism_sweep`, `shock_ring` shaders). Weapon art:
  sword.gd `style` (2D), vesper_3d.gd `weapon_style` (3D). Monsters answer `stun_for(seconds)`
  (enemy_base.gd, crawler.gd, monster_3d.gd, scribble.gd).
- Outfit look keys: hat, band, scarf, mask, cloak, cloak_rim (player_visual.gd `hat_color` /
  `band_color`, vesper_3d.gd `apply_look()`).
Controls tutorial: `scripts/ui/tutorial.gd`, 2D only, and only where a level asks for it (player.gd
`tutorial_steps`, set by build_test_level.py: the City move/jump/attack/dash/inkwave, the Sketchbook
ember at its first sketch; other levels none). Main menu PLAY forgets the
"2d." steps so every new run teaches the controls again; 2.5D rooms start none, the keys are the
same, but Pause -> Controls still replays the 2.5D one on request). The 2D
ink wave (hold attack) is taught the first time a Scribble is near, in the City's plank section; steps
are remembered in Profile; Enter / controller Back skips; shows controller buttons when one is used;
PLAY replays them; in 2D the key shows low, under Vesper's feet (`center_y`), so it never covers
monsters or captions; the Settings menu no longer has Tutorials, Difficulty, Scribbles or Aim assist:
those stay at their defaults, settings.gd FIXED).

## Sound effects
Autoload `Sfx` (`scripts/audio/sfx.gd`) plays the team's SFX pack in `assets/sfx/` by name:
`Sfx.play("jump")`, optional dB offset and pitch. Numbered files (`sword_swing_1..4`,
`sword_hit_1..4`) are variants picked at random by their base name; every play gets a slight random
pitch; `TRIM` / `GAP` set per-sound levels and anti-spam gaps. Hooked into both players (jump, double
jump, dash, landings, swings, hits, hurt, death), enemies (`ink_enemy_hit`, or `boss_hit` for nodes in
group "boss": story_ui `set_boss()` and the 2D Eraser / Red Pen / Ink Blot join it; deaths and ink
globs `ink_splat`), pickups (coin, checkpoint, heart), gates (`gate_unlock`), transitions (`teleport`:
panel turns, World25.go, Shade's trap), boss intros and the menus (hover on row change, select,
open / close, pause). In `@tool` scripts call it through `get_node("/root/Sfx")` (no autoload in the editor).
`jump`, `dash`, `sword_swing_1..4` (a miss) and `sword_hit_1..4` are our own, synthesised by
`tools/sfx/build_sfx.py` to fit the ink-and-paper theme, minimal and dry (a paper flick, a pen stroke, a
nib swish, a nib click + ink thwack + splat); re-running overwrites them (`--out DIR` to listen first).

## Conventions
- Match surrounding code: tabs, `##` doc comments on scripts/exports, typed GDScript.
- Physics layers: 1 world, 2 player, 3 enemy (mask value 4), 4 hazard, 5 sketch / shadow ink
  (value 16; light rays ignore it, the player and monsters stand on it).
- Pause screen (`scripts/ui/pause_menu.gd`), the same in 2D and 2.5D, on the `pause` action (Esc /
  Start): player.gd `PauseMenu.open_2d()` in 2D, room.gd `open_overlay("pause")` in 2.5D. Only Resume,
  Retry (reload the scene), Settings (opens on top, comes back to it) and Main Menu; nothing else is
  drawn over it. mood.gd's Esc-to-menu now only fires in scenes that don't pause.
- Input actions come from `scripts/core/input_setup.gd` (move_*, up/down, jump, attack, dash).
  Same keys in both modes: A/D move (W/S too in 2.5D), Space jump, left click attack (hold = ink
  wave in 2D), right click the light (2D `ember`, 2.5D `flash`), Shift dash. Key names shown on
  screen (tutorial caps, captions, prompts, the 2.5D HUD's mouse icon) must match.

## Checking work
- Script errors: `godot --headless --path . --quit-after 60 res://<scene>.tscn`
- Gutter checks (need a display, e.g. `xvfb-run`): `godot --path . --rendering-driver opengl3 -s
  res://tests/gutter/test_phase1.gd` (also test_phase2, test_phase5, test_levels, test_shop, and
  test_beast for the 2D Scribbled Beast fight); exit code = failures. test_shop puts the player's Profile back when it's done.
- Screenshots: from a script in a temporary scene, call `RenderingServer.force_draw(false)` then
  `get_viewport().get_texture().get_image().save_png(...)`. `--write-movie` stops drawing after a few
  frames when the screen is locked, and hit-stop freezes look far too long in it.
- `.godot/imported/` is a generated cache: never commit it.
