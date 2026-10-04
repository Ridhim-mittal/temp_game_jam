#!/usr/bin/env python3
"""Builds the 2.5D story rooms: python3 tools/rooms25/build_rooms.py
Each block below describes one room: size, gates (and where they lead),
monsters, props and the Writer's captions. Rooms are deterministic (seeded),
so re-running gives the same layout. Re-running overwrites hand edits."""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from rooms import Room, forest_ring, KIND

R = "res://scenes/world25/rooms/"
HUB = "res://scenes/clearing/clearing.tscn"


def darkwood_dressing(r, graves=3, stumps=2, mushrooms=2, rocks=2, reeds=2):
    r.clear_path_to_gates()
    for i in range(reeds):
        spot = r.free_spot(clearance=2.5)
        if spot:
            x, z = spot
            r.clear_zones.append((x, z, 1.8))
            r.nodes.append(("Props", f"Reeds{i + 1}", "grass", (0, 0, 0), 0, {
                "island_path": 'NodePath("../../Island")', "area": f"Rect2({x - 2:.1f}, {z - 1.5:.1f}, 4, 3)", "count": 22,
                "size_range": "Vector2(1.4, 2.2)", "seed": r.rng.randint(1, 99), "blades": 7, "biome_tint": "Color(0.7, 0.75, 0.78, 1)"}))
    r.scatter("TOMBSTONE", graves, solid=True)
    r.scatter("STUMP", stumps, solid=True)
    for i in range(mushrooms):
        spot = r.free_spot()
        if spot:
            r.prop("scatter", spot[0], spot[1], name=f"Mushrooms{i + 1}", count=5, seed=r.rng.randint(1, 99))
    for i in range(rocks):
        spot = r.free_spot()
        if spot:
            r.prop("scatter", spot[0], spot[1], name=f"Rocks{i + 1}", kind=2, count=3, radius=0.9, size=1.2,
                   color="Color(0.6, 0.58, 0.56, 1)", seed=r.rng.randint(1, 99), solid=True)


# ------------------------------------------------------------ Darkwood 1
r = Room("darkwood_1", "darkwood", (-1, 0), 13, 9, seed=11)
r.gate("east", HUB, "cave")
r.gate("north", R + "darkwood_2.tscn", "south", offset=-3)
r.enemy("scribble", -6, -2)
r.enemy("scribble", -3, 4)
r.enemy("scribble", 2, -4)
r.enemy("scribble", 5, 3)
r.enemy("crumple", -8, 4)
darkwood_dressing(r)
r.prop("brazier", -9.5, -6, name="Lantern1", flame_color="Color(1, 0.25, 0.15, 1)")
r.prop("brazier", 9.5, 6, name="Lantern2", flame_color="Color(1, 0.25, 0.15, 1)")
forest_ring(r)
r.write("Darkwood Margins", "1 / 3",
        "These woods weren't in any draft I kept.|The way on is always on the far side. Clear a path.",
        "See? Nothing in here you can't handle.")

# ------------------------------------------------------------ Darkwood 2
r = Room("darkwood_2", "darkwood", (-1, -1), 14, 9.5, seed=23)
r.gate("south", R + "darkwood_1.tscn", "north", offset=-3)
r.gate("west", R + "darkwood_3.tscn", "east", offset=1)
r.enemy("crumple", 6, -3)
r.enemy("crumple", -5, -4)
r.enemy("scribble", 0, 2)
r.enemy("scribble", 7, 4)
r.enemy("scribble", -7, 3)
darkwood_dressing(r, graves=4, reeds=3)
r.prop("altar", 0, -5.5, name="Altar")
r.clear_zones.append((0, -5.5, 2.5))
r.prop("brazier", -3.5, -6.5, name="Lantern1", flame_color="Color(1, 0.25, 0.15, 1)")
r.prop("brazier", 3.5, -6.5, name="Lantern2", flame_color="Color(1, 0.25, 0.15, 1)")
forest_ring(r, canopies=3)
r.write("Darkwood Margins", "2 / 3",
        "Rolling pages. I crumpled those myself, one bad night after another.|They're armoured while they're balled up. Make them hit something, or lead them into the light.",
        "The wood is thinning out. Can you smell the ink?")

