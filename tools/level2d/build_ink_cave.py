#!/usr/bin/env python3
"""Generates scenes/levels/ink_cave.tscn: the Ink Cave, where Shade's trap
(shade_trap.gd, at the end of Shade's City) drops Vesper. Run from anywhere:
python3 tools/level2d/build_ink_cave.py (re-running overwrites hand edits).

A short cave, left to right, in front of the live ink-fire painting
(cave_backdrop.gd):
  1. the fall      Vesper drops in from the trap (hard landing)
  2. bats          ink bats roost under the overhangs and swoop (ink_bat.gd)
  3. spiders       three paper spiders, two hanging from the rock
  4. the pit       two Ink Blots at once (cave_arena.gd); when both melt the
                   cave breaks apart and throws Vesper back to Shade's city

Floor top is y = 600 (the player stands at 574). x grows to the right.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "levels", "ink_cave.tscn")
FLOOR = 600

ext = []
nodes = []
count = {}


def res(kind, path):
    rid = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
    ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
    return rid


def v(x, y):
    return f"Vector2({x}, {y})"


def node(name, kind, parent, props=(), instance=None):
    head = f'[node name="{name}"'
    if kind:
        head += f' type="{kind}"'
    head += f' parent="{parent}"' if parent else ""
    if instance:
        head += f' instance=ExtResource("{instance}")'
    lines = [head + "]"]
    for k, val in props:
        lines.append(f"{k} = {val}")
    nodes.append("\n".join(lines))


def uniq(base):
    count[base] = count.get(base, 0) + 1
    return f"{base}{count[base]}"


PLAYER = res("PackedScene", "res://scenes/player/player.tscn")
SPIDER = res("PackedScene", "res://scenes/enemies/paper_spider.tscn")
BAT = res("PackedScene", "res://scenes/enemies/ink_bat.tscn")
BLOT = res("PackedScene", "res://scenes/enemies/ink_blot.tscn")
BACKDROP = res("Script", "res://scripts/background/cave_backdrop.gd")
ROCK = res("Script", "res://scripts/world/cave_rock.gd")
ARENA = res("Script", "res://scripts/world/cave_arena.gd")
PEN = res("Script", "res://scripts/world/checkpoint_pen.gd")
HEART = res("Script", "res://scripts/world/health_heart.gd")
COIN = res("Script", "res://scripts/world/coin.gd")
HUD = res("Script", "res://scripts/ui/hud.gd")
BOSSBAR = res("Script", "res://scripts/ui/boss_bar.gd")
MUSIC = res("Script", "res://scripts/audio/level_music.gd")
MOOD = res("Script", "res://scripts/world/level_mood.gd")
FRAME = res("Script", "res://scripts/ui/comic_frame.gd")
NARR = res("Script", "res://scripts/ui/narration.gd")

node("InkCave", "Node2D", None)
node("Backdrop", "Node2D", ".", [("script", f'ExtResource("{BACKDROP}")')])
node("World", "Node2D", ".")
node("Enemies", "Node2D", ".")
node("Coins", "Node2D", ".")


def rock(x, y, w, h, one_way=False, ground=False):
    props = [("position", v(x, y)), ("script", f'ExtResource("{ROCK}")'), ("size", v(w, h))]
    if one_way:
        props.append(("one_way", "true"))
    if ground:
        props.append(("ground", "true"))
    node(uniq("Rock"), "StaticBody2D", "World", props)


def overhang(x, y, w):
    """A rock shelf high up: bats and spiders hang under it."""
    rock(x, y, w, 70, one_way=True)
    return y + 50  # roughly the shelf's underside


def bat(x, y):
    node(uniq("Bat"), None, "Enemies", [("position", v(x, y))], instance=BAT)


def spider(x, hang=0.0):
    props = [("position", v(x, FLOOR - 33))]
    if hang:
        props.append(("hang_height", str(hang)))
    node(uniq("Spider"), None, "Enemies", props, instance=SPIDER)


def blot(name, x):
    node(name, None, "Enemies", [("position", v(x, FLOOR - 75)), ("hp", "10"), ("swipe_damage", "1.5"), ("slam_damage", "2.25"),
         ("display_name", f'"{"THE INK BLOT" if name.endswith("A") else "ITS TWIN"}"')], instance=BLOT)


def coins(x0, y, n, gap=48):
    for i in range(n):
        node(uniq("Coin"), "Area2D", "Coins", [("position", v(x0 + i * gap, y)), ("script", f'ExtResource("{COIN}")')])


def pen(x):
    node(uniq("Checkpoint"), "Area2D", "World", [("position", v(x, FLOOR)), ("script", f'ExtResource("{PEN}")')])


def heart(x, y):
    node(uniq("Heart"), "Area2D", "World", [("position", v(x, y)), ("script", f'ExtResource("{HEART}")')])


def narration(text, x, speaker="narrator"):
    """A caption panel (narration.gd): the comic's narration, or "vesper" (yellow) / "shade" (red) talking."""
    props = [("script", f'ExtResource("{NARR}")'), ("text", f'"{text}"'), ("trigger_x", str(x))]
    if speaker != "narrator":
        props.append(("speaker", f'"{speaker}"'))
    node(uniq("Narration"), "CanvasLayer", ".", props)


