#!/usr/bin/env python3
"""Builds the 2.5D story rooms: python3 tools/rooms25/build_rooms.py
The Gutter is four levels, west of the hub (The Spine, hand-made):
  1 The Inkwood       darkwood_1    a few Half-Drawn ghosts and a pack of Scribbles
                                    (after the hub's Scribbles)
  2 The Red Pen       shallows_pen  the boss, with two of the Writer's lamps
  3 The Torn Page     wastes_gap    ink the sketched bridge across with right click
  4 The Rubbing Room  arena         the Eraser, hard
Each block describes one room: size, gates (and where they lead), monsters,
props, the Writer's captions and how hard the Writer's lamp hunts there
(r.haunt_scale, 1 = the biome's HauntProfile as is; r.haunt_lamps, -1 = the
profile's lamp count). Rooms are deterministic (seeded), so re-running gives
the same layout. Re-running overwrites hand edits.
Every room's way in is entry_only: the Gutter only goes forward.
The older rooms at the bottom are retired: no gate leads to them, and they
are only rebuilt with OLD_ROOMS = True (their scenes stay on disk)."""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from rooms import Room, forest_ring, KIND, rect_polygon

R = "res://scenes/world25/rooms/"
HUB = "res://scenes/clearing/clearing.tscn"
# minimap cells of the four levels: a row running west from the hub at (0, 0)
CELLS = [(-1, 0), (-2, 0), (-3, 0), (-4, 0)]


def the_dead(r, stones=1, candles=1, skulls=1):
    """Cryptic rune stones, red candles and heaps of skulls: some in every room."""
    r.scatter("RUNE_STONE", stones, clearance=1.6, solid=True)
    r.scatter("CANDLES", candles, count=4, radius=0.5)
    r.scatter("SKULL_PILE", skulls, count=8, radius=0.8, solid=True)


def darkwood_dressing(r, graves=3, stumps=2, rocks=2, pools=1):
    r.clear_path_to_gates()
    the_dead(r)
    r.scatter("TOMBSTONE", graves, solid=True)
    r.scatter("STUMP", stumps, solid=True)
    r.scatter("INK_POOL", pools, radius=1.4)
    for i in range(rocks):
        spot = r.free_spot()
        if spot:
            r.prop("scatter", spot[0], spot[1], name=f"Rocks{i + 1}", kind=2, count=3, radius=0.9, size=1.2,
                   color="Color(0.6, 0.58, 0.56, 1)", seed=r.rng.randint(1, 99), solid=True)


def shallows_dressing(r, pillars=2, pools=2, mounds=2):
    r.clear_path_to_gates()
    the_dead(r, skulls=0)
    r.scatter("PILLAR", pillars, solid=True)
    r.scatter("INK_POOL", pools, radius=1.5)
    r.scatter("PAPER_MOUND", mounds, count=4, radius=1.1, solid=True)


def shallows_ring(r):
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        x, z = math.cos(a) * (r.hw + 4), math.sin(a) * (r.hd + 4)
        if any(math.dist((x, z), r.gate_pos(s)) < 5.5 for s in r.gates):
            continue
        r.nodes.append(("Deep", f"Deep{i + 1}", "bprops", (x, -6, z), 0,
                        {"kind": KIND["PILLAR"], "size": 2.4, "seed": r.rng.randint(1, 99)}))
    for i, sx in enumerate((-1, 1)):
        r.nodes.append(("Deep", f"RuinPillar{i + 1}", "bprops", (sx * (r.hw + 3), -6, -r.hd - 1.5), 0,
                        {"kind": KIND["PILLAR"], "size": 2.4, "seed": 40 + i}))
    r.nodes.append(("Deep", "Eyes1", "eyes", (r.rng.uniform(-r.hw, r.hw), -4, r.hd + 3), 0, {"color": "Color(0.4, 1, 0.85, 1)"}))


SPIRIT = dict(flame_color="Color(0.25, 0.55, 1, 1)", core_color="Color(0.75, 0.92, 1, 1)")


def wastes_dressing(r, crystals=3, mounds=3, pins=2, totems=2, pots=2):
    r.clear_path_to_gates()
    the_dead(r)
    r.scatter("CRYSTAL", crystals, count=4, radius=1.2, solid=True)
    r.scatter("PAPER_MOUND", mounds, count=5, radius=1.3, solid=True)
    r.scatter("PINS", pins, count=6, radius=1.2)
    r.scatter("PENCIL_TOTEM", totems, solid=True)
    r.scatter("INK_POT", pots, count=3, radius=0.9, solid=True)


