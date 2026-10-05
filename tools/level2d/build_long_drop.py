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
W, H = 1050, 1440   # level bounds in map units (rock fills what is not a room)
Y0 = 40             # first map row that matters

# zone borders (map y) and their themes: 1 archive, 2 works, 0 cavern
ZONES = [(500, 1), (950, 2), (10 ** 6, 0)]

# open air, map units: x, y, w, h
ROOMS = {
    "hall1": (60, 90, 580, 130), "shaft1": (540, 220, 90, 120), "hall2": (200, 340, 660, 120),
    "nook": (60, 340, 160, 120), "shaft2": (770, 460, 90, 110),
    "tower": (430, 570, 460, 320), "side_a": (120, 610, 260, 110), "door_a": (380, 670, 50, 50),
    "side_b": (120, 780, 260, 110), "door_b": (380, 840, 50, 50), "shaft3": (480, 890, 90, 100),
    "cavern": (80, 990, 780, 150), "pit": (670, 1140, 110, 90), "bottom": (300, 1230, 640, 150),
    "lift": (920, 340, 70, 1040), "lift_door": (860, 390, 60, 70),
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
res("PackedScene", "res://scenes/enemies/crawler.tscn", "2_crawler")
res("Script", "res://scripts/ui/hud.gd", "5_hud")
res("Script", "res://scripts/audio/level_music.gd", "8_music")
res("Script", "res://scripts/world/coin.gd", "9_coin")
res("Script", "res://scripts/world/moving_platform.gd", "12_moving")
res("Script", "res://scripts/world/level_exit.gd", "17_exit")
res("Script", "res://scripts/world/checkpoint_pen.gd", "18_pen")
res("Script", "res://scripts/world/health_heart.gd", "19_heart")
res("PackedScene", "res://scenes/enemies/scribble.tscn", "20_scribble")
res("PackedScene", "res://scenes/enemies/crumple.tscn", "21_crumple")
res("PackedScene", "res://scenes/enemies/crossed_out.tscn", "22_crossed")
res("PackedScene", "res://scenes/enemies/smudge.tscn", "23_smudge")
res("PackedScene", "res://scenes/enemies/inkwell.tscn", "24_inkwell")
res("Script", "res://scripts/world/level_mood.gd", "30_mood")
res("Script", "res://scripts/world/lantern.gd", "40_lantern")
res("Script", "res://scripts/world/caption.gd", "43_caption")
res("Script", "res://scripts/depth/depth_backdrop.gd", "50_backdrop")
res("Script", "res://scripts/depth/rock_block.gd", "51_rock")
res("Script", "res://scripts/depth/depth_trim.gd", "52_trim")
res("Script", "res://scripts/depth/depth_ledge.gd", "53_ledge")


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
for x, y, w, h in ROOMS.values():
    for cy in range(y * U // G, (y + h) * U // G):
        for cx in range(x * U // G, (x + w) * U // G):
            open_cell[cy][cx] = True


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
    x, y, w, h = ROOMS[name]
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
    node(uniq("Lantern"), "Node2D", "World",
         [("position", v(x, y)), ("script", 'ExtResource("40_lantern")'), ("radius", f"{r:g}"), ("chain", f"{chain:g}"),
          ("casts_shadows", "false")])


def caption(x, y, text, tilt=-0.03):
    node(uniq("Caption"), "Node2D", "World",
         [("position", v(x, y)), ("script", 'ExtResource("43_caption")'), ("text", f'"{text}"'), ("tilt", f"{tilt:g}")])


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


def heart(x, y):
    node(uniq("Heart"), "Area2D", "World", [("position", v(x, y)), ("script", 'ExtResource("19_heart")')])


# ------------------------------------------------------------- the rooms
# 1. THE ARCHIVE: top hall, first shaft, lower hall, a quiet nook
l, t, r, f = px("hall1")
START = (l + 200, f - 26)
ledge(l + 900, f - 110, 220)
ledge(l + 1250, f - 220, 220)
ledge(l + 1650, f - 110, 220)
coin_row(l + 820, l + 980, f - 150, 3)
coin_row(l + 1170, l + 1330, f - 260, 3)
coin_row(l + 1570, l + 1730, f - 150, 3)
lamp(l + 520, t, 300, 150)
lamp(l + 1900, t, 300, 190)
sl, st, sr, sf = px("shaft1")
l2, t2, r2, f2 = px("hall2")
steps(sl, sr, st, f2)
coin_row(sl + 225, sl + 225, st + 200, 1)
nl, nt, nr, nf = px("nook")
checkpoint(nl + 330, nf)
lamp(nl + 220, nt, 260, 120)
heart(nl + 520, nf - 60)
ledge(l2 + 900, f2 - 110, 240)
ledge(l2 + 1500, f2 - 110, 240)
ledge(l2 + 1200, f2 - 220, 240)
coin_row(l2 + 1120, l2 + 1280, f2 - 260, 3)
enemy("crawler", l2 + 700, f2 - 20)
enemy("crawler", l2 + 2000, f2 - 20)
lamp(l2 + 1200, t2, 320, 110)
lamp(l2 + 2500, t2, 300, 150)

# 2. THE PENCIL WORKS: shaft into the scaffold tower, two side rooms
sl, st, sr, sf = px("shaft2")
tl, tt, tr, tf = px("tower")
steps(sl, sr, st, tt + 60)
ledge((sl + sr) / 2, st, 150)                    # stepping stone across the shaft mouth, towards the lift
# the tower: a zigzag of planks from the shaft mouth down to the floor
y, i = tt + 170, 0
span = (tr - 260) - (tl + 260)
while y <= tf - 100:
    k = (i * 290) % (2 * span)
    cx = (tr - 260) - (k if k <= span else 2 * span - k)
    ledge(cx, y, 300)
    if i % 3 == 1:
        coin_row(cx - 60, cx + 60, y - 40, 3)
    y += 110
    i += 1
for sx, sy in [(tl + 700, tt + 420), (tl + 1500, tt + 760), (tl + 900, tt + 1150)]:
    enemy("scribble", sx, sy)
lamp(tl + 600, tt, 320, 220)
lamp(tl + 1700, tt, 320, 520)
lamp(tl + 1100, tt, 320, 900)
al, at, ar, af = px("side_a")
ledge(tl + 150, af, 300, one_way=False)        # landing outside the upper side room
checkpoint(al + 500, af)
coin_row(al + 200, al + 380, af - 40, 4)
lamp(al + 700, at, 280, 130)
heart(al + 950, af - 60)
bl, bt, br, bf = px("side_b")                    # the ambush room
enemy("crumple", bl + 350, bf - 25)
enemy("crossed", bl + 900, bf - 30)
coin_row(bl + 150, bl + 450, bf - 200, 6)
ledge(bl + 300, bf - 110, 220)
lamp(bl + 650, bt, 280, 130)

# 3. THE DRIPPING MARGINS: shaft, wide cavern, the pit, the bottom
sl, st, sr, sf = px("shaft3")
cl, ct, cr, cf = px("cavern")
steps(sl, sr, st, cf)
checkpoint(sl - 250, cf)
ledge(cl + 600, cf - 110, 220)
ledge(cl + 1000, cf - 220, 220)
ledge(cl + 3000, cf - 110, 240)
ledge(cl + 3300, cf - 220, 220)
coin_row(cl + 920, cl + 1080, cf - 260, 3)
coin_row(cl + 3220, cl + 3380, cf - 260, 3)
enemy("smudge", cl + 1400, cf - 12)
enemy("inkwell", cl + 400, cf - 26)
enemy("crawler", cl + 3500, cf - 20)
lamp(cl + 1700, ct, 320, 200)
lamp(cl + 3100, ct, 300, 160)
pl, pt, pr, pf = px("pit")
ol, ot, orr, of = px("bottom")
steps(pl, pr, pt, of, 190)
heart(pl + 275, pt + 250)
checkpoint(ol + 700, of)
enemy("crossed", ol + 1300, of - 30)
enemy("scribble", ol + 1700, of - 330)
enemy("scribble", ol + 1900, of - 380)
lamp(ol + 1000, ot, 320, 260)
lamp(ol + 2500, ot, 320, 220)
coin_row(ol + 2300, ol + 2600, of - 40, 5)
node("Exit", "Area2D", "World", [("position", v(ol + 2750, of)), ("script", 'ExtResource("17_exit")'),
     ("target_scene", '"res://scenes/ui/main_menu.tscn"'), ("label", '"THE END OF THE DROP"')])

# 4. the lift: a girder that rides the shaft between the bottom room and the Archive
ll, lt, lr, lf = px("lift")
dl, dt, dr, df = px("lift_door")
node("Lift", "AnimatableBody2D", "World",
     [("position", v((ll + lr) / 2, lf - 10)), ("script", 'ExtResource("12_moving")'), ("size", v(lr - ll - 60, 20)),
      ("travel", v(0, -(lf - df) - 10)), ("period", "44")])
ledge((ll + lr) / 2, df, lr - ll)   # one-way cap: ride up through it, but no dropping down the shaft from the top

caption(START[0] + 260, START[1] - 190, "The way on is down.")
caption(px("tower")[0] + 1150, px("tower")[1] + 120, "Mind the drop.")
caption(ol + 2300, of - 220, "The lift goes back to the top.")

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
        '[node name="LevelMusic" type="Node" parent="."]', 'script = ExtResource("8_music")', 'track = "margins"', "",
        '[node name="LevelMood" type="Node" parent="."]', 'script = ExtResource("30_mood")', ""]
open(os.path.join(ROOT, "scenes/levels/long_drop.tscn"), "w").write("\n".join(out))
print(f"{len(world)} world nodes, {len(trims)} trims, {len(enemies)} enemies, {len(coins)} coins; start {START}")
