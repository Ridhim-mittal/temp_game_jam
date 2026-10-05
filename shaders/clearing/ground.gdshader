shader_type spatial;
// Ground (top faces) and cliffs (side faces) for 2.5D islands, painted in
// world space from a biome palette (scripts/world25/biome.gd):
//   mode 0 GRASS        stone tiles (paved over: no grass), earth patches
//   mode 1 WATER_STONE  flagstones under rippling caustic light (Shallows)
//   mode 2 CRACKED      cracked earth with pale grit (Crumple Wastes)
//   mode 3 DIRT         bare packed earth, roots, pebbles, dropped staples (the Spine)
// Any mode can carry the Writer's marks scratched into it
// (`rune_density`; writers_marks.gdshaderinc: ink drops, nibs, quills, the
// Ember, proofing and comic marks), some of them glowing (`rune_color`).
// Two palettes (A and B) can be blended across the island: biome A on the
// `blend_from` side, B past `blend_to`, meeting along a wavy inked line.
// Palette order: base, light, dark, accent, accent_dark, stain, cliff,
// lip, cliff_line (linear colours, set by island.gd).
render_mode specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"
#include "res://shaders/world25/writers_marks.gdshaderinc"

uniform vec4 pal_a[9];
uniform vec4 pal_b[9];
uniform int mode_a = 0;
uniform int mode_b = 0;
uniform float use_blend = 0.0;
uniform vec2 blend_from = vec2(0.0, 0.0);
uniform vec2 blend_to = vec2(10.0, 0.0);
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
// xz centre + radius of each sandy patch (radius 0 = unused).
uniform vec3 sand_zones[4];
// xz centre + radius where ink stains gather (around the altar).
uniform vec3 stain_zone = vec3(0.0, 0.0, 0.0);
uniform float stain_amount : hint_range(0.0, 1.0) = 0.25;
// Cryptic sigils scratched into the ground: share of 3-unit cells with one
// (0 = none), and the glow of the ones that burn.
uniform float rune_density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rune_color : source_color = vec4(1.0, 0.28, 0.18, 1.0);
uniform float rune_glow = 1.4;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 P(int w, int i) {
	return w == 0 ? pal_a[i].rgb : pal_b[i].rgb;
}

// Voronoi: x = distance to the nearest cell edge-ish (F2 - F1), y = id of
// the nearest cell. `wobble` animates the cell centres.
vec2 voronoi(vec2 x, float wobble) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = vec2(hash(n + g), hash(n + g + 17.3));
			vec2 o = 0.5 + 0.42 * sin(wobble + 6.2831 * h);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = hash(n + g + 3.7);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f2 - f1, id);
}

float stains(vec2 p) {
	float boost = stain_zone.z > 0.0 ? clamp(1.0 - length(p - stain_zone.xy) / stain_zone.z, 0.0, 1.0) : 0.0;
	return fbm(p * 0.45 + 17.0) + boost * 0.35;
}