def wastes_ring(r):
    for i in range(7):
        a = i / 7 * math.tau + 0.2
        x, z = math.cos(a) * (r.hw + 4.5), math.sin(a) * (r.hd + 4.5)
        if any(math.dist((x, z), r.gate_pos(s)) < 5.5 for s in r.gates):
            continue
        k = ["CRYSTAL", "PAPER_MOUND", "PENCIL_TOTEM"][i % 3]
        y = {"CRYSTAL": -5.0, "PAPER_MOUND": -3.5, "PENCIL_TOTEM": -6.0}[k]
        r.nodes.append(("Deep", f"Deep{i + 1}", "bprops", (x, y, z), 0,
                        {"kind": KIND[k], "size": 2.6, "count": 6, "radius": 1.6, "seed": r.rng.randint(1, 99)}))
    r.nodes.append(("Deep", "Eyes1", "eyes", (r.rng.uniform(-r.hw, r.hw), -4, r.hd + 3), 0, {"color": "Color(1, 0.6, 0.85, 1)"}))


EMBER = dict(flame_color="Color(1, 0.3, 0.45, 1)", core_color="Color(1, 0.8, 0.85, 1)")


# ------------------------------------------------------------ Boss arena (round)
class Arena(Room):
    def polygon(self):
        pts = []
        n = 22
        gap = 1.8 / self.hw  # half-angle of the gate gap
        for i in range(n):
            a = -math.pi / 2 + i / n * math.tau
            if abs(math.atan2(math.sin(a), math.cos(a))) < gap * 1.3:
                continue
            j = self.rng.uniform(-0.35, 0.35)
            pts.append((math.cos(a) * (self.hw + j), math.sin(a) * (self.hd + j)))
        # gate on the east (+x): two points straight at the gap
        gx = self.hw
        east = [(gx, -1.8), (gx, 1.8)]
        # insert where angles cross 0 (east)
        k = next(i for i, p in enumerate(pts) if p[1] > 0 and p[0] > 0)
        pts[k:k] = east
        return pts, [k]


# ======================================================== rooms over a chasm

class ChasmRoom(Room):
    """Two islands either side of a chasm (|x| < gap), joined by a drawn
    bridge along z = 0. Gates sit on the outer east and west edges."""
    gap = 4.0

    def polygon(self):
        east_gaps = {"west": (self.gap, 0)}
        west_gaps = {"east": (-self.gap, 0)}
        if "east" in self.gates:
            east_gaps["east"] = self.gate_pos("east")
        if "west" in self.gates:
            west_gaps["west"] = self.gate_pos("west")
        east, east_open = rect_polygon(self.rng, self.gap, self.hw, -self.hd, self.hd, east_gaps)
        west, west_open = rect_polygon(self.rng, -self.hw, -self.gap, -self.hd, self.hd, west_gaps)
        self.extra_islands = [("WestIsland", west, west_open)]
        return east, east_open

    def inside(self, x, z, margin=1.6):
        return super().inside(x, z, margin) and abs(x) > self.gap + margin

    def add_bridge(self):
        self.nodes.append(("Bridge", "DrawnBridge", "bridge", (self.gap, 0, 0), 90, {"length": self.gap * 2, "width": 3.0}))
        self.clear_zones.append((self.gap + 1.5, 0, 2.0))
        self.clear_zones.append((-self.gap - 1.5, 0, 2.0))


def chasm_depths(r, kind_list, y=-7):
    """Things rising out of the chasm below the bridge, for depth."""
    for i, (k, x, z) in enumerate(kind_list):
        r.nodes.append(("Deep", f"Chasm{i + 1}", k[0], (x, y, z), 0, k[1]))


# ======================================================== the four levels