# ------------------------------------------------------------ Darkwood 3: forest melting into the Shallows
r = Room("darkwood_3", "darkwood", (-2, -1), 15, 9.5, seed=37, biome_b="shallows", blend=((5, 0), (-6, 0)))
r.gate("east", R + "darkwood_2.tscn", "west", offset=1)
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
r.prop("scatter", 10, -1, name="Mushrooms1", count=6, seed=7)
r.prop("bprops", 6, -7, name="Stump1", kind=KIND["STUMP"], solid=True)
# water half (west)
r.prop("bprops", -10, -5.5, name="Coral1", kind=KIND["CORAL"], count=6, radius=1.4, seed=3, solid=True)
r.prop("bprops", -11, 5, name="Tubes1", kind=KIND["TUBE_PLANT"], count=5, seed=5)
r.prop("bprops", -5, -6.5, name="Pillar1", kind=KIND["PILLAR"], seed=8, solid=True)
r.prop("bprops", -8, 1.5, name="Pool1", kind=KIND["INK_POOL"], radius=1.6, seed=2)
r.prop("brazier", 2, 6.8, name="Lantern1", flame_color="Color(1, 0.25, 0.15, 1)")
r.prop("brazier", -3, -7, name="SpiritFlame", flame_color="Color(0.25, 0.55, 1, 1)", core_color="Color(0.75, 0.92, 1, 1)")
# surroundings: pines in the east, coral and tubes rising from the deep in the west
for i, (x, z) in enumerate([(12, -12), (17.5, -5), (17.5, 3), (6, -13)]):
    r.nodes.append(("Forest", f"Pine{i + 1}", "pine", (x, 0, z), 0, {"height": 8.5, "radius": 2.2}))
for i, (x, z) in enumerate([(-10, -12.5), (-18, -4), (-17.5, 5), (-4, -13)]):
    r.nodes.append(("Forest", f"DeepCoral{i + 1}", "bprops", (x, -4, z), 0, {"kind": KIND["CORAL"], "size": 2.2, "count": 7, "radius": 1.6, "seed": i + 20}))
r.nodes.append(("Forest", "DeepTubes", "bprops", (-12, -6, 13), 0, {"kind": KIND["TUBE_PLANT"], "size": 3.0, "count": 6, "seed": 9}))
r.nodes.append(("Forest", "TrunkR", "trunk", (18.5, -8, 8.5), 0, {"height": 26.0, "radius": 1.6}))
r.nodes.append(("Forest", "Canopy1", "bprops", (8, 0, -11.5), 0, {"kind": KIND["CANOPY"], "size": 1.1, "seed": 31}))
r.write("Where the Ink Pools", "Darkwood, 3 / 3",
        "The ink is pooling up ahead. The woods give way to water here.|Something swims in it. Watch for ripples.",
        "...You're getting good at this. Too good.")


def shallows_dressing(r, coral=3, tubes=2, pillars=2, pools=2):
    r.clear_path_to_gates()
    r.scatter("CORAL", coral, count=6, radius=1.3, solid=True)
    r.scatter("TUBE_PLANT", tubes, count=5)
    r.scatter("PILLAR", pillars, solid=True)
    r.scatter("INK_POOL", pools, radius=1.5)


def shallows_ring(r):
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        x, z = math.cos(a) * (r.hw + 4), math.sin(a) * (r.hd + 4)
        if any(math.dist((x, z), r.gate_pos(s)) < 5.5 for s in r.gates):
            continue
        k = "CORAL" if i % 2 == 0 else "TUBE_PLANT"
        r.nodes.append(("Deep", f"Deep{i + 1}", "bprops", (x, -4.5 if k == "CORAL" else -6, z), 0,
                        {"kind": KIND[k], "size": 2.4, "count": 7, "radius": 1.8, "seed": r.rng.randint(1, 99)}))
    for i, sx in enumerate((-1, 1)):
        r.nodes.append(("Deep", f"RuinPillar{i + 1}", "bprops", (sx * (r.hw + 3), -6, -r.hd - 1.5), 0,
                        {"kind": KIND["PILLAR"], "size": 2.4, "seed": 40 + i}))
    r.nodes.append(("Deep", "Eyes1", "eyes", (r.rng.uniform(-r.hw, r.hw), -4, r.hd + 3), 0, {"color": "Color(0.4, 1, 0.85, 1)"}))


SPIRIT = dict(flame_color="Color(0.25, 0.55, 1, 1)", core_color="Color(0.75, 0.92, 1, 1)")

# ------------------------------------------------------------ Shallows 1
r = Room("shallows_1", "shallows", (-3, -1), 13, 9.5, seed=51)
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
r.write("Inkwell Shallows", "1 / 2",
        "The Inkwell Shallows. Where I used to rinse my nibs.|The bottles spit. Cut the blobs out of the air, and don't stand in the puddles.",
        "Still here? Fine. Keep going.")