// Stone tiles laid in a running bond (the old grass, paved over): each tile
// its own shade, dark grout, chipped corners, moss in some joints, the odd
// crack, worn patches, and earth showing where tiles are missing.
vec3 grass_top(vec2 p, int w) {
	float n = fbm(p * 0.22) + noise(p * 1.4) * 0.12;
	float ts = 1.6;
	vec2 tp = p / ts;
	tp.x += mod(floor(tp.y), 2.0) * 0.5;
	vec2 cell = floor(tp);
	vec2 f = fract(tp);
	float h = hash(cell);
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), step(0.66, h) * 0.75);
	col = mix(col, P(w, 2), step(h, 0.2) * 0.7);
	col *= 0.9 + 0.14 * noise(p * 2.3 + h * 13.0);
	// worn, darker stretches of floor (the old two-tone mottling)
	col = mix(col, P(w, 2), step(n, 0.38) * 0.45);
	// grout and chipped corners
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * ts;
	vec2 corner = vec2(step(0.5, hash(cell + 2.0)), step(0.5, hash(cell + 3.0)));
	float chip = step(0.8, hash(cell + 5.1)) * (1.0 - step(0.22, length(f - corner)));
	float grout = 1.0 - smoothstep(0.035, 0.065, edge);
	// moss creeping out of some joints
	float moss = (1.0 - smoothstep(0.06, 0.2, edge)) * step(0.58, noise(p * 0.6 + 3.0));
	col = mix(col, P(w, 2) * 0.85, moss * 0.7);
	col = mix(col, mix(P(w, 4), ink.rgb, 0.65), max(grout, chip));
	// a hairline crack through some tiles
	vec2 v = voronoi(p * 0.9 + 5.0, 0.0);
	col = mix(col, mix(P(w, 4), ink.rgb, 0.5), (1.0 - smoothstep(0.012, 0.03, v.x)) * step(0.8, hash(cell + 9.0)));

	// earth where tiles are missing: wobbly edge, dashed ink outline, grit
	float sm = -1.0;
	for (int i = 0; i < 4; i++) {
		vec3 z = sand_zones[i];
		if (z.z > 0.0) {
			sm = max(sm, 1.0 - length(p - z.xy) / z.z);
		}
	}
	sm += (noise(p * 0.9) - 0.5) * 0.28;
	// plus a few small holes in the paving anywhere
	sm = max(sm, (fbm(p * 0.45 + 40.0) - 0.79) * 3.0);
	if (sm > 0.0) {
		col = P(w, 3);
		col = mix(col, P(w, 4), step(0.62, noise(p * 0.6 + 4.0)) * 0.6);
		col = mix(col, P(w, 4), step(0.93, hash(floor(p * 9.0))));
	}
	float dash = step(0.5, fract((p.x + p.y) * 2.2));
	col = mix(col, ink.rgb, step(abs(sm), 0.012) * dash * 0.85);
	col = mix(col, P(w, 4) * 0.8, step(abs(sm), 0.03) * (1.0 - step(abs(sm), 0.012)) * step(0.0, sm));

	// ink stains, heavier near the altar
	float s = stains(p);
	float th = 1.0 - stain_amount * 0.5;
	col = mix(col, P(w, 5), step(th, s));
	col = mix(col, P(w, 5) * 0.7, step(th + 0.06, s) * 0.5);
	return col;
}

vec3 water_top(vec2 p, int w, out float glow) {
	// flagstones
	vec2 v = voronoi(p * 0.55, 0.0);
	vec3 col = mix(P(w, 0), P(w, 1), step(0.6, v.y) * 0.6);
	col *= 0.92 + 0.16 * noise(p * 1.7);
	col = mix(col, P(w, 4), 1.0 - smoothstep(0.03, 0.07, v.x));
	// dark ink pooled in the low stones
	float s = stains(p);
	col = mix(col, P(w, 5), step(0.78, s) * 0.85);
	// caustic light rippling across everything
	float t = TIME * 0.6;
	vec2 c1 = voronoi(p * 0.75 + vec2(t * 0.15, 0.0), t);
	vec2 c2 = voronoi(p * 1.1 - vec2(0.0, t * 0.12), t * 1.3 + 2.0);
	float caustic = max(1.0 - smoothstep(0.0, 0.035, c1.x), (1.0 - smoothstep(0.0, 0.022, c2.x)) * 0.5);
	col = mix(col, P(w, 3), caustic * 0.4);
	glow = caustic * 0.2;
	// pebbles
	vec2 pp = p * 3.0;
	float pebble = step(0.93, hash(floor(pp))) * step(length(fract(pp) - 0.5), 0.2);
	col = mix(col, P(w, 2), pebble);
	return col;
}

vec3 cracked_top(vec2 p, int w) {
	float n = fbm(p * 0.25);
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), step(0.6, n) * 0.8);
	col = mix(col, P(w, 2), step(n, 0.36));
	// crack network: big plates and finer splits
	vec2 big = voronoi(p * 0.32, 0.0);
	vec2 fine = voronoi(p * 0.9 + 5.0, 0.0);
	float crack = max(1.0 - smoothstep(0.02, 0.05, big.x), (1.0 - smoothstep(0.01, 0.03, fine.x)) * step(0.5, noise(p * 0.5)));
	col = mix(col, P(w, 4), crack);
	// pale grit and scratches
	vec2 gp = p * 6.0;
	col = mix(col, P(w, 3), step(0.97, hash(floor(gp))) * 0.8);
	float s = stains(p);
	col = mix(col, P(w, 5), step(0.8, s) * 0.8);
	return col;
}