# ------------------------------------------------------------ Level 1: The Inkwood
# Level 1 is the hub (scenes/clearing/clearing.tscn, a few Scribbles) and
# this room: where Vesper lands after slipping out from under the eraser.
# Its monsters are the Half-Drawn (half_drawn_3d.gd): scribbles the
# Writer never finished, barely on the page. Out of the Ember's light they
# are faint ghosts a sword goes through; hold right click and inside its light they
# ink in, solid enough to cut. A few of them, quick with a nib-blade, quick
# to fall, with a slow lamp. A pack of Scribbles (scribble.gd: they circle
# and claw, and shy from light) keeps the Ember busy: raise it on one
# that's winding up and it curls up. Half-Drawn first: tests read child 0. The page round it is a comic book (room.gd
# backdrop_style).
r = Room("darkwood_1", "darkwood", CELLS[0], 14, 9.5, seed=11)
r.gate("east", HUB, "cave", entry_only=True)  # the Gutter only goes forward
r.gate("west", R + "shallows_pen.tscn", "east", offset=0)
r.enemy("half_drawn", 4, -4)
r.enemy("half_drawn", 3, 4.5)
r.enemy("half_drawn", -4, -1)
r.enemy("half_drawn", -8, 4)
r.enemy("scribble", 8, -3)
r.enemy("scribble", 9, 1)
r.enemy("scribble", -1, 6)
r.enemy("scribble", -10, 0.5)
darkwood_dressing(r)
r.prop("brazier", -9.5, -6, name="Lantern1", flame_color="Color(1, 0.25, 0.15, 1)")
r.prop("brazier", 9.5, 6, name="Lantern2", flame_color="Color(1, 0.25, 0.15, 1)")
forest_ring(r)
r.haunt_scale = 0.85  # the first level: the lamp is slow and patient
r.write("The Inkwood", "1 / 4",
        "~You slipped out from under my eraser. Into the gutter, of all places.|~These I never finished. Barely a scribble each. You'll hardly see them coming.|Hold right click and raise your Ember. Only in its light are they drawn enough to cut.|Watch their eyes. When the blade goes up, get out of the way.",
        "See? Nothing in here you can't handle. ...Yet.",
        extra_room_props="backdrop_style = 1")

# ------------------------------------------------------------ Level 2: The Red Pen
# scripts/clearing/red_pen_3d.gd: its wet-ink circles (its ink domain) dry
# in light. Four unlit lanterns in the corners: strike them to light them;
# their light dries the circles and, in phase 2, dazzles the pen. Two of the
# Writer's lamps hunt Vesper through the fight.
r = Room("shallows_pen", "shallows", CELLS[1], 13, 9.5, seed=131)
r.gate("east", R + "darkwood_1.tscn", "west", offset=0, entry_only=True)
r.gate("west", R + "wastes_gap.tscn", "east", offset=0)
r.clear_path_to_gates()
r.clear_zones.append((0, 0, 7.0))  # open floor for the fight
r.enemy("red_pen", 0, -2.5, hp=18, arena="Rect2(-10, -6.5, 20, 13)")
for i, (x, z) in enumerate([(-7, -4.5), (7, -4.5), (-7, 4.5), (7, 4.5)]):
    r.prop("brazier", x, z, name=f"Lantern{i + 1}", lit=False, light_radius=3.2, **SPIRIT)
    r.clear_zones.append((x, z, 1.2))
r.scatter("PAPER_MOUND", 3, count=4, radius=1.1, solid=True)
r.scatter("INK_POOL", 2, radius=1.3)
shallows_ring(r)
r.haunt_lamps = 2  # two of the Writer's lamps: a bit harder
r.write("The Red Pen", "The Drowned Margin, 2 / 4",
        "~My editor marked every page in red. Every single page.|Wet ink dries in the light. Make the nib miss, then hit it while it's stuck.|~And this time I'm watching. With both lamps.",
        "~...Stet. It means: let it stand.|~I never knew that until now.",
        extra_room_props='boss_path = NodePath("Enemies/RedPen1")\nboss_name = "THE RED PEN"')

