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
      the same in 2D and the Gutter; SHOP is its fifth button), or press **B anywhere**. The
      game pauses while it's open.
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

15. **Coins in the Margins, shop fixes** (your next notes):
    - **The shop's "not enough coins" line** used to be drawn where the Vesper preview
      covered it. Quire's replies now show in a box under the sign. When you can't afford
      something, the reply is red and says how many more coins you need.
    - **Other bugs found and fixed:**
      - The shop was slightly see-through, so in the Margins the room's caption box and the
        coin counter showed behind its title and money. It's opaque now.
      - In 2D, pressing B to close the shop opened it again in the same frame. B is now
        read as a key event, so one press closes it.
      - The 2D "PRESS B" caption was hidden behind the Writer's narration box at the top. It
        now sits under the coin counter on the right.
      - The seventh hat row touched the details box. The rows are a little tighter now.
      - The Margins HUD had no size, so anything placed on its right edge was drawn off
        screen. It now fills the screen.
    - **Prices are about 20% lower:**
      - Weapons: 25 / 32 / 45 / 52 / 40.
      - Upgrades: 12 / 24 / 40.
      - Hats, scarves and cloaks: 8–16.
      - Armor: 28–48.
    - **"PRESS B TO OPEN THE SHOP"** now appears once you've collected 10 coins in the run,
      not just because the purse already held enough from before.
    - **Coins in the Margins:** monsters now drop coins when beaten, more for harder ones:
      - Scribble 1
      - Smudge 2
      - Crumple, Inkwell, Crossed-Out 3
      - Half-Drawn 4
      - Red Pen 30
      - Eraser 45

      They're small dark-silver coins that spill in a tight cluster, bounce, settle and
      twinkle so you can spot them in the dark. They fly to Vesper when he's near, or after a
      few seconds, and go into the same purse as the 2D coins.
    - **The map placeholder** in the top right of the Margins is gone. In its place is a coin
      counter like the 2D one, but on a dark ink tag with a spinning dark-silver coin.

16. **The Margins as the gutters of a comic** (your next notes):
    - **The way out of the hub** now stands at the back of the terrace, where the skill tree
      was. The archway portal by the stairs is gone; a pile of discarded drafts sits there
      instead.
    - **Ways on are gutters, not brick bridges.** Each one is a strip of cream paper between
      two thick ink panel borders, with printed comic panels lying either side and a dashed
      pencil ruling line down the middle. At its end two tall panels stand upright with a slit
      between them: that's the way through. Sealed, it's all a grey pencil sketch (each
      upright panel has its own sketch). The hub's bridge in is a gutter too.
    - **Moving between rooms is a trip down the gutter.** Walking out through an open gate:
      1. The screen freezes and shrinks into a panel on a comic page.
      2. The view drops into the slit beside it (the gutter between two columns of panels)
         and runs down it. A tiny ink Vesper runs ahead, drawing a line of light behind him.
         The next room loads meanwhile.
      3. It comes out beside the next panel, a pencil rough with the zone's name
         ("MEANWHILE, FURTHER DOWN THE GUTTER..."). Ink floods it, and the panel is a window
         onto the new room. It opens out to fill the screen.

      The game is paused while the page covers the screen, so nothing can hit Vesper, and his
      2 s of spawn protection start when the panel has opened. Starting the story and the
      cutscenes still use the ink wipe.
    - **Graves are discarded drafts.** A cracked, dried blob of ink, a snapped nib stuck in the
      ground with its tip lying beside it, crumpled balls of paper and crossed-out scraps.
      The other graveyard pieces changed the same way:
      - Skull heaps (on the floor and far out in the fog) are heaps of crumpled drafts and
        snapped pencils.
      - Tree stumps are pencil stubs; stone pillars are leaning stacks of books.
      - Rune stones are giant upside-down pen nibs with a glowing mark.
      - The Torn Wastes' crystals are torn, ruled pages stuck upright.
      - The bones in the hub's dirt are dropped staples.
    - **Torches are desk lamps,** after your photo: a round white base, a jointed wooden arm
      with brass bolts, a white dome shade tipped down, and a white cable looping down the
      arm. A lit lamp has a warm bulb and a soft cone of light. An unlit one is switched off
      until you hit it ("CLICK!"). The gates have a smaller pair leaning over the way, off
      until the room is cleared.
    - **The rest of the map is the Writer's desk:**
      - The islands are thick stacks of paper. The cliffs show ruled page edges, and ink has
        run over the lip and dripped down them.
      - The edge rubble is crumpled paper and torn scraps.
      - Pines are giant quills stuck nib-first.
      - The big dead trunks are giant pencils, sharpened end up.
      - Fences are rows of rulers with ink ticks.
      - The hub's stairs are a pile of books, with stacks of paper for walls.
      - Mushrooms, bushes and mossy rocks are push pins, crumpled drafts and worn erasers.
      - The sketched bridge in level 3 inks in as pieces of paper gutter, with pencil posts
        and a ruled ink line for rails.