// Bare packed earth: mottled, speckled grain, pebbles with inked rims,
// roots snaking just under the surface, sparse cracks, trodden patches and
// the odd staple dropped off the Writer's desk.
vec3 dirt_top(vec2 p, int w) {
	float n = fbm(p * 0.18) + noise(p * 1.2) * 0.15;
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), smoothstep(0.55, 0.62, n) * 0.75);
	col = mix(col, P(w, 2), 1.0 - smoothstep(0.34, 0.4, n));
	col *= 0.88 + 0.2 * noise(p * 7.0) * noise(p * 2.3 + 4.0);
	// pebbles
	vec2 pp = p * 1.8;
	vec2 pc = floor(pp);
	vec2 pf = fract(pp) - 0.5 - (vec2(hash(pc + 1.0), hash(pc + 2.0)) - 0.5) * 0.5;
	float pr = 0.1 + 0.1 * hash(pc + 3.0);
	float pd = length(pf * vec2(1.0, 1.3));
	float peb = step(0.84, hash(pc));
	col = mix(col, P(w, 4), peb * (1.0 - step(pr + 0.035, pd)));
	col = mix(col, P(w, 1) * (1.05 + 0.2 * hash(pc + 5.0)), peb * (1.0 - step(pr, pd)));
	// roots
	float rt = abs(noise(p * 0.32 + vec2(0.0, 5.0)) - 0.5);
	col = mix(col, P(w, 4), (1.0 - smoothstep(0.007, 0.016, rt)) * step(0.5, noise(p * 0.18 + 9.0)) * 0.85);
	// cracks, here and there
	vec2 v = voronoi(p * 0.4 + 3.0, 0.0);
	col = mix(col, P(w, 4), (1.0 - smoothstep(0.012, 0.03, v.x)) * step(0.6, noise(p * 0.3)));
	// trodden patches (sand zones): darker, packed flat, an inked edge
	float sm = -1.0;
	for (int i = 0; i < 4; i++) {
		vec3 z = sand_zones[i];
		if (z.z > 0.0) {
			sm = max(sm, 1.0 - length(p - z.xy) / z.z);
		}
	}
	sm += (noise(p * 0.9) - 0.5) * 0.28;
	col = mix(col, P(w, 3) * (0.9 + 0.15 * noise(p * 3.0)), step(0.0, sm) * 0.7);
	float dash = step(0.5, fract((p.x + p.y) * 2.2));
	col = mix(col, ink.rgb, step(abs(sm), 0.012) * dash * 0.6);
	// dropped staples: a bar with its two legs bent down
	vec2 bp = p * 1.4;
	vec2 bc = floor(bp);
	vec2 bf = fract(bp) - 0.5;
	float ba = hash(bc + 8.0) * 6.283;
	vec2 br = vec2(cos(ba) * bf.x + sin(ba) * bf.y, -sin(ba) * bf.x + cos(ba) * bf.y);
	float bar = step(abs(br.x), 0.17) * step(abs(br.y), 0.014);
	float legs = step(abs(abs(br.x) - 0.16), 0.014) * step(0.0, br.y) * step(br.y, 0.07);
	float staple = step(0.93, hash(bc + 4.0)) * max(bar, legs);
	col = mix(col, mix(P(w, 1), vec3(0.66, 0.68, 0.74), 0.6), staple);
	// ink stains
	float s = stains(p);
	float th = 1.0 - stain_amount * 0.5;
	col = mix(col, P(w, 5), step(th, s));
	col = mix(col, P(w, 5) * 0.7, step(th + 0.06, s) * 0.5);
	return col;
}

vec3 top_color(vec2 p, int w, int mode, out float glow) {
	glow = 0.0;
	if (mode == 1) {
		return water_top(p, w, glow);
	} else if (mode == 2) {
		return cracked_top(p, w);
	} else if (mode == 3) {
		return dirt_top(p, w);
	}
	return grass_top(p, w);
}

// The Writer's marks scratched into the ground, one in some cells of a 3-unit grid,
// each turned its own way; `hot` = this one glows.
float runes(vec2 p, out float hot, out float phase) {
	hot = 0.0;
	phase = 0.0;
	if (rune_density <= 0.0) {
		return 0.0;
	}
	vec2 cs = p / 3.2;
	vec2 cell = floor(cs);
	if (hash(cell + 41.0) > rune_density) {
		return 0.0;
	}
	vec2 f = fract(cs) - 0.5 - (vec2(hash(cell + 2.0), hash(cell + 5.0)) - 0.5) * 0.3;
	float a = hash(cell + 7.0) * 6.283;
	vec2 q = vec2(cos(a) * f.x + sin(a) * f.y, -sin(a) * f.x + cos(a) * f.y) / 0.3;
	int id = int(hash(cell + 3.0) * float(WM_COUNT));
	float m = 1.0 - smoothstep(0.05, 0.1, writers_mark(id, q));
	hot = step(0.45, hash(cell + 13.0));
	phase = hash(cell + 17.0) * 6.283;
	return m * (0.75 + 0.25 * noise(p * 9.0));
}