# ------------------------------------------------------------ Level 3: The Torn Page
# Two islands either side of a chasm and a bridge that is only a pencil
# sketch: stand at its end and hold right click, and Vesper's Ember inks it in plank
# by plank for good (drawn_bridge.gd; each plank costs a little Ember, every
# hit refills it). Gentler than before: a shorter bridge, one slow lamp, no
# searchlight, no Inkwells or Crumples.
r = ChasmRoom("wastes_gap", "wastes", CELLS[2], 15, 9, seed=127)
r.gap = 4.0
r.gate("east", R + "shallows_pen.tscn", "west", offset=0, entry_only=True)
r.gate("west", R + "arena.tscn", "east", offset=0)
r.add_bridge()
r.clear_path_to_gates()
r.prop("brazier", 6.3, 2.2, name="LanternEast", lit=False, light_radius=4.2, **EMBER)
r.prop("brazier", -6.3, -2.2, name="LanternWest", lit=False, light_radius=4.2, **EMBER)
r.clear_zones += [(6.3, 2.2, 1.2), (-6.3, -2.2, 1.2)]
r.enemy("scribble", 10, -4)
r.enemy("scribble", 11, 4)
r.enemy("smudge", 8, -1)
r.enemy("scribble", -10, -4)
r.enemy("crossed_out", -10, 4)
r.enemy("scribble", 7, 6)
r.enemy("scribble", -8, -6)
r.scatter("CRYSTAL", 3, count=4, radius=1.1, solid=True)
r.scatter("PINS", 2, count=6, radius=1.1)
r.scatter("PAPER_MOUND", 2, count=4, radius=1.2, solid=True)
wastes_ring(r)
chasm_depths(r, [(("bprops", {"kind": KIND["CRYSTAL"], "size": 3.0, "count": 5, "radius": 1.6, "seed": 7}), 0, 7),
                 (("bprops", {"kind": KIND["PENCIL_TOTEM"], "size": 3.0, "seed": 8}), 1, -7)], y=-8)
r.haunt_lamps = 1
r.haunt_scale = 0.85  # one slow lamp while you work on the bridge
r.write("The Torn Page", "The Torn Wastes, 3 / 4",
        "~This page tore right down the middle. I only ever sketched the bridge.|Stand at the edge and hold right click: your Ember inks the sketch in, plank by plank.|Inking costs Ember. Every hit feeds it, lanterns included.",
        "~Stop. Please. You don't want to see the last page.")

# ------------------------------------------------------------ Level 4: The Rubbing Room
# The Eraser (scripts/clearing/eraser_3d.gd), tuned hard: more rubber,
# faster charges, shorter rests, and below half health it charges twice in
# a row. The room's own lamps (data/haunt/rubbing.tres: two) hunt as well.
r = Arena("arena", "arena", CELLS[3], 12, 10, seed=97)
r.gate("east", R + "wastes_gap.tscn", "west", offset=0, entry_only=True)
r.enemy("eraser", -3, 0, hp=26, walk_speed=2.0, lunge_speed=12.5, windup_time=0.45, tired_time=1.5, cooldown=0.8)
for i in range(8):
    a = math.radians(i * 45 + 22.5)
    x, z = math.cos(a) * 9.6, math.sin(a) * 7.8
    if x > 7 and abs(z) < 3:
        continue
    r.prop("bprops", x, z, name=f"Totem{i + 1}", kind=KIND["PENCIL_TOTEM"], seed=i + 90, solid=True)
r.prop("bprops", -1, 0, name="Circle", kind=KIND["RITUAL_CIRCLE"], radius=4.5, color="Color(1, 0.35, 0.2, 1)")
for i, (x, z) in enumerate([(-5.6, -3.4), (3.6, -3.4), (-5.6, 3.4), (3.6, 3.4)]):
    r.prop("bprops", x, z, name=f"Candles{i + 1}", kind=KIND["CANDLES"], count=4, radius=0.5, seed=95 + i)
r.prop("bprops", -9.4, 1.2, name="Skulls1", kind=KIND["SKULL_PILE"], count=9, radius=0.9, seed=99, solid=True)
r.prop("bprops", -6, -5, name="Pins1", kind=KIND["PINS"], count=7, radius=1.2, seed=91)
r.prop("bprops", -6, 5, name="Pins2", kind=KIND["PINS"], count=7, radius=1.2, seed=92)
r.prop("bprops", 5, -6, name="Mound1", kind=KIND["PAPER_MOUND"], count=5, radius=1.2, seed=93, solid=True)
r.prop("brazier", 9.5, -4, name="Ember1", **EMBER)
r.prop("brazier", 9.5, 4, name="Ember2", **EMBER)
wastes_ring(r)
r.write("The Rubbing Room", "4 / 4",
        "~No. Not this one. Turn back.|~You don't need to see what I did to the other drafts.",
        "~...That isn't how this goes.|~That isn't how ANY of this goes.",
        cutscene="res://scenes/cutscenes/cs_reveal.tscn",
        extra_room_props='boss_path = NodePath("Enemies/Eraser1")\nboss_name = "THE ERASER"')