# the cave floor and its ends
rock(-600, FLOOR, 5400, 500, ground=True)
rock(-700, -1400, 100, 2100)
rock(4600, -1400, 100, 2100)

# 1. the fall: Vesper drops in, a couple of ledges
rock(620, 470, 200, 40, one_way=True)
coins(650, 430, 3)

# 2. bats under the overhangs
under = overhang(900, 210, 300)
bat(980, under)
bat(1110, under)
rock(1250, 450, 180, 40, one_way=True)
under = overhang(1500, 190, 280)
bat(1600, under)
coins(1530, 150, 4)
rock(1700, 470, 160, 40, one_way=True)

# 3. spiders
under = overhang(1950, 230, 260)
spider(2060, hang=FLOOR - under - 60)
spider(2300)
rock(2380, 460, 180, 40, one_way=True)
coins(2400, 420, 3)
under = overhang(2560, 220, 220)
spider(2650, hang=FLOOR - under - 60)
bat(2600, under)
pen(2840)
heart(2900, 560)

# 4. the pit: two Ink Blots at once
rock(3420, 430, 240, 40, one_way=True)  # a ledge to dodge the slams from
blot("InkBlotA", 3250)
blot("InkBlotB", 3900)
node("CaveArena", "Node2D", "World", [("script", f'ExtResource("{ARENA}")'),
     ("blot_paths", 'Array[NodePath]([NodePath("../../Enemies/InkBlotA"), NodePath("../../Enemies/InkBlotB")])'),
     ("backdrop_path", 'NodePath("../../Backdrop")'),
     ("trigger_x", "3100.0"), ("left_x", "2980.0"), ("right_x", "4280.0"), ("floor_y", f"{FLOOR}.0"),
     ("next_scene", '"res://scenes/levels/shade_finale.tscn"')])

# Vesper falls in out of Shade's trap: a hard landing (500 px), not a damaging one
node("Player", None, ".", [("position", v(260, FLOOR - 26 - 500))], instance=PLAYER)
node("Camera2D", None, "Player", [("framing_offset", v(0, -226))])

node("UI", "CanvasLayer", ".", [("layer", "2")])
node("HUD", "Control", "UI", [("layout_mode", "3"), ("anchors_preset", "15"), ("anchor_right", "1.0"),
     ("anchor_bottom", "1.0"), ("grow_horizontal", "2"), ("grow_vertical", "2"), ("mouse_filter", "2"),
     ("script", f'ExtResource("{HUD}")')])
node("BossBar", "Control", "UI", [("layout_mode", "3"), ("anchors_preset", "15"), ("anchor_right", "1.0"),
     ("anchor_bottom", "1.0"), ("mouse_filter", "2"), ("script", f'ExtResource("{BOSSBAR}")')])
node("LevelMusic", "Node", ".", [("script", f'ExtResource("{MUSIC}")'), ("track", '"inkcave"'), ("fade", "2.5")])  # cut from the Orsted theme (music.gd), crossfaded in
node("LevelMood", "Node", ".", [("script", f'ExtResource("{MOOD}")')])
node("ComicFrame", "CanvasLayer", ".", [("script", f'ExtResource("{FRAME}")'), ("page_number", "8"),
     ("live_areas", "Array[Rect2]([Rect2(-800, -2000, 5600, 3200)])")])

narration("SHADE'S TRAP. VESPER FALLS INTO A CAVE WHERE THE INK BURNS.", -1e9)
narration("SOMETHING'S ROOSTING UP THERE...", 800, "vesper")
narration("I CAN DRAW FASTER THAN YOU CAN CUT, VESPER.", 1850, "shade")
narration("TWO OF THEM? HE'S GETTING DESPERATE.", 3000, "vesper")

with open(OUT, "w") as f:
    f.write(f"[gd_scene load_steps={len(ext) + 1} format=3]\n\n")
    f.write("\n".join(ext) + "\n\n")
    f.write("\n\n".join(nodes) + "\n")
print("wrote", OUT)