// The cliffs: every island is a thick stack of the Writer's paper seen
// edge-on (the Margins are the edge of his desk): page edges in the cliff's
// colour, ruled by fine lines, the sheets a little uneven, a darker line at
// every gathering, and ink that ran over the lip dripping down it.
vec3 side_color(int w) {
	float depth = clamp(-world_pos.y / 6.0, 0.0, 1.0);
	float u = world_pos.x * 0.8 + world_pos.z * 0.8;
	vec3 col = mix(P(w, 6), vec3(0.78, 0.74, 0.66), 0.3);
	float sheet = (world_pos.y + (noise(vec2(u * 1.3, 0.0)) - 0.5) * 0.08) / 0.15;
	float f = fract(sheet);
	col *= 0.88 + 0.16 * hash(vec2(floor(sheet), floor(u * 0.5)));
	float line = 1.0 - smoothstep(0.0, 0.14, min(f, 1.0 - f));
	float gathering = step(mod(floor(sheet + 0.5), 7.0), 0.5);
	col = mix(col, P(w, 8), line * (0.55 + 0.45 * gathering));
	col = mix(col, P(w, 7), step(-0.55, world_pos.y));
	col = mix(col, ink.rgb, step(-0.62, world_pos.y) * step(world_pos.y, -0.55));
	// ink run over the lip, dripping down the pages
	float lane = floor(u * 3.0);
	float run = step(0.72, hash(vec2(lane, 9.0))) * (0.4 + 1.6 * hash(vec2(lane, 5.0)));
	float x = abs(fract(u * 3.0) - 0.5);
	float drip = step(x, 0.12) * step(-run, world_pos.y);
	drip = max(drip, step(length(vec2(x * 0.33, (world_pos.y + run) * 1.4)), 0.07) * step(0.01, run));
	col = mix(col, ink.rgb, drip);
	col = mix(col, vec3(0.0), depth * 0.85);
	return col;
}

// 0 = biome A, 1 = biome B, with a wavy, patchy boundary.
float blend_amount(vec2 p, out float edge) {
	edge = 1.0;
	if (use_blend < 0.5) {
		return 0.0;
	}
	vec2 d = blend_to - blend_from;
	float t = clamp(dot(p - blend_from, d) / dot(d, d), 0.0, 1.0);
	float wave = t + (fbm(p * 0.35) - 0.5) * 0.45;
	edge = abs(wave - 0.5);
	return step(0.5, wave);
}

void fragment() {
	vec2 p = world_pos.xz;
	float edge;
	float b = blend_amount(p, edge);
	float glow = 0.0;
	vec3 rune_emission = vec3(0.0);
	vec3 col;
	if (world_normal.y > 0.6) {
		float ga;
		float gb;
		vec3 ca = b < 0.5 ? top_color(p, 0, mode_a, ga) : vec3(0.0);
		vec3 cb = b > 0.5 ? top_color(p, 1, mode_b, gb) : vec3(0.0);
		col = b < 0.5 ? ca : cb;
		glow = b < 0.5 ? ga : gb;
		// sigils: dark scratches, some of them smouldering
		float hot;
		float phase;
		float rm = runes(p, hot, phase);
		if (rm > 0.0) {
			col = mix(col, mix(ink.rgb, rune_color.rgb * 0.7, hot), rm * 0.8);
			float pulse = 0.65 + 0.35 * sin(TIME * 1.3 + phase);
			rune_emission = rune_color.rgb * rm * hot * pulse * rune_glow;
		}
		// inked, dashed seam where the biomes meet
		if (use_blend > 0.5) {
			float dash = step(0.35, fract((p.x - p.y) * 1.6));
			col = mix(col, ink.rgb, (1.0 - smoothstep(0.004, 0.012, edge)) * dash);
		}
	} else {
		col = side_color(b < 0.5 ? 0 : 1);
	}
	ALBEDO = col;
	EMISSION = col * glow + rune_emission;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