# ======================================================== retired rooms
# Not part of the four-level Gutter any more: no gate leads to them. Their
# scenes stay in scenes/world25/rooms/. Set OLD_ROOMS = True to rebuild them
# (their gates still point at the old layout).
OLD_ROOMS = False

if OLD_ROOMS:
    # ------------------------------------------------------------ Darkwood 2
    r = Room("darkwood_2", "darkwood", (-1, -1), 14, 9.5, seed=23)
    r.gate("south", R + "darkwood_1.tscn", "north", offset=-3)
    r.gate("west", R + "darkwood_bridge.tscn", "east", offset=1)
    r.enemy("crumple", 6, -3)
    r.enemy("crumple", -5, -4)
    r.enemy("scribble", 0, 2)
    r.enemy("scribble", 7, 4)
    r.enemy("scribble", -7, 3)
    darkwood_dressing(r, graves=4)
    r.prop("altar", 0, -5.5, name="Altar")
    r.clear_zones.append((0, -5.5, 2.5))
    r.prop("brazier", -3.5, -6.5, name="Lantern1", flame_color="Color(1, 0.25, 0.15, 1)")
    r.prop("brazier", 3.5, -6.5, name="Lantern2", flame_color="Color(1, 0.25, 0.15, 1)")
    forest_ring(r)
    r.haunt_scale = 1.06  # the Writer's lamp hunts a little harder here
    r.write("The Inkwood", "2 / 3",
            "Rolling pages. I crumpled those myself, one bad night after another.|They're armoured while they're balled up. Make them hit something, or lead them into the light.",
            "The wood is thinning out. Can you smell the ink?")

    # ------------------------------------------------------------ Darkwood 3: forest melting into the Shallows
    r = Room("darkwood_3", "darkwood", (-3, -1), 15, 9.5, seed=37, biome_b="shallows", blend=((5, 0), (-6, 0)))
    r.gate("east", R + "darkwood_bridge.tscn", "west", offset=1)
    r.gate("west", R + "shallows_1.tscn", "east", offset=0)
    r.enemy("scribble", 6, -3)
    r.enemy("scribble", 7, 4)
    r.enemy("smudge", -2, 3)
    r.enemy("smudge", -7, -3)
    r.enemy("crossed_out", 1, -4)
    r.clear_path_to_gates()
    # forest half (east)
    for i, (x, z) in enumerate([(9, -6), (11, 5), (4, 6.5)]):
        r.prop("bprops", x, z, rot=r.rng.uniform(0, 360), name=f"Grave{i + 1}", kind=KIND["TOMBSTONE"], seed=i + 4, solid=True)
    r.prop("bprops", 6, -7, name="Stump1", kind=KIND["STUMP"], solid=True)
    # water half (west)
    r.prop("bprops", -10, -5.5, name="Pillar2", kind=KIND["PILLAR"], seed=3, solid=True)
    r.prop("bprops", -11, 5, name="Pool2", kind=KIND["INK_POOL"], radius=1.3, seed=5)
    r.prop("bprops", -5, -6.5, name="Pillar1", kind=KIND["PILLAR"], seed=8, solid=True)
    r.prop("bprops", -8, 1.5, name="Pool1", kind=KIND["INK_POOL"], radius=1.6, seed=2)
    r.prop("brazier", 2, 6.8, name="Lantern1", flame_color="Color(1, 0.25, 0.15, 1)")
    r.prop("brazier", -3, -7, name="SpiritFlame", flame_color="Color(0.25, 0.55, 1, 1)", core_color="Color(0.75, 0.92, 1, 1)")
    # surroundings: pines in the east, drowned pillars rising from the deep in the west
    for i, (x, z) in enumerate([(12, -12), (17.5, -5), (17.5, 3), (6, -13)]):
        r.nodes.append(("Forest", f"Pine{i + 1}", "pine", (x, 0, z), 0, {"height": 8.5, "radius": 2.2}))
    for i, (x, z) in enumerate([(-10, -12.5), (-18, -4), (-17.5, 5), (-4, -13)]):
        r.nodes.append(("Forest", f"DeepPillar{i + 1}", "bprops", (x, -6, z), 0, {"kind": KIND["PILLAR"], "size": 2.2, "seed": i + 20}))
    r.nodes.append(("Forest", "TrunkR", "trunk", (18.5, -8, 8.5), 0, {"height": 26.0, "radius": 1.6}))
    r.haunt_scale = 1.15  # the Writer's lamp hunts a little harder here
    r.write("Where the Ink Pools", "The Inkwood, 3 / 3",
            "The ink is pooling up ahead. The woods give way to water here.|Something swims in it. Watch for ripples.",
            "...You're getting good at this. Too good.")

    # ------------------------------------------------------------ Shallows 1
    r = Room("shallows_1", "shallows", (-4, -1), 13, 9.5, seed=51)
    r.gate("east", R + "darkwood_3.tscn", "west", offset=0)
    r.gate("north", R + "shallows_2.tscn", "south", offset=2)
    r.enemy("inkwell", -9, -5.5)
    r.enemy("inkwell", 9, -5)
    r.enemy("smudge", -4, 3)
    r.enemy("smudge", 4, 4)
    r.enemy("scribble", -6, -1)
    shallows_dressing(r)
    r.prop("brazier", -3, -7.5, name="Spirit1", **SPIRIT)
    r.prop("brazier", 7, 6.5, name="Spirit2", **SPIRIT)
    shallows_ring(r)
    r.write("The Drowned Margin", "1 / 2",
            "The Drowned Margin. Where I used to rinse my nibs, before the ink spilled.|The bottles spit. Cut the blobs out of the air, and don't stand in the puddles.",
            "Still here? Fine. Keep going.")

    # ------------------------------------------------------------ Shallows 2: the circle
    r = Room("shallows_2", "shallows", (-4, -2), 14, 10, seed=63)
    r.gate("south", R + "shallows_1.tscn", "north", offset=2)
    r.gate("west", R + "shallows_field.tscn", "east", offset=-1)
    r.prop("bprops", 0, -1.5, name="Circle", kind=KIND["RITUAL_CIRCLE"], radius=5.0)
    r.clear_zones.append((0, -1.5, 5.0))
    for i in range(5):
        a = math.radians(-90 + i * 72)
        r.prop("bprops", math.cos(a) * 6.6, -1.5 + math.sin(a) * 5.4, name=f"CirclePillar{i + 1}", kind=KIND["PILLAR"], seed=i + 60, solid=True)
    r.enemy("crossed_out", -4, -2)
    r.enemy("crossed_out", 4, 1)
    r.enemy("inkwell", 9, -6.5)
    r.enemy("smudge", -8, 5)
    r.enemy("smudge", 7, 6)
    shallows_dressing(r, pillars=0, pools=1, mounds=3)
    r.prop("brazier", -9.5, -7, name="Spirit1", **SPIRIT)
    r.prop("brazier", 9.5, 7, name="Spirit2", **SPIRIT)
    shallows_ring(r)
    r.haunt_scale = 1.08  # the Writer's lamp hunts a little harder here
    r.write("The Drowned Circle", "The Drowned Margin, 2 / 2",
            "~This circle... I drew it the night I gave up on page three.|~Don't read it. Just keep walking.",
            "~You read it, didn't you.")

    # ------------------------------------------------------------ Wastes 1
    r = Room("wastes_1", "wastes", (-7, -2), 13.5, 9.5, seed=71)
    r.gate("east", R + "shallows_pen.tscn", "west", offset=-1)
    r.gate("north", R + "wastes_2.tscn", "south", offset=-2)
    r.enemy("crumple", -7, 2)
    r.enemy("crumple", 6, -4)
    r.enemy("crossed_out", 0, -3)
    r.enemy("scribble", 4, 4)
    r.enemy("scribble", -4, 5)
    wastes_dressing(r)
    r.prop("brazier", -9.5, -6.5, name="Ember1", **EMBER)
    r.prop("brazier", 8, 6.8, name="Ember2", **EMBER)
    wastes_ring(r)
    r.write("The Torn Wastes", "1 / 2",
            "The Torn Wastes. Every page I tore out ends up here.|That red X on their chests? Get behind it, or come down on them from above.",
            "~Why won't you just STAY on the page?")

    # ------------------------------------------------------------ Wastes 2
    r = Room("wastes_2", "wastes", (-7, -3), 14.5, 10, seed=83)
    r.gate("south", R + "wastes_1.tscn", "north", offset=-2)
    r.gate("west", R + "wastes_gap.tscn", "east", offset=0)
    r.enemy("crumple", -6, -4)
    r.enemy("crumple", 7, 3)
    r.enemy("inkwell", -10, 6)
    r.enemy("inkwell", 10, -6.5)
    r.enemy("smudge", 0, 4)
    r.enemy("crossed_out", 3, -4)
    wastes_dressing(r, crystals=4, mounds=2, pins=3, totems=2, pots=1)
    r.prop("brazier", -5, -8, name="Ember1", **EMBER)
    r.prop("brazier", 5, 8, name="Ember2", **EMBER)
    wastes_ring(r)
    r.haunt_scale = 1.08  # the Writer's lamp hunts a little harder here
    r.write("The Pinboard", "The Torn Wastes, 2 / 2",
            "~I used to pin the bad drafts to the wall. Right here.|~Something is still rubbing them out, past that gate.",
            "~No. Not that door. Please.")

    # ------------------------------------------------------------ The Unlit Bridge (Darkwood)
    r = ChasmRoom("darkwood_bridge", "darkwood", (-2, -1), 15, 8.5, seed=101)
    r.gate("east", R + "darkwood_2.tscn", "west", offset=1)
    r.gate("west", R + "darkwood_3.tscn", "east", offset=1)
    r.add_bridge()
    r.clear_path_to_gates()
    r.prop("brazier", 5.3, 2.2, name="LanternEast", lit=False, light_radius=4.2, flame_color="Color(1, 0.55, 0.2, 1)")
    r.prop("brazier", -5.3, -2.2, name="LanternWest", lit=False, light_radius=4.2, flame_color="Color(1, 0.55, 0.2, 1)")
    r.clear_zones += [(5.3, 2.2, 1.2), (-5.3, -2.2, 1.2)]
    r.enemy("scribble", 9, -4)
    r.enemy("scribble", 10, 4)
    r.enemy("scribble_diver", 0, -3.5)
    r.enemy("scribble_diver", 0, 3.5)
    r.enemy("crumple", -10, 2)
    r.scatter("TOMBSTONE", 3, solid=True)
    r.scatter("STUMP", 2, solid=True)
    forest_ring(r)
    chasm_depths(r, [(("pine", {"height": 12.0, "radius": 2.4, "color": "Color(0.06, 0.06, 0.11, 1)"}), 0, 7),
                     (("pine", {"height": 11.0, "radius": 2.0, "color": "Color(0.06, 0.06, 0.11, 1)"}), 1.5, -6.5),
                     (("eyes", {}), 0, 2)], y=-9)
    r.haunt_scale = 1.1  # the Writer's lamp hunts a little harder here
    r.write("The Unlit Bridge", "The Inkwood",
            "That bridge only exists where light touches it.|Your ember will carry you across. Keep it fed: every hit stokes the flame.|Strike the old lanterns to light them. Light stays where you leave it.",
            "...Clever little thing.")

    # ------------------------------------------------------------ The Lamplit Field (Shallows)
    r = Room("shallows_field", "shallows", (-5, -2), 15, 10, seed=113)
    r.gate("east", R + "shallows_2.tscn", "west", offset=-1)
    r.gate("west", R + "shallows_pen.tscn", "east", offset=-1)
    r.clear_path_to_gates()
    r.nodes.append(("Lamp", "Searchlight", "searchlight", (0, 16, -15), 0, {
        "patrol": "PackedVector2Array(-9, -5, 9, -5, 9, 4, -9, 4)", "speed": 3.0, "spot_radius": 2.8}))
    for i, (x, z) in enumerate([(-6, -2.5), (-1.5, 2.5), (3, -2.5), (7.5, 2.5), (-10, 2), (11, -1.5)]):
        r.prop("bprops", x, z, name=f"CoverPillar{i + 1}", kind=KIND["PILLAR"], size=1.3, seed=i + 120, solid=True)
        r.clear_zones.append((x, z, 1.3))
    r.enemy("crossed_out", -4, 0)
    r.enemy("crossed_out", 5, 0)
    r.enemy("smudge", -8, -5)
    r.enemy("smudge", 9, 5)
    r.scatter("PAPER_MOUND", 2, count=4, radius=1.1, solid=True)
    r.scatter("INK_POOL", 2, radius=1.5)
    shallows_ring(r)
    r.haunt_scale = 1.12  # the Writer's lamp hunts a little harder here
    r.write("The Lamplit Field", "The Drowned Margin",
            "~I can't see you down there. But I can look.|Shadows hide you from the lamp. And anything crossed out that it catches... burns.",
            "~Where did you GO?")
