#!/usr/bin/env python3
"""Generates scenes/levels/test_level.tscn: the expanded test level.
Run from anywhere: python3 tools/level2d/build_test_level.py (re-running
overwrites hand edits to the scene).

Coordinates: main ground top = y 600 (the background is calibrated to it).
Up is negative y. Player body is 26x52 centred on its origin, so a player
standing on a surface at y=S has origin y=S-26. Max jump rise ~170 px; every
step below rises <= 120 px.
"""
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

ext = []      # (type, path, id)
nodes = []    # text blocks


def res(kind, path, rid):
    ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')


res("PackedScene", "res://scenes/player/player.tscn", "1_player")
res("PackedScene", "res://scenes/enemies/crawler.tscn", "2_crawler")
res("Script", "res://scripts/world/solid_block.gd", "3_block")
res("Script", "res://scripts/world/spikes.gd", "4_spikes")
res("Script", "res://scripts/ui/hud.gd", "5_hud")
res("PackedScene", "res://scenes/background/comic_background.tscn", "6_background")
res("Script", "res://scripts/world/goo_pool.gd", "7_goo")
res("Script", "res://scripts/audio/level_music.gd", "8_music")
res("Script", "res://scripts/world/coin.gd", "9_coin")
res("Script", "res://scripts/world/one_way_platform.gd", "11_oneway")
res("Script", "res://scripts/world/moving_platform.gd", "12_moving")
res("Script", "res://scripts/world/crumbling_platform.gd", "13_crumble")
res("Script", "res://scripts/world/spring_pad.gd", "14_spring")
res("Script", "res://scripts/world/building_block.gd", "15_building")
res("PackedScene", "res://scenes/enemies/scribble.tscn", "20_scribble")
res("PackedScene", "res://scenes/enemies/crumple.tscn", "21_crumple")
res("PackedScene", "res://scenes/enemies/crossed_out.tscn", "22_crossed")
res("PackedScene", "res://scenes/enemies/smudge.tscn", "23_smudge")
res("PackedScene", "res://scenes/enemies/inkwell.tscn", "24_inkwell")
res("PackedScene", "res://scenes/enemies/eraser.tscn", "25_eraser")
res("Script", "res://scripts/world/level_mood.gd", "30_mood")
res("Script", "res://scripts/world/checkpoint_pen.gd", "18_pen")
res("Script", "res://scripts/world/health_heart.gd", "19_heart")
res("Script", "res://scripts/world/level_exit.gd", "17_exit")
res("Script", "res://scripts/world/trapdoor.gd", "20_trapdoor")
res("Script", "res://scripts/world/lantern.gd", "40_lantern")
res("Script", "res://scripts/world/sketch_platform.gd", "41_sketch")
res("Script", "res://scripts/world/shadow_caster.gd", "42_caster")
res("Script", "res://scripts/world/caption.gd", "43_caption")


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


def block(x0, x1, top, bottom, script="3_block", name="Block", groups=None, extra=()):
    """Solid block spanning x0..x1, top..bottom (world y)."""
    node(uniq(name), "StaticBody2D", "World",
         [("position", v((x0 + x1) / 2, (top + bottom) / 2)), ("script", f'ExtResource("{script}")'),
          ("size", v(x1 - x0, bottom - top))] + list(extra), groups)


def plank(cx, top, w=160):
    node(uniq("Plank"), "StaticBody2D", "World",
         [("position", v(cx, top + 8)), ("script", 'ExtResource("11_oneway")'), ("size", v(w, 16))])


def crumble(cx, top, w=140):
    node(uniq("Crumble"), "StaticBody2D", "World",
         [("position", v(cx, top + 11)), ("script", 'ExtResource("13_crumble")'), ("size", v(w, 22))])


def girder(cx, top, travel, period=4.0, w=140, phase=0.0):
    node(uniq("Girder"), "AnimatableBody2D", "World",
         [("position", v(cx, top + 10)), ("script", 'ExtResource("12_moving")'), ("size", v(w, 20)),
          ("travel", v(*travel)), ("period", f"{period:g}"), ("phase", f"{phase:g}")])


def spring(x, surface):
    node(uniq("Spring"), "Area2D", "World", [("position", v(x, surface)), ("script", 'ExtResource("14_spring")')])


def light(x, y, r, surface=None):
    """A lantern whose lamp sits at (x, y). On a post down to `surface` if given."""
    props = [("position", v(x, y)), ("script", 'ExtResource("40_lantern")'), ("radius", f"{r:g}"), ("chain", "0"),
             ("casts_shadows", "false")]
    if surface is not None:
        props.append(("post", f"{surface - y:g}"))
    node(uniq("Lantern"), "Node2D", "World", props)


