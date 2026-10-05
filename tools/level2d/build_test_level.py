#!/usr/bin/env python3
"""Generates two 2D levels (re-running overwrites hand edits to both):
  scenes/levels/test_level.tscn  THE CITY: the short controls tutorial
  scenes/levels/sketchbook.tscn  THE SKETCHBOOK: the light tutorial
Each ends at a glowing panel door (scripts/world/panel_door.gd) to the next.
Run from anywhere: python3 tools/level2d/build_test_level.py

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
res("Script", "res://scripts/world/panel_door.gd", "44_door")
res("Script", "res://scripts/ui/comic_frame.gd", "45_frame")
res("Script", "res://scripts/ui/narration.gd", "46_narration")


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


def sketch(x0, x1, top, h=20, inkable=True, drinks=False):
    node(uniq("Sketch"), "StaticBody2D", "World",
         [("position", v((x0 + x1) / 2, top + h / 2)), ("script", 'ExtResource("41_sketch")'), ("size", v(x1 - x0, h)),
          ("inkable", "true" if inkable else "false"), ("drinks_light", "true" if drinks else "false")])


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


# ------------------------------------------------------------------ helpers
GROUND = 600
BOTTOM = 1100


def door(x, target, title, tall=False):
    props = [("position", v(x, GROUND)), ("script", 'ExtResource("44_door")'),
             ("target_scene", f'"{target}"'), ("next_title", f'"{title}"')]
    if tall:  # a vertical level: its panel on the page is tall
        props.append(("tall_panel", "true"))
    node("PanelDoor", "Area2D", "World", props)


def reset():
    nodes.clear()
    coins.clear()
    counts.clear()


def rects(rs):
    return "Array[Rect2]([" + ", ".join(f"Rect2({x0:g}, {y0:g}, {x1 - x0:g}, {y1 - y0:g})" for x0, y0, x1, y1 in rs) + "])"


def write(path, root, player_pos, page=1, story=(), live=()):
    """story: the Writer's captions, [(text, trigger_x)] in order (-1e9 = on arrival)."""
    out = ["[gd_scene format=3]", ""] + ext + ["", f'[node name="{root}" type="Node2D"]', "",
           '[node name="ComicBackground" parent="." instance=ExtResource("6_background")]', "",
           '[node name="World" type="Node2D" parent="."]', ""]
    world = [n for n in nodes if 'parent="World"' in n]
    enemies = [n for n in nodes if 'parent="Enemies"' in n]
    out += ["\n\n".join(world), "", '[node name="Coins" type="Node2D" parent="."]', ""]
    for i, (x, y) in enumerate(coins, 1):
        out += [f'[node name="Coin{i}" type="Area2D" parent="Coins"]', f"position = {v(round(x), round(y))}",
                'script = ExtResource("9_coin")', ""]
    out += ['[node name="Enemies" type="Node2D" parent="."]', "", "\n\n".join(enemies), "",
            '[node name="Player" parent="." instance=ExtResource("1_player")]', f"position = {v(*player_pos)}", "",
            '[node name="UI" type="CanvasLayer" parent="."]', "layer = 2", "",
            '[node name="HUD" type="Control" parent="UI"]', "layout_mode = 3", "anchors_preset = 15",
            "anchor_right = 1.0", "anchor_bottom = 1.0", "grow_horizontal = 2", "grow_vertical = 2",
            "mouse_filter = 2", 'script = ExtResource("5_hud")', "",
            '[node name="LevelMusic" type="Node" parent="."]', 'script = ExtResource("8_music")', "",
            '[node name="LevelMood" type="Node" parent="."]', 'script = ExtResource("30_mood")', "",
            '[node name="ComicFrame" type="CanvasLayer" parent="."]', 'script = ExtResource("45_frame")', f"page_number = {page}",
            f"live_areas = {rects(live)}", ""]
    for k, (text, x) in enumerate(story):
        out += [f'[node name="Narration{k + 1}" type="CanvasLayer" parent="."]', 'script = ExtResource("46_narration")',
                f'text = "{text}"', f"trigger_x = {x:g}", ""]
    open(os.path.join(ROOT, path), "w").write("\n".join(out))
    print(f"{path}: {len(world)} world nodes, {len(enemies)} enemies, {len(coins)} coins")


