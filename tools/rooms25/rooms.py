#!/usr/bin/env python3
"""Room-layout helpers used by build_rooms.py to generate the 2.5D story
rooms (scenes/world25/rooms/*.tscn). The output is ordinary, editable Godot
scenes. NOTE: re-running build_rooms.py overwrites those files, so once a
room has been edited by hand in the Godot editor, change it there instead.
"""
import math, random, os

PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(PROJ, "scenes/world25/rooms")
os.makedirs(OUT, exist_ok=True)

EXT = [
    ("Script", "res://scripts/world25/room.gd", "room"),
    ("Script", "res://scripts/clearing/island.gd", "island"),
    ("Script", "res://scripts/world25/gate.gd", "gate"),
    ("Script", "res://scripts/world25/biome_props.gd", "bprops"),
    ("Script", "res://scripts/clearing/grass_field.gd", "grass"),
    ("Script", "res://scripts/clearing/pine.gd", "pine"),
    ("Script", "res://scripts/clearing/trunk.gd", "trunk"),
    ("Script", "res://scripts/clearing/brazier.gd", "brazier"),
    ("Script", "res://scripts/clearing/scatter_props.gd", "scatter"),
    ("Script", "res://scripts/clearing/watcher_eyes.gd", "eyes"),
    ("Script", "res://scripts/clearing/altar.gd", "altar"),
    ("PackedScene", "res://scenes/clearing/scribble.tscn", "scribble"),
    ("PackedScene", "res://scenes/clearing/monsters/crumple.tscn", "crumple"),
    ("PackedScene", "res://scenes/clearing/monsters/crossed_out.tscn", "crossed_out"),
    ("PackedScene", "res://scenes/clearing/monsters/smudge.tscn", "smudge"),
    ("PackedScene", "res://scenes/clearing/monsters/inkwell.tscn", "inkwell"),
    ("PackedScene", "res://scenes/clearing/monsters/eraser.tscn", "eraser"),
    ("Resource", "res://data/biomes/darkwood.tres", "b_darkwood"),
    ("Resource", "res://data/biomes/shallows.tres", "b_shallows"),
    ("Resource", "res://data/biomes/wastes.tres", "b_wastes"),
    ("Resource", "res://data/biomes/arena.tres", "b_arena"),
]
KIND = {k: i for i, k in enumerate("CANOPY TOMBSTONE STUMP GARDEN_PLOT BARN SCARECROW PILLAR RITUAL_CIRCLE SHADE_STATUE CORAL TUBE_PLANT INK_POOL CRYSTAL PAPER_MOUND PINS NEST PENCIL_TOTEM INK_POT".split())}
ROT = {"north": 0, "south": 180, "east": -90, "west": 90}


def T(x, y, z, rot_y=0.0):
    c, s = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    return f"Transform3D({c:.4f}, 0, {-s:.4f}, 0, 1, 0, {s:.4f}, 0, {c:.4f}, {x:.2f}, {y:.2f}, {z:.2f})"


def fmt(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, str): return v
    return str(v)


