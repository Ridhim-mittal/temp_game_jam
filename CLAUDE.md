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
  The Crossed-Out (`scripts/enemies/crossed_out.gd`, its `paint()` shared by 2D and, via the puppet,
  `crossed_out_3d.gd`; after the team's sheet, kept slim and about Vesper's height): a stooped ghoul in a
  tattered brown coat and a battered top hat, white X eyes (red on a windup) over a grin of jagged teeth,
  a black clawed hand on its shield, an X of two splintered nailed planks with a red-ink stain; light
  chars the planks, edges glowing, until they crumble (`_shield`). Strokes boil at 12 fps, one InkBatch.

## 2D story start (main menu PLAY)
`cs_book` (scripts/cutscenes/cs_book.gd: ~28 s animated opening. It sounds like grief and anger: the
"margins" track (the game's tune, minor and slow: the menu's) plays all through it, the City's own
LevelMusic bringing "city" in when the level loads; under it rain on the window, the lamp's hum and a
pen scratching that stops (`_update_room()`), thunder after each lightning flash (`_lightning()`), and
while the Writer changes the book a growl, a heartbeat that hardens and a bell tolled for the dead
(`_cues()`). The Writer's desk, a comic book on it, and things that say what he has lost: a big framed
photo of two brothers (one in Vesper's hat and red scarf, "brothers." under it, a black ribbon over the
corner: the ending's answer, never explained here), a candle burning by it, the brother's red scarf, the
ending he tore in two ("AND VESPER CAME HOME.", a red NO across it), drafts crushed into balls, a
snapped pencil, a pile of earlier issues, a pocket watch, the window's cold light with rain running
down it. The Writer's hand (shade_hand.gd as a puppet, `drips`
and `aura` off; he is not named, that stays for the Long Drop) taps the cover, lifts its corner and
the light throws it back; page one says "I JUST HAD THE CRAZIEST ADVENTURE..." (Vesper); the hand
comes back with its pen (`_build_jobs()`: timed ink strokes on a page; the nib follows the line and
hops, lifted, between strokes, the wrist trailing so the hand turns about its pen, its shadow parting
from it as it lifts: `_update_writer()`, `_pen_state()`; strokes are pressed thin-thick-thin (`NIB`)
and shine wet behind the nib), reads along the caption, blots out CRAZIEST and writes LAST over it,
then sketches the Scribbled Beast on the inside of the cover (its lines boil at 12 fps once its red
eyes are in) and writes THE END beside it, stabbing the full stop in; ink flung off the pen when the
light throws it back, and out of the book as its cover bursts open, stays on the desk (`_splats`).
Page one's four panels have a far layer each (sliding towers, pencilled pillars real in the Ember's
light and a gleam along the spikes, Scribble eyes in the Gutter's dark that shut at the lamp, a
pencilled city being rubbed out) and the Eraser breaks out over its border (`_paint_breakout()`);
page two's lower panels are pencil roughs of the Sketchbook, the Long Drop and the Beast. It flicks
the page over, the camera holds a beat on the pencil city (its stick Vesper blinks) and dives into the
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