# ======================================================== THE CITY (controls tutorial)
# Just enough to learn the controls (the on-screen tutorial, scripts/ui/tutorial.gd,
# shows each key): walk, jump up a few rooftops, slash a Crawler, clear a spike
# strip, jump or dash a spike pit, jump up through planks past a Scribble, then
# the panel door. About a minute and a half.
reset()
block(-240, 820, GROUND, BOTTOM, name="Ground")
block(-240, -160, -600, BOTTOM, name="Wall")
# jump: a step and two rooftops
block(560, 760, 500, GROUND, name="Step")
block(860, 1060, 400, 424, name="Platform")
block(1160, 1360, 470, 494, name="Platform")
coin_row(610, 710, 462, 2)
coin_row(910, 1010, 362, 3)
# attack: a Crawler on open ground
block(820, 2380, GROUND, BOTTOM, name="Ground")
enemy("crawler", 1700, 580)
coin_row(1500, 1600, 560, 2)
# a spike strip: hop it (or pogo off it with a down slash)
node("Spikes1", "StaticBody2D", "World", [("position", v(2050, 588)), ("script", 'ExtResource("4_spikes")'), ("size", v(160, 24))])
coins += [(1980, 480), (2050, 450), (2120, 480)]
checkpoint(2300, GROUND)
# dash: a 300 px spike pit, too wide to just jump (~260 px); a dash or double jump clears it
block(2380, 2680, 800, BOTTOM, name="PitFloor")
spikes(2380, 2680, 800)
coin_row(2440, 2620, 520, 3)
block(2680, 3700, GROUND, BOTTOM, name="Ground")
# jump up through planks, a Scribble circling them
plank(2980, 490, 180)
plank(3220, 390, 180)
plank(3460, 490, 160)
enemy("scribble", 3220, 300)
caption(2560, 360, "OUT OF REACH?\nHOLD ATTACK, THEN LET GO:\nINK FLIES FURTHER THAN A SWORD.")
coin_row(2940, 3020, 452, 2)
coin_row(3180, 3260, 352, 3)
heart(3220, 350)
# the way on
door(3600, "res://scenes/levels/sketchbook.tscn", "THE SKETCHBOOK")
block(3700, 3780, -600, BOTTOM, name="Wall")
write("scenes/levels/test_level.tscn", "TestLevel", (100, 570), page=1, story=[
    ("VESPER STARTS OUT IN A CITY INFECTED BY EVIL MONSTERS. HE FIGHTS THEM OFF WITH THE LIGHT AND HIS SWORD.", -1e9),
    ("THESE MONSTERS HAD INFESTED EVERY STREET OF THE CITY. ONE SWING OF THE SWORD SENT THEM SCATTERING.", 1350),
    ("THE CITY WAS COMING APART, ONE PANEL AT A TIME. WHERE THE STREET BROKE, VESPER LEAPT.", 2250),
    ("AND AT THE EDGE OF THE PAGE, A DOOR OF LIGHT WAS WAITING.", 3150),
], live=[(-240, -1200, 3780, 660), (2380, 590, 2680, 812)])

