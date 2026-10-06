#!/usr/bin/env python3
"""Generates scenes/levels/shades_city.tscn: Shade's corrupted comic city
(Act 3, back in 2D). Run from anywhere: python3 tools/level2d/build_shades_city.py
(re-running overwrites hand edits to the scene).

One street, left to right, in front of the concept painting (city_painting.gd):
  1. arrival      Vesper is dropped in from the sky (hard landing), a few stacks
  2. spiders      the first paper spider drops on its thread, then two more
  3. the light    the author's light sweeps the street (author_light.gd); hide
                  under awnings / scaffold / the billboard (light_cover.gd)
  4. the gate     the sleeping Ink Blot (gate_arena.gd): walls rise, beat it,
                  get health back, walk through the gate... into Shade's trap

Street top is y = 600 (the player stands at 574). x grows to the right.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "levels", "shades_city.tscn")
STREET = 600

ext = []
nodes = []
ids = {}


def res(kind, path):
    rid = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
    ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
    ids[path] = rid
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


count = {}


def uniq(base):
    count[base] = count.get(base, 0) + 1
    return f"{base}{count[base]}"


PLAYER = res("PackedScene", "res://scenes/player/player.tscn")
SPIDER = res("PackedScene", "res://scenes/enemies/paper_spider.tscn")
BLOT = res("PackedScene", "res://scenes/enemies/ink_blot.tscn")
BACKDROP = res("Script", "res://scripts/background/city_painting.gd")
STREETS = res("Script", "res://scripts/world/street_ground.gd")
WALLS = res("Script", "res://scripts/world/city_block.gd")
COVER = res("Script", "res://scripts/world/light_cover.gd")
STACK = res("Script", "res://scripts/world/paper_stack.gd")
LIGHT = res("Script", "res://scripts/world/author_light.gd")
ARENA = res("Script", "res://scripts/world/gate_arena.gd")
PEN = res("Script", "res://scripts/world/checkpoint_pen.gd")
HEART = res("Script", "res://scripts/world/health_heart.gd")
COIN = res("Script", "res://scripts/world/coin.gd")
HUD = res("Script", "res://scripts/ui/hud.gd")
BOSSBAR = res("Script", "res://scripts/ui/boss_bar.gd")
MUSIC = res("Script", "res://scripts/audio/level_music.gd")
MOOD = res("Script", "res://scripts/world/level_mood.gd")
FRAME = res("Script", "res://scripts/ui/comic_frame.gd")
NARR = res("Script", "res://scripts/ui/narration.gd")

node("ShadesCity", "Node2D", None)
node("Backdrop", "Node2D", ".", [("script", f'ExtResource("{BACKDROP}")')])
node("World", "Node2D", ".")
node("Enemies", "Node2D", ".")
node("Coins", "Node2D", ".")


def block(name, x, y, w, h):
    node(name, "StaticBody2D", "World", [("position", v(x, y)), ("script", f'ExtResource("{STREETS}")'), ("size", v(w, h))])


def wall(name, x, y, w, h):
    """An end wall: a tall neon-edged building (city_block.gd, centred), in Shade's pink."""
    node(name, "StaticBody2D", "World", [("position", v(x + w / 2, y + h / 2)), ("script", f'ExtResource("{WALLS}")'),
         ("size", v(w, h)), ("trim", "Color(1, 0.36, 0.66, 1)"), ("accent", "Color(0.4, 0.85, 1, 1)")])


def stack(x, w, h):
    node(uniq("Stack"), "StaticBody2D", "World", [("position", v(x, STREET)), ("script", f'ExtResource("{STACK}")'), ("size", v(w, h))])


def cover(kind, x, y, w, h=22):
    # kinds: 0 awning, 1 scaffold, 2 billboard, 3 bar (no posts)
    node(uniq("Cover"), "StaticBody2D", "World", [("position", v(x, y)), ("script", f'ExtResource("{COVER}")'),
         ("kind", str(kind)), ("size", v(w, h)), ("post_height", str(STREET - y - h))])


def spider(x, hang=0.0):
    props = [("position", v(x, STREET - 33))]
    if hang:
        props.append(("hang_height", str(hang)))
    node(uniq("Spider"), None, "Enemies", props, instance=SPIDER)


def coins(x0, y, n, gap=48):
    for i in range(n):
        node(uniq("Coin"), "Area2D", "Coins", [("position", v(x0 + i * gap, y)), ("script", f'ExtResource("{COIN}")')])


def pen(x):
    node(uniq("Checkpoint"), "Area2D", "World", [("position", v(x, STREET)), ("script", f'ExtResource("{PEN}")')])


def heart(x, y):
    node(uniq("Heart"), "Area2D", "World", [("position", v(x, y)), ("script", f'ExtResource("{HEART}")')])