# ------------------------------------------------------------ Shallows 2: the circle
r = Room("shallows_2", "shallows", (-3, -2), 14, 10, seed=63)
r.gate("south", R + "shallows_1.tscn", "north", offset=2)
r.gate("west", R + "wastes_1.tscn", "east", offset=-1)
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
shallows_dressing(r, coral=3, tubes=3, pillars=0, pools=1)
r.prop("brazier", -9.5, -7, name="Spirit1", **SPIRIT)
r.prop("brazier", 9.5, 7, name="Spirit2", **SPIRIT)
shallows_ring(r)
r.write("The Drowned Circle", "Inkwell Shallows, 2 / 2",
        "~This circle... I drew it the night I gave up on page three.|~Don't read it. Just keep walking.",
        "~You read it, didn't you.")


def wastes_dressing(r, crystals=3, mounds=3, pins=2, nests=1, totems=2, pots=2):
    r.clear_path_to_gates()
    r.scatter("CRYSTAL", crystals, count=4, radius=1.2, solid=True)
    r.scatter("PAPER_MOUND", mounds, count=5, radius=1.3, solid=True)
    r.scatter("PINS", pins, count=6, radius=1.2)
    r.scatter("NEST", nests, count=4, radius=1.2, solid=True)
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

# ------------------------------------------------------------ Wastes 1
r = Room("wastes_1", "wastes", (-4, -2), 13.5, 9.5, seed=71)
r.gate("east", R + "shallows_2.tscn", "west", offset=-1)
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
r.write("Crumple Wastes", "1 / 2",
        "The Crumple Wastes. Every page I tore out ends up here.|That red X on their chests? Get behind it, or come down on them from above.",
        "~Why won't you just STAY on the page?")

# ------------------------------------------------------------ Wastes 2
r = Room("wastes_2", "wastes", (-4, -3), 14.5, 10, seed=83)
r.gate("south", R + "wastes_1.tscn", "north", offset=-2)
r.gate("west", R + "arena.tscn", "east", offset=0)
r.enemy("crumple", -6, -4)
r.enemy("crumple", 7, 3)
r.enemy("inkwell", -10, 6)
r.enemy("inkwell", 10, -6.5)
r.enemy("smudge", 0, 4)
r.enemy("crossed_out", 3, -4)
wastes_dressing(r, crystals=4, mounds=2, pins=3, nests=2, totems=2, pots=1)
r.prop("brazier", -5, -8, name="Ember1", **EMBER)
r.prop("brazier", 5, 8, name="Ember2", **EMBER)
wastes_ring(r)
r.write("The Pinboard", "Crumple Wastes, 2 / 2",
        "~I used to pin the bad drafts to the wall. Right here.|~Something is still rubbing them out, past that gate.",
        "~No. Not that door. Please.")


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


r = Arena("arena", "arena", (-5, -3), 12, 10, seed=97)
r.gate("east", R + "wastes_2.tscn", "west", offset=0)
r.enemy("eraser", -3, 0, hp=16)
for i in range(8):
    a = math.radians(i * 45 + 22.5)
    x, z = math.cos(a) * 9.6, math.sin(a) * 7.8
    if x > 7 and abs(z) < 3:
        continue
    r.prop("bprops", x, z, name=f"Totem{i + 1}", kind=KIND["PENCIL_TOTEM"], seed=i + 90, solid=True)
r.prop("bprops", -1, 0, name="Circle", kind=KIND["RITUAL_CIRCLE"], radius=4.5, color="Color(1, 0.35, 0.2, 1)")
r.prop("bprops", -6, -5, name="Pins1", kind=KIND["PINS"], count=7, radius=1.2, seed=91)
r.prop("bprops", -6, 5, name="Pins2", kind=KIND["PINS"], count=7, radius=1.2, seed=92)
r.prop("bprops", 5, -6, name="Mound1", kind=KIND["PAPER_MOUND"], count=5, radius=1.2, seed=93, solid=True)
r.prop("brazier", 9.5, -4, name="Ember1", **EMBER)
r.prop("brazier", 9.5, 4, name="Ember2", **EMBER)
wastes_ring(r)
r.write("The Rubbing Room", "",
        "~No. Not this one. Turn back.|~You don't need to see what I did to the other drafts.",
        "~...That isn't how this goes.|~That isn't how ANY of this goes.",
        cutscene="res://scenes/cutscenes/cs_reveal.tscn",
        extra_room_props='boss_path = NodePath("Enemies/Eraser1")\nboss_name = "THE ERASER"')