# ======================================================== THE SKETCHBOOK (light tutorial)
# Pencil sketches are only solid in light (scripts/world/lights.gd). Each beat
# teaches one rule, then leans on it: the Ember costs meter, ink is the way to
# rest, lanterns are free light that walls can shadow, and a lit cut-out's
# shadow is solid ink.
reset()
block(7900, 8420, GROUND, BOTTOM, name="Ground")
block(7820, 7900, -600, BOTTOM, name="Wall")
# 9a. first light: a sketch bridge over spikes, too wide to jump (~470 px max)
caption(8680, 455, "HOLD Q - RAISE YOUR EMBER\nLIGHT MAKES THE SKETCH REAL")
block(8420, 8940, 800, BOTTOM, name="PitFloor")
spikes(8420, 8940, 800)
sketch(8420, 8940, GROUND)
coin_row(8500, 8860, 560, 5)
block(8940, 9260, GROUND, BOTTOM, name="Ground")
# 9b. the Blue Gap: grey pencil (inkable), an open gap, then non-photo blue
# that drinks the light (the Ember drains 2x over it, ember.gd). Straight
# across is more than one Ember: stop at the end of the grey,
# ink yourself a ledge, rest on it until the Ember is full, then jump the gap
# and sprint the blue (~85 meter) while the Scribbles circle.
caption(9470, 445, "TOO FAR FOR ONE EMBER?\nSTAND STILL WITH IT RAISED: INK SPREADS FROM YOUR FEET.\nINK STAYS. REST ON IT.")
block(9260, 10700, 800, BOTTOM, name="PitFloor")
spikes(9260, 10700, 800)
sketch(9260, 10040, GROUND)
sketch(10190, 10700, GROUND, inkable=False, drinks=True)
caption(10445, 470, "BLUE PENCIL NEVER TAKES INK.\nIT DRINKS YOUR LIGHT.", tilt=0.03)
coin_row(10080, 10150, 540, 2)
enemy("scribble", 9850, 360)
enemy("scribble", 10500, 340)
block(10700, 10940, GROUND, BOTTOM, name="Ground")
enemy("crossed", 10860, 570)                             # its X only burns in light
# 9c. lanterns: free light that refills the Ember, but a sign shadows the far end
caption(11030, 470, "LANTERNS ARE FREE LIGHT.\nSHADOWS ARE NOT.", tilt=0.03)
block(10940, 11480, 800, BOTTOM, name="PitFloor")
spikes(10940, 11480, 800)
sketch(10940, 11480, GROUND)
lantern(11200, 220, 400, chain=120)                      # lamp at (11200, 340)
block(11255, 11318, 440, 462, name="Sign")                # shadows x 11340-11480 of the bridge
# 9d. shadow ink: hit the lantern, the cut-out star's shadow is a ramp over the wall
caption(11510, 385, "HIT THE LANTERN.\nA SHADOW IS INK TOO.")
block(11480, 12540, GROUND, BOTTOM, name="Ground")
lantern(11590, 520, 220, chain=0, post=80, lit=False)
caster(11680, 470, stick=130)
block(11840, 11900, 270, GROUND, name="Wall")
coins += [(11760, 380), (11800, 350)]
for x in [8250, 10820, 11520]:
    checkpoint(x, GROUND)
heart(10760, 560)
# over the wall: the way on, down the Long Drop
door(12300, "res://scenes/levels/long_drop.tscn", "THE LONG DROP", tall=True)
block(12540, 12620, -600, BOTTOM, name="Wall")
write("scenes/levels/sketchbook.tscn", "Sketchbook", (8100, 570), page=2, story=[
    ("PAST THE CITY, THE WORLD WAS STILL A SKETCH: PENCIL LINES THAT ONLY TURNED REAL IN THE LIGHT.", -1e9),
    ("SOME BRIDGES WERE TOO LONG FOR ONE BREATH OF LIGHT. SO VESPER STOPPED, AND LET THE INK SET.", 9100),
    ("THE OLD LANTERNS STILL REMEMBERED HOW TO SHINE. BUT LIGHT CASTS SHADOWS.", 10840),
    ("AND BELOW THE LAST PAGE OF THE SKETCHBOOK, THE WORLD DROPPED AWAY INTO THE DARK...", 11940),
], live=[(7820, -1200, 12620, 660), (8420, 590, 8940, 812), (9260, 590, 10700, 812), (10940, 590, 11480, 812)])