def lantern(x, y, r, chain=60, post=0, lit=True, shadows=True, swing=0, period=3.0):
    """Lantern hung by `chain` from the pivot (x, y); with `post` it stands on a post instead."""
    props = [("position", v(x, y)), ("script", 'ExtResource("40_lantern")'), ("radius", f"{r:g}"),
             ("chain", f"{chain:g}"), ("post", f"{post:g}"), ("lit", "true" if lit else "false"),
             ("casts_shadows", "true" if shadows else "false")]
    if swing:
        props += [("swing", f"{swing:g}"), ("swing_period", f"{period:g}")]
    node(uniq("Lantern"), "Node2D", "World", props)


def sketch(x0, x1, top, h=20, inkable=True):
    node(uniq("Sketch"), "StaticBody2D", "World",
         [("position", v((x0 + x1) / 2, top + h / 2)), ("script", 'ExtResource("41_sketch")'), ("size", v(x1 - x0, h)),
          ("inkable", "true" if inkable else "false")])


def caster(x, y, stick=0):
    node(uniq("Cutout"), "StaticBody2D", "World", [("position", v(x, y)), ("script", 'ExtResource("42_caster")'), ("stick", f"{stick:g}")])


def caption(x, y, text, tilt=-0.03):
    node(uniq("Caption"), "Node2D", "World", [("z_index", "5"), ("position", v(x, y)), ("script", 'ExtResource("43_caption")'),
         ("text", '"' + text.replace("\n", "\\n") + '"'), ("tilt", f"{tilt:g}")])


def spikes(x0, x1, floor):
    node(uniq("PitSpikes"), "StaticBody2D", "World", [("position", v((x0 + x1) / 2, floor - 12)), ("script", 'ExtResource("4_spikes")'), ("size", v(x1 - x0, 24))])


def enemy(kind, x, y, extra=()):
    rid = {"crawler": "2_crawler", "scribble": "20_scribble", "crumple": "21_crumple", "crossed": "22_crossed",
           "smudge": "23_smudge", "inkwell": "24_inkwell", "eraser": "25_eraser"}[kind]
    node(uniq(kind.capitalize()), None, "Enemies", [("position", v(x, y))] + list(extra), instance=rid)


coins = []


def coin_row(x0, x1, y, n):
    for i in range(n):
        coins.append((x0 + (x1 - x0) * (i / max(n - 1, 1)), y))


def checkpoint(x, floor_y):
    node(uniq("Checkpoint"), "Area2D", "World", [("position", v(x, floor_y)), ("script", 'ExtResource("18_pen")')])


def heart(x, y):
    node(uniq("Heart"), "Area2D", "World", [("position", v(x, y)), ("script", 'ExtResource("19_heart")')])


# ------------------------------------------------------------------ layout
GROUND = 600
BOTTOM = 1100
DX = 3600  # the light section (9) pushes the Eraser arena this far right
LEFT, RIGHT = -240, 9440 + DX

# --- ground: main run, a sunken valley, then the long stretch
block(LEFT, 3700, GROUND, BOTTOM, name="Ground")
block(3700, 4500, 760, BOTTOM, name="ValleyFloor")
block(4500, 8420, GROUND, BOTTOM, name="Ground")
block(11440, 9050 + DX, GROUND, BOTTOM, name="Ground")
block(9190 + DX, RIGHT, GROUND, BOTTOM, name="Ground")   # gap: the trapdoor shaft
block(LEFT, LEFT + 80, -1400, BOTTOM, name="Wall")       # world edges, tall enough for the tower
block(RIGHT - 80, RIGHT, -1400, BOTTOM, name="Wall")

# --- 1. start (the original tutorial layout)
block(400, 600, 458, 482, name="Platform")
block(680, 880, 348, 372, name="Platform")
block(970, 1230, 238, 262, name="Platform")
block(2120, 2280, 480, 600, name="Step")
node("Spikes1", "StaticBody2D", "World", [("position", v(1650, 588)), ("script", 'ExtResource("4_spikes")'), ("size", v(260, 24))])
node("GooPool1", "Area2D", "World", [("z_index", "1"), ("position", v(1330, 590)), ("script", 'ExtResource("7_goo")'), ("size", v(220, 20))])
coin_row(250, 400, 562, 4)
coin_row(470, 530, 430, 2)
coin_row(750, 810, 320, 2)
coins += [(1040, 210), (1100, 195), (1160, 210)]
coin_row(1250, 1360, 552, 3)
for i in range(5):
    t = i / 4
    coins.append((1560 + t * 180, 520 - 110 * math.sin(math.pi * t)))
