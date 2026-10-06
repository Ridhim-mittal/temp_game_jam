#!/usr/bin/env python3
"""Generates scenes/levels/long_drop.tscn: "The Long Drop", one tall level
that descends through three zones (Archive -> Pencil Works -> Dripping
Margins). Run from anywhere: python3 tools/level2d/build_long_drop.py
(re-running overwrites hand edits to the scene).

How it works: ROOMS are rectangles of open air in map units (1 unit = 5 px).
Everything else inside the level bounds is solid rock. The script rasterises
the rooms on a 50 px grid, merges the solid cells into a few big blocks, and
puts a styled trim on every floor, ceiling and wall edge. Ledges, pickups
and monsters are then placed by hand below.

Player: body 26x52 centred on its origin, so standing on a floor at y=F the
origin is at F-26. A normal jump rises ~170 px; ledges are 110 px apart so
every shaft can be climbed as well as descended.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
U = 5          # px per map unit
G = 50         # grid cell, px
W, H = 2150, 900    # level bounds in map units (rock fills what is not a room)
Y0 = 40             # first map row that matters

# zone borders (map y) and their themes: 1 archive, 2 works, 0 cavern
ZONES = [(265, 1), (545, 2), (10 ** 6, 0)]

# open air, map units: x, y, w, h. Cut down for a ~3 minute run (+ the boss): the hall with the dash
# pit, the drop into the Shadow Gallery, a shaft and a second drop into the Pendulum's cavern, whose
# far bank walks straight into the boss arena. (Retired: hall 1 and its shaft, the plank tower, the two
# side rooms, the pit and the bottom room with the Sketchbook's Blue Gap / lantern bridge replays.)
ROOMS = {
    "hall2": (200, 90, 660, 120), "nook": (60, 90, 160, 120), "shaft2": (770, 210, 90, 110),
    "gallery": (300, 320, 600, 220),                      # light puzzle 1: the Shadow Gallery
    "cavern": (400, 600, 540, 150),                       # light puzzle 2: the Pendulum, over the sump
    "sump": (520, 750, 300, 90),
    "arena": (940, 550, 440, 200),                        # the Scribbled Beast (boss)
    "run": (1380, 600, 700, 150),                         # the Eraser's chase, to the gutter
}
# solid rock put back inside rooms (applied after ROOMS), then air cut through it again
SOLIDS = {
    "bump1": (1560, 742, 20, 8),        # the chase: two easy hops (40 px)...
    "bump2": (1810, 742, 24, 8),
    "shelf": (300, 380, 240, 160),      # the gallery's high exit ledge
    "slab": (650, 720, 40, 10),         # hangs under the pendulum lantern and shadows the bridge
}
CUTS = {
    "run_dip": (1680, 750, 40, 10),     # ...a shallow dip (50 px)
    "gutter_pit": (2030, 750, 50, 150),  # the end of the page: the gutter, down into the Margins
    "shaft2b": (410, 380, 90, 220),     # down through the shelf into the cavern
    # spike pits cut 200 px into the floor (the level's size is unchanged)
    "dash_pit": (650, 210, 90, 40),     # hall2: 450 px, needs a double jump and a dash
}


def theme_at(map_y):
    for bottom, theme in ZONES:
        if map_y < bottom:
            return theme
    return 0


ext = []
nodes = []


def res(kind, path, rid):
    ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')


res("PackedScene", "res://scenes/player/player.tscn", "1_player")
res("Script", "res://scripts/world/big_coin.gd", "49_bigcoin")
res("Script", "res://scripts/effects/fall_cutscene.gd", "48_fallcine")
res("PackedScene", "res://scenes/enemies/crawler.tscn", "2_crawler")
res("Script", "res://scripts/ui/hud.gd", "5_hud")
res("Script", "res://scripts/audio/level_music.gd", "8_music")
res("Script", "res://scripts/world/spikes.gd", "4_spikes")
res("Script", "res://scripts/world/coin.gd", "9_coin")
res("Script", "res://scripts/world/checkpoint_pen.gd", "18_pen")
res("Script", "res://scripts/world/health_heart.gd", "19_heart")
res("PackedScene", "res://scenes/enemies/scribble.tscn", "20_scribble")
res("PackedScene", "res://scenes/enemies/crumple.tscn", "21_crumple")
res("PackedScene", "res://scenes/enemies/crossed_out.tscn", "22_crossed")
res("PackedScene", "res://scenes/enemies/smudge.tscn", "23_smudge")
res("PackedScene", "res://scenes/enemies/inkwell.tscn", "24_inkwell")
res("Script", "res://scripts/world/level_mood.gd", "30_mood")
res("Script", "res://scripts/world/lantern.gd", "40_lantern")
res("Script", "res://scripts/world/sketch_platform.gd", "41_sketch")
res("Script", "res://scripts/world/shadow_caster.gd", "42_caster")
res("Script", "res://scripts/world/caption.gd", "43_caption")
res("Script", "res://scripts/depth/depth_backdrop.gd", "50_backdrop")
res("Script", "res://scripts/depth/rock_block.gd", "51_rock")
res("Script", "res://scripts/depth/depth_trim.gd", "52_trim")
res("Script", "res://scripts/depth/depth_ledge.gd", "53_ledge")
res("Script", "res://scripts/enemies/scribbled_beast.gd", "60_beast")
res("Script", "res://scripts/world/beast_arena.gd", "61_arena")
res("Script", "res://scripts/world/eraser_chase.gd", "62_chase")


def v(x, y):
    return f"Vector2({x:g}, {y:g})"


def node(name, ntype, parent, props, groups=None, instance=None):
    head = f'[node name="{name}"'
    if ntype:
        head += f' type="{ntype}"'
    head += f' parent="{parent}"'
    if groups:
        head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
    if instance:
        head += f' instance=ExtResource("{instance}")'
    head += "]"
    nodes.append("\n".join([head] + [f"{k} = {val}" for k, val in props]))


counts = {}


def uniq(prefix):
    counts[prefix] = counts.get(prefix, 0) + 1
    return f"{prefix}{counts[prefix]}"


# ------------------------------------------------------------ rock + trims
cols, rows = W * U // G, H * U // G
open_cell = [[False] * cols for _ in range(rows)]
for rects, value in ((ROOMS, True), (SOLIDS, False), (CUTS, True)):
    for x, y, w, h in rects.values():
        for cy in range(y * U // G, (y + h) * U // G):
            for cx in range(x * U // G, (x + w) * U // G):
                open_cell[cy][cx] = value


def solid(cx, cy):
    return not (0 <= cx < cols and 0 <= cy < rows) or not open_cell[cy][cx]


# merge solid cells: runs along each row, then stack identical runs
runs = {}
for cy in range(Y0 * U // G, rows):
    cx = 0
    while cx < cols:
        if not open_cell[cy][cx]:
            start = cx
            while cx < cols and not open_cell[cy][cx]:
                cx += 1
            runs.setdefault((start, cx), []).append(cy)
        else:
            cx += 1
for (a, b), ys in runs.items():
    ys.sort()
    i = 0
    while i < len(ys):
        j = i
        while j + 1 < len(ys) and ys[j + 1] == ys[j] + 1:
            j += 1
        x0, x1, top, bottom = a * G, b * G, ys[i] * G, (ys[j] + 1) * G
        node(uniq("Rock"), "StaticBody2D", "World",
             [("position", v((x0 + x1) / 2, (top + bottom) / 2)), ("script", 'ExtResource("51_rock")'),
              ("size", v(x1 - x0, bottom - top))])
        i = j + 1


# thick rock all round the level so the camera never sees past its edge
M = 900
for name, (x0, x1, top, bottom) in {"EdgeLeft": (-M, 0, Y0 * U - M, H * U + M), "EdgeRight": (W * U, W * U + M, Y0 * U - M, H * U + M),
                                    "EdgeTop": (0, W * U, Y0 * U - M, Y0 * U), "EdgeBottom": (0, W * U, H * U, H * U + M)}.items():
    node(name, "StaticBody2D", "World", [("position", v((x0 + x1) / 2, (top + bottom) / 2)), ("script", 'ExtResource("51_rock")'),
         ("size", v(x1 - x0, bottom - top))])


def trim(x, y, length, mode):
    node(uniq("Trim"), "Node2D", "Trims",
         [("position", v(x, y)), ("script", 'ExtResource("52_trim")'), ("length", f"{length:g}"), ("mode", str(mode)),
          ("theme", str(theme_at(y / U)))])


for cy in range(rows):       # floors (mode 0) and ceilings (mode 1)
    for mode, dy in ((0, -1), (1, 1)):
        cx = 0
        while cx < cols:
            if solid(cx, cy) and not solid(cx, cy + dy):
                start = cx
                while cx < cols and solid(cx, cy) and not solid(cx, cy + dy):
                    cx += 1
                trim(start * G, cy * G if mode == 0 else (cy + 1) * G, (cx - start) * G, mode)
            else:
                cx += 1
for cx in range(cols):       # walls: mode 2 faces right, mode 3 faces left
    for mode, dx in ((2, 1), (3, -1)):
        cy = 0
        while cy < rows:
            if solid(cx, cy) and not solid(cx + dx, cy):
                start = cy
                while cy < rows and solid(cx, cy) and not solid(cx + dx, cy) and theme_at(cy * G / U) == theme_at(start * G / U):
                    cy += 1
                trim((cx + 1) * G if mode == 2 else cx * G, start * G, (cy - start) * G, mode)
            else:
                cy += 1


# ----------------------------------------------------------------- helpers
def px(name):
    x, y, w, h = {**ROOMS, **SOLIDS, **CUTS}[name]
    return x * U, y * U, (x + w) * U, (y + h) * U   # left, top, right, floor


def ledge(cx, top, w=180, one_way=True):
    node(uniq("Ledge"), "StaticBody2D", "World",
         [("position", v(cx, top + 9)), ("script", 'ExtResource("53_ledge")'), ("size", v(w, 18)),
          ("theme", str(theme_at(top / U))), ("one_way", "true" if one_way else "false")])


def steps(x0, x1, y_from, y_to, w=170):
    """Alternating ledges down a shaft, 110 px apart, so it can be climbed too."""
    y, side = y_from + 110, 0
    while y <= y_to - 100:
        ledge(x0 + w / 2 + 10 if side == 0 else x1 - w / 2 - 10, y, w)
        y += 110
        side ^= 1


def lamp(x, y, r=260, chain=70):
    """Scenery lantern hung from (x, y): lit, casts no shadows."""
    node(uniq("Lantern"), "Node2D", "World",
         [("position", v(x, y)), ("script", 'ExtResource("40_lantern")'), ("radius", f"{r:g}"), ("chain", f"{chain:g}"),
          ("casts_shadows", "false")])


def lantern(x, y, r, chain=60, post=0, lit=True, swing=0, period=3.0, name="PuzzleLantern"):
    """Puzzle lantern hung by `chain` from the pivot (x, y), or on a `post`: casts shadows, hit to toggle."""
    props = [("position", v(x, y)), ("script", 'ExtResource("40_lantern")'), ("radius", f"{r:g}"),
             ("chain", f"{chain:g}"), ("post", f"{post:g}"), ("lit", "true" if lit else "false"), ("casts_shadows", "true")]
    if swing:
        props += [("swing", f"{swing:g}"), ("swing_period", f"{period:g}")]
    node(name, "Node2D", "World", props)


def sketch(x0, x1, top, h=20, inkable=True, name=None, drinks=False):
    props = [("position", v((x0 + x1) / 2, top + h / 2)), ("script", 'ExtResource("41_sketch")'), ("size", v(x1 - x0, h)),
             ("inkable", "true" if inkable else "false")]
    if drinks:  # the Ember drains twice as fast over it (ember.gd)
        props.append(("drinks_light", "true"))
    node(name or uniq("Sketch"), "StaticBody2D", "World", props)


def spikes(x0, x1, floor):
    """A spike strip on a floor at y=floor (width a multiple of 20 px: the spike drawing needs it)."""
    assert (x1 - x0) % 20 == 0, (x0, x1)
    node(uniq("Spikes"), "StaticBody2D", "World",
         [("position", v((x0 + x1) / 2, floor - 12)), ("script", 'ExtResource("4_spikes")'), ("size", v(x1 - x0, 24))])


def pit_spikes(name):
    """Spikes along the floor of a pit in CUTS (5 px clear of each wall)."""
    l, t, r, f = px(name)
    w = (r - l - 10) // 20 * 20
    spikes((l + r - w) / 2, (l + r + w) / 2, f)


def caster(x, y, stick=0, length=420, name=None):
    node(name or uniq("Cutout"), "StaticBody2D", "World",
         [("position", v(x, y)), ("script", 'ExtResource("42_caster")'), ("stick", f"{stick:g}"), ("shadow_length", f"{length:g}")])


def caption(x, y, text, tilt=-0.03):
    node(uniq("Caption"), "Node2D", "World", [("z_index", "5"), ("position", v(x, y)), ("script", 'ExtResource("43_caption")'),
         ("text", '"' + text.replace("\n", "\\n") + '"'), ("tilt", f"{tilt:g}")])


def enemy(kind, x, y, extra=()):
    rid = {"crawler": "2_crawler", "scribble": "20_scribble", "crumple": "21_crumple", "crossed": "22_crossed",
           "smudge": "23_smudge", "inkwell": "24_inkwell"}[kind]
    node(uniq(kind.capitalize()), None, "Enemies", [("position", v(x, y))] + list(extra), instance=rid)


coins = []


def coin_row(x0, x1, y, n):
    for i in range(n):
        coins.append((x0 + (x1 - x0) * (i / max(n - 1, 1)), y))


def checkpoint(x, floor_y):
    node(uniq("Checkpoint"), "Area2D", "World", [("position", v(x, floor_y)), ("script", 'ExtResource("18_pen")')])


def big_coin(x, y):
    """The big Lumen (big_coin.gd): 15 coins at once, off the usual path."""
    node(uniq("BigCoin"), "Area2D", "World", [("position", v(x, y)), ("script", 'ExtResource("49_bigcoin")')])


def heart(x, y):
    node(uniq("Heart"), "Area2D", "World", [("position", v(x, y)), ("script", 'ExtResource("19_heart")')])


# ------------------------------------------------------------- the rooms
# 1. THE ARCHIVE: the hall with the dash pit (the level starts here), a quiet nook to the left
l2, t2, r2, f2 = px("hall2")
START = (l2 + 150, f2 - 26)
nl, nt, nr, nf = px("nook")
lamp(nl + 220, nt, 260, 120)
heart(nl + 520, nf - 60)
ledge(nl + 260, nf - 120, 180)                  # the nook's secret: up on a ledge in the dark corner
big_coin(nl + 110, nf - 330)
ledge(l2 + 900, f2 - 110, 240)
ledge(l2 + 1500, f2 - 110, 240)
ledge(l2 + 1200, f2 - 220, 240)
coin_row(l2 + 820, l2 + 980, f2 - 150, 3)
coin_row(l2 + 1120, l2 + 1280, f2 - 260, 3)
enemy("crawler", l2 + 1400, f2 - 20)
enemy("crawler", l2 + 2050, f2 - 20)
# the City's dash pit, wider: 450 px of spikes. A dash (at most ~430 px) or a double jump
# (~470 at its very best, from the very edge) falls short; jump, jump again, dash (~510) clears it.
pit_spikes("dash_pit")
coin_row(px("dash_pit")[0] + 80, px("dash_pit")[2] - 80, f2 - 150, 3)
lamp(l2 + 1200, t2, 320, 110)
lamp(l2 + 2500, t2, 300, 150)

# 2. THE PENCIL WORKS: the Shadow Gallery (light puzzle)
sl, st, sr, sf = px("shaft2")
gl, gt, gr, F = px("gallery")
steps(sl, sr, st, gt + 60)
# Below the shaft's last ledge it's a ~1200 px drop into the gallery, past the fall-damage height and
# out of the player's hands: a short cutscene (fall_cutscene.gd) instead. HUD out, letterbox in, the
# camera leans in, and he lands kneeling but unhurt.
node("DropCutscene", "Area2D", "World", [("position", v((sl + sr) / 2, gt + 20)), ("script", 'ExtResource("48_fallcine")'),
     ("size", v(sr - sl, 120))])
# The Shadow Gallery. You land on the right; the way on is a ledge 800 px up on the left.
#   1. Hit lantern B (on a post). The cut-out star beside it throws a ramp of shadow ink up and left.
#   2. From the top of that ramp lantern A hangs dead ahead, out of sword reach: an ink wave
#      (hold attack) lights it. (Or raise the Ember, cross the blue sketch and slash it.)
#   3. A's light holds the blue sketch solid and its star throws a second ramp up to the ledge.
wall = px("shelf")[2]                            # x of the ledge's face
checkpoint(gr - 150, F)
lantern(wall + 1496, F - 70, 220, chain=0, post=70, lit=False, name="LanternB")
caster(wall + 1376, F - 150, stick=150, length=600, name="StarB")
lantern(wall + 460, gt, 260, chain=F - 500 - gt, lit=False, name="LanternA")
caster(wall + 330, F - 585, length=520, name="StarA")
sketch(wall + 310, wall + 710, F - 470, inkable=False, name="GallerySketch")
caption(wall + 1640, F - 330, "HIT THE LANTERN.\nA SHADOW IS INK TOO.")
hl, ht, hr, hf = px("shelf")
heart(hl + 250, ht - 60)
coin_row(hl + 120, hl + 520, ht - 40, 5)

# 3. THE DRIPPING MARGINS: down through the shelf (a short shaft of ledges, then a second drop
# cutscene into the cavern), the Pendulum (light puzzle), its far bank and the boss.
sl, st, sr, sf = px("shaft2b")
cl, ct, cr, cf = px("cavern")
steps(sl, sr, st, ct)
node("DropCutscene2", "Area2D", "World", [("position", v((sl + sr) / 2, ct + 20)), ("script", 'ExtResource("48_fallcine")'),
     ("size", v(sr - sl, 120))])
# The Pendulum. A blue sketch bridge over the sump, 1500 px: too far for one Ember (about
# 1200 px), far too far to jump. The lantern swings across the middle of it and refills the
# Ember in its light, but its reach stops short of both ends and the slab under it shadows the
# centre. Cross with the swing; spend the Ember only where the lantern's light is not.
# You land on the near (west) bank. Falling in is not deadly: ledges climb back out, and down
# there, under the bridge, lies the second big Lumen.
ul, ut, ur, uf = px("sump")
mid = (ul + ur) / 2
checkpoint(ul - 300, cf)
sketch(ul, ur, cf, inkable=False, name="PendulumBridge")
lantern(mid, cf - 640, 420, chain=380, swing=40, period=5.0, name="Pendulum")
steps(ul, ul + 300, cf, uf, 150)
big_coin(ur - 200, uf - 70)
enemy("scribble", mid + 200, cf - 430)
lamp(cl + 250, ct, 300, 200)
# the far bank: a breath, a heart and the last checkpoint, then the arena
coin_row(ur + 60, ur + 260, cf - 60, 3)
heart(ur + 200, cf - 60)
checkpoint(cr - 150, cf)                           # before the boss

# THE SCRIBBLED BEAST (scribbled_beast.gd, run by beast_arena.gd): it comes out of the gutter
# between the page's columns, holding a shield torn out of the gutter itself. Two lanterns on
# posts: it snuffs them as it comes; light one and it cowers a moment, its shield turned to the
# light, then lobs ink at it. It watches only these two lanterns.
al, at, ar, af = px("arena")
gap = (al + ar) / 2
lantern(gap - 560, af - 70, 280, chain=0, post=70, lit=True, name="ArenaLanternW")
lantern(gap + 560, af - 70, 280, chain=0, post=70, lit=True, name="ArenaLanternE")
node("ScribbledBeast", "CharacterBody2D", "Enemies", [("position", v(gap, af + 600)), ("script", 'ExtResource("60_beast")')])
node("BeastArena", "Node2D", "World", [("position", v(gap, af)), ("script", 'ExtResource("61_arena")'),
     ("beast_path", 'NodePath("../../Enemies/ScribbledBeast")'),
     ("lantern_paths", 'Array[NodePath]([NodePath("../ArenaLanternW"), NodePath("../ArenaLanternE")])'),
     ("trigger_x", f"{al + 340:g}"), ("barrier_x", f"{al + 30:g}"), ("east_x", f"{ar - 20:g}"), ("room_height", f"{af - at:g}"),
     ("chase_path", 'NodePath("../EraserChase")')])

# THE ERASER'S CHASE (eraser_chase.gd): after the fight Shade drops his eraser into the arena,
# the arena's right-hand border rips open and Vesper runs east down this corridor, the Eraser
# rubbing the world out behind him. Two easy hops and a dip. The corridor ends where its panel
# ends: the gutter (a pit), and he falls into the Margins (margins_fall.gd, then the 2.5D hub).
rl, rt, rr, rf = px("run")
gl1, _, gr1, _ = px("gutter_pit")
checkpoint(rl + 160, rf)                            # dying in the chase restarts it here
node("EraserChase", "Node2D", "World", [("position", v(rl, rf)), ("script", 'ExtResource("62_chase")'),
     ("end_x", f"{(gl1 + gr1) / 2:g}"), ("gutter_half", f"{(gr1 - gl1) / 2:g}"), ("erase_from", f"{al + 60:g}"),
     ("room_top", f"{rt:g}")])


# ------------------------------------------------------------------ write
zone_bottoms = ", ".join(f"{b * U:g}" for b, _ in ZONES[:-1])
themes = ", ".join(str(th) for _, th in ZONES)
out = ["[gd_scene format=3]", ""] + ext + ["", '[node name="LongDrop" type="Node2D"]', "",
       '[node name="Backdrop" type="Node2D" parent="."]', 'script = ExtResource("50_backdrop")',
       f"themes = PackedInt32Array({themes})", f"zone_bottoms = PackedFloat32Array({zone_bottoms})", "",
       '[node name="World" type="Node2D" parent="."]', ""]
world = [n for n in nodes if 'parent="World"' in n]
trims = [n for n in nodes if 'parent="Trims"' in n]
enemies = [n for n in nodes if 'parent="Enemies"' in n]
out += ["\n\n".join(world), "", '[node name="Trims" type="Node2D" parent="."]', "", "\n\n".join(trims), "",
        '[node name="Coins" type="Node2D" parent="."]', ""]
for i, (x, y) in enumerate(coins, 1):
    out += [f'[node name="Coin{i}" type="Area2D" parent="Coins"]', f"position = {v(round(x), round(y))}",
            'script = ExtResource("9_coin")', ""]
out += ['[node name="Enemies" type="Node2D" parent="."]', "", "\n\n".join(enemies), "",
        '[node name="Player" parent="." instance=ExtResource("1_player")]', f"position = {v(*START)}", "",
        '[node name="UI" type="CanvasLayer" parent="."]', "layer = 2", "",
        '[node name="HUD" type="Control" parent="UI"]', "layout_mode = 3", "anchors_preset = 15",
        "anchor_right = 1.0", "anchor_bottom = 1.0", "grow_horizontal = 2", "grow_vertical = 2",
        "mouse_filter = 2", 'script = ExtResource("5_hud")', "",
        '[node name="LevelMusic" type="Node" parent="."]', 'script = ExtResource("8_music")', 'track = "deep"', "",
        '[node name="LevelMood" type="Node" parent="."]', 'script = ExtResource("30_mood")', ""]
open(os.path.join(ROOT, "scenes/levels/long_drop.tscn"), "w").write("\n".join(out))
print(f"{len(world)} world nodes, {len(trims)} trims, {len(enemies)} enemies, {len(coins)} coins; start {START}")