class Room:
    def __init__(self, rid, biome, cell, hw, hd, seed=1, biome_b=None, blend=None):
        self.rid, self.biome, self.cell, self.hw, self.hd = rid, biome, cell, hw, hd
        self.biome_b, self.blend = biome_b, blend
        self.rng = random.Random(seed)
        self.gates = {}      # side -> (target_scene, target_gate, offset)
        self.nodes = []
        self.enemies = []
        self.clear_zones = [(0, 0, 3.0)]
        self.props = {}
        self.story = {}

    def gate(self, side, target, target_gate, offset=0.0, always_open=False):
        self.gates[side] = (target, target_gate, offset, always_open)

    def gate_pos(self, side):
        off = self.gates[side][2]
        hw, hd = self.hw, self.hd
        return {"north": (off, -hd), "south": (off, hd), "east": (hw, off), "west": (-hw, off)}[side]

    # ---- polygon with gaps at the gates
    def polygon(self):
        hw, hd, c = self.hw, self.hd, 2.5
        corners = [(-hw + c, -hd), (hw - c, -hd), (hw, -hd + c), (hw, hd - c), (hw - c, hd), (-hw + c, hd), (-hw, hd - c), (-hw, -hd + c)]
        sides = [("north", corners[0], corners[1]), ("east", corners[2], corners[3]), ("south", corners[4], corners[5]), ("west", corners[6], corners[7])]
        pts, open_edges = [], []
        for name, a, b in sides:
            pts.append(a)
            length = math.dist(a, b)
            d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
            outward = (d[1], -d[0])  # clockwise order in (x, z): right-hand normal points out
            gap = None
            if name in self.gates:
                g = self.gate_pos(name)
                t = (g[0] - a[0]) * d[0] + (g[1] - a[1]) * d[1]
                gap = (t - 1.8, t + 1.8)
            n = max(int(length / 3.5), 1)
            for i in range(1, n):
                t = length * i / n
                if gap and gap[0] - 1.2 < t < gap[1] + 1.2:
                    continue
                j = self.rng.uniform(-0.6, 0.6)
                pts.append((a[0] + d[0] * t + outward[0] * j, a[1] + d[1] * t + outward[1] * j))
            if gap:
                # insert the gap points in order along the edge
                before = [p for p in pts[pts.index(a):] ]
                g0 = (a[0] + d[0] * gap[0], a[1] + d[1] * gap[0])
                g1 = (a[0] + d[0] * gap[1], a[1] + d[1] * gap[1])
                # find insertion index: after last point whose t < gap[0]
                seg = pts[pts.index(a):]
                ts = [((p[0] - a[0]) * d[0] + (p[1] - a[1]) * d[1]) for p in seg]
                k = pts.index(a) + sum(1 for t in ts if t < gap[0])
                pts[k:k] = [g0, g1]
                open_edges.append(k)
        # open edge indices must be recomputed after all insertions
        open_edges = []
        for name in self.gates:
            g = self.gate_pos(name)
            for i in range(len(pts)):
                p, q = pts[i], pts[(i + 1) % len(pts)]
                mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
                if math.dist(mid, g) < 0.05:
                    open_edges.append(i)
        return pts, open_edges

    def inside(self, x, z, margin=1.6):
        return abs(x) < self.hw - margin and abs(z) < self.hd - margin and not (abs(x) > self.hw - 2.5 - margin + 1.0 and abs(z) > self.hd - 2.5 - margin + 1.0)

    def clear_path_to_gates(self):
        for side in self.gates:
            gx, gz = self.gate_pos(side)
            for k in range(6):
                t = k / 5
                self.clear_zones.append((gx * (1 - t) * 0.92, gz * (1 - t) * 0.92, 2.2))

    def free_spot(self, margin=1.8, clearance=1.4, tries=200):
        for _ in range(tries):
            x = self.rng.uniform(-self.hw + margin, self.hw - margin)
            z = self.rng.uniform(-self.hd + margin, self.hd - margin)
            if not self.inside(x, z, margin):
                continue
            if any(math.dist((x, z), (cx, cz)) < cr + clearance for cx, cz, cr in self.clear_zones):
                continue
            return x, z
        return None

    def prop(self, script, x, z, y=0.0, rot=0.0, name=None, **props):
        self.nodes.append(("Props", name or f"{script}_{len(self.nodes)}", script, (x, y, z), rot, props))

    def scatter(self, kind, n, clearance=1.4, **props):
        for i in range(n):
            spot = self.free_spot(clearance=clearance)
            if not spot:
                return
            x, z = spot
            self.clear_zones.append((x, z, props.get("radius", 1.0) * props.get("size", 1.0) * 0.8))
            p = dict(props)
            p.setdefault("seed", self.rng.randint(1, 999))
            self.prop("bprops", x, z, rot=self.rng.uniform(0, 360), name=f"{kind.title().replace('_', '')}{i + 1}", kind=KIND[kind], **p)

    def enemy(self, kind, x, z, **props):
        self.enemies.append((kind, x, z, props))
        self.clear_zones.append((x, z, 1.2))

    # ---- output
    def write(self, title, subtitle, enter, clear, cutscene="", extra_room_props=""):
        pts, open_edges = self.polygon()
        ext = "".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]\n' for t, p, i in EXT)
        lines = [f"[gd_scene format=3]\n\n{ext}"]
        hw, hd = self.hw, self.hd
        bounds = f"Rect2({-hw + 5.5}, {-hd + 3}, {2 * hw - 11}, {2 * hd - 6})"
        room = [f'[node name="{self.rid.title().replace("_", "")}" type="Node3D"]', 'script = ExtResource("room")',
                f'room_id = "{self.rid}"', f'biome = ExtResource("b_{self.biome}")', f"map_cell = Vector2i({self.cell[0]}, {self.cell[1]})",
                f"camera_bounds = {bounds}", "default_spawn = Vector3(0, 0.05, 0)", f'title = "{title}"', f'subtitle = "{subtitle}"',
                f'enter_captions = "{enter}"', f'clear_captions = "{clear}"']
        if cutscene:
            room.append(f'cutscene_on_clear = "{cutscene}"')
        if self.biome_b:
            room.append(f'biome_b = ExtResource("b_{self.biome_b}")')
            room.append(f"blend_from = Vector2({self.blend[0][0]}, {self.blend[0][1]})")
            room.append(f"blend_to = Vector2({self.blend[1][0]}, {self.blend[1][1]})")
        if extra_room_props:
            room.append(extra_room_props)
        lines.append("\n".join(room) + "\n")
        pstr = ", ".join(f"{x:.2f}, {z:.2f}" for x, z in pts)
        oe = ", ".join(str(i) for i in open_edges)
        lines.append(f'[node name="Island" type="Node3D" parent="."]\nscript = ExtResource("island")\npolygon = PackedVector2Array({pstr})\nopen_edges = PackedInt32Array({oe})\n')
        lines.append(f'[node name="Grass" type="Node3D" parent="."]\nscript = ExtResource("grass")\nisland_path = NodePath("../Island")\n'
                     f"area = Rect2({-hw}, {-hd}, {2 * hw}, {2 * hd})\ncount = {int(hw * hd * 1.6)}\nsize_range = Vector2(0.55, 0.95)\nseed = {self.rng.randint(1, 99)}\n"
                     f"keep_clear = PackedVector3Array({', '.join(f'{x:.1f}, {z:.1f}, {r * 0.7:.1f}' for x, z, r in self.clear_zones[:40])})\n")
        for side, (target, tg, off, always) in self.gates.items():
            gx, gz = self.gate_pos(side)
            g = [f'[node name="Gate{side.title()}" type="Node3D" parent="."]', f"transform = {T(gx, 0, gz, ROT[side])}", 'script = ExtResource("gate")',
                 f'gate_id = "{side}"', f'target_scene = "{target}"', f'target_gate = "{tg}"']
            if always:
                g.append("always_open = true")
            lines.append("\n".join(g) + "\n")
        groups = {}
        for parent, name, script, (x, y, z), rot, props in self.nodes:
            groups.setdefault(parent, []).append((name, script, x, y, z, rot, props))
        for parent, items in groups.items():
            lines.append(f'[node name="{parent}" type="Node3D" parent="."]\n')
            used = set()
            for name, script, x, y, z, rot, props in items:
                while name in used:
                    name += "b"
                used.add(name)
                body = "\n".join(f"{k} = {fmt(v)}" for k, v in props.items())
                lines.append(f'[node name="{name}" type="Node3D" parent="{parent}"]\ntransform = {T(x, y, z, rot)}\nscript = ExtResource("{script}")\n{body}\n')
        lines.append('[node name="Enemies" type="Node3D" parent="."]\n')
        for i, (kind, x, z, props) in enumerate(self.enemies):
            body = "\n".join(f"{k} = {fmt(v)}" for k, v in props.items())
            lines.append(f'[node name="{kind.title().replace("_", "")}{i + 1}" parent="Enemies" instance=ExtResource("{kind}")]\ntransform = {T(x, 0.05, z)}\n{body}\n')
        open(os.path.join(OUT, f"{self.rid}.tscn"), "w").write("\n".join(lines))
        print("wrote", self.rid, "gates", list(self.gates), "open edges", open_edges, "enemies", len(self.enemies))


