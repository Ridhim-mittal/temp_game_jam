#!/usr/bin/env python3
"""Generates scenes/levels/shade_finale.tscn: the last fight, back in Shade's
City after the Ink Cave collapses (chapter SHADE). Run from anywhere:
python3 tools/level2d/build_shade_finale.py (re-running overwrites hand edits).

One walled stretch of street in front of the city painting, a few one-way
bars to jump to. Everything that happens is run by shade_finale.gd: Shade's
hand writes its name, draws waves of monsters, then the light and Vesper's
double (shade_double.gd), then THE END.

Street top is y = 600 (the player stands at 574). The arena runs x 0..1600.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "levels", "shade_finale.tscn")
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
BACKDROP = res("Script", "res://scripts/background/city_painting.gd")
STREETS = res("Script", "res://scripts/world/street_ground.gd")
WALLS = res("Script", "res://scripts/world/city_block.gd")
COVER = res("Script", "res://scripts/world/light_cover.gd")
FINALE = res("Script", "res://scripts/world/shade_finale.gd")
HUD = res("Script", "res://scripts/ui/hud.gd")
BOSSBAR = res("Script", "res://scripts/ui/boss_bar.gd")
MUSIC = res("Script", "res://scripts/audio/level_music.gd")
MOOD = res("Script", "res://scripts/world/level_mood.gd")
FRAME = res("Script", "res://scripts/ui/comic_frame.gd")

LEFT, RIGHT = 0, 1600

node("ShadeFinale", "Node2D", None)
node("Backdrop", "Node2D", ".", [("script", f'ExtResource("{BACKDROP}")')])
node("World", "Node2D", ".")


def block(name, x, y, w, h):
    node(name, "StaticBody2D", "World", [("position", v(x, y)), ("script", f'ExtResource("{STREETS}")'), ("size", v(w, h))])


def wall(name, x, y, w, h):
    """An end wall: a tall neon-edged building (city_block.gd, centred), in Shade's pink."""
    node(name, "StaticBody2D", "World", [("position", v(x + w / 2, y + h / 2)), ("script", f'ExtResource("{WALLS}")'),
         ("size", v(w, h)), ("trim", "Color(1, 0.36, 0.66, 1)"), ("accent", "Color(0.4, 0.85, 1, 1)")])


def bar(x, y, w):
    node(uniq("Bar"), "StaticBody2D", "World", [("position", v(x, y)), ("script", f'ExtResource("{COVER}")'),
         ("kind", "3"), ("size", v(w, 22)), ("post_height", str(STREET - y - 22))])


block("Street", LEFT - 700, STREET, RIGHT - LEFT + 1400, 500)
wall("WallLeft", LEFT - 60, -1400, 60, 2100)
wall("WallRight", RIGHT, -1400, 60, 2100)
# a few bars to get above the shockwaves and the dives
bar(LEFT + 220, 450, 200)
bar(RIGHT - 420, 450, 200)
bar(LEFT + 700, 330, 200)

node("Finale", "Node2D", ".", [("z_index", "3"), ("script", f'ExtResource("{FINALE}")'),
     ("arena_left", f"{LEFT}.0"), ("arena_right", f"{RIGHT}.0"), ("floor_y", f"{STREET}.0")])

# thrown back into the city from the collapsing cave: a hard landing
node("Player", None, ".", [("position", v(LEFT + 560, STREET - 26 - 500))], instance=PLAYER)
node("Camera2D", None, "Player", [("framing_offset", v(0, -226)), ("limit_left", str(LEFT - 60)),
     ("limit_right", str(RIGHT + 60))])

node("UI", "CanvasLayer", ".", [("layer", "2")])
node("HUD", "Control", "UI", [("layout_mode", "3"), ("anchors_preset", "15"), ("anchor_right", "1.0"),
     ("anchor_bottom", "1.0"), ("grow_horizontal", "2"), ("grow_vertical", "2"), ("mouse_filter", "2"),
     ("script", f'ExtResource("{HUD}")')])
node("BossBar", "Control", "UI", [("layout_mode", "3"), ("anchors_preset", "15"), ("anchor_right", "1.0"),
     ("anchor_bottom", "1.0"), ("mouse_filter", "2"), ("script", f'ExtResource("{BOSSBAR}")')])
node("LevelMusic", "Node", ".", [("script", f'ExtResource("{MUSIC}")'), ("track", '"hunters"')])  # The Hunters, low (music.gd)
node("LevelMood", "Node", ".", [("script", f'ExtResource("{MOOD}")')])
node("ComicFrame", "CanvasLayer", ".", [("script", f'ExtResource("{FRAME}")'), ("page_number", "9"),
     ("live_areas", "Array[Rect2]([Rect2(-800, -2000, 3200, 3200)])")])

with open(OUT, "w") as f:
    f.write(f"[gd_scene load_steps={len(ext) + 1} format=3]\n\n")
    f.write("\n".join(ext) + "\n\n")
    f.write("\n\n".join(nodes) + "\n")
print("wrote", OUT)