17. **The dead zone** (your next notes, after the broken-nib-grave image):
    - **Graves are broken nibs,** like the image. Each is a giant fountain-pen nib, greyed
      and patched with rust, curved across like a real nib, its point snapped off in a
      jagged break. It has a breather hole and a slit, and ink bleeds from the break down
      its face. An epitaph is scratched in ("REST IN INK", "THE INK RUNS DRY",
      "UNFINISHED"...). It leans in a mound of dug earth wrapped in thorny brambles, with an
      ink puddle at its foot and now and then a torn page lying in the dirt.
    - **No more pencils, quills or the ink-blob drafts:**
      - The pine rings are bare dead trees.
      - The giant trunks are dead trunks with snapped branches.
      - Stumps are split dead stumps.
      - The pencil totems in levels 3 and 4, and the giant pencils over the comic page, are
        giant broken nibs.
    - **No books:** the stairs are stone again, and the book stacks are broken stone
      pillars.
    - **Ways on are broken portals:** a dark, cracked, ragged walkway between broken ink
      kerbs, with torn scraps hanging off it, ending in two cracked pillars snapped at
      different heights and a broken lintel. A faint seam of light runs in each pillar. The
      hub's bridge and level 3's inked bridge are the same dark walkway; that bridge has
      leaning iron posts with a sagging bar.
    - **Gutter to gutter:** the room change never leaves the dark now. The screen tears down
      the middle and its halves part and grey. You run down a black slit between greyed,
      faded, torn dead panels, with dust drifting and the line of light behind tiny Vesper.
      Then the slit clears onto the next room and the two walls part. There's no comic page
      or panel any more.
    - **The lamps are back** to the original stone braziers with flames, and the gates'
      stone-post lanterns are back too. (The desk lamp script is kept but unhooked.)
    - **Ground symbols are cryptic and scary.** The pen nib, quill, speech bubble, POW burst
      and question mark are gone. In their place are a stitched mouth, claw marks, the death
      rune, a broken seal, a screaming face, a handprint and a ring of thorns. The eye now has
      a slit pupil and lashes. The ritual rings' centre is an eye in an inverted triangle of
      thorns instead of a big nib.
    - **Worn and torn everywhere:**
      - The fence is a broken wrought-iron fence: spear-topped bars leaning, some bent or
        missing, the top rail snapped.
      - Pins are rusty.
      - Rocks are grimy and chipped.
      - The comic page under level 1 has faded to a yellowed grey.

18. **The capture: from the Gutter back into Shade's City** (your next note: the lights all
    round the Eraser's arena, one catches Vesper, Shade's hand pulls him up into the 2D comic,
    and Shade's City plays next). About 16 s; Enter or Esc skips it.
    - **Where:** beating the Eraser no longer cuts to `cs_reveal`. Once the Rubbing Room's
      clear captions are done, the room spawns `scenes/world25/light_capture.tscn`
      (room.gd `ending_on_clear`, set by the generator).
    - **Lights out (3D, `scripts/world25/light_capture.gd`):** black bars come in and the
      HUD goes. The Haunting Lamps sputter out and the two braziers are snuffed one by one.
      Only Vesper's Ember is left, and Shade's black balloon says "ENOUGH HIDING IN MY
      MARGINS."
    - **Lights on:** nine of the Writer's lamps slam down round the arena, KLAK, KLAK,
      faster and faster. Vesper turns to each one. They use the Haunting Lamp's own column and
      ring, which now take a colour.
    - **The hunt:** they sweep in. He runs, one swings at him and he dashes clear, then they
      ring him and turn. A brighter lamp slams down on him from straight above (KA-CHUNK!),
      the others pour into it, and the dark burns off: "FOUND YOU."
    - **Taken:** the beam lifts him off the floor, with paper, ink flakes and light rising
      round him. The camera drops low, looking up the beam, which warms to gold. Shade's
      hand from the final fight (the skeletal hand with the golden pen) comes down it, a flat
      drawing in the 3D room, and hooks him by the collar with the nib (SHNK!). "BACK TO MY
      PAGE." One yank and he's gone up the light, which flares to white.
    - **The climb (2D, `scripts/effects/page_climb.gd`):** out of the white, that last frame
      shrinks into a dead panel at the foot of a comic page. The hand tears up through its
      top border (RRRIP!) with Vesper hanging off the nib, flat and drawn again. It hauls him
      up the gutter between two columns of panels, the beam trailing after him. The panels
      are crops of the city painting: dead, crooked, torn and crossed out in red at the
      bottom, then pencil roughs, then inked, then the city in full colour. Each one comes a
      little more alive as he passes. "YOU DON'T GET TO DIE OFF THE PAGE."
    - **Shade's City:** the hand rips through the bottom of the big top panel (SKRRRIP!).
      That panel is a window onto the real level, which loaded in the background. It opens
      out to fill the screen while the hand holds him over the city: "NOW WATCH ME DELETE
      IT." The claws open and he drops. From there it's the level's own opening: the fall,
      THUD! and its narration.
    - **Under the hood:** the 3D player has cutscene hooks (`cutscene`, `cutscene_dir`,
      `cutscene_dash()`, `cutscene_hold` / `cutscene_point`; no damage meanwhile), and
      `shade_hand.gd` has a puppet mode. The low camera hides any tall prop, and any of the
      void's heaps and statues, that would block the shot.