def narration(text, x, speaker="narrator"):
    """A caption panel (narration.gd): the comic's narration, or "vesper" (yellow) / "shade" (red) talking."""
    props = [("script", f'ExtResource("{NARR}")'), ("text", f'"{text}"'), ("trigger_x", str(x))]
    if speaker != "narrator":
        props.append(("speaker", f'"{speaker}"'))
    node(uniq("Narration"), "CanvasLayer", ".", props)


# the street and its ends
block("Street", -600, STREET, 8000, 500)
wall("WallLeft", -660, -1400, 60, 2100)
wall("WallRight", 7340, -1400, 60, 2100)

# 1. arrival: dropped from the sky, a few stacks to hop
stack(700, 120, 70)
stack(860, 120, 140)
cover(3, 1030, 430, 190)
coins(1060, 390, 3)
stack(1320, 150, 90)

# 2. spiders
spider(1850, hang=300)
stack(2150, 110, 60)
cover(3, 2330, 450, 220)
coins(2370, 410, 4)
spider(2600)
spider(2860, hang=280)
pen(3060)

# 3. the author's light: hide from cover to cover
node("AuthorLight", "Node2D", "World", [("script", f'ExtResource("{LIGHT}")'), ("zone_from", "3250.0"),
     ("zone_to", "5560.0"), ("street_y", f"{STREET}.0")])
cover(0, 3460, 452, 220)
cover(0, 3900, 452, 200)
stack(4120, 100, 60)
spider(4180)
cover(1, 4360, 440, 280)
spider(4700)
cover(0, 4880, 452, 220)
cover(2, 5240, 430, 400)
pen(5440)
heart(5530, 560)

# 4. the gate and its keeper
node("InkBlot", None, "Enemies", [("position", v(6450, STREET - 75))], instance=BLOT)
node("GateArena", "Node2D", "World", [("script", f'ExtResource("{ARENA}")'), ("blot_path", 'NodePath("../../Enemies/InkBlot")'),
     ("trigger_x", "5960.0"), ("left_x", "5800.0"), ("right_x", "7000.0"), ("gate_x", "6830.0"),
     ("street_y", f"{STREET}.0"), ("next_scene", '"res://scenes/levels/ink_cave.tscn"')])

# Vesper falls in from above: a hard landing (500 px), not a damaging one
node("Player", None, ".", [("position", v(300, STREET - 26 - 500))], instance=PLAYER)
node("Camera2D", None, "Player", [("framing_offset", v(0, -226))])

node("UI", "CanvasLayer", ".", [("layer", "2")])
node("HUD", "Control", "UI", [("layout_mode", "3"), ("anchors_preset", "15"), ("anchor_right", "1.0"),
     ("anchor_bottom", "1.0"), ("grow_horizontal", "2"), ("grow_vertical", "2"), ("mouse_filter", "2"),
     ("script", f'ExtResource("{HUD}")')])
node("BossBar", "Control", "UI", [("layout_mode", "3"), ("anchors_preset", "15"), ("anchor_right", "1.0"),
     ("anchor_bottom", "1.0"), ("mouse_filter", "2"), ("script", f'ExtResource("{BOSSBAR}")')])
node("LevelMusic", "Node", ".", [("script", f'ExtResource("{MUSIC}")')])
node("LevelMood", "Node", ".", [("script", f'ExtResource("{MOOD}")')])
node("ComicFrame", "CanvasLayer", ".", [("script", f'ExtResource("{FRAME}")'), ("page_number", "7"),
     ("live_areas", "Array[Rect2]([Rect2(-660, -2000, 8060, 3200)])")])

# the story (narration.gd caption panels: the comic's narration, Vesper in yellow, Shade in red)
narration("SHADE, THE WRITER, DRAGGED VESPER BACK ONTO THE PAGE. BUT THE CITY HE KNEW WAS GONE.", -1e9)
narration("MY CITY... WHAT DID HE DO TO IT? EVERYTHING'S CORRUPTED.", -1e9, "vesper")
narration("I'M ENDING YOU, VESPER. ONCE AND FOR ALL. THIS ONE IS PERSONAL.", 900, "shade")
narration("SOMETHING SKITTERS IN THE GUTTERS. SHADE HAS BEEN DRAWING NEW THINGS.", 1500)
narration("I SEE YOU, VESPER. STEP INTO MY LIGHT.", 3200, "shade")
narration("A GATE OUT OF THE CITY. AND SOMETHING GUARDING IT.", 5700)

with open(OUT, "w") as f:
    f.write(f"[gd_scene load_steps={len(ext) + 1} format=3]\n\n")
    f.write("\n".join(ext) + "\n\n")
    f.write("\n\n".join(nodes) + "\n")
print("wrote", OUT)