def forest_ring(r, n_pines=10, void_pines=4, canopies=2):
    """Darkwood surroundings: pines on the rim, trunks, canopy over the north edge."""
    for i in range(n_pines):
        side = r.rng.choice(["n", "e", "w"])
        if side == "n":
            x, z = r.rng.uniform(-r.hw, r.hw), -r.hd - r.rng.uniform(2.5, 5)
        else:
            x, z = (r.hw if side == "e" else -r.hw) + (1 if side == "e" else -1) * r.rng.uniform(2.5, 5), r.rng.uniform(-r.hd, r.hd * 0.5)
        if any(math.dist((x, z), r.gate_pos(s)) < 5 for s in r.gates):
            continue
        r.nodes.append(("Forest", f"Pine{i + 1}", "pine", (x, 0, z), 0, {"height": round(r.rng.uniform(7, 10), 1), "radius": round(r.rng.uniform(1.8, 2.4), 1)}))
    for i in range(void_pines):
        x = r.rng.uniform(-r.hw, r.hw)
        z = r.hd + r.rng.uniform(3, 5)
        if any(math.dist((x, z), r.gate_pos(s)) < 5 for s in r.gates):
            continue
        r.nodes.append(("Forest", f"VoidPine{i + 1}", "pine", (x, -9, z), 0, {"height": 11.0, "radius": 2.2, "color": "Color(0.06, 0.06, 0.11, 1)"}))
    for sx in (-1, 1):
        r.nodes.append(("Forest", f"Trunk{'L' if sx < 0 else 'R'}", "trunk", (sx * (r.hw + 3.5), -8, r.hd - 1), 0, {"height": 26.0, "radius": 1.6}))
    for i in range(canopies):
        x = -r.hw * 0.6 + i * r.hw * 1.2 / max(canopies - 1, 1)
        if any(math.dist((x, -r.hd), r.gate_pos(s)) < 4.5 for s in r.gates):
            x += 5
        r.nodes.append(("Forest", f"Canopy{i + 1}", "bprops", (x, 0, -r.hd - 2.2), 0, {"kind": KIND["CANOPY"], "size": round(r.rng.uniform(1.0, 1.25), 2), "seed": r.rng.randint(1, 99)}))
    r.nodes.append(("Forest", "Eyes1", "eyes", (r.rng.uniform(-r.hw, r.hw), -4, r.hd + 3), 0, {}))