19. **Music for Shade's part, a tense cut for its bosses, and their sounds** (your next note:
    "add this music to the shade part... keep the sound low... much more tense when the boss
    fight and add sound effects there"). The track is `audio/music/src/the_hunters.mp3`; the
    team's `tools/master_music.py` makes both versions from it.
    - **"hunters", in Shade's City, the Ink Cave and the finale:**
      - Kept low. It's mastered at -23 LUFS with no level boost, so it's the quietest track
        in the game.
      - The original is dark and bass-heavy, so its muddy low mids are eased (-2 dB round
        380 Hz) and a little presence is added (+2 dB round 2.8 kHz). That way it still
        reads quietly under the sound effects.
      - Its intro plays once. Then it loops 39 whole bars (7.0 to 89.1 s), with the
        breakdown leading back into the build. The loop point was found by matching the
        music either side of it (its chroma and spectrum), and lands on the beat.
    - **"hunt", in the boss fights:**
      - It's 32 bars from the track's driving middle (its peak, breakdown and climb back),
        made 8% faster (about 123 BPM) and brighter, and it starts right on the groove.
      - Tension is laid over it, on the track's own beat grid (114.04 BPM, found to within
        13 ms all through):
        - a heartbeat thump on every beat;
        - ticking sixteenths;
        - a trembling D / E-flat string cluster that swells over each 8-bar phrase;
        - a riser into a sub hit at every phrase.
      - I checked that every layer lands on the music's beat, and that the loops have no
        gap or click.
    - **When it switches:**
      - The Ink Blot's gate: the tense cut comes in as the walls rise, and the city's tune
        creeps back when it melts.
      - The two Blots in the cave: tense, then silence before the cave collapses.
      - The finale:
        - The Hunters plays while the hand writes SHADE.
        - The tense cut comes in from the first wave.
        - The light falls in silence.
        - The tense cut crashes back in when the double steps out.
        - Silence as it cracks apart, then The Hunters again, slowly, for the end.
    - **New sounds in those fights:**
      - The Ink Blot: roars as it wakes, enrages and takes its turn. Its footfalls are wet and
        heavy. It growls before each swipe, which then whooshes. It strains before a slam,
        which booms and sends its shockwaves rumbling. Its globs retch out, light sears it
        with a hiss, and it groans and slops as it melts.
      - The arenas: the ink walls rumble up and thud home, then sink with a rumble, and the
        tape rips off.
      - Shade's hand: the nib scratches while it draws its monsters; its name gets lower,
        heavier brush strokes.
      - Shade's double: its blade rings before a cut. Its cuts, dashes and dives whoosh, its
        plunge booms and rumbles, and its ink waves slosh. Light makes it hiss, it screams when
        it rages and it shatters when it dies.
      - The pillar of light whooshes and rumbles.
      - All of these are synthesised in code and built when the level loads, so nothing
        hitches mid-fight.

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
| Ways on (look) | `scripts/world25/gutter_strip.gd`: `STONE`, `INK`, `SCRAP`, `PILLAR` (the portal pillars' size) |
| Gutter to gutter | `scripts/world25/gutter_transition.gd`: `T_TEAR`, `T_RUN0`, `T_RUN`, `T_CLEAR`, `T_OPEN0`, `T_OPEN` (timings), `SLIT` (slit width), `TRAVEL` (screens run), `DEAD` (panel greys) |
| Nib graves | `scripts/world25/broken_nib.gd`: `STEEL`, `RUST`, size and break height in `build()`; `biome_props.gd` `EPITAPHS`, brambles in `_bramble()` |
| Ground symbols | `shaders/world25/writers_marks.gdshaderinc` (`writers_mark()`, `writers_seal()` for the ring centre) |
| Backdrop fade | `comic_page.gdshader` `faded` (0.7) |
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
| Margins coins | per monster `lumens` (monster_3d.gd export; set in each monster's `_ready()`); `scripts/world25/lumen.gd`: `MAX_COINS` (14), `magnet` (3), `home_after` (6 s), coin size in `_ready()`, spill speed in `spill()` |
| "PRESS B" caption | `scripts/ui/hud.gd` `SHOP_HINT_AT` (10 coins collected in the run) |
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
- **`tests/gutter/test_phase2.gd`: 20/20 checks** over the hub and the four levels.
  - No grass, farm or cosy props or round doors in any room, and no shop but Quire's in
    the hub.
  - Every room's beaten monsters drop exactly their coins' worth.
  - The HUD shows the purse, and there's no map in the corner.
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
- **`tests/gutter/test_levels.gd`: 51/51 checks** (rerun after round 17).
  - The gates chain hub → 1 → 2 → 3 → 4, and none leads to a retired room.
  - The hub's way on is at the back of the terrace and the archway is gone. Walking out
    through it starts the trip down the gutter with the game held still. It arrives in the
    Inkwood at its way in, the game runs again, the page is gone and spawn protection is on.
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

- **`tests/gutter/test_shade_music.gd` (new, round 19): 24/24 checks.**
  - Both tracks load, and The Hunters sits lower than every other track.
  - Shade's City plays it, looping from bar 4.
  - The Blot waking turns the music tense. Its roar and the walls' rumble and thud play,
    and so do its slam, globs and dying groan. The Hunters comes back when it melts.
  - The Ink Cave plays The Hunters, then tense for the two Blots, with a roar on MY TURN!
    The music goes silent when the last one melts, and the collapse rumbles.
  - The finale: the light falls in silence, and the double brings the tense cut back. Its
    plunge booms and its blade rings. The finale opens on The Hunters, the nib scratches as
    Shade writes, and the first wave is tense.
- Round 19 reruns: test_capture 21/21, test_phase1 35/35, test_phase2 27/27, test_phase5
  17/17, test_levels 67/67, test_shop 57/57, test_beast 43/43.
- **`tests/gutter/test_capture.gd` (new, round 18): 21/21 checks.** It clears the Rubbing
  Room and plays the real thing:
  - The ending starts once the captions are done. It takes the controls, holds off
    pause and the shop, and no damage gets through.
  - The Haunting Lamps blink out, the braziers go out, and all nine lamps land.
  - He runs and dashes, and the catching beam lands on him.
  - The light lifts him 2.4 units, the hand reaches his collar, and the yank takes him up.
  - Then the page runs over the paused room, Shade's City is swapped in, and its panel is a
    paused window with its Vesper hidden. World25 is reset.
  - The drop gives the level back (unpaused, Vesper shown), the page goes, the canvas
    transform is back to normal, and he lands on the street.
  - Enter skips the lot and lands in Shade's City the same way.
- Round 18 reruns, after merging `main`'s new music: test_phase1 35/35, test_phase2 27/27,
  test_phase5 17/17, test_levels 67/67, test_shop 57/57, test_beast 43/43.
- **`tests/gutter/test_shop.gd` (new): 57/57 checks.** It puts your saved progress back
  afterwards.
  - The purse:
    - Buying, equipping and the three upgrades in order, with their prices.
    - The retired Compass Edge isn't sold.
    - No upgrades for a weapon you don't own.
  - 2D, the shop:
    - A coin goes into the purse.
    - The pause screen lists SHOP (no skill tree). Picking it opens the shop on top, and
      closing it comes back to the pause screen.
    - Once 10 coins are collected in the run, "PRESS B" and the B SHOP tag show.
    - B opens the shop and pauses the level. Buying a hat in it puts the hat on Vesper at
      once.
    - Short of coins, Quire says how many more are needed.
    - B opens it again, and B closes it for good (it doesn't reopen).
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
  - Margins coins: a Half-Drawn spills 4 small dark-silver coins, clustered where it fell.
    They fly to Vesper and fill the purse, and the HUD counter shows it.

## Not verified

- **Hearing the new music and sounds:** this machine has no audio device. The Hunters'
  loops, the tense cut's layers and the new effects were checked by analysis instead:
  loudness, the loop seams, the beat alignment, the layers' level per band and
  spectrograms. Their final balance needs a listen. Levels are in `master_music.py`
  (`TENSION`, each track's `lufs` and `eq`), music.gd `TRIM`, and the dB in each sound call.

- **The capture at full speed and with sound:** it was checked frame by frame in
  screenshots, at a fixed 30 fps. This machine has no audio device, so the clanks, rips
  and whooshes (synthesised in code) haven't been heard.

- **The gutter-to-gutter trip at full speed:** it is timed to take about 2.5 s plus
  loading. Here it took about 12 s, because every frame is drawn on the CPU and the
  animation never skips frames. It was checked frame by frame in screenshots.
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
  2.5D (since cut to four buttons). I merged that in and kept it, adding SHOP as a fifth
  button. Earlier sections of this report still say Q.