coin_row(2170, 2230, 450, 2)
enemy("crawler", 1000, 580)
enemy("crawler", 1100, 222, [("start_direction", "1")])
enemy("crawler", 1950, 580)

# --- 2. scaffold swarm: plank tiers, Scribbles circling, light on top = safe spot
plank(2600, 490, 180)
plank(2850, 380, 180)
plank(3100, 270, 200)
plank(3360, 380, 180)
plank(3560, 490, 160)
light(3100, 200, 120, surface=270)
coin_row(2560, 2640, 452, 2)
coin_row(2810, 2890, 342, 2)
coin_row(3060, 3140, 232, 3)
coin_row(3320, 3400, 342, 2)
enemy("scribble", 2800, 260)
enemy("scribble", 2950, 200)
enemy("scribble", 3300, 240)

# --- 3. crumple valley: walls daze it, a light pool unfolds it, spring out
light(3820, 735, 95, surface=760)
enemy("crumple", 4150, 735)
spring(4440, 760)
coin_row(3900, 4300, 722, 5)

# --- 4. the tower: climb ~1160 px next to the skyscraper
plank(4800, 490, 160)
plank(5030, 380, 160)
block(5200, 5400, 280, 304, name="Ledge")
girder(5040, 170, (0, -320), period=5.0, w=130)            # elevator
crumble(4790, -250, 150)
plank(5020, -350, 160)
block(5190, 5410, -440, -416, name="Ledge")
enemy("inkwell", 5330, -466)                               # lobs ink down the shaft
coin_row(4760, 4840, 452, 2)
coin_row(5260, 5340, 242, 2)
coins += [(5040, 60), (5040, -40), (4790, -290), (5020, -390)]

# --- 5. rooftop of the skyscraper
block(5500, 6900, -560, BOTTOM, script="15_building", name="Skyscraper")
block(5900, 5980, -610, -560, name="ACUnit")
block(6420, 6520, -620, -560, name="ACUnit")
light(6250, -600, 85, surface=-560)
enemy("crossed", 6150, -590)
enemy("crawler", 6700, -580)
coin_row(5560, 5840, -600, 4)
coins += [(5940, -650), (6470, -660)]
coin_row(6560, 6840, -600, 4)

# --- 6. the descent: planks and crumbling slabs back down
plank(7020, -420, 150)
crumble(7200, -280, 140)
plank(7040, -140, 150)
crumble(7230, 0, 140)
plank(7060, 150, 150)
plank(7240, 300, 150)
plank(7080, 450, 150)
coins += [(7020, -460), (7200, -320), (7040, -180), (7230, -40), (7060, 110), (7240, 260)]

# --- 7. smudge plaza, then a girder ride over a spike pit
light(7620, 570, 95, surface=600)
enemy("smudge", 7500, 588)
node("Spikes2", "StaticBody2D", "World", [("position", v(8000, 588)), ("script", 'ExtResource("4_spikes")'), ("size", v(400, 24))])
block(7760, 7800, 540, 600, name="PitEdge")
block(8200, 8240, 540, 600, name="PitEdge")
girder(7850, 480, (300, 0), period=4.5, w=140)
coin_row(7880, 8120, 440, 4)