## The story and its captions
Shade IS the Writer (one person). Vesper lives in an ordinary comic of cities and monsters (the City,
the Sketchbook; the opening and their narration stay as they were). He wanders into a panel that
was drawn for his death (the Long Drop: "WAIT... THIS IS A WEIRD PANEL. I SHOULD EXPLORE."); Shade
sends the Scribbled Beast to finish the page, Vesper wins, Shade names himself ("I AM SHADE. YOUR
WRITER. PAGE FORTY-ONE...") and sends his Eraser; Vesper falls into the margins. In the Margins
(2.5D) Shade hunts him with his lamp ("My lamp will find him"), Vesper doesn't know where he is;
at the Rubbing Room's end the light finds him ("FOUND YOU." / "The light... it's pulling me up!";
the pull back into 2D is a cutscene a teammate is drawing). Shade's City: everything corrupted,
Shade: "I'M ENDING YOU... THIS ONE IS PERSONAL." The Ink Cave, then the finale: Shade draws the
monsters live, then fights as Vesper's double; after it Vesper asks "WHY, SHADE? WHY DID YOU WANT ME
DEAD?" (the answer, his brother who died fighting a city of monsters, is the ending cutscene to come).
Every story line is a caption panel (`scripts/ui/caption_style.gd`): the comic's narration = the yellow
box, Vesper = yellow with a VESPER tab, Shade = blood red with a SHADE tab. 2D: narration.gd `speaker`
("narrator" / "vesper" / "shade"; the generators' `narration(text, x, speaker)`); the Margins:
room captions, a leading "~" = Shade, "^" = Vesper (room.gd), story_ui.gd "shaky" / "shade" = Shade's
red panel (the lamps' and the Red Pen's lines too); beast_arena.gd, eraser_chase.gd, margins_fall.gd,
shade_trap.gd and shade_finale.gd (`_say(text, "writer" | "shade" | "vesper")`) draw the same panels.

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
Cut down for the 20-minute run (about 3 minutes + the boss): hall 2 (the level starts there; two
Crawlers and the City's dash pit made harder: 450 px, needs a double jump plus a dash; the nook to the
left holds a big Lumen; no heart by the spawn) -> shaft 2 -> the Shadow Gallery (hit lantern B, ride the shadow-ink
ramp, light the far lantern A with an ink wave, cross the blue sketch, second ramp to the shelf) -> a
short shaft of ledges down through the shelf -> the Pendulum's cavern (a blue sketch bridge under a
swinging lantern; no spikes, since spikes can be pogoed across; falling into the sump isn't deadly,
ledges climb out, and the second big Lumen lies down there) -> its far bank walks straight into the boss
arena. Both long, unsteerable drops (shaft 2 into the gallery, the shelf shaft into the cavern) are
short cutscenes (`scripts/effects/fall_cutscene.gd`, an Area2D under each shaft's last ledge): the HUD
(the level's UI layer) fades out, letterbox bars slide in, the camera zooms in (`zoom_in`), player.gd
`cutscene` takes the controls and the hard landing kneels without fall damage; `hold_after_land` later
it all comes back. Checkpoints: the gallery, the cavern's near bank, the far bank before the boss, the start of the Eraser's chase.
Retired (no longer generated): hall 1 and its shaft, the plank tower, the two side rooms, the pit and the
bottom room with the Sketchbook's Blue Gap / lantern bridge replays.
It ends in the boss arena (room "arena", east of the bottom room): THE SCRIBBLED BEAST
(`scripts/enemies/scribbled_beast.gd`, run by `scripts/world/beast_arena.gd` on the arena floor at the
gutter it comes out of). A hulking two-headed scribble (heads with staring white eyes and toothed maws,
a third eye in its chest, long clawed arms, spindly legs), all frantic pen + pencil strokes redrawn at
12 fps (InkBatch, one draw call), pale rim from the enemy outline; it carries a SHIELD torn out of the
gutter (black, the white panel lines down both edges, crossed out) that always faces what it fears
most: a lit arena lantern, else the raised Ember, else Vesper; it covers a side, plainly (`_covers()`:
facing left / right it blocks every hit from that side, facing up everything above its chest), so
light a lantern (`ArenaLanternW/E`, short posts, the only lanterns it watches: `arena_lanterns`) and
hit its open side, or dash through it. A lit lantern pins it for `snuff_delay` (1.6 s: it stops, a
charge included, and cowers), then it lobs an ink glob (`beast_glob.gd`, slash it to keep the light).
Touching it only hurts mid-charge or mid-leap (`_update_harm()`). CLAW up close (`claw_damage` 2, a
bottle), RUSH across the arena (jump it: it hits the wall and is DAZED, shield down), STAGGER every
`stagger_every` (4) damage; hp 16; phase two (half hp): faster, red eyes, LEAP slams with floor
shockwaves (`beast_shockwave.gd`) and Scribbles called out of the gutter (`crack_gutter()` on the arena,
group "beast_spawn"). Dying: light breaks out through its cracking shield, it unravels into strokes
and paper, `defeated`.
The Margins are the comic's gutters, the gaps between the panels, so the Beast comes out of the gap
between the page's columns, not the floor. Intro once a run (~15 s, Enter skips): letterbox, the page
rumbles, an ink line splits the panel top to bottom, the halves part on the gutter (dark, two inked
panel borders, dead panels drifting in it); deep in it the Beast comes up out of the depth, small and
dark (`_emerge()`: the outline's scale and modulate), shield over its head deflecting the lanterns'
light, snuffing both; its claws crack the borders and it tears out into Vesper's panel, the gap slams
shut ("WHAM!"); three eyes open, ROAR, title card "THE SCRIBBLED BEAST", the Writer's captions: "That
wasn't supposed to get out." / "...Fine. Let it finish the page. This is where your story ends,
Vesper."; after a death a ~3 s short intro (GameState.seen "beast_intro"). A wall of scribble seals
the way back and the arena's right-hand panel border (`east_x`) is shut; boss bar; a one-time "LIGHT
IT!" tag after 2 blocked hits.
Ending (~25 s, Enter skips the talk but not the Eraser): the camera frames its death; Shade, the Writer,
breaks out of the narration in his black balloon (red letters, "- SHADE"; furious lines shake, pulse
red and get pen scratches across the panel) and Vesper answers in his own white balloon (`DIALOGUE`):
"NO." / "Page forty-one: 'The Beast tears Vesper apart. The End.' I wrote it. In ink." / "...Guess I
skipped that page." / "You were supposed to die here, Vesper. That was your ending." / "A hero who won't
stay dead ruins the whole book." / "Fine. If ink can't finish you..." / (a shadow falls; SHADE'S ERASER
slams down) "...I'll rub you out myself."; the right-hand border rips open: RUN!
THE ERASER'S CHASE (`scripts/world/eraser_chase.gd`, room "run" east of the arena, two 40 px hops and a
dip): SHADE'S ERASER (`scripts/enemies/shade_eraser.gd`, from the team's sheet: a pink rubber block with a
chipped crown, a torn tan sleeve with a blue "SHADE'S ERASER" band and a skull face, angry white eyes and
a jagged maw, thin scribbled clawed arms, thick outlines, a 24 fps vibration; `rubbing` scrubs it side to
side throwing pink shavings and dust; touching it costs half a bottle) follows, rubber-banded (catches
up when far, eases off right behind him), and everything behind it is rubbed back to blank paper.
Every Eraser in the game is drawn by `scripts/enemies/eraser_art.gd` (from the team's model sheet: the block three-
quarters on, the crown's top face and two big bites, the blue band on the left side face, a skull filling the
sleeve, pen hatching and doubled sketchy outlines, long arms with five spidery claws; draw in sheet
units W 210 x H 330, `EraserArt.draw(ci, xf, pose)` or `draw_into(batch, ...)` inside another batch): front
view (idle, `rubbing`, `roar`, `windup` (leans back, arms up, eyes lit), `tired` (dizzy spiral eyes, tongue out,
stars and a weak-spot marker), `rage` (red eyes)) and the sheet's side / attack view (`side`, the charge: crown
first, speed streaks and dust). Used by the chase's SHADE'S ERASER, the 2D mini-boss in Shade's waves (eraser.gd,
body 62 x 92, the art 100 px tall), the Rubbing Room's boss in the Gutter (eraser_3d.gd: the 2D art on the
puppet billboard, red-eyed when FURIOUS), Shade's hand's sketch of it, the opening book's THE ERASER panel and
the fall into the Margins. The
corridor ends where its panel ends: the gutter (a pit, `end_x`); there the controls go (player.gd
`cutscene_run` keeps him running), Shade: "THE END, VESPER.", the Eraser lunges, Vesper leaps into the gap
and falls, and `scripts/effects/margins_fall.gd` plays (~12 s, Enter skips): the frozen moment becomes a
panel on a comic page, the camera dives into the white gutter between its columns, he tumbles down it
past the panels of his story (in colour, then greyed, crossed out in red, torn, pencil, gone) as the
gutter darkens to ink, Eraser crumbs raining, Shade: "LET THE MARGINS HAVE YOU."; in the dark Scribble
eyes open either side, Shade stamps THE END below him, his Ember flares (the eyes flinch shut, "END"
burns away), "NOT YET."; the floor of the Margins rushes up, an ink splash, "THE MARGINS" title, then
World25.fall_in_from_panel() drops him into the 2.5D hub (the purse comes along). Dying in the chase
restarts it from the corridor's checkpoint (GameState.seen "beast_dead": the arena stays open).
The 2D player's
`cutscene` flag takes the controls (no input, no damage, the Ember can't rise; `cutscene_run` makes him
run on by himself). Shared:
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
Reached from the Rubbing Room through THE CAPTURE (see 2.5D story), or Chapters -> SHADE'S CITY. Generated by `tools/level2d/build_shades_city.py` (re-running overwrites hand
edits). Backdrop (`city_painting.gd`, also the finale's), layered like the City's comic_background so
it has depth: the team's concept painting (`assets/backgrounds/shades_city.webp`) far back, drifting
slowly (`drift`, mirrored on repeat so no seam shows), a navy-violet haze over its lower half (its own
street junk must not read as walkable), three comic_skyline.gd layers in its pinks / blues / violets
(scroll 0.2 / 0.38 / 0.62), drifting motes and comic_foreground.gd silhouettes in front (1.35). Being real
parallax planes, the pencil sketch outside the comic frame's live area is a sketch of the same deep city.
The end walls are city_block.gd in Shade's pink (generator `wall()`), and the live area starts at their
outer edge. The player's Camera2D `framing_offset` (0, -226) puts the street (`street_ground.gd`) in the
bottom ~15%. Platforms: `paper_stack.gd` (CMYK bales) and
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
   No drop (kills, waves, an Ink Blot's big heart) is made while Vesper's ink is full (health_heart.gd
   `player_full()`), and a seeking heart that reaches him full fades away instead of sitting on him.
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
`eraser_3d.gd` charges twice in a row below `double_charge_below` health) → THE CAPTURE (below) →
Shade's City (2D). (`cs_reveal` is no longer played; the arena's `cutscene_on_clear` is empty.)
THE CAPTURE (~16 s, Enter / Esc skips; room.gd `ending_on_clear` spawns `scenes/world25/light_capture.tscn`
in the room once its clear captions are done). Part 1, `scripts/world25/light_capture.gd`, in the 3D arena:
bars in, HUD out, the Haunting Lamps blink out and the braziers are snuffed; nine of the Writer's lamps
(the Haunting Lamp's column + circle shaders, which now take a `tint`) slam down round the rim (KLAK!), hunt
him (he runs, one swings at him, he dashes: clearing_player.gd `cutscene`, `cutscene_dir`, `cutscene_dash()`),
ring him, and a brighter lamp slams down on him (KA-CHUNK!), the others pouring into it; the light lifts
him (`cutscene_hold` / `cutscene_point`: no physics, posed in the air), warms to gold, and Shade's hand
(shade_hand.gd in puppet mode: `puppet`, `puppet_nib`, `puppet_flex`, `puppet_turn`, drawn into a
SubViewport on a camera-facing quad, `capture_hand.gdshader`) comes down the beam and hooks his collar
with its nib (SHNK!), then yanks him out of frame. Shade speaks in his black balloon ("ENOUGH HIDING IN MY
MARGINS." / "FOUND YOU." / "BACK TO MY PAGE."). The low camera hides tall props and the void's statues in
its way (`_clear_foreground()`). Part 2, `scripts/effects/page_climb.gd` (a layer on the root, like
panel_turn.gd): the last frame shrinks into a dead panel at the foot of a comic page; the hand tears up
out of it with 2D Vesper and hauls him up the gutter between two columns of panels (crops of the city
painting, `shaders/page_panel.gdshader`: dead and crossed out at the bottom, then pencil, ink, colour on the
way up); it rips through the bottom border of the top panel, a window onto the live Shade's City (loaded
in the background from the start of part 1, swapped in behind the page, paused, its Vesper hidden),
which opens out to fill the screen; "NOW WATCH ME DELETE IT." and the hand drops him: the level's own fall,
THUD and narration take over. World25 is reset there (the Gutter's run is over). test_capture checks it all.
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

## Music
Autoload `Music` (`scripts/audio/music.gd`): `Music.play(track, fade)` cross-fades (nothing if it's
already on), `Music.stop(fade)`; a level picks its track with a `LevelMusic` node (`level_music.gd`).
Old synth tracks (`tools/make_music.py`): lit, margins (main menu, cs_reveal), boss, ending. The 2D story uses the team's licensed
tracks (sources in `audio/music/src/`, kept out of Godot by a .gdignore; `tools/master_music.py` cuts each
into an intro + seamless loop by matching the music, blends the seam, cuts the clips' fade-outs, eases the
battle's hot top end and masters them quiet; `LOOP_FROM` in music.gd = the loop points it prints, `TRIM` the
levels): "city" = Cool Down (THE CITY + the Sketchbook; cs_book starts it as the book opens), "deep" =
A Flicker in the Deep (THE LONG DROP: the quiet first pass is the intro, the full one loops through its own
fade, quiet into quiet), "beast" = Incisive Battle (the Beast's fight and the Eraser's chase). The Margins (2.5D, the biomes'
`music`): "repose" = Repose (the Spine hub, the Torn Wastes, the arena after the Eraser), "silk" = the
Silksong track (the Inkwood, the Drowned Margin; it fades in and out, so it loops whole, through that breath),
and boss rooms play room.gd `boss_music` ("dread": Incisive Battle two semitones down at the same tempo, top
rolled off, far back in a dark cavern reverb: tense but dark) while the boss lives; on clearing the room's
own tune creeps back over 3 s. test_phase2 checks each room's track. beast_arena.gd: the deep tune fades
as the intro starts (only the rumble), "beast" crashes in on the ROAR (or when the fight starts / the
short intro), silence for the death and Shade's lines, "beast" again on RUN! (eraser_chase.gd `begin()`),
fading out as he runs out of page; the 2.5D hub's biome takes over after the fall.
Shade's part (Shade's City, the Ink Cave, the finale; their generators set `LevelMusic` `track`):
"hunters" = The Hunters (`the_hunters.mp3`, 114 BPM, D minor), kept low (-23 LUFS, TRIM 0), its muddy low
mids eased and a little presence added so it reads under the effects; the intro plays once, then it loops 39
whole bars (7.006..89.1 s), its breakdown leading back into the build. Its boss fights play "hunt": 32 bars
from the driving middle (peak, breakdown, climb back), 8% faster, brighter, starting straight on the groove,
with tension laid over it on the track's own beat grid (master_music.py `tension()` / `TENSION`): a heartbeat
thump on every beat, ticking sixteenths, a trembling D / E-flat string cluster swelling over each 8-bar phrase,
and a noise riser into a sub hit at every phrase. gate_arena.gd: "hunt" as the walls rise and the Blot wakes,
"hunters" back (3 s) when it melts; cave_arena.gd: "hunt" for the two Blots, silence when the last melts (the
collapse); shade_finale.gd: "hunters" while the hand writes, "hunt" from the first wave, silence as the light
falls, "hunt" again (from the top) when the double steps out, silence as it cracks apart, then "hunters"
slowly for the end. The fights' sounds (SfxSynth, built at level load so nothing hitches): the Blot roars
waking / enraging / on MY TURN!, wet footfalls, a growl before each swipe then a whoosh, a strain before the
slam then a boom and the shockwaves' rumble, retching globs, a hiss when light sears it, a dying groan and
slops as it melts; the arenas' walls rumble up and thud home, sink with a rumble, the tape rips off; Shade's
hand scratches with its nib while it draws (brush strokes lower for its name); the double's blade rings
before a cut, whooshes on cuts / dashes / dives, booms and rumbles on its plunge, sloshes its ink waves,
hisses in light, screams when it rages and shatters when it dies; the light's pillar whooshes and rumbles.
test_shade_music checks the tracks, the switches and the sounds.

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
`jump`, `double_jump`, `dash`, `sword_swing_1..4` (a miss) and `sword_hit_1..4` are our own, synthesised by
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
  res://tests/gutter/test_phase1.gd` (also test_phase2, test_phase5, test_levels, test_shop,
  test_beast for the end of the Long Drop: the Scribbled Beast, the Eraser's chase and the fall
  into the Margins, test_shade_music for Shade's part's music and boss sounds, and test_capture
  for the end of the Gutter: the capture and the climb into
  Shade's City); exit code = failures. test_shop puts the player's Profile back when it's done.
- Screenshots: from a script in a temporary scene, call `RenderingServer.force_draw(false)` then
  `get_viewport().get_texture().get_image().save_png(...)`. `--write-movie` stops drawing after a few
  frames when the screen is locked, and hit-stop freezes look far too long in it.
- `.godot/imported/` is a generated cache: never commit it.