# --- 9. the Sketchbook: the light mechanic (scripts/world/lights.gd)
# Pencil sketches are only solid in light. Each beat teaches one rule, then
# leans on it: the Ember costs meter, ink is the way to rest, lanterns are
# free light that walls can shadow, and a lit cut-out's shadow is solid ink.
block(8300, 8340, 480, GROUND, name="Gate")              # end of the smudge plaza
# 9a. first light: a sketch bridge over spikes, too wide to jump (~470 px max)
caption(8680, 420, "HOLD Q - RAISE YOUR EMBER\nLIGHT MAKES THE SKETCH REAL")
block(8420, 8940, 800, BOTTOM, name="PitFloor")
spikes(8420, 8940, 800)
sketch(8420, 8940, GROUND)
coin_row(8500, 8860, 560, 5)
block(8940, 9260, GROUND, BOTTOM, name="Ground")
# 9b. ink a stepping stone: 1400 px is more than one Ember (100 meter at 25/s
# = 4 s = 1200 px of running). Stop halfway, stand still to ink, rest on it.
# Scribbles flee your light, so they dive the moment you lower it.
caption(9560, 400, "TOO FAR FOR ONE EMBER?\nSTAND STILL WITH IT RAISED: THE SKETCH INKS IN.\nINK STAYS. REST ON IT.")
block(9260, 10660, 800, BOTTOM, name="PitFloor")
spikes(9260, 10660, 800)
sketch(9260, 10660, GROUND)
coin_row(9900, 10020, 560, 3)
enemy("scribble", 9800, 380)
enemy("scribble", 10150, 340)
block(10660, 10900, GROUND, BOTTOM, name="Ground")
enemy("crossed", 10820, 570)                             # its X only burns in light
# 9c. lanterns: free light that refills the Ember, but a sign shadows the far end
caption(10990, 440, "LANTERNS ARE FREE LIGHT.\nSHADOWS ARE NOT.", tilt=0.03)
block(10900, 11440, 800, BOTTOM, name="PitFloor")
spikes(10900, 11440, 800)
sketch(10900, 11440, GROUND)
lantern(11160, 220, 400, chain=120)                      # lamp at (11160, 340)
block(11215, 11278, 440, 462, name="Sign")                # shadows x 11300-11440 of the bridge
# 9d. shadow ink: hit the lantern, the cut-out star's shadow is a ramp over the wall
caption(11470, 360, "HIT THE LANTERN.\nA SHADOW IS INK TOO.")
lantern(11550, 520, 220, chain=0, post=80, lit=False)
caster(11640, 470, stick=130)
block(11800, 11860, 270, GROUND, name="Wall")
coins += [(11720, 380), (11760, 350)]

# --- 8. eraser arena: three erasable platforms (moved right by DX)
for x, top in [(8600, 458), (8860, 388), (9120, 458)]:
    block(x + DX - 100, x + DX + 100, top, top + 24, name="Erasable", groups=["erasable"])
enemy("eraser", 8900 + DX, 564)
coin_row(8560 + DX, 8640 + DX, 420, 2)
coin_row(8820 + DX, 8900 + DX, 350, 2)
coin_row(9080 + DX, 9160 + DX, 420, 2)
# the way out of the comic panel: chained until the Eraser is beaten
node("Trapdoor", "StaticBody2D", "World", [("position", v(9120 + DX, 609)), ("script", 'ExtResource("20_trapdoor")'),
     ("guardian", 'NodePath("../../Enemies/Eraser1")')])

# --- checkpoints (cute pens) and health hearts
for x, fy in [(2420, 600), (4600, 600), (5560, -560), (7250, 600), (8250, 600), (10780, 600), (11480, 600), (11950, 600)]:
    checkpoint(x, fy)
for x, y in [(3360, 340), (4300, 715), (5370, 245), (6080, -600), (7080, 410), (10720, 560), (11980, 560)]:
    heart(x, y)

# ------------------------------------------------------------------ write
out = ["[gd_scene format=3]", ""] + ext + ["", '[node name="TestLevel" type="Node2D"]', "",
       '[node name="ComicBackground" parent="." instance=ExtResource("6_background")]', "",
       '[node name="World" type="Node2D" parent="."]', ""]
world = [n for n in nodes if 'parent="World"' in n]
enemies = [n for n in nodes if 'parent="Enemies"' in n]
out += ["\n\n".join(world), "", '[node name="Coins" type="Node2D" parent="."]', ""]
for i, (x, y) in enumerate(coins, 1):
    out += [f'[node name="Coin{i}" type="Area2D" parent="Coins"]', f"position = {v(round(x), round(y))}",
            'script = ExtResource("9_coin")', ""]
out += ['[node name="Enemies" type="Node2D" parent="."]', "", "\n\n".join(enemies), "",
        '[node name="Player" parent="." instance=ExtResource("1_player")]', "position = Vector2(100, 570)", "",
        '[node name="UI" type="CanvasLayer" parent="."]', "layer = 2", "",
        '[node name="HUD" type="Control" parent="UI"]', "layout_mode = 3", "anchors_preset = 15",
        "anchor_right = 1.0", "anchor_bottom = 1.0", "grow_horizontal = 2", "grow_vertical = 2",
        "mouse_filter = 2", 'script = ExtResource("5_hud")', "",
        '[node name="LevelMusic" type="Node" parent="."]', 'script = ExtResource("8_music")', "",
        '[node name="LevelMood" type="Node" parent="."]', 'script = ExtResource("30_mood")', ""]
open(os.path.join(ROOT, "scenes/levels/test_level.tscn"), "w").write("\n".join(out))
print(f"{len(world)} world nodes, {len(enemies)} enemies, {len(coins)} coins")
